-- F2 dev menu. Available to every player. Everything goes through the server's
-- ElevatorDev remote (Elevator.server), including spawning a stock item at your feet
-- by its ItemId or name from Shared.StockItems.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local StockItems = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StockItems"))

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
-- Matches an ItemId or display name, ignoring case and spaces ("reimu", "Ring box").
local function findItem(text)
	local wanted = text:lower():gsub("%s", "")
	for _, id in StockItems.ids() do
		local def = StockItems.get(id)
		if id:lower() == wanted or def.name:lower():gsub("%s", "") == wanted then
			return id
		end
	end
	for _, id in StockItems.ids() do
		if wanted ~= "" and id:lower():find(wanted, 1, true) then
			return id
		end
	end
	return nil
end

local spawnBox = Instance.new("TextBox")
spawnBox.LayoutOrder = 6
spawnBox.Size = UDim2.new(1, 0, 0, 30)
spawnBox.BackgroundColor3 = Color3.fromRGB(24, 22, 18)
spawnBox.BorderSizePixel = 0
spawnBox.ClearTextOnFocus = false
spawnBox.Font = Enum.Font.Gotham
spawnBox.TextSize = 12
spawnBox.TextColor3 = Color3.fromRGB(222, 202, 160)
spawnBox.PlaceholderColor3 = Color3.fromRGB(110, 104, 92)
spawnBox.PlaceholderText = "Spawn item (Enter)"
spawnBox.Text = ""
spawnBox.Parent = panel
local spawnCorner = Instance.new("UICorner")
spawnCorner.CornerRadius = UDim.new(0, 4)
spawnCorner.Parent = spawnBox
local spawnStatus = label("", 7, Enum.Font.Gotham, 11, Color3.fromRGB(168, 158, 138))

spawnBox.FocusLost:Connect(function(enterPressed)
	if not enterPressed or spawnBox.Text == "" then
		return
	end
	local id = findItem(spawnBox.Text)
	if id then
		devRemote:FireServer("SpawnItem", id)
		spawnStatus.Text = "Spawned " .. StockItems.get(id).name
	else
		spawnStatus.Text = 'No item "' .. spawnBox.Text .. '"'
	end
end)

label("F2 to hide", 8, Enum.Font.Gotham, 11, Color3.fromRGB(110, 104, 92))

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F2 then
		gui.Enabled = not gui.Enabled
	end
end)
