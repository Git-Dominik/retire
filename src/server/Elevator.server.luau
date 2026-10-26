-- Elevator ambience (music, machinery hum) and the door open/close sequence.
-- Doors move on the server so every player sees and hears the same thing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MUSIC_ID = "rbxassetid://9042688121" -- "Waltz From The Past" (APM, solo cello)
local HUM_ID = "rbxassetid://9112797280" -- "Industrial Presence 2" (Pro Sound Effects)
local DING_ID = "rbxassetid://18192219147"
local DOOR_CLOSE_ID = "rbxassetid://128821003758087"

local DOOR_TIME = 2.4
-- Gap between the ding and the doors starting to move.
local DING_LEAD = 0.7

local elevator = workspace:WaitForChild("Elevator")
local doorsFolder = elevator:WaitForChild("Doors")

-- ================= SOUNDS =================
local function makeSound(parent, name, id, props)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	for k, v in props do
		s[k] = v
	end
	s.Parent = parent
	return s
end

-- Music comes out of the gramophone, filtered thin and tinny like an old record.
local music = makeSound(elevator.Furniture.GramBox, "Music", MUSIC_ID, {
	Looped = true,
	Volume = 0.2,
	RollOffMinDistance = 12,
	RollOffMaxDistance = 70,
})
local recordEq = Instance.new("EqualizerSoundEffect")
recordEq.LowGain = -14
recordEq.MidGain = 2
recordEq.HighGain = -10
recordEq.Parent = music

-- Machinery under the floor: low, constant, only really noticed when it stops.
local hum = makeSound(elevator.Shell.Floor, "MachineryHum", HUM_ID, {
	Looped = true,
	Volume = 0.3,
	RollOffMinDistance = 30,
	RollOffMaxDistance = 90,
})
local humEq = Instance.new("EqualizerSoundEffect")
humEq.LowGain = 4
humEq.MidGain = -4
humEq.HighGain = -18
humEq.Parent = hum

local ding = makeSound(elevator.Fixtures.DialFace, "Ding", DING_ID, {
	Volume = 0.8,
	RollOffMinDistance = 25,
	RollOffMaxDistance = 120,
})
local doorSound = makeSound(doorsFolder.Threshold, "DoorClose", DOOR_CLOSE_ID, {
	Volume = 0.9,
	RollOffMinDistance = 20,
	RollOffMaxDistance = 100,
})

music:Play()
hum:Play()

-- ================= DOORS =================
-- Each leaf is the attributed part plus its decoration parts, which share its name prefix.
local leaves = {}
for _, leafName in { "DoorLeft", "DoorRight" } do
	local leaf = doorsFolder[leafName]
	local offset = elevator.PrimaryPart.CFrame.RightVector * leaf:GetAttribute("ClosedOffset")
	local parts = {}
	for _, p in doorsFolder:GetChildren() do
		if p:IsA("BasePart") and p.Name:sub(1, #leafName) == leafName then
			table.insert(parts, { part = p, open = p.CFrame, closed = p.CFrame + offset })
		end
	end
	table.insert(leaves, parts)
end

elevator:SetAttribute("DoorState", "Open")

local function moveDoors(target)
	local info = TweenInfo.new(DOOR_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local last
	for _, parts in leaves do
		for _, entry in parts do
			last = TweenService:Create(entry.part, info, { CFrame = entry[target] })
			last:Play()
		end
	end
	last.Completed:Wait()
end

local function setDoors(state)
	local current = elevator:GetAttribute("DoorState")
	if current == state or current == "Moving" then
		return
	end
	elevator:SetAttribute("DoorState", "Moving")
	ding:Play()
	task.wait(DING_LEAD)
	doorSound:Play()
	moveDoors(state == "Closed" and "closed" or "open")
	elevator:SetAttribute("DoorState", state)
end

-- ================= DEV REMOTE =================
local devRemote = Instance.new("RemoteEvent")
devRemote.Name = "ElevatorDev"
devRemote.Parent = ReplicatedStorage

local function isDev(player)
	return RunService:IsStudio() or player.UserId == game.CreatorId
end

devRemote.OnServerEvent:Connect(function(player, action)
	if not isDev(player) then
		return
	end
	if action == "Close" then
		setDoors("Closed")
	elseif action == "Open" then
		setDoors("Open")
	end
end)
