-- Builds the plain room that sits outside the elevator doors on each floor.
-- The elevator itself never moves: the room is swapped while the doors are shut.
-- Rooms butt straight onto the elevator's front facade, which serves as their fourth wall.

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
local ITEMS = {
	{
		name = "Brass Key",
		size = Vector3.new(0.3, 0.15, 1.1),
		color = Color3.fromRGB(181, 145, 72),
		material = Enum.Material.Metal,
	},
	{
		name = "Old Photograph",
		size = Vector3.new(0.9, 0.04, 1.2),
		color = Color3.fromRGB(196, 182, 150),
		material = Enum.Material.SmoothPlastic,
	},
	{
		name = "Pocket Watch",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.2, 0.9, 0.9),
		color = Color3.fromRGB(170, 150, 110),
		material = Enum.Material.Metal,
	},
	{
		name = "Teacup",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.45, 0.55, 0.55),
		color = Color3.fromRGB(226, 222, 210),
		material = Enum.Material.SmoothPlastic,
	},
	{
		name = "Candle Stub",
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
	Levels.rest(item, surface * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	return item
end

-- ================= FLOOR 1: LIBRARY HALL =================
-- A long, dim library hallway: bookcases down the left, sconces and paintings
-- on the right, a carpet runner under a wooden barrel vault, and a door left
-- ajar at the far end between two potted plants.
local LIB_WIDTH = 24
local LIB_DEPTH = 64
local LIB_WALL_H = 11
local LIB_VAULT_RISE = 4.5

local LIB = {
	darkWood = Color3.fromRGB(56, 30, 20),
	wood = Color3.fromRGB(92, 50, 32),
	wallpaper = Color3.fromRGB(86, 40, 28),
	carpet = Color3.fromRGB(54, 26, 22),
	floor = Color3.fromRGB(70, 38, 26),
	lamp = Color3.fromRGB(255, 186, 128),
}
local BOOK_COLORS = {
	Color3.fromRGB(112, 34, 28),
	Color3.fromRGB(58, 74, 44),
	Color3.fromRGB(122, 74, 36),
	Color3.fromRGB(150, 112, 52),
	Color3.fromRGB(44, 48, 70),
	Color3.fromRGB(86, 40, 54),
	Color3.fromRGB(176, 140, 104),
}

-- One bookcase against a side wall, its back at xBack and its open front facing
-- `facing` (+1 or -1 along x), running along the hall from z0 for `length` studs.
-- Shelves are filled with books of random sizes.
local function makeBookcase(parent, hallAt, rng, xBack, facing, z0, length)
	local depth, height, shelves = 1.8, 9, 4
	-- x here is measured out from the back of the case toward the hall.
	local function at(x, y, z)
		return hallAt(xBack + facing * x, y, z)
	end
	local xFront = depth
	local zMid = z0 + length / 2
	local wood, dark = LIB.wood, LIB.darkWood
	part(parent, "CaseBack", Vector3.new(0.2, height, length), at(0.1, height / 2, zMid), dark, Enum.Material.Wood)
	for _, z in { z0 + 0.15, z0 + length - 0.15 } do
		part(parent, "CaseSide", Vector3.new(depth, height, 0.3), at(depth / 2, height / 2, z), wood, Enum.Material.Wood)
	end
	part(parent, "CaseBase", Vector3.new(depth + 0.15, 0.7, length), at(depth / 2 + 0.07, 0.35, zMid), dark, Enum.Material.Wood)
	part(parent, "CaseTop", Vector3.new(depth + 0.3, 0.45, length + 0.3), at(depth / 2 + 0.15, height + 0.22, zMid), wood, Enum.Material.Wood)
	-- A raised crest along the top, standing in for the carved arch.
	part(parent, "CaseCrest", Vector3.new(0.35, 1.1, length * 0.55), at(depth - 0.2, height + 0.95, zMid), wood, Enum.Material.Wood)

	local shelfGap = (height - 1.2) / shelves
	for s = 0, shelves - 1 do
		local y = 0.7 + s * shelfGap
		part(parent, "Shelf", Vector3.new(depth - 0.2, 0.14, length - 0.6), at(depth / 2, y, zMid), wood, Enum.Material.Wood)
		-- Books, packed left to right, occasionally leaving a gap or a short stack.
		local z = z0 + 0.4
		while z < z0 + length - 0.7 do
			if rng:NextNumber() < 0.06 then
				z += rng:NextNumber(0.4, 0.9)
				continue
			end
			local thick = rng:NextNumber(0.22, 0.42)
			local tall = math.min(rng:NextNumber(0.85, 1.35), shelfGap - 0.25)
			local deep = rng:NextNumber(1.1, 1.45)
			local color = BOOK_COLORS[rng:NextInteger(1, #BOOK_COLORS)]
			if rng:NextNumber() < 0.08 and z + 1.4 < z0 + length - 0.7 then
				-- A small stack lying flat.
				local h = 0.07
				for _ = 1, rng:NextInteger(2, 4) do
					local t = rng:NextNumber(0.18, 0.3)
					part(parent, "Book", Vector3.new(deep, t, 1.2), at(xFront - 0.1 - deep / 2, y + 0.07 + h + t / 2, z + 0.6), BOOK_COLORS[rng:NextInteger(1, #BOOK_COLORS)], Enum.Material.Fabric)
					h += t
				end
				z += 1.35
			else
				local lean = rng:NextNumber() < 0.05 and math.rad(rng:NextNumber(8, 16)) or 0
				part(parent, "Book", Vector3.new(deep, tall, thick), at(xFront - 0.1 - deep / 2, y + 0.07 + tall / 2, z + thick / 2) * CFrame.Angles(lean, 0, 0), color, Enum.Material.Fabric)
				z += thick + 0.02
			end
		end
	end
end

-- A wall lamp with a wide, flat glowing shade, like the ones in DOORS: the
-- bloom turns the shade into a soft halo, and the light is broad and gentle.
local function makeSconce(parent, cf)
	part(parent, "SconcePlate", Vector3.new(0.15, 0.9, 0.5), cf, LIB.darkWood, Enum.Material.Metal)
	part(parent, "SconceArm", Vector3.new(0.5, 0.12, 0.12), cf * CFrame.new(0.25, -0.2, 0), Color3.fromRGB(70, 52, 36), Enum.Material.Metal)
	local bulb = part(parent, "SconceBulb", Vector3.new(0.5, 0.45, 1.3), cf * CFrame.new(0.6, 0.05, 0), LIB.lamp, Enum.Material.Neon)
	bulb.Shape = Enum.PartType.Ball
	bulb.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = LIB.lamp
	light.Range = 24
	light.Brightness = 0.8
	light.Parent = bulb
end

local function makePainting(parent, cf, rng)
	part(parent, "Frame", Vector3.new(0.25, 4.2, 3.2), cf, Color3.fromRGB(96, 66, 36), Enum.Material.Wood)
	local canvas = Color3.fromRGB(rng:NextInteger(150, 210), rng:NextInteger(120, 170), rng:NextInteger(90, 130))
	part(parent, "Canvas", Vector3.new(0.1, 3.4, 2.4), cf * CFrame.new(0.1, 0, 0), canvas, Enum.Material.SmoothPlastic)
	-- A dark shape on the canvas, so it reads as a picture of something.
	local subject = Color3.fromRGB(rng:NextInteger(70, 140), rng:NextInteger(30, 60), rng:NextInteger(20, 40))
	part(parent, "Subject", Vector3.new(0.05, rng:NextNumber(1.2, 2), rng:NextNumber(0.6, 1.2)), cf * CFrame.new(0.17, -0.4, 0), subject, Enum.Material.SmoothPlastic)
end

local function makePlant(parent, cf)
	local pot = part(parent, "Pot", Vector3.new(1.4, 1.3, 1.3), cf * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(120, 48, 34), Enum.Material.Slate)
	pot.Shape = Enum.PartType.Cylinder
	for i, size in { 1.8, 1.5, 1.1 } do
		local leaves = part(parent, "Leaves", Vector3.new(size, size * 1.1, size), cf * CFrame.new(0, 1.1 + i * 0.85, 0), Color3.fromRGB(40, 54, 30), Enum.Material.Grass)
		leaves.Shape = Enum.PartType.Ball
	end
end

local function buildLibrary(level, base, rng, itemDef)
	local W, D, wallH, rise = LIB_WIDTH, LIB_DEPTH, LIB_WALL_H, LIB_VAULT_RISE
	local room = Instance.new("Model")
	room.Name = "Level" .. level
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end

	-- Floor and the patterned runner down the middle.
	part(room, "Floor", Vector3.new(W, 1, D), at(0, -0.5, D / 2), LIB.floor, Enum.Material.WoodPlanks)
	part(room, "Runner", Vector3.new(W - 7, 0.06, D - 1), at(0, 0.03, D / 2), LIB.carpet, Enum.Material.Carpet)

	-- Side walls: wallpaper over wood wainscoting, with a rail and crown moulding.
	-- The right wall (-x) has a low opening for the vent near the far end.
	local ventZ, ventSize = D - 3, 3
	local gap0, gap1 = ventZ - ventSize / 2, ventZ + ventSize / 2
	for _, side in { -1, 1 } do
		local x = side * (W / 2 + 0.5)
		local inner = side * W / 2
		local spans = side == -1 and { { 0, gap0 }, { gap1, D } } or { { 0, D } }
		for _, span in spans do
			local len, mid = span[2] - span[1], (span[1] + span[2]) / 2
			part(room, "Wall", Vector3.new(1, wallH + 1, len), at(x, (wallH + 1) / 2, mid), LIB.wallpaper, Enum.Material.Fabric)
			part(room, "Wainscot", Vector3.new(0.4, 3.2, len), at(inner - side * 0.2, 1.6, mid), LIB.wood, Enum.Material.Wood)
		end
		if side == -1 then
			part(room, "Wall", Vector3.new(1, wallH + 1 - ventSize, ventSize), at(x, ventSize + (wallH + 1 - ventSize) / 2, ventZ), LIB.wallpaper, Enum.Material.Fabric)
		end
		part(room, "Rail", Vector3.new(0.6, 0.3, D), at(inner - side * 0.3, 3.35, D / 2), LIB.darkWood, Enum.Material.Wood)
		part(room, "Crown", Vector3.new(0.9, 0.6, D), at(inner - side * 0.45, wallH - 0.3, D / 2), LIB.darkWood, Enum.Material.Wood)
	end

	-- Far wall with a doorway onto a small back room. The door is locked; the
	-- floor's item waits inside, reachable only through the vent.
	local doorW, doorH = 4, 8
	local backH = wallH + rise + 1
	local sideW = (W - doorW) / 2
	for _, side in { -1, 1 } do
		part(room, "WallBack", Vector3.new(sideW, backH, 1), at(side * (doorW / 2 + sideW / 2), backH / 2, D + 0.5), LIB.wallpaper, Enum.Material.Fabric)
		part(room, "WainscotBack", Vector3.new(sideW, 3.2, 0.4), at(side * (doorW / 2 + sideW / 2), 1.6, D - 0.2), LIB.wood, Enum.Material.Wood)
		part(room, "DoorCasing", Vector3.new(0.4, doorH + 0.4, 0.5), at(side * (doorW / 2 + 0.2), (doorH + 0.4) / 2, D - 0.25), LIB.darkWood, Enum.Material.Wood)
	end
	part(room, "WallBackTop", Vector3.new(doorW, backH - doorH, 1), at(0, doorH + (backH - doorH) / 2, D + 0.5), LIB.wallpaper, Enum.Material.Fabric)
	part(room, "DoorHead", Vector3.new(doorW + 0.8, 0.4, 0.5), at(0, doorH + 0.2, D - 0.25), LIB.darkWood, Enum.Material.Wood)
	local hinge = at(-doorW / 2, 0, D + 0.1)
	local door = part(room, "Door", Vector3.new(doorW - 0.1, doorH - 0.1, 0.25), hinge * CFrame.new(doorW / 2, doorH / 2, 0), LIB.wood, Enum.Material.Wood)
	part(door, "Knob", Vector3.new(0.25, 0.25, 0.6), door.CFrame * CFrame.new(doorW / 2 - 0.5, -0.3, 0), Color3.fromRGB(150, 120, 70), Enum.Material.Metal)

	-- The back room, a little wider than the doorway.
	local roomGreen = Color3.fromRGB(40, 50, 44)
	local sideX = doorW / 2 + 2.5
	part(room, "BeyondFloor", Vector3.new(doorW + 4, 1, 6), at(0, -0.5, D + 4), LIB.floor, Enum.Material.WoodPlanks)
	part(room, "BeyondBack", Vector3.new(doorW + 4, doorH + 2, 1), at(0, (doorH + 2) / 2, D + 7.5), roomGreen, Enum.Material.Fabric)
	part(room, "BeyondSide", Vector3.new(1, doorH + 2, 6), at(sideX, (doorH + 2) / 2, D + 4), roomGreen, Enum.Material.Fabric)
	-- Its right side wall has the vent's way in, low down in the middle.
	for _, span in { { D + 1, D + 2.5 }, { D + 5.5, D + 7 } } do
		part(room, "BeyondSide", Vector3.new(1, doorH + 2, span[2] - span[1]), at(-sideX, (doorH + 2) / 2, (span[1] + span[2]) / 2), roomGreen, Enum.Material.Fabric)
	end
	part(room, "BeyondSide", Vector3.new(1, doorH + 2 - ventSize, ventSize), at(-sideX, ventSize + (doorH + 2 - ventSize) / 2, D + 4), roomGreen, Enum.Material.Fabric)
	part(room, "BeyondTop", Vector3.new(doorW + 4, 1, 6), at(0, doorH + 2.5, D + 4), LIB.darkWood)
	part(room, "BeyondDresser", Vector3.new(2.4, 3, 1.2), at(1, 1.5, D + 6.4), LIB.wood, Enum.Material.Wood)
	-- A single candle so the back room isn't pitch black.
	local candle = part(room, "Candle", Vector3.new(0.6, 0.25, 0.25), at(-0.4, 3.3, D + 6.6) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(232, 222, 196))
	candle.Shape = Enum.PartType.Cylinder
	local candleLight = Instance.new("PointLight")
	candleLight.Color = Color3.fromRGB(255, 170, 90)
	candleLight.Range = 10
	candleLight.Brightness = 0.9
	candleLight.Parent = candle

	-- The vent: a grate over the hall opening and a dark sheet-metal duct running
	-- behind the right wall, round the corner and into the back room's side wall.
	local metal = Color3.fromRGB(58, 56, 52)
	local ductX = -(W / 2 + 2.6) -- duct centreline behind the hall's right wall
	local ductZ = D + 4 -- where it turns toward the back room
	-- One axis-aligned box of the duct, given its extents in hall space.
	local function box(name, xa, xb, ya, yb, za, zb, material)
		part(room, name, Vector3.new(math.abs(xb - xa), yb - ya, math.abs(zb - za)), at((xa + xb) / 2, (ya + yb) / 2, (za + zb) / 2), metal, material or Enum.Material.Metal)
	end
	-- Three runs: A through the hall wall, B behind it toward the back, C across
	-- into the back room. Walls are laid out by hand so no run blocks another.
	local h, t, vs = ventSize / 2, 0.2, ventSize
	local wallIn, roomWall = -W / 2, -sideX - 0.5
	local xOut, xIn = ductX - h, ductX + h
	box("DuctWall", xOut - t, xOut, 0, vs, ventZ - h - t, ductZ + h + t)
	box("DuctWall", xOut, wallIn, 0, vs, ventZ - h - t, ventZ - h)
	box("DuctWall", xIn, wallIn, 0, vs, ventZ + h, ventZ + h + t)
	box("DuctWall", xIn, xIn + t, 0, vs, ventZ + h, ductZ - h)
	box("DuctWall", xIn, roomWall, 0, vs, ductZ - h - t, ductZ - h)
	box("DuctWall", xOut, roomWall, 0, vs, ductZ + h, ductZ + h + t)
	for _, run in {
		{ xOut - t, wallIn, ventZ - h - t, ventZ + h + t },
		{ xOut - t, xIn + t, ventZ - h - t, ductZ + h + t },
		{ xOut - t, roomWall, ductZ - h - t, ductZ + h + t },
	} do
		box("DuctFloor", run[1], run[2], -t, 0, run[3], run[4], Enum.Material.DiamondPlate)
		box("DuctTop", run[1], run[2], vs, vs + t, run[3], run[4])
	end

	local grate = part(room, "VentGrate", Vector3.new(0.12, ventSize - 0.2, ventSize - 0.2), at(-W / 2 + 0.06, ventSize / 2, ventZ), Color3.fromRGB(46, 44, 40), Enum.Material.Metal)
	for i = -2, 2 do
		local slat = part(grate, "Slat", Vector3.new(0.18, 0.12, ventSize - 0.4), grate.CFrame * CFrame.new(0, i * 0.5, 0), Color3.fromRGB(30, 28, 26), Enum.Material.Metal)
		slat.CanCollide = false
	end
	-- The grate inside the back room has already been pushed out onto the floor.
	part(room, "VentGrateFallen", Vector3.new(ventSize - 0.2, 0.12, ventSize - 0.2), at(-sideX + 1.8, 0.06, D + 2.6) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(46, 44, 40), Enum.Material.Metal)

	makePlant(room, at(-doorW / 2 - 2.5, 0, D - 1.2))
	makePlant(room, at(doorW / 2 + 2.5, 0, D - 1.2))

	-- Barrel vault: a flattened arch of planks spanning wall to wall, with
	-- darker arched ribs hanging just below it every few bays.
	local SEGMENTS = 14
	local function archPoint(t)
		local a = math.pi * t
		return Vector2.new(-math.cos(a) * W / 2, wallH + math.sin(a) * rise)
	end
	local function arch(name, zMid, length, thickness, color, hangBelow)
		for i = 1, SEGMENTS do
			local p0, p1 = archPoint((i - 1) / SEGMENTS), archPoint(i / SEGMENTS)
			local dir = p1 - p0
			local outward = Vector2.new(-dir.Unit.Y, dir.Unit.X)
			local centre = (p0 + p1) / 2 + outward * (hangBelow and -thickness / 2 or thickness / 2)
			part(room, name, Vector3.new(dir.Magnitude + 0.08, thickness, length), at(centre.X, centre.Y, zMid) * CFrame.Angles(0, 0, math.atan2(dir.Y, dir.X)), color, hangBelow and Enum.Material.Wood or Enum.Material.WoodPlanks)
		end
	end
	arch("Vault", D / 2, D, 0.5, LIB.wood, false)
	for z = 8, D - 4, 12 do
		arch("Rib", z, 0.9, 0.8, LIB.darkWood, true)
	end

	-- Looking out of the elevator into the hall, +x is on your left.
	-- Bookcases down the left wall.
	local caseLength, gap = 5.6, 0.5
	local z = 2
	while z + caseLength < D - 9 do
		makeBookcase(room, at, rng, W / 2 - 0.4, -1, z, caseLength)
		z += caseLength + gap
	end

	-- Sconces and paintings down the right wall, facing into the hall.
	for sz = 8, D - 6, 12 do
		makeSconce(room, at(-W / 2 + 0.1, 7, sz))
	end
	for _, pz in { 14, 38, 50 } do
		makePainting(room, at(-W / 2 + 0.15, 6.8, pz), rng)
	end
	-- One sconce on the left past the bookcases, near the far end.
	makeSconce(room, at(W / 2 - 0.1, 7, D - 5) * CFrame.Angles(0, math.pi, 0))

	-- Soft shadowless fill along the vault so the hall stays dim rather than black.
	for fz = 6, D, 16 do
		local fill = Instance.new("Attachment")
		fill.Name = "Fill"
		fill.Parent = room.Floor
		fill.WorldPosition = at(0, wallH, fz).Position
		local light = Instance.new("PointLight")
		light.Color = LIB.lamp
		light.Range = 22
		light.Brightness = 0.26
		light.Shadows = false
		light.Parent = fill
	end

	-- A note by the entrance, on a small side table against the right wall.
	local noteTop = makeTable(room, at(-W / 2 + 1.6, 0, 5), Vector2.new(1.8, 2.6), LIB.darkWood)
	local note = part(room, "Note", Vector3.new(0.9, 0.03, 1.2), noteTop * CFrame.new(0, 0.015, 0) * CFrame.Angles(0, 0.3, 0), Color3.fromRGB(226, 212, 180))

	-- The item waits on the dresser in the locked back room.
	local item = placeItem(room, itemDef, at(1, 3, D + 6.4), rng)

	-- Everything the floor's challenge (Library.luau) needs.
	local info = {
		kind = "library",
		base = base,
		hallWidth = W,
		hallDepth = D,
		door = door,
		doorHinge = hinge,
		grate = grate,
		note = note,
		-- The crawl, as root positions in the order travelled. Low enough that
		-- the head (and the camera) sits inside the duct.
		ventPath = {
			at(-W / 2 + 1.2, 0.7, ventZ).Position,
			at(-W / 2 - 0.3, 0.7, ventZ).Position,
			at(ductX, 0.7, ventZ).Position,
			at(ductX, 0.7, ductZ).Position,
			at(-sideX - 0.3, 0.7, ductZ).Position,
			at(-sideX + 1.4, 0.7, ductZ).Position,
		},
		ventExit = at(-sideX + 2.2, 3, ductZ).Position,
		librarianStart = at(0, 0, D - 4).Position,
		librarianEnd = at(0, 0, 3).Position,
	}
	return room, item, itemDef.name, info
end

-- base: floor-level CFrame at the centre of the elevator's outer door face, facing into the room.
-- Returns the room model, the item part to be carried back, and the item's name.
function Levels.build(level, base)
	local rng = Random.new(level)
	local palette = PALETTES[(level - 1) % #PALETTES + 1]
	local itemDef = ITEMS[(level - 1) % #ITEMS + 1]

	if level == 1 then
		return buildLibrary(level, base, rng, itemDef)
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
