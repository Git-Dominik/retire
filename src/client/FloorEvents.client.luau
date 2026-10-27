-- Client side of floor challenges (Library.luau): short hint lines at the
-- bottom of the screen, and the jumpscare when the Librarian catches you.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SCREAM_ID = "rbxassetid://130285917830946"

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("FloorEvents")

local gui = Instance.new("ScreenGui")
gui.Name = "FloorEvents"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

-- ================= HINTS =================
local hintLabel = Instance.new("TextLabel")
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 1, -170)
hintLabel.Size = UDim2.new(0.6, 0, 0, 30)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Garamond
hintLabel.TextSize = 22
hintLabel.TextWrapped = true
hintLabel.TextColor3 = Color3.fromRGB(232, 218, 190)
hintLabel.TextStrokeColor3 = Color3.fromRGB(10, 6, 4)
hintLabel.TextTransparency = 1
hintLabel.TextStrokeTransparency = 1
hintLabel.Parent = gui

local hintToken = 0
remotes.Hint.OnClientEvent:Connect(function(text)
	hintToken += 1
	local token = hintToken
	hintLabel.Text = text
	TweenService:Create(hintLabel, TweenInfo.new(0.25), { TextTransparency = 0, TextStrokeTransparency = 0.5 }):Play()
	task.delay(3.5 + #text * 0.03, function()
		if token == hintToken then
			TweenService:Create(hintLabel, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end)

-- ================= JUMPSCARE =================
-- A black screen with the Librarian's two pale eyes rushing at you.
local scare = Instance.new("Frame")
scare.Size = UDim2.fromScale(1, 1)
scare.BackgroundColor3 = Color3.fromRGB(4, 2, 2)
scare.BorderSizePixel = 0
scare.Visible = false
scare.ZIndex = 50
scare.Parent = gui

local eyes = {}
for _, side in { -1, 1 } do
	local eye = Instance.new("Frame")
	eye.AnchorPoint = Vector2.new(0.5, 0.5)
	eye.BackgroundColor3 = Color3.fromRGB(255, 238, 210)
	eye.BorderSizePixel = 0
	eye.ZIndex = 51
	eye.Parent = scare
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = eye
	table.insert(eyes, { frame = eye, side = side })
end

local scream = Instance.new("Sound")
scream.SoundId = SCREAM_ID
scream.Volume = 0.8
scream.Parent = gui

remotes.Jumpscare.OnClientEvent:Connect(function()
	scare.Visible = true
	scare.BackgroundTransparency = 0
	for _, e in eyes do
		e.frame.Position = UDim2.fromScale(0.5 + e.side * 0.05, 0.45)
		e.frame.Size = UDim2.fromScale(0.03, 0.015)
		TweenService:Create(e.frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(0.5 + e.side * 0.2, 0.42),
			Size = UDim2.fromScale(0.16, 0.07),
		}):Play()
	end
	scream:Play()
	task.wait(0.9)
	TweenService:Create(scare, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	for _, e in eyes do
		TweenService:Create(e.frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	end
	task.wait(0.6)
	scare.Visible = false
	for _, e in eyes do
		e.frame.BackgroundTransparency = 0
	end
end)
