-- Floor 1's challenge, run on the library hall that Levels builds.
--
-- The item is in the back room behind a door locked from the inside. The way in
-- is the vent near the far end: pull the grate and crawl through the duct, then
-- unlock the door from inside to walk back out.
--
-- The hall belongs to the Librarian. Running makes noise: books slip off the
-- shelves and the lamps stutter as a warning, and if it keeps up the lamps die
-- and a tall shadow drifts down the hall. Anyone moving faster than a careful
-- crouch-walk while it's out gets rushed. Stand still or sneak until it fades.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Library = {}

local SOUNDS = {
	rattle = "rbxassetid://9118901593", -- Security Gate 4 (Pro Sound Effects)
	unlock = "rbxassetid://9114155536", -- Door Squeaky 2 (Pro Sound Effects)
	vent = "rbxassetid://9116749199", -- Metal Pipe Movement Heavy Hollow Pipe 4
	grate = "rbxassetid://9116540638", -- Metal Clang 13
	book = "rbxassetid://113430293583481",
	flicker = "rbxassetid://116266785932124",
	whisper = "rbxassetid://85064677546638",
}

-- Noise: rises while anyone in the hall runs, drains otherwise.
local RUN_SPEED = 13
local NOISE_GAIN = 30
local NOISE_DRAIN = 12
local WARN_AT = 45
local HUNT_AT = 100
local HUNT_COOLDOWN = 25

-- The Librarian.
local WARNING_TIME = 1.6 -- lamps flicker before it appears
local HUNT_TIME = 9
local DRIFT_SPEED = 5
local RUSH_SPEED = 32
-- Walking is 10.2 and crouching 5.6 (Camera.client); anything above this is heard.
local HEARD_SPEED = 7.5
-- How long a rushed player has to hold still before it loses them.
local LOSE_TIME = 0.8
local KILL_RANGE = 4

local CRAWL_SPEED = 4.5

local remotes = ReplicatedStorage:FindFirstChild("FloorEvents")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "FloorEvents"
	for _, name in { "Hint", "Jumpscare" } do
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	remotes.Parent = ReplicatedStorage
end

local function hint(player, text)
	remotes.Hint:FireClient(player, text)
end

local function sound(parent, id, volume, props)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 80
	for k, v in props or {} do
		s[k] = v
	end
	s.Parent = parent
	return s
end

local function prompt(parent, action, object, hold)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 7
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil
end

-- A tall, thin shadow with pale eyes, trailing smoke instead of legs.
local function makeLibrarian()
	local model = Instance.new("Model")
	model.Name = "Librarian"
	local black = Color3.fromRGB(8, 6, 6)
	local function piece(name, size, offset, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.Color = color or black
		p.Material = material or Enum.Material.SmoothPlastic
		p:SetAttribute("Offset", offset)
		p.Parent = model
		return p
	end
	local torso = piece("Torso", Vector3.new(1.5, 6, 0.9), CFrame.new(0, 6, 0))
	local head = piece("Head", Vector3.new(1.4, 1.7, 1.4), CFrame.new(0, 9.9, -0.2))
	head.Shape = Enum.PartType.Ball
	for _, side in { -1, 1 } do
		-- Arms hang long and slightly forward, past where knees would be.
		piece("Arm", Vector3.new(0.3, 6.5, 0.3), CFrame.new(side * 1, 5.4, -0.3) * CFrame.Angles(math.rad(-8), 0, side * math.rad(6)))
		local eye = piece("Eye", Vector3.new(0.22, 0.12, 0.08), CFrame.new(side * 0.3, 10.05, -0.86), Color3.fromRGB(255, 236, 200), Enum.Material.Neon)
		eye.CastShadow = false
	end
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.fromRGB(10, 8, 8))
	smoke.LightInfluence = 0
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 3.4) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(0.8, 1.4)
	smoke.Rate = 40
	smoke.Speed = NumberRange.new(0.5, 1.5)
	smoke.SpreadAngle = Vector2.new(30, 30)
	smoke.Acceleration = Vector3.new(0, -2, 0)
	smoke.EmissionDirection = Enum.NormalId.Bottom
	smoke.Parent = torso
	model.PrimaryPart = torso
	return model
end

local function placeLibrarian(model, cf)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			p.CFrame = cf * p:GetAttribute("Offset")
		end
	end
end

function Library.start(room, info)
	local base, W, D = info.base, info.hallWidth, info.hallDepth
	local alive = true
	local connections = {}

	local function inHall(position)
		local p = base:PointToObjectSpace(position)
		return math.abs(p.X) < W / 2 and p.Z > 0 and p.Z < D and p.Y > -2 and p.Y < 12
	end

	-- ================= NOTE =================
	local notePrompt = prompt(info.note, "Read", "Note")
	table.insert(connections, notePrompt.Triggered:Connect(function(player)
		hint(player, "“Silence is kept in this hall. Do not run. If the lamps go out, do not move.”")
	end))

	-- ================= DOOR =================
	local door = info.door
	local knob = door:FindFirstChild("Knob")
	if knob then
		knob.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = door, knob
		weld.Parent = knob
	end
	local rattle = sound(door, SOUNDS.rattle, 0.5)
	local creak = sound(door, SOUNDS.unlock, 0.6)
	local doorPrompt = prompt(door, "Open", "Door")
	table.insert(connections, doorPrompt.Triggered:Connect(function(player)
		local root = rootOf(player)
		if not root then
			return
		end
		if base:PointToObjectSpace(root.Position).Z < D then
			rattle:Play()
			hint(player, "Locked. Something is wedged against it from the other side.")
			return
		end
		-- From inside: unlock and swing it open into the back room.
		doorPrompt.Enabled = false
		creak:Play()
		local openCf = info.doorHinge * CFrame.Angles(0, math.rad(-95), 0) * info.doorHinge:Inverse() * door.CFrame
		TweenService:Create(door, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = openCf }):Play()
	end))

	-- ================= VENT =================
	local grate = info.grate
	local clang = sound(grate, SOUNDS.grate, 0.5)
	local ventPrompt = prompt(grate, "Crawl in", "Vent", 0.6)
	local grateOff = false
	local crawling = {}

	local function crawl(player)
		local root, humanoid = rootOf(player)
		if not root or crawling[player] then
			return
		end
		crawling[player] = true
		root.Anchored = true
		humanoid:UnequipTools()
		local head = player.Character:FindFirstChild("Head")
		-- A faint light so the duct isn't pitch black, and the scrape of metal.
		local glow = Instance.new("PointLight")
		glow.Range = 7
		glow.Brightness = 0.5
		glow.Color = Color3.fromRGB(255, 200, 150)
		glow.Shadows = false
		glow.Parent = head
		local scrape = sound(root, SOUNDS.vent, 0.35, { Looped = true })
		scrape:Play()

		local path = info.ventPath
		local from = path[1]
		root.CFrame = CFrame.lookAt(from, path[2])
		for i = 2, #path do
			if not alive or not root.Parent then
				break
			end
			local to = path[i]
			local look = (i < #path) and path[i + 1] or to + (to - from)
			-- Face along this stretch (Camera.client turns the view), then shuffle along it.
			player:SetAttribute("ForcedLook", (to - from).Unit)
			local stretch = TweenService:Create(root, TweenInfo.new((to - from).Magnitude / CRAWL_SPEED, Enum.EasingStyle.Linear), {
				CFrame = CFrame.lookAt(to, to + (to - from).Unit),
			})
			stretch:Play()
			stretch.Completed:Wait()
			if i < #path then
				player:SetAttribute("ForcedLook", (look - to).Unit)
				local turn = TweenService:Create(root, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { CFrame = CFrame.lookAt(to, look) })
				turn:Play()
				turn.Completed:Wait()
			end
			from = to
		end

		scrape:Destroy()
		glow:Destroy()
		player:SetAttribute("ForcedLook", nil)
		if root.Parent then
			root.CFrame = CFrame.new(info.ventExit) * (root.CFrame - root.CFrame.Position)
			root.Anchored = false
		end
		crawling[player] = nil
	end

	table.insert(connections, ventPrompt.Triggered:Connect(function(player)
		if not grateOff then
			grateOff = true
			clang:Play()
			-- The grate comes away and drops on the floor in front of the vent.
			local fallen = base * CFrame.new(-W / 2 + 1.4, 0.08, base:PointToObjectSpace(grate.Position).Z + 0.6) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(0.2, 0, 0)
			TweenService:Create(grate, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = fallen }):Play()
			for _, slat in grate:GetChildren() do
				if slat:IsA("BasePart") then
					local offset = grate.CFrame:ToObjectSpace(slat.CFrame)
					TweenService:Create(slat, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = fallen * offset }):Play()
				end
			end
			task.wait(0.4)
		end
		crawl(player)
	end))

	-- ================= LAMPS AND BOOKS =================
	local lamps = {}
	local books = {}
	for _, d in room:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "SconceBulb" then
			local light = d:FindFirstChildOfClass("PointLight")
			table.insert(lamps, { bulb = d, light = light, color = d.Color })
		elseif d:IsA("BasePart") and d.Name == "Book" then
			table.insert(books, d)
		end
	end
	local flickerSound = sound(room:FindFirstChild("Runner") or room.PrimaryPart or room:FindFirstChildWhichIsA("BasePart"), SOUNDS.flicker, 0.4, { RollOffMaxDistance = 120 })

	local function setLamps(on, level)
		for _, lamp in lamps do
			lamp.bulb.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			lamp.bulb.Color = on and lamp.color or Color3.fromRGB(40, 32, 26)
			if lamp.light then
				lamp.light.Enabled = on
				lamp.light.Brightness = 0.8 * (level or 1)
			end
		end
	end

	local function flicker(duration)
		flickerSound:Play()
		local t0 = os.clock()
		while alive and os.clock() - t0 < duration do
			setLamps(math.random() > 0.45, math.random() * 0.6 + 0.4)
			task.wait(math.random() * 0.12 + 0.04)
		end
		setLamps(true)
	end

	local function dropBook()
		local book = table.remove(books, math.random(#books))
		if not book or not book.Parent then
			return
		end
		book.Anchored = false
		-- Shelves face -x in hall space; nudge it out over the edge.
		book.AssemblyLinearVelocity = base:VectorToWorldSpace(Vector3.new(-5, 2, 0))
		book.AssemblyAngularVelocity = Vector3.new(math.random() * 4, 0, math.random() * 4)
		local thud = sound(book, SOUNDS.book, 0.7)
		task.delay(0.35, function()
			if thud.Parent then
				thud:Play()
			end
		end)
	end

	-- ================= THE LIBRARIAN =================
	local noise = 0
	local warned = false
	local hunting = false
	local lastHunt = -math.huge

	local function hunt()
		hunting = true
		local librarian = makeLibrarian()
		local whisper = sound(librarian.PrimaryPart, SOUNDS.whisper, 0.9, { Looped = true, RollOffMaxDistance = 90 })

		flicker(WARNING_TIME)
		if not alive then
			librarian:Destroy()
			return
		end
		setLamps(false)

		local position = info.librarianStart
		local facing = (info.librarianEnd - info.librarianStart).Unit
		placeLibrarian(librarian, CFrame.lookAt(position, position + facing))
		librarian.Parent = room
		whisper:Play()

		local target, stillFor = nil, 0
		local t0 = os.clock()
		local last = os.clock()
		while alive and os.clock() - t0 < HUNT_TIME do
			RunService.Heartbeat:Wait()
			local now = os.clock()
			local dt = now - last
			last = now

			-- Listen for anyone moving too fast in the hall.
			if not target then
				for _, player in Players:GetPlayers() do
					local root = rootOf(player)
					if root and not crawling[player] and inHall(root.Position) then
						local v = root.AssemblyLinearVelocity
						if Vector2.new(v.X, v.Z).Magnitude > HEARD_SPEED then
							target, stillFor = player, 0
							break
						end
					end
				end
			end

			local goal, speed
			local targetRoot = target and rootOf(target)
			if targetRoot and inHall(targetRoot.Position) and not crawling[target] then
				local v = targetRoot.AssemblyLinearVelocity
				stillFor = Vector2.new(v.X, v.Z).Magnitude < 2 and stillFor + dt or 0
				if stillFor > LOSE_TIME then
					target = nil
				else
					goal, speed = targetRoot.Position, RUSH_SPEED
				end
			else
				target = nil
			end
			if not goal then
				goal, speed = info.librarianEnd, DRIFT_SPEED
			end

			local flat = Vector3.new(goal.X, position.Y, goal.Z) - position
			if flat.Magnitude > 0.1 then
				facing = facing:Lerp(flat.Unit, math.min(dt * 8, 1)).Unit
				position += flat.Unit * math.min(speed * dt, flat.Magnitude)
			end
			placeLibrarian(librarian, CFrame.lookAt(position, position + facing))

			if targetRoot and target and (Vector3.new(targetRoot.Position.X, position.Y, targetRoot.Position.Z) - position).Magnitude < KILL_RANGE then
				remotes.Jumpscare:FireClient(target)
				local _, humanoid = rootOf(target)
				if humanoid then
					humanoid.Health = 0
				end
				break
			end
		end

		-- Fade out, lamps come back.
		whisper:Destroy()
		for _, p in librarian:GetChildren() do
			if p:IsA("BasePart") then
				TweenService:Create(p, TweenInfo.new(0.8), { Transparency = 1 }):Play()
				local smoke = p:FindFirstChildOfClass("ParticleEmitter")
				if smoke then
					smoke.Enabled = false
				end
			end
		end
		task.wait(0.9)
		librarian:Destroy()
		if alive then
			setLamps(true)
		end
		noise, warned = 0, false
		lastHunt = os.clock()
		hunting = false
	end

	-- Lets the dev menu summon it on demand.
	Library.summon = function()
		if not hunting then
			task.spawn(hunt)
		end
	end

	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		if hunting then
			return
		end
		local running = false
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if root and not crawling[player] and inHall(root.Position) then
				local v = root.AssemblyLinearVelocity
				if Vector2.new(v.X, v.Z).Magnitude > RUN_SPEED then
					running = true
				end
			end
		end
		noise = math.clamp(noise + (running and NOISE_GAIN or -NOISE_DRAIN) * dt, 0, HUNT_AT)
		if noise >= WARN_AT and not warned then
			warned = true
			task.spawn(dropBook)
			task.spawn(flicker, 0.6)
		elseif noise < WARN_AT * 0.5 then
			warned = false
		end
		if noise >= HUNT_AT and os.clock() - lastHunt > HUNT_COOLDOWN then
			task.spawn(hunt)
		end
	end))

	room.Destroying:Connect(function()
		alive = false
		Library.summon = nil
		for _, c in connections do
			c:Disconnect()
		end
		-- Anyone mid-crawl when the floor goes away is let go.
		for player in crawling do
			local root = rootOf(player)
			if root then
				root.Anchored = false
			end
		end
	end)
end

return Library
