-- Relays arm reaches so every client can animate everyone's arm (see Arms.client).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Further than any prompt can be triggered from, with some slack for lag.
local MAX_REACH = 15

local remote = Instance.new("RemoteEvent")
remote.Name = "ArmReach"
remote.Parent = ReplicatedStorage

remote.OnServerEvent:Connect(function(player, target)
	if typeof(target) ~= "Vector3" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - target).Magnitude > MAX_REACH then
		return
	end
	remote:FireAllClients(character, target)
end)
