-- Material-aware footsteps for every character, not just ours, since the
-- default "Running" sound is silenced on all of them.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local SOUNDS = {
	Concrete = {
		"rbxassetid://104345504554799",
		"rbxassetid://70639393862430",
		"rbxassetid://108290664490396",
		"rbxassetid://96955798612091",
		"rbxassetid://120195545352847",
		"rbxassetid://78982375383648",
		"rbxassetid://112000835797556",
		"rbxassetid://106961831442199",
	},
	Wood = {
		"rbxassetid://136507037003210",
		"rbxassetid://86757586209661",
		"rbxassetid://102979601052590",
		"rbxassetid://135290502484224",
		"rbxassetid://137526436035209",
	},
	Tile = {
		"rbxassetid://112733259097591",
		"rbxassetid://118048499719068",
		"rbxassetid://85601232131360",
		"rbxassetid://126965755395879",
		"rbxassetid://133063162472741",
		"rbxassetid://72966441854333",
		"rbxassetid://139267724392327",
		"rbxassetid://107732044493047",
	},
	Metal = {
		"rbxassetid://114246762368685",
		"rbxassetid://132729689652587",
		"rbxassetid://113703432248314",
	},
	Carpet = {
		"rbxassetid://91882016473062",
		"rbxassetid://111131620367547",
		"rbxassetid://73343053773763",
		"rbxassetid://123224557798023",
		"rbxassetid://92103616531947",
		"rbxassetid://73871404556766",
		"rbxassetid://77619756895899",
		"rbxassetid://131412978408311",
		"rbxassetid://83766009140419",
		"rbxassetid://114768473003662",
	},
	Grass = {
		"rbxassetid://73076319380473",
		"rbxassetid://115438917666178",
		"rbxassetid://92061301674605",
		"rbxassetid://92614595247225",
	},
}

-- Anything unlisted (Plastic placeholders included) falls back to Concrete.
local DEFAULT_GROUP = "Concrete"

-- By name so newer materials that an older client lacks don't error.
local MATERIAL_GROUPS = {
	Concrete = { "Concrete", "Slate", "Brick", "Cobblestone", "Pavement", "Asphalt", "Rock", "Basalt", "Limestone", "Sandstone", "Plaster" },
	Wood = { "Wood", "WoodPlanks", "Cardboard" },
	Tile = { "Marble", "Granite", "Glass", "CeramicTiles", "Ice", "Glacier" },
	Metal = { "Metal", "DiamondPlate", "CorrodedMetal", "Foil" },
	Carpet = { "Fabric", "Carpet", "Leather", "Rubber" },
	Grass = { "Grass", "LeafyGrass", "Ground", "Mud", "Sand", "Snow" },
}

local WALK_SPEED = 10.2
local MIN_SPEED = 1.5
-- Longer strides at higher speed keep sprint steps from turning into a drumroll.
local STRIDE_BASE = 3.2
local STRIDE_PER_SPEED = 0.16
-- Distance before the first step after stopping. Not zero, or tiny nudges
-- and physics jitter each fire a step.
local FIRST_STEP_DISTANCE = 2.5
local BASE_VOLUME = 0.3
local PITCH_JITTER = 0.08
local ROLLOFF_MIN = 6
local ROLLOFF_MAX = 60

local groupForMaterial = {}
for group, names in pairs(MATERIAL_GROUPS) do
	for _, name in ipairs(names) do
		local ok, material = pcall(function()
			return Enum.Material[name]
		end)
		if ok and material then
			groupForMaterial[material] = group
		end
	end
end

task.spawn(function()
	local preload = {}
	for _, ids in pairs(SOUNDS) do
		for _, id in ipairs(ids) do
			local s = Instance.new("Sound")
			s.SoundId = id
			table.insert(preload, s)
		end
	end
	ContentProvider:PreloadAsync(preload)
end)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local tracked = {}

local function floorGroup(character, root, humanoid)
	rayParams.FilterDescendantsInstances = { character }
	local reach = humanoid.HipHeight + root.Size.Y / 2 + 1.5
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), rayParams)
	if not hit then
		return nil
	end
	return groupForMaterial[hit.Material] or DEFAULT_GROUP
end

local function playStep(state, root, group, speed)
	local ids = SOUNDS[group]
	local index = math.random(1, #ids)
	-- Same sample twice in a row is the most noticeable tell of a footstep loop.
	if #ids > 1 and index == state.lastIndex then
		index = index % #ids + 1
	end
	state.lastIndex = index

	local s = Instance.new("Sound")
	s.SoundId = ids[index]
	s.Volume = BASE_VOLUME * math.clamp(speed / WALK_SPEED, 0.35, 1.15)
	s.PlaybackSpeed = 1 + (math.random() * 2 - 1) * PITCH_JITTER
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = ROLLOFF_MIN
	s.RollOffMaxDistance = ROLLOFF_MAX
	s.Parent = root
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
end

-- With SoundService.CharacterSoundsUseNewApi the engine plays this sound
-- itself, so an RbxCharacterSounds override can't stop it; pin it silent.
local function silence(sound)
	sound.Volume = 0
	sound:GetPropertyChangedSignal("Volume"):Connect(function()
		if sound.Volume ~= 0 then
			sound.Volume = 0
		end
	end)
end

local function silenceDefaultSteps(character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local running = root:FindFirstChild("Running")
	if running and running:IsA("Sound") then
		silence(running)
	end
	root.ChildAdded:Connect(function(child)
		if child.Name == "Running" and child:IsA("Sound") then
			silence(child)
		end
	end)
end

local function track(character)
	task.spawn(silenceDefaultSteps, character)
	tracked[character] = { distance = 0, lastIndex = 0, primed = true }
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			tracked[character] = nil
		end
	end)
end

local function watchPlayer(p)
	p.CharacterAdded:Connect(track)
	if p.Character then
		track(p.Character)
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)

RunService.Heartbeat:Connect(function(dt)
	for character, state in pairs(tracked) do
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or humanoid.Health <= 0 then
			continue
		end

		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		if speed < MIN_SPEED then
			state.primed = true
			continue
		end

		state.distance += speed * dt
		local stride = STRIDE_BASE + speed * STRIDE_PER_SPEED
		if state.primed then
			state.primed = false
			-- Bring the first step forward so starting to walk is heard promptly.
			state.distance = math.max(state.distance, stride - FIRST_STEP_DISTANCE)
		end
		if state.distance >= stride then
			local group = floorGroup(character, root, humanoid)
			if group then
				state.distance = 0
				playStep(state, root, group, speed)
			end
		end
	end
end)
