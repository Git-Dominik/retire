-- Small things to fiddle with while riding the elevator: the service bell on the cargo
-- sill, the gramophone, the two floor lamps, the grandfather clock and the armchairs.
-- Sounds are played here so everyone hears them; the bell plunger and the spinning
-- record are animated by ElevatorProps.client from the attributes set here.

local Debris = game:GetService("Debris")

local BELL_ID = "rbxassetid://9125485659" -- "Desk Bell Counter Service Single Ringing Dings 2" (Pro Sound Effects)
local RECORD_ID = "rbxassetid://9045811853" -- "My Old Kentucky Home (a)", upright piano (KPM)
local WIND_ID = "rbxassetid://9126029394" -- "Switch Rotating Switch Clicks" (Pro Sound Effects)
local CHAIN_ID = "rbxassetid://9116216027" -- "Lamp Switch Pull Chain Slow Fast Pulls 15" (Pro Sound Effects)
local CHIME_ID = "rbxassetid://9116463812" -- "Mantle Clock 1", 1912 Seth Thomas strike (Pro Sound Effects)

-- Seconds of the clock recording to play: the strike, before it settles into ticking.
local CHIME_LENGTH = 6
local RECORD_VOLUME = 0.22

local elevator = workspace:WaitForChild("Elevator")
local decor = elevator:WaitForChild("Decor")
local lights = elevator:WaitForChild("Lights")

local function makePrompt(parent, action, object, distance)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = distance or 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function makeSound(parent, id, volume, props)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 60
	for k, v in props or {} do
		s[k] = v
	end
	s.Parent = parent
	return s
end

-- One-shot copy so rapid rings overlap instead of cutting each other off.
local function playOnce(template)
	local s = template:Clone()
	s.Parent = template.Parent
	s:Play()
	Debris:AddItem(s, s.TimeLength > 0 and s.TimeLength + 0.5 or 6)
end

-- ================= SERVICE BELL =================
local bell = elevator:WaitForChild("CargoLift"):WaitForChild("ServiceBell")
local bellTop = bell:WaitForChild("Top")
local ding = makeSound(bellTop, BELL_ID, 0.5)
local lastRing = 0
local bellPrompt = makePrompt(bell:WaitForChild("Base"), "Ring", "Service Bell", 6)
-- The bell makes its own sound; skip the generic interaction click.
bellPrompt:SetAttribute("SkipInteractSound", true)
bellPrompt.Triggered:Connect(function()
	if os.clock() - lastRing < 0.25 then
		return
	end
	lastRing = os.clock()
	playOnce(ding)
	bell:SetAttribute("RingSeq", (bell:GetAttribute("RingSeq") or 0) + 1)
end)

-- ================= GRAMOPHONE =================
-- The free model's "Wind" prompt finally does something: it puts a record on, or
-- lifts the needle if one is playing. The elevator's own ride music takes over the
-- gramophone while it descends, so the record stops then.
local gramophone = decor:WaitForChild("Gramophone")
local horn = gramophone:WaitForChild("Horn")
local record = makeSound(horn, RECORD_ID, 0, { RollOffMinDistance = 12, RollOffMaxDistance = 70 })
local recordEq = Instance.new("EqualizerSoundEffect")
recordEq.LowGain = -14
recordEq.MidGain = 2
recordEq.HighGain = -10
recordEq.Parent = record
local wind = makeSound(gramophone:WaitForChild("Base"), WIND_ID, 0.4)
local windPrompt = gramophone:WaitForChild("Swing"):FindFirstChildOfClass("ProximityPrompt")
	or makePrompt(gramophone.Swing, "Wind", "Gramophone")
windPrompt.ObjectText = "Gramophone"

local function setRecord(on)
	gramophone:SetAttribute("Playing", on)
	windPrompt.ActionText = on and "Stop record" or "Wind"
	if on then
		record.TimePosition = 0
		record.Volume = RECORD_VOLUME
		record:Play()
	else
		record:Stop()
	end
end
setRecord(false)

windPrompt.Triggered:Connect(function()
	if elevator:GetAttribute("Descending") then
		return
	end
	wind:Play()
	setRecord(not gramophone:GetAttribute("Playing"))
end)
record.Ended:Connect(function()
	setRecord(false)
end)
elevator:GetAttributeChangedSignal("Descending"):Connect(function()
	if elevator:GetAttribute("Descending") then
		setRecord(false)
	end
end)

-- ================= FLOOR LAMPS =================
for _, side in { "L", "R" } do
	local shade = lights:FindFirstChild("FloorLampShade" .. side)
	local bulb = lights:FindFirstChild("FloorLampBulb" .. side)
	local light = bulb and bulb:FindFirstChildWhichIsA("Light")
	if shade and bulb and light then
		local chain = makeSound(shade, CHAIN_ID, 0.5)
		local onColor, onMaterial = bulb.Color, bulb.Material
		local shadeColor = shade.Color
		local prompt = makePrompt(shade, "Switch off", "Lamp", 7)
		prompt.Triggered:Connect(function()
			local on = not light.Enabled
			light.Enabled = on
			bulb.Material = on and onMaterial or Enum.Material.SmoothPlastic
			bulb.Color = on and onColor or Color3.fromRGB(70, 60, 48)
			shade.Color = on and shadeColor or shadeColor:Lerp(Color3.new(), 0.45)
			prompt.ActionText = on and "Switch off" or "Switch on"
			playOnce(chain)
		end)
	end
end

-- ================= GRANDFATHER CLOCK =================
local clock = decor:FindFirstChild("GrandfatherClock")
local clockPart = clock and clock:FindFirstChildWhichIsA("BasePart", true)
if clockPart then
	local chime = makeSound(clockPart, CHIME_ID, 0.45)
	local chiming = false
	makePrompt(clockPart, "Chime", "Grandfather Clock", 7).Triggered:Connect(function()
		if chiming then
			return
		end
		chiming = true
		chime.TimePosition = 0
		chime:Play()
		task.wait(CHIME_LENGTH)
		chime:Stop()
		chiming = false
	end)
end

-- ================= ARMCHAIRS =================
-- An invisible seat on each chair, taken with a prompt rather than by bumping into it.
for _, chair in decor:GetChildren() do
	if chair:IsA("Model") and chair.Name:match("^Armchair") then
		local cf, size = chair:GetBoundingBox()
		local mesh = chair:FindFirstChildWhichIsA("BasePart", true)
		local look = mesh and mesh.CFrame.LookVector or cf.LookVector
		look = Vector3.new(look.X, 0, look.Z).Unit
		local seatPos = cf.Position - Vector3.new(0, size.Y / 2, 0) + Vector3.new(0, 1.9, 0) - look * 0.15
		local seat = Instance.new("Seat")
		seat.Name = "Seat"
		seat.Anchored = true
		seat.CanCollide = false
		seat.CanTouch = false
		seat.Transparency = 1
		seat.Size = Vector3.new(1.8, 0.2, 1.8)
		seat.CFrame = CFrame.lookAt(seatPos, seatPos + look)
		seat:SetAttribute("ArmchairSeat", true)
		seat.Parent = chair
		local prompt = makePrompt(seat, "Sit", "Armchair", 6)
		prompt.Triggered:Connect(function(player)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and not seat.Occupant then
				seat:Sit(humanoid)
			end
		end)
		-- Prompts are hidden while seated, so the client shows its own stand hint.
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			prompt.Enabled = not seat.Occupant
		end)
	end
end
