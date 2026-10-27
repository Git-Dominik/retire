-- Employee room interactions: staff doors, storage door, lockers, fridge, light
-- switch, coffee machine and microwave. Everything runs on the server so every
-- player sees the same door positions and light state.
--
-- Movable pieces are Models tagged with Hinge (CFrame), OpenAngle (degrees) and
-- SwingTime, so this script never has to know where the room ended up. A pair of
-- double doors points at each other through the Partner attribute.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DOOR_SOUND = "rbxassetid://9120839581"
local DING_ID = "rbxassetid://18192219147"
local HUM_ID = "rbxassetid://9112797280"

local store = workspace:WaitForChild("Grocery Store")
local area = store:WaitForChild("Employee Area")
local breakRoom = area:WaitForChild("Break Room")

local LIGHT_ON = Color3.fromRGB(255, 196, 120)
local LIGHT_OFF = Color3.fromRGB(52, 55, 57)

-- ================= SOUND =================
local function makeSound(parent, name, soundId, volume, speed)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = soundId
	s.Volume = volume
	s.PlaybackSpeed = speed or 1
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 45
	s.Parent = parent
	return s
end

-- ================= SWINGING GROUPS =================
local groups = {}

for _, model in ipairs(area:GetDescendants()) do
	if model:IsA("Model") and model:GetAttribute("Hinge") then
		groups[model.Name] = {
			model = model,
			hinge = model:GetAttribute("Hinge"),
			angle = model:GetAttribute("OpenAngle"),
			time = model:GetAttribute("SwingTime") or 0.7,
			pivot = model:GetPivot(),
			open = false,
			busy = false,
			sound = makeSound(model.PrimaryPart, "Swing", DOOR_SOUND, 0.4, 1.05),
		}
	end
end

local function partnerOf(group)
	local name = group.model:GetAttribute("Partner")
	return name and groups[name]
end

local function eased(t)
	return t < 0.5 and 2 * t * t or 1 - ((-2 * t + 2) ^ 2) / 2
end

local function setOpen(group, open, silent)
	if group.busy or group.open == open then
		return
	end
	group.busy = true

	if not silent then
		group.sound:Play()
	end

	local from = group.open and 1 or 0
	local to = open and 1 or 0
	local start = os.clock()

	while true do
		local t = math.clamp((os.clock() - start) / group.time, 0, 1)
		local amount = from + (to - from) * eased(t)
		group.model:PivotTo(
			group.hinge * CFrame.Angles(0, math.rad(group.angle * amount), 0) * group.hinge:Inverse() * group.pivot
		)
		if t >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end

	group.open = open
	group.busy = false

	local prompt = group.model.PrimaryPart:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.ActionText = open and "Close" or "Open"
	end
end

local function toggle(group)
	if not group or group.busy then
		return
	end

	local target = not group.open
	local partner = partnerOf(group)
	if partner then
		task.spawn(setOpen, partner, target)
	end
	setOpen(group, target)

	local autoClose = group.model:GetAttribute("AutoClose")
	if autoClose and target then
		task.delay(autoClose, function()
			if group.open and not group.busy then
				setOpen(group, false)
			end
		end)
	end
end

for _, group in pairs(groups) do
	local prompt = group.model.PrimaryPart:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function()
			toggle(group)
		end)
	end
end

-- ================= LIGHTS =================
local panels = {}
for _, d in ipairs(area:GetDescendants()) do
	if d.Name == "Light Panel" then
		table.insert(panels, d)
		if not d:FindFirstChildWhichIsA("PointLight") then
			local l = Instance.new("PointLight")
			l.Range = 18
			l.Brightness = 1.4
			l.Color = LIGHT_ON
			l.Shadows = true
			l.Parent = d
		end
	end
end

local lightsOn = true
local switch = area:FindFirstChild("Light Switch Toggle")

local function setLights(on)
	lightsOn = on
	for _, panel in ipairs(panels) do
		panel.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
		panel.Color = on and LIGHT_ON or LIGHT_OFF
		panel.Transparency = on and 0.15 or 0
		local l = panel:FindFirstChildWhichIsA("PointLight")
		if l then
			l.Enabled = on
		end
	end
	if switch then
		TweenService:Create(switch, TweenInfo.new(0.15), {
			Color = on and Color3.fromRGB(240, 196, 40) or Color3.fromRGB(60, 64, 66),
		}):Play()
	end
end

if switch then
	local click = makeSound(switch, "Click", DING_ID, 0.12, 2.4)
	click.RollOffMaxDistance = 18
	local prompt = switch:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function()
			setLights(not lightsOn)
			click:Play()
		end)
	end
end

-- ================= KITCHEN =================
local coffeeMaker = breakRoom:FindFirstChild("Coffee Maker")
local pot = breakRoom:FindFirstChild("Coffee Pot")
local microwave = breakRoom:FindFirstChild("Microwave")

if coffeeMaker and pot then
	local brew = makeSound(coffeeMaker, "Brew", HUM_ID, 0.35, 1.35)
	local emptyColor = pot.Color
	local brewing = false

	local prompt = coffeeMaker:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function()
			if brewing then
				return
			end
			brewing = true
			brew:Play()
			TweenService:Create(pot, TweenInfo.new(1.6, Enum.EasingStyle.Quad), {
				Color = Color3.fromRGB(78, 48, 28),
				Transparency = 0.15,
			}):Play()
			task.wait(3)
			local ding = makeSound(coffeeMaker, "Ding", DING_ID, 0.4, 1.6)
			ding:Play()
			task.delay(2, function()
				ding:Destroy()
			end)
			task.wait(40)
			TweenService:Create(pot, TweenInfo.new(1.2), {
				Color = emptyColor,
				Transparency = 0,
			}):Play()
			brewing = false
		end)
	end
end

if microwave then
	local light = Instance.new("PointLight")
	light.Range = 7
	light.Brightness = 2.2
	light.Color = Color3.fromRGB(255, 236, 200)
	light.Enabled = false
	light.Parent = microwave

	local hum = makeSound(microwave, "Hum", HUM_ID, 0.3, 1.9)
	hum.RollOffMaxDistance = 25
	local heating = false

	local prompt = microwave:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function()
			if heating then
				return
			end
			heating = true
			light.Enabled = true
			hum:Play()
			task.wait(3.2)
			hum:Stop()
			light.Enabled = false
			local ding = makeSound(microwave, "Ding", DING_ID, 0.5, 1.6)
			ding:Play()
			task.delay(2, function()
				ding:Destroy()
			end)
			heating = false
		end)
	end
end

print(string.format("[EmployeeRoom] ready: %d light panels", #panels))
