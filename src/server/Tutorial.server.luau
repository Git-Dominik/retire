-- Remembers, across sessions, which players have finished the first-time tutorial.
-- The steps themselves run on each client (TutorialClient); this only loads and saves
-- the result.
--
-- Each player gets a TutorialDone attribute once their save is read: false runs the
-- tutorial, true skips it. It stays unset while loading, so the client waits. If the
-- DataStore can't be read (Studio without API access, an outage) the player is treated
-- as new and plays it again.
-- The client fires the TutorialFinished remote at the end; the server marks the player
-- done and saves it to the PlayerProgress DataStore (key: UserId, value: a table with
-- TutorialDone). In Studio, the remote's "Reset" action (the F2 dev menu) clears it again
-- so the tutorial can be replayed.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RETRIES = 3
local RETRY_WAIT = 2

local storeOk, progressStore =
	pcall(DataStoreService.GetDataStore, DataStoreService, "PlayerProgress")
if not storeOk then
	warn(`[Tutorial] no DataStore, the tutorial won't be remembered: {progressStore}`)
	progressStore = nil
end

local remote = Instance.new("RemoteEvent")
remote.Name = "TutorialFinished"
remote.Parent = ReplicatedStorage

local function withRetries(label, fn)
	for attempt = 1, RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[Tutorial] {label} failed (try {attempt}): {result}`)
		if attempt < RETRIES then
			task.wait(RETRY_WAIT)
		end
	end
	return false
end

local function save(player, done)
	if not progressStore then
		return
	end
	withRetries(`saving {player.UserId}`, function()
		progressStore:UpdateAsync(tostring(player.UserId), function(old)
			local data = typeof(old) == "table" and old or {}
			data.TutorialDone = done
			return data
		end)
	end)
end

local function load(player)
	local done = false
	if progressStore then
		local ok, data = withRetries(`loading {player.UserId}`, function()
			return progressStore:GetAsync(tostring(player.UserId))
		end)
		done = ok and typeof(data) == "table" and data.TutorialDone == true
	end
	if player.Parent then
		player:SetAttribute("TutorialDone", done)
	end
end

Players.PlayerAdded:Connect(load)
for _, player in Players:GetPlayers() do
	task.spawn(load, player)
end

remote.OnServerEvent:Connect(function(player, action)
	if action == "Reset" then
		if RunService:IsStudio() and player:GetAttribute("TutorialDone") == true then
			player:SetAttribute("TutorialDone", false)
			save(player, false)
		end
		return
	end
	if player:GetAttribute("TutorialDone") ~= false then
		return
	end
	player:SetAttribute("TutorialDone", true)
	save(player, true)
end)
