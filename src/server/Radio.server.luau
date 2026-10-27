-- The radio on the store's service counter plays a quiet loop of relaxing tracks,
-- heard only around the shop. It plays on the server so everyone in the store
-- hears the same song.
--
-- The store is put away in ServerStorage while the elevator is down
-- (Elevator.server), which silences it; it picks up again when the store comes back.

local TRACKS = {
	128746954935989, -- Midnight Lobby Sway
	135272444646832, -- Cozy Piano Mornings
	127468148248456, -- Café Saxophone
	118638936958413, -- Midnight Chill Jazz
}
local VOLUME = 0.35
-- Full volume within this many studs of the radio, fading out by the far one.
local NEAR, FAR = 6, 45

local store = workspace:WaitForChild("Grocery Store")
local radio = store:FindFirstChild("StoreRadio", true)
if not radio then
	warn("[Radio] no StoreRadio model in the store")
	return
end
local body = radio:WaitForChild("Body")

local sound = Instance.new("Sound")
sound.Name = "Music"
sound.Volume = VOLUME
sound.RollOffMode = Enum.RollOffMode.InverseTapered
sound.RollOffMinDistance = NEAR
sound.RollOffMaxDistance = FAR
sound.Parent = body

-- A small speaker: less bass and treble, so it sounds like it's coming out of the radio.
local tone = Instance.new("EqualizerSoundEffect")
tone.LowGain = -8
tone.MidGain = 0
tone.HighGain = -5
tone.Parent = sound

local track = math.random(#TRACKS)

local function play()
	sound.SoundId = "rbxassetid://" .. TRACKS[track]
	sound.TimePosition = 0
	sound:Play()
end

sound.Ended:Connect(function()
	track = track % #TRACKS + 1
	play()
end)

-- Back in the world after the elevator returns: carry on where it left off.
store.AncestryChanged:Connect(function()
	if store:IsDescendantOf(workspace) and not sound.IsPlaying then
		sound:Resume()
	end
end)

play()
