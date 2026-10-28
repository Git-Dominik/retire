-- The shop's money and the daily quota. Server-only state, published as attributes on
-- ReplicatedStorage for ShopHUD; nothing is saved, so it all resets with the server:
--   ShopMoney       everything the shop has taken from sales
--   DayEarnings     sales since dawn, measured against Quota
--   Quota           today's target: FIRST_QUOTA on day 1, then QUOTA_GROWTH more each
--                   day, rounded to the nearest 5
--   DaySales, DayWalkouts, DayStolenValue   today's counts for the summary
--   Strikes, MaxStrikes, ShopFailed
-- Dawn (workspace.Phase -> "Day") resets the day's numbers. EVALUATE_DELAY seconds after
-- dusk the day is judged: the DaySummary remote goes to every client, and a missed quota
-- is a strike. At MaxStrikes the ShopFailed remote fires, ShopFailed is set (which stops
-- CustomerService spawning) and onShopFailed runs.
-- CounterService reports sales, CustomerService walkouts, ShoplifterService thefts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))

local QuotaService = {}

local summaryRemote = Instance.new("RemoteEvent")
summaryRemote.Name = "DaySummary"
summaryRemote.Parent = ReplicatedStorage

local failedRemote = Instance.new("RemoteEvent")
failedRemote.Name = "ShopFailed"
failedRemote.Parent = ReplicatedStorage

local function get(name)
	return ReplicatedStorage:GetAttribute(name) or 0
end

local function add(name, amount)
	ReplicatedStorage:SetAttribute(name, get(name) + amount)
end

local function round5(n)
	return math.floor(n / 5 + 0.5) * 5
end

function QuotaService.quotaFor(day)
	local quota = Config.FIRST_QUOTA
	for _ = 2, day do
		quota = round5(quota * (1 + Config.QUOTA_GROWTH))
	end
	return quota
end

function QuotaService.failed()
	return ReplicatedStorage:GetAttribute("ShopFailed") == true
end

-- Game over goes here. Runs once, when the strikes reach MaxStrikes.
local function onShopFailed() end

-- Adds a strike and returns whether that ended the shop. Raising MaxStrikes in the config
-- is all it takes to allow more.
local function addStrike()
	add("Strikes", 1)
	return get("Strikes") >= get("MaxStrikes")
end

local function startDay()
	ReplicatedStorage:SetAttribute("DayEarnings", 0)
	ReplicatedStorage:SetAttribute("DaySales", 0)
	ReplicatedStorage:SetAttribute("DayWalkouts", 0)
	ReplicatedStorage:SetAttribute("DayStolenValue", 0)
	ReplicatedStorage:SetAttribute(
		"Quota",
		QuotaService.quotaFor(workspace:GetAttribute("DayNumber") or 1)
	)
end

local function evaluateDay(day)
	local earned, quota = get("DayEarnings"), get("Quota")
	local met = earned >= quota
	local failed = false
	if not met and not QuotaService.failed() then
		failed = addStrike()
	end
	summaryRemote:FireAllClients({
		day = day,
		earned = earned,
		quota = quota,
		sales = get("DaySales"),
		walkouts = get("DayWalkouts"),
		stolen = get("DayStolenValue"),
		met = met,
		strikes = get("Strikes"),
		maxStrikes = get("MaxStrikes"),
		failed = failed or QuotaService.failed(),
	})
	if failed then
		ReplicatedStorage:SetAttribute("ShopFailed", true)
		failedRemote:FireAllClients(day)
		onShopFailed()
	end
end

-- A finished sale: into the till and towards today's quota.
function QuotaService.recordSale(price)
	add("ShopMoney", price)
	add("DayEarnings", price)
	add("DaySales", 1)
end

function QuotaService.recordWalkout()
	add("DayWalkouts", 1)
end

function QuotaService.recordStolen(value)
	add("DayStolenValue", value)
end

-- ================= SETUP =================
ReplicatedStorage:SetAttribute("ShopMoney", 0)
ReplicatedStorage:SetAttribute("Strikes", 0)
ReplicatedStorage:SetAttribute("MaxStrikes", Config.MAX_STRIKES)
ReplicatedStorage:SetAttribute("ShopFailed", false)
startDay()

-- Only a day that was actually open gets judged (the server may start at night).
local dayOpen = workspace:GetAttribute("Phase") == "Day"
workspace:GetAttributeChangedSignal("Phase"):Connect(function()
	if workspace:GetAttribute("Phase") == "Day" then
		dayOpen = true
		startDay()
	elseif dayOpen then
		dayOpen = false
		local day = workspace:GetAttribute("DayNumber") or 1
		task.delay(Config.EVALUATE_DELAY, evaluateDay, day)
	end
end)

return QuotaService
