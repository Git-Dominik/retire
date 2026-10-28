-- The shaft wall that rushes past the elevator doorway during a ride, so the car visibly moves.
-- Client-side and local, so it runs smoothly at the client's frame rate (server-side PivotTo
-- looks choppy). Elevator.server owns the ride and sets RideDir (1 going down, -1 going up,
-- 0 when still), RideStart (server time) and RideTime on the Elevator model.
-- The wall runs in the gap between the iron gate and the wooden doors, inside the place-only
-- ShaftWindow part in the Elevator model: an invisible slab covering the doorway, whose front
-- face looks into the car. The wall enters and leaves through the floor and the wall above the
-- doorway, which hide it, so from inside it looks like the landing drops away and the shaft
-- streams past. Going down the wall moves up; going up it moves down.

local RunService = game:GetService("RunService")

local CONFIG = {
	-- Studs per second at full speed, and the time spent getting up to it and slowing down.
	Speed = 30,
	SpeedUpTime = 1.2,
	SlowDownTime = 1.8,
	-- One concrete panel per segment, with a dark floor slab at its leading end.
	SegmentHeight = 2.6,
	SlabHeight = 0.4,
	-- How far past the window's sides the wall runs, out of sight behind the jambs.
	SideOverlap = 0.3,
	WallColor = Color3.fromRGB(104, 96, 86),
	SlabColor = Color3.fromRGB(42, 39, 36),
	-- A little light on the wall so it reads through the gate.
	LightColor = Color3.fromRGB(255, 214, 160),
	LightBrightness = 0.7,
	LightRange = 7,
}

local elevator = workspace:WaitForChild("Elevator")
local window = elevator:WaitForChild("ShaftWindow")

local folder = Instance.new("Folder")
folder.Name = "ShaftWall"
folder.Parent = workspace

local function newPart(name, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Color = color
	p.Material = material
	return p
end

-- Enough segments to fill the window plus one entering and one leaving.
local height = window.Size.Y
local pool = {}
for i = 1, math.ceil(height / CONFIG.SegmentHeight) + 2 do
	pool[i] = {
		wall = newPart("Wall", CONFIG.WallColor, Enum.Material.Concrete),
		slab = newPart("Slab", CONFIG.SlabColor, Enum.Material.Metal),
	}
end

local light = Instance.new("PointLight")
light.Color = CONFIG.LightColor
light.Brightness = CONFIG.LightBrightness
light.Range = CONFIG.LightRange
light.Shadows = false
light.Enabled = false
light.Parent = window

local function hideAll()
	for _, seg in pool do
		seg.wall.Parent = nil
		seg.slab.Parent = nil
	end
	light.Enabled = false
end

-- Distance travelled after t seconds of a ride lasting total: speed up, cruise, slow down.
local function travelled(t, total)
	local v, a, d = CONFIG.Speed, CONFIG.SpeedUpTime, CONFIG.SlowDownTime
	local function rising(x)
		return 0.5 * v / a * x * x
	end
	local cruise = math.max(total - a - d, 0)
	if t <= a then
		return rising(t)
	elseif t <= a + cruise then
		return rising(a) + v * (t - a)
	end
	local x = math.min(t - a - cruise, d)
	return rising(a) + v * cruise + v * x - 0.5 * v / d * x * x
end

local function render(t, total, dir)
	local frame = window.CFrame
	local width = window.Size.X + 2 * CONFIG.SideOverlap
	local depth = window.Size.Z
	local h = CONFIG.SegmentHeight
	-- u runs along the direction of travel: 0 at the window edge the wall enters through,
	-- height at the edge it leaves through. The leading edge enters at u = 0.
	local s = travelled(t, total)
	local distance = travelled(total, total)
	-- Whole segments only, and short enough that the trailing edge has left by the end.
	local count = math.max(math.floor((distance - height - 0.2) / h), 0)
	local first = math.max(math.floor((s - height) / h), 0)
	local last = math.min(math.floor(s / h), count - 1)
	local function y(u)
		return dir > 0 and (-height / 2 + u) or (height / 2 - u)
	end

	local used = 0
	for k = first, last do
		used += 1
		local seg = pool[used]
		if not seg then
			break
		end
		-- Segment k spans u in [s - (k + 1) h, s - k h]; its slab sits at the leading end.
		local mid = s - (k + 0.5) * h
		local slabMid = s - k * h - CONFIG.SlabHeight / 2
		seg.wall.Size = Vector3.new(width, h, depth)
		seg.wall.CFrame = frame * CFrame.new(0, y(mid), 0)
		seg.slab.Size = Vector3.new(width, CONFIG.SlabHeight, depth + 0.1)
		seg.slab.CFrame = frame * CFrame.new(0, y(slabMid), -0.05)
		seg.wall.Parent = folder
		seg.slab.Parent = folder
	end
	for i = used + 1, #pool do
		pool[i].wall.Parent = nil
		pool[i].slab.Parent = nil
	end
	light.Enabled = used > 0
end

local connection
local function onRide()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	hideAll()
	local dir = elevator:GetAttribute("RideDir") or 0
	local start = elevator:GetAttribute("RideStart")
	local total = elevator:GetAttribute("RideTime")
	if dir == 0 or not start or not total then
		return
	end
	connection = RunService.RenderStepped:Connect(function()
		local t = workspace:GetServerTimeNow() - start
		if t >= total then
			connection:Disconnect()
			connection = nil
			hideAll()
			return
		end
		render(math.max(t, 0), total, dir)
	end)
end

elevator:GetAttributeChangedSignal("RideDir"):Connect(onRide)
onRide()
