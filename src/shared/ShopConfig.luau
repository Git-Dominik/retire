-- Tuning for the shop's day: the day/night clock, customers, haggling, shoplifters and
-- the daily quota. Read by DayNightService, CustomerService, ShoplifterService,
-- CounterService, QuotaService and CustomerAvatar on the server, and by DayNightClient,
-- ShopHUD and CustomerVisuals on the client. Times are in real seconds unless named as
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
	-- Nobody comes while the shop furniture has nothing on it.
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

	-- ================= HAGGLING =================
	OFFER_RANGE = { 0.7, 0.9 }, -- opening offer, as a fraction of the base price
	WILLING_TO_PAY = { 0.85, 1.15 }, -- hidden per customer, as a fraction of the base price
	COUNTER_STEP = 10, -- percent of the base price per step
	COUNTER_RANGE = { 50, 150 }, -- percent of the base price
	CLOSE_COUNTER_MARGIN = 0.1, -- within this much above willing, they meet you halfway
	PATIENCE = 2,
	FIRST_RESPONSE_TIME = 60,
	LATER_RESPONSE_TIME = 30,
	NEGOTIATE_PROMPT_DISTANCE = 8,
	MAX_NEGOTIATE_DISTANCE = 14, -- walking further than this releases the negotiation
	SELLER_SHARE = 0, -- fraction of each sale paid to the selling player's Money
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
}
