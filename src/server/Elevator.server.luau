-- Elevator ambience, the door open/close sequence, and the floor-by-floor descent.
-- Doors move on the server so every player sees and hears the same thing.
--
-- Loop: everyone boards -> doors shut -> the room outside is swapped during a short
-- "ride" -> doors open on the next floor. From floor 1 on, the elevator only leaves
-- once that floor's item has been placed on the merchant's tray.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Levels = require(script.Parent.Levels)
local Library = require(script.Parent.Library)

local MUSIC_ID = "rbxassetid://9042688121" -- "Waltz From The Past" (APM, solo cello)
local HUM_ID = "rbxassetid://9112797280" -- "Industrial Presence 2" (Pro Sound Effects)
local MOVE_ID = "rbxassetid://18454901772" -- elevator moving loop
local DING_ID = "rbxassetid://18192219147"
local DOOR_CLOSE_ID = "rbxassetid://128821003758087"

local DOOR_TIME = 2.4
-- Gap between the ding and the doors starting to move.
local DING_LEAD = 0.7
-- Gap between the wooden doors and the iron gate starting to move.
local GATE_LAG = 0.6
-- How long the ride between floors lasts once the doors are shut.
local DESCENT_TIME = 20
-- Everyone has to stay aboard this long before the doors close.
local BOARD_DELAY = 2

local MUSIC_VOLUME = 0.2
local MOVE_VOLUME = 0.225

local elevator = workspace:WaitForChild("Elevator")
local doorsFolder = elevator:WaitForChild("Doors")
local floorPart = elevator.PrimaryPart
local tray = elevator.Furniture.OfferingTray

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
-- It only plays while the elevator is moving, and picks up where it left off.
local music = makeSound(elevator.Furniture.GramBox, "Music", MUSIC_ID, {
	Looped = true,
	Volume = 0,
	RollOffMinDistance = 12,
	RollOffMaxDistance = 70,
})
local recordEq = Instance.new("EqualizerSoundEffect")
recordEq.LowGain = -14
recordEq.MidGain = 2
recordEq.HighGain = -10
recordEq.Parent = music

-- The machinery is out in the shaft, so it's heard through the walls:
-- highs gone, mids dulled, a short boxy reverb.
local function muffle(sound, eq)
	local e = Instance.new("EqualizerSoundEffect")
	e.LowGain = eq.low
	e.MidGain = eq.mid
	e.HighGain = eq.high
	e.Parent = sound
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 0.8
	reverb.Density = 1
	reverb.Diffusion = 1
	reverb.DryLevel = 0
	reverb.WetLevel = -12
	reverb.Parent = sound
end

-- Machinery under the floor: low, constant, only really noticed when it stops.
local hum = makeSound(floorPart, "MachineryHum", HUM_ID, {
	Looped = true,
	Volume = 0.06,
	RollOffMinDistance = 30,
	RollOffMaxDistance = 90,
})
muffle(hum, { low = 2, mid = -14, high = -40 })

local moveSound = makeSound(floorPart, "Moving", MOVE_ID, {
	Looped = true,
	Volume = 0,
	RollOffMinDistance = 30,
	RollOffMaxDistance = 90,
})
muffle(moveSound, { low = 3, mid = -8, high = -24 })

local ding = makeSound(elevator.Fixtures.DialFace, "Ding", DING_ID, {
	Volume = 0.25,
	RollOffMinDistance = 25,
	RollOffMaxDistance = 120,
})
local doorSound = makeSound(doorsFolder.Threshold, "DoorClose", DOOR_CLOSE_ID, {
	Volume = 0.3,
	RollOffMinDistance = 20,
	RollOffMaxDistance = 100,
})

hum:Play()

-- Fades a looped sound in or out; fading out pauses it so it resumes in place.
local function fade(sound, volume, time)
	if volume > 0 and not sound.IsPlaying then
		sound:Resume()
	end
	local tween = TweenService:Create(sound, TweenInfo.new(time), { Volume = volume })
	tween:Play()
	if volume == 0 then
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				sound:Pause()
			end
		end)
	end
end

-- ================= DOORS =================
-- Every moving part with its open and closed property goals.
local doorParts = {}

-- Each leaf is the attributed part plus its decoration parts, which share its name prefix.
for _, leafName in { "DoorLeft", "DoorRight" } do
	local leaf = doorsFolder[leafName]
	local offset = floorPart.CFrame.RightVector * leaf:GetAttribute("ClosedOffset")
	for _, p in doorsFolder:GetChildren() do
		if p:IsA("BasePart") and p.Name:sub(1, #leafName) == leafName then
			table.insert(doorParts, { part = p, open = { CFrame = p.CFrame }, closed = { CFrame = p.CFrame + offset } })
		end
	end
end

-- The inner scissor gate sits folded at both jambs. Closing spreads each half's bars
-- evenly to the centre and flattens its lattice struts across the gap.
local GATE_BARS = 5 -- highest bar index per half
for _, p in doorsFolder:GetChildren() do
	local kind, side, index = p.Name:match("^Gate(%a+)(%-?1)_(%d)$")
	if not kind then
		continue
	end
	side, index = tonumber(side), tonumber(index)
	local outer = doorsFolder[`GateBar{side}_0`]
	local localPos = floorPart.CFrame:PointToObjectSpace(p.Position)
	local outerX = math.abs(floorPart.CFrame:PointToObjectSpace(outer.Position).X)
	local innerX = outer.Size.X / 2
	local closed
	if kind == "Bar" then
		local x = side * (outerX - (outerX - innerX) * index / GATE_BARS)
		closed = { CFrame = floorPart.CFrame * CFrame.new(x, localPos.Y, localPos.Z) }
	elseif kind == "Lattice" then
		local span = outerX - innerX
		local rise = p.Size.X * math.abs(math.sin(math.rad(p.Orientation.Z)))
		local length = math.sqrt(span * span + rise * rise)
		local centre = Vector3.new(side * (outerX + innerX) / 2, localPos.Y, localPos.Z)
		closed = {
			CFrame = floorPart.CFrame * CFrame.new(centre) * CFrame.Angles(0, 0, side * math.atan2(rise, span)),
			Size = Vector3.new(length, p.Size.Y, p.Size.Z),
		}
	end
	if closed then
		table.insert(doorParts, { part = p, gate = true, open = { CFrame = p.CFrame, Size = p.Size }, closed = closed })
	end
end

elevator:SetAttribute("DoorState", "Open")

local function moveDoors(target)
	local info = TweenInfo.new(DOOR_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local function play(gate)
		local last
		for _, entry in doorParts do
			if (entry.gate == true) == gate then
				last = TweenService:Create(entry.part, info, entry[target])
				last:Play()
			end
		end
		return last
	end
	-- Closing shuts the wooden doors and then draws the gate; opening reverses it.
	local gateFirst = target == "open"
	play(gateFirst)
	task.wait(GATE_LAG)
	play(not gateFirst).Completed:Wait()
end

-- ================= FLOOR DIAL =================
-- The needle above the doors sweeps one tick per floor, from tick 0 (lobby) on
-- the left to tick 8 on the right, pivoting on the dial hub.
local DIAL_TICKS = 8
local DIAL_FIRST_ANGLE = -80
local DIAL_STEP = 20
local needle = elevator.Fixtures.DialNeedle
local dialFace = elevator.Fixtures.DialFace
-- Hub position with the needle's current swing taken out, so angles are absolute.
local needlePivot = CFrame.new(needle.Position - needle.CFrame.UpVector * needle.Size.Y / 2)
	* needle.CFrame.Rotation
	* CFrame.Angles(0, 0, -math.rad(needle.Orientation.Z))
-- Shortened so the tip stops just short of the floor numbers instead of covering them.
needle.Size = Vector3.new(needle.Size.X, 0.8, needle.Size.Z)

local function needleCFrame(floor)
	local angle = math.rad(DIAL_FIRST_ANGLE + DIAL_STEP * math.min(floor, DIAL_TICKS))
	return needlePivot * CFrame.Angles(0, 0, angle) * CFrame.new(0, needle.Size.Y / 2, 0)
end

local function setDial(floor, time)
	TweenService:Create(needle, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		CFrame = needleCFrame(floor),
	}):Play()
end

-- Floor numbers printed just inside each tick.
do
	local gui = Instance.new("SurfaceGui")
	gui.Name = "FloorNumbers"
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.LightInfluence = 1
	gui.Parent = dialFace
	local faceRadius = 100 * dialFace.Size.Y / 2
	for tick = 0, DIAL_TICKS do
		local angle = math.rad(DIAL_FIRST_ANGLE + DIAL_STEP * tick)
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromOffset(faceRadius + math.sin(angle) * 100, faceRadius - math.cos(angle) * 100)
		label.Size = UDim2.fromOffset(40, 30)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Garamond
		label.TextSize = 28
		label.TextColor3 = Color3.fromRGB(58, 40, 26)
		label.Text = tick == 0 and "L" or tostring(tick)
		label.Parent = gui
	end
end

setDial(0, 0)

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

-- ================= FLOORS =================
local level = 0
local offered = false
local descending = false
local room, roomItem, roomItemName
local shownOffering

elevator:SetAttribute("Level", level)

-- Floor-level CFrame at the elevator's outer door face, looking out of the elevator.
local roomBase = floorPart.CFrame * CFrame.new(0, floorPart.Size.Y / 2, floorPart.Size.Z / 2)

local offerPrompt = Instance.new("ProximityPrompt")
offerPrompt.Name = "OfferPrompt"
offerPrompt.ObjectText = "Merchant"
offerPrompt.KeyboardKeyCode = Enum.KeyCode.E
offerPrompt.MaxActivationDistance = 7
offerPrompt.RequiresLineOfSight = false
offerPrompt.Enabled = false
offerPrompt.Parent = tray

local function findOffering(container)
	if not container then
		return nil
	end
	for _, tool in container:GetChildren() do
		if tool:IsA("Tool") and tool:GetAttribute("OfferingLevel") == level then
			return tool
		end
	end
	return nil
end

local function giveItem(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or roomItem.Transparency > 0 then
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = roomItemName
	tool.CanBeDropped = false
	tool:SetAttribute("OfferingLevel", level)
	local handle = roomItem:Clone()
	handle.Name = "Handle"
	handle:ClearAllChildren()
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	-- The original stays in the room, hidden, and comes back if the carrier dies or leaves.
	local item, prompt = roomItem, roomItem.TakePrompt
	item.Transparency = 1
	prompt.Enabled = false
	tool.Destroying:Connect(function()
		if not offered and item.Parent then
			item.Transparency = 0
			prompt.Enabled = true
		end
	end)

	tool.Parent = player.Backpack
	humanoid:EquipTool(tool)
end

offerPrompt.Triggered:Connect(function(player)
	if offered or descending then
		return
	end
	local tool = findOffering(player.Character) or findOffering(player:FindFirstChild("Backpack"))
	if not tool then
		return
	end
	offered = true
	offerPrompt.Enabled = false

	shownOffering = tool.Handle:Clone()
	shownOffering.Name = "Offering"
	shownOffering.Anchored = true
	shownOffering.Parent = elevator
	Levels.rest(shownOffering, tray.CFrame * CFrame.new(0, tray.Size.Y / 2, 0))
	tool:Destroy()
end)

local function clearLevel()
	if room then
		room:Destroy()
		room = nil
	end
	if shownOffering then
		shownOffering:Destroy()
		shownOffering = nil
	end
	-- Anything still carried from the floor being left behind is gone.
	for _, player in Players:GetPlayers() do
		for _, container in { player.Character, player:FindFirstChild("Backpack") } do
			for _, tool in container and container:GetChildren() or {} do
				if tool:IsA("Tool") and tool:GetAttribute("OfferingLevel") then
					tool:Destroy()
				end
			end
		end
	end
end

local function buildLevel()
	local challenge
	room, roomItem, roomItemName, challenge = Levels.build(level, roomBase)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TakePrompt"
	prompt.ActionText = "Take"
	prompt.ObjectText = roomItemName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = roomItem
	prompt.Triggered:Connect(giveItem)

	room.Parent = workspace
	if challenge and challenge.kind == "library" then
		Library.start(room, challenge)
	end

	offered = false
	offerPrompt.ActionText = "Offer " .. roomItemName
	offerPrompt.Enabled = true
end

-- The lobby spawn pad sits where the floor rooms go, so hide it once we leave.
-- Once the lobby is left behind, anyone who dies comes back inside the elevator
-- rather than at the old lobby spawn, which is now buried inside a floor room.
local function onCharacter(character)
	if level == 0 then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root then
		task.defer(function()
			character:PivotTo(floorPart.CFrame * CFrame.new(0, 3.5, 4))
		end)
	end
end
for _, player in Players:GetPlayers() do
	player.CharacterAdded:Connect(onCharacter)
end
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(onCharacter)
end)

local function hideLobbySpawn()
	local spawn = workspace:FindFirstChild("SpawnLocation")
	if not spawn then
		return
	end
	spawn.Transparency = 1
	spawn.CanCollide = false
	for _, d in spawn:GetChildren() do
		if d:IsA("Decal") then
			d.Transparency = 1
		end
	end
end

local function descend()
	if descending or elevator:GetAttribute("DoorState") == "Moving" then
		return
	end
	descending = true
	offerPrompt.Enabled = false
	setDoors("Closed")

	clearLevel()
	if level == 0 then
		hideLobbySpawn()
	end
	-- Clients shake the camera while this is set.
	elevator:SetAttribute("Descending", true)
	setDial(level + 1, DESCENT_TIME)
	fade(moveSound, MOVE_VOLUME, 1.2)
	fade(music, MUSIC_VOLUME, 2)
	task.wait(DESCENT_TIME)
	elevator:SetAttribute("Descending", false)

	level += 1
	elevator:SetAttribute("Level", level)
	buildLevel()
	fade(moveSound, 0, 1.5)
	fade(music, 0, 3)
	setDoors("Open")
	descending = false
end

local function isAboard(position)
	local localPos = floorPart.CFrame:PointToObjectSpace(position)
	local half = floorPart.Size / 2
	-- Stop short of the doorway so standing between the doors doesn't count.
	return math.abs(localPos.X) < half.X - 1 and localPos.Z > -half.Z and localPos.Z < half.Z - 1.5 and localPos.Y > 0
end

-- True when every living player is inside (and there's at least one).
local function everyoneAboard()
	local anyone = false
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			if not isAboard(root.Position) then
				return false
			end
			anyone = true
		end
	end
	return anyone
end

task.spawn(function()
	local boardedSince
	while true do
		task.wait(0.25)
		local ready = not descending
			and elevator:GetAttribute("DoorState") == "Open"
			and (level == 0 or offered)
			and everyoneAboard()
		if not ready then
			boardedSince = nil
		elseif not boardedSince then
			boardedSince = os.clock()
		elseif os.clock() - boardedSince >= BOARD_DELAY then
			boardedSince = nil
			descend()
		end
	end
end)

-- ================= DEV REMOTE =================
local devRemote = Instance.new("RemoteEvent")
devRemote.Name = "ElevatorDev"
devRemote.Parent = ReplicatedStorage

local function isDev(player)
	return RunService:IsStudio() or player.UserId == game.CreatorId
end

devRemote.OnServerEvent:Connect(function(player, action)
	if not isDev(player) or descending then
		return
	end
	if action == "Close" then
		setDoors("Closed")
	elseif action == "Open" then
		setDoors("Open")
	elseif action == "Descend" then
		descend()
	elseif action == "Librarian" and Library.summon then
		Library.summon()
	end
end)
