-- Shared structure for every tile: floor, walls with doorways / shutters / windows, roof,
-- and perimeter galleries reached by full stair flights.
--
-- A tile works in its own frame t.cf (local +Z = north, X = east; floor at y = 0, which may
-- differ from the base). Sockets sit on the tile's outer boundary:
--   N: (off, y, D/2)  E: (W/2, y, off)  S: (off, y, -D/2)  W: (-W/2, y, off)
-- Two tiles that meet at a socket each build their own wall (back to back on the shared
-- boundary) with the same 12 x 14 opening; one doorway frame is added on top by the level.

local Config = require(script.Parent.Config)
local G = require(script.Parent.Geometry)

local S = Config.Settings
local C = Config.Colors
local M = Enum.Material
local T = S.Wall
local DW, DH = S.DoorWidth, S.DoorHeight

local Shell = {}

Shell.SIDES = { N = 0, E = 1, S = 2, W = 3 }
Shell.LOCALDIR = {
	N = Vector3.new(0, 0, 1),
	E = Vector3.new(1, 0, 0),
	S = Vector3.new(0, 0, -1),
	W = Vector3.new(-1, 0, 0),
}

function Shell.socketPoint(proto, sock)
	local W, D = proto.W, proto.D
	if sock.side == "N" then
		return Vector3.new(sock.off, sock.y, D / 2)
	elseif sock.side == "S" then
		return Vector3.new(sock.off, sock.y, -D / 2)
	elseif sock.side == "E" then
		return Vector3.new(W / 2, sock.y, sock.off)
	end
	return Vector3.new(-W / 2, sock.y, sock.off)
end

-- Wall styles
local function brick(t)
	return t.data.brickColor or C.brick[1]
end
function Shell.styleBrick(t)
	return { mat = M.Brick, color = brick(t), plinth = 3, courses = {}, pilasters = 12, topChamfer = true, bottomChamfer = true }
end
function Shell.styleShed(t, split)
	-- brick to `split`, corrugated cladding above (the rolling-mill look)
	return {
		mat = M.Brick, color = brick(t), plinth = 3, courses = { split - 0.3 }, pilasters = 10,
		upper = { y = split, mat = M.CorrodedMetal, color = C.corrugated },
		topChamfer = true, bottomChamfer = true,
	}
end
function Shell.styleConcrete()
	return { mat = M.Concrete, color = C.concrete, plinth = 2.5, topChamfer = true, bottomChamfer = true }
end

-- helpers in tile space
function Shell.frame(t)
	local cf = t.cf
	local function P(x, y, z)
		return cf * Vector3.new(x, y, z)
	end
	local function F(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	return P, F, cf.XVector, cf.ZVector
end

-- keep-out rectangles (tile space) so props never block doors, stairs or walkways
function Shell.reserve(t, x0, z0, x1, z1)
	t.keepout = t.keepout or {}
	table.insert(t.keepout, { math.min(x0, x1), math.min(z0, z1), math.max(x0, x1), math.max(z0, z1) })
end
function Shell.free(t, x, z, r)
	local W, D = t.proto.W, t.proto.D
	if math.abs(x) > W / 2 - T - r or math.abs(z) > D / 2 - T - r then
		return false
	end
	for _, k in t.keepout or {} do
		if x + r > k[1] and x - r < k[3] and z + r > k[2] and z - r < k[4] then
			return false
		end
	end
	return true
end
-- random free floor spot (tile space), or nil
function Shell.spot(ctx, t, r, x0, z0, x1, z1)
	local W, D = t.proto.W, t.proto.D
	x0, z0 = x0 or -W / 2, z0 or -D / 2
	x1, z1 = x1 or W / 2, z1 or D / 2
	for _ = 1, 30 do
		local x, z = ctx.rng:NextNumber(x0, x1), ctx.rng:NextNumber(z0, z1)
		if Shell.free(t, x, z, r) then
			return x, z
		end
	end
	return nil
end

-- spec: style, h, wallBottom, floor (false to skip), roof ("flat" | "skylight" | false),
-- windows = { sill, height, width, spacing }, open = { S = width } (an unframed opening
-- centred on that side, used against the elevator facade).
function Shell.build(ctx, parent, t, spec)
	local proto = t.proto
	local W, D = proto.W, proto.D
	local P, F, X, Z = Shell.frame(t)
	local m = G.model(parent, "Shell")
	local h = spec.h
	local yb = spec.wallBottom or (proto.yMin or -1)

	if spec.floor ~= false then
		G.mk(ctx, m, "Floor", Vector3.new(W, 1, D), F(0, -0.5, 0), spec.floorColor or C.floor, spec.floorMat or M.Concrete)
	end

	-- per-side openings
	local sides = {
		N = { a = Vector3.new(-W / 2, 0, D / 2 - T / 2), b = Vector3.new(W / 2, 0, D / 2 - T / 2), inward = -Z, len = W, origin = -W / 2 },
		S = { a = Vector3.new(-W / 2, 0, -D / 2 + T / 2), b = Vector3.new(W / 2, 0, -D / 2 + T / 2), inward = Z, len = W, origin = -W / 2 },
		E = { a = Vector3.new(W / 2 - T / 2, 0, -D / 2 + T), b = Vector3.new(W / 2 - T / 2, 0, D / 2 - T), inward = -X, len = D - 2 * T, origin = -D / 2 + T },
		W = { a = Vector3.new(-W / 2 + T / 2, 0, -D / 2 + T), b = Vector3.new(-W / 2 + T / 2, 0, D / 2 - T), inward = X, len = D - 2 * T, origin = -D / 2 + T },
	}
	for name, sd in sides do
		sd.gaps = {}
		sd.blocked = {}
	end
	for _, sock in proto.sockets do
		local sd = sides[sock.side]
		local s = sock.off - sd.origin
		table.insert(sd.blocked, { s - DW / 2 - 2, s + DW / 2 + 2 })
		if t.connected[sock.id] then
			table.insert(sd.gaps, { s = s, w = DW, y0 = sock.y, y1 = sock.y + DH, kind = "door" })
		else
			local lp = Shell.socketPoint(proto, sock)
			local inwardL = -Shell.LOCALDIR[sock.side]
			G.shutter(ctx, m, P(lp.X + inwardL.X * T, sock.y, lp.Z + inwardL.Z * T), sd.inward)
		end
		-- keep the floor in front of every socket clear
		local lp = Shell.socketPoint(proto, sock)
		local inwardL = -Shell.LOCALDIR[sock.side]
		local depth = 14
		local c = lp + inwardL * (depth / 2)
		local hx = (sock.side == "N" or sock.side == "S") and (DW / 2 + 3) or depth / 2
		local hz = (sock.side == "N" or sock.side == "S") and depth / 2 or (DW / 2 + 3)
		if math.abs(sock.y) < 0.5 then
			Shell.reserve(t, c.X - hx, c.Z - hz, c.X + hx, c.Z + hz)
		end
	end
	if spec.open then
		for name, w in spec.open do
			local sd = sides[name]
			table.insert(sd.gaps, { s = sd.len / 2, w = w, y0 = yb, y1 = math.min(h, 22), kind = "open" })
			table.insert(sd.blocked, { sd.len / 2 - w / 2 - 2, sd.len / 2 + w / 2 + 2 })
		end
	end

	-- windows high in the walls, only where the outside really is outside
	if spec.windows then
		local wn = spec.windows
		local count = 0
		for name, sd in sides do
			local s = wn.spacing / 2 + 2
			while s < sd.len - wn.spacing / 2 - 1 do
				local ok = true
				for _, b in sd.blocked do
					if s + wn.width / 2 > b[1] and s - wn.width / 2 < b[2] and (wn.sill < DH + 1.5 or true) then
						-- openings above doors would share a stretch of wall; keep them apart
						ok = false
					end
				end
				if ok then
					local along = sd.origin + s
					local outsideL
					if name == "N" or name == "S" then
						outsideL = Vector3.new(along, wn.sill + wn.height / 2, (name == "N" and 1 or -1) * (D / 2 + 3))
					else
						outsideL = Vector3.new((name == "E" and 1 or -1) * (W / 2 + 3), wn.sill + wn.height / 2, along)
					end
					ok = t.isOutside(P(outsideL.X, outsideL.Y, outsideL.Z))
				end
				if ok then
					count += 1
					table.insert(sd.gaps, { s = s, w = wn.width, y0 = wn.sill, y1 = wn.sill + wn.height, kind = "window", light = count % 2 == 1 })
				end
				s += wn.spacing
			end
		end
	end

	local style = spec.style
	for name, sd in sides do
		G.wallRun(ctx, m, P(sd.a.X, 0, sd.a.Z), P(sd.b.X, 0, sd.b.Z), yb, h, sd.inward, {
			gaps = sd.gaps,
			ext = 0,
			floor = 0,
			style = style,
			name = "Wall" .. name,
		})
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			G.chamfer(ctx, m, P(sx * (W / 2 - T), 0, sz * (D / 2 - T)), P(sx * (W / 2 - T), h, sz * (D / 2 - T)), S.Chamfer * 1.5, style.upper and style.upper.color or style.color, style.upper and style.upper.mat or style.mat)
		end
	end

	-- roof
	if spec.roof then
		local span, across = W >= D and W or D, W >= D and D or W
		local alongX = W >= D
		if spec.roof == "skylight" then
			-- glazed strips across the short way, solid strips between them
			local pitch = 12
			local n = math.floor((span - 2 * T) / pitch)
			local start = -n * pitch / 2
			local cursor = -span / 2
			for i = 0, n - 1 do
				local g0 = start + i * pitch + 4
				local g1 = g0 + 4
				local function strip(a, b, glass)
					local sz = b - a
					if sz <= 0.05 then
						return
					end
					local mid = (a + b) / 2
					local size = alongX and Vector3.new(sz, glass and 0.3 or 1, across) or Vector3.new(across, glass and 0.3 or 1, sz)
					local cf = alongX and F(mid, h + 0.5, 0) or F(0, h + 0.5, mid)
					local p = G.mk(ctx, m, glass and "Skylight" or "Roof", size, cf, glass and C.glass or C.ceiling, glass and M.Glass or M.Concrete, glass and { Transparency = 0.45, CastShadow = false } or nil)
					if glass and i % 2 == 0 then
						local l = Instance.new("SurfaceLight")
						l.Face = Enum.NormalId.Bottom
						l.Color = C.daylight
						l.Brightness = 0.6
						l.Range = h + 4
						l.Angle = 60
						l.Shadows = false
						l.Parent = p
						G.lightShaft(ctx, m, alongX and P(mid, h - 0.5, 0) or P(0, h - 0.5, mid), alongX and P(mid + 3, 2, 0) or P(0, 2, mid + 3), 4, 9, C.daylight, 0.04)
					end
				end
				strip(cursor, g0, false)
				strip(g0, g1, true)
				cursor = g1
			end
			local mid = (cursor + span / 2) / 2
			local sz = span / 2 - cursor
			G.mk(ctx, m, "Roof", alongX and Vector3.new(sz, 1, across) or Vector3.new(across, 1, sz), alongX and F(mid, h + 0.5, 0) or F(0, h + 0.5, mid), C.ceiling, M.Concrete)
		else
			G.mk(ctx, m, "Roof", Vector3.new(W, 1, D), F(0, h + 0.5, 0), C.ceiling, M.Concrete)
		end
		-- roof girders across the short way, purlins along
		local count = math.max(1, math.floor(span / 9))
		for i = 1, count do
			local u = -span / 2 + span * i / (count + 1)
			local a = alongX and P(u, h - 1, -across / 2 + T) or P(-across / 2 + T, h - 1, u)
			local b = alongX and P(u, h - 1, across / 2 - T) or P(across / 2 - T, h - 1, u)
			G.ibeam(ctx, m, a, b, 2, 1, C.darkSteel, Vector3.yAxis, G.NOCOLLIDE)
		end
		for _, v in { -across / 4, across / 4 } do
			local a = alongX and P(-span / 2 + T, h - 0.4, v) or P(v, h - 0.4, -span / 2 + T)
			local b = alongX and P(span / 2 - T, h - 0.4, v) or P(v, h - 0.4, span / 2 - T)
			G.ibeam(ctx, m, a, b, 0.8, 0.6, C.darkSteel, Vector3.yAxis, G.NOCOLLIDE)
		end
	end
	return m
end

-- Perimeter gallery at height y along `sides`, reached by perpendicular stair flights.
-- spec: y, width, sides = { N = true, ... }, flights = { { side, off, width } },
-- railGaps = { [side] = { { at = offset, w } } } (offsets in tile space along that side).
-- Returns the inner-edge positions so callers can attach bridges.
function Shell.gallery(ctx, parent, t, spec)
	local proto = t.proto
	local W, D = proto.W, proto.D
	local P, F, X, Z = Shell.frame(t)
	local m = G.model(parent, "Gallery")
	local y, gw = spec.y, spec.width
	local has = spec.sides
	local xi, zi = W / 2 - T, D / 2 - T
	local edges = {}

	local function deckRect(x0, z0, x1, z1)
		G.mk(ctx, m, "Deck", Vector3.new(x1 - x0, 0.5, z1 - z0), F((x0 + x1) / 2, y - 0.25, (z0 + z1) / 2), C.plate, M.DiamondPlate)
	end
	if has.N then
		deckRect(-xi, zi - gw, xi, zi)
		edges.N = { a = Vector3.new(has.W and -xi + gw or -xi, y, zi - gw), b = Vector3.new(has.E and xi - gw or xi, y, zi - gw) }
	end
	if has.S then
		deckRect(-xi, -zi, xi, -zi + gw)
		edges.S = { a = Vector3.new(has.W and -xi + gw or -xi, y, -zi + gw), b = Vector3.new(has.E and xi - gw or xi, y, -zi + gw) }
	end
	local z0 = has.S and -zi + gw or -zi
	local z1 = has.N and zi - gw or zi
	if has.E then
		deckRect(xi - gw, z0, xi, z1)
		edges.E = { a = Vector3.new(xi - gw, y, z0), b = Vector3.new(xi - gw, y, z1) }
	end
	if has.W then
		deckRect(-xi, z0, -xi + gw, z1)
		edges.W = { a = Vector3.new(-xi + gw, y, z0), b = Vector3.new(-xi + gw, y, z1) }
	end

	-- stair flights from the floor straight up to the deck edge
	local flightZones = {}
	for _, f in spec.flights or {} do
		local fw = f.width or 6
		local n = math.ceil(y / 0.7)
		local run = n * 1.05
		local e = edges[f.side]
		if e then
			local dir, foot
			if f.side == "N" then
				dir = Vector3.new(0, 0, 1)
				foot = Vector3.new(f.off, 0, e.a.Z - run)
			elseif f.side == "S" then
				dir = Vector3.new(0, 0, -1)
				foot = Vector3.new(f.off, 0, e.a.Z + run)
			elseif f.side == "E" then
				dir = Vector3.new(1, 0, 0)
				foot = Vector3.new(e.a.X - run, 0, f.off)
			else
				dir = Vector3.new(-1, 0, 0)
				foot = Vector3.new(e.a.X + run, 0, f.off)
			end
			G.flight(ctx, m, P(foot.X, 0, foot.Z), (f.side == "N" or f.side == "S") and (dir.Z > 0 and Z or -Z) or (dir.X > 0 and X or -X), run, y, fw, { left = true, right = true })
			local far = foot + dir * run
			Shell.reserve(t, math.min(foot.X, far.X) - fw / 2 - 2.5, math.min(foot.Z, far.Z) - fw / 2 - 2.5, math.max(foot.X, far.X) + fw / 2 + 2.5, math.max(foot.Z, far.Z) + fw / 2 + 2.5)
			-- keep the foot of the stairs clear too
			local before = foot - dir * 6
			Shell.reserve(t, math.min(foot.X, before.X) - fw / 2, math.min(foot.Z, before.Z) - fw / 2, math.max(foot.X, before.X) + fw / 2, math.max(foot.Z, before.Z) + fw / 2)
			flightZones[f.side] = flightZones[f.side] or {}
			table.insert(flightZones[f.side], { off = f.off, w = fw })
		end
	end

	-- railings on the inner edges, posts and fascia beams underneath
	for side, e in edges do
		local horizontal = side == "N" or side == "S"
		local function offOf(p)
			return horizontal and p.X or p.Z
		end
		local gaps = {}
		for _, fz in flightZones[side] or {} do
			table.insert(gaps, { at = fz.off - offOf(e.a), w = fz.w + 0.4 })
		end
		for _, g in (spec.railGaps and spec.railGaps[side]) or {} do
			table.insert(gaps, { at = g.at - offOf(e.a), w = g.w })
		end
		G.railGaps(ctx, m, P(e.a.X, y, e.a.Z), P(e.b.X, y, e.b.Z), gaps)
		G.ibeam(ctx, m, P(e.a.X, y - 1.2, e.a.Z), P(e.b.X, y - 1.2, e.b.Z), 1.4, 0.7, C.darkSteel, Vector3.yAxis, G.NOCOLLIDE)
		-- posts, kept out of doorways underneath and away from the stairs
		local len = (e.b - e.a).Magnitude
		local dirE = (e.b - e.a) / len
		local inwardL = horizontal and Vector3.new(0, 0, side == "N" and -1 or 1) or Vector3.new(side == "E" and -1 or 1, 0, 0)
		local n = math.max(1, math.floor(len / 9))
		for i = 0, n do
			local p = e.a + dirE * (len * i / n) + inwardL * 0.6
			local o = offOf(p)
			local clear = true
			for _, sock in proto.sockets do
				if sock.side == side and math.abs(sock.y) < 0.5 and math.abs(sock.off - o) < DW / 2 + 2.5 then
					clear = false
				end
			end
			for _, fz in flightZones[side] or {} do
				if math.abs(fz.off - o) < fz.w / 2 + 1.5 then
					clear = false
				end
			end
			if clear then
				G.ibeam(ctx, m, P(p.X, 0, p.Z), P(p.X, y - 0.5, p.Z), 0.9, 0.9, C.steel, horizontal and X or Z)
				Shell.reserve(t, p.X - 1.5, p.Z - 1.5, p.X + 1.5, p.Z + 1.5)
			end
		end
	end
	-- nothing tall goes under the decks
	if has.N then
		Shell.reserve(t, -xi, zi - gw - 1, xi, zi)
	end
	if has.S then
		Shell.reserve(t, -xi, -zi, xi, -zi + gw + 1)
	end
	if has.E then
		Shell.reserve(t, xi - gw - 1, -zi, xi, zi)
	end
	if has.W then
		Shell.reserve(t, -xi, -zi, -xi + gw + 1, zi)
	end
	return edges
end

return Shell
