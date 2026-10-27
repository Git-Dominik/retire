-- F2 dev menu. Only built in Studio or for the place owner; the server checks
-- again before acting on anything sent from here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not (RunService:IsStudio() or player.UserId == game.CreatorId) then
	return
end

local devRemote = ReplicatedStorage:WaitForChild("ElevatorDev")
local elevator = workspace:WaitForChild("Elevator")

local gui = Instance.new("ScreenGui")
gui.Name = "DevMenu"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = UDim2.new(0, 24, 0.5, 0)
panel.Size = UDim2.fromOffset(220, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 6)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(148, 120, 64)
panelStroke.Transparency = 0.4
panelStroke.Parent = panel
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel

local function label(text, order, font, size, color)
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.Size = UDim2.new(1, 0, 0, size + 4)
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = panel
	return l
end

label("DEV MENU", 1, Enum.Font.GothamBold, 13, Color3.fromRGB(222, 202, 160))
local stateLabel = label("", 2, Enum.Font.Gotham, 12, Color3.fromRGB(168, 158, 138))

local function updateState()
	stateLabel.Text = "Floor "
		.. tostring(elevator:GetAttribute("Level") or "?")
		.. "  ·  Doors: "
		.. tostring(elevator:GetAttribute("DoorState") or "?")
end
elevator:GetAttributeChangedSignal("DoorState"):Connect(updateState)
elevator:GetAttributeChangedSignal("Level"):Connect(updateState)
updateState()

local function button(text, order, onClick)
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.Size = UDim2.new(1, 0, 0, 30)
	b.BackgroundColor3 = Color3.fromRGB(24, 22, 18)
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = Color3.fromRGB(222, 202, 160)
	b.Text = text
	b.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = b
	b.Activated:Connect(onClick)
	return b
end

-- Modal frees the mouse from the first-person lock while the menu is open.
local closeButton = button("Close elevator", 3, function()
	devRemote:FireServer("Close")
end)
closeButton.Modal = true
button("Open elevator", 4, function()
	devRemote:FireServer("Open")
end)
button("Descend (skip item)", 5, function()
	devRemote:FireServer("Descend")
end)
button("Summon Librarian (floor 1)", 6, function()
	devRemote:FireServer("Librarian")
end)
label("F2 to hide", 7, Enum.Font.Gotham, 11, Color3.fromRGB(110, 104, 92))

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F2 then
		gui.Enabled = not gui.Enabled
	end
end)
