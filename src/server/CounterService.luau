-- The service counter: where customers set their item down and haggle over it.
-- Each CounterSpot_<n> part (CustomerUtil) gets a "Negotiate" ProximityPrompt, enabled
-- only while a customer's item sits there with the negotiation open and nobody is
-- handling it. The spot part is tagged CounterSpot, and its OfferText attribute is the
-- bubble beside the item (CustomerVisuals.client draws it).
--
-- All of it is server state, per spot: the customer, their item, the current offer, the
-- hidden willing price (base price x WillingToPay), Patience, who holds the negotiation,
-- and the response deadline. CustomerService calls claimSpot, negotiate (which yields
-- until there's an outcome) and release; abort drops a negotiation when a customer is
-- sent away.
--
-- Remotes:
--   Haggle (server -> client)  "open" / "update" with the deal's public numbers, "close"
--   HaggleAction (client -> server)  spot index, then "accept", "counter" (percent of the
--                              base price), "refuse" or "close"
--   SaleEffect (server -> all clients)  position and amount, for the floating "+$"
-- Every action is checked: the player holds that spot's negotiation, is close enough, the
-- deal is still open, and a counter is a whole step inside COUNTER_RANGE. Closing a deal
-- flips its status before anything can yield, so it can only ever complete once.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("ShopConfig"))
local StockItems = require(Shared:WaitForChild("StockItems"))
local CustomerUtil = require(script.Parent:WaitForChild("CustomerUtil"))
local QuotaService = require(script.Parent:WaitForChild("QuotaService"))

local CounterService = {}

local haggleRemote = Instance.new("RemoteEvent")
haggleRemote.Name = "Haggle"
haggleRemote.Parent = ReplicatedStorage

local actionRemote = Instance.new("RemoteEvent")
actionRemote.Name = "HaggleAction"
actionRemote.Parent = ReplicatedStorage

local saleRemote = Instance.new("RemoteEvent")
saleRemote.Name = "SaleEffect"
saleRemote.Parent = ReplicatedStorage

local spots = {} -- [index] = spot state

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function inReach(player, spot)
	local root = rootOf(player)
	return root ~= nil
		and (root.Position - spot.part.Position).Magnitude <= Config.MAX_NEGOTIATE_DISTANCE
end

-- What the negotiating player's window shows. Never includes the willing price or Patience.
local function publicDeal(spot)
	local item = StockItems.get(spot.itemId)
	return {
		spot = spot.index,
		itemId = spot.itemId,
		itemName = item and item.name or spot.itemId,
		basePrice = spot.basePrice,
		offer = spot.offer,
		deadline = spot.deadline,
		step = Config.COUNTER_STEP,
		range = Config.COUNTER_RANGE,
	}
end

local function setOffer(spot, offer)
	spot.offer = offer
	spot.part:SetAttribute("OfferText", offer and `Offer: ${offer}` or nil)
end

local function refreshPrompt(spot)
	spot.prompt.Enabled = spot.status == "open" and spot.negotiator == nil
end

-- Lets go of whoever is handling the spot and closes their window.
local function unlock(spot)
	local player = spot.negotiator
	spot.negotiator = nil
	if player and player.Parent then
		haggleRemote:FireClient(player, "close", spot.index)
	end
	refreshPrompt(spot)
end

-- Ends the deal exactly once. outcome is "sold", "refused", "patience", "timeout" or
-- "aborted". Returns false if it was already over.
local function finish(spot, outcome, price, player)
	if spot.status ~= "open" then
		return false
	end
	spot.status = "done"
	spot.outcome = { kind = outcome, price = price, player = player }
	if outcome == "sold" then
		QuotaService.recordSale(price, player)
		saleRemote:FireAllClients(spot.part.Position + Vector3.new(0, 1.2, 0), price)
	end
	setOffer(spot, nil)
	unlock(spot)
	return true
end

local function say(spot, text, mood)
	if spot.customer then
		CustomerUtil.say(spot.customer, text, mood, 3)
	end
end

-- ================= PLAYER ACTIONS =================
local function onCounter(spot, player, percent)
	if
		typeof(percent) ~= "number"
		or percent ~= percent
		or percent % Config.COUNTER_STEP ~= 0
		or percent < Config.COUNTER_RANGE[1]
		or percent > Config.COUNTER_RANGE[2]
	then
		return
	end
	local price = math.floor(spot.basePrice * percent / 100 + 0.5)
	if price <= spot.willing then
		say(spot, "Deal.", "happy")
		finish(spot, "sold", price, player)
	elseif price <= spot.willing * (1 + Config.CLOSE_COUNTER_MARGIN) then
		local meet = math.floor((spot.offer + price) / 2 + 0.5)
		setOffer(spot, meet)
		say(spot, `Meet me halfway? ${meet}.`, "want")
		spot.deadline = workspace:GetServerTimeNow() + Config.LATER_RESPONSE_TIME
		haggleRemote:FireClient(player, "update", publicDeal(spot))
	else
		spot.patience -= 1
		if spot.patience <= 0 then
			say(spot, "Forget it. I'm not being robbed.", "annoyed")
			finish(spot, "patience", nil, player)
		else
			say(spot, "You can't be serious.", "annoyed")
			spot.deadline = workspace:GetServerTimeNow() + Config.LATER_RESPONSE_TIME
			haggleRemote:FireClient(player, "update", publicDeal(spot))
		end
	end
end

actionRemote.OnServerEvent:Connect(function(player, index, action, value)
	local spot = typeof(index) == "number" and spots[index]
	if not spot or spot.negotiator ~= player or spot.status ~= "open" then
		return
	end
	if action == "close" then
		unlock(spot)
		return
	end
	if not inReach(player, spot) or not (spot.customer and spot.customer.model.Parent) then
		unlock(spot)
		return
	end
	if action == "accept" then
		say(spot, "Pleasure doing business.", "happy")
		finish(spot, "sold", spot.offer, player)
	elseif action == "refuse" then
		finish(spot, "refused", nil, player)
	elseif action == "counter" then
		onCounter(spot, player, value)
	end
end)

local function onPrompt(spot, player)
	if spot.status ~= "open" or spot.negotiator or not inReach(player, spot) then
		return
	end
	spot.negotiator = player
	refreshPrompt(spot)
	haggleRemote:FireClient(player, "open", publicDeal(spot))
end

-- Walking away, dying or leaving lets go of the negotiation.
local sinceCheck = 0
RunService.Heartbeat:Connect(function(dt)
	sinceCheck += dt
	if sinceCheck < 0.5 then
		return
	end
	sinceCheck = 0
	for _, spot in spots do
		local player = spot.negotiator
		if player and (not player.Parent or not inReach(player, spot)) then
			unlock(spot)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for _, spot in spots do
		if spot.negotiator == player then
			spot.negotiator = nil
			refreshPrompt(spot)
		end
	end
end)

-- ================= SETUP =================
for _, entry in CustomerUtil.counterSpots() do
	local part = entry.part
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "NegotiatePrompt"
	prompt.ActionText = "Negotiate"
	prompt.ObjectText = ""
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = Config.NEGOTIATE_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = part
	CollectionService:AddTag(part, "CounterSpot")
	part:SetAttribute("OfferText", nil)

	local spot = { index = entry.index, part = part, prompt = prompt, status = "idle" }
	spots[entry.index] = spot
	prompt.Triggered:Connect(function(player)
		onPrompt(spot, player)
	end)
end

-- ================= CUSTOMER API =================
-- A free spot for the customer, now theirs; nil if every spot is taken.
function CounterService.claimSpot(customer)
	for _, spot in spots do
		if not spot.customer then
			spot.customer = customer
			spot.status = "idle"
			customer.spot = spot
			return spot
		end
	end
	return nil
end

function CounterService.spotCount()
	local count = 0
	for _ in spots do
		count += 1
	end
	return count
end

-- Opens the deal for the item now sitting on the spot and waits for the outcome:
-- returns a table { kind, price, player }.
function CounterService.negotiate(customer, spot, itemId)
	local item = StockItems.get(itemId)
	spot.itemId = itemId
	spot.basePrice = item and item.basePrice or 0
	spot.willing = spot.basePrice * customer.willingToPay
	spot.patience = Config.PATIENCE
	spot.outcome = nil
	spot.negotiator = nil
	spot.status = "open"
	spot.deadline = workspace:GetServerTimeNow() + Config.FIRST_RESPONSE_TIME
	spot.prompt.ObjectText = item and item.name or itemId
	setOffer(spot, math.floor(spot.basePrice * CustomerUtil.randomRange(Config.OFFER_RANGE) + 0.5))
	refreshPrompt(spot)

	while not spot.outcome do
		if workspace:GetServerTimeNow() > spot.deadline then
			finish(spot, "timeout")
			break
		end
		task.wait(0.2)
	end
	return spot.outcome
end

-- Frees the customer's spot for the next in line.
function CounterService.release(customer)
	local spot = customer.spot
	customer.spot = nil
	if spot and spot.customer == customer then
		finish(spot, "aborted")
		spot.customer = nil
		spot.status = "idle"
		refreshPrompt(spot)
	end
end

-- The customer is being sent away mid-deal (dusk, store closing): same as release.
CounterService.abort = CounterService.release

return CounterService
