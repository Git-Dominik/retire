-- Right arm animation on the player's own avatar arm: it reaches for whatever
-- you interact with and holds a carried item up in front of you. In first
-- person only the forearm and hand are shown, and only while in use.
--
-- A two-bone IK solve places the hand's grip point on a target, and the result
-- is written into the R15 shoulder and elbow joints (AnimationConstraints) during
-- PreSimulation, blended over whatever the Animator is playing. Targets live in
-- the upper torso's space, so the arm moves with the body instead of fighting
-- it; on top sit small breathing, walk and turn motions so it never sits dead
-- still. The held pose tilts partly with where you look.
--
-- Other players' arms reach too (relayed through Arms.server); while they hold
-- something they use the default tool pose.
--
-- A tool can set where it's held (in upper-torso space) with a HoldPoint
-- attribute. Setting LeftHoldPoint as well makes it two-handed: the left arm
-- holds that point the same way, and neither hand leaves it to reach for things.
-- When the item has a Handle, it's held level and both hands take it the same
-- way (the left as the mirror image of the right), so the arms move as a pair.
-- A held item is drawn in toward the chest when a wall is in front of it; far
-- enough in, the left hand lets go and drops back beside it, still in view, and
-- the right carries it alone until there's room again.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local reachRemote = ReplicatedStorage:WaitForChild("ArmReach")

-- Where the hand holds an item, in upper-torso space: right of centre, at chest
-- height, out in front.
local HOLD_POINT = Vector3.new(0.5, 0.15, -1.3)
-- How much the held pose follows the view tilting up and down, and its limits.
local PITCH_FOLLOW = 0.6
local PITCH_MIN, PITCH_MAX = math.rad(-55), math.rad(35)
-- Which way the elbow points (shoulder space): out to the side, down and back.
local ELBOW_HINT = Vector3.new(0.5, -0.7, 0.5)
-- How long the hand stays at a reach target before coming back.
local REACH_TIME = 0.2
-- Smoothing rates (higher snaps faster). Kept high so a grab is quick and crisp.
local TARGET_RATE = 22
local WEIGHT_RATE = 20
local PITCH_RATE = 10
-- Small life on top of the hold pose.
local BREATH_AMOUNT = 0.015
local WALK_SWAY = 0.035
-- How far the held item trails behind moving.
local MOVE_LAG = 0.03
local MOVE_LAG_LIMIT = 0.25
local LAG_RATE = 6
-- Inertia: the held item keeps its own heading, which springs after the view's,
-- so looking around leaves it behind (further the quicker) and it swings back
-- in once you stop, carrying a touch past. Sideways it swings round the view by
-- part of the gap (easing off toward a most, in radians); up and down it hangs
-- low and tips. It moves as one piece, so both hands keep hold.
local INERTIA_STIFFNESS = 35
local INERTIA_DAMPING = 8.5
local TURN_SWING = 0.8
local TURN_SWING_MAX = math.rad(22)
local LOOK_SWAY = 0.8
local LOOK_SWAY_MAX = 0.3
local LOOK_SWAY_TILT = 0.3
-- Backing off from walls: how far past the hands an item without a Handle
-- reaches and how wide it is (one with a Handle is measured), the gap kept from
-- the wall, how close to the chest the hands may be pulled in (past its middle,
-- so even a deep item fits when you stand right up to a wall), and how quickly
-- the item comes back out once there's room (going in is immediate).
local CLEARANCE_AHEAD = 0.5
local CLEARANCE_RADIUS = 0.35
local WALL_GAP = 0.08
local CLOSEST_HOLD = -0.2
local PULL_RATE = 10
-- How far in (studs) a wall pushes a two-handed item before the left hand lets
-- go, and how far it must come back out before the hand takes hold again.
local LET_GO_PULL = 0.1
local REGRAB_PULL = 0.04
-- Where the let-go left hand rests, from its grip on the item (upper-torso
-- space): just off the item's side, a little lower and nearer, still in view.
local LET_GO_OFFSET = Vector3.new(0.05, -0.25, 0.15)

local arms = {} -- [character] = state

local function approach(value, goal, rate, dt)
	return value + (goal - value) * (1 - math.exp(-rate * dt))
end

-- Shortest rotation taking direction a onto direction b.
local function rotationBetween(a, b)
	local axis = a:Cross(b)
	local dot = math.clamp(a:Dot(b), -1, 1)
	if axis.Magnitude < 1e-6 then
		return dot > 0 and CFrame.identity or CFrame.Angles(math.pi, 0, 0)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

local function child(parent, name)
	return parent and parent:FindFirstChild(name)
end

-- Everything the solve needs about one of a character's arms ("Right" or
-- "Left"), or nil if it isn't an R15 rig with AnimationConstraint joints.
local function rigFor(character, side)
	local torso = character:FindFirstChild("UpperTorso")
	local upper = character:FindFirstChild(side .. "UpperArm")
	local lower = character:FindFirstChild(side .. "LowerArm")
	local hand = character:FindFirstChild(side .. "Hand")
	local shoulder = child(upper, side .. "Shoulder")
	local elbow = child(lower, side .. "Elbow")
	local wrist = child(hand, side .. "Wrist")
	local grip = child(hand, side .. "GripAttachment")
	if not (torso and shoulder and elbow and wrist and grip) then
		return nil
	end
	if not (shoulder:IsA("AnimationConstraint") and elbow:IsA("AnimationConstraint") and wrist:IsA("AnimationConstraint")) then
		return nil
	end
	-- Rest-pose geometry: the upper arm from shoulder to elbow, and the forearm
	-- from elbow to the hand's grip point, each in its joint's own frame.
	local upperRest = shoulder.Attachment1.CFrame:Inverse() * elbow.Attachment0.CFrame
	local forearm = (elbow.Attachment1.CFrame:Inverse() * wrist.Attachment0.CFrame * wrist.Attachment1.CFrame:Inverse() * grip.CFrame).Position
	return {
		torso = torso,
		shoulder = shoulder,
		elbow = elbow,
		wrist = wrist,
		grip = grip,
		upperRest = upperRest,
		shoulderRest = shoulder.Attachment0.CFrame,
		upperLength = upperRest.Position.Magnitude,
		forearm = forearm,
		forearmLength = forearm.Magnitude,
		-- The left elbow points out to its own side.
		elbowHint = side == "Left" and ELBOW_HINT * Vector3.new(-1, 1, 1) or ELBOW_HINT,
	}
end

-- Shoulder and elbow rotations that put the grip point on target (shoulder space).
local function solve(rig, target)
	local l1, l2 = rig.upperLength, rig.forearmLength
	local distance = math.clamp(target.Magnitude, math.abs(l1 - l2) + 0.05, l1 + l2 - 0.01)
	local dir = target.Unit
	local along = (l1 * l1 - l2 * l2 + distance * distance) / (2 * distance)
	local out = math.sqrt(math.max(l1 * l1 - along * along, 0))
	local hint = rig.elbowHint - dir * rig.elbowHint:Dot(dir)
	hint = hint.Magnitude > 1e-4 and hint.Unit or Vector3.new(0, -1, 0)
	local elbowPos = dir * along + hint * out

	local shoulderRot = rotationBetween(rig.upperRest.Position.Unit, elbowPos.Unit)
	local elbowFrame = shoulderRot * rig.upperRest
	local forearmGoal = elbowFrame:VectorToObjectSpace(dir * distance - elbowPos)
	local elbowRot = rotationBetween(rig.forearm.Unit, forearmGoal.Unit)
	return shoulderRot, elbowRot
end

local function stateFor(character)
	local s = arms[character]
	if not s then
		s = {
			right = { side = "Right", weight = 0 },
			left = { side = "Left", weight = 0 },
			reachUntil = 0,
			pitch = 0,
			walkPhase = 0,
			heldYaw = 0,
			heldYawVelocity = 0,
			heldPitch = 0,
			heldPitchVelocity = 0,
			moveLag = Vector3.zero,
			pull = 0,
		}
		arms[character] = s
	end
	return s
end

-- The arm's rig, rebuilt whenever the character's parts change.
local function rigOf(arm, character)
	if not arm.rig or not arm.rig.torso.Parent then
		arm.rig = rigFor(character, arm.side)
	end
	return arm.rig
end

-- Blends one arm toward its goal (upper-torso space), or back to whatever the
-- Animator is playing when there's no goal.
local clearanceParams = RaycastParams.new()
clearanceParams.FilterType = Enum.RaycastFilterType.Exclude
clearanceParams.RespectCanCollide = true

-- How far (studs, toward the chest) the hold has to come in so the held item
-- doesn't push into whatever is in front of it. Without a measured shape (item,
-- a list of its corners in upper-torso space) a ball ahead of point stands in.
local function wallPull(character, torsoCf, point, corners)
	local minX, maxX, minY, maxY, front
	if corners then
		minX, maxX, minY, maxY, front = math.huge, -math.huge, math.huge, -math.huge, 0
		for _, c in corners do
			minX, maxX = math.min(minX, c.X), math.max(maxX, c.X)
			minY, maxY = math.min(minY, c.Y), math.max(maxY, c.Y)
			front = math.max(front, -c.Z)
		end
	else
		minX, maxX = point.X - CLEARANCE_RADIUS, point.X + CLEARANCE_RADIUS
		minY, maxY = point.Y - CLEARANCE_RADIUS, point.Y + CLEARANCE_RADIUS
		front = -point.Z + CLEARANCE_AHEAD
	end
	-- Sweep the item's outline, as a thin slab, out from the chest to its front.
	local reach = front + WALL_GAP
	local slab = Vector3.new(maxX - minX + 2 * WALL_GAP, maxY - minY + 2 * WALL_GAP, 0.1)
	local origin = torsoCf * CFrame.new((minX + maxX) / 2, (minY + maxY) / 2, 0)
	clearanceParams.FilterDescendantsInstances = { character }
	local hit = workspace:Blockcast(origin, slab, torsoCf:VectorToWorldSpace(Vector3.new(0, 0, -reach)), clearanceParams)
	if not hit then
		return 0
	end
	-- (hit.Distance runs to the contact point, which can be well off to the side;
	-- how far ahead the wall is is that point's depth in front of the chest.)
	local ahead = -torsoCf:PointToObjectSpace(hit.Position).Z
	return math.min(reach - ahead, -point.Z - CLOSEST_HOLD)
end

-- How far a hold point (upper-torso space) lies past what the arm can reach,
-- as the move that would bring it back in.
local function overreach(rig, point)
	local fromShoulder = point - rig.shoulder.Attachment0.Position
	local excess = fromShoulder.Magnitude - (rig.upperLength + rig.forearmLength) * 0.96
	return excess > 0 and fromShoulder.Unit * excess or Vector3.zero
end

-- The corners of every part of a tool, in its Handle's space.
local function toolCorners(tool, handle)
	local corners = {}
	local handleInverse = handle.CFrame:Inverse()
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			local cf, half = handleInverse * part.CFrame, part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						table.insert(corners, cf * (half * Vector3.new(sx, sy, sz)))
					end
				end
			end
		end
	end
	return corners
end

-- Springs value toward goal (with velocity), in short steps so a long frame
-- can't make it blow up. Returns the new value and velocity.
local function spring(value, velocity, goal, dt)
	while dt > 0 do
		local step = math.min(dt, 1 / 60)
		velocity += ((goal - value) * INERTIA_STIFFNESS - velocity * INERTIA_DAMPING) * step
		value += velocity * step
		dt -= step
	end
	return value, velocity
end

-- Where an arm's forearm and hand end up for the given joint rotations
-- (defaulting to the joints' current Transforms), measured from torsoCf.
local function armCFrames(rig, torsoCf, shoulderT, elbowT, wristT)
	local upper = torsoCf * rig.shoulder.Attachment0.CFrame * (shoulderT or rig.shoulder.Transform) * rig.shoulder.Attachment1.CFrame:Inverse()
	local lower = upper * rig.elbow.Attachment0.CFrame * (elbowT or rig.elbow.Transform) * rig.elbow.Attachment1.CFrame:Inverse()
	return lower, lower * rig.wrist.Attachment0.CFrame * (wristT or rig.wrist.Transform) * rig.wrist.Attachment1.CFrame:Inverse()
end

-- A CFrame reflected across its parent's X = 0 plane: the same hold, on the
-- other side, as the other hand would make it.
local function mirrorX(cf)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

-- Eases one arm's target toward its goal (upper-torso space). An exact goal is
-- locked onto once the hand has come close, so a regrab still eases in. Returns
-- whether the arm is in use and should be posed.
local function track(arm, rig, goal, torsoCf, dt, exact)
	arm.weight = approach(arm.weight, goal and 1 or 0, WEIGHT_RATE, dt)
	if goal then
		-- Starting from rest, ease out from wherever the hand actually is.
		if not arm.target or arm.weight < 0.02 then
			arm.target = torsoCf:PointToObjectSpace(rig.grip.WorldPosition)
		end
		arm.locked = exact and (arm.locked or (goal - arm.target).Magnitude < 0.05)
		if arm.locked then
			arm.target = goal
		else
			arm.target = arm.target:Lerp(goal, 1 - math.exp(-TARGET_RATE * dt))
		end
	elseif arm.weight < 0.01 then
		arm.target = nil
	end
	return arm.target ~= nil
end

-- Blends the arm toward reaching its target, or back to whatever the Animator is
-- playing as its weight falls. handCf, when given, is where the hand itself
-- should end up (world space): the wrist turns to match instead of staying
-- straight, and the hand goes to it rather than to the arm's target.
local function pose(arm, rig, torsoCf, handCf)
	local target = handCf and torsoCf:PointToObjectSpace((handCf * rig.grip.CFrame).Position) or arm.target
	local shoulderRot, elbowRot = solve(rig, rig.shoulder.Attachment0.CFrame:PointToObjectSpace(target))
	rig.shoulder.Transform = rig.shoulder.Transform:Lerp(shoulderRot, arm.weight)
	rig.elbow.Transform = rig.elbow.Transform:Lerp(elbowRot, arm.weight)
	local wrist = CFrame.identity
	if handCf then
		local lower = armCFrames(rig, torsoCf)
		wrist = ((lower * rig.wrist.Attachment0.CFrame):Inverse() * handCf * rig.wrist.Attachment1.CFrame).Rotation
	end
	rig.wrist.Transform = rig.wrist.Transform:Lerp(wrist, arm.weight)
end

RunService.PreSimulation:Connect(function(dt)
	local now = os.clock()
	for character, s in arms do
		if not character.Parent then
			arms[character] = nil
			continue
		end
		local rig = rigOf(s.right, character)
		if not rig then
			continue
		end
		local torsoCf = rig.torso.CFrame
		local isLocal = character == player.Character
		local leftRig = rigOf(s.left, character)
		if isLocal then
			-- Crouching only drops the camera (Camera.client), not the body. Drop your
			-- own shoulders with it (only on your screen), so held items and reaches
			-- sit where they would standing instead of the arms coming down from above.
			local crouch = CFrame.new(0, player:GetAttribute("CrouchOffset") or 0, 0)
			for _, r in { rig, leftRig } do
				r.shoulder.Attachment0.CFrame = crouch * r.shoulderRest
			end
		end
		local shoulderInTorso = rig.shoulder.Attachment0.Position
		local tool = isLocal and character:FindFirstChildOfClass("Tool")
		local holdPoint = tool and tool:GetAttribute("HoldPoint") or HOLD_POINT
		local leftHoldPoint = tool and tool:GetAttribute("LeftHoldPoint")

		-- Pick this frame's targets, in upper-torso space. A two-handed hold never
		-- lets go to reach.
		local goal, leftGoal
		if now < s.reachUntil and not leftHoldPoint then
			goal = torsoCf:PointToObjectSpace(s.reachWorld)
		elseif tool and not player:GetAttribute("ReadingJournal") then
			-- Tilt the hold point around the shoulder with (part of) the view's pitch.
			local camPitch = camera.CFrame:ToEulerAnglesYXZ()
			s.pitch = approach(s.pitch, math.clamp(camPitch * PITCH_FOLLOW, PITCH_MIN, PITCH_MAX), PITCH_RATE, dt)
			local tilt = CFrame.Angles(s.pitch, 0, 0)
			-- (Hold points are measured from the standing shoulder.)
			local restShoulder = rig.shoulderRest.Position
			local fromShoulder = tilt * (holdPoint - restShoulder)

			-- Inertia: spring the item's own heading after the (already smoothed)
			-- view. Looking left (yaw increasing) leaves it behind to the right,
			-- looking up leaves it low. After a gap in holding it starts level with
			-- the view; it's kept within half a turn of it, so spinning can't wind it up.
			local _, camYaw = camera.CFrame:ToEulerAnglesYXZ()
			if not (s.lastHeldAt and now - s.lastHeldAt < 0.1) then
				s.heldYaw, s.heldYawVelocity = camYaw, 0
				s.heldPitch, s.heldPitchVelocity = camPitch, 0
			end
			s.lastHeldAt = now
			s.heldYaw = camYaw + (s.heldYaw - camYaw + math.pi) % (2 * math.pi) - math.pi
			s.heldYaw, s.heldYawVelocity = spring(s.heldYaw, s.heldYawVelocity, camYaw, dt)
			s.heldPitch, s.heldPitchVelocity = spring(s.heldPitch, s.heldPitchVelocity, camPitch, dt)
			s.yawBehind = s.heldYaw - camYaw
			s.pitchBehind = s.heldPitch - camPitch
			local dip = LOOK_SWAY_MAX * math.tanh(s.pitchBehind * LOOK_SWAY / LOOK_SWAY_MAX)

			-- A little life: breathing, a sway while walking, and lag behind moving.
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local speed = humanoid and humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed or 0
			s.walkPhase += dt * speed * 0.75
			local walk = math.min(speed / 10, 1.5)
			local velocity = root and torsoCf:VectorToObjectSpace(root.AssemblyLinearVelocity) or Vector3.zero
			local moveGoal = -velocity * MOVE_LAG
			if moveGoal.Magnitude > MOVE_LAG_LIMIT then
				moveGoal = moveGoal.Unit * MOVE_LAG_LIMIT
			end
			s.moveLag = s.moveLag:Lerp(moveGoal, 1 - math.exp(-LAG_RATE * dt))
			local life = Vector3.new(
				math.sin(s.walkPhase) * WALK_SWAY * walk,
				math.sin(now * 1.3) * BREATH_AMOUNT - math.abs(math.cos(s.walkPhase)) * WALK_SWAY * 0.6 * walk + dip,
				0
			) + s.moveLag
			goal = shoulderInTorso + fromShoulder + life
			if leftHoldPoint then
				-- Swung about the same (right) shoulder, so both hands stay on the item.
				leftGoal = shoulderInTorso + tilt * (leftHoldPoint - restShoulder) + life
			end

			-- Swing the hold round the view. The body turns with the mouse while the
			-- view eases after it (Camera.client), so mid-turn the body, and the item
			-- with it, runs ahead of what you see; first turn it back to face the
			-- view, then the inertia's share further, so it trails behind instead.
			local _, bodyYaw = (root and root.CFrame or torsoCf):ToEulerAnglesYXZ()
			local catchUp = (camYaw - bodyYaw + math.pi) % (2 * math.pi) - math.pi
			local trail = TURN_SWING_MAX * math.tanh(s.yawBehind * TURN_SWING / TURN_SWING_MAX)
			s.swing = catchUp + trail
			local eye = torsoCf:PointToObjectSpace(camera.CFrame.Position)
			local pivot = Vector3.new(eye.X, 0, eye.Z)
			local swing = CFrame.Angles(0, s.swing, 0)
			goal = pivot + swing * (goal - pivot)
			if leftGoal then
				leftGoal = pivot + swing * (leftGoal - pivot)
				-- Swung that far, a hand can end up out of reach; bring the whole item
				-- in by however far that is so neither lets go.
				local shift = overreach(rig, goal) + (leftRig and overreach(leftRig, leftGoal) or Vector3.zero)
				goal -= shift
				leftGoal -= shift
			end

			-- Draw the item in toward the chest when a wall is in the way: at once,
			-- so it can't be walked into one, and back out gently. An item with a
			-- Handle is measured where it would sit (turned as it was last frame).
			local middle = leftGoal and (goal + leftGoal) / 2 or goal
			local handle = tool:FindFirstChild("Handle")
			local corners
			if handle then
				local rotation = s.itemRotation or CFrame.identity
				local item = CFrame.new(goal - rotation * tool.Grip.Position) * rotation
				corners = toolCorners(tool, handle)
				for i, c in corners do
					corners[i] = item * c
				end
			end
			local needed = math.max(wallPull(character, torsoCf, middle, corners), 0)
			s.pull = needed > s.pull and needed or approach(s.pull, needed, PULL_RATE, dt)
			local pull = Vector3.new(0, 0, s.pull)
			goal += pull
			if leftGoal then
				leftGoal += pull
			end
		end

		-- Pressed far enough into a wall, the left hand lets go and rests beside the
		-- item instead.
		if s.pull > LET_GO_PULL then
			s.letGo = true
		elseif s.pull < REGRAB_PULL then
			s.letGo = false
		end
		if leftGoal and s.letGo then
			leftGoal += LET_GO_OFFSET
		end
		local handle = leftGoal and leftRig and tool:FindFirstChild("Handle")

		local rightHandCf, leftHandCf
		local holding = track(s.right, rig, goal, torsoCf, dt)
		if holding and goal and s.pull > 0 then
			-- The hand eases toward its goal; never let it lag out past the wall.
			local t = s.right.target
			s.right.target = Vector3.new(t.X, t.Y, math.max(t.Z, goal.Z))
		end
		if holding and handle then
			-- Hold the item level between the hands: keep only how far a plain
			-- right-hand hold would tip it forward or back, place it so the right
			-- grip sits on the right hand's target, and give each hand its own
			-- side's grip on it, the left the mirror of the right.
			local shoulderRot, elbowRot = solve(rig, rig.shoulder.Attachment0.CFrame:PointToObjectSpace(s.right.target))
			local _, plainHand = armCFrames(rig, CFrame.identity, shoulderRot, elbowRot, CFrame.identity)
			local tip = (plainHand * rig.grip.CFrame * tool.Grip:Inverse()):ToEulerAnglesYXZ()
			-- (Facing round as far as the hold was swung round the view.)
			local level = CFrame.Angles(0, s.swing or 0, 0) * CFrame.Angles(tip, 0, 0)
			local item = CFrame.new(s.right.target - level * tool.Grip.Position) * level
			-- Inertia tips it, about its middle, part of the way back to where it faced.
			local middle = item * ((tool.Grip.Position + mirrorX(tool.Grip).Position) / 2)
			local turn = CFrame.Angles((s.pitchBehind or 0) * LOOK_SWAY_TILT, 0, 0)
			item = CFrame.new(middle) * turn * CFrame.new(-middle) * item
			s.itemRotation = item.Rotation
			rightHandCf = torsoCf * item * tool.Grip * rig.grip.CFrame:Inverse()
			if not s.letGo then
				local leftGrip = item * mirrorX(tool.Grip)
				leftHandCf = torsoCf * leftGrip * leftRig.grip.CFrame:Inverse()
				leftGoal = leftGrip.Position
			end
		end
		if s.right.target then
			pose(s.right, rig, torsoCf, rightHandCf)
		end
		if leftRig and track(s.left, leftRig, leftGoal, torsoCf, dt, leftHandCf ~= nil) then
			pose(s.left, leftRig, torsoCf, leftHandCf)
		end
	end
end)

-- First person hides your whole body; bring the forearm and hand back while the
-- arm is in use. The camera module only rewrites transparency when zoom changes,
-- so this sets it every frame, after the camera has updated.
local SHOWN_PARTS = { right = { "RightLowerArm", "RightHand" }, left = { "LeftLowerArm", "LeftHand" } }
RunService:BindToRenderStep("ArmVisible", Enum.RenderPriority.Camera.Value + 3, function()
	local character = player.Character
	local s = character and arms[character]
	if not s then
		return
	end
	for key, names in SHOWN_PARTS do
		local shown = s[key].weight > 0.05
		for _, name in names do
			local part = character:FindFirstChild(name)
			if part then
				part.LocalTransparencyModifier = shown and 0 or 1
			end
		end
	end
end)

local function reach(character, target)
	if not character then
		return
	end
	local s = stateFor(character)
	s.reachWorld = target
	s.reachUntil = os.clock() + REACH_TIME
end

player.CharacterAdded:Connect(stateFor)
if player.Character then
	stateFor(player.Character)
end

local function reachForPrompt(prompt)
	local parent = prompt.Parent
	local target = (parent:IsA("Attachment") and parent.WorldPosition) or (parent:IsA("BasePart") and parent.Position)
	if target then
		reach(player.Character, target)
		reachRemote:FireServer(target)
	end
end

-- Reach for anything you interact with: items, the tray, the journal.
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who == player then
		reachForPrompt(prompt)
	end
end)

-- A prompt's AltKey (the floor selector's Q) is a second way to use it, but it
-- never triggers the prompt, so it's watched for here.
local altPrompts = {}
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt:GetAttribute("AltKey") then
		altPrompts[prompt] = true
	end
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	altPrompts[prompt] = nil
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	for prompt in altPrompts do
		if input.KeyCode.Name == prompt:GetAttribute("AltKey") then
			reachForPrompt(prompt)
			return
		end
	end
end)

reachRemote.OnClientEvent:Connect(function(character, target)
	if character ~= player.Character then
		reach(character, target)
	end
end)
