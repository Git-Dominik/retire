-- Decides, for this player only, which Stock prompts show on the shop furniture
-- (StockingService owns all the stocking state). A Stock prompt shows while you hold
-- a shop item (a Tool with the ShopItem attribute, taken off the storage racks) and
-- the furniture has a free slot (its FreeSlots attribute), and names the held item.

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
	for _, furniture in CollectionService:GetTagged("StockFurniture") do
		local prompt = furniture:FindFirstChild("StockPrompt", true)
		if prompt then
			prompt.Enabled = tool ~= nil and (furniture:GetAttribute("FreeSlots") or 0) > 0
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
	furniture.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			markDirty()
		end
	end)
	markDirty()
end
for _, furniture in CollectionService:GetTagged("StockFurniture") do
	watch(furniture)
end
CollectionService:GetInstanceAddedSignal("StockFurniture"):Connect(watch)

local function watchCharacter(character)
	character.ChildAdded:Connect(markDirty)
	character.ChildRemoved:Connect(markDirty)
	markDirty()
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	watchCharacter(player.Character)
end
