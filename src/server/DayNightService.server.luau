-- The day/night clock. One full day takes ShopConfig.DAY_LENGTH real seconds; Day runs
-- from DAWN_HOUR to DUSK_HOUR and Night the rest. This script owns the clock and the day
-- count; it only writes Lighting.ClockTime (once a CLOCK_WRITE_INTERVAL), and
-- DayNightClient eases every other lighting property on each client.
--
-- The clock is published as an anchor, so clients can run it smoothly on their own:
--   workspace.ClockAnchorTime  server time (workspace:GetServerTimeNow()) of the anchor
--   workspace.ClockAnchorHour  the hour at that moment
--   workspace.DayLength        seconds per full day
--   workspace.ClockPaused      true while the clock is held at ClockAnchorHour
-- The current hour is ClockAnchorHour + elapsed * 24 / DayLength (or just ClockAnchorHour
-- while paused). The server reads the anchor back every tick, so setting both attributes
-- (a dev tool, a test) jumps the clock.
-- The server starts paused at FIRST_NIGHT_HOUR, the night before Day 1. When the elevator
-- first comes back up to the store (Elevator.Level returns to 0) the clock jumps to dawn
-- and starts running: that's Day 1.
-- Also sets:
--   workspace.Phase      "Day" or "Night" (Journal.client's to-do list reads it too)
--   workspace.DayNumber  starts at 1 and goes up at each dawn; set before Phase changes
-- Fires the PhaseChanged remote (phase, dayNumber) on every change.
--
-- The store's neon OPEN sign goes dark at night: its own Flicker script (which would
-- relight it) is switched off, the letters drop to dull glass, and the glow and buzz stop.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))

local phaseRemote = Instance.new("RemoteEvent")
phaseRemote.Name = "PhaseChanged"
phaseRemote.Parent = ReplicatedStorage

local function hourNow()
	if workspace:GetAttribute("ClockPaused") then
		return workspace:GetAttribute("ClockAnchorHour")
	end
	local anchorTime = workspace:GetAttribute("ClockAnchorTime")
	local anchorHour = workspace:GetAttribute("ClockAnchorHour")
	local length = workspace:GetAttribute("DayLength")
	local elapsed = workspace:GetServerTimeNow() - anchorTime
	return (anchorHour + elapsed * 24 / length) % 24
end

local function phaseAt(hour)
	return (hour >= Config.DAWN_HOUR and hour < Config.DUSK_HOUR) and "Day" or "Night"
end

-- ================= OPEN SIGN =================
-- Back to how its own script left it for the day, or dark for the night.
local function setSignLit(lit)
	-- The store is parked in ServerStorage while the elevator is down.
	local store = workspace:FindFirstChild("Grocery Store")
		or ServerStorage:FindFirstChild("Grocery Store")
	local sign = store and store:FindFirstChild("Neon Open Sign")
	if not sign then
		return
	end
	local flicker = sign:FindFirstChild("Flicker")
	if flicker and flicker:IsA("Script") then
		flicker.Enabled = lit
	end
	for _, group in sign:GetChildren() do
		local color = group:GetAttribute("NeonColor")
		if group:IsA("Model") and color then
			for _, p in group:GetDescendants() do
				if p:IsA("BasePart") then
					p.Material = lit and Enum.Material.Neon or Enum.Material.Glass
					p.Color = lit and color or color:Lerp(Color3.new(0.1, 0.08, 0.08), 0.75)
				end
			end
		end
	end
	for _, d in sign:GetDescendants() do
		if d:IsA("Light") then
			d.Enabled = lit
		elseif d:IsA("Sound") then
			d.Volume = lit and 0.12 or 0
		end
	end
end

-- ================= CLOCK =================
workspace:SetAttribute("DayLength", Config.DAY_LENGTH)
workspace:SetAttribute("ClockAnchorTime", workspace:GetServerTimeNow())
workspace:SetAttribute("ClockAnchorHour", Config.FIRST_NIGHT_HOUR)
workspace:SetAttribute("ClockPaused", true)
workspace:SetAttribute("DayNumber", 1)

local phase = phaseAt(Config.FIRST_NIGHT_HOUR)
-- The first dawn starts Day 1 rather than moving on from it.
local firstDawn = true
workspace:SetAttribute("Phase", phase)
setSignLit(phase == "Day")

local sinceWrite = math.huge
RunService.Heartbeat:Connect(function(dt)
	local hour = hourNow()
	sinceWrite += dt
	if sinceWrite >= Config.CLOCK_WRITE_INTERVAL then
		sinceWrite = 0
		Lighting.ClockTime = hour
	end

	local now = phaseAt(hour)
	if now == phase then
		return
	end
	phase = now
	if now == "Day" then
		if not firstDawn then
			workspace:SetAttribute("DayNumber", workspace:GetAttribute("DayNumber") + 1)
		end
		firstDawn = false
	end
	workspace:SetAttribute("Phase", now)
	setSignLit(now == "Day")
	phaseRemote:FireAllClients(now, workspace:GetAttribute("DayNumber"))
end)

-- ================= FIRST DAY =================
-- Back up from the first trip down: dawn breaks and the clock starts.
task.spawn(function()
	local elevator = workspace:WaitForChild("Elevator")
	local wasDown = false
	local connection
	connection = elevator:GetAttributeChangedSignal("Level"):Connect(function()
		local level = elevator:GetAttribute("Level") or 0
		if level > 0 then
			wasDown = true
		elseif wasDown then
			connection:Disconnect()
			workspace:SetAttribute("ClockAnchorTime", workspace:GetServerTimeNow())
			workspace:SetAttribute("ClockAnchorHour", Config.DAWN_HOUR)
			workspace:SetAttribute("ClockPaused", false)
		end
	end)
end)
