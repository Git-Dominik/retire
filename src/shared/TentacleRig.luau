-- Poses the wall shopkeeper's tentacles (see WallShop.client). A tentacle mass is a rig of
-- skinned tentacles whose bone chains all start at one knot under its RootPart; the knot
-- is hidden behind the wall, so the tentacles reach in from the dark at the edges of the
-- shop's hole rather than from the eyes. Every chain root carries a Mode attribute:
--   Grip    follows a route (Way1..WayN, Vector3 in the shop's pivot space) out of the
--           hole and along the wall or floor, rippling gently along its length.
--   Reach   the same, but the body ripples more and its tip also sways toward the room.
--   Hidden  lies straight back behind the wall and stays still.
-- The last stretch of every visible tentacle (TipShare of its length, or what's left past
-- the route's end if that's more) is its tip. The tip sweeps from one side to the other in
-- the plane of the surface it lies on, curling one way, holding, then curling the other.
-- HookNormal (shop space, default the wall's normal) names that surface.
-- Length (studs, optional) is how much of the chain comes out past the knot; the rest of a
-- longer chain stays drawn back behind the wall, so a big, thick rig can show just its
-- outer stretch.
-- Sway (studs of ripple), Speed and Phase shape the motion; Phase also staggers when each
-- tentacle starts to creep out. Neighbours should differ in Phase by about pi, so their
-- tips swing opposite ways.
-- Coming out, a tentacle skips the hidden stretch of its route, then creeps out of the
-- hole at CreepSpeed, easing in and slowing as its tip settles; going back it withdraws
-- faster. update() returns the frame's events ("emerge" as a tip leaves the void, "grip"
-- as a tentacle settles, each with a world position) so the client can play sounds. Whatever isn't out yet lies straight back
-- along the route's run-on behind the knot: the root bone itself slides back that far, so
-- the tip only ever travels the route and the chain never folds.
-- The bones follow the leader along a smoothed target curve: each bone ends exactly one
-- bone length further along it, so no joint can fold back on itself.
-- A root only moves while its tentacle is drawn back: moving one stretches the knot's
-- shared skin, which is fine only because the knot and the run-on are hidden behind the wall.
-- Used by WallShop.client; nothing here touches the network.

local TentacleRig = {}

local CONFIG = {
	-- Route samples per waypoint gap; the route is a Catmull-Rom curve through the waypoints.
	Samples = 10,
	-- Spacing of the target curve the bones follow, in studs, and how much it's smoothed.
	Step = 0.25,
	SmoothPasses = 24,
	-- Waves along a tentacle, so its ripple travels down the length.
	Waves = 1.4,
	-- Ripple is scaled by tentacle length over this, so short tentacles move less.
	SwayLength = 12,
	-- A slow swell through the middle of each tentacle, on top of the ripple.
	SwellAmount = 0.12,
	SwellSpeed = 0.35,
	-- The tip: its share of the tentacle, clamped to these lengths in studs.
	TipShare = 0.22,
	TipMin = 1.4,
	TipMax = 2.5,
	-- How far round the tip curls at either side of its sweep, in radians, but never so far
	-- that the tip's end swings more than TipSwing studs sideways (long horn-like tips).
	TipCurl = 0.9,
	TipSwing = 1.2,
	-- Sweep rate (rad/s, times Speed) and how long it holds at each side: higher holds longer.
	SweepSpeed = 0.55,
	SweepHold = 2.0,
	-- Creeping out: studs per second at full pace, the stretch (studs) over which it eases in
	-- and out of that pace, the slowest it goes, and the most a tentacle waits (s) before it
	-- starts, spread across the tentacles by Phase.
	CreepSpeed = 11,
	CreepEase = 1.2,
	CreepMin = 0.35,
	CreepStagger = 0.35,
	-- Opening, a tentacle starts this far short of where its route comes out of the void
	-- (shop z below HoleDepth), so no time goes on creeping through the dark.
	HoleDepth = 1,
	HoleLead = 0.4,
	-- Withdrawing, studs per second.
	WithdrawSpeed = 6,
	-- How much motion is left while the shop is shut (the tentacles are out of sight then).
	Idle = 0.3,
}

local function catmullRom(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return 0.5
		* (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

-- Rotation that turns `from` onto `to` (both unit vectors) the short way round.
local function rotationBetween(from, to)
	local dot = from:Dot(to)
	if dot > 0.99999 then
		return CFrame.identity
	elseif dot < -0.99999 then
		return CFrame.Angles(math.pi, 0, 0)
	end
	return CFrame.fromAxisAngle(from:Cross(to).Unit, math.acos(dot))
end

local function chainOf(root)
	local bones, reaches, total = {}, {}, 0
	local bone = root
	while bone do
		table.insert(bones, bone)
		bone = bone:FindFirstChildOfClass("Bone")
	end
	for i = 1, #bones do
		local nextBone = bones[i + 1]
		reaches[i] = nextBone and nextBone.CFrame.Position.Magnitude or reaches[i - 1] or 0.5
		total += reaches[i]
	end
	return bones, reaches, total
end

-- Where a segment a->b first reaches `reach` studs from p, or nil if it never does.
local function crossing(p, a, b, reach)
	local d = b - a
	local f = a - p
	local qa = d:Dot(d)
	local qb = 2 * f:Dot(d)
	local qc = f:Dot(f) - reach * reach
	local disc = qb * qb - 4 * qa * qc
	if qa < 1e-9 or disc < 0 then
		return nil
	end
	local t = (-qb + math.sqrt(disc)) / (2 * qa)
	if t < 0 or t > 1 then
		return nil
	end
	return a + d * t
end

-- Lays the chain along `curve` (a dense polyline starting where the root should be),
-- follow-the-leader: each bone aims at the first point on the curve one bone length from
-- its own base. The root bone is moved onto curve[1] if it isn't there already.
local function followCurve(rootPart, chain, curve)
	local parent = rootPart.CFrame
	local index = 1
	for i, bone in chain.bones do
		local base = parent * bone.CFrame
		local shift = Vector3.zero
		if i == 1 then
			shift = base:PointToObjectSpace(curve[1])
			base *= CFrame.new(shift)
		end
		local from = base.Position
		local reach = chain.reaches[i]
		local target
		while index < #curve do
			target = crossing(from, curve[index], curve[index + 1], reach)
			if target then
				break
			end
			index += 1
		end
		if not target then
			local n = #curve
			target = from + (curve[n] - curve[n - 1]).Unit * reach
		end
		local aim = base:VectorToObjectSpace(target - from)
		local turn = aim.Magnitude > 1e-4 and rotationBetween(Vector3.yAxis, aim.Unit) or CFrame.identity
		bone.Transform = CFrame.new(shift) * turn
		parent = base * turn
	end
end

local function sampleRoute(ways)
	local first, last = ways[1], ways[#ways]
	local padded = { 2 * first - ways[2], table.unpack(ways) }
	table.insert(padded, 2 * last - ways[#ways - 1])
	local points, lengths = { first }, { 0 }
	for i = 2, #padded - 2 do
		for step = 1, CONFIG.Samples do
			local p = catmullRom(padded[i - 1], padded[i], padded[i + 1], padded[i + 2], step / CONFIG.Samples)
			lengths[#points + 1] = lengths[#points] + (p - points[#points]).Magnitude
			points[#points + 1] = p
		end
	end
	return points, lengths
end

-- A point `s` studs along the route's polyline, with its direction there.
local function routePoint(points, lengths, s)
	for i = 2, #lengths do
		if lengths[i] >= s then
			local a = lengths[i - 1]
			local direction = (points[i] - points[i - 1]).Unit
			return points[i - 1]:Lerp(points[i], (s - a) / (lengths[i] - a)), direction
		end
	end
	local n = #points
	return points[n], (points[n] - points[n - 1]).Unit
end

-- mass: a tentacle rig Model with a RootPart; pivot: the shop's pivot CFrame.
function TentacleRig.setup(mass, pivot)
	local rootPart = mass:FindFirstChild("RootPart")
	if not rootPart then
		return nil
	end
	local state = { rootPart = rootPart, chains = {} }
	-- Deeper into the wall, away from the room.
	local deep = pivot:VectorToWorldSpace(Vector3.zAxis)
	for _, root in rootPart:GetChildren() do
		if not root:IsA("Bone") then
			continue
		end
		local mode = root:GetAttribute("Mode") or "Hidden"
		local bones, reaches, total = chainOf(root)
		local origin = (rootPart.CFrame * root.CFrame).Position
		local chain = { mode = mode, bones = bones, reaches = reaches, total = total }
		if mode == "Hidden" then
			local curve = { origin, origin + deep * (total + 1) }
			followCurve(rootPart, chain, curve)
			continue
		end
		local ways = { origin }
		while root:GetAttribute("Way" .. #ways) do
			table.insert(ways, pivot * root:GetAttribute("Way" .. #ways))
		end
		if #ways < 3 then
			continue
		end
		local points, lengths = sampleRoute(ways)
		local routeLength = lengths[#lengths]
		-- How much of the chain comes out; anything beyond stays drawn back behind the wall.
		local extent = math.clamp(root:GetAttribute("Length") or total, 0, total)
		local tip = math.clamp(extent * CONFIG.TipShare, CONFIG.TipMin, CONFIG.TipMax)
		-- The body follows the route up to here; the rest of what comes out is the tip.
		local bodyEnd = math.min(routeLength, extent - tip)
		local tipStart, tipDirection = routePoint(points, lengths, bodyEnd)
		local normal = pivot:VectorToWorldSpace(root:GetAttribute("HookNormal") or Vector3.zAxis).Unit
		tipDirection -= normal * tipDirection:Dot(normal)
		-- A route ending (nearly) straight out of the surface has no clear in-plane
		-- direction; hang down.
		if tipDirection.Magnitude < 0.5 then
			local down = pivot:VectorToWorldSpace(-Vector3.yAxis)
			tipDirection = down - normal * down:Dot(normal)
		end
		tipDirection = tipDirection.Unit
		chain.points = points
		chain.lengths = lengths
		chain.bodyEnd = bodyEnd
		chain.tipStart = tipStart
		chain.tipDirection = tipDirection
		chain.tipSide = normal:Cross(tipDirection)
		chain.tipLength = extent - bodyEnd
		chain.extent = extent
		-- The run-on behind the knot, bent into the wall so a drawn-back tentacle can never
		-- poke out into the room.
		chain.backward = ((ways[1] - ways[2]).Unit + deep).Unit
		-- How far along the route it leaves the void, and where.
		chain.hidden = routeLength
		chain.hole = points[#points]
		for i, p in points do
			if pivot:PointToObjectSpace(p).Z < CONFIG.HoleDepth then
				chain.hidden = lengths[i]
				chain.hole = p
				break
			end
		end
		chain.reach = mode == "Reach"
		chain.sway = root:GetAttribute("Sway") or 0.3
		chain.speed = root:GetAttribute("Speed") or 1
		chain.phase = root:GetAttribute("Phase") or 0
		chain.plane = pivot.Rotation
		chain.normal = normal
		-- How far out it is, in studs along itself, and when it may start creeping.
		chain.out = 0
		chain.delay = (chain.phase % (2 * math.pi)) / (2 * math.pi) * CONFIG.CreepStagger
		chain.startAt = nil
		table.insert(state.chains, chain)
	end
	return state
end

-- -1..1, easing across and holding at each end, so the tip clearly picks a side.
local function sweep(chain, now)
	local x = math.sin(now * CONFIG.SweepSpeed * chain.speed + chain.phase)
	return math.tanh(CONFIG.SweepHold * x) / math.tanh(CONFIG.SweepHold)
end

-- The resting shape `at` studs along the tentacle: back behind the knot before the route,
-- along the route through the body, then curling to one side or the other in the tip.
local function shapePoint(chain, at, curvature)
	if at <= 0 then
		return chain.points[1] + chain.backward * -at
	elseif at <= chain.bodyEnd then
		return (routePoint(chain.points, chain.lengths, at))
	end
	local d = at - chain.bodyEnd
	if math.abs(curvature) < 1e-3 then
		return chain.tipStart + chain.tipDirection * d
	end
	local angle = curvature * d
	return chain.tipStart
		+ chain.tipDirection * (math.sin(angle) / curvature)
		+ chain.tipSide * ((1 - math.cos(angle)) / curvature)
end

-- Moves chain.out toward fully out (open) or fully in (shut). Coming out it waits its turn,
-- jumps straight to the mouth of the hole, then eases up to CreepSpeed and slows again
-- over the last CreepEase studs.
local function creep(chain, open, now, dt, events)
	if not open then
		chain.startAt = nil
		chain.out = math.max(0, chain.out - CONFIG.WithdrawSpeed * dt)
		chain.emerged = chain.out > chain.hidden
		chain.gripped = false
		return
	end
	chain.startAt = chain.startAt or now + chain.delay
	if now < chain.startAt then
		return
	end
	local mouth = chain.hidden - CONFIG.HoleLead
	local left = chain.extent - chain.out
	local ease = math.min(math.max(chain.out - mouth, 0) + 0.5, left) / CONFIG.CreepEase
	local pace = CONFIG.CreepSpeed * math.clamp(ease, CONFIG.CreepMin, 1)
	chain.out = math.min(chain.extent, math.max(chain.out, mouth) + pace * dt)
	if not chain.emerged and chain.out > chain.hidden then
		chain.emerged = true
		table.insert(events, { kind = "emerge", position = chain.hole })
	end
	if not chain.gripped and chain.out >= chain.extent then
		chain.gripped = true
		table.insert(events, { kind = "grip", position = chain.bones[#chain.bones].TransformedWorldCFrame.Position })
	end
end

local function updateChain(rootPart, chain, open, now, dt, events)
	creep(chain, open, now, dt, events)
	local visible = chain.out / chain.extent
	local activity = CONFIG.Idle + (1 - CONFIG.Idle) * visible
	local amount = chain.sway * math.min(1, chain.total / CONFIG.SwayLength) * activity
	-- A gentle arc of angle a over length L ends about L * a / 2 to the side.
	local curl = math.min(CONFIG.TipCurl, 2 * CONFIG.TipSwing / chain.tipLength)
	local curvature = sweep(chain, now) * activity * curl / chain.tipLength
	-- Shut, the whole tentacle lies along the run-on behind the knot.
	local retract = chain.total - chain.out
	local swell = math.sin(now * CONFIG.SwellSpeed + chain.phase) * CONFIG.SwellAmount
	local length = chain.total + 1

	local curve = {}
	for c = 0, length, CONFIG.Step do
		local at = c - retract
		local u = math.clamp(at / chain.bodyEnd, 0, 1)
		-- The body ripples; the root end holds still and the tip does its own sweeping.
		local weight = math.sin(math.pi * u)
		local wave = now * chain.speed + chain.phase - u * CONFIG.Waves
		local ripple = Vector3.new(
			math.sin(wave),
			math.cos(wave * 0.8 + 1.3) * 0.7 + swell,
			chain.reach and math.sin(wave * 1.3 + 0.6) * 0.6 or 0
		)
		table.insert(curve, shapePoint(chain, at, curvature) + chain.plane * (ripple * amount * weight))
	end
	for _ = 1, CONFIG.SmoothPasses do
		local previous = curve[1]
		for i = 2, #curve - 1 do
			local current = curve[i]
			curve[i] = (previous + current * 2 + curve[i + 1]) / 4
			previous = current
		end
	end
	followCurve(rootPart, chain, curve)
end

-- open: whether the shop is open (tentacles creep out) or shut (they withdraw);
-- now: a clock in seconds; dt: seconds since the last update. Returns this frame's events.
function TentacleRig.update(state, open, now, dt)
	local events = {}
	for _, chain in state.chains do
		updateChain(state.rootPart, chain, open, now, dt, events)
	end
	return events
end

return TentacleRig
