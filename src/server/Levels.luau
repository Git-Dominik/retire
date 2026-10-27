-- Builds the plain room that sits outside the elevator doors on each floor.
-- The elevator itself never moves: the room is swapped while the doors are shut.
-- Rooms butt straight onto the elevator's front facade, which serves as their fourth wall.

-- Floor 1 is built by a procedural generator. FoundryLevel is still being finished (it has
-- no Layout/Hub/Pit/Halls yet), so only pick it up once those modules exist and fall back
-- to the complete FactoryLevel generator until then. A broken generator must never stop
-- this module - the Elevator script requires it.
local FactoryLevel = require(script.Parent.FactoryLevel)

local function loadFoundry()
	local mod = script.Parent:FindFirstChild("FoundryLevel")
	if not mod then
		return nil
	end
	for _, child in { "Layout", "Hub", "Pit", "Halls" } do
		if not mod:FindFirstChild(child) then
			return nil
		end
	end
	local ok, loaded = pcall(require, mod)
	return ok and loaded or nil
end

local FoundryLevel = loadFoundry()

local Levels = {}

local WIDTH = 34
local DEPTH = 34
local HEIGHT = 15

local PALETTES = {
	{ wall = Color3.fromRGB(96, 74, 54), floor = Color3.fromRGB(62, 43, 31), trim = Color3.fromRGB(42, 29, 21) },
	{ wall = Color3.fromRGB(70, 78, 66), floor = Color3.fromRGB(54, 44, 36), trim = Color3.fromRGB(36, 34, 28) },
	{ wall = Color3.fromRGB(104, 66, 62), floor = Color3.fromRGB(58, 38, 32), trim = Color3.fromRGB(44, 26, 24) },
	{ wall = Color3.fromRGB(78, 72, 88), floor = Color3.fromRGB(50, 42, 40), trim = Color3.fromRGB(34, 30, 36) },
	{ wall = Color3.fromRGB(110, 96, 70), floor = Color3.fromRGB(66, 50, 34), trim = Color3.fromRGB(46, 36, 24) },
}

-- Cylinders stand upright; everything else lies flat.
-- value is what it pawns for (dollars), weight is what the cargo scale reads (kg).
local ITEMS = {
	{
		name = "Brass Key",
		value = 35,
		weight = 0.4,
		size = Vector3.new(0.3, 0.15, 1.1),
		color = Color3.fromRGB(181, 145, 72),
		material = Enum.Material.Metal,
	},
	{
		name = "Old Photograph",
		value = 20,
		weight = 0.2,
		size = Vector3.new(0.9, 0.04, 1.2),
		color = Color3.fromRGB(196, 182, 150),
		material = Enum.Material.SmoothPlastic,
	},
	{
		name = "Pocket Watch",
		value = 120,
		weight = 0.6,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.2, 0.9, 0.9),
		color = Color3.fromRGB(170, 150, 110),
		material = Enum.Material.Metal,
	},
	{
		name = "Teacup",
		value = 45,
		weight = 0.9,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.45, 0.55, 0.55),
		color = Color3.fromRGB(226, 222, 210),
		material = Enum.Material.SmoothPlastic,
	},
	{
		name = "Candle Stub",
		value = 8,
		weight = 0.5,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.7, 0.35, 0.35),
		color = Color3.fromRGB(232, 222, 196),
		material = Enum.Material.SmoothPlastic,
	},
}

local LAMP_COLOR = Color3.fromRGB(255, 196, 140)

local function part(parent, name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Rests a part on a surface, given the surface's top-centre CFrame.
function Levels.rest(p, surface)
	if p.Shape == Enum.PartType.Cylinder then
		p.CFrame = surface * CFrame.new(0, p.Size.X / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	else
		p.CFrame = surface * CFrame.new(0, p.Size.Y / 2, 0)
	end
end

-- A small four-legged table; returns its top-centre CFrame.
local function makeTable(parent, cf, size, color)
	local legH = 3.4
	part(parent, "TableTop", Vector3.new(size.X, 0.25, size.Y), cf * CFrame.new(0, legH + 0.125, 0), color, Enum.Material.Wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local offset = CFrame.new(sx * (size.X / 2 - 0.3), legH / 2, sz * (size.Y / 2 - 0.3))
			part(parent, "TableLeg", Vector3.new(0.25, legH, 0.25), cf * offset, color, Enum.Material.Wood)
		end
	end
	return cf * CFrame.new(0, legH + 0.25, 0)
end

local function makeChair(parent, cf, color)
	part(parent, "ChairSeat", Vector3.new(1.8, 0.2, 1.8), cf * CFrame.new(0, 1.9, 0), color, Enum.Material.Wood)
	part(parent, "ChairBack", Vector3.new(1.8, 2.2, 0.2), cf * CFrame.new(0, 3.1, 0.8), color, Enum.Material.Wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(parent, "ChairLeg", Vector3.new(0.2, 1.8, 0.2), cf * CFrame.new(sx * 0.75, 0.9, sz * 0.75), color, Enum.Material.Wood)
		end
	end
end

local function makeLamp(parent, cf)
	part(parent, "LampRod", Vector3.new(0.15, 1.5, 0.15), cf * CFrame.new(0, -0.75, 0), Color3.fromRGB(60, 48, 32), Enum.Material.Metal)
	local shadeCf = cf * CFrame.new(0, -1.8, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local shade = part(parent, "LampShade", Vector3.new(0.6, 1.6, 1.6), shadeCf, Color3.fromRGB(150, 110, 70), Enum.Material.Fabric)
	shade.Shape = Enum.PartType.Cylinder
	local bulb = part(parent, "LampBulb", Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(0, -2.2, 0), LAMP_COLOR, Enum.Material.Neon)
	bulb.Shape = Enum.PartType.Ball
	bulb.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = LAMP_COLOR
	light.Range = 24
	light.Brightness = 1.2
	light.Shadows = true
	light.Parent = bulb
end

-- The floor's item, resting on a surface at a random turn.
local function placeItem(room, itemDef, surface, rng)
	local item = part(room, itemDef.name, itemDef.size, CFrame.identity, itemDef.color, itemDef.material)
	if itemDef.shape then
		item.Shape = itemDef.shape
	end
	item:SetAttribute("Value", itemDef.value)
	item:SetAttribute("Weight", itemDef.weight)
	Levels.rest(item, surface * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	return item
end

-- base: floor-level CFrame at the centre of the elevator's outer door face, facing into the room.
-- Returns the room model, the item part to be carried back, and the item's name.
function Levels.build(level, base)
	local rng = Random.new(level)
	local palette = PALETTES[(level - 1) % #PALETTES + 1]
	local itemDef = ITEMS[(level - 1) % #ITEMS + 1]

	-- Floor 1 is procedurally generated; the generator picks where the item goes.
	if level == 1 then
		local generator = FoundryLevel or FactoryLevel
		local okBuild, room, surface = pcall(generator.build, base)
		if okBuild then
			return room, placeItem(room, itemDef, surface, rng), itemDef.name
		end
		warn(`[Levels] level 1 generator failed, using a plain room: {room}`)
	end

	local room = Instance.new("Model")
	room.Name = "Level" .. level

	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end

	-- Shell
	part(room, "Floor", Vector3.new(WIDTH, 1, DEPTH), at(0, -0.5, DEPTH / 2), palette.floor, Enum.Material.WoodPlanks)
	part(room, "Ceiling", Vector3.new(WIDTH, 1, DEPTH), at(0, HEIGHT + 0.5, DEPTH / 2), palette.trim)
	part(room, "WallBack", Vector3.new(WIDTH, HEIGHT, 1), at(0, HEIGHT / 2, DEPTH + 0.5), palette.wall, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		local x = side * (WIDTH / 2 + 0.5)
		part(room, "WallSide", Vector3.new(1, HEIGHT, DEPTH + 2), at(x, HEIGHT / 2, DEPTH / 2), palette.wall, Enum.Material.Fabric)
		part(room, "Baseboard", Vector3.new(0.3, 0.8, DEPTH), at(x - side * 0.65, 0.4, DEPTH / 2), palette.trim, Enum.Material.Wood)
	end
	part(room, "Baseboard", Vector3.new(WIDTH, 0.8, 0.3), at(0, 0.4, DEPTH - 0.15), palette.trim, Enum.Material.Wood)
	part(room, "Rug", Vector3.new(10, 0.05, 16), at(0, 0.025, DEPTH / 2), palette.trim:Lerp(palette.wall, 0.4), Enum.Material.Fabric)

	makeLamp(room, at(0, HEIGHT, DEPTH * 0.3))
	makeLamp(room, at(0, HEIGHT, DEPTH * 0.75))

	-- Item table goes in one of the far corners or against a side wall.
	local spots = {
		{ x = -WIDTH / 2 + 3, z = DEPTH - 3 },
		{ x = WIDTH / 2 - 3, z = DEPTH - 3 },
		{ x = -WIDTH / 2 + 3, z = DEPTH * 0.5 },
		{ x = WIDTH / 2 - 3, z = DEPTH * 0.5 },
	}
	local spot = table.remove(spots, rng:NextInteger(1, #spots))
	local top = makeTable(room, at(spot.x, 0, spot.z), Vector2.new(3, 3), palette.trim)
	makeChair(room, at(spot.x + (spot.x < 0 and 2.6 or -2.6), 0, spot.z) * CFrame.Angles(0, math.pi / 2 * (spot.x < 0 and 1 or -1), 0), palette.trim)

	-- A cabinet in one of the remaining spots so the room isn't bare.
	local other = spots[rng:NextInteger(1, #spots)]
	part(room, "Cabinet", Vector3.new(3, 6, 1.6), at(other.x, 3, other.z) * CFrame.Angles(0, math.pi / 2, 0), palette.trim, Enum.Material.Wood)

	return room, placeItem(room, itemDef, top, rng), itemDef.name
end

return Levels
