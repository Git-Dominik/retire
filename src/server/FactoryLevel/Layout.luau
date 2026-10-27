-- Rolls the floor plan for the factory level. Pure data: no instances are made here.
--
-- Topology (from the level-1 diagram), fixed on every descent:
--   start --c1--> hub
--   hub --c2--> roomA            (west, often bending north through an elbow)
--   hub --c3--> ring             (diagonal, south-west)
--   hub --c4--> depot            (east, at the hub's catwalk level)
--   depot --c5--> roomB          (south, stepping down)
--   c1 --c6--> roomB             (branch off the start corridor, closing a loop)
-- Everything else is rolled: corridor lengths, room sizes and heights, door offsets,
-- hub/ring radii, pit depth, which hub segment the ring leaves from, stair/bridge spots.
-- Plans whose footprints overlap are rejected (Layout.generate returns nil).

local Config = require(script.Parent.Config)

local S = Config.Settings
local T = S.Wall
local CW = S.CorridorWidth
local TAU = math.pi * 2

local Layout = {}

local function between(rng, r)
	return rng:NextNumber(r[1], r[2])
end
local function corridorLength(rng)
	return between(rng, S.CorridorLength)
end
local function dirOf(a)
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

-- Hub wall segments are numbered from the south (towards the elevator), counter-clockwise
-- seen from above: 0 = towards the start, 4 = east, 12 = west, 13/14 = south-west.
function Layout.hubAngle(k)
	return -math.pi / 2 + (k % S.HubSides) * TAU / S.HubSides
end
local hubAngle = Layout.hubAngle

function Layout.generate(rng)
	local L = {}
	local N = S.HubSides

	-- Start bay against the elevator facade (local z = 0)
	local start = { W = rng:NextInteger(14, 18), D = rng:NextInteger(9, 12), h = 11, y = 0 }
	start.c = Vector3.new(0, 0, start.D / 2)
	L.start = start
	local z0 = start.D + T -- outer face of the bay's north wall

	-- Hub: straight ahead, below the elevator. c1 needs a level stretch long enough for
	-- the branch to room B, then stairs (about one stud of run per stud of drop).
	local drop = between(rng, S.HubDrop)
	local stairRun = drop * 1.1
	local len1 = math.max(corridorLength(rng), 8.5 + stairRun)
	local hub = { R = between(rng, S.HubRadius), y = -drop }
	hub.c = Vector3.new(0, 0, z0 + len1 + hub.R + T)
	hub.boilerR = rng:NextNumber(3.4, 4.2)
	L.hub = hub
	local yH = hub.y
	local yDeck = yH + S.CatwalkHeight

	-- c1: level first, then stairs down into the hub
	local flatLen = len1 - stairRun
	L.c1 = {
		legs = {
			{ a = Vector3.new(0, 0, z0), b = Vector3.new(0, 0, z0 + flatLen), ya = 0, yb = 0, gaps = {} },
			{ a = Vector3.new(0, 0, z0 + flatLen), b = Vector3.new(0, 0, z0 + len1), ya = 0, yb = yH },
		},
	}

	local kRing = rng:NextNumber() < 0.5 and 13 or 14
	hub.doors = {
		[0] = { y0 = yH },
		[12] = { y0 = yH },
		[kRing] = { y0 = yH },
		[4] = { y0 = yDeck }, -- the depot is reached from the catwalk
	}
	local function hubDoor(k)
		return hub.c + dirOf(hubAngle(k)) * (hub.R + T)
	end

	-- Room A (north-west): either bends north through an elbow or runs straight west
	local A = { W = rng:NextInteger(15, 19), D = rng:NextInteger(15, 18), h = 13 }
	A.y = yH + (rng:NextNumber() < 0.5 and 0 or 3)
	local pA = hubDoor(12)
	if rng:NextNumber() < 0.6 then
		local a1 = rng:NextNumber(5, 9)
		local cn = pA + Vector3.new(-(a1 + CW / 2), 0, 0)
		local a2 = rng:NextNumber(6, 11)
		local southZ = cn.Z + CW / 2 + a2
		local off = rng:NextNumber(-(A.W / 2 - 4), A.W / 2 - 4)
		A.c = Vector3.new(cn.X - off, 0, southZ + T + A.D / 2)
		A.door = { side = "S", off = off }
		L.c2 = {
			legs = {
				{ a = pA, b = cn + Vector3.new(CW / 2, 0, 0), ya = yH, yb = yH },
				{ a = cn + Vector3.new(0, 0, CW / 2), b = Vector3.new(cn.X, 0, southZ), ya = yH, yb = A.y },
			},
			elbows = { { c = cn, y = yH, d1 = Vector3.new(-1, 0, 0), d2 = Vector3.new(0, 0, 1) } },
		}
	else
		local eastX = pA.X - corridorLength(rng)
		local off = rng:NextNumber(-(A.D / 2 - 4), A.D / 2 - 4)
		A.c = Vector3.new(eastX - T - A.W / 2, 0, pA.Z - off)
		A.door = { side = "E", off = off }
		L.c2 = { legs = { { a = pA, b = Vector3.new(eastX, 0, pA.Z), ya = yH, yb = A.y } } }
	end
	L.roomA = A

	-- Pit ring (south-west, diagonal)
	local aR = hubAngle(kRing)
	local dR = dirOf(aR)
	local ring = { Ro = between(rng, S.RingRadius), depth = between(rng, S.PitDepth) }
	ring.y = yH + (rng:NextNumber() < 0.35 and -2 or 0)
	ring.doorAngle = aR + math.pi
	local pR0 = hubDoor(kRing)
	local pR1 = pR0 + dR * corridorLength(rng)
	ring.c = pR1 + dR * (ring.Ro + T)
	ring.stairSeg = rng:NextInteger(3, 9)
	ring.stairDir = rng:NextNumber() < 0.5 and 1 or -1
	L.ring = ring
	L.c3 = { legs = { { a = pR0, b = pR1, ya = yH, yb = ring.y } } }

	-- Depot (east, catwalk level)
	local depot = { W = rng:NextInteger(11, 13), D = rng:NextInteger(11, 13), h = 10, y = yDeck }
	local pE = hubDoor(4)
	local westX = pE.X + corridorLength(rng)
	local offW = rng:NextNumber(-(depot.D / 2 - 4), depot.D / 2 - 4)
	depot.c = Vector3.new(westX + T + depot.W / 2, 0, pE.Z - offW)
	local offS = rng:NextNumber(-(depot.W / 2 - 4), depot.W / 2 - 4)
	depot.doors = { { side = "W", off = offW }, { side = "S", off = offS } }
	L.depot = depot
	L.c4 = { legs = { { a = pE, b = Vector3.new(westX, 0, pE.Z), ya = yDeck, yb = yDeck } } }

	-- Room B (south-east): under the depot's south door, level with the start corridor
	local B = { W = rng:NextInteger(14, 17), D = rng:NextInteger(13, 16), h = 11, y = 0 }
	local dsX = depot.c.X + offS
	local dsZ = depot.c.Z - depot.D / 2 - T
	local zbMin = z0 + CW / 2 + T + 0.6
	local zbMax = z0 + flatLen - CW / 2 - 0.6
	if zbMax < zbMin then
		return nil, "start corridor too short for the branch"
	end
	local zb = rng:NextNumber(zbMin, zbMax)
	-- c5's length must put the branch height inside room B's west wall
	local lo = math.max(8, dsZ - T - zb - B.D + 4)
	local hi = math.min(22, dsZ - T - zb - 4)
	if hi < lo then
		return nil, "room B can't line up with both its corridors"
	end
	local len5 = rng:NextNumber(lo, hi)
	local offN = rng:NextNumber(-(B.W / 2 - 4), B.W / 2 - 4)
	B.c = Vector3.new(dsX - offN, 0, dsZ - len5 - T - B.D / 2)
	B.doors = { { side = "N", off = offN }, { side = "W", off = zb - B.c.Z } }
	L.roomB = B
	L.c5 = { legs = { { a = Vector3.new(dsX, 0, dsZ), b = Vector3.new(dsX, 0, dsZ - len5), ya = yDeck, yb = 0 } } }
	local bx0, bx1 = CW / 2 + T, B.c.X - B.W / 2 - T
	if bx1 - bx0 < 4 then
		return nil, "branch to room B too short"
	end
	L.c6 = { legs = { { a = Vector3.new(bx0, 0, zb), b = Vector3.new(bx1, 0, zb), ya = 0, yb = 0 } } }
	table.insert(L.c1.legs[1].gaps, { s = zb - z0, toward = Vector3.new(1, 0, 0), y = 0 })

	-- Hub internals: stairs up to the catwalk, a radial bridge to the boiler, a high bridge.
	-- The stairs sweep about four segments back from their top and must stay clear of the
	-- ground-floor doorways (the depot door is up on the catwalk, so it doesn't count).
	local ground = { [0] = true, [12] = true, [kRing] = true }
	local options = {}
	for k = 0, N - 1 do
		if k ~= 4 then
			for _, sgn in { 1, -1 } do
				local ok = true
				for j = 0, 4 do
					if ground[(k - sgn * j) % N] then
						ok = false
						break
					end
				end
				if ok then
					table.insert(options, { k, sgn })
				end
			end
		end
	end
	if #options == 0 then
		return nil, "no room for the catwalk stairs"
	end
	local pick = options[rng:NextInteger(1, #options)]
	hub.stairSeg, hub.stairDir = pick[1], pick[2]

	local busy = { [0] = true, [12] = true, [kRing] = true, [4] = true }
	for j = 0, 4 do
		busy[(hub.stairSeg - hub.stairDir * j) % N] = true
	end
	local candidates = {}
	for k = 0, N - 1 do
		if not busy[k] and not busy[(k + 1) % N] and not busy[(k - 1) % N] then
			table.insert(candidates, k)
		end
	end
	if #candidates == 0 then
		for k = 0, N - 1 do
			if not busy[k] then
				table.insert(candidates, k)
			end
		end
	end
	if #candidates == 0 then
		return nil, "no room for the boiler bridge"
	end
	hub.bridgeSeg = candidates[rng:NextInteger(1, #candidates)]
	hub.highAngle = rng:NextNumber(0, math.pi)
	hub.highOffset = rng:NextNumber(5, 8) * (rng:NextNumber() < 0.5 and 1 or -1)
	hub.floodPhase = rng:NextNumber(0, TAU)

	return L
end

-- ================= OVERLAP CHECK =================
local CONNECTED = {
	start = { c1 = true, elevator = true },
	c1 = { hub = true, c6 = true },
	hub = { c2 = true, c3 = true, c4 = true },
	c2 = { roomA = true },
	c3 = { ring = true },
	c4 = { depot = true },
	depot = { c5 = true },
	c5 = { roomB = true },
	c6 = { roomB = true },
}

local function connected(a, b)
	return a == b or (CONNECTED[a] and CONNECTED[a][b]) or (CONNECTED[b] and CONNECTED[b][a]) or false
end

function Layout.shapes(L)
	local shapes = {}
	local function box(name, c, W, D)
		table.insert(shapes, { kind = "box", name = name, minx = c.X - W / 2 - T, maxx = c.X + W / 2 + T, minz = c.Z - D / 2 - T, maxz = c.Z + D / 2 + T })
	end
	box("start", L.start.c, L.start.W, L.start.D)
	table.insert(shapes, { kind = "circle", name = "hub", c = L.hub.c, r = (L.hub.R + T) / math.cos(math.pi / S.HubSides) })
	box("roomA", L.roomA.c, L.roomA.W, L.roomA.D)
	table.insert(shapes, { kind = "circle", name = "ring", c = L.ring.c, r = (L.ring.Ro + T) / math.cos(math.pi / S.RingSides) })
	box("depot", L.depot.c, L.depot.W, L.depot.D)
	box("roomB", L.roomB.c, L.roomB.W, L.roomB.D)
	for _, name in { "c1", "c2", "c3", "c4", "c5", "c6" } do
		for _, leg in L[name].legs do
			table.insert(shapes, { kind = "seg", name = name, a = leg.a, b = leg.b, r = CW / 2 + T })
		end
		for _, e in L[name].elbows or {} do
			box(name, e.c, CW, CW)
		end
	end
	table.insert(shapes, { kind = "box", name = "elevator", minx = -21, maxx = 21, minz = -60, maxz = 0 })
	return shapes
end

local function dist2D(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end
local function closestOnSeg(p, a, b)
	local ab = b - a
	local l2 = ab:Dot(ab)
	if l2 < 1e-6 then
		return a
	end
	return a + ab * math.clamp((p - a):Dot(ab) / l2, 0, 1)
end
local function boxDist(bx, p)
	local dx = math.max(bx.minx - p.X, 0, p.X - bx.maxx)
	local dz = math.max(bx.minz - p.Z, 0, p.Z - bx.maxz)
	return math.sqrt(dx * dx + dz * dz)
end
local function asSeg(s)
	if s.kind == "circle" then
		return s.c, s.c, s.r
	end
	return s.a, s.b, s.r
end

local function overlaps(s1, s2, margin)
	if s1.kind == "box" and s2.kind == "box" then
		return s1.minx < s2.maxx + margin and s2.minx < s1.maxx + margin and s1.minz < s2.maxz + margin and s2.minz < s1.maxz + margin
	end
	if s1.kind == "box" or s2.kind == "box" then
		local bx = s1.kind == "box" and s1 or s2
		local a, b, r = asSeg(s1.kind == "box" and s2 or s1)
		local n = math.max(1, math.ceil(dist2D(a, b)))
		for i = 0, n do
			if boxDist(bx, a:Lerp(b, i / n)) < r + margin then
				return true
			end
		end
		return false
	end
	local a1, b1, r1 = asSeg(s1)
	local a2, b2, r2 = asSeg(s2)
	local n = math.max(1, math.ceil(dist2D(a1, b1)))
	for i = 0, n do
		local p = a1:Lerp(b1, i / n)
		if dist2D(p, closestOnSeg(p, a2, b2)) < r1 + r2 + margin then
			return true
		end
	end
	return false
end

-- True when nothing overlaps except things that are meant to join.
function Layout.isClear(L)
	local shapes = Layout.shapes(L)
	for i = 1, #shapes do
		for j = i + 1, #shapes do
			local s1, s2 = shapes[i], shapes[j]
			if not connected(s1.name, s2.name) and overlaps(s1, s2, 0.4) then
				return false, s1.name .. " overlaps " .. s2.name
			end
		end
	end
	return true
end

-- Local-space bounds of the whole plan, for clearing stray props out of the way.
function Layout.bounds(L)
	local b = { minx = math.huge, maxx = -math.huge, minz = math.huge, maxz = -math.huge }
	for _, s in Layout.shapes(L) do
		if s.name ~= "elevator" then
			if s.kind == "box" then
				b.minx, b.maxx = math.min(b.minx, s.minx), math.max(b.maxx, s.maxx)
				b.minz, b.maxz = math.min(b.minz, s.minz), math.max(b.maxz, s.maxz)
			else
				local a, c, r = asSeg(s)
				b.minx, b.maxx = math.min(b.minx, a.X - r, c.X - r), math.max(b.maxx, a.X + r, c.X + r)
				b.minz, b.maxz = math.min(b.minz, a.Z - r, c.Z - r), math.max(b.maxz, a.Z + r, c.Z + r)
			end
		end
	end
	b.miny = math.min(L.ring.y - L.ring.depth, L.hub.y) - 3
	b.maxy = L.hub.y + S.HubHeight + 3
	return b
end

return Layout
