-- How much noise each player is making, for enemy AI to listen for. Server only.
--
-- Three levels, from movement:
--   None  standing still or crouching
--   Low   walking
--   High  sprinting
-- Picking up an item is High for PICKUP_TIME, whatever the player is doing.
--
-- Movement runs on the client (Camera.client), so the level is read from the speed
-- the character's root replicates, not from the keys held. The cut-offs sit halfway
-- between the speeds in MovementConfig, so the eased speed changes level mid-blend.
--
-- Enemy behaviour trees: `Noise.of(player) >= Noise.Level.Low` and so on.
-- Pickups: whoever gives a player an item calls `Noise.pickup(player)`
-- (Elevator.server for floor items, StockingService for shop items).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Movement = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MovementConfig"))

local PICKUP_TIME = 1.5

local LOW_SPEED = (Movement.CROUCH_SPEED + Movement.WALK_SPEED) / 2
local HIGH_SPEED = (Movement.WALK_SPEED + Movement.SPRINT_SPEED) / 2

local Noise = {}

Noise.Level = table.freeze({ None = 0, Low = 1, High = 2 })

-- os.clock() each player's pickup noise lasts until.
local pickupUntil = {}

function Noise.pickup(player)
	pickupUntil[player] = os.clock() + PICKUP_TIME
end

-- The player's current noise level, one of Noise.Level.
function Noise.of(player)
	if (pickupUntil[player] or 0) > os.clock() then
		return Noise.Level.High
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return Noise.Level.None
	end
	-- Horizontal only, so falling or riding something doesn't count as footsteps.
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if speed >= HIGH_SPEED then
		return Noise.Level.High
	elseif speed >= LOW_SPEED then
		return Noise.Level.Low
	end
	return Noise.Level.None
end

Players.PlayerRemoving:Connect(function(player)
	pickupUntil[player] = nil
end)

return Noise
