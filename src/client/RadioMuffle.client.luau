-- Muffles the store radio while the player is in a back room (storage room, staff room, elevator),
-- as if heard through the wall. Client-side and local: each player hears it from where they stand.
-- Radio.server owns the music itself (the Music sound under StoreRadio.Body); this script only
-- adds a local EqualizerSoundEffect to it and eases the gains in and out.
-- The rooms are invisible parts tagged MuffleZone (place-only): StorageZone and StaffZone in the
-- Grocery Store model, so they move with the store, and ElevatorZone in the Elevator model. The
-- store is swapped out while the elevator is down, which replaces the Music sound, so the filter
-- is looked up and re-added whenever it goes missing.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CONFIG = {
	Tag = "MuffleZone",
	-- Through a wall: the highs go first, the mids dull, the bass carries.
	LowGain = -5,
	MidGain = -20,
	HighGain = -45,
	-- Exponential smoothing rate (1/s) for walking in and out of a room.
	Rate = 5,
}

local player = Players.LocalPlayer

local function findMusic(store)
	local radio = store:FindFirstChild("StoreRadio", true)
	local body = radio and radio:FindFirstChild("Body")
	return body and body:FindFirstChild("Music")
end

local function inMuffleZone()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, zone in CollectionService:GetTagged(CONFIG.Tag) do
		if zone:IsA("BasePart") and zone:IsDescendantOf(workspace) then
			local offset = zone.CFrame:PointToObjectSpace(root.Position)
			local half = zone.Size / 2
			if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

local muffle
local amount = 0

RunService.Heartbeat:Connect(function(dt)
	local store = workspace:FindFirstChild("Grocery Store")
	if not store then
		return
	end
	local music = findMusic(store)
	if not music then
		return
	end
	if not (muffle and muffle.Parent == music) then
		muffle = Instance.new("EqualizerSoundEffect")
		muffle.Name = "Muffle"
		muffle.Parent = music
	end

	local target = inMuffleZone() and 1 or 0
	amount += (target - amount) * (1 - math.exp(-CONFIG.Rate * dt))
	muffle.LowGain = CONFIG.LowGain * amount
	muffle.MidGain = CONFIG.MidGain * amount
	muffle.HighGain = CONFIG.HighGain * amount
end)
