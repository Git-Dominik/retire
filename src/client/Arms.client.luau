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

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local TURN_LAG = 0.025
local TURN_LAG_LIMIT = 0.12

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

-- Everything the solve needs about one character's right arm, or nil if it
-- isn't an R15 rig with AnimationConstraint joints.
local function rigFor(character)
	local torso = character:FindFirstChild("UpperTorso")
	local upper = character:FindFirstChild("RightUpperArm")
	local lower = character:FindFirstChild("RightLowerArm")
	local hand = character:FindFirstChild("RightHand")
	local shoulder = child(upper, "RightShoulder")
	local elbow = child(lower, "RightElbow")
	local wrist = child(hand, "RightWrist")
	local grip = child(hand, "RightGripAttachment")
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
		upperLength = upperRest.Position.Magnitude,
		forearm = forearm,
		forearmLength = forearm.Magnitude,
	}
end

-- Shoulder and elbow rotations that put the grip point on target (shoulder space).
local function solve(rig, target)
	local l1, l2 = rig.upperLength, rig.forearmLength
	local distance = math.clamp(target.Magnitude, math.abs(l1 - l2) + 0.05, l1 + l2 - 0.01)
	local dir = target.Unit
	local along = (l1 * l1 - l2 * l2 + distance * distance) / (2 * distance)
	local out = math.sqrt(math.max(l1 * l1 - along * along, 0))
	local hint = ELBOW_HINT - dir * ELBOW_HINT:Dot(dir)
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
		s = { weight = 0, reachUntil = 0, pitch = 0, walkPhase = 0, turnLag = 0 }
		arms[character] = s
	end
	return s
end

RunService.PreSimulation:Connect(function(dt)
	local now = os.clock()
	for character, s in arms do
		if not character.Parent then
			arms[character] = nil
			continue
		end
		local rig = s.rig
		if not rig or not rig.torso.Parent then
			rig = rigFor(character)
			s.rig = rig
			if not rig then
				continue
			end
		end
		local torsoCf = rig.torso.CFrame
		local shoulderCf = torsoCf * rig.shoulder.Attachment0.CFrame
		local shoulderInTorso = rig.shoulder.Attachment0.Position
		local isLocal = character == player.Character

		-- Pick this frame's target, in upper-torso space.
		local goal
		if now < s.reachUntil then
			goal = torsoCf:PointToObjectSpace(s.reachWorld)
		elseif isLocal and character:FindFirstChildOfClass("Tool") and not player:GetAttribute("ReadingJournal") then
			-- Tilt the hold point around the shoulder with (part of) the view's pitch.
			local camPitch = camera.CFrame:ToEulerAnglesYXZ()
			s.pitch = approach(s.pitch, math.clamp(camPitch * PITCH_FOLLOW, PITCH_MIN, PITCH_MAX), PITCH_RATE, dt)
			local fromShoulder = CFrame.Angles(s.pitch, 0, 0) * (HOLD_POINT - shoulderInTorso)

			-- A little life: breathing, a sway while walking, a lag when turning.
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local speed = humanoid and humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed or 0
			s.walkPhase += dt * speed * 0.75
			local walk = math.min(speed / 10, 1.5)
			local _, yaw = (root and root.CFrame or torsoCf):ToEulerAnglesYXZ()
			local turnRate = s.lastYaw and ((yaw - s.lastYaw + math.pi) % (2 * math.pi) - math.pi) / math.max(dt, 1e-3) or 0
			s.lastYaw = yaw
			s.turnLag = approach(s.turnLag, math.clamp(-turnRate * TURN_LAG, -TURN_LAG_LIMIT, TURN_LAG_LIMIT), 8, dt)
			local life = Vector3.new(
				math.sin(s.walkPhase) * WALK_SWAY * walk + s.turnLag,
				math.sin(now * 1.3) * BREATH_AMOUNT - math.abs(math.cos(s.walkPhase)) * WALK_SWAY * 0.6 * walk,
				0
			)
			goal = shoulderInTorso + fromShoulder + life
		end

		s.weight = approach(s.weight, goal and 1 or 0, WEIGHT_RATE, dt)
		if goal then
			-- Starting from rest, ease out from wherever the hand actually is.
			if not s.target or s.weight < 0.02 then
				s.target = torsoCf:PointToObjectSpace(rig.grip.WorldPosition)
			end
			s.target = s.target:Lerp(goal, 1 - math.exp(-TARGET_RATE * dt))
		elseif s.weight < 0.01 then
			s.target = nil
			continue
		end
		if not s.target then
			continue
		end

		local shoulderRot, elbowRot = solve(rig, shoulderCf:PointToObjectSpace(torsoCf * s.target))
		rig.shoulder.Transform = rig.shoulder.Transform:Lerp(shoulderRot, s.weight)
		rig.elbow.Transform = rig.elbow.Transform:Lerp(elbowRot, s.weight)
		rig.wrist.Transform = rig.wrist.Transform:Lerp(CFrame.identity, s.weight)
	end
end)

-- First person hides your whole body; bring the forearm and hand back while the
-- arm is in use. The camera module only rewrites transparency when zoom changes,
-- so this sets it every frame, after the camera has updated.
local SHOWN_PARTS = { "RightLowerArm", "RightHand" }
RunService:BindToRenderStep("ArmVisible", Enum.RenderPriority.Camera.Value + 3, function()
	local character = player.Character
	local s = character and arms[character]
	if not s then
		return
	end
	local shown = s.weight > 0.05
	for _, name in SHOWN_PARTS do
		local part = character:FindFirstChild(name)
		if part then
			part.LocalTransparencyModifier = shown and 0 or 1
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

-- Reach for anything you interact with: items, the tray, the journal.
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= player then
		return
	end
	local parent = prompt.Parent
	local target = (parent:IsA("Attachment") and parent.WorldPosition) or (parent:IsA("BasePart") and parent.Position)
	if target then
		reach(player.Character, target)
		reachRemote:FireServer(target)
	end
end)

reachRemote.OnClientEvent:Connect(function(character, target)
	if character ~= player.Character then
		reach(character, target)
	end
end)
