-- Decides, for this player only, which Stock prompts show on the shop furniture
-- (StockingService owns all the stocking state). A Stock prompt shows while you hold
-- a shop item (a Tool with the ShopItem attribute, taken off the storage racks) and
-- the furniture has a free slot the item fits (StockItems.fits: large items need large
-- slots), and names the held item.
-- A slot's ShelfTakePrompt shows while the slot is Occupied and your hands are empty, and
-- names the item on it. A request client's QuestSellPrompt on the counter (CounterService)
-- shows only while you hold the item it asks for (its ItemId attribute).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StockItems = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StockItems"))

local player = Players.LocalPlayer

local function heldItem()
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	return tool and tool:GetAttribute("ShopItem") and tool or nil
end

local function refreshPrompts()
	local tool = heldItem()
	local def = tool and StockItems.get(tool:GetAttribute("ItemId"))
	local handsFull = player.Character and player.Character:FindFirstChildOfClass("Tool") ~= nil
	for _, slot in CollectionService:GetTagged("StockSlot") do
		local take = slot:FindFirstChild("ShelfTakePrompt", true)
		if take then
			local model = slot:FindFirstChild("StockedItem")
			local item = model and StockItems.get(model:GetAttribute("ItemId"))
			take.Enabled = not handsFull and slot:GetAttribute("Occupied") == true and model ~= nil
			take.ObjectText = item and item.name or take.ObjectText
		end
	end
	for _, spot in CollectionService:GetTagged("CounterSpot") do
		local sell = spot:FindFirstChild("QuestSellPrompt")
		if sell then
			sell.Enabled = tool ~= nil
				and tool:GetAttribute("ItemId") == sell:GetAttribute("ItemId")
		end
	end
	for _, furniture in CollectionService:GetTagged("StockFurniture") do
		local prompt = furniture:FindFirstChild("StockPrompt", true)
		if prompt then
			local room = false
			if tool then
				for _, slot in furniture:GetChildren() do
					if
						CollectionService:HasTag(slot, "StockSlot")
						and not slot:GetAttribute("Occupied")
						and StockItems.fits(
							tool:GetAttribute("ItemId"),
							slot:GetAttribute("SlotSize")
						)
					then
						room = true
					end
				end
			end
			prompt.Enabled = room
			if tool then
				prompt.ObjectText = def and def.name or tool.Name
			end
		end
	end
end

-- Refreshes at most once a frame, whenever anything it depends on changes.
local dirty = true
local function markDirty()
	dirty = true
end
RunService.Heartbeat:Connect(function()
	if dirty then
		dirty = false
		refreshPrompts()
	end
end)

local function watch(furniture)
	furniture.AttributeChanged:Connect(markDirty)
	-- Prompts, stocked items arriving and slots filling or emptying.
	furniture.DescendantAdded:Connect(markDirty)
	furniture.DescendantRemoving:Connect(markDirty)
	for _, d in furniture:GetDescendants() do
		if CollectionService:HasTag(d, "StockSlot") then
			d.AttributeChanged:Connect(markDirty)
		end
	end
	markDirty()
end
for _, furniture in CollectionService:GetTagged("StockFurniture") do
	watch(furniture)
end
CollectionService:GetInstanceAddedSignal("StockFurniture"):Connect(watch)

-- A request client's Sell prompt coming and going on a counter spot.
local function watchSpot(spot)
	spot.ChildAdded:Connect(markDirty)
	markDirty()
end
for _, spot in CollectionService:GetTagged("CounterSpot") do
	watchSpot(spot)
end
CollectionService:GetInstanceAddedSignal("CounterSpot"):Connect(watchSpot)

local function watchCharacter(character)
	character.ChildAdded:Connect(markDirty)
	character.ChildRemoved:Connect(markDirty)
	markDirty()
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	watchCharacter(player.Character)
end
