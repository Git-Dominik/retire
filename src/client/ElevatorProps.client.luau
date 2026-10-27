-- Local animation for the elevator's fiddly props (see ElevatorProps.server): the
-- service bell's plunger dips when rung, and the gramophone record turns while it plays.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Record speed, revolutions per second (a 78 spins a little faster than this).
local RECORD_SPEED = 0.9

local elevator = workspace:WaitForChild("Elevator")
local bell = elevator:WaitForChild("CargoLift"):WaitForChild("ServiceBell")
local bellTop = bell:WaitForChild("Top")
local gramophone = elevator:WaitForChild("Decor"):WaitForChild("Gramophone")
local vinyl = gramophone:WaitForChild("Vinyl")

-- ================= BELL =================
local topRest = bellTop.CFrame
local ringRun = 0
bell:GetAttributeChangedSignal("RingSeq"):Connect(function()
	ringRun += 1
	local run = ringRun
	local start = os.clock()
	local down = topRest - topRest.UpVector * 0.07
	while true do
		local t = os.clock() - start
		if run ~= ringRun then
			return
		end
		if t < 0.05 then
			bellTop.CFrame = topRest:Lerp(down, t / 0.05)
		else
			local u = math.min((t - 0.05) / 0.3, 1)
			bellTop.CFrame = down:Lerp(topRest, TweenService:GetValue(u, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
			if u >= 1 then
				return
			end
		end
		RunService.RenderStepped:Wait()
	end
end)

-- ================= RECORD =================
-- Spins up when the record starts and coasts down when it stops.
local vinylRest = vinyl.CFrame
local angle, speed = 0, 0
RunService.RenderStepped:Connect(function(dt)
	local target = gramophone:GetAttribute("Playing") and RECORD_SPEED or 0
	speed += (target - speed) * math.min(dt * 2.5, 1)
	if speed > 0.001 then
		angle += speed * math.pi * 2 * dt
		vinyl.CFrame = vinylRest * CFrame.Angles(0, -angle, 0)
	end
end)

-- ================= ARMCHAIR STAND =================
-- ProximityPrompts are hidden while a character is seated, so the seat prompt
-- cannot be used to get back up. Show a small stand hint and bind that instead.
local player = Players.LocalPlayer
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local playerGui = player:WaitForChild("PlayerGui")
local standGui = Instance.new("ScreenGui")
standGui.Name = "SeatStand"
standGui.ResetOnSpawn = false
standGui.IgnoreGuiInset = true
standGui.Parent = playerGui

local hint = Instance.new("TextButton")
hint.Name = "StandHint"
hint.AnchorPoint = Vector2.new(0.5, 0.5)
hint.Position = UDim2.new(0.5, 0, 1, -112)
hint.Size = UDim2.fromOffset(146, 44)
hint.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
hint.BackgroundTransparency = 0.25
hint.BorderSizePixel = 0
hint.AutoButtonColor = false
hint.Text = ""
hint.Visible = false
hint.ZIndex = 9
hint.Parent = standGui

local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 8)
hintCorner.Parent = hint

local hintStroke = Instance.new("UIStroke")
hintStroke.Color = Color3.fromRGB(160, 132, 74)
hintStroke.Thickness = 1
hintStroke.Transparency = 0.35
hintStroke.Parent = hint

local keyBadge = Instance.new("TextLabel")
keyBadge.Name = "Key"
keyBadge.AnchorPoint = Vector2.new(0, 0.5)
keyBadge.Position = UDim2.new(0, 8, 0.5, 0)
keyBadge.Size = UDim2.fromOffset(32, 32)
keyBadge.BackgroundColor3 = Color3.fromRGB(255, 228, 196)
keyBadge.BorderSizePixel = 0
keyBadge.Font = Enum.Font.GothamBold
keyBadge.TextSize = 15
keyBadge.TextColor3 = Color3.fromRGB(46, 30, 22)
keyBadge.Text = touch and "TAP" or "E"
keyBadge.ZIndex = 10
keyBadge.Parent = hint

local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(0, 6)
keyCorner.Parent = keyBadge

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Action"
hintLabel.BackgroundTransparency = 1
hintLabel.Position = UDim2.new(0, 48, 0, 0)
hintLabel.Size = UDim2.new(1, -56, 1, 0)
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextSize = 16
hintLabel.TextColor3 = Color3.fromRGB(255, 228, 196)
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Text = "Stand"
hintLabel.ZIndex = 10
hintLabel.Parent = hint

local function isArmchairSeat(seat)
	return seat ~= nil and seat:GetAttribute("ArmchairSeat") == true
end

local function standUp()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not humanoid.Sit then
		return
	end
	local seat = humanoid.SeatPart
	if not isArmchairSeat(seat) then
		return
	end
	local look = seat.CFrame.LookVector
	local root = character:FindFirstChild("HumanoidRootPart")
	local floorY = seat.CFrame.Position.Y - 1.9
	local standPos = seat.CFrame.Position + look * 3.2
	standPos = Vector3.new(standPos.X, floorY + humanoid.HipHeight + (root and root.Size.Y / 2 or 1), standPos.Z)
	humanoid.Sit = false
	-- Roblox drops the character behind the seat; put them back in front instead.
	RunService.Heartbeat:Wait()
	if humanoid.Health > 0 and not humanoid.Sit then
		character:PivotTo(CFrame.lookAt(standPos, standPos + look))
	end
end

local seatedConnection
local function bindCharacter(character)
	if seatedConnection then
		seatedConnection:Disconnect()
	end
	local humanoid = character:WaitForChild("Humanoid")
	seatedConnection = humanoid.Seated:Connect(function(isSeated, seat)
		hint.Visible = isSeated and isArmchairSeat(seat)
	end)
	humanoid.Died:Connect(function()
		hint.Visible = false
	end)
	hint.Visible = humanoid.Sit and isArmchairSeat(humanoid.SeatPart)
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	bindCharacter(player.Character)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space then
		standUp()
	end
end)

hint.Activated:Connect(standUp)