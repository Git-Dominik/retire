-- Builds the customer NPCs' bodies. Each customer looks like a random friend of a player
-- in the server: every player's friends are fetched when they join (all pages, with
-- retries) and dropped when they leave, and the pool is everyone's friends minus anyone
-- actually in the server. Avatars only ever read a friend's public HumanoidDescription.
-- Descriptions are cached per UserId so a friend costs one request per session.
-- With no usable friend (none, or the requests failed) a customer is one of
-- ShopConfig.FALLBACK_AVATARS instead.
--
-- Every hat is stripped (the description's HatAccessory and Hat-type accessories, then any
-- Hat accessory left on the built rig), so the shoplifters' grey hat is the only one in the
-- shop. Scripts and sounds from the rig are removed too; the walk and idle animation ids are
-- read off its Animate script first.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))

local DEFAULT_ANIMATIONS = {
	idle = "rbxassetid://507766666",
	walk = "rbxassetid://507777826",
}

local CustomerAvatar = {}

local friendsByPlayer = {} -- [Player] = { { userId, name } }
local pool = {} -- everyone's friends, deduplicated
local descriptions = {} -- [userId] = HumanoidDescription template, or false if it failed
local lastPicked

-- Calls fn until it succeeds, waiting longer after each failure (rate limits).
local function withRetries(fn)
	for attempt = 1, Config.FRIEND_FETCH_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt < Config.FRIEND_FETCH_RETRIES then
			task.wait(2 ^ attempt)
		end
	end
	return false, nil
end

local function rebuildPool()
	local inServer = {}
	for _, player in Players:GetPlayers() do
		inServer[player.UserId] = true
	end
	local seen = {}
	table.clear(pool)
	for _, friends in friendsByPlayer do
		for _, friend in friends do
			if not seen[friend.userId] and not inServer[friend.userId] then
				seen[friend.userId] = true
				table.insert(pool, friend)
			end
		end
	end
end

local function fetchFriends(player)
	local ok, pages = withRetries(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if not ok then
		warn(`[Customers] Couldn't fetch friends of {player.Name}`)
		return
	end
	local friends = {}
	while true do
		for _, entry in pages:GetCurrentPage() do
			-- Deleted accounts stay in friend lists, with a blank avatar.
			if entry.Username ~= "Account Deleted" and entry.DisplayName ~= "Account Deleted" then
				table.insert(
					friends,
					{ userId = entry.Id, name = entry.DisplayName or entry.Username }
				)
			end
		end
		if pages.IsFinished then
			break
		end
		local advanced = withRetries(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not advanced then
			break
		end
	end
	if player.Parent then
		friendsByPlayer[player] = friends
		rebuildPool()
	end
end

Players.PlayerAdded:Connect(function(player)
	rebuildPool()
	fetchFriends(player)
end)
Players.PlayerRemoving:Connect(function(player)
	friendsByPlayer[player] = nil
	task.defer(rebuildPool)
end)
for _, player in Players:GetPlayers() do
	task.spawn(fetchFriends, player)
end

-- Picks who the next customer looks like, never someone in `exclude` ([userId] = true,
-- the faces already in the shop) and not the last one picked if there's any choice.
function CustomerAvatar.pick(exclude)
	local function choose(list)
		local options, fallback = {}, {}
		for _, entry in list do
			if not exclude[entry.userId] then
				table.insert(fallback, entry)
				if entry.userId ~= lastPicked then
					table.insert(options, entry)
				end
			end
		end
		local from = #options > 0 and options or fallback
		return from[math.random(1, math.max(#from, 1))]
	end
	local entry = choose(pool) or choose(Config.FALLBACK_AVATARS)
	if not entry then
		-- Every face is already in the shop: repeat a preset rather than send nobody.
		entry = Config.FALLBACK_AVATARS[math.random(1, #Config.FALLBACK_AVATARS)]
	end
	lastPicked = entry.userId
	return entry
end

local function descriptionFor(userId)
	if descriptions[userId] == nil then
		local ok, description = withRetries(function()
			return Players:GetHumanoidDescriptionFromUserId(userId)
		end)
		descriptions[userId] = ok and description or false
	end
	local template = descriptions[userId]
	return template and template:Clone() or nil
end

local function stripHatsFromDescription(description)
	pcall(function()
		local kept = {}
		for _, accessory in description:GetAccessories(true) do
			if accessory.AccessoryType ~= Enum.AccessoryType.Hat then
				table.insert(kept, accessory)
			end
		end
		description:SetAccessories(kept, true)
	end)
	description.HatAccessory = ""
end

local function isHat(accessory)
	if accessory.AccessoryType == Enum.AccessoryType.Hat then
		return true
	end
	local handle = accessory:FindFirstChild("Handle")
	return handle ~= nil and handle:FindFirstChild("HatAttachment") ~= nil
end

local function animationIds(model)
	local ids = table.clone(DEFAULT_ANIMATIONS)
	local animate = model:FindFirstChild("Animate")
	if animate then
		for key, path in { idle = { "idle", "Animation1" }, walk = { "walk", "WalkAnim" } } do
			local animation = animate:FindFirstChild(path[1])
			animation = animation and animation:FindFirstChild(path[2])
			if animation and animation:IsA("Animation") and animation.AnimationId ~= "" then
				ids[key] = animation.AnimationId
			end
		end
	end
	return ids
end

-- Builds an R15 rig for the entry from CustomerAvatar.pick. Returns the model, the name to
-- show over it, and its animation ids; or nil if not even a fallback could be built.
function CustomerAvatar.build(entry)
	local description = descriptionFor(entry.userId)
	local name = entry.name
	if not description then
		local fallback = Config.FALLBACK_AVATARS[math.random(1, #Config.FALLBACK_AVATARS)]
		description = descriptionFor(fallback.userId) or Instance.new("HumanoidDescription")
		name = fallback.name
	end
	stripHatsFromDescription(description)

	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn(`[Customers] Couldn't build an avatar for {entry.userId}: {model}`)
		return nil
	end
	local animations = animationIds(model)
	for _, d in model:GetDescendants() do
		if (d:IsA("Accessory") and isHat(d)) or d:IsA("BaseScript") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	return model, name, animations
end

return CustomerAvatar
