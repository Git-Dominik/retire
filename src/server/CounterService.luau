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
-- Request clients (QuestService) are the one exception to paying by themselves. They come
-- straight to the counter and ask for the item there; a player fetches it (from the racks,
-- or off the shop furniture with its Take prompt) and hands it over. questCheckout puts a
-- "Sell" prompt (QuestSellPrompt, hold QUEST_SELL_HOLD, ItemId attribute) on their spot
-- for up to QUEST_COUNTER_WAIT; StockingClient shows it only to a player holding that
-- item. The server checks the client still holds the spot, the player is holding the
-- requested item and is within QUEST_SELL_MAX_DISTANCE, then takes the tool (Sold), sets
-- the item on the counter, completes the request and pays the fixed RewardPrice, all
-- without yielding, so the reward can only be paid once. The prompt goes with the spot
-- when the client is released.

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

-- The requested item's tool, if the player can hand it over on this spot now: the client
-- still holds the spot, and the player is alive, close enough and holding that item.
local function handedItem(player, customer, spot, quest)
	if spot.customer ~= customer or customer.gone or customer.sentHome then
		return nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not root or not humanoid or humanoid.Health <= 0 or not tool then
		return nil
	end
	if
		not tool:GetAttribute("ShopItem")
		or tool:GetAttribute("Stocked")
		or tool:GetAttribute("Sold")
	then
		return nil
	end
	if tool:GetAttribute("ItemId") ~= quest.ItemId then
		return nil
	end
	if (root.Position - spot.part.Position).Magnitude > Config.QUEST_SELL_MAX_DISTANCE then
		return nil
	end
	return tool
end

-- A request client's sale at the fixed RewardPrice. Yields until a player hands over the
-- requested item (returning the price and the item, now lying on the spot) or until
-- QUEST_COUNTER_WAIT runs out or they lose the spot (returning nil).
function CounterService.questCheckout(customer, spot, quest)
	local item = StockItems.get(quest.ItemId)
	local price = quest.RewardPrice
	spot.part:SetAttribute("PriceText", `${price}`)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QuestSellPrompt"
	prompt.ActionText = "Sell"
	prompt.ObjectText = `{item and item.name or quest.ItemId} for ${price}`
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Config.QUEST_SELL_HOLD
	prompt.MaxActivationDistance = Config.QUEST_SELL_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = true
	-- StockingClient enables it for whoever holds this item.
	prompt.Enabled = false
	prompt:SetAttribute("ItemId", quest.ItemId)
	prompt.Parent = spot.part
	spot.prompt = prompt

	local paid, sold = false, nil
	prompt.Triggered:Connect(function(player)
		local tool = not paid and handedItem(player, customer, spot, quest)
		-- Nothing below yields, so a second trigger always sees paid.
		if not tool or not QuestService.complete(quest) then
			return
		end
		paid = true
		tool:SetAttribute("Sold", true)
		tool:Destroy()
		sold = StockItems.create(quest.ItemId)
		if sold then
			for _, d in sold:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = false
				end
			end
			sold:PivotTo(StockItems.restingCFrame(quest.ItemId, spot.part))
			sold.Parent = CustomerUtil.folder
			CustomerUtil.setGroup(sold, "Customers")
		end
		-- Set here, not in the client's thread: if they're sent home this instant, the sold
		-- item is still destroyed rather than put back on a shelf.
		customer.sold = true
		customer.carried = sold and { model = sold, itemId = quest.ItemId } or nil
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
