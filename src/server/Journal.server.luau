-- The journal lying on a stand in the lobby. Every player takes their own copy
-- (the HasJournal player attribute); reading it is handled by Journal.client.
-- The stand sits where the floor rooms get built, so it goes once we leave the lobby.

local elevator = workspace:WaitForChild("Elevator")

local STAND_POSITION = Vector3.new(-9, 0, -8)

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

-- Turned to face the spawn so the book reads as something left out for you.
local base = CFrame.lookAt(STAND_POSITION, Vector3.new(0, STAND_POSITION.Y, 0))
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
