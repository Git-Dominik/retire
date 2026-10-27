-- Tuning for the shop stocking system (StockingService on the server,
-- StockingClient for the prompts). Distances are in studs.

return {
	-- Prompts.
	STOCK_PROMPT_DISTANCE = 9,
	TAKE_PROMPT_DISTANCE = 7,
	-- Server-side reach checks, a little past the prompts for lag.
	MAX_STOCK_DISTANCE = 14,
	MAX_TAKE_DISTANCE = 11,
	-- How far in front of the player a dropped item lands.
	DROP_DISTANCE = 2,

	SOUNDS = {
		take = { id = "rbxassetid://9113578539", volume = 0.5, speed = 1.1 }, -- Box Slide Cardboard Rub 11
		place = { id = "rbxassetid://9113719636", volume = 0.22, speed = 1.9 }, -- Cardboard Box 1
	},
}
