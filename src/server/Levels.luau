-- Builds the plain room that sits outside the elevator doors on each floor.
-- The elevator itself never moves: the room is swapped while the doors are shut.
-- Rooms butt straight onto the elevator's front facade, which serves as their fourth wall.
-- Each floor holds one scavenge item, a random pick from ReplicatedStorage.StockItems
-- (definitions and prices in Shared.StockItems). It carries Value and ItemId attributes.
-- Floor 2's back wall has a hole with a shop built into it: ServerStorage.WallShop, a
-- place-only template pivoted at the bottom centre of its opening on the wall's room
-- face, front on LookVector. Its OpeningSize attribute (Vector2) is the hole cut here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local StockItems = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StockItems"))

-- Floor 1 is built by the FoundryLevel generator (the big eight-room steel works). Only pick
-- it up when all its modules are there, and fall back to the older FactoryLevel generator
-- otherwise. A broken generator must never stop this module - the Elevator script requires it.
local FactoryLevel = require(script.Parent.FactoryLevel)

local function loadFoundry()
	local mod = script.Parent:FindFirstChild("FoundryLevel")
	if not mod then
		return nil
	end
	for _, child in { "Config", "Geometry", "Shell", "Props", "Generator", "TilesBasic", "TilesHalls", "TilesCore", "TilesWarehouse" } do
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

-- Each floor's item is drawn from ReplicatedStorage.StockItems, weighted by
-- value ^ -RARITY: at 1, a $12 lighter turns up about 29 times as often as a
-- $350 ring box; 0 makes every item equally likely.
local RARITY = 1

local LAMP_COLOR = Color3.fromRGB(255, 196, 140)

local WALL_SHOP_LEVEL = 2

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

local function pickItem(rng)
	local ids, total = {}, 0
	for _, id in StockItems.ids() do
		local def = StockItems.get(id)
		if StockItems.template(id) then
			local chance = (def.value or 1) ^ -RARITY
			table.insert(ids, { id = id, chance = chance })
			total += chance
		end
	end
	local roll = rng:NextNumber(0, total)
	for _, entry in ids do
		roll -= entry.chance
		if roll <= 0 then
			return StockItems.get(entry.id)
		end
	end
	return StockItems.get(ids[#ids].id)
end

-- The floor's item, resting on a surface at a random turn. It's one part (the
-- template's biggest opaque part by surface area) carrying the rest of the model as welded
-- children, because the take prompt, the held tool's Handle and the cargo lift all
-- deal in a single part. RestOffset is that part's CFrame relative to the item's
-- bottom centre, so anything re-resting it (Cargo.server) knows where it sits;
-- ShownTransparency on each piece is what to restore after hiding it.
local function placeItem(room, itemDef, surface, rng)
	local model = StockItems.create(itemDef.id)
	local rest = surface * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	model:PivotTo(rest)
	local parts, item, bestArea = {}, nil, -1
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			local s = d.Size
			-- Opaque parts win: Journal.client reads a visible item as Transparency 0.
			local area = s.X * s.Y + s.Y * s.Z + s.X * s.Z + (d.Transparency == 0 and 1e6 or 0)
			if area > bestArea then
				item, bestArea = d, area
			end
		elseif
			d:IsA("LuaSourceContainer")
			or d:IsA("Sound")
			or d:IsA("JointInstance")
			or d:IsA("WeldConstraint")
		then
			d:Destroy()
		end
	end
	-- Template pivots don't all sit exactly on the model's underside, so lift it by its
	-- real lowest corner.
	local lowest = math.huge
	for _, p in parts do
		local h = p.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = p.CFrame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
					lowest = math.min(lowest, rest:PointToObjectSpace(corner).Y)
				end
			end
		end
	end
	model:PivotTo(model:GetPivot() + rest.UpVector * -lowest)
	item:SetAttribute("RestOffset", rest:ToObjectSpace(item.CFrame))
	for _, p in parts do
		p:SetAttribute("ShownTransparency", p.Transparency)
		p.CanCollide = false
		if p ~= item then
			p.Anchored = false
			p.Massless = true
			p.Parent = item
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = item
			weld.Part1 = p
			weld.Parent = p
		end
	end
	item.Name = itemDef.name
	item.Anchored = true
	item:SetAttribute("Value", itemDef.value)
	item:SetAttribute("ItemId", itemDef.id)
	item.Parent = room
	model:Destroy()
	return item
end

-- A loose copy of an item resting on surface, for the dev menu's spawner.
function Levels.placeItem(parent, id, surface)
	local itemDef = StockItems.get(id)
	return itemDef and placeItem(parent, itemDef, surface, Random.new())
end

-- base: floor-level CFrame at the centre of the elevator's outer door face, facing into the room.
-- Returns the room model, the item part to be carried back, and the item's name.
function Levels.build(level, base)
	local rng = Random.new(level)
	local palette = PALETTES[(level - 1) % #PALETTES + 1]
	-- The room's layout is fixed per floor, but the item is a fresh draw every visit.
	local itemDef = pickItem(Random.new())

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
	local wallShop = level == WALL_SHOP_LEVEL and ServerStorage:FindFirstChild("WallShop")
	local opening = wallShop and wallShop:GetAttribute("OpeningSize")
	if opening then
		-- The back wall goes up around the shop's hole: a piece either side and one above.
		local sideW = (WIDTH - opening.X) / 2
		for _, side in { -1, 1 } do
			local x = side * (opening.X / 2 + sideW / 2)
			part(room, "WallBack", Vector3.new(sideW, HEIGHT, 1), at(x, HEIGHT / 2, DEPTH + 0.5), palette.wall, Enum.Material.Fabric)
		end
		local overH = HEIGHT - opening.Y
		part(room, "WallBack", Vector3.new(opening.X, overH, 1), at(0, opening.Y + overH / 2, DEPTH + 0.5), palette.wall, Enum.Material.Fabric)
		local shop = wallShop:Clone()
		-- The room runs along base's +Z, so the template's front (-Z) already faces the doors.
		shop:PivotTo(at(0, 0, DEPTH))
		shop.Parent = room
	else
		part(room, "WallBack", Vector3.new(WIDTH, HEIGHT, 1), at(0, HEIGHT / 2, DEPTH + 0.5), palette.wall, Enum.Material.Fabric)
	end
	for _, side in { -1, 1 } do
		local x = side * (WIDTH / 2 + 0.5)
		part(room, "WallSide", Vector3.new(1, HEIGHT, DEPTH + 2), at(x, HEIGHT / 2, DEPTH / 2), palette.wall, Enum.Material.Fabric)
		part(room, "Baseboard", Vector3.new(0.3, 0.8, DEPTH), at(x - side * 0.65, 0.4, DEPTH / 2), palette.trim, Enum.Material.Wood)
	end
	if opening then
		local boardW = (WIDTH - opening.X) / 2
		for _, side in { -1, 1 } do
			local x = side * (opening.X / 2 + boardW / 2)
			part(room, "Baseboard", Vector3.new(boardW, 0.8, 0.3), at(x, 0.4, DEPTH - 0.15), palette.trim, Enum.Material.Wood)
		end
	else
		part(room, "Baseboard", Vector3.new(WIDTH, 0.8, 0.3), at(0, 0.4, DEPTH - 0.15), palette.trim, Enum.Material.Wood)
	end
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
