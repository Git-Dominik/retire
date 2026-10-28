-- The service counter, where customers pay. Nobody has to stand behind it: a customer
-- sets their item down on a free CounterSpot_<n> part (CustomerUtil), waits CHECKOUT_TIME
-- with the price showing beside it, and pays the item's base price into the till
-- (QuotaService). The players' job is only to keep the shelves stocked.
--
-- Server state, per spot: the customer using it. CustomerService calls claimSpot,
-- checkout (which yields) and release. The sale happens inside the customer's own thread,
-- so a customer sent away mid-checkout (dusk, the store closing) never pays.
--
-- The spot parts are tagged CounterSpot; their PriceText attribute is the bubble beside
-- the item (CustomerVisuals.client draws it).
-- Remote: SaleEffect (server -> all clients) position and amount, for the floating "+$".
--
-- Request clients (QuestService) are the one exception to paying by themselves: their
-- price is fixed at the request's RewardPrice, and questCheckout puts a "Sell" prompt
-- (QuestSellPrompt, hold QUEST_SELL_HOLD) on their spot for up to QUEST_COUNTER_WAIT. Any
-- player can hold it. The server checks the client still holds the spot with the item on
-- it and the player is within QUEST_SELL_MAX_DISTANCE, then completes the request and
-- pays, all without yielding, so the reward can only be paid once. The prompt goes with
-- the spot when the client is released.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("ShopConfig"))
local StockItems = require(Shared:WaitForChild("StockItems"))
local CustomerUtil = require(script.Parent:WaitForChild("CustomerUtil"))
local QuotaService = require(script.Parent:WaitForChild("QuotaService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))

local CounterService = {}

local saleRemote = Instance.new("RemoteEvent")
saleRemote.Name = "SaleEffect"
saleRemote.Parent = ReplicatedStorage

local spots = {} -- [index] = { index, part, customer }

for _, entry in CustomerUtil.counterSpots() do
	CollectionService:AddTag(entry.part, "CounterSpot")
	entry.part:SetAttribute("PriceText", nil)
	spots[entry.index] = { index = entry.index, part = entry.part }
end

-- A free spot for the customer, now theirs; nil if every spot is taken.
function CounterService.claimSpot(customer)
	for _, spot in spots do
		if not spot.customer then
			spot.customer = customer
			customer.spot = spot
			return spot
		end
	end
	return nil
end

-- Rings up the item sitting on the customer's spot. Returns the price paid, or nil if
-- they lost the spot meanwhile.
function CounterService.checkout(customer, spot, itemId)
	local item = StockItems.get(itemId)
	local price = item and item.basePrice or 0
	spot.part:SetAttribute("PriceText", `${price}`)
	task.wait(CustomerUtil.randomRange(Config.CHECKOUT_TIME))
	spot.part:SetAttribute("PriceText", nil)
	if spot.customer ~= customer then
		return nil
	end
	QuotaService.recordSale(price)
	saleRemote:FireAllClients(spot.part.Position + Vector3.new(0, 1.2, 0), price)
	return price
end

local function removeSellPrompt(spot)
	if spot.prompt then
		spot.prompt:Destroy()
		spot.prompt = nil
	end
	spot.part:SetAttribute("PriceText", nil)
end

-- Whether the player's Sell on this spot is a sale: the client is still at the spot, the
-- requested item is lying on it, and the player is close enough to reach it.
local function canSell(player, customer, spot, quest)
	if spot.customer ~= customer or customer.gone or customer.sentHome then
		return false
	end
	local carried = customer.carried
	if not carried or carried.itemId ~= quest.ItemId or not carried.model.Parent then
		return false
	end
	if (carried.model:GetPivot().Position - spot.part.Position).Magnitude > 4 then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root ~= nil
		and humanoid ~= nil
		and humanoid.Health > 0
		and (root.Position - spot.part.Position).Magnitude <= Config.QUEST_SELL_MAX_DISTANCE
end

-- A request client's sale: the item is on their spot at the fixed RewardPrice, and a player
-- holds Sell. Yields until then (returning the price) or until QUEST_COUNTER_WAIT runs out
-- or they lose the spot (returning nil).
function CounterService.questCheckout(customer, spot, quest)
	local item = StockItems.get(quest.ItemId)
	local price = quest.RewardPrice
	spot.part:SetAttribute("PriceText", `${price}`)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QuestSellPrompt"
	prompt.ActionText = "Sell"
	prompt.ObjectText = item and item.name or quest.ItemId
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Config.QUEST_SELL_HOLD
	prompt.MaxActivationDistance = Config.QUEST_SELL_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = true
	prompt.Parent = spot.part
	spot.prompt = prompt

	local paid = false
	prompt.Triggered:Connect(function(player)
		if paid or not canSell(player, customer, spot, quest) then
			return
		end
		-- Nothing below yields, so a second trigger always sees paid.
		if not QuestService.complete(quest) then
			return
		end
		paid = true
		-- Set here, not in the client's thread: if they're sent home this instant, the sold
		-- item is still destroyed rather than put back on a shelf.
		customer.sold = true
		QuotaService.recordSale(price)
		saleRemote:FireAllClients(spot.part.Position + Vector3.new(0, 1.2, 0), price)
		removeSellPrompt(spot)
	end)

	local deadline = os.clock() + Config.QUEST_COUNTER_WAIT
	while not paid and spot.customer == customer and os.clock() < deadline do
		task.wait(0.1)
	end
	if spot.prompt == prompt then
		removeSellPrompt(spot)
	end
	return paid and price or nil
end

-- Frees the customer's spot for the next in line.
function CounterService.release(customer)
	local spot = customer.spot
	customer.spot = nil
	if spot and spot.customer == customer then
		spot.customer = nil
		removeSellPrompt(spot)
	end
end

return CounterService
