-- The storage racks in the store's elevator room, as somewhere to keep loose items.
-- Cargo.server puts each delivered item on the first free spot; StockingService lets
-- players take them off again and puts back any that were dropped (death, leaving).
--
-- Each shelf board of every rack under the store's StorageRacks folder holds
-- SPOTS_PER_SHELF items side by side, facing out. This module owns which spot each
-- item is on; a spot frees itself as soon as its item leaves the rack. Items placed
-- here are tagged RackItem.
--
-- Items are single parts with the rest of their model welded on, carrying a
-- RestOffset from their bottom centre (see Levels).

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local SPOTS_PER_SHELF = 4
local YAW_JITTER = 12 -- degrees either way, so a full rack doesn't look machine-placed

local StockRacks = {}

local occupied = {} -- [shelf part] = { [spot index] = item }

local function findStore()
	return workspace:FindFirstChild("Grocery Store")
		or ServerStorage:FindFirstChild("Grocery Store")
end

-- Every shelf board, rack by rack (by name), top shelf first. The thin lips along
-- the boards' front edges are also called Shelf, so boards are told apart by height.
local function shelves()
	local store = findStore()
	local folder = store and store:FindFirstChild("StorageRacks", true)
	if not folder then
		return {}
	end
	local racks = folder:GetChildren()
	table.sort(racks, function(a, b)
		return a.Name < b.Name
	end)
	local list = {}
	for _, rack in racks do
		local boards = {}
		for _, part in rack:GetChildren() do
			if part:IsA("BasePart") and part.Name == "Shelf" and part.Size.Y > 0.08 then
				table.insert(boards, part)
			end
		end
		table.sort(boards, function(a, b)
			return a.Position.Y > b.Position.Y
		end)
		for _, board in boards do
			table.insert(list, { rack = rack, shelf = board })
		end
	end
	return list
end

local function restOn(p, surface)
	local offset = p:GetAttribute("RestOffset")
	if offset then
		p.CFrame = surface * offset
	else
		p.CFrame = surface * CFrame.new(0, p.Size.Y / 2, 0)
	end
end

-- Puts the item on the first free spot. Returns false (and leaves it alone) when
-- every rack is full.
function StockRacks.place(item)
	for _, entry in shelves() do
		local shelf, rack = entry.shelf, entry.rack
		local spots = occupied[shelf] or {}
		occupied[shelf] = spots
		for i = 1, SPOTS_PER_SHELF do
			if not spots[i] then
				-- Spots run along the board's long side; items face out the rack's front.
				local x = (i - (SPOTS_PER_SHELF + 1) / 2) * shelf.Size.X / SPOTS_PER_SHELF
				local top = shelf.CFrame * Vector3.new(x, shelf.Size.Y / 2, 0)
				local front = rack:GetPivot().LookVector
				local yaw = math.rad(math.random(-YAW_JITTER, YAW_JITTER))
				restOn(item, CFrame.lookAt(top, top + front) * CFrame.Angles(0, yaw, 0))
				item.Anchored = true
				item.CanCollide = false
				item.Parent = rack
				CollectionService:AddTag(item, "RackItem")
				spots[i] = item
				local connection
				connection = item.AncestryChanged:Connect(function()
					if item.Parent ~= rack then
						connection:Disconnect()
						CollectionService:RemoveTag(item, "RackItem")
						if spots[i] == item then
							spots[i] = nil
						end
					end
				end)
				return true
			end
		end
	end
	return false
end

return StockRacks
