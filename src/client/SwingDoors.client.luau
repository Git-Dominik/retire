-- Double-action swinging doors (the golden pair into the storage room). Nobody presses anything:
-- walking into the doorway pushes the leaves away from you, and they flap shut once it's clear.
-- Client-side and local. Every client sees every character, so each one works out the same swing
-- without a remote, and the motion stays smooth at the client's frame rate. The server never moves
-- the doors; their saved pose is the closed one.
-- A door is a Model tagged SwingDoor (place-only, built in Studio) with an OpenAngle attribute
-- (degrees). Its WorldPivot sits at the centre of the opening. Each child Model is a leaf whose
-- WorldPivot is on its hinge line; which way a leaf turns comes from which side of the hinge it
-- hangs. The leaves don't collide, so they never block or shove a character.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CONFIG = {
	Tag = "SwingDoor",
	-- How far either side of the doorway (in studs) a character starts pushing the leaves.
	Reach = 3.5,
	-- Extra width beyond the opening that still counts as walking through it.
	SideSlack = 1,
	-- Spring for the leaves: stiffness (rad/s) and damping ratio. Below 1 they swing a little past
	-- closed and settle, like a gravity hinge; low enough that it's a single small rebound.
	OpenFrequency = 9,
	CloseFrequency = 5.5,
	Damping = 0.55,
	-- Only pick a new push direction when the leaves are nearly shut, so someone in the doorway
	-- doesn't flip them through themselves.
	ReverseBelow = math.rad(12),
	SoundId = "rbxassetid://107461222732355",
	Volume = 0.35,
}

local doors = {}

local function newDoor(model)
	local door = {
		model = model,
		leaves = {},
		angle = 0,
		velocity = 0,
		side = 1,
		open = false,
	}
	local _, size = model:GetBoundingBox()
	door.halfWidth = size.X / 2
	for _, child in model:GetChildren() do
		if child:IsA("Model") then
			local pivot = child:GetPivot()
			local centre = pivot:PointToObjectSpace(child:GetBoundingBox().Position)
			table.insert(door.leaves, {
				model = child,
				pivot = pivot,
				-- +1 when the leaf hangs on the hinge's +X side.
				hang = centre.X >= 0 and 1 or -1,
			})
		end
	end
	local anchor = model:FindFirstChildWhichIsA("BasePart", true)
	if anchor and CONFIG.SoundId then
		local sound = Instance.new("Sound")
		sound.Name = "Swing"
		sound.SoundId = CONFIG.SoundId
		sound.Volume = CONFIG.Volume
		sound.RollOffMinDistance = 6
		sound.RollOffMaxDistance = 40
		sound.Parent = anchor
		door.sound = sound
	end
	return door
end

-- Local Z (in the door's frame) of the closest character standing in the doorway, or nil.
local function nearestPusher(door)
	local frame = door.model:GetPivot()
	local best, bestDistance
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local offset = frame:PointToObjectSpace(root.Position)
			if
				math.abs(offset.X) < door.halfWidth + CONFIG.SideSlack
				and math.abs(offset.Z) < CONFIG.Reach
				and math.abs(offset.Y) < 6
			then
				local distance = math.abs(offset.Z)
				if not bestDistance or distance < bestDistance then
					best, bestDistance = offset.Z, distance
				end
			end
		end
	end
	return best
end

local function step(door, dt)
	local openAngle = math.rad(door.model:GetAttribute("OpenAngle") or 85)
	local pusher = nearestPusher(door)
	if pusher and math.abs(door.angle) < CONFIG.ReverseBelow then
		door.side = pusher >= 0 and 1 or -1
	end
	if pusher and not door.open and door.sound then
		door.sound:Play()
	end
	door.open = pusher ~= nil

	-- Positive angle swings the leaves away from the +Z side.
	local target = door.open and openAngle * door.side or 0
	local omega = door.open and CONFIG.OpenFrequency or CONFIG.CloseFrequency
	local accel = omega * omega * (target - door.angle) - 2 * CONFIG.Damping * omega * door.velocity
	door.velocity += accel * dt
	door.angle += door.velocity * dt
	if not door.open and math.abs(door.angle) < 1e-3 and math.abs(door.velocity) < 1e-2 then
		door.angle, door.velocity = 0, 0
	end

	for _, leaf in door.leaves do
		-- Turning by +a about Y carries a leaf hanging on +X towards -Z, so flip for the other side.
		leaf.model:PivotTo(leaf.pivot * CFrame.Angles(0, door.angle * leaf.hang, 0))
	end
end

local function add(model)
	if model:IsA("Model") and not doors[model] then
		doors[model] = newDoor(model)
	end
end

local function remove(model)
	local door = doors[model]
	if door then
		if door.sound then
			door.sound:Destroy()
		end
		doors[model] = nil
	end
end

CollectionService:GetInstanceAddedSignal(CONFIG.Tag):Connect(add)
CollectionService:GetInstanceRemovedSignal(CONFIG.Tag):Connect(remove)
for _, model in CollectionService:GetTagged(CONFIG.Tag) do
	add(model)
end

RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 1 / 30)
	for _, door in doors do
		step(door, dt)
	end
end)
