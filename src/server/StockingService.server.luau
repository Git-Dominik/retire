-- Shop stocking. Items sent up by the cargo lift sit on the storage racks in the
-- elevator room (StockRacks). Players take one off as a held Tool and stock it onto
-- the display cases, shelves and cupboards out in the shop with the furniture's
-- Stock prompt.
--
-- The server owns every bit of state: which slots are taken, the stocked item
-- models, and the rack items. A taken item leaves its rack; if its tool is lost
-- without being stocked (dying, leaving, respawning) the item goes back on a rack.
-- StockingClient only decides which Stock prompts this player sees.
--
-- Dropping: the DropItem remote (Camera.client fires it on Backspace) drops the
-- held shop item or scavenged item on the floor in front of the player. It sets the
-- tool's DropAt attribute (a floor CFrame) and destroys the tool; whoever built the
-- tool (here, or Elevator.server for scavenged items) puts the item down there.
-- A dropped shop item is tagged DroppedItem and can be taken again.
--
-- Placed in Studio, not built here:
--   StockFurniture  tag on each furniture model
--   StockSlot       the invisible slot parts under each furniture model, with
--                   Occupied, SlotIndex and SlotSize attributes
-- Relies on: RackItem tag and ItemId attribute on rack items (StockRacks, Levels).
-- Sets: FreeSlots on furniture; ShopItem and ItemId on the held tool.
-- Remote: ReplicatedStorage.DropItem (client to server, no arguments).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("StockingConfig"))
local StockItems = require(Shared:WaitForChild("StockItems"))
local StockRacks = require(script.Parent:WaitForChild("StockRacks"))

local store = workspace:WaitForChild("Grocery Store")

local dropRemote = Instance.new("RemoteEvent")
dropRemote.Name = "DropItem"
dropRemote.Parent = ReplicatedStorage

-- ================= HELPERS =================
local function playSound(parent, sound)
	local s = Instance.new("Sound")
	s.SoundId = sound.id
	s.Volume = sound.volume
	s.PlaybackSpeed = sound.speed
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = 40
	s.Parent = parent
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

-- ================= FURNITURE =================
-- The furniture's slots in fill order (SlotIndex runs left to right, bottom to top).
local function slotsOf(furniture)
	local slots = {}
	for _, child in furniture:GetChildren() do
		if CollectionService:HasTag(child, "StockSlot") then
			table.insert(slots, child)
		end
	end
	table.sort(slots, function(a, b)
		return (a:GetAttribute("SlotIndex") or 0) < (b:GetAttribute("SlotIndex") or 0)
	end)
	return slots
end

local function nextFreeSlot(furniture)
	for _, slot in slotsOf(furniture) do
		if not slot:GetAttribute("Occupied") then
			return slot
		end
	end
	return nil
end

-- Keeps the FreeSlots attribute current; clients hide the prompt when it hits 0.
local function updateFreeSlots(furniture)
	local free = 0
	for _, slot in slotsOf(furniture) do
		if not slot:GetAttribute("Occupied") then
			free += 1
		end
	end
	furniture:SetAttribute("FreeSlots", free)
end

-- The furniture's main part, which carries its Stock prompt: the one with the most
-- surface (a shelf unit's back panel, a case's cabinet), so the prompt sits at its
-- middle rather than down on a kick plate.
local function mainPartOf(furniture)
	local best, bestArea
	for _, d in furniture:GetDescendants() do
		if d:IsA("BasePart") and not CollectionService:HasTag(d, "StockSlot") then
			local s = d.Size
			local area = s.X * s.Y + s.Y * s.Z + s.X * s.Z
			if not best or area > bestArea then
				best, bestArea = d, area
			end
		end
	end
	return best
end

-- ================= TAKING =================
-- The item comes off the rack into the player's hands as a Tool whose Handle is a copy
-- of it. The original is kept off-world until the item is stocked or comes back.
local function restOn(p, surface)
	local offset = p:GetAttribute("RestOffset")
	p.CFrame = surface * (offset or CFrame.new(0, p.Size.Y / 2, 0))
end

local function take(player, item)
	local root = rootOf(player)
	local takeable = CollectionService:HasTag(item, "RackItem")
		or CollectionService:HasTag(item, "DroppedItem")
	if not root or not takeable then
		return
	end
	if (root.Position - item.Position).Magnitude > Config.MAX_TAKE_DISTANCE then
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = item.Name
	tool.CanBeDropped = false
	tool:SetAttribute("ShopItem", true)
	tool:SetAttribute("ItemId", item:GetAttribute("ItemId"))
	local handle = item:Clone()
	handle.Name = "Handle"
	CollectionService:RemoveTag(handle, "RackItem")
	CollectionService:RemoveTag(handle, "DroppedItem")
	local prompt = handle:FindFirstChild("RackTakePrompt")
	if prompt then
		prompt:Destroy()
	end
	handle.Anchored = false
	handle.Massless = true
	handle.Parent = tool

	CollectionService:RemoveTag(item, "DroppedItem")
	item.Parent = nil
	playSound(root, Config.SOUNDS.take)

	-- Anywhere but the backpack or the hands means it was lost: back to the racks.
	local character = root.Parent
	local connection
	connection = tool.AncestryChanged:Connect(function()
		if tool.Parent == player.Backpack or tool.Parent == player.Character then
			return
		end
		connection:Disconnect()
		local dropAt = tool:GetAttribute("DropAt")
		if dropAt and not tool:GetAttribute("Stocked") and store.Parent == workspace then
			-- Dropped items join the store so they move and park with it.
			restOn(item, dropAt)
			item.Anchored = true
			item.Parent = store
			CollectionService:AddTag(item, "DroppedItem")
		elseif tool:GetAttribute("Stocked") or not StockRacks.place(item) then
			-- Stocked, or every rack is full and there's nowhere to put it back.
			item:Destroy()
		end
	end)
	tool.Parent = player.Backpack
	character:FindFirstChildOfClass("Humanoid"):EquipTool(tool)
end

local function setupRackItem(item)
	if not item:IsA("BasePart") or item:FindFirstChild("RackTakePrompt") then
		return
	end
	local def = StockItems.get(item:GetAttribute("ItemId"))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RackTakePrompt"
	prompt.ActionText = "Take"
	prompt.ObjectText = def and def.name or item.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = Config.TAKE_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = item
	prompt.Triggered:Connect(function(player)
		take(player, item)
	end)
end

-- ================= STOCKING =================
local function stock(player, furniture, prompt)
	local root = rootOf(player)
	local tool = root and root.Parent:FindFirstChildOfClass("Tool")
	if not tool or not tool:GetAttribute("ShopItem") or tool:GetAttribute("Stocked") then
		return
	end
	if (root.Position - prompt.Parent.Position).Magnitude > Config.MAX_STOCK_DISTANCE then
		return
	end
	local slot = nextFreeSlot(furniture)
	local itemId = tool:GetAttribute("ItemId")
	local model = slot and StockItems.create(itemId, slot:GetAttribute("SlotSize"))
	if not model then
		updateFreeSlots(furniture)
		return
	end
	model.Name = "StockedItem"
	model:SetAttribute("ItemId", itemId)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	model:PivotTo(StockItems.restingCFrame(itemId, slot))
	model.Parent = slot
	slot:SetAttribute("Occupied", true)
	updateFreeSlots(furniture)
	playSound(slot, Config.SOUNDS.place)

	tool:SetAttribute("Stocked", true)
	tool:Destroy()
end

-- ================= SETUP =================
local function setupFurniture(furniture)
	if not furniture:IsA("Model") or furniture:FindFirstChild("StockPrompt", true) then
		return
	end
	local main = mainPartOf(furniture)
	if not main then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StockPrompt"
	prompt.ActionText = "Stock"
	prompt.ObjectText = furniture.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.STOCK_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	-- Shown by StockingClient only while you hold a shop item.
	prompt.Enabled = false
	prompt.Parent = main

	for _, slot in slotsOf(furniture) do
		if slot:GetAttribute("Occupied") == nil then
			slot:SetAttribute("Occupied", false)
		end
	end
	updateFreeSlots(furniture)

	-- Slots added later count straight away.
	furniture.ChildAdded:Connect(function(child)
		if CollectionService:HasTag(child, "StockSlot") then
			updateFreeSlots(furniture)
		end
	end)

	prompt.Triggered:Connect(function(player)
		if furniture:IsDescendantOf(store) then
			stock(player, furniture, prompt)
		end
	end)
end

for _, furniture in CollectionService:GetTagged("StockFurniture") do
	setupFurniture(furniture)
end
CollectionService:GetInstanceAddedSignal("StockFurniture"):Connect(setupFurniture)

for _, tag in { "RackItem", "DroppedItem" } do
	for _, item in CollectionService:GetTagged(tag) do
		setupRackItem(item)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(setupRackItem)
end

-- ================= DROPPING =================
-- The floor a couple of studs in front of the player, with the item facing them.
local function dropSurface(character, root)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	local ahead = root.Position + root.CFrame.LookVector * Config.DROP_DISTANCE
	local hit = workspace:Raycast(ahead, Vector3.new(0, -10, 0), params)
	if not hit then
		return nil
	end
	local facing = -root.CFrame.LookVector * Vector3.new(1, 0, 1)
	return CFrame.lookAt(hit.Position, hit.Position + facing)
end

dropRemote.OnServerEvent:Connect(function(player)
	local root = rootOf(player)
	local tool = root and root.Parent:FindFirstChildOfClass("Tool")
	if not tool or not (tool:GetAttribute("ShopItem") or tool:GetAttribute("ScavengedLevel")) then
		return
	end
	local surface = dropSurface(root.Parent, root)
	if not surface then
		return
	end
	tool:SetAttribute("DropAt", surface)
	playSound(root, Config.SOUNDS.place)
	tool:Destroy()
end)
