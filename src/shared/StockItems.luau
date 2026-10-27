-- Everything a stock box can hold. Each entry's model lives in
-- ReplicatedStorage.StockItems (pivot at the bottom centre, front facing along
-- the pivot's LookVector). A slot's front faces out of its furniture, so the
-- item ends up at slot.CFrame * rotation.
--
-- Any item fits any slot: anything bigger than the slot is scaled down to fit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ITEMS = {
	Camera = { name = "Camera", model = "Camera" },
	PocketWatch = {
		name = "Pocket watch",
		model = "PocketWatch",
		rotation = CFrame.Angles(0, math.rad(25), 0),
	},
	MusicBox = { name = "Music box", model = "MusicBox" },
	Radio = { name = "Radio", model = "Radio" },
	Clock = { name = "Mantel clock", model = "Clock" },
	Vase = { name = "Vase", model = "Vase" },
	Bottle = { name = "Bottle", model = "Bottle" },
	Candlestick = { name = "Candlestick", model = "Candlestick" },
	Figurine = { name = "Figurine", model = "Figurine" },
	Compass = { name = "Compass", model = "Compass", rotation = CFrame.Angles(0, math.rad(-15), 0) },
	RingBox = { name = "Ring box", model = "RingBox" },
	Wristwatch = {
		name = "Wristwatch",
		model = "Wristwatch",
		rotation = CFrame.Angles(0, math.rad(90), 0),
	},
	Lighter = { name = "Lighter", model = "Lighter" },
	Pendant = { name = "Pendant", model = "Pendant", rotation = CFrame.Angles(0, math.rad(-20), 0) },
}

local StockItems = {}

for id, item in ITEMS do
	item.id = id
	item.rotation = item.rotation or CFrame.identity
end

-- The definition for an ItemId, or nil if there's no such item.
function StockItems.get(id)
	return ITEMS[id]
end

-- The template model for an item (don't move it; clone it).
function StockItems.template(id)
	local item = ITEMS[id]
	local folder = ReplicatedStorage:WaitForChild("StockItems")
	return item and folder:WaitForChild(item.model, 5)
end

-- A fresh copy of the item, shrunk if needed so it fits a slot of the given
-- size (width, height, depth, in the slot's own frame).
function StockItems.create(id, slotSize)
	local template = StockItems.template(id)
	if not template then
		return nil
	end
	local model = template:Clone()
	if slotSize then
		local item = ITEMS[id]
		local extents = template:GetAttribute("Extents") or template:GetExtentsSize()
		-- The item's own footprint, turned by its rotation offset.
		local turned = item.rotation:VectorToWorldSpace(extents)
		local width, depth = math.abs(turned.X), math.abs(turned.Z)
		local scale = math.min(1, slotSize.X / width, slotSize.Y / extents.Y, slotSize.Z / depth)
		if scale < 0.999 then
			model:ScaleTo(scale)
		end
	end
	return model
end

-- Where an item rests in a slot.
function StockItems.restingCFrame(id, slot)
	local item = ITEMS[id]
	local bottom = slot.CFrame * CFrame.new(0, -slot.Size.Y / 2, 0)
	return bottom * (item and item.rotation or CFrame.identity)
end

return StockItems
