-- Rain and the city outside, heard through the grocery store's walls.
-- Fades in while the player is inside the store's AmbienceZone and out when
-- they leave. Client-side: it's background noise, nobody needs it in sync.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CITY_ID = "rbxassetid://9112757705" -- "City Ambience 1" (Pro Sound Effects), evening traffic + distant walla
local RAIN_ID = "rbxassetid://9112856750" -- "Rain On Window 2" (Pro Sound Effects), downpour heard from inside

local CITY_VOLUME = 0.12
local RAIN_VOLUME = 0.2
-- Seconds to fade fully in or out.
local FADE_TIME = 1.5

local player = Players.LocalPlayer

local function makeSound(name, id, volume, eq)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s:SetAttribute("FullVolume", volume)
	-- Through glass and brick: the highs go first, the mids dull, the lows carry.
	local e = Instance.new("EqualizerSoundEffect")
	e.LowGain = eq.low
	e.MidGain = eq.mid
	e.HighGain = eq.high
	e.Parent = s
	s.Parent = script
	s:Play()
	return s
end

local sounds = {
	makeSound("City", CITY_ID, CITY_VOLUME, { low = 2, mid = -10, high = -30 }),
	makeSound("Rain", RAIN_ID, RAIN_VOLUME, { low = 0, mid = -6, high = -20 }),
}

local function insideStore()
	local store = workspace:FindFirstChild("Grocery Store")
	local zone = store and store:FindFirstChild("AmbienceZone")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (zone and root) then
		return false
	end
	local offset = zone.CFrame:PointToObjectSpace(root.Position)
	local half = zone.Size / 2
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z
end

local mix = 0
RunService.Heartbeat:Connect(function(dt)
	local target = insideStore() and 1 or 0
	if mix == target then
		return
	end
	local step = dt / FADE_TIME
	mix = if target > mix then math.min(mix + step, 1) else math.max(mix - step, 0)
	for _, s in sounds do
		s.Volume = s:GetAttribute("FullVolume") * mix
	end
end)
