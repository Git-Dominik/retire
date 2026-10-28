-- The journal lying on a stand in the lobby. Every player takes their own copy
-- (the HasJournal player attribute); reading it is handled by Journal.client.
--
-- While someone is reading, a small book icon floats above their head for everyone else
-- (Journal.client fires the JournalRead remote as the book goes up or down; the server
-- owns the icon so it replicates, and hides it from the reader themselves).
-- The stand sits where the floor rooms get built, so it goes once we leave the lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local elevator = workspace:WaitForChild("Elevator")

-- In the break room, against the wall under the cork board, left of the lockers.
local STAND_POSITION = Vector3.new(13.8, 1.1, -49.55)

local LEATHER = Color3.fromRGB(74, 40, 28)
local PAPER = Color3.fromRGB(214, 200, 168)
local WOOD = Color3.fromRGB(46, 30, 20)

local function part(parent, name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local stand = Instance.new("Model")
stand.Name = "JournalStand"

-- Back to the wall, facing into the room.
local base = CFrame.lookAt(STAND_POSITION, STAND_POSITION + Vector3.new(0, 0, 1))
part(stand, "Foot", Vector3.new(1.6, 0.2, 1.6), base * CFrame.new(0, 0.1, 0), WOOD, Enum.Material.Wood)
part(stand, "Post", Vector3.new(0.3, 3.4, 0.3), base * CFrame.new(0, 1.9, 0), WOOD, Enum.Material.Wood)
-- Lectern top, tilted toward the reader.
local top = base * CFrame.new(0, 3.65, 0) * CFrame.Angles(math.rad(-20), 0, 0)
part(stand, "Top", Vector3.new(2, 0.15, 1.5), top, WOOD, Enum.Material.Wood)

local book = Instance.new("Model")
book.Name = "Journal"
local bookCf = top * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, math.rad(8), 0)
part(book, "Cover", Vector3.new(1.05, 0.22, 1.4), bookCf, LEATHER, Enum.Material.Leather)
part(book, "Pages", Vector3.new(0.98, 0.17, 1.32), bookCf * CFrame.new(0.04, 0.005, 0), PAPER)
part(book, "Strap", Vector3.new(0.12, 0.24, 1.42), bookCf * CFrame.new(0.3, 0, 0), Color3.fromRGB(40, 22, 16), Enum.Material.Leather)
book.PrimaryPart = book.Cover
book.Parent = stand

-- Hangs above and in front of the lectern so it lights the book's face, not just the floor.
local glowHolder = Instance.new("Attachment")
glowHolder.Position = Vector3.new(0, 2.2, -1)
glowHolder.Parent = book.Cover
local glow = Instance.new("PointLight")
glow.Color = Color3.fromRGB(255, 190, 130)
glow.Range = 9
glow.Brightness = 1
glow.Parent = glowHolder

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "TakePrompt"
prompt.ActionText = "Take"
prompt.ObjectText = "Journal"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0.3
prompt.MaxActivationDistance = 7
prompt.RequiresLineOfSight = false
prompt:SetAttribute("IgnoreSight", true) -- Camera.client forces sight on every other prompt
prompt.Parent = book.Cover

prompt.Triggered:Connect(function(player)
	player:SetAttribute("HasJournal", true)
end)

stand.Parent = workspace

elevator:GetAttributeChangedSignal("Level"):Connect(function()
	if (elevator:GetAttribute("Level") or 0) > 0 and stand.Parent then
		stand:Destroy()
	end
end)

-- ================= READING ICON =================
local readRemote = Instance.new("RemoteEvent")
readRemote.Name = "JournalRead"
readRemote.Parent = ReplicatedStorage

local function frame(parent, size, position, color, corner)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, corner)
	c.Parent = f
	f.Parent = parent
	return f
end

-- A little open book: leather cover, two cream pages, a dark spine.
local function buildIcon(player)
	local gui = Instance.new("BillboardGui")
	gui.Name = "JournalIcon"
	gui.Size = UDim2.fromOffset(44, 36)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 60
	gui.PlayerToHideFrom = player
	frame(gui, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), LEATHER, 5)
	frame(gui, UDim2.fromScale(0.42, 0.72), UDim2.fromScale(0.28, 0.5), PAPER, 2)
	frame(gui, UDim2.fromScale(0.42, 0.72), UDim2.fromScale(0.72, 0.5), PAPER, 2)
	frame(gui, UDim2.new(0, 2, 0.84, 0), UDim2.fromScale(0.5, 0.5), WOOD, 0)
	return gui
end

readRemote.OnServerEvent:Connect(function(player, reading)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if typeof(reading) ~= "boolean" or not head then
		return
	end
	local icon = head:FindFirstChild("JournalIcon")
	if reading and not icon and player:GetAttribute("HasJournal") then
		buildIcon(player).Parent = head
	elseif not reading and icon then
		icon:Destroy()
	end
end)

-- The reader may close the book as they die; the icon goes with the old character anyway.
Players.PlayerRemoving:Connect(function(player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	local icon = head and head:FindFirstChild("JournalIcon")
	if icon then
		icon:Destroy()
	end
end)
