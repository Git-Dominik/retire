-- Elevator ambience, the door open/close sequence, and the floor-by-floor descent.
-- Doors move on the server so every player sees and hears the same thing.
--
-- Loop: someone picks a floor on the floor selector and sends it -> everyone boards ->
-- doors shut -> the room outside is swapped during a short "ride" -> doors open on the
-- chosen floor. "STORE" on the selector brings the elevator back up to the lobby.
-- Scavenged items go home through the cargo lift (Cargo.server).
-- Every item on a floor carries the ScavengeItem tag.
-- During a ride the Elevator model carries RideDir (1 going down, -1 going up, 0 when
-- still), RideStart (server time) and RideTime; ElevatorShaft.client runs the shaft
-- wall past the doorway from those.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Levels = require(script.Parent.Levels)
local Noise = require(script.Parent.Noise)

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
-- How long a one-floor ride lasts once the doors are shut; each extra floor adds a
-- little, up to a cap, so a long trip doesn't drag.
local DESCENT_TIME = 20
local PER_FLOOR_TIME = 3
local MAX_RIDE_TIME = 32
-- Everyone has to stay aboard this long before the doors close.
local BOARD_DELAY = 2

local MUSIC_VOLUME = 0.2
local MOVE_VOLUME = 0.225

local elevator = workspace:WaitForChild("Elevator")
local doorsFolder = elevator:WaitForChild("Doors")
local floorPart = elevator.PrimaryPart
local selector = elevator:WaitForChild("FloorSelector")

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

-- The lobby starts with the doors shut; the call button outside opens them.
for _, entry in doorParts do
	for property, value in entry.closed do
		entry.part[property] = value
	end
end
elevator:SetAttribute("DoorState", "Closed")

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
local descending = false
local room

elevator:SetAttribute("Level", level)

-- Floor-level CFrame at the elevator's outer door face, looking out of the elevator.
local roomBase = floorPart.CFrame * CFrame.new(0, floorPart.Size.Y / 2, floorPart.Size.Z / 2)

-- ================= FLOOR SELECTOR =================
-- A telegraph-style pedestal that rises out of the floor when someone comes near
-- (FloorSelector.client does all the moving). The knob turns the pointer through
-- STORE (0) and floors 1..DIAL_TICKS; pulling the lever sends the elevator there
-- once everyone is aboard. The server only keeps the choice, in attributes:
--   Selected  floor the pointer is on
--   Sent      the lever has been pulled for Selected
--   SendSeq   bumped on every pull, so clients animate the lever and ring the bell
--   Busy      riding, so the controls are locked
--   Locked    on a floor nothing has been sent up from yet; it stays buried until
--             the cargo lift has made a trip (or has no trips left to make)
--   Raised    it's up, decided here so every player sees the same thing
--   FacingUserId  the player its head turns to follow (0 for none)
local selectorHead = selector.Pedestal.Head
local cargoLift = elevator:WaitForChild("CargoLift")

local function makeSelectorPrompt(parent, action, hold)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = "Floor selector"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 6
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("IgnoreSight", true) -- the pedestal's own parts would block sight
	prompt.Parent = parent
	return prompt
end

local turnPrompt = makeSelectorPrompt(selectorHead.Pointer.Knob, "Turn dial", 0)
local sendPrompt = makeSelectorPrompt(selector.Pedestal.Lever.Grip, "Send", 0.5)

local function setSelected(floor)
	selector:SetAttribute("Selected", floor)
	selector:SetAttribute("Sent", false)
	sendPrompt.ActionText = floor == 0 and "Return to store" or `Go to floor {floor}`
end

-- The pointer rests on the floor below the current one (see travel()).
setSelected(1)
selector:SetAttribute("Busy", false)
selector:SetAttribute("SendSeq", 0)
selector:SetAttribute("Locked", false)

local function unlockSelector()
	selector:SetAttribute("Locked", false)
end
cargoLift:GetAttributeChangedSignal("SendSeq"):Connect(unlockSelector)

-- A run with no cargo trips left can't unlock it, so it isn't locked at all then.
local function lockSelector()
	selector:SetAttribute("Locked", (elevator:GetAttribute("CargoTripsLeft") or 1) > 0)
end

-- E on the knob turns the pointer right (deeper); Q, sent by FloorSelector.client
-- through SelectorTurn since a prompt has one key, turns it left (back up). It stops
-- at either end of the dial and steps over the floor the elevator is already on.
-- One detent at a time: a turn is ignored until the last one's click (0.42s) has
-- finished, so mashing Q/E can't stack the sounds.
local TURN_COOLDOWN = 0.45
local lastTurn = 0

local function turnDial(step)
	if descending or not selector:GetAttribute("Raised") or selector:GetAttribute("Sent") then
		return
	end
	if os.clock() - lastTurn < TURN_COOLDOWN then
		return
	end
	local floor = selector:GetAttribute("Selected") + step
	if floor == level then
		floor += step
	end
	if floor >= 0 and floor <= DIAL_TICKS then
		lastTurn = os.clock()
		setSelected(floor)
	end
end

turnPrompt:SetAttribute("AltKey", "Q")
-- The dial's own detent click is the feedback; the generic interact click on top of
-- it would still stack when the keys are mashed.
turnPrompt:SetAttribute("SkipInteractSound", true)
turnPrompt.Triggered:Connect(function()
	turnDial(1)
end)

local turnRemote = Instance.new("RemoteEvent")
turnRemote.Name = "SelectorTurn"
turnRemote.Parent = ReplicatedStorage
turnRemote.OnServerEvent:Connect(function(player)
	-- Same reach as the prompt, so Q only works where E would.
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local knob = selectorHead.Pointer.Knob
	if root and (root.Position - knob.Position).Magnitude <= turnPrompt.MaxActivationDistance + 2 then
		turnDial(-1)
	end
end)

local sentAt = 0
sendPrompt.Triggered:Connect(function()
	if descending or not selector:GetAttribute("Raised") or selector:GetAttribute("Selected") == level then
		return
	end
	sentAt = os.clock()
	selector:SetAttribute("Sent", true)
	selector:SetAttribute("SendSeq", selector:GetAttribute("SendSeq") + 1)
end)

-- ================= CALL BUTTON =================
-- The call panel beside the lobby doors: the status light goes amber while the car
-- "arrives", then the doors open. Only the lobby has one.
local CALL_DELAY = 2.5
local CALL_WAITING = Color3.fromRGB(255, 170, 60)
local CALL_ARRIVED = Color3.fromRGB(110, 225, 95)

local lobby = workspace:FindFirstChild("Grocery Store")
local callPanel = lobby and lobby:FindFirstChild("Call Panel", true)
if callPanel then
	local statusLight = callPanel:FindFirstChild("Status Light")
	local callPrompt = callPanel["Call Plate"]:FindFirstChildWhichIsA("ProximityPrompt")
	callPrompt.ActionText = "Call"
	callPrompt.ObjectText = "Elevator"
	callPrompt.KeyboardKeyCode = Enum.KeyCode.E
	callPrompt.RequiresLineOfSight = false
	callPrompt:SetAttribute("IgnoreSight", true) -- the button ring sits in front of the plate

	-- A short metal click from the button itself, every time it's pressed.
	local pressSound = makeSound(callPanel["Call Plate"], "ButtonPress", "rbxassetid://9120097918", {
		Volume = 1.6,
		RollOffMinDistance = 12,
		RollOffMaxDistance = 50,
	})

	local calling = false
	callPrompt.Triggered:Connect(function()
		pressSound:Play()
		if calling or descending or level ~= 0 or elevator:GetAttribute("DoorState") ~= "Closed" then
			return
		end
		calling = true
		callPrompt.Enabled = false
		if statusLight then
			statusLight.Color = CALL_WAITING
		end
		task.wait(CALL_DELAY)
		setDoors("Open")
		if statusLight then
			statusLight.Color = CALL_ARRIVED
		end
		callPrompt.Enabled = true
		calling = false
	end)
end

local function giveItem(player, item, itemName)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not item.TakePrompt.Enabled then
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = itemName
	tool.CanBeDropped = false
	tool:SetAttribute("ScavengedLevel", level)
	-- The item part carries the rest of its model as welded children (see Levels).
	local handle = item:Clone()
	handle.Name = "Handle"
	handle.TakePrompt:Destroy()
	CollectionService:RemoveTag(handle, "ScavengeItem")
	handle.Anchored = false
	handle.Massless = true
	handle.Parent = tool

	-- The original stays in the room, hidden, and comes back if the carrier dies or leaves.
	-- Loading it into the cargo lift marks the tool Stored, so it stays gone. Dropping
	-- it (StockingService sets DropAt) brings it back where it was dropped instead.
	local prompt = item.TakePrompt
	local function setShown(shown)
		local parts = item:GetDescendants()
		table.insert(parts, item)
		for _, p in parts do
			if p:IsA("BasePart") then
				p.Transparency = shown and (p:GetAttribute("ShownTransparency") or 0) or 1
			end
		end
	end
	setShown(false)
	prompt.Enabled = false
	tool.Destroying:Connect(function()
		if not tool:GetAttribute("Stored") and item.Parent then
			local dropAt = tool:GetAttribute("DropAt")
			if dropAt then
				-- Floor items carry a RestOffset from their bottom centre (see Levels).
				item.CFrame = dropAt * (item:GetAttribute("RestOffset") or CFrame.identity)
			end
			setShown(true)
			prompt.Enabled = true
		end
	end)

	tool.Parent = player.Backpack
	humanoid:EquipTool(tool)
	Noise.pickup(player)
end

local function clearLevel()
	if room then
		room:Destroy()
		room = nil
	end
	-- Anything still carried from the floor being left behind is gone; only what's
	-- loaded into the cargo lift (Cargo.server) makes it back to the store.
	for _, player in Players:GetPlayers() do
		for _, container in { player.Character, player:FindFirstChild("Backpack") } do
			for _, tool in container and container:GetChildren() or {} do
				if tool:IsA("Tool") and tool:GetAttribute("ScavengedLevel") then
					tool:Destroy()
				end
			end
		end
	end
end

local function makeTakeable(item, itemName)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TakePrompt"
	prompt.ActionText = "Take"
	prompt.ObjectText = itemName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = item
	prompt.Triggered:Connect(function(player)
		giveItem(player, item, itemName)
	end)
	-- Journal.client points its world arrow at tagged items.
	CollectionService:AddTag(item, "ScavengeItem")
end

local function buildLevel()
	local items
	room, items = Levels.build(level, roomBase)
	for _, item in items do
		makeTakeable(item, item.Name)
	end

	room.Parent = workspace
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

-- The grocery store is the lobby and sits right where the floor rooms are built,
-- so it's put away (not destroyed) while the elevator is down, and the lobby spawn
-- pad is hidden with it. Coming back up to the store reverses both.
local function setLobbyShown(shown)
	local store = shown and ServerStorage:FindFirstChild("Grocery Store") or workspace:FindFirstChild("Grocery Store")
	if store then
		store.Parent = shown and workspace or ServerStorage
	end

	local spawn = workspace:FindFirstChild("SpawnLocation")
	if not spawn then
		return
	end
	-- Remember how it looked so it can be put back exactly.
	if spawn:GetAttribute("ShownTransparency") == nil then
		spawn:SetAttribute("ShownTransparency", spawn.Transparency)
	end
	spawn.Transparency = shown and spawn:GetAttribute("ShownTransparency") or 1
	spawn.CanCollide = shown
	for _, d in spawn:GetChildren() do
		if d:IsA("Decal") then
			d.Transparency = shown and 0 or 1
		end
	end
end

local function travel(target)
	if descending or target == level or elevator:GetAttribute("DoorState") == "Moving" then
		return
	end
	descending = true
	selector:SetAttribute("Busy", true)
	setDoors("Closed")

	clearLevel()
	if level == 0 then
		setLobbyShown(false)
	end
	local rideTime = math.min(DESCENT_TIME + PER_FLOOR_TIME * (math.abs(target - level) - 1), MAX_RIDE_TIME)
	-- Clients shake the camera while this is set.
	elevator:SetAttribute("Descending", true)
	elevator:SetAttribute("RideTime", rideTime)
	elevator:SetAttribute("RideStart", workspace:GetServerTimeNow())
	elevator:SetAttribute("RideDir", target > level and 1 or -1)
	setDial(target, rideTime)
	fade(moveSound, MOVE_VOLUME, 1.2)
	fade(music, MUSIC_VOLUME, 2)
	task.wait(rideTime)
	elevator:SetAttribute("RideDir", 0)
	elevator:SetAttribute("Descending", false)

	level = target
	elevator:SetAttribute("Level", level)
	if level == 0 then
		setLobbyShown(true)
		unlockSelector()
	else
		buildLevel()
		lockSelector()
	end
	setSelected(level < DIAL_TICKS and level + 1 or 0)
	fade(moveSound, 0, 1.5)
	fade(music, 0, 3)
	setDoors("Open")
	selector:SetAttribute("Busy", false)
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
			and selector:GetAttribute("Sent")
			and everyoneAboard()
		if not ready then
			boardedSince = nil
		elseif not boardedSince then
			boardedSince = os.clock()
		elseif os.clock() - boardedSince >= BOARD_DELAY then
			boardedSince = nil
			travel(selector:GetAttribute("Selected"))
		end
	end
end)

-- The floor selector comes up while anyone aboard is within RAISE_RANGE of its
-- hatch, and goes down once nobody is within LOWER_RANGE. It also stays down on a
-- floor until the cargo lift has gone up (Locked), and from a little after a send
-- (time for the lever throw) until the ride is over. Its head follows the nearest
-- player in range. Clients animate all of it from Raised and FacingUserId.
local SELECTOR_RAISE_RANGE = 4.5
local SELECTOR_LOWER_RANGE = 5.5
local SELECTOR_SEND_SINK_DELAY = 1

selector:SetAttribute("Raised", false)
selector:SetAttribute("FacingUserId", 0)
task.spawn(function()
	local selectorRoot = selector.Root.CFrame
	while true do
		task.wait(0.1)
		local range = selector:GetAttribute("Raised") and SELECTOR_LOWER_RANGE or SELECTOR_RAISE_RANGE
		local nearest, nearestDistance
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid and root and humanoid.Health > 0 and isAboard(root.Position) then
				local offset = selectorRoot:PointToObjectSpace(root.Position)
				local distance = Vector2.new(offset.X, offset.Z).Magnitude
				if distance < range and (not nearestDistance or distance < nearestDistance) then
					nearest, nearestDistance = player, distance
				end
			end
		end
		local done = selector:GetAttribute("Busy")
			or (selector:GetAttribute("Sent") and os.clock() - sentAt > SELECTOR_SEND_SINK_DELAY)
		local up = nearest ~= nil and not selector:GetAttribute("Locked") and not done
		selector:SetAttribute("Raised", up)
		selector:SetAttribute("FacingUserId", up and nearest.UserId or 0)
	end
end)

-- ================= DEV REMOTE =================
local devRemote = Instance.new("RemoteEvent")
devRemote.Name = "ElevatorDev"
devRemote.Parent = ReplicatedStorage

devRemote.OnServerEvent:Connect(function(player, action, itemId)
	-- Spawns a takeable copy of a stock item at the player's feet. It joins the floor
	-- room so it's cleared with it; in the lobby it stays until the server restarts.
	if action == "SpawnItem" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or typeof(itemId) ~= "string" then
			return
		end
		local feet = root.CFrame * CFrame.new(0, -(root.Size.Y / 2 + humanoid.HipHeight), -2)
		local item = Levels.placeItem(room or workspace, itemId, feet)
		if item then
			makeTakeable(item, item.Name)
		end
		return
	end
	if descending then
		return
	end
	if action == "Close" then
		setDoors("Closed")
	elseif action == "Open" then
		setDoors("Open")
	elseif action == "Descend" then
		travel(level + 1)
	end
end)
