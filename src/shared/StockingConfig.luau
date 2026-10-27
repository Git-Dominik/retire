-- Tuning for the shop stocking system (StockingService on the server,
-- StockingClient for the visuals). Times are in seconds, distances in studs.
-- Both sides read the same table, so the server's timing and the animations
-- the clients play always agree.

return {
	-- Box flaps.
	BOX_OPEN_TIME = 0.35,
	BOX_CLOSE_TIME = 0.3,
	-- The box closes by itself after this long without a placement.
	AUTO_CLOSE_DELAY = 2,

	-- Item flight. The item pops up out of the box, swoops to a point a short way
	-- in front of the slot (towards the player), then eases into the slot.
	ITEM_POP_TIME = 0.12,
	ITEM_POP_HEIGHT = 0.45,
	ITEM_APPROACH_TIME = 0.14,
	ITEM_FLIGHT_TIME = 0.32,
	ITEM_FLIGHT_START_DISTANCE = 2.2,
	ITEM_FLIGHT_START_RISE = 0.5,

	-- Spam protection: clicks closer together than this are silently ignored.
	PLACE_COOLDOWN = 0.2,

	-- Prompts.
	STOCK_PROMPT_DISTANCE = 9,
	BOX_PROMPT_DISTANCE = 7,
	-- Server-side reach checks, a little past the prompts for lag.
	MAX_STOCK_DISTANCE = 14,
	MAX_BOX_DISTANCE = 11,

	-- Other players within this range see the item flights.
	REPLICATE_RADIUS = 80,

	-- Rejected attempt: a quick side-to-side shake of the held box.
	REJECT_SHAKE_TIME = 0.28,
	REJECT_SHAKE_ANGLE = 7,

	-- The box is a Tool held in both hands by the arm IK (Arms.client). Every box is
	-- carried at the same size, whatever its size on the rack: width, height, depth.
	BOX_HELD_SIZE = Vector3.new(1.1, 0.7, 0.8),
	-- Where the box's centre is held, in upper-torso space: centred, a little below
	-- chest height and well out in front, so it sits low in the view.
	BOX_HOLD_CENTER = Vector3.new(0, 0.3, -1.6),
	-- Where the hands grip: this far out from each side of the box, and this far
	-- below its middle.
	BOX_HAND_GAP = 0.3,
	BOX_HAND_DROP = 0.15,
	-- Tool.Grip for the box (its floor is the Handle), measured against the hold
	-- pose so the box sits level between the hands, tipped a little toward you.
	BOX_GRIP = CFrame.new(
		0.8500,
		0.1771,
		0.0541,
		0.9443,
		0.1188,
		0.3068,
		-0.1770,
		0.9696,
		0.1692,
		-0.2773,
		-0.2140,
		0.9366
	):Orthonormalize(),

	-- Empty boxes on the rack are darkened by this factor.
	EMPTY_BOX_SHADE = 0.45,

	-- Key that puts the held box back on its rack.
	PUT_DOWN_KEY = Enum.KeyCode.Q,

	SOUNDS = {
		take = { id = "rbxassetid://9113578539", volume = 0.5, speed = 1.1 }, -- Box Slide Cardboard Rub 11
		putBack = { id = "rbxassetid://9113719636", volume = 0.45, speed = 1 }, -- Cardboard Box 1, set down
		flapOpen = { id = "rbxassetid://9113579658", volume = 0.35, speed = 1.35 }, -- Box Slide Cardboard Rub 13
		flapClose = { id = "rbxassetid://9113579658", volume = 0.3, speed = 1.6 },
		place = { id = "rbxassetid://9113719636", volume = 0.22, speed = 1.9 },
		reject = { id = "rbxassetid://9113719770", volume = 0.35, speed = 0.8 }, -- Cardboard Box 3
	},
}
