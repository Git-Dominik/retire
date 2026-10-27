local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
-- How fast the view catches up to the mouse. Lower trails further behind;
-- around 30+ feels close to the raw default camera.
local LOOK_SMOOTHING = 10
-- Furthest the view may trail the mouse, in degrees, so fast spins stay tight.
local MAX_LOOK_LAG = 15
-- Degrees of roll per degree the view trails the mouse; turning left leans right.
local TURN_LEAN = 0.1
-- Studs the camera pushes forward while sprinting, easing back after you stop.
local SPRINT_FORWARD = 1.5
-- Pitch the view is pulled to while reading the journal, in degrees.
local READ_PITCH = -46

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
dot.Size = UDim2.fromOffset(6, 6)
dot.BackgroundColor3 = Color3.fromRGB(230, 222, 205)
dot.BackgroundTransparency = 0.6
dot.BorderSizePixel = 0
dot.ZIndex = 2
dot.Parent = gui
local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = dot
local dotStroke = Instance.new("UIStroke")
dotStroke.Color = Color3.fromRGB(10, 10, 10)
dotStroke.Transparency = 0.7
dotStroke.Thickness = 1
dotStroke.Parent = dot

-- hide the default mouse cursor; the dot replaces it
UserInputService.MouseIconEnabled = false

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

-- Bind overview above the stamina bar, in the journal hint's style. It lists the
-- binds that apply right now: Backspace drops a held shop or scavenged item
-- (StockingService's DropItem remote).
local DROP_KEY = Enum.KeyCode.Backspace

local binds = Instance.new("TextLabel")
binds.Name = "Binds"
binds.AnchorPoint = Vector2.new(0.5, 1)
binds.Position = UDim2.new(0.5, 0, 1, -58)
binds.Size = UDim2.fromOffset(560, 24)
binds.BackgroundTransparency = 1
binds.Font = Enum.Font.GothamBold
binds.TextSize = 12
binds.TextColor3 = Color3.fromRGB(222, 202, 160)
binds.TextTransparency = 1
binds.TextStrokeTransparency = 1
binds.ZIndex = 4
binds.Parent = gui

local function heldDroppable()
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	if tool and (tool:GetAttribute("ShopItem") or tool:GetAttribute("ScavengedLevel")) then
		return tool
	end
	return nil
end

local bindsShown = false
local bindsTween
local function refreshBinds()
	local text = heldDroppable() and not touch and "BACKSPACE   drop" or nil
	local shown = text ~= nil and not player:GetAttribute("ReadingJournal")
	binds.Text = text or binds.Text
	if shown == bindsShown then
		return
	end
	bindsShown = shown
	if bindsTween then
		bindsTween:Cancel()
	end
	bindsTween = TweenService:Create(binds, TweenInfo.new(0.3), { TextTransparency = shown and 0.1 or 1, TextStrokeTransparency = shown and 0.6 or 1 })
	bindsTween:Play()
end

local function watchBindsCharacter(character)
	character.ChildAdded:Connect(refreshBinds)
	character.ChildRemoved:Connect(refreshBinds)
	refreshBinds()
end
player.CharacterAdded:Connect(watchBindsCharacter)
if player.Character then
	watchBindsCharacter(player.Character)
end
player:GetAttributeChangedSignal("ReadingJournal"):Connect(refreshBinds)

-- ================= PROMPT UI =================
-- The prompt sits on the object itself: a cartoon hand tapping at it with the key
-- badge underneath, and the action in small type beside the key.
local HAND_IMAGE = "rbxassetid://6018832212" -- "Images/hand_cursor1600" decal 6018832303, a plain silhouette
local CREAM = Color3.fromRGB(255, 228, 196)
local INK = Color3.fromRGB(46, 30, 22)
local POPUP_W, POPUP_H = 260, 140
-- Pixel the hand's fingertip sits at inside the popup; the popup is shifted so this
-- point lands on the object.
local TIP = Vector2.new(34, 8)

-- Drawn on the HUD and moved onto the object's screen position every frame.
local popupGroup = Instance.new("CanvasGroup")
popupGroup.Name = "PromptPopup"
popupGroup.Size = UDim2.fromOffset(POPUP_W, POPUP_H)
popupGroup.BackgroundTransparency = 1
popupGroup.GroupTransparency = 1
popupGroup.Visible = false
popupGroup.ZIndex = 9
popupGroup.Parent = gui
local popupScale = Instance.new("UIScale")
popupScale.Parent = popupGroup
local popupTarget

local hand = Instance.new("ImageLabel")
hand.Name = "Hand"
hand.BackgroundTransparency = 1
hand.Image = HAND_IMAGE
hand.ImageColor3 = CREAM
hand.Size = UDim2.fromOffset(64, 64)
-- The image's fingertip is near its top-left third; tilt it so it points up and in.
hand.AnchorPoint = Vector2.new(0.36, 0.04)
hand.Position = UDim2.fromOffset(TIP.X, TIP.Y)
hand.Rotation = -18
hand.ZIndex = 3
hand.Parent = popupGroup

local badge = Instance.new("Frame")
badge.Name = "Key"
badge.AnchorPoint = Vector2.new(0.5, 0)
badge.Position = UDim2.fromOffset(TIP.X + 11, TIP.Y + 70)
badge.Size = UDim2.fromOffset(42, 42)
badge.BackgroundColor3 = CREAM
badge.BorderSizePixel = 0
badge.ZIndex = 2
badge.Parent = popupGroup
local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0, 8)
badgeCorner.Parent = badge
-- Fills the key from the bottom while a hold prompt is held down.
local holdFill = Instance.new("Frame")
holdFill.Name = "HoldFill"
holdFill.AnchorPoint = Vector2.new(0, 1)
holdFill.Position = UDim2.fromScale(0, 1)
holdFill.Size = UDim2.fromScale(1, 0)
holdFill.BackgroundColor3 = Color3.fromRGB(214, 168, 96)
holdFill.BorderSizePixel = 0
holdFill.ZIndex = 2
holdFill.Parent = badge
local holdCorner = Instance.new("UICorner")
holdCorner.CornerRadius = UDim.new(0, 8)
holdCorner.Parent = holdFill
local keyLabel = Instance.new("TextLabel")
keyLabel.Size = UDim2.fromScale(1, 1)
keyLabel.BackgroundTransparency = 1
keyLabel.Font = Enum.Font.GothamBlack
keyLabel.TextSize = 24
keyLabel.TextColor3 = INK
keyLabel.Text = "E"
keyLabel.ZIndex = 3
keyLabel.Parent = badge

-- A prompt with an AltKey attribute (the floor selector's Q) gets a second key badge
-- to the left of its own; the prompt's script handles that key itself.
local BADGE_STEP = 48
local altBadge = badge:Clone()
altBadge.Name = "AltKey"
altBadge.HoldFill:Destroy()
altBadge.Visible = false
altBadge.Parent = popupGroup
local altKeyLabel = altBadge:FindFirstChildOfClass("TextLabel")

local actionLabel = Instance.new("TextLabel")
actionLabel.AnchorPoint = Vector2.new(0, 0.5)
actionLabel.Position = UDim2.new(0, TIP.X + 11 + 30, 0, TIP.Y + 70 + 21)
actionLabel.Size = UDim2.fromOffset(140, 24)
actionLabel.BackgroundTransparency = 1
actionLabel.Font = Enum.Font.GothamBold
actionLabel.TextSize = 18
actionLabel.TextColor3 = CREAM
actionLabel.TextXAlignment = Enum.TextXAlignment.Left
actionLabel.Text = ""
actionLabel.ZIndex = 3
actionLabel.Parent = popupGroup

local currentPrompt
local promptTween
local holdTween

local function updatePromptText()
	if not currentPrompt then
		return
	end
	if actionLabel.Text ~= currentPrompt.ActionText then
		actionLabel.Text = currentPrompt.ActionText
	end
	local key = UserInputService:GetStringForKeyCode(currentPrompt.KeyboardKeyCode)
	keyLabel.Text = key ~= "" and string.upper(key) or currentPrompt.KeyboardKeyCode.Name

	local alt = currentPrompt:GetAttribute("AltKey")
	local shift = alt and BADGE_STEP or 0
	altBadge.Visible = alt ~= nil
	altKeyLabel.Text = alt or ""
	badge.Position = UDim2.fromOffset(TIP.X + 11 + shift, TIP.Y + 70)
	actionLabel.Position = UDim2.new(0, TIP.X + 11 + 30 + shift, 0, TIP.Y + 70 + 21)
end

local function setHold(fraction, time)
	if holdTween then
		holdTween:Cancel()
	end
	holdTween = TweenService:Create(holdFill, TweenInfo.new(time, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, fraction) })
	holdTween:Play()
end

local function showPrompt(prompt)
	currentPrompt = prompt
	updatePromptText()
	setHold(0, 0)
	popupTarget = prompt.Parent
	popupGroup.Visible = true
	if promptTween then
		promptTween:Cancel()
	end
	popupScale.Scale = 0.7
	promptTween = TweenService:Create(popupGroup, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 })
	promptTween:Play()
	TweenService:Create(popupScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function hidePrompt(prompt)
	if prompt and currentPrompt ~= prompt then
		return
	end
	currentPrompt = nil
	if promptTween then
		promptTween:Cancel()
	end
	local hideTween = TweenService:Create(popupGroup, TweenInfo.new(0.12), { GroupTransparency = 1 })
	promptTween = hideTween
	-- Completed is deferred, so it can land after another prompt has already been
	-- shown; only hide if this fade-out finished and nothing replaced it.
	hideTween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and promptTween == hideTween and not currentPrompt then
			popupGroup.Visible = false
		end
	end)
	promptTween:Play()
end

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	if prompt == currentPrompt then
		setHold(1, prompt.HoldDuration)
	end
end)
ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	if prompt == currentPrompt then
		setHold(0, 0.12)
	end
end)
-- Every interaction gets a soft click, heard only by whoever triggered it.
local interactSound = Instance.new("Sound")
interactSound.Name = "Interact"
interactSound.SoundId = "rbxassetid://9113817566" -- "Clothes Handling 2" (Pro Sound Effects)
interactSound.Volume = 0.35
interactSound.Parent = script

-- A quick press on the key so the trigger reads.
local function pressPopup()
	popupScale.Scale = 0.88
	TweenService:Create(popupScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if not prompt:GetAttribute("SkipInteractSound") then
		SoundService:PlayLocalSound(interactSound)
	end
	if prompt ~= currentPrompt then
		return
	end
	setHold(0, 0.12)
	pressPopup()
end)

-- The alt key gets the same click and press as the prompt's own key.
UserInputService.InputBegan:Connect(function(input, processed)
	local alt = currentPrompt and currentPrompt:GetAttribute("AltKey")
	if processed or not alt or input.KeyCode.Name ~= alt then
		return
	end
	if not currentPrompt:GetAttribute("SkipInteractSound") then
		SoundService:PlayLocalSound(interactSound)
	end
	pressPopup()
end)

-- Pins the popup to the object and makes the hand tap at it.
RunService.RenderStepped:Connect(function()
	if not popupGroup.Visible or not popupTarget then
		return
	end
	local world = popupTarget:IsA("Attachment") and popupTarget.WorldPosition or popupTarget.Position
	local point, onScreen = camera:WorldToViewportPoint(world)
	popupGroup.Position = UDim2.fromOffset(point.X - TIP.X, point.Y - TIP.Y)
	if not onScreen then
		popupGroup.Position = UDim2.fromOffset(-1000, -1000)
	end
	local tap = math.max(0, math.sin(os.clock() * 5)) ^ 3
	hand.Position = UDim2.fromOffset(TIP.X + tap * 4, TIP.Y + tap * 6)
end)

-- Soft outline around whatever the current prompt belongs to. A part that is a
-- model's PrimaryPart (the lobby journal) outlines the whole model.
local outline = Instance.new("Highlight")
outline.Name = "InteractOutline"
outline.FillTransparency = 1
outline.OutlineColor = Color3.fromRGB(255, 222, 168)
outline.OutlineTransparency = 1
outline.DepthMode = Enum.HighlightDepthMode.Occluded
outline.Parent = playerGui
local outlinePrompt
local outlineTween

local function outlineTarget(prompt)
	local parent = prompt.Parent
	local model = parent and parent.Parent
	if model and model:IsA("Model") and model.PrimaryPart == parent then
		return model
	end
	return parent
end

local function setOutline(prompt)
	outlinePrompt = prompt
	if prompt then
		outline.Adornee = outlineTarget(prompt)
	end
	if outlineTween then
		outlineTween:Cancel()
	end
	outlineTween = TweenService:Create(outline, TweenInfo.new(prompt and 0.16 or 0.14), { OutlineTransparency = prompt and 0.25 or 1 })
	outlineTween:Play()
end

ProximityPromptService.PromptShown:Connect(function(prompt)
	setOutline(prompt)
	if touch then
		return
	end
	showPrompt(prompt)
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	if outlinePrompt == prompt then
		setOutline(nil)
	end
	if touch then
		return
	end
	hidePrompt(prompt)
end)

if not touch then
	local function useCustomStyle(d)
		if d:IsA("ProximityPrompt") then
			d.Style = Enum.ProximityPromptStyle.Custom
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		useCustomStyle(d)
	end
	-- Prompts on things spawned later (floor items, the offering tray) too.
	workspace.DescendantAdded:Connect(useCustomStyle)
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
local rumbleAmount = 0
local readBlend = 0
-- Pitch you were looking at when the journal opened; set while reading or easing back.
local readFromPitch
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
	elseif key == DROP_KEY and heldDroppable() then
		local dropRemote = ReplicatedStorage:FindFirstChild("DropItem")
		if dropRemote then
			dropRemote:FireServer()
		end
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
	-- Arms.client lowers whatever you're holding by the same amount.
	player:SetAttribute("CrouchOffset", crouchOffset)
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
	dot.Visible = not player:GetAttribute("ReadingJournal")

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
	-- Reading the journal (see Journal.client) holds the pitch: it eases from where
	-- you were looking down onto the book and back again, while the mouse still
	-- turns you left and right. Writing the held pitch into targetCFrame stops the
	-- default camera from banking up vertical mouse movement in the meantime.
	-- Scripted moves (crawling through a vent) set ForcedLook to the direction the
	-- view should face; it eases round to it, and mouse look is ignored until it
	-- clears. Like the pitch hold below, writing it into targetCFrame keeps the
	-- default camera from banking up mouse movement in the meantime.
	local forcedLook = player:GetAttribute("ForcedLook")
	if typeof(forcedLook) == "Vector3" and forcedLook.Magnitude > 0 then
		local goal = CFrame.lookAt(Vector3.zero, forcedLook)
		local current = targetCFrame - targetCFrame.Position
		targetCFrame = CFrame.new(targetCFrame.Position) * current:Lerp(goal, math.min(dt * 8, 1))
		pitch, yaw = targetCFrame:ToEulerAnglesYXZ()
	end
	local reading = player:GetAttribute("ReadingJournal")
	-- Eases back out quicker than it eases in, so you can look up soon after shutting the journal.
	readBlend += ((reading and 1 or 0) - readBlend) * math.min(dt * (reading and 5 or 16), 1)
	if reading and not readFromPitch then
		readFromPitch = pitch
	end
	if readFromPitch then
		pitch = readFromPitch + (math.rad(READ_PITCH) - readFromPitch) * readBlend
		targetCFrame = CFrame.new(targetCFrame.Position) * CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
		if not reading and readBlend < 0.05 then
			readFromPitch = nil
		end
	end
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
	-- Low rattle while the elevator is descending; eases in and out with the ride.
	local elevator = workspace:FindFirstChild("Elevator")
	local descending = elevator and elevator:GetAttribute("Descending")
	rumbleAmount += ((descending and 1 or 0) - rumbleAmount) * math.min(dt * 1.5, 1)
	local t = os.clock()
	local rumblePitch = math.noise(t * 9, 3.1) * 0.5 * rumbleAmount
	local rumbleRoll = math.noise(t * 7, 8.7) * 0.42 * rumbleAmount
	local rumbleY = math.noise(t * 11, 5.3) * 0.075 * rumbleAmount
	local turnLean = -math.deg(targetYaw - smoothYaw) * TURN_LEAN
	camera.CFrame = CFrame.new(targetCFrame.Position + Vector3.new(0, rumbleY, 0))
		* smoothRotation
		* CFrame.Angles(math.rad(shake + rumblePitch), 0, math.rad(roll + turnLean + rumbleRoll))
end)
