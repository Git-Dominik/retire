-- The floor selector by the elevator door. Elevator.server keeps its state, including
-- whether it's up (Raised) and who it faces (FacingUserId), so every player sees the
-- same thing. This script only animates it: when it's raised, the hatch leaves swing
-- open, the pedestal rises and settles, and the folded dial head flips up to face
-- that player and keeps turning to follow them. Lowered, it all sinks again.
-- The motion runs on each client, at its own frame rate. The model is built in its
-- raised pose; every moving group is posed from its pivot part each frame.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local RISE_TIME = 1.3
local SINK_TIME = 1
-- How far down the pedestal hides: its folded top ends up under the floor.
local SINK_DEPTH = 6
local LEAF_OPEN = math.rad(105)
-- The head starts folded face-up and tilts down to its built angle.
local HEAD_FOLD = math.rad(72)
local MAX_YAW = math.rad(50)
local LEVER_PULL = math.rad(60)

local DIAL_FIRST_ANGLE = -120
local DIAL_STEP = 30

local SOUNDS = {
	Mechanism = { "rbxassetid://9118203061", 0.35 }, -- "Robot Fingers 2", winding gear clicks (Pro Sound Effects)
	Hatch = { "rbxassetid://7309104360", 0.3 }, -- metal hatch squeak
	Click = { "rbxassetid://9119730203", 0.4 }, -- "Switch Portable Plastic Radio Tape Player 6" (Pro Sound Effects)
	Bell = { "rbxassetid://9125485659", 0.35 }, -- the service bell's ring, pitched down
}

local LAMP_IDLE = Color3.fromRGB(255, 170, 80)
local LAMP_SENT = Color3.fromRGB(120, 230, 100)

local elevator = workspace:WaitForChild("Elevator")
local selector = elevator:WaitForChild("FloorSelector")
local hatch = selector:WaitForChild("Hatch")
local pedestal = selector:WaitForChild("Pedestal")
local head = pedestal:WaitForChild("Head")
local pointer = head:WaitForChild("Pointer")
local lever = pedestal:WaitForChild("Lever")
local rootCFrame = selector:WaitForChild("Root").CFrame
local lamp = head:WaitForChild("Lamp")
local glow = lamp:WaitForChild("Glow")
local dial = head:WaitForChild("FaceGui"):WaitForChild("Dial")
local prompts = {
	pointer:WaitForChild("Knob"):WaitForChild("ProximityPrompt"),
	lever:WaitForChild("Grip"):WaitForChild("ProximityPrompt"),
}

local function ease(t, style, direction)
	return TweenService:GetValue(math.clamp(t, 0, 1), style, direction)
end

-- Eases to 1 by `impact`, then dips back by `bounce` once before settling.
local function landing(t, impact, bounce)
	t = math.clamp(t, 0, 1)
	if t < impact then
		return ease(t / impact, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end
	local u = (t - impact) / (1 - impact)
	return 1 - bounce * math.sin(math.pi * u) * (1 - u)
end

local function makeSound(name, parent)
	local def = SOUNDS[name]
	local s = Instance.new("Sound")
	s.Name = "Selector" .. name
	s.SoundId = def[1]
	s.Volume = def[2]
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = 45
	s.Parent = parent
	return s
end

local sounds = {
	Mechanism = makeSound("Mechanism", selector.Root),
	Hatch = makeSound("Hatch", selector.Root),
	Click = makeSound("Click", pointer.Knob),
	Bell = makeSound("Bell", lamp),
}
sounds.Bell.PlaybackSpeed = 0.85

-- ================= GROUPS =================
-- Each group remembers its parts relative to its pivot, and its pivot relative to its
-- parent group's, as built. Posing it is then parent pose * rest offset * motion.
local function makeGroup(pivotCFrame, parent)
	local group = {
		pivot = pivotCFrame,
		parent = parent,
		motion = CFrame.identity,
		parts = {},
		offsets = {},
		cframes = {},
	}
	group.rest = parent and parent.pivot:Inverse() * pivotCFrame or pivotCFrame
	return group
end

local base = makeGroup(rootCFrame, nil)
local groups = {}
local groupOf = {}
local function addGroup(model, pivotName, parent)
	local group = makeGroup(model:WaitForChild(pivotName).CFrame, parent)
	groupOf[model] = group
	table.insert(groups, group)
	return group
end

-- Parents before children, so each pose is computed after its parent's.
local pedestalGroup = makeGroup(rootCFrame, base)
groupOf[pedestal] = pedestalGroup
table.insert(groups, pedestalGroup)
local headGroup = addGroup(head, "HeadPivot", pedestalGroup)
local pointerGroup = addGroup(pointer, "PointerPivot", headGroup)
local leverGroup = addGroup(lever, "LeverPivot", pedestalGroup)
local leafGroups = {
	L = addGroup(hatch:WaitForChild("LeafL"), "Hinge", base),
	R = addGroup(hatch:WaitForChild("LeafR"), "Hinge", base),
}

-- Each part belongs to the nearest group model above it.
for _, p in selector:GetDescendants() do
	if not p:IsA("BasePart") then
		continue
	end
	local model = p.Parent
	while model ~= selector and not groupOf[model] do
		model = model.Parent
	end
	local group = groupOf[model]
	if group then
		table.insert(group.parts, p)
		table.insert(group.offsets, group.pivot:Inverse() * p.CFrame)
	end
end

base.current = rootCFrame

local function pose()
	local parts, cframes = {}, {}
	for _, group in groups do
		group.current = group.parent.current * group.rest * group.motion
		for i, p in group.parts do
			table.insert(parts, p)
			table.insert(cframes, group.current * group.offsets[i])
		end
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- ================= DIAL =================
local function dialAngle(floor)
	return math.rad(DIAL_FIRST_ANGLE + DIAL_STEP * floor)
end

local pointerAngle = dialAngle(selector:GetAttribute("Selected") or 1)
local pointerSpeed = 0

selector:GetAttributeChangedSignal("Selected"):Connect(function()
	sounds.Click:Play()
end)

-- The floor the elevator is on is printed faded, since the dial skips it.
local function markCurrentFloor()
	local level = elevator:GetAttribute("Level") or 0
	for floor = 0, 8 do
		local label = dial:FindFirstChild("Floor" .. floor)
		if label then
			label.TextTransparency = floor == level and 0.7 or 0
		end
	end
end
elevator:GetAttributeChangedSignal("Level"):Connect(markCurrentFloor)
markCurrentFloor()

-- Q turns the pointer back while the knob's prompt (E, the other way) is showing;
-- the prompt's AltKey attribute puts a Q badge beside its E.
local turnRemote = ReplicatedStorage:WaitForChild("SelectorTurn")
local knobShown = false
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt == prompts[1] then
		knobShown = true
	end
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	if prompt == prompts[1] then
		knobShown = false
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and knobShown and input.KeyCode == Enum.KeyCode.Q then
		turnRemote:FireServer()
	end
end)

-- ================= LEVER =================
local pulledAt
selector:GetAttributeChangedSignal("SendSeq"):Connect(function()
	pulledAt = os.clock()
	sounds.Click:Play()
	task.delay(0.15, function()
		sounds.Bell:Play()
	end)
end)

-- Snaps down, holds a moment, and springs back with one small rebound.
local function leverPull()
	if not pulledAt then
		return 0
	end
	local t = os.clock() - pulledAt
	if t < 0.15 then
		return ease(t / 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	elseif t < 0.45 then
		return 1
	elseif t < 0.95 then
		return 1 - landing((t - 0.45) / 0.5, 0.6, 0.12)
	end
	pulledAt = nil
	return 0
end

-- ================= LOOP =================
-- Where the player the server has it facing is, relative to the hatch.
local function facingOffset()
	local facing = Players:GetPlayerByUserId(selector:GetAttribute("FacingUserId") or 0)
	local character = facing and facing.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and rootCFrame:PointToObjectSpace(root.Position)
end

local progress = 0
local raised = false
local yaw = 0
local promptsOn
local posedHidden = false
local lampPulse = 0

RunService.RenderStepped:Connect(function(dt)
	local up = selector:GetAttribute("Raised") == true
	if up ~= raised then
		raised = up
		if raised then
			sounds.Hatch:Play()
		else
			sounds.Mechanism.PlaybackSpeed = 0.8
			sounds.Mechanism:Play()
		end
	end

	local before = progress
	progress = math.clamp(progress + (raised and dt / RISE_TIME or -dt / SINK_TIME), 0, 1)
	if raised and before < 0.12 and progress >= 0.12 then
		sounds.Mechanism.PlaybackSpeed = 1
		sounds.Mechanism:Play()
	elseif not raised and before > 0.2 and progress <= 0.2 then
		sounds.Hatch:Play()
	end

	-- Starts swinging round to the player as it comes up through the hatch; behind it,
	-- it just turns as far as it can.
	local targetYaw = 0
	local offset = facingOffset()
	if progress > 0.2 and offset and Vector2.new(offset.X, offset.Z).Magnitude > 1.5 then
		targetYaw = math.clamp(math.atan2(-offset.X, -offset.Z), -MAX_YAW, MAX_YAW)
	end
	yaw += (targetYaw - yaw) * math.min(dt * 3, 1)

	local targetAngle = dialAngle(selector:GetAttribute("Selected") or 1)
	pointerSpeed += ((targetAngle - pointerAngle) * 260 - pointerSpeed * 22) * dt
	pointerAngle += pointerSpeed * dt

	local open = ease(progress / 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local height = landing((progress - 0.1) / 0.65, 0.8, 0.05)
	-- The head lifts its face toward the player gradually all the way up, not at the end.
	local unfold = ease((progress - 0.15) / 0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	pedestalGroup.motion = CFrame.new(0, -SINK_DEPTH * (1 - height), 0) * CFrame.Angles(0, yaw, 0)
	headGroup.motion = CFrame.Angles(HEAD_FOLD * (1 - unfold), 0, 0)
	pointerGroup.motion = CFrame.Angles(0, 0, pointerAngle)
	leverGroup.motion = CFrame.Angles(-LEVER_PULL * leverPull(), 0, 0)
	leafGroups.L.motion = CFrame.Angles(0, 0, -LEAF_OPEN * (1 - open))
	leafGroups.R.motion = CFrame.Angles(0, 0, LEAF_OPEN * (1 - open))
	-- Nothing to move while it sits shut underground.
	if progress > 0 or before > 0 or not posedHidden then
		posedHidden = progress == 0
		pose()
	end

	-- Controls only work once it's fully up, and not mid-ride.
	local enable = progress >= 0.97 and not selector:GetAttribute("Busy")
	if enable ~= promptsOn then
		promptsOn = enable
		for _, prompt in prompts do
			prompt.Enabled = enable
		end
	end

	-- Lamp: warm when idle, green once sent, a slow amber throb while riding.
	local color, brightness = LAMP_IDLE, 0.6
	if selector:GetAttribute("Busy") then
		lampPulse += dt
		brightness = 0.4 + 0.5 * (0.5 + 0.5 * math.sin(lampPulse * 4))
	elseif selector:GetAttribute("Sent") then
		color, brightness = LAMP_SENT, 0.9
	end
	lamp.Color = color
	glow.Color = color
	glow.Brightness = brightness
end)
