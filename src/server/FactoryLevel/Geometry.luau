-- Building blocks for the factory level. Everything takes a ctx:
--   ctx.base     CFrame all local coordinates are relative to
--   ctx.rng      Random for this level
--   ctx.parts    running part count
--   ctx.flicker  lights the level makes flicker
--   ctx.loot     loot surfaces { cf = local CFrame, area = string, primary = bool }
-- "Soft" edges: instead of hard 90-degree corners, wall/ceiling and wall/floor edges,
-- inside corners, door heads and pillars get single-face 45-degree cuts.

local Config = require(script.Parent.Config)

local S = Config.Settings
local C = Config.Colors
local STYLE = Config.Styles
local M = Enum.Material

local T = S.Wall
local CW = S.CorridorWidth
local SQ2 = math.sqrt(2)
local TAU = math.pi * 2

local G = {}

G.DECO = { CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false }
local DECO = G.DECO
local HIDDEN = { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false }

-- ================= PRIMITIVES =================
function G.mk(ctx, parent, name, size, lcf, color, material, props, class)
	local p = Instance.new(class or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = ctx.base * lcf
	p.Color = color
	p.Material = material or M.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	p.Parent = parent
	ctx.parts += 1
	return p
end
local mk = G.mk

function G.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
local model = G.model

function G.flatAt(p, y)
	return Vector3.new(p.X, y, p.Z)
end
local flatAt = G.flatAt

function G.dirOf(a)
	return Vector3.new(math.cos(a), 0, math.sin(a))
end
function G.tangOf(a)
	return Vector3.new(-math.sin(a), 0, math.cos(a))
end
local dirOf, tangOf = G.dirOf, G.tangOf

-- Frame with X along a horizontal direction, Y up.
function G.along(pos, dir)
	return CFrame.fromMatrix(pos, dir, Vector3.yAxis, dir:Cross(Vector3.yAxis))
end
local along = G.along

-- Frame at the midpoint of a->b with X along a->b; also returns the length.
function G.orient(a, b)
	local v = b - a
	local len = v.Magnitude
	local x = v / len
	local up = math.abs(x.Y) > 0.95 and Vector3.xAxis or Vector3.yAxis
	local z = x:Cross(up).Unit
	local y = z:Cross(x)
	return CFrame.fromMatrix((a + b) / 2, x, y, z), len
end
local orient = G.orient

function G.cyl(ctx, parent, name, a, b, d, color, material, props)
	if (b - a).Magnitude < 0.05 then
		return nil
	end
	local cf, len = orient(a, b)
	local p = mk(ctx, parent, name, Vector3.new(len, d, d), cf, color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local cyl = G.cyl

function G.bar(ctx, parent, name, a, b, w, h, color, material, props)
	if (b - a).Magnitude < 0.05 then
		return nil
	end
	local cf, len = orient(a, b)
	return mk(ctx, parent, name, Vector3.new(len, h or w, w), cf, color, material, props)
end
local bar = G.bar

-- Upright cylinder (floor, ceiling, tank) centred on `centre`.
function G.disc(ctx, parent, name, centre, radius, thick, color, material, props)
	local p = mk(ctx, parent, name, Vector3.new(thick, radius * 2, radius * 2), CFrame.new(centre) * CFrame.Angles(0, 0, math.pi / 2), color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local disc = G.disc

-- A square bar turned 45 degrees about its length, laid along the edge a->b where two
-- surfaces meet. Half of it hides inside them; the other half reads as a flat 45-degree
-- cut of leg `c` on that edge.
function G.chamfer(ctx, parent, a, b, c, color, material)
	if (b - a).Magnitude < 0.05 then
		return nil
	end
	local cf, len = orient(a, b)
	return mk(ctx, parent, "Chamfer", Vector3.new(len, c * SQ2, c * SQ2), cf * CFrame.Angles(math.pi / 4, 0, 0), color, material, { CanCollide = false, CanTouch = false, CanQuery = false })
end
local chamfer = G.chamfer

-- Regular octagonal column of width w: two crossed cores plus four 45-degree fillers.
function G.pillar(ctx, parent, pos, y0, y1, w, color, material, props)
	local h = y1 - y0
	if h <= 0.05 then
		return nil
	end
	local c = w / (2 + SQ2)
	local mid = Vector3.new(pos.X, (y0 + y1) / 2, pos.Z)
	local m = model(parent, "Pillar")
	mk(ctx, m, "Core", Vector3.new(w - 2 * c, h, w), CFrame.new(mid), color, material, props)
	mk(ctx, m, "Core", Vector3.new(w, h, w - 2 * c), CFrame.new(mid), color, material, props)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local offset = Vector3.new(sx * (w / 2 - c), 0, sz * (w / 2 - c))
			mk(ctx, m, "Bevel", Vector3.new(c * SQ2, h, c * SQ2), CFrame.new(mid + offset) * CFrame.Angles(0, math.pi / 4, 0), color, material, props)
		end
	end
	return m
end
local pillar = G.pillar

-- ================= WALLS =================
-- Straight wall on the centreline p0 -> p1 (local XZ) from y0 to y1. `inward` points into
-- the space it faces; decoration goes on that side. `ext` lengthens only the structural
-- slab at both ends so corners close. gaps: { { s = centre distance from p0, w, y0, y1 } }
function G.wallRun(ctx, parent, p0, p1, y0, y1, inward, opts)
	opts = opts or {}
	local style = opts.style or STYLE.room
	local ext = opts.ext or 0
	local floorY = opts.floor or y0
	local flat = Vector3.new(p1.X - p0.X, 0, p1.Z - p0.Z)
	local len = flat.Magnitude
	if len < 0.05 then
		return nil
	end
	local dir = flat / len
	local frame = along(Vector3.new(p0.X, 0, p0.Z), dir)
	local zs = inward:Dot(frame.ZVector) >= 0 and 1 or -1
	local function at(s, y, n)
		return frame * CFrame.new(s, y, n * zs)
	end
	local face = T / 2
	local m = model(parent, opts.name or "Wall")

	local function slab(a, b, ya, yb)
		if b - a > 0.05 and yb - ya > 0.05 then
			mk(ctx, m, "Wall", Vector3.new(b - a, yb - ya, T), at((a + b) / 2, (ya + yb) / 2, 0), style.wall, style.wallMat)
		end
	end

	local gaps = table.clone(opts.gaps or {})
	table.sort(gaps, function(a, b)
		return a.s < b.s
	end)
	local solids = {}
	local cursor = -ext
	for _, g in gaps do
		local ga, gb = g.s - g.w / 2, g.s + g.w / 2
		slab(cursor, ga, y0, y1)
		table.insert(solids, { cursor, ga })
		if g.y0 > y0 + 0.05 then
			slab(ga, gb, y0, g.y0)
		end
		if g.y1 < y1 - 0.05 then
			slab(ga, gb, g.y1, y1)
		end
		cursor = gb
		-- steel frame, with 45-degree cuts in the head corners of the opening
		local fh = g.y1 - g.y0
		for _, e in { ga - 0.25, gb + 0.25 } do
			mk(ctx, m, "Jamb", Vector3.new(0.5, fh + 0.5, T + 0.5), at(e, g.y0 + (fh + 0.5) / 2, 0), C.darkSteel, M.Metal)
		end
		mk(ctx, m, "Head", Vector3.new(g.w + 1, 0.5, T + 0.5), at(g.s, g.y1 + 0.25, 0), C.darkSteel, M.Metal)
		for _, e in { ga, gb } do
			mk(ctx, m, "HeadBevel", Vector3.new(0.9 * SQ2, 0.9 * SQ2, T + 0.5), at(e, g.y1, 0) * CFrame.Angles(0, 0, math.pi / 4), C.darkSteel, M.Metal, DECO)
		end
	end
	slab(cursor, len + ext, y0, y1)
	table.insert(solids, { cursor, len + ext })

	local bandTop = style.band and math.min(floorY + style.band, y1) or floorY
	for _, sg in solids do
		local a, b = math.max(sg[1], 0), math.min(sg[2], len)
		if b - a > 0.1 then
			local mid = (a + b) / 2
			if style.band and bandTop > floorY then
				mk(ctx, m, "Band", Vector3.new(b - a, bandTop - floorY, 0.3), at(mid, (floorY + bandTop) / 2, face + 0.15), style.bandColor, style.bandMat, DECO)
				mk(ctx, m, "BandCap", Vector3.new(b - a, 0.25, 0.45), at(mid, bandTop, face + 0.22), C.darkSteel, M.Metal, DECO)
			end
			if style.upperMat and y1 - bandTop > 0.2 then
				mk(ctx, m, "Panel", Vector3.new(b - a, y1 - bandTop, 0.15), at(mid, (bandTop + y1) / 2, face + 0.075), style.upperColor, style.upperMat, DECO)
			end
			if style.ribs then
				local s = a + style.ribs / 2
				while s < b - 0.5 do
					mk(ctx, m, "Rib", Vector3.new(0.7, y1 - floorY, 0.5), at(s, (floorY + y1) / 2, face + 0.25), C.steel, M.Metal, DECO)
					s += style.ribs
				end
			end
			if style.chamfer and opts.floor then
				chamfer(ctx, m, at(a, floorY, face).Position, at(b, floorY, face).Position, 0.6, style.wall, style.wallMat)
			end
		end
	end
	if style.topChamfer then
		chamfer(ctx, m, at(0, y1, face).Position, at(len, y1, face).Position, S.Chamfer, style.wall, style.wallMat)
	end
	return m, solids
end
local wallRun = G.wallRun

-- Walls of a regular N-gon whose inner faces sit at apothem r, facing the centre.
-- Segment k is centred on angle phase + k*2pi/N. doors: { [k] = { y0 = sill } }
function G.polyWalls(ctx, parent, c, r, N, phase, y0, y1, floorY, doors, style)
	local half = math.pi / N
	local ap = r + T / 2
	local hl = ap * math.tan(half)
	for k = 0, N - 1 do
		local a = phase + k * TAU / N
		local radial, tang = dirOf(a), tangOf(a)
		local mid = c + radial * ap
		local door = doors and doors[k]
		local gaps = door and { { s = hl, w = door.w or CW, y0 = door.y0, y1 = door.y0 + S.DoorHeight } } or nil
		wallRun(ctx, parent, mid - tang * hl, mid + tang * hl, y0, y1, -radial, {
			gaps = gaps,
			ext = (T / 2) * math.tan(half) + 0.06,
			floor = floorY,
			style = style,
			name = "Wall" .. k,
		})
	end
end

-- Axis-aligned rectangular room. spec: name, c (centre), W, D, y (floor), h, doors =
-- { { side = "N"|"S"|"E"|"W", off = offset along the wall, y0 = sill } }, open = { S = true },
-- noFloor, style.
function G.boxRoom(ctx, parent, spec)
	local m = model(parent, spec.name)
	local c, W, D, y, h = spec.c, spec.W, spec.D, spec.y, spec.h
	local style = spec.style or STYLE.room
	local hw, hd = W / 2, D / 2
	local function P(x, z)
		return Vector3.new(c.X + x, 0, c.Z + z)
	end
	if not spec.noFloor then
		mk(ctx, m, "Floor", Vector3.new(W + 2 * T, 1, D + 2 * T), CFrame.new(c.X, y - 0.5, c.Z), C.floor, M.Concrete, nil)
	end
	mk(ctx, m, "Ceiling", Vector3.new(W + 2 * T, 1, D + 2 * T), CFrame.new(c.X, y + h + 0.5, c.Z), C.ceiling, M.Concrete)

	local doorsBy = { N = {}, S = {}, E = {}, W = {} }
	for _, d in spec.doors or {} do
		local sill = d.y0 or y
		local s = (d.side == "N" or d.side == "S") and (hw + d.off) or (hd + d.off)
		table.insert(doorsBy[d.side], { s = s, w = d.w or CW, y0 = sill, y1 = sill + S.DoorHeight })
	end
	local walls = {
		N = { P(-hw, hd + T / 2), P(hw, hd + T / 2), Vector3.new(0, 0, -1) },
		S = { P(-hw, -hd - T / 2), P(hw, -hd - T / 2), Vector3.new(0, 0, 1) },
		E = { P(hw + T / 2, -hd), P(hw + T / 2, hd), Vector3.new(-1, 0, 0) },
		W = { P(-hw - T / 2, -hd), P(-hw - T / 2, hd), Vector3.new(1, 0, 0) },
	}
	for side, w in walls do
		if not (spec.open and spec.open[side]) then
			wallRun(ctx, m, w[1], w[2], y - 1, y + h, w[3], { gaps = doorsBy[side], ext = T, floor = y, style = style, name = "Wall" .. side })
		end
	end
	-- 45-degree cuts in the inside corners
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local cp = P(sx * hw, sz * hd)
			chamfer(ctx, m, flatAt(cp, y), flatAt(cp, y + h), S.Chamfer * 1.3, style.wall, style.wallMat)
		end
	end
	-- steel roof beams across the short side
	local alongX = W >= D
	local span, across = alongX and W or D, alongX and D or W
	local count = math.floor(span / 4.5)
	for i = 1, count do
		local t = -span / 2 + span * i / (count + 1)
		local pos = alongX and Vector3.new(c.X + t, y + h - 0.35, c.Z) or Vector3.new(c.X, y + h - 0.35, c.Z + t)
		local size = alongX and Vector3.new(0.5, 0.7, across) or Vector3.new(across, 0.7, 0.5)
		mk(ctx, m, "Beam", size, CFrame.new(pos), C.darkSteel, M.Metal, { CanCollide = false, CanTouch = false, CanQuery = false })
	end
	return m
end

-- ================= LIGHTS =================
local function lampColor(kind)
	return (kind == "red" and C.red) or (kind == "sodium" and C.sodium) or (kind == "purple" and C.purple) or (kind == "dead" and C.deadBulb) or C.cold
end

function G.rollLamp(rng)
	local r = rng:NextNumber()
	if r < 0.55 then
		return "cold"
	elseif r < 0.72 then
		return "sodium"
	elseif r < 0.82 then
		return "red"
	end
	return "dead"
end

-- Caged pendant hanging from a ceiling point. Cold lamps are downward spots.
function G.hangLamp(ctx, parent, pos, kind, opts)
	opts = opts or {}
	local m = model(parent, "Lamp")
	local drop = opts.drop or 0.5
	local size = opts.size or 1.4
	local hp = pos - Vector3.new(0, drop, 0)
	if drop > 0.2 then
		cyl(ctx, m, "Rod", pos, hp, 0.12, C.darkSteel, M.Metal, DECO)
	end
	mk(ctx, m, "Shade", Vector3.new(size, 0.35, size), CFrame.new(hp - Vector3.new(0, 0.17, 0)), C.darkSteel, M.Metal, DECO)
	local color = lampColor(kind)
	local bs = 0.55 * size / 1.4
	local bulb = mk(ctx, m, "Bulb", Vector3.new(bs, bs, bs), CFrame.new(hp - Vector3.new(0, 0.55, 0)), color, kind == "dead" and M.Glass or M.Neon, DECO)
	bulb.Shape = Enum.PartType.Ball
	local cy = hp.Y - 0.95
	bar(ctx, m, "Cage", Vector3.new(hp.X - 0.5, cy, hp.Z), Vector3.new(hp.X + 0.5, cy, hp.Z), 0.06, nil, C.darkSteel, M.Metal, DECO)
	bar(ctx, m, "Cage", Vector3.new(hp.X, cy, hp.Z - 0.5), Vector3.new(hp.X, cy, hp.Z + 0.5), 0.06, nil, C.darkSteel, M.Metal, DECO)
	local light
	if kind == "cold" then
		light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Angle = opts.angle or 110
		light.Range = opts.range or 18
		light.Brightness = opts.brightness or 1.5
	elseif kind ~= "dead" then
		light = Instance.new("PointLight")
		light.Range = opts.range or 14
		light.Brightness = opts.brightness or (kind == "red" and 2 or 1.2)
	end
	if light then
		light.Color = color
		light.Shadows = opts.shadows or false
		light.Parent = bulb
		if opts.flicker then
			table.insert(ctx.flicker, { light = light, bulb = bulb })
		end
	end
	return bulb, light
end

-- Caged bulb on a wall plate; pos is on the wall face, inward points into the room.
function G.wallLamp(ctx, parent, pos, inward, kind, opts)
	opts = opts or {}
	local m = model(parent, "WallLamp")
	local cf = CFrame.lookAt(pos, pos + inward)
	mk(ctx, m, "Plate", Vector3.new(0.7, 0.9, 0.2), cf * CFrame.new(0, 0, -0.1), C.darkSteel, M.Metal, DECO)
	local color = lampColor(kind)
	local bulb = mk(ctx, m, "Bulb", Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(0, 0, -0.5), color, M.Neon, DECO)
	bulb.Shape = Enum.PartType.Ball
	bar(ctx, m, "Cage", (cf * CFrame.new(-0.35, 0, -0.5)).Position, (cf * CFrame.new(0.35, 0, -0.5)).Position, 0.06, nil, C.darkSteel, M.Metal, DECO)
	bar(ctx, m, "Cage", (cf * CFrame.new(0, -0.35, -0.5)).Position, (cf * CFrame.new(0, 0.35, -0.5)).Position, 0.06, nil, C.darkSteel, M.Metal, DECO)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = opts.range or 12
	light.Brightness = opts.brightness or 1.4
	light.Shadows = false
	light.Parent = bulb
	if opts.flicker then
		table.insert(ctx.flicker, { light = light, bulb = bulb })
	end
	return bulb, light
end

-- ================= PROPS =================
function G.sign(ctx, parent, pos, inward, size, text, textColor, plateColor)
	local plate = mk(ctx, parent, "Sign", size, CFrame.lookAt(pos, pos + inward), plateColor, M.Metal, DECO)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 1
	gui.Parent = plate
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Oswald
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = gui
	return plate, label
end

function G.puddle(ctx, parent, pos, r)
	return disc(ctx, parent, "Puddle", pos + Vector3.new(0, 0.03, 0), r, 0.04, C.puddle, M.SmoothPlastic, {
		Reflectance = 0,
		CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
	})
end

function G.steam(ctx, parent, pos, dir, strength)
	local up = math.abs(dir.Y) > 0.9 and Vector3.xAxis or Vector3.yAxis
	local p = mk(ctx, parent, "SteamVent", Vector3.new(0.4, 0.4, 0.4), CFrame.lookAt(pos, pos + dir, up), C.black, M.SmoothPlastic, HIDDEN)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(190, 195, 200))
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 6) })
	e.Lifetime = NumberRange.new(3, 5)
	e.Rate = 5 * (strength or 1)
	e.Speed = NumberRange.new(1.5, 3)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-20, 20)
	e.Acceleration = Vector3.new(0, 0.6, 0)
	e.LightEmission = 0.05
	e.LightInfluence = 1
	e.EmissionDirection = Enum.NormalId.Front
	e.Parent = p
	return p
end

-- Crate on the floor at pos; returns its top surface (local CFrame).
function G.crate(ctx, parent, pos, size, yaw, kind)
	local m = model(parent, "Crate")
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
	local metal = kind == "metal"
	mk(ctx, m, "Body", size - Vector3.new(0.1, 0, 0.1), cf * CFrame.new(0, size.Y / 2, 0), metal and C.steel or C.wood, metal and M.DiamondPlate or M.WoodPlanks)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			mk(ctx, m, "Edge", Vector3.new(0.25, size.Y, 0.25), cf * CFrame.new(sx * (size.X / 2 - 0.12), size.Y / 2, sz * (size.Z / 2 - 0.12)), metal and C.yellow or C.darkSteel, M.Metal, DECO)
		end
	end
	return cf * CFrame.new(0, size.Y, 0)
end

function G.barrel(ctx, parent, pos, color)
	local h, r = 3.1, 1.05
	local m = model(parent, "Drum")
	disc(ctx, m, "Body", pos + Vector3.new(0, h / 2, 0), r, h, color, M.Metal)
	disc(ctx, m, "Band", pos + Vector3.new(0, h * 0.3, 0), r + 0.05, 0.2, C.darkSteel, M.Metal, DECO)
	disc(ctx, m, "Band", pos + Vector3.new(0, h * 0.7, 0), r + 0.05, 0.2, C.darkSteel, M.Metal, DECO)
	return CFrame.new(pos + Vector3.new(0, h, 0))
end

-- A crate that may hold the level's item; the spot is recorded for later.
function G.lootSpot(ctx, parent, pos, area, primary)
	local top = G.crate(ctx, parent, pos, Vector3.new(2.2, 1.6, 2.2), ctx.rng:NextNumber(0, TAU), "metal")
	table.insert(ctx.loot, { cf = top, area = area, primary = primary })
	return top
end

-- ================= RAILINGS & STAIRS =================
local RAIL_H = 3.2

-- Yellow handrail along a polyline of floor points, with an invisible guard so nobody
-- slips through, and posts at least every 3 studs.
function G.railing(ctx, parent, pts, opts)
	local m = model(parent, "Railing")
	local h = RAIL_H
	local function post(p)
		mk(ctx, m, "Post", Vector3.new(0.2, h, 0.2), CFrame.new(p + Vector3.new(0, h / 2, 0)), C.yellow, M.Metal, DECO)
	end
	post(pts[1])
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local len = (b - a).Magnitude
		if len > 0.05 then
			local n = math.max(1, math.ceil(len / 3))
			for j = 1, n do
				post(a:Lerp(b, j / n))
			end
			local up, mid = Vector3.new(0, h, 0), Vector3.new(0, h * 0.5, 0)
			bar(ctx, m, "Rail", a + up, b + up, 0.18, nil, C.yellow, M.Metal, DECO)
			bar(ctx, m, "MidRail", a + mid, b + mid, 0.12, nil, C.yellow, M.Metal, DECO)
			if not (opts and opts.noKick) then
				bar(ctx, m, "Kick", a + Vector3.new(0, 0.15, 0), b + Vector3.new(0, 0.15, 0), 0.08, 0.3, C.yellow, M.Metal, DECO)
			end
			local cf = orient(a + mid, b + mid)
			mk(ctx, m, "Guard", Vector3.new(len, h, 0.25), cf, C.black, M.SmoothPlastic, { Transparency = 1, CastShadow = false, CanTouch = false, CanQuery = false })
		end
	end
	return m
end
local railing = G.railing

-- Railing from p0 to p1 with an opening of width gapW centred gapAt studs from p0.
function G.railWithGap(ctx, parent, p0, p1, gapAt, gapW)
	local len = (p1 - p0).Magnitude
	local dir = (p1 - p0) / len
	local g0, g1 = math.max(0, gapAt - gapW / 2), math.min(len, gapAt + gapW / 2)
	if g0 > 0.3 then
		railing(ctx, parent, { p0, p0 + dir * g0 })
	end
	if len - g1 > 0.3 then
		railing(ctx, parent, { p0 + dir * g1, p1 })
	end
end

-- Solid straight stairs starting at `start` (floor point, centre of the first step) and
-- climbing `rise` (negative goes down) over `run` studs along dir.
function G.stairs(ctx, parent, start, dir, run, rise, width, color, material)
	local m = model(parent, "Stairs")
	local n = math.max(1, math.ceil(math.abs(rise) / 0.75))
	local depth = run / n
	local bottom = math.min(start.Y, start.Y + rise) - 0.2
	local side = dir:Cross(Vector3.yAxis)
	for k = 0, n - 1 do
		local top = start.Y + rise * (k + 1) / n
		local c = start + dir * (depth * (k + 0.5))
		mk(ctx, m, "Step", Vector3.new(depth + 0.02, top - bottom, width), along(Vector3.new(c.X, (top + bottom) / 2, c.Z), dir), color, material)
		local edge = start + dir * (depth * k + 0.1)
		bar(ctx, m, "Nosing", Vector3.new(edge.X, top + 0.02, edge.Z) - side * (width / 2 - 0.6), Vector3.new(edge.X, top + 0.02, edge.Z) + side * (width / 2 - 0.6), 0.16, 0.05, C.yellow, M.SmoothPlastic, DECO)
	end
	return m
end
local stairs = G.stairs

-- ================= CORRIDORS =================
-- One straight leg. Flat, ramped (<= 0.3 slope) or stepped depending on its rise.
-- leg: { a, b (local XZ), ya, yb, gaps = { { s, toward = side vector, y } } }
function G.corridorLeg(ctx, parent, leg, name)
	local rng = ctx.rng
	local p0, p1, ya, yb = leg.a, leg.b, leg.ya, leg.yb
	local flat = Vector3.new(p1.X - p0.X, 0, p1.Z - p0.Z)
	local len = flat.Magnitude
	if len < 0.1 then
		return nil
	end
	local dir = flat / len
	local side = dir:Cross(Vector3.yAxis)
	local dy = yb - ya
	local isFlat = math.abs(dy) < 0.05
	local yLow, yHigh = math.min(ya, yb), math.max(ya, yb)
	local top = yHigh + S.CorridorHeight
	local m = model(parent, name)
	local function pt(s, u, yy)
		local p = p0 + dir * s + side * u
		return Vector3.new(p.X, yy, p.Z)
	end
	local function floorAt(s)
		return ya + dy * math.clamp(s / len, 0, 1)
	end

	if isFlat then
		mk(ctx, m, "Floor", Vector3.new(len, 1, CW + 2 * T), along(pt(len / 2, 0, ya - 0.5), dir), C.floor, M.Concrete, nil)
		mk(ctx, m, "Drain", Vector3.new(math.max(len - 1.5, 0.5), 0.05, 0.8), along(pt(len / 2, 0, ya + 0.02), dir), C.drain, M.DiamondPlate, DECO)
	elseif math.abs(dy) / len <= 0.3 then
		local cf = along(pt(len / 2, 0, (ya + yb) / 2), dir) * CFrame.Angles(0, 0, math.atan2(dy, len)) * CFrame.new(0, -0.5, 0)
		mk(ctx, m, "Ramp", Vector3.new(math.sqrt(len * len + dy * dy) + 0.4, 1, CW + 2 * T), cf, C.floor, M.Concrete)
		for i = 1, math.floor(len / 1.5) do
			local s = i * 1.5
			mk(ctx, m, "Grip", Vector3.new(0.2, 0.08, CW - 0.4), along(pt(s, 0, floorAt(s) + 0.04), dir), C.yellow, M.Metal, DECO)
		end
	else
		stairs(ctx, m, pt(0, 0, ya), dir, len, dy, CW + 2 * T, C.floor, M.Concrete)
	end

	for _, sgn in { 1, -1 } do
		local u = sgn * (CW / 2 + T / 2)
		local gaps = {}
		for _, g in leg.gaps or {} do
			if g.toward:Dot(side * sgn) > 0 then
				table.insert(gaps, { s = g.s, w = CW, y0 = g.y, y1 = g.y + S.DoorHeight })
			end
		end
		wallRun(ctx, m, pt(0, u, 0), pt(len, u, 0), yLow - 1, top, -side * sgn, {
			gaps = gaps,
			floor = isFlat and ya or nil,
			style = isFlat and STYLE.corridor or STYLE.ramp,
			name = "Wall",
		})
	end
	mk(ctx, m, "Ceiling", Vector3.new(len, 1, CW + 2 * T), along(pt(len / 2, 0, top + 0.5), dir), C.ceiling, M.Concrete)

	-- steel portal frames
	local nF = math.max(1, math.floor(len / 6))
	local function nearGap(s)
		for _, g in leg.gaps or {} do
			if math.abs(s - g.s) < CW / 2 + 1 then
				return true
			end
		end
		return false
	end
	for i = 1, nF do
		local s = len * i / (nF + 1)
		if not nearGap(s) then
			local fy = floorAt(s) - (isFlat and 0 or 0.5)
			for _, sgn in { 1, -1 } do
				mk(ctx, m, "Frame", Vector3.new(0.6, top - fy, 0.5), along(pt(s, sgn * (CW / 2 - 0.25), (top + fy) / 2), dir), C.steel, M.Metal)
			end
			mk(ctx, m, "FrameBeam", Vector3.new(0.6, 0.6, CW), along(pt(s, 0, top - 0.3), dir), C.steel, M.Metal, DECO)
		end
	end

	-- pipe run inside the frames
	local ps = rng:NextNumber() < 0.5 and 1 or -1
	local yp = top - 1.25
	cyl(ctx, m, "Pipe", pt(-0.3, ps * (CW / 2 - 1.0), yp), pt(len + 0.3, ps * (CW / 2 - 1.0), yp), 0.8, C.pipe, M.CorrodedMetal, DECO)
	cyl(ctx, m, "Pipe", pt(-0.3, ps * (CW / 2 - 1.9), yp + 0.2), pt(len + 0.3, ps * (CW / 2 - 1.9), yp + 0.2), 0.5, C.copper, M.Metal, DECO)

	for i = 0, nF do
		local s = len * (i + 0.5) / (nF + 1)
		local kind = G.rollLamp(rng)
		G.hangLamp(ctx, m, pt(s, 0, top), kind, { drop = 0.3, range = 16, flicker = kind ~= "dead" and rng:NextNumber() < 0.25 })
	end
	if isFlat then
		for _ = 1, rng:NextInteger(0, 2) do
			G.puddle(ctx, m, pt(rng:NextNumber(1, len - 1), rng:NextNumber(-1.5, 1.5), ya), rng:NextNumber(0.6, 1.4))
		end
	end
	return m
end

-- Square junction where a corridor turns 90 degrees: d1 is the travel direction coming
-- in, d2 going out. The outside of the bend gets a large 45-degree cut.
function G.elbow(ctx, parent, e)
	local m = model(parent, "Elbow")
	local c, y, d1, d2 = e.c, e.y, e.d1, e.d2
	local hw = CW / 2
	local top = y + S.CorridorHeight
	mk(ctx, m, "Floor", Vector3.new(CW + 2 * T, 1, CW + 2 * T), CFrame.new(c.X, y - 0.5, c.Z), C.floor, M.Concrete, nil)
	mk(ctx, m, "Ceiling", Vector3.new(CW + 2 * T, 1, CW + 2 * T), CFrame.new(c.X, top + 0.5, c.Z), C.ceiling, M.Concrete)
	local f = c + d1 * (hw + T / 2)
	wallRun(ctx, m, f - d2 * (hw + T), f + d2 * hw, y - 1, top, -d1, { floor = y, style = STYLE.corridor, name = "WallFront" })
	local b = c - d2 * (hw + T / 2)
	wallRun(ctx, m, b - d1 * hw, b + d1 * (hw + T), y - 1, top, d2, { floor = y, style = STYLE.corridor, name = "WallBack" })
	local oc = c + d1 * hw - d2 * hw
	chamfer(ctx, m, flatAt(oc, y), flatAt(oc, top), 1.6, C.wall, M.Concrete)
	pillar(ctx, m, c - d1 * (hw + T / 2) + d2 * (hw + T / 2), y - 1, top, T + 0.3, C.wall, M.Concrete)
	G.hangLamp(ctx, m, flatAt(c, top), "sodium", { drop = 0.3, range = 14 })
	return m
end

return G
