-- Animates the cargo lift in the elevator's back wall on this client, so it moves at
-- the full frame rate. Cargo.server owns the rules and only sets attributes:
--   CargoLift.CargoValue      drums roll to it
--   CargoLift.SendSeq/SendAt  a trip started at SendAt (server time): button, gate,
--                             ride up, pause, ride down, gate
--   Elevator.CargoTripsLeft   a lamp sputters out for each trip used
-- Parts are moved locally only; on the server everything stays at rest.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local elevator = workspace:WaitForChild("Elevator")
local lift = elevator:WaitForChild("CargoLift")
local floorPart = elevator:WaitForChild("Shell"):WaitForChild("Floor")
local car = lift:WaitForChild("Car")
local gate = lift:WaitForChild("Gate")
local button = lift:WaitForChild("SendButton")
local counter = lift:WaitForChild("ValueCounter")
local tripLamps = lift:WaitForChild("TripLamps")
local sheave = lift:WaitForChild("Sheave")
local wheel = sheave:WaitForChild("Wheel")

local MAX_TRIPS = 3
-- Degrees between neighbouring digits on a counter drum.
local DIGIT_STEP = 36
-- Spacing of the splice marks that show the visible ropes running over the sheave.
local MARK_SPACING = 0.9

local LAMP_ON = Color3.fromRGB(110, 225, 95)
local LAMP_OFF = Color3.fromRGB(40, 46, 36)

-- All Pro Sound Effects library sounds.
local SOUNDS = {
	Button = { "rbxassetid://9114303090", 0.6 }, -- "Elevator Button 1"
	Gate = { "rbxassetid://9113763589", 0.45 }, -- "Chain Rattle Glassy Metal Rattle 2"
	Rattle = { "rbxassetid://9116780292", 0.28 }, -- "Metal Pulley 1", rickety rattle (looped)
	Squeak = { "rbxassetid://9117951813", 0.16 }, -- "Pulley Rotating Movement With Squeaking 2" (looped)
	Bell = { "rbxassetid://9125485591", 0.4 }, -- "Desk Bell Counter Service Single Ringing Dings 1"
	Land = { "rbxassetid://9120884415", 0.4 }, -- "Wood Hit Bump Wood Impacts On Concrete 2"
	Drums = { "rbxassetid://9126015861", 0.45 }, -- "Switch Cassette Deck Resetting Tape Counter 5"
	Lamp = { "rbxassetid://9120093894", 0.4 }, -- "Toggle Switch Metal Industrial Equipment 130"
	Drop = { "rbxassetid://9120884415", 0.2 }, -- the bump again, pitched up, for items landing
}

local sounds = {}
local function makeSound(name, parent)
	local def = SOUNDS[name]
	local s = Instance.new("Sound")
	s.Name = "Cargo" .. name
	s.SoundId = def[1]
	s.Volume = def[2]
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 55
	s.Parent = parent
	sounds[name] = s
	return s
end
makeSound("Button", button:WaitForChild("Bezel"))
makeSound("Gate", lift:WaitForChild("LoadPoint"))
makeSound("Rattle", wheel:WaitForChild("Rim")).Looped = true
makeSound("Squeak", wheel.Rim).Looped = true
makeSound("Bell", wheel.Rim)
makeSound("Land", lift.LoadPoint)
makeSound("Drums", counter.Drums.Drum3.Axle)
makeSound("Lamp", tripLamps:WaitForChild("Lamp2"):FindFirstChildWhichIsA("BasePart"))
makeSound("Drop", lift.LoadPoint).PlaybackSpeed = 1.5

local facing = -floorPart.CFrame.LookVector -- out of the cabinet, toward the room
local up = floorPart.CFrame.UpVector

-- Turns a model about an axis through a point, relative to where it started.
local function turned(rest, point, axis, angle)
	return CFrame.new(point) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-point) * rest
end

-- ================= EASING =================
local function ease(t, style, direction)
	return TweenService:GetValue(math.clamp(t, 0, 1), style, direction)
end

-- Arrives by `impact` (0..1 of the time) along `style`, then gives one small rebound of
-- `bounce` (a fraction of the distance) and settles. Gentler than Bounce easing.
local function landing(t, impact, bounce, style, direction)
	if t < impact then
		return ease(t / impact, style, direction)
	end
	local u = (t - impact) / (1 - impact)
	return 1 - bounce * math.sin(math.pi * u) * (1 - u)
end

-- Runs fn(t) every frame for `duration` seconds, t going 0 to 1, starting `offset`
-- seconds in (to catch up with a trip that started before this client heard of it).
local function animate(duration, fn, offset)
	local start = os.clock() - (offset or 0)
	while true do
		local t = math.min((os.clock() - start) / duration, 1)
		fn(t)
		if t >= 1 then
			return
		end
		RunService.RenderStepped:Wait()
	end
end

-- ================= REST POSES =================
local carHome = car:GetPivot()
-- The gate is stored below the opening; it closes from above, so it parks behind the
-- upper panel while open and is hidden there.
local gateClosed = gate:GetPivot() - up * gate:GetAttribute("ClosedDrop")
local gateTravel = math.abs(gate:GetAttribute("ClosedDrop"))
local gateParts = {}
for _, p in gate:GetDescendants() do
	if p:IsA("BasePart") then
		gateParts[p] = p.Transparency
	end
end
local gateHidden
local press = button:WaitForChild("Press")
local pressRest = press:GetPivot()
local pressTravel = button:GetAttribute("Travel")

local function setGate(closed) -- 0 open .. 1 shut
	gate:PivotTo(gateClosed + up * gateTravel * (1 - closed))
	local hide = closed <= 0.001
	if hide ~= gateHidden then
		gateHidden = hide
		for p, transparency in gateParts do
			p.Transparency = hide and 1 or transparency
		end
	end
end
setGate(0)

-- ================= ROPES & SHEAVE =================
-- The sheave and its ropes are geared to the car: the wheel turns by the distance the
-- car travels over its radius, and splice marks slide along the two visible ropes, one
-- side running up while the other runs down.
local wheelRest = wheel:GetPivot()
local wheelCentre = wheel.Rim.Position
local wheelRadius = wheel.Rim.Size.Y / 2
local ropes = {}
for _, cable in sheave:GetChildren() do
	if cable.Name == "Cable" then
		local side = floorPart.CFrame:PointToObjectSpace(cable.Position).X < 0 and -1 or 1
		local marks = {}
		for i = 1, math.floor(cable.Size.X / MARK_SPACING) do
			local mark = Instance.new("Part")
			mark.Name = "Splice"
			mark.Anchored = true
			mark.CanCollide = false
			mark.CanQuery = false
			mark.CanTouch = false
			mark.CastShadow = false
			mark.Shape = Enum.PartType.Cylinder
			mark.Size = Vector3.new(0.14, cable.Size.Y + 0.04, cable.Size.Z + 0.04)
			mark.Color = Color3.fromRGB(34, 30, 26)
			mark.Material = Enum.Material.Fabric
			mark.Parent = cable
			marks[i] = mark
		end
		table.insert(ropes, { cable = cable, side = side, marks = marks })
	end
end

local function setRope(height)
	wheel:PivotTo(turned(wheelRest, wheelCentre, facing, -height / wheelRadius))
	for _, rope in ropes do
		local length = rope.cable.Size.X
		local along = rope.cable.CFrame.RightVector
		local start = rope.cable.Position - along * length / 2
		for i, mark in rope.marks do
			local d = ((i - 1) * MARK_SPACING + height * rope.side) % length
			mark.CFrame = CFrame.new(start + along * d) * (rope.cable.CFrame - rope.cable.Position)
		end
	end
end

-- Places the car `height` studs above home, with a little sway on its cables.
local carRotation = carHome - carHome.Position
-- `rope` is how far the ropes have run, when that differs from the car's height (the
-- haul keeps going after the car is out of sight).
local function setCar(height, sway, clock, rope)
	local bob = math.sin(clock * 8) * 0.025 * sway
	local tilt = CFrame.Angles(math.sin(clock * 4.7) * 0.007 * sway, 0, math.sin(clock * 3.6) * 0.011 * sway)
	car:PivotTo(CFrame.new(carHome.Position + up * (height + bob)) * tilt * carRotation)
	setRope(rope or height)
end

-- Rope run of a haul `s` seconds in, for one lasting `total`: a hard pull up to cruising
-- speed, a steady run, then braking at the end. Returns distance and speed (0..1).
local CRUISE = 4.5
local ACCEL, BRAKE = 0.4, 0.9
local function haul(s, total)
	s = math.clamp(s, 0, total)
	local brakeAt = total - BRAKE
	if s < ACCEL then
		return CRUISE * s * s / (2 * ACCEL), s / ACCEL
	end
	local d = CRUISE * ACCEL / 2 + CRUISE * (math.min(s, brakeAt) - ACCEL)
	if s <= brakeAt then
		return d, 1
	end
	local u = s - brakeAt
	return d + CRUISE * (u - u * u / (2 * BRAKE)), 1 - u / BRAKE
end

local function setPitch(speed)
	sounds.Squeak.PlaybackSpeed = 0.8 + 0.35 * speed
	sounds.Rattle.PlaybackSpeed = 0.85 + 0.25 * speed
end
setRope(0)

-- ================= LAMPS =================
local function lightLamp(lamp, lit)
	for _, p in lamp:GetDescendants() do
		if p:IsA("BasePart") then
			p.Color = lit and LAMP_ON or LAMP_OFF
			p.Material = lit and Enum.Material.Neon or Enum.Material.Glass
		end
	end
	local glow = lamp:FindFirstChild("Glow", true)
	if glow then
		glow.Enabled = lit
	end
end

-- Lamps go out from the right, so lamp 3 is the first trip spent. One going out
-- sputters a couple of times before it dies.
local lampLit = {}
local function setLamps(animate)
	local left = elevator:GetAttribute("CargoTripsLeft") or MAX_TRIPS
	for i = 1, MAX_TRIPS do
		local lamp = tripLamps:FindFirstChild("Lamp" .. i)
		local lit = i <= left
		if lamp and lampLit[i] ~= lit then
			lampLit[i] = lit
			if animate then
				sounds.Lamp:Play()
				task.spawn(function()
					for _, gap in { 0.06, 0.08, 0.05, 0.14 } do
						lightLamp(lamp, not lit)
						task.wait(gap)
						lightLamp(lamp, lit)
						task.wait(gap * 0.6)
					end
				end)
			else
				lightLamp(lamp, lit)
			end
		end
	end
end
setLamps(false)
elevator:GetAttributeChangedSignal("CargoTripsLeft"):Connect(function()
	setLamps(true)
end)

-- ================= DRUM COUNTER =================
-- Each drum is a ten-sided wheel on an axle along the cabinet face, built with 0 at the
-- front. Turning it forward by DIGIT_STEP brings the next digit down into the window.
local drums = {}
for k = 1, 5 do
	local drum = counter.Drums:WaitForChild("Drum" .. k)
	local axis = floorPart.CFrame:PointToWorldSpace(
		Vector3.new(drum:GetAttribute("AxisX"), counter:GetAttribute("AxisY"), counter:GetAttribute("AxisZ"))
	)
	drums[k] = { model = drum, rest = drum:GetPivot(), axis = axis, angle = 0, run = 0 }
end

local function setDrum(entry, angle)
	entry.angle = angle
	entry.model:PivotTo(turned(entry.rest, entry.axis, floorPart.CFrame.RightVector, math.rad(angle)))
end

-- Always rolls forward, the way a mechanical counter does, with a small overshoot.
local function rollDrum(entry, digit, delay)
	local delta = (digit * DIGIT_STEP - entry.angle % 360) % 360
	if delta == 0 then
		return
	end
	entry.run += 1
	local run = entry.run
	local from = entry.angle
	task.delay(delay, function()
		animate(0.16 + delta / 360 * 0.3, function(t)
			if entry.run == run then
				setDrum(entry, from + delta * ease(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
			end
		end)
	end)
end

local function showValue(animate)
	local value = lift:GetAttribute("CargoValue") or 0
	local text = string.format("%05d", math.clamp(math.floor(value + 0.5), 0, 99999))
	for k = 5, 1, -1 do
		local digit = tonumber(text:sub(k, k))
		if animate then
			-- Units drum first, then each higher drum a beat later.
			rollDrum(drums[k], digit, (5 - k) * 0.035)
		else
			setDrum(drums[k], digit * DIGIT_STEP)
		end
	end
	if animate then
		sounds.Drums:Play()
	end
end
showValue(false)
lift:GetAttributeChangedSignal("CargoValue"):Connect(function()
	showValue(true)
end)

-- ================= ITEMS =================
-- A newly loaded item drops onto the platform and settles with one small hop.
car.ChildAdded:Connect(function(item)
	if not item:IsA("BasePart") or not item:GetAttribute("ScavengedLevel") then
		return
	end
	local landed = item.CFrame
	local carOffset = carHome:ToObjectSpace(landed)
	sounds.Drop:Play()
	task.spawn(function()
		animate(0.32, function(t)
			if item.Parent ~= car then
				return
			end
			local h = 0.7 * (1 - landing(t, 0.5, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
			-- Relative to the car, in case it's already moving.
			item.CFrame = car:GetPivot() * carOffset + up * h
		end)
	end)
end)

-- ================= A TRIP =================
local function trip(offset)
	local T = {
		lead = lift:GetAttribute("PressLead"),
		gate = lift:GetAttribute("GateTime"),
		ride = lift:GetAttribute("RideTime"),
		pause = lift:GetAttribute("TopPause"),
		back = lift:GetAttribute("ReturnTime"),
		rise = lift:GetAttribute("Rise"),
	}
	local skip = offset

	-- Plays a phase, or skips it (snapping to its end) if we joined after it finished.
	local function phase(duration, fn)
		if skip >= duration then
			skip -= duration
			fn(1)
			return
		end
		animate(duration, fn, skip)
		skip = 0
	end
	-- Button: snaps in, eases back out with a slight overshoot.
	if skip < 0.1 then
		sounds.Button:Play()
	end
	task.spawn(function()
		animate(0.05, function(t)
			press:PivotTo(pressRest - facing * pressTravel * ease(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		end)
		task.wait(0.06)
		animate(0.22, function(t)
			press:PivotTo(pressRest - facing * pressTravel * (1 - ease(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out)))
		end)
	end)
	phase(T.lead, function() end)

	-- Gate drops shut and rebounds once.
	if skip < T.gate then
		sounds.Gate:Play()
	end
	phase(T.gate, function(t)
		setGate(landing(t, 0.55, 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
	end)

	-- Ride up: squat as the cable takes the load, then a smooth climb. The loaded items
	-- are children of the car, so they ride along.
	sounds.Rattle:Play()
	sounds.Squeak:Play()
	-- Ride up: the car squats as the cable takes the load, lurches off, catches once on
	-- the guides and is gone in a few seconds; the ropes keep hauling until it reaches the
	-- store.
	local SQUAT = 0.16
	local ropeTop = haul(T.ride - SQUAT, T.ride - SQUAT)
	phase(T.ride, function(t)
		local s = t * T.ride
		local rope, speed = haul(s - SQUAT, T.ride - SQUAT)
		local squat = -0.12 * ease(s / SQUAT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			* (1 - ease((s - SQUAT) / 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		local hitch = (s > 1 and s < 1.14) and -0.06 * math.sin(math.pi * (s - 1) / 0.14) or 0
		setCar(math.min(rope, T.rise) + squat + hitch, speed, os.clock(), rope)
		setPitch(speed)
	end)
	sounds.Rattle:Stop()
	sounds.Squeak:Stop()
	sounds.Bell:Play()

	phase(T.pause, function() end)

	-- Ride down, easing in, with one soft bump on the buffers.
	sounds.Rattle:Play()
	sounds.Squeak:Play()
	local landed = false
	phase(T.back, function(t)
		local height = T.rise * (1 - landing(t, 0.8, 0.03, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut))
		local speed = math.sin(math.pi * math.min(t / 0.8, 1))
		setCar(height, speed, os.clock(), ropeTop - T.rise + height)
		setPitch(speed)
		if not landed and t >= 0.8 then
			landed = true
			sounds.Rattle:Stop()
			sounds.Squeak:Stop()
			sounds.Land:Play()
		end
	end)
	sounds.Rattle:Stop()
	sounds.Squeak:Stop()
	setCar(0, 0, 0, ropeTop - T.rise)

	-- Out of trips: the gate stays shut for good.
	if (elevator:GetAttribute("CargoTripsLeft") or 0) > 0 then
		sounds.Gate:Play()
		phase(T.gate, function(t)
			local raised = t < 0.18 and -0.015 * math.sin(math.pi * t / 0.18)
				or ease((t - 0.18) / 0.82, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			setGate(1 - raised)
		end)
	end
end

local lastSeq = lift:GetAttribute("SendSeq") or 0
lift:GetAttributeChangedSignal("SendSeq"):Connect(function()
	local seq = lift:GetAttribute("SendSeq") or 0
	if seq <= lastSeq then
		return
	end
	lastSeq = seq
	local offset = math.max(0, workspace:GetServerTimeNow() - (lift:GetAttribute("SendAt") or 0))
	task.spawn(trip, offset)
end)

-- Joining with no trips left: the gate is already shut.
if (elevator:GetAttribute("CargoTripsLeft") or MAX_TRIPS) == 0 then
	setGate(1)
end
