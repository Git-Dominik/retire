local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local WALK_SPEED = 10.2
local SPRINT_SPEED = 18.5
local CROUCH_SPEED = 5.6
local BASE_FOV = 72
-- How fast the view catches up to the mouse. Lower trails further behind;
-- around 30+ feels close to the raw default camera.
local LOOK_SMOOTHING = 20
-- Furthest the view may trail the mouse, in degrees, so fast spins stay tight.
local MAX_LOOK_LAG = 12
-- Degrees of roll per degree the view trails the mouse; turning left leans right.
local TURN_LEAN = 0.12
-- Studs the camera pushes forward while sprinting, easing back after you stop.
local SPRINT_FORWARD = 0.6

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
sbStroke.Color = Color3.fromRGB(255, 255, 255)
sbStroke.Thickness = 1
sbStroke.Transparency = 0.55
sbStroke.Parent = staminaBg

local staminaFill = Instance.new("Frame")
staminaFill.Name = "Fill"
staminaFill.AnchorPoint = Vector2.new(0, 0.5)
staminaFill.Position = UDim2.new(0, 0, 0.5, 0)
staminaFill.Size = UDim2.fromScale(1, 1)
staminaFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
staminaFill.BackgroundTransparency = 0.12
staminaFill.BorderSizePixel = 0
staminaFill.ZIndex = 5
staminaFill.Parent = staminaBg
local sfCorner = Instance.new("UICorner")
sfCorner.CornerRadius = UDim.new(0, 3)
sfCorner.Parent = staminaFill

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

-- ================= MOVEMENT =================
local character
local humanoid
local stamina = 100
local staminaDelay = 0
local exhausted = false
local sprintHeld = false
local crouchHeld = false
local bobPhase = 0
-- Eased toward the movement state so bob and shake fade in and out instead
-- of popping when you start, stop or begin sprinting.
local bobAmount = 0
local shakeAmount = 0
local crouchOffset = 0
local roll = 0
-- Rotation the default camera chose this frame, before smoothing.
local targetCFrame
-- Yaw is tracked unwrapped (it keeps counting past 360) so smoothing never
-- takes the short way round against a fast spin.
local targetYaw
local smoothYaw
local smoothPitch
local fov = BASE_FOV
local sprintForward = 0
local sprinting = false
local moving = false
-- Kept separately because the transparencies it drives use different ranges,
-- so it can't be read back from any one of them.
local hudFade = 0

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
	bobAmount = 0
	shakeAmount = 0
	roll = 0
	targetCFrame = nil
	targetYaw = nil
	fov = BASE_FOV
	sprintForward = 0
	sprinting = false
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	camera.FieldOfView = BASE_FOV
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

-- ================= TOUCH CONTROLS =================
-- Holding a button would pin the thumb that steers the camera, so on touch
-- sprint and crouch are toggles instead.
local sprintButton
local crouchButton

local function makeTouchButton(name, label, position)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = position
	b.Size = UDim2.fromOffset(64, 64)
	b.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	b.BackgroundTransparency = 0.35
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.TextColor3 = Color3.fromRGB(222, 202, 160)
	b.Text = label
	b.ZIndex = 6
	b.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(160, 132, 74)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.35
	stroke.Parent = b
	return b
end

local function paintTouchButton(b, active)
	b.BackgroundColor3 = active and Color3.fromRGB(146, 120, 66) or Color3.fromRGB(10, 10, 12)
	b.TextColor3 = active and Color3.fromRGB(16, 14, 10) or Color3.fromRGB(222, 202, 160)
end

if touch then
	sprintButton = makeTouchButton("SprintButton", "RUN", UDim2.new(1, -78, 1, -150))
	crouchButton = makeTouchButton("CrouchButton", "CROUCH", UDim2.new(1, -158, 1, -96))

	sprintButton.Activated:Connect(function()
		sprintHeld = not sprintHeld
		if sprintHeld then
			crouchHeld = false
		end
	end)
	crouchButton.Activated:Connect(function()
		crouchHeld = not crouchHeld
		if crouchHeld then
			sprintHeld = false
		end
	end)
end

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
	-- A toggled sprint would otherwise resume on its own once stamina recovers.
	if touch and exhausted then
		sprintHeld = false
	end

	local speedFactor = moving and (sprinting and 1.5 or (crouchHeld and 0.55 or 1)) or 0
	bobAmount += (speedFactor - bobAmount) * math.min(dt * 6, 1)
	bobPhase += dt * (sprinting and 12.5 or 9) * (moving and 1 or 0)
	local bobY = math.sin(bobPhase * 2) * 0.055 * bobAmount
	local bobX = math.cos(bobPhase) * 0.045 * bobAmount
	local breath = math.sin(os.clock() * 1.25) * 0.009
	local targetCrouch = crouchHeld and -1.55 or 0
	crouchOffset += (targetCrouch - crouchOffset) * math.min(dt * 8, 1)
	sprintForward += ((sprinting and SPRINT_FORWARD or 0) - sprintForward) * math.min(dt * 4, 1)
	humanoid.CameraOffset = Vector3.new(bobX, bobY + breath + crouchOffset, -sprintForward)

	local targetFov = BASE_FOV + (sprinting and 7 or 0) + (crouchHeld and -3 or 0) + (exhausted and 1.5 or 0)
	fov += (targetFov - fov) * math.min(dt * 6, 1)
	camera.FieldOfView = fov

	local frac = stamina / 100
	staminaFill.Size = UDim2.new(frac, 0, 1, 0)
	staminaFill.BackgroundColor3 = exhausted and Color3.fromRGB(160, 58, 48) or Color3.fromRGB(255, 255, 255)
	local fade = (stamina > 99 and not sprintHeld and staminaDelay <= 0) and 1 or 0
	hudFade += (fade - hudFade) * math.min(dt * 4, 1)
	staminaBg.BackgroundTransparency = 0.55 + 0.42 * hudFade
	staminaFill.BackgroundTransparency = 0.12 + 0.7 * hudFade
	sbStroke.Transparency = 0.55 + 0.45 * hudFade
	dot.BackgroundTransparency = 0.55 + 0.35 * hudFade

	if touch then
		paintTouchButton(sprintButton, sprintHeld)
		paintTouchButton(crouchButton, crouchHeld)
	end

	if currentPrompt then
		updatePromptText()
	end
end)

-- The default camera turns from whatever camera.CFrame was last frame, so it
-- has to see its own unsmoothed result again. Otherwise the smoothing lag
-- would swallow mouse input instead of easing it.
RunService:BindToRenderStep("HotelCameraRestore", Enum.RenderPriority.Camera.Value - 1, function()
	if targetCFrame then
		camera.CFrame = targetCFrame
	end
end)

RunService:BindToRenderStep("HotelCameraFX", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not humanoid or humanoid.Health <= 0 then
		-- Hand the camera back untouched, or the restore step would freeze it.
		targetCFrame = nil
		targetYaw = nil
		return
	end
	targetCFrame = camera.CFrame
	local pitch, yaw = targetCFrame:ToEulerAnglesYXZ()
	if targetYaw then
		-- Wrap only the per-frame step, which is always well under half a turn.
		targetYaw += (yaw - targetYaw + math.pi) % (2 * math.pi) - math.pi
		local alpha = 1 - math.exp(-LOOK_SMOOTHING * dt)
		local maxLag = math.rad(MAX_LOOK_LAG)
		smoothYaw += (targetYaw - smoothYaw) * alpha
		smoothYaw = math.clamp(smoothYaw, targetYaw - maxLag, targetYaw + maxLag)
		smoothPitch += (pitch - smoothPitch) * alpha
		smoothPitch = math.clamp(smoothPitch, pitch - maxLag, pitch + maxLag)
	else
		targetYaw = yaw
		smoothYaw = yaw
		smoothPitch = pitch
	end
	local smoothRotation = CFrame.fromEulerAnglesYXZ(smoothPitch, smoothYaw, 0)

	local lateral = humanoid.MoveDirection:Dot(targetCFrame.RightVector)
	local targetRoll = -lateral * (sprinting and 2.0 or (crouchHeld and 0.7 or 1.1))
	roll += (targetRoll - roll) * math.min(dt * 6, 1)
	shakeAmount += ((sprinting and 1 or 0) - shakeAmount) * math.min(dt * 5, 1)
	local shake = math.noise(os.clock() * 14, 0) * 0.1 * shakeAmount
	local turnLean = -math.deg(targetYaw - smoothYaw) * TURN_LEAN
	camera.CFrame = CFrame.new(targetCFrame.Position)
		* smoothRotation
		* CFrame.Angles(math.rad(shake), 0, math.rad(roll + turnLean))
end)
