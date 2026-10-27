-- The bell over the shop door: rings once when the player walks in from the street.
-- Client-side and local: each player hears their own entrance.
-- It watches the invisible DoorTrigger part in the doorway of the Grocery Store model (place-only,
-- so the store can be moved without touching this). It rings when the character steps into the
-- trigger from the outside, judged by which side of the trigger the store's AmbienceZone is on.
-- Teleports (the elevator arriving at the store, respawning) jump the character far in one
-- frame, which is how they're told apart from walking, and stay silent.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local CONFIG = {
	-- "Desk Bell Counter Service Single Ringing Dings 2" (Pro Sound Effects); same asset the elevator
	-- service bell uses, pitched up so it reads as a small door bell. The owner preferred this over
	-- "Store Entry Bell 1" (9119642644).
	SoundId = "rbxassetid://9125485659",
	Volume = 0.4,
	PlaybackSpeed = 1.35,
	-- Further than a sprint covers in one frame means the character was moved, not walked.
	MaxStepPerFrame = 6,
	-- Don't re-ring if the player hovers in and out of the doorway.
	Cooldown = 4,
}

local player = Players.LocalPlayer

local bell = Instance.new("Sound")
bell.Name = "DoorBell"
bell.SoundId = CONFIG.SoundId
bell.Volume = CONFIG.Volume
bell.PlaybackSpeed = CONFIG.PlaybackSpeed
bell.Parent = SoundService

local function rootPosition()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function doorway()
	local store = workspace:FindFirstChild("Grocery Store")
	local trigger = store and store:FindFirstChild("DoorTrigger")
	local zone = store and store:FindFirstChild("AmbienceZone")
	return trigger, zone
end

-- Which side of the trigger (along its X axis) the street is on: opposite the store's interior.
local function streetSign(trigger, zone)
	local sign = trigger.CFrame:PointToObjectSpace(zone.Position).X
	return if sign > 0 then -1 else 1
end

local function inBox(trigger, position)
	local offset = trigger.CFrame:PointToObjectSpace(position)
	local half = trigger.Size / 2
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z
end

local wasInside, lastPosition, enteredFromStreet
local lastRing = -math.huge

RunService.Heartbeat:Connect(function()
	local position = rootPosition()
	local trigger, zone = doorway()
	if not (position and trigger and zone) then
		-- No character or no store (parked while the elevator is down): forget where we were.
		wasInside, lastPosition = nil, nil
		return
	end
	local inside = inBox(trigger, position)
	local walked = lastPosition and (position - lastPosition).Magnitude <= CONFIG.MaxStepPerFrame
	if inside and not wasInside and walked then
		local from = trigger.CFrame:PointToObjectSpace(lastPosition).X
		enteredFromStreet = from * streetSign(trigger, zone) > 0
	end
	if wasInside and not inside and walked and enteredFromStreet then
		-- Stepped through to the store side: ring when they clear the doorway, not on the threshold.
		local to = trigger.CFrame:PointToObjectSpace(position).X
		if to * streetSign(trigger, zone) < 0 and os.clock() - lastRing > CONFIG.Cooldown then
			lastRing = os.clock()
			bell:Play()
		end
	end
	if not inside then
		enteredFromStreet = nil
	end
	wasInside, lastPosition = inside, position
end)
