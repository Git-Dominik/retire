-- Builders for each room in the factory plan (see Layout). They all take
-- (ctx, parent, roomData) and register loot surfaces in ctx.loot.

local CollectionService = game:GetService("CollectionService")

local Config = require(script.Parent.Config)
local G = require(script.Parent.Geometry)

local S = Config.Settings
local C = Config.Colors
local STYLE = Config.Styles
local M = Enum.Material

local T = S.Wall
local CW = S.CorridorWidth
local TAU = math.pi * 2

local mk, model, flatAt, dirOf, tangOf, along = G.mk, G.model, G.flatAt, G.dirOf, G.tangOf, G.along
local cyl, bar, disc, chamfer, pillar = G.cyl, G.bar, G.disc, G.chamfer, G.pillar
local railing, railWithGap, stairs = G.railing, G.railWithGap, G.stairs
local hangLamp, wallLamp = G.hangLamp, G.wallLamp
local DECO = G.DECO

local Rooms = {}

local function angleDiff(a, b)
	return math.abs((a - b + math.pi) % TAU - math.pi)
end

-- ================= START BAY (orange) =================
function Rooms.start(ctx, parent, s)
	local rng = ctx.rng
	local m = G.boxRoom(ctx, parent, {
		name = "StartBay", c = s.c, W = s.W, D = s.D, y = 0, h = s.h,
		open = { S = true }, -- the elevator facade is the fourth wall
		doors = { { side = "N", off = 0 } },
	})
	local hw = s.W / 2
	-- hazard band where the elevator doors open
	local tiles = math.floor(s.W / 1.2)
	for i = 0, tiles - 1 do
		local x = -s.W / 2 + 0.6 + i * 1.2
		mk(ctx, m, "Hazard", Vector3.new(1.2, 0.04, 0.8), CFrame.new(x, 0.02, 0.6), i % 2 == 0 and C.yellow or C.black, M.SmoothPlastic, DECO)
	end
	G.sign(ctx, m, Vector3.new(0, S.DoorHeight + 1.4, s.D - 0.45), Vector3.new(0, 0, -1), Vector3.new(7.5, 1.3, 0.1), "SUB-LEVEL 1  ·  FOUNDRY", C.signText, C.signPlate)
	hangLamp(ctx, m, Vector3.new(-hw / 2, s.h, s.D / 2), "cold", { drop = 0.8, flicker = rng:NextNumber() < 0.5 })
	hangLamp(ctx, m, Vector3.new(hw / 2, s.h, s.D / 2), rng:NextNumber() < 0.3 and "dead" or "cold", { drop = 0.8 })
	wallLamp(ctx, m, Vector3.new(CW / 2 + 1.5, S.DoorHeight - 1, s.D - 0.55), Vector3.new(0, 0, -1), "red", { range = 10, brightness = 2 })
	for _, sx in { -1, 1 } do
		local x = sx * (hw - 1.6)
		if rng:NextNumber() < 0.7 then
			G.barrel(ctx, m, Vector3.new(x, 0, rng:NextNumber(2.5, s.D - 2.5)), rng:NextNumber() < 0.5 and C.rust or C.steel)
		elseif rng:NextNumber() < 0.6 then
			G.crate(ctx, m, Vector3.new(x, 0, rng:NextNumber(2.5, s.D - 2.5)), Vector3.new(2.4, 2.2, 2.4), rng:NextNumber(-0.3, 0.3), "wood")
		end
	end
	local px = (rng:NextNumber() < 0.5 and -1 or 1) * (hw - 1.1)
	cyl(ctx, m, "Pipe", Vector3.new(px, s.h - 1.4, 0), Vector3.new(px, s.h - 1.4, s.D), 0.8, C.pipe, M.CorrodedMetal, DECO)
	for _ = 1, rng:NextInteger(1, 3) do
		G.puddle(ctx, m, Vector3.new(rng:NextNumber(-hw + 2, hw - 2), 0, rng:NextNumber(2, s.D - 2)), rng:NextNumber(0.8, 2))
	end
	return m
end

-- ================= HUB (red) =================
-- Round turbine hall on three tiers: ground floor with the boiler, a catwalk ring at
-- CatwalkHeight (reached by curved stairs, joined to a platform round the boiler, and
-- leading to the depot), and a high bridge at BridgeHeight reached by a ladder.
function Rooms.hub(ctx, parent, hub)
	local rng = ctx.rng
	local m = model(parent, "Hub")
	local c, R, y = hub.c, hub.R, hub.y
	local N = S.HubSides
	local half = math.pi / N
	local phase = -math.pi / 2
	local yc = y + S.CatwalkHeight
	local yTop = y + S.HubHeight
	local function segAng(k)
		return phase + (k % N) * TAU / N
	end
	local function at(a, r, yy)
		return Vector3.new(c.X + math.cos(a) * r, yy, c.Z + math.sin(a) * r)
	end
	local outer = (R + T) / math.cos(half) + 0.5

	disc(ctx, m, "Floor", Vector3.new(c.X, y - 0.5, c.Z), outer, 1, C.floor, M.Concrete, nil)
	disc(ctx, m, "Ceiling", Vector3.new(c.X, yTop + 0.5, c.Z), outer, 1, C.ceiling, M.Concrete)
	G.polyWalls(ctx, m, c, R, N, phase, y - 1, yTop, y, hub.doors, STYLE.hub)

	-- octagonal pillars at the inner corners, red beacons on some of them
	for k = 0, N - 1 do
		local a = segAng(k) + half
		if not hub.doors[k] and not hub.doors[(k + 1) % N] then
			pillar(ctx, m, at(a, R / math.cos(half) - 0.3, 0), y, yTop, 1.8, C.pillar, M.Concrete)
			if k % 5 == 1 then
				wallLamp(ctx, m, at(a, R / math.cos(half) - 1.3, yc + 3.2), -dirOf(a), "red", { range = 7, brightness = 0.9, flicker = rng:NextNumber() < 0.3 })
			end
		end
	end

	-- catwalk ring
	local ri, ro = R - 4.2, R + 0.3
	for k = 0, N - 1 do
		local a = segAng(k)
		local radial, tang = dirOf(a), tangOf(a)
		local mid = c + radial * ((ri + ro) / 2)
		mk(ctx, m, "Catwalk", Vector3.new(2 * ro * math.tan(half) + 0.1, 0.4, ro - ri), along(flatAt(mid, yc - 0.2), tang), C.grate, M.DiamondPlate)
		local hl = ri * math.tan(half)
		local p0 = flatAt(c + radial * ri - tang * hl, yc)
		local p1 = flatAt(c + radial * ri + tang * hl, yc)
		if k == hub.stairSeg or k == hub.bridgeSeg then
			railWithGap(ctx, m, p0, p1, hl, 3.2)
		else
			railing(ctx, m, { p0, p1 })
		end
		if k % 2 == 0 and not hub.doors[k] then
			local sp = c + radial * (ri + 0.5)
			mk(ctx, m, "CatwalkPost", Vector3.new(0.5, yc - 0.4 - y, 0.5), CFrame.new(sp.X, (y + yc - 0.4) / 2, sp.Z), C.steel, M.Metal)
			bar(ctx, m, "Knee", at(a, R, yc - 3.4), at(a, R - 3.2, yc - 0.4), 0.4, nil, C.steel, M.Metal, DECO)
		end
	end

	-- curved stairs from the floor up to the catwalk
	do
		local sm = model(m, "CatwalkStairs")
		local rs = R - 6
		local n = math.ceil(S.CatwalkHeight / 0.7)
		local dA = 1.3 / rs
		local aTop = segAng(hub.stairSeg)
		local inner, outerPts = {}, {}
		for k = 0, n - 1 do
			local a = aTop - hub.stairDir * (n - 1 - k) * dA
			local tread = y + S.CatwalkHeight * (k + 1) / n
			local p = c + dirOf(a) * rs
			local cf = along(Vector3.new(p.X, (tread + y - 0.2) / 2, p.Z), tangOf(a))
			mk(ctx, sm, "Step", Vector3.new(1.36, tread - y + 0.2, 3.6), cf, C.pillar, M.Concrete)
			mk(ctx, sm, "Nosing", Vector3.new(0.16, 0.06, 3.2), along(Vector3.new(p.X, tread + 0.02, p.Z), tangOf(a)) * CFrame.new(-hub.stairDir * 0.6, 0, 0), C.yellow, M.SmoothPlastic, DECO)
			table.insert(inner, at(a, rs - 1.6, tread))
			if k < n - 2 then
				table.insert(outerPts, at(a, rs + 1.6, tread))
			end
		end
		railing(ctx, sm, inner, { noKick = true })
		if #outerPts > 1 then
			railing(ctx, sm, outerPts, { noKick = true })
		end
	end

	-- boiler, its platform at catwalk height, and the bridge across to it
	local bm = model(m, "Boiler")
	local rb = hub.boilerR
	local bh = S.CatwalkHeight + 4.5
	disc(ctx, bm, "Plinth", Vector3.new(c.X, y + 0.4, c.Z), rb + 0.8, 0.8, C.pillar, M.Concrete)
	disc(ctx, bm, "Tank", Vector3.new(c.X, y + 0.8 + bh / 2, c.Z), rb, bh, C.boiler, M.CorrodedMetal)
	for i = 1, 4 do
		disc(ctx, bm, "Band", Vector3.new(c.X, y + 0.8 + bh * i / 5, c.Z), rb + 0.08, 0.35, C.darkSteel, M.Metal, DECO)
	end
	disc(ctx, bm, "Cap", Vector3.new(c.X, y + 0.8 + bh + 0.4, c.Z), rb * 0.8, 0.8, C.boiler, M.CorrodedMetal)
	disc(ctx, bm, "Cap", Vector3.new(c.X, y + 0.8 + bh + 1.1, c.Z), rb * 0.5, 0.6, C.boiler, M.CorrodedMetal)
	cyl(ctx, bm, "Flue", Vector3.new(c.X, y + bh + 1.4, c.Z), Vector3.new(c.X, yTop, c.Z), 1.6, C.pipe, M.CorrodedMetal)
	G.steam(ctx, bm, Vector3.new(c.X + rb * 0.5, y + bh + 1.6, c.Z), Vector3.yAxis, 1.2)
	local ga = rng:NextNumber(0, TAU)
	cyl(ctx, bm, "Gauge", at(ga, rb - 0.05, y + 4.5), at(ga, rb + 0.15, y + 4.5), 1.1, C.signText, M.SmoothPlastic, DECO)

	local pr0, pr1 = rb + 0.1, rb + 2.6
	local aB = segAng(hub.bridgeSeg)
	for k = 0, 11 do
		local a = k * TAU / 12
		local radial, tang = dirOf(a), tangOf(a)
		local mid = c + radial * ((pr0 + pr1) / 2)
		mk(ctx, bm, "Platform", Vector3.new(2 * pr1 * math.tan(math.pi / 12) + 0.1, 0.4, pr1 - pr0), along(flatAt(mid, yc - 0.2), tang), C.grate, M.DiamondPlate)
		if angleDiff(a, aB) > 0.4 then
			local hl = pr1 * math.tan(math.pi / 12)
			railing(ctx, bm, { flatAt(c + radial * pr1 - tang * hl, yc), flatAt(c + radial * pr1 + tang * hl, yc) })
		end
		if k % 3 == 0 then
			local sp = c + radial * (pr1 - 0.4)
			mk(ctx, bm, "PlatformPost", Vector3.new(0.45, yc - 0.4 - y, 0.45), CFrame.new(sp.X, (y + yc - 0.4) / 2, sp.Z), C.steel, M.Metal)
		end
	end
	do
		local radial = dirOf(aB)
		local b0, b1 = c + radial * (pr1 - 0.2), c + radial * (ri + 0.2)
		mk(ctx, bm, "Bridge", Vector3.new((b1 - b0).Magnitude, 0.4, 2.6), along(flatAt((b0 + b1) / 2, yc - 0.2), radial), C.grate, M.DiamondPlate)
		local side = tangOf(aB)
		for _, sgn in { 1, -1 } do
			railing(ctx, bm, { flatAt(b0 + side * (1.3 * sgn), yc), flatAt(b1 + side * (1.3 * sgn), yc) })
		end
	end

	-- high bridge across the hall, reached by a ladder from the catwalk
	do
		local hm = model(m, "HighBridge")
		local yb = y + S.BridgeHeight
		local u = dirOf(hub.highAngle)
		local perp = tangOf(hub.highAngle)
		local off = hub.highOffset
		local halfL = math.sqrt(math.max(R * R - off * off, 4)) + 0.3
		local m0 = c + perp * off
		local e0, e1 = m0 - u * halfL, m0 + u * halfL
		mk(ctx, hm, "Deck", Vector3.new(halfL * 2, 0.4, 2.6), along(flatAt(m0, yb - 0.2), u), C.grate, M.DiamondPlate)
		for _, sgn in { 1, -1 } do
			bar(ctx, hm, "Stringer", flatAt(e0 + perp * (1.2 * sgn), yb - 0.7), flatAt(e1 + perp * (1.2 * sgn), yb - 0.7), 0.3, 0.6, C.steel, M.Metal)
		end
		local hangers = math.floor(halfL * 2 / 5)
		for i = 1, hangers do
			local p = e0:Lerp(e1, i / (hangers + 1))
			for _, sgn in { 1, -1 } do
				cyl(ctx, hm, "Hanger", flatAt(p + perp * (1.25 * sgn), yb), flatAt(p + perp * (1.25 * sgn), yTop), 0.18, C.darkSteel, M.Metal, DECO)
			end
		end
		-- ladder spot: beside the deck, standing on the catwalk, clear of doors and stairs
		local best
		for _, cand in { { e0, u }, { e1, -u } } do
			for _, sgnL in { 1, -1 } do
				for t = 1, 9, 0.25 do
					local p = cand[1] + cand[2] * t + perp * (2.3 * sgnL)
					local r = (flatAt(p, 0) - c).Magnitude
					if r <= R - 1.3 and r >= ri + 1.1 then
						local a = math.atan2(p.Z - c.Z, p.X - c.X)
						local ok = true
						for _, k in { 4, hub.stairSeg, hub.bridgeSeg } do
							if angleDiff(a, segAng(k)) < 0.45 then
								ok = false
							end
						end
						if ok then
							best = { p = p, sgnL = sgnL }
						end
						break
					end
				end
				if best then
					break
				end
			end
			if best then
				break
			end
		end
		if best then
			local hgt = 2 * math.ceil((yb - yc + 0.6) / 2)
			mk(ctx, hm, "Ladder", Vector3.new(2, hgt, 2), CFrame.new(best.p.X, yc + hgt / 2, best.p.Z) * CFrame.Angles(0, hub.highAngle, 0), C.steel, M.Metal, nil, "TrussPart")
		end
		for _, sgn in { 1, -1 } do
			local o = perp * (1.3 * sgn)
			local a0, a1 = flatAt(e0 + o, yb), flatAt(e1 + o, yb)
			if best and best.sgnL == sgn then
				railWithGap(ctx, hm, a0, a1, (best.p - e0):Dot(u), 2.6)
			else
				railing(ctx, hm, { a0, a1 })
			end
		end
		G.lootSpot(ctx, hm, flatAt(m0 + u * rng:NextNumber(-halfL * 0.4, halfL * 0.4), yb), "HubBridge", true)
	end

	-- pipework: risers along the walls, a ring main under the roof, feeds off the boiler
	local busy = {}
	for k in hub.doors do
		busy[k] = true
	end
	for j = 0, 5 do
		busy[(hub.stairSeg - hub.stairDir * j) % N] = true
	end
	busy[hub.bridgeSeg] = true
	for k = 0, N - 1 do
		local a = segAng(k)
		if not busy[k] and rng:NextNumber() < 0.45 then
			local d = rng:NextNumber(0.7, 1.2)
			local p = at(a, R - 0.5 - d / 2, y) + tangOf(a) * rng:NextNumber(-2, 2)
			local topY = yTop - 2.5
			cyl(ctx, m, "Riser", p, flatAt(p, topY), d, rng:NextNumber() < 0.5 and C.pipe or C.copper, M.CorrodedMetal)
			local elbowBall = mk(ctx, m, "Elbow", Vector3.new(d + 0.15, d + 0.15, d + 0.15), CFrame.new(flatAt(p, topY)), C.darkSteel, M.Metal, DECO)
			elbowBall.Shape = Enum.PartType.Ball
			cyl(ctx, m, "Riser", flatAt(p, topY), flatAt(p + dirOf(a) * 1.5, topY), d, C.pipe, M.CorrodedMetal, DECO)
		end
	end
	local mainR = (R - 0.8) / math.cos(half)
	for k = 0, N - 1 do
		local a0, a1 = segAng(k) - half, segAng(k) + half
		cyl(ctx, m, "RingMain", at(a0, mainR, yTop - 3), at(a1, mainR, yTop - 3), 1.1, C.copper, M.Metal, DECO)
		local j = mk(ctx, m, "Joint", Vector3.new(1.35, 1.35, 1.35), CFrame.new(at(a1, mainR, yTop - 3)), C.darkSteel, M.Metal, DECO)
		j.Shape = Enum.PartType.Ball
	end
	for _ = 1, rng:NextInteger(3, 4) do
		local k = rng:NextInteger(0, N - 1)
		if not busy[k] then
			local a = segAng(k) + rng:NextNumber(-0.15, 0.15)
			local yy = y + rng:NextNumber(5.6, 7.6)
			local d = rng:NextNumber(0.6, 1)
			cyl(ctx, m, "Feed", at(a, rb - 0.1, yy), at(a, R + 0.2, yy), d, rng:NextNumber() < 0.5 and C.pipe or C.copper, M.CorrodedMetal)
			cyl(ctx, m, "Flange", at(a, rb + 0.1, yy), at(a, rb + 0.5, yy), d + 0.4, C.darkSteel, M.Metal, DECO)
			local mid = at(a, (rb + R) / 2, yy)
			if rng:NextNumber() < 0.5 then
				cyl(ctx, m, "ValveStem", mid, mid + Vector3.new(0, d / 2 + 0.6, 0), 0.2, C.darkSteel, M.Metal, DECO)
				disc(ctx, m, "ValveWheel", mid + Vector3.new(0, d / 2 + 0.6, 0), 0.7, 0.12, C.red, M.Metal, DECO)
			end
			if rng:NextNumber() < 0.4 then
				G.steam(ctx, m, mid + Vector3.new(0, d / 2, 0), Vector3.yAxis, 0.6)
			end
		end
	end

	-- light: three cold floods from the roof, sodium lamps over the ground doorways
	for i = 0, 2 do
		local a = hub.floodPhase + i * TAU / 3
		hangLamp(ctx, m, at(a, R * 0.55, yTop), "cold", { drop = 3, range = 48, angle = 70, brightness = 2.4, shadows = true, size = 2.4 })
	end
	for k, door in hub.doors do
		local a = segAng(k)
		wallLamp(ctx, m, at(a, R - 0.6, door.y0 + S.DoorHeight + 1.3), -dirOf(a), "sodium", { range = 12, brightness = 0.9 })
	end

	-- wet floor, a couple of steaming floor vents
	for _ = 1, rng:NextInteger(5, 8) do
		local a, r = rng:NextNumber(0, TAU), rng:NextNumber(rb + 2, R - 1.5)
		G.puddle(ctx, m, at(a, r, y), rng:NextNumber(0.8, 2.2))
	end
	for _ = 1, 2 do
		local a, r = rng:NextNumber(0, TAU), rng:NextNumber(rb + 2.5, R - 6)
		local p = at(a, r, y)
		mk(ctx, m, "Vent", Vector3.new(1.6, 0.06, 1.6), CFrame.new(p + Vector3.new(0, 0.03, 0)), C.drain, M.DiamondPlate, DECO)
		G.steam(ctx, m, p + Vector3.new(0, 0.2, 0), Vector3.yAxis, 0.7)
	end

	-- machinery hum
	local spk = mk(ctx, m, "Ambience", Vector3.new(1, 1, 1), CFrame.new(c.X, y + 6, c.Z), C.black, M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local hum = Instance.new("Sound")
	hum.Name = "FactoryHum"
	hum.SoundId = S.AmbientSound
	hum.Looped = true
	hum.Volume = 0.35
	hum.RollOffMinDistance = 20
	hum.RollOffMaxDistance = 140
	hum.Playing = true
	hum.Parent = spk

	-- loot on the catwalk and on the ground floor
	local free = {}
	for k = 0, N - 1 do
		if not busy[k] then
			table.insert(free, k)
		end
	end
	if #free > 0 then
		local k = free[rng:NextInteger(1, #free)]
		G.lootSpot(ctx, m, at(segAng(k), (ri + ro) / 2 - 0.3, yc), "HubCatwalk", true)
		local k2 = free[rng:NextInteger(1, #free)]
		G.lootSpot(ctx, m, at(segAng(k2) + half * 0.5, R - 2.2, y), "HubFloor", false)
	end
	return m
end

-- ================= MULTI-FLOOR PIT (blue inside green ring) =================
-- A catwalk ring at corridor level around a pit that drops to a flooded basement.
-- A spiral of cantilevered treads hugs the pit wall on the way down.
function Rooms.ring(ctx, parent, ring)
	local rng = ctx.rng
	local m = model(parent, "PitRing")
	local c, Ro, y, depth = ring.c, ring.Ro, ring.y, ring.depth
	local N = S.RingSides
	local half = math.pi / N
	local phase = ring.doorAngle
	local yTop = y + S.RingHeight
	local Rp = Ro - S.RingWalk
	local yP = y - depth
	local function segAng(k)
		return phase + (k % N) * TAU / N
	end
	local function at(a, r, yy)
		return Vector3.new(c.X + math.cos(a) * r, yy, c.Z + math.sin(a) * r)
	end

	disc(ctx, m, "Ceiling", Vector3.new(c.X, yTop + 0.5, c.Z), (Ro + T) / math.cos(half) + 0.5, 1, C.ceiling, M.Concrete)
	G.polyWalls(ctx, m, c, Ro, N, phase, y - 1, yTop, y, { [0] = { y0 = y } }, STYLE.room)
	G.polyWalls(ctx, m, c, Rp, N, phase, yP - 1, y - 1, yP, nil, STYLE.pit)
	disc(ctx, m, "PitFloor", Vector3.new(c.X, yP - 0.5, c.Z), (Rp + T) / math.cos(half) + 0.3, 1, C.floor, M.Concrete)
	disc(ctx, m, "Floodwater", Vector3.new(c.X, yP + 0.35, c.Z), Rp / math.cos(half), 0.3, C.water, M.Glass, {
		Transparency = 0.3, Reflectance = 0.03, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
	})

	for k = 0, N - 1 do
		local a = segAng(k)
		local radial, tang = dirOf(a), tangOf(a)
		local ro = Ro + 0.3
		local mid = c + radial * ((Rp + ro) / 2)
		mk(ctx, m, "Walkway", Vector3.new(2 * ro * math.tan(half) + 0.1, 1, ro - Rp), along(flatAt(mid, y - 0.5), tang), C.grate, M.DiamondPlate)
		local hl = Rp * math.tan(half)
		local p0 = flatAt(c + radial * (Rp + 0.15) - tang * hl, y)
		local p1 = flatAt(c + radial * (Rp + 0.15) + tang * hl, y)
		if k == ring.stairSeg then
			railWithGap(ctx, m, p0, p1, hl, 3)
		else
			railing(ctx, m, { p0, p1 })
		end
		if k % 3 == 1 then
			wallLamp(ctx, m, at(a, Ro - 0.6, y + 6.5), -radial, "sodium", { range = 14, flicker = rng:NextNumber() < 0.35 })
		end
	end

	-- spiral treads down the pit wall
	local rs = Rp - 1.5
	local n = math.ceil(depth / 0.75)
	local dA = 1.35 / rs
	local a0 = segAng(ring.stairSeg)
	do
		local sm = model(m, "SpiralStair")
		local pts = {}
		for k = 0, n - 1 do
			local a = a0 + ring.stairDir * k * dA
			local tread = y - depth * (k + 1) / n
			local p = c + dirOf(a) * rs
			mk(ctx, sm, "Tread", Vector3.new(1.45, 0.45, 2.8), along(flatAt(p, tread - 0.225), tangOf(a)), C.grate, M.DiamondPlate)
			bar(ctx, sm, "Bracket", at(a, Rp, tread - 1.3), at(a, Rp - 1.2, tread - 0.45), 0.3, nil, C.steel, M.Metal, DECO)
			table.insert(pts, at(a, rs - 1.25, tread))
		end
		railing(ctx, sm, pts, { noKick = true })
	end

	-- light: a cold shaft down the pit, a failing red lamp at the bottom
	hangLamp(ctx, m, Vector3.new(c.X, yTop, c.Z), "cold", { drop = 2, range = 40, angle = 35, brightness = 2.2, shadows = true })
	local redA = a0 - ring.stairDir * 1.2
	wallLamp(ctx, m, at(redA, Rp - 0.6, yP + 3), -dirOf(redA), "red", { range = 12, brightness = 1.3, flicker = true })
	G.steam(ctx, m, at(rng:NextNumber(0, TAU), Rp * 0.4, yP + 0.6), Vector3.yAxis, 0.8)
	for _ = 1, 2 do
		local a = a0 - ring.stairDir * rng:NextNumber(0.3, 1.0)
		cyl(ctx, m, "PitPipe", at(a, Rp - 0.6, yP), at(a, Rp - 0.6, y - 1), rng:NextNumber(0.5, 0.9), C.pipe, M.CorrodedMetal, DECO)
	end

	-- loot: in the flooded basement, and up on the ring
	G.lootSpot(ctx, m, at(a0 - ring.stairDir * 0.6, Rp - 2.2, yP), "PitBasement", true)
	G.lootSpot(ctx, m, at(segAng(ring.stairSeg + 6), (Rp + Ro) / 2, y), "PitRing", false)
	for _ = 1, rng:NextInteger(1, 3) do
		local k = rng:NextInteger(1, N - 1)
		if k ~= ring.stairSeg and k ~= (ring.stairSeg + 6) % N then
			G.barrel(ctx, m, at(segAng(k) + half * 0.4, Ro - 1.4, y), rng:NextNumber() < 0.5 and C.rust or C.steel)
		end
	end
	return m
end

-- ================= ROOM A (green): storeroom with a mezzanine =================
function Rooms.roomA(ctx, parent, A)
	local rng = ctx.rng
	local m = G.boxRoom(ctx, parent, { name = "StoreRoom", c = A.c, W = A.W, D = A.D, y = A.y, h = A.h, doors = { { side = A.door.side, off = A.door.off } } })
	local c, y = A.c, A.y
	local hw, hd = A.W / 2, A.D / 2
	local mz, md = 6, 4.5
	local frontZ = c.Z + hd - md
	mk(ctx, m, "Mezzanine", Vector3.new(A.W, 0.5, md), CFrame.new(c.X, y + mz - 0.25, c.Z + hd - md / 2), C.grate, M.DiamondPlate)
	mk(ctx, m, "MezzanineEdge", Vector3.new(A.W, 0.6, 0.4), CFrame.new(c.X, y + mz - 0.6, frontZ + 0.2), C.darkSteel, M.Metal)

	-- stairs on the side away from the door
	local sx = -1
	if A.door.side == "S" then
		sx = A.door.off > 0 and -1 or 1
	end
	local run = 8.4
	local stairX = c.X + sx * (hw - 1.6)
	stairs(ctx, m, Vector3.new(stairX, y, frontZ - run), Vector3.new(0, 0, 1), run, mz, 2.8, C.pillar, M.Concrete)
	local n = math.ceil(mz / 0.75)
	local pts = {}
	for k = 0, n - 1 do
		table.insert(pts, Vector3.new(stairX - sx * 1.25, y + mz * (k + 1) / n, frontZ - run + run / n * (k + 0.5)))
	end
	railing(ctx, m, pts, { noKick = true })
	railWithGap(ctx, m, Vector3.new(c.X - hw, y + mz, frontZ + 0.15), Vector3.new(c.X + hw, y + mz, frontZ + 0.15), stairX - (c.X - hw), 3.2)

	-- posts under the mezzanine edge
	local posts = math.max(2, math.floor(A.W / 5))
	for i = 1, posts - 1 do
		local x = c.X - hw + A.W * i / posts
		if math.abs(x - stairX) > 2 then
			pillar(ctx, m, Vector3.new(x, 0, frontZ + 0.4), y, y + mz - 0.5, 0.8, C.steel, M.Metal)
		end
	end

	-- pallet racks under the mezzanine
	local rackZ = c.Z + hd - 1.1
	local x = c.X - hw + 2.2
	while x < c.X + hw - 2 do
		local rk = model(m, "Rack")
		for _, dx in { -1.75, 1.75 } do
			mk(ctx, rk, "Upright", Vector3.new(0.25, 5.2, 1.6), CFrame.new(x + dx, y + 2.6, rackZ), C.steel, M.Metal)
		end
		for _, hy in { 0.4, 2.0, 3.6 } do
			mk(ctx, rk, "Shelf", Vector3.new(3.6, 0.15, 1.6), CFrame.new(x, y + hy, rackZ), C.steel, M.DiamondPlate)
			if rng:NextNumber() < 0.55 then
				local sz = rng:NextNumber(0.9, 1.3)
				G.crate(ctx, rk, Vector3.new(x + rng:NextNumber(-1, 1), y + hy + 0.075, rackZ), Vector3.new(sz, sz, sz), rng:NextNumber(-0.3, 0.3), rng:NextNumber() < 0.5 and "metal" or "wood")
			end
		end
		table.insert(ctx.loot, { cf = CFrame.new(x, y + 2.075, rackZ), area = "StoreRoomRack", primary = false })
		x += 4.4
	end

	-- a press on the open floor
	local pz = c.Z + rng:NextNumber(-hd + 6, math.max(-hd + 6.1, hd - md - 3))
	local px = c.X - sx * rng:NextNumber(0, math.max(0.1, hw - 3.5))
	pillar(ctx, m, Vector3.new(px, 0, pz), y, y + 3.4, 3, C.steel, M.Metal)
	cyl(ctx, m, "Ram", Vector3.new(px, y + 3.4, pz), Vector3.new(px, y + 6, pz), 1.2, C.darkSteel, M.Metal)
	mk(ctx, m, "Crosshead", Vector3.new(3.2, 0.8, 1.2), CFrame.new(px, y + 6.2, pz), C.yellow, M.Metal)

	G.lootSpot(ctx, m, Vector3.new(c.X - sx * rng:NextNumber(0, hw - 2.5), y + mz, c.Z + hd - 2.2), "StoreRoomMezzanine", true)
	hangLamp(ctx, m, Vector3.new(c.X, y + A.h, c.Z - hd / 3), "cold", { drop = 1, flicker = rng:NextNumber() < 0.4 })
	hangLamp(ctx, m, Vector3.new(c.X, y + mz - 0.5, c.Z + hd - md / 2), "sodium", { drop = 0.2, range = 10, brightness = 0.7 })
	for _ = 1, rng:NextInteger(1, 3) do
		G.puddle(ctx, m, Vector3.new(c.X + rng:NextNumber(-hw + 2, hw - 2), y, c.Z + rng:NextNumber(-hd + 2, hd - md - 1)), rng:NextNumber(0.7, 1.8))
	end
	return m
end

-- ================= ROOM B (green): workshop with a sunken bay =================
function Rooms.roomB(ctx, parent, B)
	local rng = ctx.rng
	local m = G.boxRoom(ctx, parent, { name = "Workshop", c = B.c, W = B.W, D = B.D, y = B.y, h = B.h, doors = B.doors, noFloor = true })
	local c, y = B.c, B.y
	local hw, hd = B.W / 2, B.D / 2
	local sw, sd, dep = B.W - 7, B.D - 7, 1.8
	local ys = y - dep
	local function slab(x0, x1, z0, z1)
		mk(ctx, m, "Floor", Vector3.new(x1 - x0, dep + 1, z1 - z0), CFrame.new(c.X + (x0 + x1) / 2, y - (dep + 1) / 2, c.Z + (z0 + z1) / 2), C.floor, M.Concrete, nil)
	end
	slab(-hw - T, hw + T, sd / 2, hd + T)
	slab(-hw - T, hw + T, -hd - T, -sd / 2)
	slab(-hw - T, -sw / 2, -sd / 2, sd / 2)
	slab(sw / 2, hw + T, -sd / 2, sd / 2)
	mk(ctx, m, "BayFloor", Vector3.new(sw, 1, sd), CFrame.new(c.X, ys - 0.5, c.Z), C.floor, M.Concrete, nil)
	mk(ctx, m, "BayWater", Vector3.new(sw - 0.1, 0.2, sd - 0.1), CFrame.new(c.X, ys + 0.12, c.Z), C.water, M.Glass, { Transparency = 0.3, Reflectance = 0.03, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	-- yellow 45-degree lip round the bay
	local corners = {
		Vector3.new(c.X - sw / 2, y, c.Z - sd / 2), Vector3.new(c.X + sw / 2, y, c.Z - sd / 2),
		Vector3.new(c.X + sw / 2, y, c.Z + sd / 2), Vector3.new(c.X - sw / 2, y, c.Z + sd / 2),
	}
	for i = 1, 4 do
		chamfer(ctx, m, corners[i], corners[i % 4 + 1], 0.35, C.yellow, M.Metal)
	end
	-- steps down into the bay from the south rim
	local stepX = c.X + rng:NextNumber(-sw / 2 + 2, sw / 2 - 2)
	stairs(ctx, m, Vector3.new(stepX, y, c.Z - sd / 2), Vector3.new(0, 0, 1), 1.8, -dep, 2.6, C.floor, M.Concrete)

	-- generator in the bay
	local gx = c.X + (stepX > c.X and -1 or 1) * (sw / 4)
	local gz = c.Z + rng:NextNumber(-sd / 4, sd / 4)
	pillar(ctx, m, Vector3.new(gx, 0, gz), ys, ys + 2.6, 2.8, C.steel, M.Metal)
	disc(ctx, m, "Housing", Vector3.new(gx, ys + 3.1, gz), 1.1, 1, C.rust, M.CorrodedMetal)
	cyl(ctx, m, "Flywheel", Vector3.new(gx + 1.5, ys + 1.6, gz), Vector3.new(gx + 1.9, ys + 1.6, gz), 2.4, C.darkSteel, M.Metal)

	-- workbench along the east wall
	local bz = c.Z + rng:NextNumber(-hd + 3, hd - 3)
	local bx = c.X + hw - 1.1
	mk(ctx, m, "BenchTop", Vector3.new(1.8, 0.2, 4.6), CFrame.new(bx, y + 3.1, bz), C.wood, M.WoodPlanks)
	for _, dz in { -2, 2 } do
		for _, dx in { -0.7, 0.7 } do
			mk(ctx, m, "BenchLeg", Vector3.new(0.2, 3, 0.2), CFrame.new(bx + dx, y + 1.5, bz + dz), C.darkSteel, M.Metal)
		end
	end
	mk(ctx, m, "Vice", Vector3.new(0.6, 0.5, 0.8), CFrame.new(bx - 0.4, y + 3.45, bz + 1.6), C.darkSteel, M.Metal, DECO)
	table.insert(ctx.loot, { cf = CFrame.new(bx, y + 3.2, bz - 0.6), area = "WorkshopBench", primary = true })

	-- chains hanging over the bay
	for _ = 1, rng:NextInteger(2, 4) do
		local p = Vector3.new(c.X + rng:NextNumber(-sw / 2 + 1, sw / 2 - 1), 0, c.Z + rng:NextNumber(-sd / 2 + 1, sd / 2 - 1))
		cyl(ctx, m, "Chain", flatAt(p, y + B.h), flatAt(p, y + B.h - rng:NextNumber(3, 6)), 0.15, C.darkSteel, M.Metal, DECO)
	end
	for _, corner in { { -1, -1 }, { 1, 1 } } do
		if rng:NextNumber() < 0.7 then
			G.barrel(ctx, m, Vector3.new(c.X + corner[1] * (hw - 1.4), y, c.Z + corner[2] * (hd - 1.4)), rng:NextNumber() < 0.5 and C.rust or C.steel)
		end
	end
	G.lootSpot(ctx, m, Vector3.new(gx, ys, gz + (gz > c.Z and -2.6 or 2.6)), "WorkshopBay", true)
	hangLamp(ctx, m, Vector3.new(c.X, y + B.h, c.Z), "cold", { drop = 2, flicker = rng:NextNumber() < 0.5 })
	wallLamp(ctx, m, Vector3.new(c.X - hw + 0.6, y + 6, c.Z + rng:NextNumber(-hd + 3, hd - 3)), Vector3.new(1, 0, 0), "red", { range = 12, brightness = 2 })
	return m
end

-- ================= DEPOT (purple) =================
-- The hopper takes whatever scavenged item a player carries. `onDeposit(player, prompt)`
-- is supplied by the level so the rules live in one place.
function Rooms.depot(ctx, parent, D, onDeposit)
	local rng = ctx.rng
	local m = G.boxRoom(ctx, parent, { name = "Depot", c = D.c, W = D.W, D = D.D, y = D.y, h = D.h, doors = D.doors })
	local c, y = D.c, D.y
	local hw, hd = D.W / 2, D.D / 2
	local hz = c.Z + rng:NextNumber(-(hd - 3.6), hd - 3.6)
	local frontX = c.X + hw - 2.6
	local inward = Vector3.new(-1, 0, 0)
	local hcf = CFrame.lookAt(Vector3.new(frontX + 1.3, y + 2.1, hz), Vector3.new(frontX + 0.3, y + 2.1, hz))
	local hm = model(m, "Hopper")
	mk(ctx, hm, "Body", Vector3.new(4.6, 4.2, 2.6), hcf, C.steel, M.Metal)
	for _, sx in { -1, 1 } do
		chamfer(ctx, hm, (hcf * CFrame.new(sx * 2.3, -2.1, -1.3)).Position, (hcf * CFrame.new(sx * 2.3, 2.1, -1.3)).Position, 0.45, C.steel, M.Metal)
	end
	chamfer(ctx, hm, (hcf * CFrame.new(-2.3, 2.1, -1.3)).Position, (hcf * CFrame.new(2.3, 2.1, -1.3)).Position, 0.45, C.steel, M.Metal)
	local mouth = mk(ctx, hm, "Mouth", Vector3.new(3, 1.6, 0.3), hcf * CFrame.new(0, 0.1, -1.2), C.black, M.SmoothPlastic)
	for _, e in {
		{ Vector3.new(3.4, 0.15, 0.12), Vector3.new(0, 0.98, -1.36) },
		{ Vector3.new(3.4, 0.15, 0.12), Vector3.new(0, -0.78, -1.36) },
		{ Vector3.new(0.15, 1.9, 0.12), Vector3.new(-1.62, 0.1, -1.36) },
		{ Vector3.new(0.15, 1.9, 0.12), Vector3.new(1.62, 0.1, -1.36) },
	} do
		mk(ctx, hm, "Glow", e[1], hcf * CFrame.new(e[2]), C.purple, M.Neon, DECO)
	end
	local glow = Instance.new("PointLight")
	glow.Color = C.purple
	glow.Range = 12
	glow.Brightness = 1.6
	glow.Parent = mouth
	G.sign(ctx, hm, (hcf * CFrame.new(0, 3, -1)).Position, inward, Vector3.new(4.6, 1.2, 0.1), "DEPOSIT", C.purple, C.signPlate)
	local _, counter = G.sign(ctx, hm, (hcf * CFrame.new(0, -1.35, -1.36)).Position, inward, Vector3.new(2.4, 0.6, 0.05), "$0", C.signText, C.black)
	-- marked drop zone in front of the hopper
	for i = 0, 3 do
		for j = 0, 1 do
			local p = Vector3.new(frontX - 0.8 - j * 1.4, y + 0.03, hz - 2.1 + i * 1.4)
			mk(ctx, m, "DropZone", Vector3.new(1.4, 0.05, 1.4), CFrame.new(p), (i + j) % 2 == 0 and Color3.fromRGB(70, 34, 110) or C.black, M.SmoothPlastic, DECO)
		end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DepositPrompt"
	prompt.ActionText = "Turn in"
	prompt.ObjectText = "Depot"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = mouth
	CollectionService:AddTag(mouth, "LootDepot")
	if onDeposit then
		onDeposit(m, prompt, counter, glow)
	end

	hangLamp(ctx, m, Vector3.new(c.X, y + D.h, c.Z), "cold", { drop = 0.8 })
	for _, d in D.doors do
		if d.side == "W" then
			wallLamp(ctx, m, Vector3.new(c.X - hw + 0.6, y + S.DoorHeight + 1, c.Z + d.off), Vector3.new(1, 0, 0), "purple", { range = 10, brightness = 1.4 })
		end
	end
	return m
end

return Rooms
