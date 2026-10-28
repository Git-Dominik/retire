-- Brings floor 2's wall shopkeeper to life: a cluster of mismatched glowing eyes in the dark
-- and the tentacles around them. When the local player comes within ShowRadius the eyes
-- open one after another, then each blinks and glances about on its own (mostly at the
-- player, whose closeness shrinks the pupils), and they close again past HideRadius. As
-- the shop opens, tentacles come out of the edges of the hole, wrap around the frame onto
-- the wall, and sweep their tips from side to side; they draw back as it shuts.
-- Around that: dark mist and dust seep out along the floor (with a puff of dust as it
-- opens) and motes drift in the void, the room's colour sinks as the player gets close,
-- and a muffled ambience bed and a looping swell rise from the dark with breathing now and
-- then.
-- Client-side and local: each player sees and hears the shopkeeper react to themselves.
-- Everything lives in ServerStorage.WallShop (place-only), which Levels clones into the
-- floor 2 room on every visit:
--   Eyes (tag ShopEyes): a Root part (the cluster's rest point, carrying the Glow
--     PointLight, ShownBrightness attribute) and Eye1..EyeN models (Size attribute), each
--     with Sclera, Iris, Pupil and Halo parts using sphere SpecialMeshes. Parts are saved
--     hidden; ShownTransparency is what they fade to, Look marks the iris and pupil that
--     glance, Pupil marks the pupil.
--   Tentacles: tentacle rig Models tagged ShopTentacles (Left, Right, Top), their knots
--     hidden behind the wall. Shared.TentacleRig poses them; its header lists the
--     per-chain attributes.
--   Effects (tag ShopEffects): Mist, Dust and Motes parts holding ParticleEmitters, saved
--     off. An emitter's Burst attribute is how many particles it puffs out as the shop opens.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TentacleRig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TentacleRig"))

local CONFIG = {
	EyesTag = "ShopEyes",
	TentacleTag = "ShopTentacles",
	EffectsTag = "ShopEffects",
	-- Studs from the eyes; a gap between the two so they don't flicker at the edge.
	ShowRadius = 22,
	HideRadius = 26,
	-- Exponential smoothing rates (1/s).
	FadeRate = 4,
	FollowRate = 3,
	GlanceRate = 12,
	-- Each eye opens this long after the one before it, plus a little jitter.
	OpenStagger = 0.12,
	OpenJitter = 0.15,
	-- The cluster leans a little after the player and turns partway to face them.
	DriftPerStud = 0.05,
	MaxDrift = Vector3.new(0.8, 0.4, 0.3),
	TurnAmount = 0.25,
	BobHeight = 0.06,
	BobSpeed = 0.9,
	BlinkTime = 0.15,
	BlinkGap = NumberRange.new(2, 7),
	-- Glances: how long each lasts, the chance it's at the player, and how far the iris
	-- and pupil can slide across the eye (share of the eye's size).
	GlanceHold = NumberRange.new(0.6, 2.6),
	GlanceAtPlayer = 0.65,
	GlanceShift = 0.2,
	-- Pupil size (share of saved) with the player at PupilNear studs or closer, and at PupilFar.
	PupilClose = 0.7,
	PupilWide = 1.15,
	PupilNear = 6,
	PupilFar = 20,
	-- The glow breathes: brightness swings by this share at this rate (rad/s).
	GlowPulse = 0.2,
	GlowPulseSpeed = 1.1,
	-- The room's colour sinks as the player comes in from ShowRadius to DreadNear studs.
	DreadNear = 8,
	DreadSaturation = -0.25,
	DreadContrast = 0.1,
	DreadBrightness = -0.04,
	DreadTint = Color3.fromRGB(205, 215, 255),
	Sounds = {
		-- "Electric Forest Airy Washy Shrieky 4" (Pro Sound Effects), slowed into a low drone.
		Ambience = { id = "rbxassetid://9114244977", volume = 0.35, speed = 0.6 },
		-- "AIR SWELL TUNNEL 03" (Epic Score, Horror Tools), looped while the shop is open and
		-- restarted from its swell each time the eyes open.
		Swell = { id = "rbxassetid://9043337370", volume = 0.45, speed = 1 },
		-- "Creature Mix Weird Deep Monster Breathing 1-3" (Pro Sound Effects).
		Breaths = { "rbxassetid://9113983944", "rbxassetid://9113984054", "rbxassetid://9113984056" },
		BreathVolume = 0.5,
		BreathGap = NumberRange.new(7, 14),
		-- The ambience bed and swell sound as if from deep inside the wall.
		Muffle = { LowGain = 2, MidGain = -12, HighGain = -35 },
		-- Rate (1/s) the looped sounds fade with the shop opening and shutting.
		FadeRate = 1.5,
	},
}

local player = Players.LocalPlayer
local rng = Random.new()

local eyesStates = {}
local tentacleStates = {}
local effectsStates = {}

local dread = Instance.new("ColorCorrectionEffect")
dread.Name = "ShopDread"
dread.Parent = Lighting
local dreadAmount = 0

local function sound(parent, spec, looped)
	local s = Instance.new("Sound")
	s.SoundId = spec.id
	s.Volume = spec.volume
	s.PlaybackSpeed = spec.speed or 1
	s.Looped = looped or false
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 45
	s.Parent = parent
	return s
end

-- A looped sound from inside the wall, through a low-pass so it sounds muffled.
local function muffledLoop(parent, spec)
	local s = sound(parent, spec, true)
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = CONFIG.Sounds.Muffle.LowGain
	eq.MidGain = CONFIG.Sounds.Muffle.MidGain
	eq.HighGain = CONFIG.Sounds.Muffle.HighGain
	eq.Parent = s
	s.Volume = 0
	return s
end

-- A one-shot from the shop, cleaned up when it's done.
local function playOnce(parent, spec, speed)
	local s = sound(parent, spec)
	s.PlaybackSpeed = speed or 1
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
end

local function setupEyes(cluster)
	local root = cluster:WaitForChild("Root", 10)
	if not root or eyesStates[cluster] then
		return
	end
	local rest = root.CFrame
	local eyes = {}
	for _, model in cluster:GetChildren() do
		local sclera = model:IsA("Model") and model:WaitForChild("Sclera", 10)
		if sclera then
			local center = rest:ToObjectSpace(sclera.CFrame)
			local parts = {}
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") then
					local mesh = p:FindFirstChildOfClass("SpecialMesh")
					table.insert(parts, {
						part = p,
						offset = sclera.CFrame:ToObjectSpace(p.CFrame),
						mesh = mesh,
						scale = mesh and mesh.Scale or Vector3.one,
						shown = p:GetAttribute("ShownTransparency") or 0,
						look = p:GetAttribute("Look") == true,
						pupil = p:GetAttribute("Pupil") == true,
					})
				end
			end
			table.insert(eyes, {
				center = center,
				size = model:GetAttribute("Size") or sclera.Size.X,
				parts = parts,
				visible = 0,
				-- Bigger eyes nearer the middle open first.
				order = center.Position.Magnitude,
				glance = Vector2.zero,
				glanceTarget = Vector2.zero,
				nextGlance = 0,
				nextBlink = os.clock() + rng:NextNumber(CONFIG.BlinkGap.Min, CONFIG.BlinkGap.Max),
			})
		end
	end
	table.sort(eyes, function(a, b)
		return a.order < b.order
	end)
	for i, eye in eyes do
		eye.delay = (i - 1) * CONFIG.OpenStagger + rng:NextNumber(0, CONFIG.OpenJitter)
	end
	local glow = root:FindFirstChildOfClass("PointLight")
	local ambience = muffledLoop(root, CONFIG.Sounds.Ambience)
	ambience:Play()
	local swell = muffledLoop(root, CONFIG.Sounds.Swell)
	eyesStates[cluster] = {
		root = root,
		rest = rest,
		eyes = eyes,
		glow = glow,
		shownBrightness = glow and glow:GetAttribute("ShownBrightness") or 2,
		ambience = ambience,
		swell = swell,
		loudness = 0,
		visible = 0,
		wanted = false,
		openedAt = 0,
		nextBreath = 0,
		pose = CFrame.identity,
	}
end

local function clamp3(v, limit)
	return Vector3.new(
		math.clamp(v.X, -limit.X, limit.X),
		math.clamp(v.Y, -limit.Y, limit.Y),
		math.clamp(v.Z, -limit.Z, limit.Z)
	)
end

local function blinkOf(eye, now)
	local since = now - eye.nextBlink
	if since < 0 then
		return 1
	elseif since < CONFIG.BlinkTime then
		return 1 - math.sin(math.pi * since / CONFIG.BlinkTime)
	end
	eye.nextBlink = now + rng:NextNumber(CONFIG.BlinkGap.Min, CONFIG.BlinkGap.Max)
	return 1
end

local function updateEyes(state, head, dt, now)
	local rel = head and state.rest:PointToObjectSpace(head.Position)
	local distance = rel and rel.Magnitude or math.huge
	local wasWanted = state.wanted
	if distance < CONFIG.ShowRadius then
		state.wanted = true
	elseif distance > CONFIG.HideRadius then
		state.wanted = false
	end
	if state.wanted and not wasWanted then
		state.openedAt = now
		state.nextBreath = now + rng:NextNumber(2, 4)
		-- Start the loop from its swell, unless it's still audible from a moment ago.
		if state.loudness < 0.05 then
			state.swell.TimePosition = 0
		end
		state.swell:Play()
	end
	local fade = 1 - math.exp(-CONFIG.FadeRate * dt)
	state.visible += ((state.wanted and 1 or 0) - state.visible) * fade

	-- The cluster leans after the player and turns a little to face them. The room is on
	-- the rest frame's front (-Z), so a player there has a negative Z.
	local target = CFrame.identity
	if rel and state.wanted then
		local drift = clamp3(rel * CONFIG.DriftPerStud, CONFIG.MaxDrift)
		local facing = CFrame.lookAt(Vector3.zero, rel).Rotation
		target = CFrame.new(drift) * CFrame.identity:Lerp(facing, CONFIG.TurnAmount)
	end
	state.pose = state.pose:Lerp(target, 1 - math.exp(-CONFIG.FollowRate * dt))
	local bob = CFrame.new(0, math.sin(now * CONFIG.BobSpeed) * CONFIG.BobHeight, 0)
	local frame = state.rest * bob * state.pose

	local near = math.clamp((distance - CONFIG.PupilNear) / (CONFIG.PupilFar - CONFIG.PupilNear), 0, 1)
	local pupilScale = CONFIG.PupilClose + (CONFIG.PupilWide - CONFIG.PupilClose) * near
	local glanceFade = 1 - math.exp(-CONFIG.GlanceRate * dt)

	for _, eye in state.eyes do
		local open = state.wanted and now - state.openedAt >= eye.delay
		eye.visible += ((open and 1 or 0) - eye.visible) * fade
		local eyeFrame = frame * eye.center

		-- Pick a new glance now and then: mostly at the player, sometimes anywhere.
		if now >= eye.nextGlance then
			eye.nextGlance = now + rng:NextNumber(CONFIG.GlanceHold.Min, CONFIG.GlanceHold.Max)
			if head and rng:NextNumber() < CONFIG.GlanceAtPlayer then
				local look = eyeFrame:PointToObjectSpace(head.Position)
				local flat = Vector2.new(look.X, look.Y) / math.max(1, -look.Z) * 2
				eye.glanceTarget = flat.Magnitude > 1 and flat.Unit or flat
			else
				local angle = rng:NextNumber(0, 2 * math.pi)
				eye.glanceTarget = Vector2.new(math.cos(angle), math.sin(angle)) * rng:NextNumber(0.3, 0.9)
			end
		end
		eye.glance = eye.glance:Lerp(eye.glanceTarget, glanceFade)
		local shift = eye.glance * CONFIG.GlanceShift * eye.size
		local slide = CFrame.new(shift.X, shift.Y, 0)

		local lid = math.max(0.04, math.min(1, eye.visible * 1.4) * blinkOf(eye, now))
		for _, entry in eye.parts do
			entry.part.CFrame = eyeFrame * (entry.look and slide or CFrame.identity) * entry.offset
			entry.part.Transparency = 1 + (entry.shown - 1) * eye.visible
			if entry.mesh then
				local width = entry.pupil and pupilScale or 1
				entry.mesh.Scale = entry.scale * Vector3.new(width, lid * (entry.pupil and pupilScale or 1), 1)
			end
		end
	end

	if state.glow then
		local pulse = 1 + CONFIG.GlowPulse * math.sin(now * CONFIG.GlowPulseSpeed)
		state.glow.Brightness = state.shownBrightness * state.visible * pulse
	end
	state.loudness += ((state.wanted and 1 or 0) - state.loudness) * (1 - math.exp(-CONFIG.Sounds.FadeRate * dt))
	state.ambience.Volume = CONFIG.Sounds.Ambience.volume * state.loudness
	state.swell.Volume = CONFIG.Sounds.Swell.volume * state.loudness
	if not state.wanted and state.loudness < 0.01 and state.swell.IsPlaying then
		state.swell:Stop()
	end
	if state.wanted and now >= state.nextBreath then
		state.nextBreath = now + rng:NextNumber(CONFIG.Sounds.BreathGap.Min, CONFIG.Sounds.BreathGap.Max)
		local breaths = CONFIG.Sounds.Breaths
		playOnce(state.root, {
			id = breaths[rng:NextInteger(1, #breaths)],
			volume = CONFIG.Sounds.BreathVolume,
		}, rng:NextNumber(0.75, 0.9))
	end
	-- How strongly this shop darkens the room for the player.
	local dreadTarget = state.visible
		* math.clamp((CONFIG.ShowRadius - distance) / (CONFIG.ShowRadius - CONFIG.DreadNear), 0, 1)
	return dreadTarget
end

-- Tentacles -> Tentacles folder -> the shop clone, whose pivot their paths are relative to.
local function setupTentacles(mass)
	if tentacleStates[mass] then
		return
	end
	local shop = mass.Parent and mass.Parent.Parent
	if not shop or not shop:IsA("Model") or not mass:WaitForChild("RootPart", 10) then
		return
	end
	tentacleStates[mass] = { shop = shop, rig = TentacleRig.setup(mass, shop:GetPivot()) }
end

-- The tentacles and effects answer to the eyes of their own shop: out while the eyes want
-- to be open. The rig paces the creeping itself, rather than following the eyes' fade.
local function shopEyes(shop)
	local eyes = shop:FindFirstChild("Eyes")
	return eyes and eyesStates[eyes]
end

local function setupEffects(fx)
	if effectsStates[fx] then
		return
	end
	local emitters = {}
	for _, d in fx:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			table.insert(emitters, d)
		end
	end
	effectsStates[fx] = { shop = fx.Parent, emitters = emitters, on = false }
end

local function watch(tag, setup, states)
	CollectionService:GetInstanceAddedSignal(tag):Connect(setup)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		states[instance] = nil
	end)
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(setup, instance)
	end
end
watch(CONFIG.EyesTag, setupEyes, eyesStates)
watch(CONFIG.TentacleTag, setupTentacles, tentacleStates)
watch(CONFIG.EffectsTag, setupEffects, effectsStates)

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local now = os.clock()
	local dreadTarget = 0
	for eyes, state in eyesStates do
		if not eyes:IsDescendantOf(workspace) then
			state.ambience:Destroy()
			state.swell:Destroy()
			eyesStates[eyes] = nil
		else
			dreadTarget = math.max(dreadTarget, updateEyes(state, head, dt, now))
		end
	end
	for mass, state in tentacleStates do
		if not mass:IsDescendantOf(workspace) then
			tentacleStates[mass] = nil
		elseif state.rig then
			local eyes = shopEyes(state.shop)
			TentacleRig.update(state.rig, eyes ~= nil and eyes.wanted, now, dt)
		end
	end
	for fx, state in effectsStates do
		if not fx:IsDescendantOf(workspace) then
			effectsStates[fx] = nil
		else
			local eyes = shopEyes(state.shop)
			local on = eyes ~= nil and eyes.wanted
			if on ~= state.on then
				state.on = on
				for _, emitter in state.emitters do
					emitter.Enabled = on
					local burst = emitter:GetAttribute("Burst")
					if on and burst then
						emitter:Emit(burst)
					end
				end
			end
		end
	end
	dreadAmount += (dreadTarget - dreadAmount) * (1 - math.exp(-2 * dt))
	dread.Saturation = CONFIG.DreadSaturation * dreadAmount
	dread.Contrast = CONFIG.DreadContrast * dreadAmount
	dread.Brightness = CONFIG.DreadBrightness * dreadAmount
	dread.TintColor = Color3.new(1, 1, 1):Lerp(CONFIG.DreadTint, dreadAmount)
end)
