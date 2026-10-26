local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local WALK_SPEED = 10.2
local SPRINT_SPEED = 18.5
local CROUCH_SPEED = 5.6
local BASE_FOV = 72

local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

for _, core in ipairs({Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.PlayerList}) do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(core, false)
	end)
end

player.CameraMode = Enum.CameraMode.LockFirstPerson

-- ================= HUD =================
local gui = Instance.new("ScreenGui")
gui.Name = "HotelHUD"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function makeEdge(size, position, rotation)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = position
	f.ZIndex = 1
	f.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Rotation = rotation
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.28),
		NumberSequenceKeypoint.new(0.5, 0.84),
		NumberSequenceKeypoint.new(1, 1),
	})
	grad.Parent = f
end
makeEdge(UDim2.new(1, 0, 0.24, 0), UDim2.fromScale(0, 0), 90)
makeEdge(UDim2.new(1, 0, 0.24, 0), UDim2.fromScale(0, 0.76), 270)
makeEdge(UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0, 0), 0)
makeEdge(UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0.84, 0), 180)

local dot = Instance.new("Frame")
dot.Name = "Crosshair"
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(3, 3)
dot.BackgroundColor3 = Color3.fromRGB(230, 222, 205)
dot.BackgroundTransparency = 0.55
dot.BorderSizePixel = 0
dot.ZIndex = 2
dot.Parent = gui
local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = dot

local staminaBg = Instance.new("Frame")
staminaBg.Name = "Stamina"
staminaBg.AnchorPoint = Vector2.new(0.5, 1)
staminaBg.Position = UDim2.new(0.5, 0, 1, -46)
staminaBg.Size = UDim2.fromOffset(240, 7)
staminaBg.BackgroundColor3 = Color3.fromRGB(8, 10, 12)
staminaBg.BackgroundTransparency = 0.55
staminaBg.BorderSizePixel = 0
staminaBg.ZIndex = 4
staminaBg.Parent = gui
local sbCorner = Instance.new("UICorner")
sbCorner.CornerRadius = UDim.new(0, 4)
sbCorner.Parent = staminaBg
local sbStroke = Instance.new("UIStroke")
sbStroke.Color = Color3.fromRGB(146, 120, 66)
sbStroke.Thickness = 1
sbStroke.Transparency = 0.55
sbStroke.Parent = staminaBg

local staminaFill = Instance.new("Frame")
staminaFill.Name = "Fill"
staminaFill.AnchorPoint = Vector2.new(0, 0.5)
staminaFill.Position = UDim2.new(0, 0, 0.5, 0)
staminaFill.Size = UDim2.fromScale(1, 1)
staminaFill.BackgroundColor3 = Color3.fromRGB(224, 214, 192)
staminaFill.BackgroundTransparency = 0.12
staminaFill.BorderSizePixel = 0
staminaFill.ZIndex = 5
staminaFill.Parent = staminaBg
local sfCorner = Instance.new("UICorner")
sfCorner.CornerRadius = UDim.new(0, 3)
sfCorner.Parent = staminaFill

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -78)
hint.Size = UDim2.new(0.9, 0, 0, 20)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamMedium
hint.TextSize = 13
hint.TextColor3 = Color3.fromRGB(218, 205, 180)
hint.TextTransparency = 0.25
hint.Text = "WASD  MOVE        SHIFT  RUN        CTRL  CROUCH        E  INTERACT"
hint.ZIndex = 4
hint.Parent = gui
task.delay(8, function()
	TweenService:Create(hint, TweenInfo.new(2), { TextTransparency = 1 }):Play()
end)

-- ================= PROMPT UI =================
local promptGroup = Instance.new("CanvasGroup")
promptGroup.Name = "Prompt"
promptGroup.AnchorPoint = Vector2.new(0.5, 1)
promptGroup.Position = UDim2.new(0.5, 0, 1, -122)
promptGroup.Size = UDim2.fromOffset(256, 50)
promptGroup.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
promptGroup.BackgroundTransparency = 0.28
promptGroup.BorderSizePixel = 0
promptGroup.GroupTransparency = 1
promptGroup.Visible = false
promptGroup.ZIndex = 9
promptGroup.Parent = gui

local pgCorner = Instance.new("UICorner")
pgCorner.CornerRadius = UDim.new(0, 5)
pgCorner.Parent = promptGroup
local pgStroke = Instance.new("UIStroke")
pgStroke.Color = Color3.fromRGB(148, 120, 64)
pgStroke.Thickness = 1
pgStroke.Transparency = 0.4
pgStroke.Parent = promptGroup

local badge = Instance.new("Frame")
badge.Position = UDim2.fromOffset(10, 10)
badge.Size = UDim2.fromOffset(30, 30)
badge.BackgroundColor3 = Color3.fromRGB(24, 22, 18)
badge.BackgroundTransparency = 0.15
badge.BorderSizePixel = 0
badge.ZIndex = 10
badge.Parent = promptGroup
local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0, 4)
badgeCorner.Parent = badge
local badgeStroke = Instance.new("UIStroke")
badgeStroke.Color = Color3.fromRGB(160, 132, 74)
badgeStroke.Thickness = 1
badgeStroke.Transparency = 0.35
badgeStroke.Parent = badge
local keyLabel = Instance.new("TextLabel")
keyLabel.Size = UDim2.fromScale(1, 1)
keyLabel.BackgroundTransparency = 1
keyLabel.Font = Enum.Font.GothamBold
keyLabel.TextSize = 14
keyLabel.TextColor3 = Color3.fromRGB(222, 202, 160)
keyLabel.Text = "E"
keyLabel.ZIndex = 11
keyLabel.Parent = badge

local actionLabel = Instance.new("TextLabel")
actionLabel.Position = UDim2.fromOffset(52, 8)
actionLabel.Size = UDim2.fromOffset(192, 18)
actionLabel.BackgroundTransparency = 1
actionLabel.Font = Enum.Font.GothamBold
actionLabel.TextSize = 12
actionLabel.TextColor3 = Color3.fromRGB(214, 198, 166)
actionLabel.TextXAlignment = Enum.TextXAlignment.Left
actionLabel.Text = ""
actionLabel.ZIndex = 10
actionLabel.Parent = promptGroup

local objectLabel = Instance.new("TextLabel")
objectLabel.Position = UDim2.fromOffset(52, 25)
objectLabel.Size = UDim2.fromOffset(192, 18)
objectLabel.BackgroundTransparency = 1
objectLabel.Font = Enum.Font.Garamond
objectLabel.TextSize = 14
objectLabel.TextColor3 = Color3.fromRGB(168, 158, 138)
objectLabel.TextXAlignment = Enum.TextXAlignment.Left
objectLabel.Text = ""
objectLabel.ZIndex = 10
objectLabel.Parent = promptGroup

local currentPrompt
local promptTween

local function updatePromptText()
	if not currentPrompt then
		return
	end
	local action = string.upper(currentPrompt.ActionText)
	if actionLabel.Text ~= action then
		actionLabel.Text = action
	end
	if objectLabel.Text ~= currentPrompt.ObjectText then
		objectLabel.Text = currentPrompt.ObjectText
	end
end

local function showPrompt(prompt)
	currentPrompt = prompt
	updatePromptText()
	promptGroup.Visible = true
	if promptTween then
		promptTween:Cancel()
	end
	promptTween = TweenService:Create(promptGroup, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 })
	promptTween:Play()
end

local function hidePrompt(prompt)
	if prompt and currentPrompt ~= prompt then
		return
	end
	currentPrompt = nil
	if promptTween then
		promptTween:Cancel()
	end
	promptTween = TweenService:Create(promptGroup, TweenInfo.new(0.14), { GroupTransparency = 1 })
	promptTween.Completed:Connect(function()
		if promptGroup.GroupTransparency >= 0.99 then
			promptGroup.Visible = false
		end
	end)
	promptTween:Play()
end

ProximityPromptService.PromptShown:Connect(function(prompt)
	if touch then
		return
	end
	showPrompt(prompt)
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	if touch then
		return
	end
	hidePrompt(prompt)
end)

if not touch then
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			d.Style = Enum.ProximityPromptStyle.Custom
		end
	end
end

-- ================= FOOTSTEPS =================
local footstepId = "rbxasset://sounds/action_footsteps_plastic.mp3"
local footsteps = {}
for i = 1, 3 do
	local s = Instance.new("Sound")
	s.Name = "HotelFootstep" .. i
	s.SoundId = footstepId
	s.Volume = 0.18
	s.PlaybackSpeed = 0.8
	s.Parent = SoundService
	footsteps[i] = s
end

local function silenceCharacterSounds(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local running = root:FindFirstChild("Running")
	if running and running:IsA("Sound") and running.SoundId ~= "" then
		for _, s in ipairs(footsteps) do
			s.SoundId = running.SoundId
		end
	end
	for _, d in ipairs(root:GetChildren()) do
		if d:IsA("Sound") then
			d.Volume = 0
		end
	end
	task.delay(1.5, function()
		if not root.Parent then
			return
		end
		for _, d in ipairs(root:GetChildren()) do
			if d:IsA("Sound") then
				d.Volume = 0
			end
		end
	end)
end

-- ================= MOVEMENT =================
local character
local humanoid
local stamina = 100
local staminaDelay = 0
local exhausted = false
local sprintHeld = false
local crouchHeld = false
local bobPhase = 0
local crouchOffset = 0
local stepTimer = 0
local stepIndex = 1
local roll = 0
local fov = BASE_FOV
local sprinting = false
local moving = false

local function onCharacterAdded(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	humanoid.UseJumpPower = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.WalkSpeed = WALK_SPEED
	humanoid.CameraOffset = Vector3.new(0, 0, 0)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	stamina = 100
	staminaDelay = 0
	exhausted = false
	crouchOffset = 0
	bobPhase = 0
	stepTimer = 0
	roll = 0
	fov = BASE_FOV
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	camera.FieldOfView = BASE_FOV
	silenceCharacterSounds(char)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then
		sprintHeld = true
	elseif key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl or key == Enum.KeyCode.C then
		crouchHeld = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	local key = input.KeyCode
	if key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then
		sprintHeld = false
	elseif key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl or key == Enum.KeyCode.C then
		crouchHeld = false
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	moving = humanoid.MoveDirection.Magnitude > 0.1
	sprinting = sprintHeld and moving and not crouchHeld and not exhausted and stamina > 0.5

	local targetSpeed = crouchHeld and CROUCH_SPEED or (sprinting and SPRINT_SPEED or WALK_SPEED)
	humanoid.WalkSpeed += (targetSpeed - humanoid.WalkSpeed) * math.min(dt * 8, 1)

	if sprinting then
		stamina = math.max(0, stamina - dt * 13.5)
		staminaDelay = 0.7
	else
		staminaDelay = math.max(0, staminaDelay - dt)
		if staminaDelay <= 0 then
			stamina = math.min(100, stamina + dt * 10)
		end
	end
	if stamina <= 0 then
		exhausted = true
	end
	if exhausted and stamina > 25 then
		exhausted = false
	end

	local speedFactor = moving and (sprinting and 1.5 or (crouchHeld and 0.55 or 1)) or 0
	bobPhase += dt * (sprinting and 12.5 or 9) * (moving and 1 or 0)
	local bobY = math.sin(bobPhase * 2) * 0.055 * speedFactor
	local bobX = math.cos(bobPhase) * 0.045 * speedFactor
	local breath = math.sin(os.clock() * 1.25) * 0.009
	local targetCrouch = crouchHeld and -1.55 or 0
	crouchOffset += (targetCrouch - crouchOffset) * math.min(dt * 8, 1)
	humanoid.CameraOffset = Vector3.new(bobX, bobY + breath + crouchOffset, 0)

	local targetFov = BASE_FOV + (sprinting and 7 or 0) + (crouchHeld and -3 or 0) + (exhausted and 1.5 or 0)
	fov += (targetFov - fov) * math.min(dt * 6, 1)
	camera.FieldOfView = fov

	if moving then
		local interval = sprinting and 0.31 or (crouchHeld and 0.68 or 0.47)
		stepTimer += dt
		if stepTimer >= interval then
			stepTimer = 0
			local s = footsteps[stepIndex]
			stepIndex = (stepIndex % #footsteps) + 1
			s.TimePosition = 0
			s.PlaybackSpeed = (sprinting and 0.96 or (crouchHeld and 0.62 or 0.78)) + math.random() * 0.05
			s.Volume = sprinting and 0.24 or (crouchHeld and 0.09 or 0.16)
			s:Play()
		end
	else
		stepTimer = 0
	end

	local frac = stamina / 100
	staminaFill.Size = UDim2.new(frac, 0, 1, 0)
	staminaFill.BackgroundColor3 = exhausted and Color3.fromRGB(160, 58, 48) or Color3.fromRGB(224, 214, 192)
	local fade = (stamina > 99 and not sprintHeld and staminaDelay <= 0) and 1 or 0
	local current = 1 - staminaBg.BackgroundTransparency
	current += (fade - current) * math.min(dt * 4, 1)
	staminaBg.BackgroundTransparency = 0.55 + 0.42 * current
	staminaFill.BackgroundTransparency = 0.12 + 0.7 * current
	sbStroke.Transparency = 0.55 + 0.45 * current
	dot.BackgroundTransparency = 0.55 + 0.35 * current

	if currentPrompt then
		updatePromptText()
	end
end)

RunService:BindToRenderStep("HotelCameraFX", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local lateral = humanoid.MoveDirection:Dot(camera.CFrame.RightVector)
	local targetRoll = -lateral * (sprinting and 2.0 or (crouchHeld and 0.7 or 1.1))
	roll += (targetRoll - roll) * math.min(dt * 6, 1)
	local shake = 0
	if sprinting then
		shake = math.noise(os.clock() * 14, 0) * 0.1
	end
	camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(shake), 0, math.rad(roll))
end)
