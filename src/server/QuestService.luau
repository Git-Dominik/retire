-- Item requests ("quests"): a client asks for one item by a due day and pays a fixed reward
-- for it. Server-only state, kept in memory and never saved, so it resets with the server
-- like the day count.
--
-- At each dawn (workspace.Phase -> "Day") one new request may be issued: always on day 1,
-- otherwise QUEST_ISSUE_CHANCE of the time, and never past MAX_ACTIVE_QUESTS. The item is a
-- random one with floorIds (StockItems) on a floor up to MAX_QUEST_FLOOR, or up to the
-- ReplicatedStorage DeepestFloorReached attribute when that's set, and no item is asked for
-- twice at once. The client is a random friend face from CustomerAvatar (a different one
-- from the last request when there's a choice). It's due QUEST_DUE_DAYS later, and pays
-- basePrice * QUEST_PRICE_MULTIPLIER.
--
-- On the due day CustomerService asks takeDueVisit() for a client to send in once the clock
-- passes the request's visit hour (inside QUEST_VISIT_WINDOW of the day). The client
-- goes to the counter and asks; CounterService completes the request when a player hands
-- the item over there with Sell. Anything else (tired of waiting, despawned, or dusk on the
-- due day) fails it. Failing costs only the reward; it's never a strike.
--
-- Each request: QuestId, ClientUserId, ClientName, ItemId, IssuedDay, DueDay, RewardPrice,
-- Status ("Active", "Completed" or "Failed") and InStock (the item is on the shop
-- furniture right now, rechecked every second). Server-only: visitHour, visiting, retryAt.
--
-- Clients read the active requests plus the last QUEST_RECENT_KEPT finished ones from the
-- ReplicatedStorage attribute QuestList (a JSON array, rewritten on every change), so a
-- player joining mid-session gets the whole list with the rest of ReplicatedStorage.
-- QuestClient decodes it and Journal.client draws it.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("ShopConfig"))
local StockItems = require(Shared:WaitForChild("StockItems"))
local CustomerUtil = require(script.Parent:WaitForChild("CustomerUtil"))
local CustomerAvatar = require(script.Parent:WaitForChild("CustomerAvatar"))

local QuestService = {}

local active = {} -- [QuestId] = request
local recent = {} -- finished requests, newest first
local nextQuestId = 1
local lastClientUserId
local lastDawnDay

local function today()
	return workspace:GetAttribute("DayNumber") or 1
end

-- The clock hour from DayNightService's anchor, as ShopHUD works it out.
local function hourNow()
	local anchorHour = workspace:GetAttribute("ClockAnchorHour") or 0
	if workspace:GetAttribute("ClockPaused") then
		return anchorHour
	end
	local anchorTime = workspace:GetAttribute("ClockAnchorTime") or workspace:GetServerTimeNow()
	local length = workspace:GetAttribute("DayLength") or Config.DAY_LENGTH
	return (anchorHour + (workspace:GetServerTimeNow() - anchorTime) * 24 / length) % 24
end

-- Active requests, soonest due first.
local function activeList()
	local list = {}
	for _, quest in active do
		table.insert(list, quest)
	end
	table.sort(list, function(a, b)
		if a.DueDay ~= b.DueDay then
			return a.DueDay < b.DueDay
		end
		return a.QuestId < b.QuestId
	end)
	return list
end

local function snapshot(quest)
	return {
		QuestId = quest.QuestId,
		ClientUserId = quest.ClientUserId,
		ClientName = quest.ClientName,
		ItemId = quest.ItemId,
		IssuedDay = quest.IssuedDay,
		DueDay = quest.DueDay,
		RewardPrice = quest.RewardPrice,
		Status = quest.Status,
		InStock = quest.InStock,
	}
end

-- Rewrites QuestList: active requests (soonest first), then the recent finished ones.
local function publish()
	local list = {}
	for _, quest in activeList() do
		table.insert(list, snapshot(quest))
	end
	for _, quest in recent do
		table.insert(list, snapshot(quest))
	end
	ReplicatedStorage:SetAttribute("QuestList", HttpService:JSONEncode(list))
end

-- The deepest floor a request may send players to.
local function maxFloor()
	local deepest = ReplicatedStorage:GetAttribute("DeepestFloorReached")
	return typeof(deepest) == "number" and deepest or Config.MAX_QUEST_FLOOR
end

local function isRequested(itemId)
	for _, quest in active do
		if quest.ItemId == itemId then
			return true
		end
	end
	return false
end

-- A random item that's reachable and not already asked for, or nil.
local function pickItem()
	local deepest = maxFloor()
	local options = {}
	for _, id in StockItems.ids() do
		local reachable = false
		for _, floor in StockItems.get(id).floorIds do
			if floor <= deepest then
				reachable = true
			end
		end
		if reachable and not isRequested(id) then
			table.insert(options, id)
		end
	end
	return options[math.random(1, math.max(#options, 1))]
end

local function countActive()
	local n = 0
	for _ in active do
		n += 1
	end
	return n
end

-- Creates a request issued today, if there's an item to ask for.
local function issue(day)
	local itemId = pickItem()
	if not itemId then
		return
	end
	local client = CustomerAvatar.pick(lastClientUserId and { [lastClientUserId] = true } or {})
	lastClientUserId = client.userId
	local window = Config.QUEST_VISIT_WINDOW
	local fraction = window[1] + math.random() * (window[2] - window[1])
	local dueDays = Config.QUEST_DUE_DAYS
	local quest = {
		QuestId = nextQuestId,
		ClientUserId = client.userId,
		ClientName = client.name,
		ItemId = itemId,
		IssuedDay = day,
		DueDay = day + math.random(dueDays[1], dueDays[2]),
		RewardPrice = math.floor(
			StockItems.get(itemId).basePrice * Config.QUEST_PRICE_MULTIPLIER + 0.5
		),
		Status = "Active",
		InStock = false,
		visitHour = Config.DAWN_HOUR + fraction * (Config.DUSK_HOUR - Config.DAWN_HOUR),
	}
	nextQuestId += 1
	active[quest.QuestId] = quest
	publish()
end

-- Ends an active request. Returns false if it had already ended, so a request can only be
-- completed (and paid) once.
local function finish(quest, status)
	if quest.Status ~= "Active" or active[quest.QuestId] ~= quest then
		return false
	end
	quest.Status = status
	active[quest.QuestId] = nil
	table.insert(recent, 1, quest)
	while #recent > Config.QUEST_RECENT_KEPT do
		table.remove(recent)
	end
	publish()
	return true
end

-- ================= API =================
-- Whether an active request wants this item (normal customers leave those alone).
function QuestService.isRequested(itemId)
	return isRequested(itemId)
end

-- The request whose client should walk in now (due today, past its visit hour, not already
-- on the way), marked as visiting; nil if there's none.
function QuestService.takeDueVisit()
	local day, hour, now = today(), hourNow(), os.clock()
	for _, quest in activeList() do
		if
			quest.DueDay == day
			and not quest.visiting
			and hour >= quest.visitHour
			and now >= (quest.retryAt or 0)
		then
			quest.visiting = true
			return quest
		end
	end
	return nil
end

-- The client couldn't be sent in after all (the avatar failed to build, the shop closed
-- meanwhile); try again shortly.
function QuestService.visitNotStarted(quest)
	quest.visiting = false
	quest.retryAt = os.clock() + 5
end

-- Marks the request done. Returns true only for the call that actually completed it.
function QuestService.complete(quest)
	return finish(quest, "Completed")
end

-- Marks the request failed, unless it already ended.
function QuestService.fail(quest)
	return finish(quest, "Failed")
end

-- ================= DAY CYCLE =================
local function onDawn()
	local day = today()
	if lastDawnDay == day then
		return
	end
	lastDawnDay = day
	-- Anything a missed dusk left behind is over.
	for _, quest in activeList() do
		if quest.DueDay < day then
			finish(quest, "Failed")
		end
	end
	if
		countActive() < Config.MAX_ACTIVE_QUESTS
		and (day == 1 or math.random() < Config.QUEST_ISSUE_CHANCE)
	then
		issue(day)
	end
end

-- The day is over: whatever was due today and isn't done has failed.
local function onDusk()
	local day = today()
	for _, quest in activeList() do
		if quest.DueDay <= day then
			finish(quest, "Failed")
		end
	end
end

workspace:GetAttributeChangedSignal("Phase"):Connect(function()
	if workspace:GetAttribute("Phase") == "Day" then
		onDawn()
	else
		onDusk()
	end
end)

-- ================= IN STOCK =================
-- InStock follows the shop furniture customers browse (not the racks or anyone's hands).
task.spawn(function()
	while true do
		task.wait(1)
		local stocked = {}
		for _, furniture in CustomerUtil.shopFurniture() do
			for _, slot in CustomerUtil.slotsOf(furniture) do
				local model = CustomerUtil.itemIn(slot)
				if model then
					stocked[model:GetAttribute("ItemId")] = true
				end
			end
		end
		local changed = false
		for _, quest in active do
			local inStock = stocked[quest.ItemId] == true
			if quest.InStock ~= inStock then
				quest.InStock = inStock
				changed = true
			end
		end
		if changed then
			publish()
		end
	end
end)

publish()
if workspace:GetAttribute("Phase") == "Day" then
	onDawn()
end

return QuestService
