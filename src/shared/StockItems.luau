-- Every item the floors spawn and the shop can stock. Each entry's model lives in
-- ReplicatedStorage.StockItems (pivot at the bottom centre, front facing along
-- the pivot's LookVector). A slot's front faces out of its furniture, so the
-- item ends up at slot.CFrame * rotation.
--
-- Items come in two sizes (the `size` field): "Small" (the default, up to 1 x 1 stud) and
-- "Large" (up to 2 x 2), which only go in large slots (fits). Within that, anything
-- bigger than its slot is scaled down to fit. Copies swap
-- Glass for see-through plastic (see create), so they still show inside display cases.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- value is what the item pawns for (dollars). Floors also spawn these, cheap ones
-- far more often than dear ones (see Levels). basePrice is what it sells for in the
-- shop: customers pay it at the counter (CounterService) and shoplifters cost it.
-- floorIds lists the floors the item can be found on (names in ShopConfig.FLOOR_NAMES).
-- QuestService only asks for items that have some, and the journal's Requests page shows
-- them. Levels doesn't read them yet: any floor can still spawn any item.
-- TODO: the floorIds below are placeholder guesses (cheap items shallow, dear ones deep);
-- set them to where each item really turns up.
local ITEMS = {
	Camera = {
		name = "Camera",
		model = "Camera",
		value = 140,
		basePrice = 210,
		floorIds = { 2, 3 },
	},
	PocketWatch = {
		name = "Pocket watch",
		model = "PocketWatch",
		value = 180,
		basePrice = 270,
		rotation = CFrame.Angles(0, math.rad(25), 0),
		floorIds = { 3, 4 },
	},
	MusicBox = {
		name = "Music box",
		model = "MusicBox",
		value = 90,
		basePrice = 135,
		floorIds = { 1, 2 },
	},
	Radio = {
		name = "Radio",
		model = "Radio",
		value = 220,
		basePrice = 330,
		floorIds = { 3, 4, 5 },
	},
	Clock = {
		name = "Mantel clock",
		model = "Clock",
		value = 200,
		basePrice = 300,
		floorIds = { 3, 4 },
	},
	Vase = { name = "Vase", model = "Vase", value = 45, basePrice = 70, floorIds = { 1, 2 } },
	Bottle = { name = "Bottle", model = "Bottle", value = 15, basePrice = 25, floorIds = { 1 } },
	Candlestick = {
		name = "Candlestick",
		model = "Candlestick",
		value = 25,
		basePrice = 40,
		floorIds = { 1, 2 },
	},
	Figurine = {
		name = "Figurine",
		model = "Figurine",
		value = 30,
		basePrice = 45,
		floorIds = { 1, 2 },
	},
	Compass = {
		name = "Compass",
		model = "Compass",
		value = 60,
		basePrice = 90,
		rotation = CFrame.Angles(0, math.rad(-15), 0),
		floorIds = { 2 },
	},
	RingBox = {
		name = "Ring box",
		model = "RingBox",
		value = 350,
		basePrice = 525,
		floorIds = { 4, 5 },
	},
	Wristwatch = {
		name = "Wristwatch",
		model = "Wristwatch",
		value = 160,
		basePrice = 240,
		rotation = CFrame.Angles(0, math.rad(90), 0),
		floorIds = { 2, 3 },
	},
	Lighter = { name = "Lighter", model = "Lighter", value = 12, basePrice = 20, floorIds = { 1 } },
	Pendant = {
		name = "Pendant",
		model = "Pendant",
		value = 80,
		basePrice = 120,
		rotation = CFrame.Angles(0, math.rad(-20), 0),
		floorIds = { 2, 3 },
	},
	Reimu = {
		name = "Reimu fumo",
		model = "Reimu",
		value = 120,
		basePrice = 180,
		floorIds = { 2, 3 },
	},

	-- ================= LARGE =================
	-- Up to 2 x 2 studs across. They only fit large slots (see fits), and on the floors they
	-- only spawn on LargeItemSpawn points (Levels). TODO: placeholder floorIds, as above.
	Gramophone = {
		name = "Gramophone",
		model = "Gramophone",
		size = "Large",
		value = 260,
		basePrice = 390,
		floorIds = { 2, 3 },
	},
	Typewriter = {
		name = "Typewriter",
		model = "Typewriter",
		size = "Large",
		value = 190,
		basePrice = 285,
		floorIds = { 1, 2 },
	},
	Suitcase = {
		name = "Suitcase",
		model = "Suitcase",
		size = "Large",
		value = 110,
		basePrice = 165,
		floorIds = { 1, 2, 3 },
	},
}

local StockItems = {}

for id, item in ITEMS do
	item.id = id
	item.rotation = item.rotation or CFrame.identity
	item.basePrice = item.basePrice or item.value
	item.floorIds = item.floorIds or {}
	item.size = item.size or "Small"
end

-- A slot counts as large when its space is at least this many studs across both ways.
-- Regular slots are under 1 x 1; the Display Stands and the storage LargeShelfs are bigger.
local LARGE_SLOT = 1.5

-- Whether the item may go in a slot of this size (its SlotSize attribute): small items
-- fit anywhere, large ones only in large slots.
function StockItems.fits(id, slotSize)
	local item = ITEMS[id]
	if not item then
		return false
	end
	if item.size ~= "Large" then
		return true
	end
	return typeof(slotSize) == "Vector3" and slotSize.X >= LARGE_SLOT and slotSize.Z >= LARGE_SLOT
end

-- The definition for an ItemId, or nil if there's no such item.
function StockItems.get(id)
	return ITEMS[id]
end

-- Every ItemId.
function StockItems.ids()
	local ids = {}
	for id in ITEMS do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
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
	-- Roblox doesn't draw Glass behind Glass, so a glass bottle in a display case vanished.
	-- Glass pieces become see-through plastic with a little shine instead.
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Glass then
			d.Material = Enum.Material.SmoothPlastic
			d.Reflectance = math.max(d.Reflectance, 0.15)
		end
	end
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
