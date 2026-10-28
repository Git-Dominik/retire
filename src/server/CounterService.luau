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

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("ShopConfig"))
local StockItems = require(Shared:WaitForChild("StockItems"))
local CustomerUtil = require(script.Parent:WaitForChild("CustomerUtil"))
local QuotaService = require(script.Parent:WaitForChild("QuotaService"))

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

-- Frees the customer's spot for the next in line.
function CounterService.release(customer)
	local spot = customer.spot
	customer.spot = nil
	if spot and spot.customer == customer then
		spot.customer = nil
		spot.part:SetAttribute("PriceText", nil)
	end
end

return CounterService
