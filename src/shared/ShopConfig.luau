-- Tuning for the shop's day: the day/night clock, customers, the counter, shoplifters and
-- the daily quota. Read by DayNightService, CustomerService, ShoplifterService,
-- CounterService, QuotaService and CustomerAvatar on the server, and by DayNightClient,
-- ShopHUD and CustomerVisuals on the client. The QUESTS section is read by QuestService,
-- CustomerService and CounterService on the server and QuestClient and Journal.client. Times are in real seconds unless named as
-- hours; distances are in studs; money is in dollars.

return {
	-- ================= CLOCK =================
	DAY_LENGTH = 12 * 60, -- one full 24-hour cycle
	DAWN_HOUR = 7, -- Day runs from dawn to dusk, Night from dusk to dawn
	DUSK_HOUR = 19,
	-- The server starts on the night before Day 1, with the clock held at this hour. Day 1
	-- dawns when the elevator first comes back up to the store; the clock runs from then on.
	FIRST_NIGHT_HOUR = 22,
	-- How often the server writes Lighting.ClockTime (clients interpolate every frame).
	CLOCK_WRITE_INTERVAL = 1,

	-- ================= LIGHTING =================
	-- The day look is whatever the place's Lighting is saved with; DayNightClient reads it
	-- on start. Night is this, reached by a tween at dusk (and back at dawn). Ambient also
	-- lights interiors, so it only drops a little.
	LIGHT_TWEEN_TIME = 25,
	NIGHT_LIGHTING = {
		Brightness = 0.6,
		Ambient = Color3.fromRGB(36, 25, 22),
		OutdoorAmbient = Color3.fromRGB(42, 46, 66),
		ColorShift_Top = Color3.fromRGB(96, 108, 150),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
	},
	NIGHT_ATMOSPHERE = {
		Density = 0.42,
		Color = Color3.fromRGB(58, 64, 92),
		Decay = Color3.fromRGB(34, 32, 56),
		Glare = 0,
	},

	-- ================= CUSTOMERS =================
	-- There are never more customers than unsold items, so nobody comes to an empty shop.
	SPAWN_INTERVAL = { 25, 45 }, -- seconds between customers
	FIRST_SPAWN_DELAY = 8, -- after dawn, or after the first item is stocked, before the first one
	MAX_CUSTOMERS = 4, -- in the shop at once with one player
	MAX_CUSTOMERS_PER_EXTRA_PLAYER = 1,
	MAX_CUSTOMERS_CAP = 8,
	WALK_SPEED = 8,
	-- Chance a customer wants something that's actually on the shelves (when anything
	-- is); otherwise they want any item at all.
	WANT_IN_STOCK_CHANCE = 0.5,
	BROWSE_PAUSE = { 2, 4 }, -- seconds looking at each piece of furniture
	NOT_FOUND_WAIT = 5,
	-- Customers only browse furniture inside SHOP_ZONE (a part in the store covering the shop
	-- floor), and never inside the STAFF_ZONES parts (back rooms).
	SHOP_ZONE = "AmbienceZone",
	STAFF_ZONES = { "StaffZone", "StorageZone" },
	-- How far in front of furniture or the counter a customer stands.
	FURNITURE_STAND_GAP = 1.6,
	COUNTER_STAND_DISTANCE = 2.6,
	QUEUE_SPACING = 2.6,
	-- Timeouts, so nobody gets stuck.
	WALK_TIMEOUT = 20, -- any single walk
	QUEUE_TIMEOUT = 90, -- waiting in line for a counter spot
	LEAVE_TIMEOUT = 25, -- walking out; despawned where they stand after this
	MAX_LIFETIME = 360, -- anything longer and they're sent home

	-- ================= COUNTER =================
	-- Customers pay the item's base price by themselves; nobody needs to be at the counter.
	CHECKOUT_TIME = { 2, 3.5 }, -- seconds from setting the item down to paying
	ITEM_TWEEN_TIME = 0.3,

	-- ================= SHOPLIFTERS =================
	SHOPLIFTER_CHANCE = 0.1, -- on day 1
	SHOPLIFTER_CHANCE_PER_DAY = 0.02,
	SHOPLIFTER_CHANCE_MAX = 0.3,
	SHOPLIFTER_ITEMS = { 1, 2 },
	SHOPLIFTER_TAKE_PAUSE = 0.5,
	SHOPLIFTER_WANDER_TIME = 5, -- when there's nothing on the shelves to take
	-- The grey robber hat. With HAT_ASSET_ID set, that accessory is loaded instead of the
	-- one built from parts.
	HAT_ASSET_ID = 0,
	HAT_COLOR = Color3.fromRGB(110, 110, 115),

	-- ================= AVATARS =================
	FRIEND_FETCH_RETRIES = 3,
	-- Customers look like these accounts when no player's friends can be used.
	FALLBACK_AVATARS = {
		{ userId = 156, name = "builderman" },
		{ userId = 261, name = "Shedletsky" },
		{ userId = 2, name = "John Doe" },
		{ userId = 3, name = "Jane Doe" },
		{ userId = 1, name = "Roblox" },
	},

	-- ================= QUOTA =================
	FIRST_QUOTA = 150,
	QUOTA_GROWTH = 0.2, -- per day, rounded to the nearest 5
	MAX_STRIKES = 1,
	EVALUATE_DELAY = 3, -- after dusk, before the day is judged
	SUMMARY_TIME = 8, -- how long the end-of-day summary stays up

	-- ================= QUESTS =================
	-- A client asks for one item by a due day, comes to the counter that morning and pays a
	-- fixed reward when a player hands it over (QuestService).
	QUEST_PRICE_MULTIPLIER = 2.0, -- reward = basePrice times this, rounded
	MAX_ACTIVE_QUESTS = 3,
	QUEST_ISSUE_CHANCE = 0.6, -- at each dawn; day 1 always gets one
	QUEST_DUE_DAYS = { 2, 4 }, -- due this many days after the day it's issued
	-- Only items found on floors up to here are asked for. ReplicatedStorage's
	-- DeepestFloorReached attribute replaces it when something sets it.
	MAX_QUEST_FLOOR = 3,
	-- When the client walks in on the due day, as a fraction of the way from dawn to dusk.
	QUEST_VISIT_WINDOW = { 0, 1 / 3 },
	QUEST_COUNTER_WAIT = 60, -- at the counter, for a player to bring the item and hold Sell
	QUEST_SELL_HOLD = 0.5,
	QUEST_SELL_PROMPT_DISTANCE = 8,
	QUEST_SELL_MAX_DISTANCE = 13, -- server-side reach check, a little past the prompt for lag
	QUEST_RECENT_KEPT = 5, -- finished quests still listed in the journal
	FLOOR_NAMES = {
		[1] = "Floor 1",
		[2] = "Floor 2",
		[3] = "Floor 3",
		[4] = "Floor 4",
		[5] = "Floor 5",
		[6] = "Floor 6",
		[7] = "Floor 7",
		[8] = "Floor 8",
	},
}
