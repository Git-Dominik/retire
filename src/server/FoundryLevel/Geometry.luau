-- Building blocks for the factory. Everything takes a ctx:
--   ctx.base, ctx.rng, ctx.parts, ctx.flicker, ctx.loot, ctx.molten
-- All coordinates are local to ctx.base (the elevator door, +Z away from the elevator).
--
-- Look: weathered brick, concrete, corrugated and painted steel; nothing glows except light
-- sources and hot metal. Edges get single-face 45-degree cuts (chamfer bars), columns are
-- octagonal, doorways get one standard steel frame each.

local Config = require(script.Parent.Config)

local S = Config.Settings
local C = Config.Colors
local M = Enum.Material

local T = S.Wall
local DW, DH = S.DoorWidth, S.DoorHeight
local SQ2 = math.sqrt(2)
local TAU = math.pi * 2

local G = {}

G.DECO = { CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false }
G.NOCOLLIDE = { CanCollide = false, CanTouch = false, CanQuery = false }
G.HIDDEN = { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false }
local DECO, NOCOLLIDE, HIDDEN = G.DECO, G.NOCOLLIDE, G.HIDDEN

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

function G.along(pos, dir)
	return CFrame.fromMatrix(pos, dir, Vector3.yAxis, dir:Cross(Vector3.yAxis))
end
local along = G.along

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

function G.disc(ctx, parent, name, centre, radius, thick, color, material, props)
	local p = mk(ctx, parent, name, Vector3.new(thick, radius * 2, radius * 2), CFrame.new(centre) * CFrame.Angles(0, 0, math.pi / 2), color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local disc = G.disc

function G.ball(ctx, parent, name, centre, d, color, material, props)
	local p = mk(ctx, parent, name, Vector3.new(d, d, d), CFrame.new(centre), color, material, props)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Square bar turned 45 degrees along an edge: reads as a single-face 45-degree cut.
function G.chamfer(ctx, parent, a, b, c, color, material)
	if (b - a).Magnitude < 0.05 then
		return nil
	end
	local cf, len = orient(a, b)
	return mk(ctx, parent, "Chamfer", Vector3.new(len, c * SQ2, c * SQ2), cf * CFrame.Angles(math.pi / 4, 0, 0), color, material, NOCOLLIDE)
end
local chamfer = G.chamfer

-- Regular octagonal column of width w (in the frame `rot`, default world axes).
function G.pillar(ctx, parent, pos, y0, y1, w, color, material, rot)
	local h = y1 - y0
	if h <= 0.05 then
		return nil
	end
	local c = w / (2 + SQ2)
	local base = CFrame.new(pos.X, (y0 + y1) / 2, pos.Z) * (rot or CFrame.identity)
	local m = model(parent, "Pillar")
	mk(ctx, m, "Core", Vector3.new(w - 2 * c, h, w), base, color, material)
	mk(ctx, m, "Core", Vector3.new(w, h, w - 2 * c), base, color, material)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			mk(ctx, m, "Bevel", Vector3.new(c * SQ2, h, c * SQ2), base * CFrame.new(sx * (w / 2 - c), 0, sz * (w / 2 - c)) * CFrame.Angles(0, math.pi / 4, 0), color, material)
		end
	end
	return m
end
local pillar = G.pillar

function G.ibeam(ctx, parent, a, b, depth, width, color, upHint, props)
	if (b - a).Magnitude < 0.05 then
		return nil
	end
	local v = b - a
	local len = v.Magnitude
	local x = v / len
	local up = upHint or (math.abs(x.Y) > 0.95 and Vector3.xAxis or Vector3.yAxis)
	local z = x:Cross(up).Unit
	local y = z:Cross(x)
	local cf = CFrame.fromMatrix((a + b) / 2, x, y, z)
	local m = model(parent, "IBeam")
	mk(ctx, m, "Web", Vector3.new(len, depth, 0.3), cf, color, M.Metal, props)
	mk(ctx, m, "Flange", Vector3.new(len, 0.3, width), cf * CFrame.new(0, depth / 2 - 0.15, 0), color, M.Metal, props)
	mk(ctx, m, "Flange", Vector3.new(len, 0.3, width), cf * CFrame.new(0, -depth / 2 + 0.15, 0), color, M.Metal, props)
	return m
end
local ibeam = G.ibeam

-- ================= WALLS =================
-- Intervals of [0, len] not interrupted by an opening that spans height y.
local function freeAt(gaps, len, y, pad)
	local out, cursor = {}, 0
	for _, g in gaps do
		if y >= g.y0 - 0.01 and y <= g.y1 + 0.01 then
			local a, b = g.s - g.w / 2 - (pad or 0), g.s + g.w / 2 + (pad or 0)
			if a > cursor then
				table.insert(out, { cursor, a })
			end
			cursor = math.max(cursor, b)
		end
	end
	if cursor < len then
		table.insert(out, { cursor, len })
	end
	return out
end

-- An arched, gridded factory window built into the wall at `at(s, y, n)`.
local function window(ctx, m, at, g, style, inwardSign)
	local w, h = g.w, g.y1 - g.y0
	local cy = (g.y0 + g.y1) / 2
	local glass = mk(ctx, m, "Glass", Vector3.new(w, h, 0.15), at(g.s, cy, 0), C.glass, M.Glass, { Transparency = 0.42, Reflectance = 0.04, CastShadow = false, CanQuery = false })
	local cols = math.max(2, math.floor(w / 2.2))
	for i = 1, cols - 1 do
		mk(ctx, m, "Mullion", Vector3.new(0.18, h, 0.4), at(g.s - w / 2 + w * i / cols, cy, 0), C.frame, M.Metal, NOCOLLIDE)
	end
	local rows = math.max(2, math.floor(h / 2.4))
	for i = 1, rows - 1 do
		mk(ctx, m, "Transom", Vector3.new(w, 0.18, 0.4), at(g.s, g.y0 + h * i / rows, 0), C.frame, M.Metal, NOCOLLIDE)
	end
	for _, e in { g.s - w / 2, g.s + w / 2 } do
		mk(ctx, m, "WindowFrame", Vector3.new(0.35, h, 0.55), at(e, cy, 0), C.frame, M.Metal, NOCOLLIDE)
	end
	-- sill and a segmental arch of dark bricks over the head (both faces)
	mk(ctx, m, "Sill", Vector3.new(w + 1.4, 0.55, T + 0.7), at(g.s, g.y0 - 0.27, 0), C.brickDark, M.Brick)
	local chord, rise = w + 1.2, 1.3
	local rad = (chord * chord / 4 + rise * rise) / (2 * rise)
	local half = math.asin((chord / 2) / rad)
	local n = 9
	for i = 0, n - 1 do
		local a = -half + (2 * half) * (i + 0.5) / n
		local x = g.s + math.sin(a) * rad
		local y = g.y1 + (math.cos(a) * rad - (rad - rise)) - 0.1
		local block = 2 * rad * math.sin(half / n) + 0.05
		mk(ctx, m, "Voussoir", Vector3.new(block, 1.15, T + 0.25), at(x, y, 0) * CFrame.Angles(0, 0, -a), C.brickDark, M.Brick, NOCOLLIDE)
	end
	-- daylight: a soft spill inwards and a faint shaft, on every other window
	if g.light then
		local spill = Instance.new("SurfaceLight")
		spill.Face = inwardSign > 0 and Enum.NormalId.Back or Enum.NormalId.Front
		spill.Color = C.daylight
		spill.Range = 24
		spill.Angle = 75
		spill.Brightness = 0.7
		spill.Shadows = false
		spill.Parent = glass
		local top = at(g.s, cy, 0.5).Position
		local bottom = at(g.s, cy - h * 1.3, h * 1.1).Position
		G.lightShaft(ctx, m, top, bottom, w * 0.75, w * 1.3, C.daylight, 0.05)
	end
end

-- Straight wall on the centreline p0 -> p1 (local XZ) from y0 to y1, facing `inward`.
-- gaps: { { s, w, y0, y1, kind = "door" | "open" | "window", light } } (frames for doors
-- are built separately, once per doorway). style: { mat, color, upper = { y, mat, color },
-- plinth, courses = {heights}, pilasters = spacing, topChamfer, bottomChamfer }.
function G.wallRun(ctx, parent, p0, p1, y0, y1, inward, opts)
	opts = opts or {}
	local style = opts.style
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
		if b - a < 0.05 or yb - ya < 0.05 then
			return
		end
		local split = style.upper and style.upper.y
		if split and ya < split and yb > split then
			slab(a, b, ya, split)
			slab(a, b, split, yb)
			return
		end
		local upper = split and ya >= split - 0.01
		mk(ctx, m, "Wall", Vector3.new(b - a, yb - ya, T), at((a + b) / 2, (ya + yb) / 2, 0), upper and style.upper.color or style.color, upper and style.upper.mat or style.mat)
	end

	local gaps = table.clone(opts.gaps or {})
	table.sort(gaps, function(a, b)
		return a.s < b.s
	end)
	local cursor = -ext
	for _, g in gaps do
		local ga, gb = g.s - g.w / 2, g.s + g.w / 2
		slab(cursor, ga, y0, y1)
		if g.y0 > y0 + 0.05 then
			slab(ga, gb, y0, g.y0)
		end
		if g.y1 < y1 - 0.05 then
			slab(ga, gb, g.y1, y1)
		end
		cursor = gb
		if g.kind == "window" then
			window(ctx, m, at, g, style, zs)
		end
	end
	slab(cursor, len + ext, y0, y1)

	-- surface detail on the inside face, only where nothing passes through
	if style.plinth then
		for _, iv in freeAt(gaps, len, floorY + 0.5, 0) do
			local a, b = iv[1], iv[2]
			if b - a > 0.2 then
				mk(ctx, m, "Plinth", Vector3.new(b - a, style.plinth, 0.4), at((a + b) / 2, floorY + style.plinth / 2, face + 0.2), C.plinth, M.Concrete, DECO)
				chamfer(ctx, m, at(a, floorY + style.plinth, face + 0.4).Position, at(b, floorY + style.plinth, face + 0.4).Position, 0.28, C.plinth, M.Concrete)
			end
		end
	end
	for _, cy in style.courses or {} do
		local yy = floorY + cy
		if yy < y1 - 0.5 then
			for _, iv in freeAt(gaps, len, yy, 0) do
				if iv[2] - iv[1] > 0.2 then
					mk(ctx, m, "Course", Vector3.new(iv[2] - iv[1], 0.6, 0.3), at((iv[1] + iv[2]) / 2, yy, face + 0.15), C.brickDark, M.Brick, DECO)
				end
			end
		end
	end
	if style.pilasters then
		-- brick pilasters in the solid stretches between openings
		local all = {}
		for _, g in gaps do
			table.insert(all, { s = g.s, w = g.w + 3, y0 = -math.huge, y1 = math.huge })
		end
		for _, iv in freeAt(all, len, 0, 0) do
			local L = iv[2] - iv[1]
			if L >= 3 then
				local n = math.max(1, math.floor(L / style.pilasters))
				for i = 1, n do
					local s = iv[1] + L * (i - 0.5) / n
					mk(ctx, m, "Pilaster", Vector3.new(1.8, y1 - floorY, 0.7), at(s, (floorY + y1) / 2, face + 0.35), style.color, style.mat, DECO)
				end
			end
		end
	end
	if style.bottomChamfer and opts.floor then
		for _, iv in freeAt(gaps, len, floorY + 0.1, 0) do
			chamfer(ctx, m, at(iv[1], floorY, face).Position, at(iv[2], floorY, face).Position, 0.7, C.plinth, M.Concrete)
		end
	end
	if style.topChamfer then
		chamfer(ctx, m, at(0, y1, face).Position, at(len, y1, face).Position, S.Chamfer, style.upper and style.upper.color or style.color, style.upper and style.upper.mat or style.mat)
	end
	return m
end

-- One standard steel portal per doorway, centred on the shared wall plane at `pos`
-- (floor level), spanning both tiles' walls. dir points through the doorway.
function G.doorway(ctx, parent, pos, dir)
	local m = model(parent, "Doorway")
	local side = dir:Cross(Vector3.yAxis)
	local fd = 2 * T + 1.2
	local function at(u, y)
		return along(Vector3.new(pos.X, y, pos.Z) + side * u, side)
	end
	for _, u in { -(DW / 2 + 0.5), DW / 2 + 0.5 } do
		mk(ctx, m, "Jamb", Vector3.new(1, DH + 1, fd), at(u, pos.Y + (DH + 1) / 2), C.frame, M.Metal)
		mk(ctx, m, "JambPaint", Vector3.new(0.06, 3, fd + 0.02), at(u - math.sign(u) * 0.5, pos.Y + 1.6), C.paintYellowDark, M.Metal, DECO)
	end
	mk(ctx, m, "Head", Vector3.new(DW + 2, 1, fd), at(0, pos.Y + DH + 0.5), C.frame, M.Metal)
	for _, u in { -DW / 2, DW / 2 } do
		mk(ctx, m, "Gusset", Vector3.new(1.3 * SQ2, 1.3 * SQ2, fd), at(u, pos.Y + DH) * CFrame.Angles(0, 0, math.pi / 4), C.frame, M.Metal, DECO)
	end
	mk(ctx, m, "Threshold", Vector3.new(DW + 0.4, 0.14, fd + 1.2), at(0, pos.Y + 0.07), C.plate, M.DiamondPlate)
	return m
end

-- A closed, rusted roller shutter on the inside face of a wall (a socket left unused).
function G.shutter(ctx, parent, pos, inward)
	local m = model(parent, "Shutter")
	local side = inward:Cross(Vector3.yAxis)
	local function at(u, y, n)
		return along(Vector3.new(pos.X, y, pos.Z) + side * u + inward * n, side)
	end
	mk(ctx, m, "Curtain", Vector3.new(DW, DH, 0.25), at(0, pos.Y + DH / 2, 0.15), C.corrugatedRust, M.CorrodedMetal, NOCOLLIDE)
	for i = 1, 6 do
		mk(ctx, m, "Slat", Vector3.new(DW, 0.12, 0.1), at(0, pos.Y + i * DH / 7, 0.32), C.rust, M.Metal, DECO)
	end
	mk(ctx, m, "Housing", Vector3.new(DW + 1.4, 1.6, 1.4), at(0, pos.Y + DH + 0.8, 0.7), C.darkSteel, M.Metal, NOCOLLIDE)
	for _, u in { -(DW / 2 + 0.35), DW / 2 + 0.35 } do
		mk(ctx, m, "Guide", Vector3.new(0.7, DH, 0.7), at(u, pos.Y + DH / 2, 0.35), C.darkSteel, M.Metal, NOCOLLIDE)
	end
	mk(ctx, m, "BottomBar", Vector3.new(DW, 0.35, 0.4), at(0, pos.Y + 0.18, 0.3), C.paintYellowDark, M.Metal, DECO)
	return m
end

-- ================= LIGHT & ATMOSPHERE (all local to the factory) =================
local function lampColor(kind)
	return (kind == "red" and C.red) or (kind == "sodium" and C.sodium) or (kind == "dead" and C.deadBulb) or C.cold
end

function G.rollLamp(rng)
	local r = rng:NextNumber()
	if r < 0.55 then
		return "cold"
	elseif r < 0.82 then
		return "sodium"
	end
	return "dead"
end

function G.lightShaft(ctx, parent, top, bottom, w0, w1, color, alpha)
	local anchor = mk(ctx, parent, "LightShaft", Vector3.new(0.2, 0.2, 0.2), CFrame.new(top), C.black, M.SmoothPlastic, HIDDEN)
	local a0 = Instance.new("Attachment")
	a0.Parent = anchor
	local a1 = Instance.new("Attachment")
	a1.Position = bottom - top
	a1.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - alpha * 0.5),
		NumberSequenceKeypoint.new(0.15, 1 - alpha),
		NumberSequenceKeypoint.new(0.7, 1 - alpha * 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.LightEmission = 0.6
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Width0 = w0
	beam.Width1 = w1
	beam.Parent = anchor
	return beam
end

-- Enamelled high-bay lamp hanging from a roof point.
function G.hangLamp(ctx, parent, pos, kind, opts)
	opts = opts or {}
	local m = model(parent, "Lamp")
	local drop = opts.drop or 1
	local size = opts.size or 2
	local hp = pos - Vector3.new(0, drop, 0)
	if drop > 0.2 then
		cyl(ctx, m, "Rod", pos, hp, 0.14, C.darkSteel, M.Metal, DECO)
	end
	disc(ctx, m, "Cap", hp - Vector3.new(0, 0.25, 0), size * 0.25, 0.5, C.darkSteel, M.Metal, DECO)
	disc(ctx, m, "Shade", hp - Vector3.new(0, 0.7, 0), size * 0.5, 0.45, C.paintGreen, M.Metal, DECO)
	local color = lampColor(kind)
	local bulb = G.ball(ctx, m, "Bulb", hp - Vector3.new(0, 1.05, 0), size * 0.28, color, kind == "dead" and M.Glass or M.Neon, DECO)
	local light
	if kind == "cold" or kind == "sodium" then
		light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Angle = opts.angle or 110
		light.Range = opts.range or 26
		light.Brightness = opts.brightness or (kind == "cold" and 1.6 or 1.3)
	elseif kind == "red" then
		light = Instance.new("PointLight")
		light.Range = opts.range or 12
		light.Brightness = opts.brightness or 1.2
	end
	if light then
		light.Color = color
		light.Shadows = opts.shadows or false
		light.Parent = bulb
		if opts.flicker then
			table.insert(ctx.flicker, { light = light, bulb = bulb })
		end
	end
	if opts.shaft and light then
		G.lightShaft(ctx, m, hp - Vector3.new(0, 1.2, 0), Vector3.new(hp.X, opts.shaftTo or (hp.Y - 14), hp.Z), size * 0.8, opts.shaftWidth or 12, color, opts.shaftAlpha or 0.07)
	end
	return bulb, light
end

-- Caged bulkhead lamp on a wall; kind "red" is the small warning lamp.
function G.wallLamp(ctx, parent, pos, inward, kind, opts)
	opts = opts or {}
	local m = model(parent, "WallLamp")
	local cf = CFrame.lookAt(pos, pos + inward)
	mk(ctx, m, "Plate", Vector3.new(0.8, 1, 0.2), cf * CFrame.new(0, 0, -0.1), C.darkSteel, M.Metal, DECO)
	local color = lampColor(kind)
	local bulb = mk(ctx, m, "Bulb", Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(0, 0, -0.55), color, M.Neon, DECO)
	bulb.Shape = Enum.PartType.Ball
	local glassColor = kind == "red" and Color3.fromRGB(120, 30, 26) or C.glass
	local dome = mk(ctx, m, "Dome", Vector3.new(0.75, 0.75, 0.75), cf * CFrame.new(0, 0, -0.55), glassColor, M.Glass, { Transparency = 0.5, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false })
	dome.Shape = Enum.PartType.Ball
	bar(ctx, m, "Cage", (cf * CFrame.new(-0.42, 0, -0.55)).Position, (cf * CFrame.new(0.42, 0, -0.55)).Position, 0.06, nil, C.darkSteel, M.Metal, DECO)
	bar(ctx, m, "Cage", (cf * CFrame.new(0, -0.42, -0.55)).Position, (cf * CFrame.new(0, 0.42, -0.55)).Position, 0.06, nil, C.darkSteel, M.Metal, DECO)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = opts.range or 12
	light.Brightness = opts.brightness or 1
	light.Shadows = false
	light.Parent = bulb
	if opts.flicker then
		table.insert(ctx.flicker, { light = light, bulb = bulb })
	end
	return bulb, light
end

local function emitter(ctx, parent, name, size, lcf)
	return mk(ctx, parent, name, size, lcf, C.black, M.SmoothPlastic, HIDDEN)
end

function G.steam(ctx, parent, pos, strength, tint)
	local p = emitter(ctx, parent, "Steam", Vector3.new(0.5, 0.5, 0.5), CFrame.lookAt(pos, pos + Vector3.yAxis, Vector3.xAxis))
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(tint or Color3.fromRGB(176, 180, 186))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.84), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 10) })
	e.Lifetime = NumberRange.new(4, 7)
	e.Rate = 4 * (strength or 1)
	e.Speed = NumberRange.new(1.5, 3.5)
	e.SpreadAngle = Vector2.new(14, 14)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-15, 15)
	e.Acceleration = Vector3.new(0, 0.5, 0)
	e.LightInfluence = 1
	e.EmissionDirection = Enum.NormalId.Front
	e.Parent = p
	return p
end

-- Slow, very faint smoke filling a box volume: local haze in big halls.
function G.haze(ctx, parent, lcf, size, rate)
	local p = emitter(ctx, parent, "Haze", size, lcf)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(150, 156, 166))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.93), NumberSequenceKeypoint.new(0.7, 0.93), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new(14, 22)
	e.Lifetime = NumberRange.new(12, 18)
	e.Rate = rate or 1.5
	e.Speed = NumberRange.new(0.2, 0.6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-4, 4)
	e.LightInfluence = 1
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = p
	return p
end

function G.embers(ctx, parent, lcf, size, rate)
	local p = emitter(ctx, parent, "Embers", size, lcf)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 180, 90), Color3.fromRGB(255, 80, 20))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(1, 2.4)
	e.Rate = rate or 8
	e.Speed = NumberRange.new(2, 6)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(0, 2, 0)
	e.Drag = 0.6
	e.EmissionDirection = Enum.NormalId.Top
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = p
	return p
end

function G.glow(ctx, parent, pos, range, brightness, color)
	local p = emitter(ctx, parent, "Glow", Vector3.new(0.3, 0.3, 0.3), CFrame.new(pos))
	local l = Instance.new("PointLight")
	l.Color = color or C.moltenLight
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
	return l
end

function G.moltenZone(ctx, parent, lcf, size, shape)
	local z = mk(ctx, parent, "MoltenZone", size, lcf, C.black, M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = true, CastShadow = false })
	if shape then
		z.Shape = shape
	end
	table.insert(ctx.molten, z)
	return z
end

-- Raised trough of molten steel from a to b at floor y, with plate crossings at `bridgesAt`.
function G.moltenChannel(ctx, parent, a, b, y, width, bridgesAt)
	local m = model(parent, "MoltenChannel")
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	local dir = flat / len
	local side = dir:Cross(Vector3.yAxis)
	local function pt(s, u, yy)
		local p = a + dir * s + side * u
		return Vector3.new(p.X, yy, p.Z)
	end
	for _, sg in { -1, 1 } do
		mk(ctx, m, "Curb", Vector3.new(len, 0.6, 0.9), along(pt(len / 2, sg * (width / 2 + 0.45), y + 0.3), dir), C.slag, M.Basalt)
		chamfer(ctx, m, pt(0, sg * (width / 2 + 0.9), y + 0.6), pt(len, sg * (width / 2 + 0.9), y + 0.6), 0.3, C.slag, M.Basalt)
	end
	mk(ctx, m, "Bed", Vector3.new(len, 0.3, width), along(pt(len / 2, 0, y + 0.15), dir), C.slag, M.CrackedLava)
	mk(ctx, m, "Molten", Vector3.new(len, 0.1, width - 0.2), along(pt(len / 2, 0, y + 0.42), dir), C.molten, M.Neon, NOCOLLIDE)
	mk(ctx, m, "Crust", Vector3.new(len, 0.12, width * 0.25), along(pt(len / 2, width * 0.25, y + 0.44), dir), C.slag, M.Basalt, DECO)
	local n = math.max(1, math.floor(len / 10))
	for i = 0, n do
		G.glow(ctx, m, pt(len * i / n, 0, y + 1.6), 18, 1.8)
	end
	G.embers(ctx, m, along(pt(len / 2, 0, y + 0.6), dir), Vector3.new(len, 0.2, width), math.floor(len / 4))
	G.moltenZone(ctx, m, along(pt(len / 2, 0, y + 1.5), dir), Vector3.new(len, 2.6, width))
	for _, s in bridgesAt or {} do
		mk(ctx, m, "Crossing", Vector3.new(3.4, 0.3, width + 3), along(pt(s, 0, y + 0.75), dir), C.plate, M.DiamondPlate)
	end
	return m
end

function G.moltenPool(ctx, parent, c, r, y)
	local m = model(parent, "MoltenPool")
	disc(ctx, m, "Rim", Vector3.new(c.X, y + 0.3, c.Z), r + 1.6, 0.6, C.slag, M.CrackedLava)
	disc(ctx, m, "Molten", Vector3.new(c.X, y + 0.66, c.Z), r, 0.1, C.molten, M.Neon, NOCOLLIDE)
	disc(ctx, m, "Crust", Vector3.new(c.X + r * 0.3, y + 0.69, c.Z - r * 0.2), r * 0.35, 0.1, C.slag, M.Basalt, DECO)
	G.glow(ctx, m, Vector3.new(c.X, y + 3, c.Z), r * 3 + 14, 2.6)
	for i = 0, 2 do
		local a = i * TAU / 3
		G.glow(ctx, m, Vector3.new(c.X + math.cos(a) * r * 0.8, y + 1.5, c.Z + math.sin(a) * r * 0.8), 18, 1.4)
	end
	G.embers(ctx, m, CFrame.new(c.X, y + 0.8, c.Z), Vector3.new(r * 1.4, 0.2, r * 1.4), 12)
	G.steam(ctx, m, Vector3.new(c.X, y + 1, c.Z), 1, Color3.fromRGB(140, 110, 96))
	G.moltenZone(ctx, m, CFrame.new(c.X, y + 2, c.Z) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(4, r * 2, r * 2), Enum.PartType.Cylinder)
	return m
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
	return disc(ctx, parent, "Puddle", pos + Vector3.new(0, 0.03, 0), r, 0.04, Color3.fromRGB(26, 27, 28), M.SmoothPlastic, { Reflectance = 0.08, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false })
end

function G.coil(ctx, parent, pos, axis, r, len, hot)
	local m = model(parent, "Coil")
	local c = pos + Vector3.new(0, r, 0)
	cyl(ctx, m, "Coil", c - axis * (len / 2), c + axis * (len / 2), r * 2, hot and C.rust or C.coil, M.Metal)
	cyl(ctx, m, "Bore", c - axis * (len / 2 + 0.02), c + axis * (len / 2 + 0.02), r * 0.7, C.black, M.SmoothPlastic, DECO)
	cyl(ctx, m, "Band", c - axis * 0.15, c + axis * 0.15, r * 2 + 0.06, C.darkSteel, M.Metal, DECO)
	if hot then
		cyl(ctx, m, "HotFace", c - axis * (len / 2 + 0.01), c + axis * (len / 2 + 0.01), r * 1.4, C.molten, M.Neon, DECO)
		G.glow(ctx, m, c, 12, 1)
	end
	return m
end

function G.crate(ctx, parent, pos, size, yaw, metal)
	local m = model(parent, "Crate")
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
	mk(ctx, m, "Body", size - Vector3.new(0.1, 0, 0.1), cf * CFrame.new(0, size.Y / 2, 0), metal and C.steel or C.wood, metal and M.DiamondPlate or M.WoodPlanks)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			mk(ctx, m, "Edge", Vector3.new(0.28, size.Y, 0.28), cf * CFrame.new(sx * (size.X / 2 - 0.12), size.Y / 2, sz * (size.Z / 2 - 0.12)), C.darkSteel, M.Metal, DECO)
		end
	end
	return cf * CFrame.new(0, size.Y, 0)
end

function G.barrel(ctx, parent, pos, color)
	local h, r = 3.1, 1.05
	local m = model(parent, "Drum")
	disc(ctx, m, "Body", pos + Vector3.new(0, h / 2, 0), r, h, color, M.CorrodedMetal)
	disc(ctx, m, "Band", pos + Vector3.new(0, h * 0.3, 0), r + 0.05, 0.2, C.darkSteel, M.Metal, DECO)
	disc(ctx, m, "Band", pos + Vector3.new(0, h * 0.7, 0), r + 0.05, 0.2, C.darkSteel, M.Metal, DECO)
end

-- Horizontal tank on two cradles, axis along `axis`.
function G.tank(ctx, parent, pos, axis, r, len, color)
	local m = model(parent, "Tank")
	local c = pos + Vector3.new(0, r + 1, 0)
	cyl(ctx, m, "Shell", c - axis * (len / 2), c + axis * (len / 2), r * 2, color or C.paintRed, M.CorrodedMetal)
	for _, e in { -1, 1 } do
		cyl(ctx, m, "Head", c + axis * (e * len / 2), c + axis * (e * (len / 2 + 0.6)), r * 1.7, color or C.paintRed, M.CorrodedMetal)
		local cp = c + axis * (e * len * 0.3)
		mk(ctx, m, "Cradle", Vector3.new(r * 1.8, r + 1, 1), along(Vector3.new(cp.X, (r + 1) / 2, cp.Z), axis:Cross(Vector3.yAxis)) + Vector3.new(0, pos.Y, 0), C.darkSteel, M.Metal)
	end
	for i = 1, 3 do
		cyl(ctx, m, "Band", c + axis * ((i - 2) * len / 3 - 0.15), c + axis * ((i - 2) * len / 3 + 0.15), r * 2 + 0.08, C.darkSteel, M.Metal, DECO)
	end
	cyl(ctx, m, "Manway", c + Vector3.new(0, r - 0.2, 0), c + Vector3.new(0, r + 0.6, 0), 1.4, C.darkSteel, M.Metal, DECO)
	return m
end

function G.lootSpot(ctx, parent, pos, area, primary)
	local top = G.crate(ctx, parent, pos, Vector3.new(2.4, 1.7, 2.4), ctx.rng:NextNumber(0, TAU), true)
	table.insert(ctx.loot, { cf = top, area = area, primary = primary })
	return top
end

-- ================= RAILINGS, STAIRS, DECKS =================
local RAIL_H = 3.5

-- Weathered painted-steel handrail along a polyline of floor points, with an invisible
-- guard so nobody slips through.
function G.railing(ctx, parent, pts, opts)
	opts = opts or {}
	local m = model(parent, "Railing")
	local h = RAIL_H
	local paint = opts.color or C.paintYellow
	local function post(p)
		mk(ctx, m, "Post", Vector3.new(0.26, h, 0.26), CFrame.new(p + Vector3.new(0, h / 2, 0)), C.paintYellowDark, M.Metal, DECO)
	end
	post(pts[1])
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local len = (b - a).Magnitude
		if len > 0.05 then
			local n = math.max(1, math.ceil(len / 4))
			for j = 1, n do
				post(a:Lerp(b, j / n))
			end
			local up, mid = Vector3.new(0, h, 0), Vector3.new(0, h * 0.5, 0)
			cyl(ctx, m, "Rail", a + up, b + up, 0.24, paint, M.Metal, DECO)
			cyl(ctx, m, "MidRail", a + mid, b + mid, 0.18, paint, M.Metal, DECO)
			if not opts.noKick then
				bar(ctx, m, "Kick", a + Vector3.new(0, 0.2, 0), b + Vector3.new(0, 0.2, 0), 0.1, 0.4, C.darkSteel, M.Metal, DECO)
			end
			local cf = orient(a + mid, b + mid)
			mk(ctx, m, "Guard", Vector3.new(len, h, 0.3), cf, C.black, M.SmoothPlastic, { Transparency = 1, CastShadow = false, CanTouch = false, CanQuery = false })
		end
	end
	return m
end
local railing = G.railing

-- Railing from p0 to p1 leaving openings: gaps = { { at = distance from p0, w } }.
function G.railGaps(ctx, parent, p0, p1, gaps)
	local len = (p1 - p0).Magnitude
	if len < 0.1 then
		return
	end
	local dir = (p1 - p0) / len
	table.sort(gaps, function(a, b)
		return a.at < b.at
	end)
	local cursor = 0
	for _, g in gaps do
		local a, b = math.max(0, g.at - g.w / 2), math.min(len, g.at + g.w / 2)
		if a - cursor > 0.4 then
			railing(ctx, parent, { p0 + dir * cursor, p0 + dir * a })
		end
		cursor = math.max(cursor, b)
	end
	if len - cursor > 0.4 then
		railing(ctx, parent, { p0 + dir * cursor, p1 })
	end
end

-- Open steel stair flight: diamond-plate treads on two stringers. `foot` is the floor point
-- at the bottom centre, `dir` the climbing direction, `rise` may be negative (then `foot`
-- is the top). Handrails on the sides listed in rails ({ left = true, right = true }).
-- Returns the top and bottom floor points so callers can line up landings.
function G.flight(ctx, parent, foot, dir, run, rise, width, rails)
	local m = model(parent, "StairFlight")
	if rise < 0 then
		foot = foot + dir * run + Vector3.new(0, rise, 0)
		dir = -dir
		rise = -rise
	end
	local n = math.max(1, math.ceil(rise / 0.7))
	local depth = run / n
	local side = dir:Cross(Vector3.yAxis)
	for k = 0, n - 1 do
		local top = foot.Y + rise * (k + 1) / n
		local c = foot + dir * (depth * (k + 0.5))
		mk(ctx, m, "Tread", Vector3.new(depth + 0.05, 0.4, width), along(Vector3.new(c.X, top - 0.2, c.Z), dir), C.plate, M.DiamondPlate)
		local edge = foot + dir * (depth * k + 0.12)
		bar(ctx, m, "Nosing", Vector3.new(edge.X, top + 0.01, edge.Z) - side * (width / 2 - 0.4), Vector3.new(edge.X, top + 0.01, edge.Z) + side * (width / 2 - 0.4), 0.2, 0.04, C.paintYellowDark, M.Metal, DECO)
	end
	local topP = foot + dir * run + Vector3.new(0, rise, 0)
	for _, sg in { -1, 1 } do
		local o = side * (sg * (width / 2 + 0.2))
		G.ibeam(ctx, m, foot + o - Vector3.new(0, 0.6, 0), topP + o - Vector3.new(0, 0.6, 0), 1, 0.4, C.darkSteel, nil, NOCOLLIDE)
	end
	if rise > 6 then
		for _, sg in { -1, 1 } do
			local p = topP - dir * (run * 0.15) + side * (sg * (width / 2 + 0.2))
			mk(ctx, m, "Post", Vector3.new(0.6, rise - 1, 0.6), CFrame.new(p.X, foot.Y + (rise - 1) / 2, p.Z), C.darkSteel, M.Metal)
		end
	end
	for name, sg in { left = 1, right = -1 } do
		if rails and rails[name] then
			local pts = {}
			for k = 0, n - 1 do
				local c = foot + dir * (depth * (k + 0.5)) + side * (sg * (width / 2 - 0.2))
				table.insert(pts, Vector3.new(c.X, foot.Y + rise * (k + 1) / n, c.Z))
			end
			railing(ctx, m, pts, { noKick = true })
		end
	end
	return topP, foot
end

-- Flat steel deck (top surface at y) with an edge angle round it.
function G.deck(ctx, parent, lcf, sx, sz)
	local m = model(parent, "Deck")
	mk(ctx, m, "Plate", Vector3.new(sx, 0.5, sz), lcf * CFrame.new(0, -0.25, 0), C.plate, M.DiamondPlate)
	for _, e in { { 0, sz / 2, sx, 0.3 }, { 0, -sz / 2, sx, 0.3 }, { sx / 2, 0, 0.3, sz }, { -sx / 2, 0, 0.3, sz } } do
		mk(ctx, m, "Edge", Vector3.new(e[3], 0.9, e[4]), lcf * CFrame.new(e[1], -0.7, e[2]), C.darkSteel, M.Metal, NOCOLLIDE)
	end
	return m
end

return G
