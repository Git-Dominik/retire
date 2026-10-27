-- Tunables and palette for the factory level (floor 1).
-- The level never touches Lighting or anything belonging to the pawnshop or elevator: all
-- mood comes from parts, lights, beams and particles inside the factory itself.

local Config = {}

Config.Settings = {
	-- standard doorway every tile uses, so openings always line up exactly
	DoorWidth = 12,
	DoorHeight = 14,
	Wall = 1.5,
	Chamfer = 1.2,
	CorridorWidth = 16, -- interior width of corridor tiles
	CorridorHeight = 22,

	-- map size: how many tiles of each sort get grown off the arrival bay
	SideRooms = { 5, 7 },
	ExtraBranches = { 3, 5 }, -- corridor branches ending in junctions
	MaxPlacementTries = 60,

	MoltenDamage = 20, -- health per second while standing in molten metal (0 = off)
	-- The melt shop basement and the pit go below the elevator floor, i.e. into the
	-- Baseplate. While the factory exists the Baseplate is made non-solid and invisible;
	-- it is restored exactly when the level is cleared. Set false to leave it alone.
	HideBaseplate = true,
	FallbackSeed = 11,
	AmbientSound = "rbxassetid://9112797280",
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Config.Colors = {
	floor = rgb(52, 51, 49),
	floorDark = rgb(40, 40, 40),
	plate = rgb(58, 59, 60),
	ceiling = rgb(30, 30, 31),
	brick = { rgb(114, 60, 42), rgb(102, 55, 40), rgb(122, 70, 48), rgb(96, 58, 44) },
	brickDark = rgb(52, 42, 40),
	concrete = rgb(84, 82, 78),
	plinth = rgb(70, 68, 64),
	corrugated = rgb(70, 74, 72),
	corrugatedRust = rgb(92, 70, 56),
	steel = rgb(58, 60, 62),
	darkSteel = rgb(34, 35, 37),
	frame = rgb(40, 41, 43),
	rust = rgb(96, 60, 40),
	pipe = rgb(74, 64, 56),
	pipeDark = rgb(46, 44, 42),
	coil = rgb(104, 106, 110),
	paintYellow = rgb(150, 118, 40), -- worn safety yellow, not glowing
	paintYellowDark = rgb(112, 90, 36),
	paintRed = rgb(110, 32, 28),
	paintGreen = rgb(54, 72, 58),
	paintBlue = rgb(50, 66, 84),
	black = rgb(20, 20, 20),
	slag = rgb(40, 32, 28),
	molten = rgb(255, 96, 20),
	moltenCore = rgb(255, 150, 60),
	moltenLight = rgb(255, 120, 50),
	glass = rgb(176, 188, 194),
	water = rgb(22, 30, 32),
	wood = rgb(88, 66, 46),
	daylight = rgb(205, 218, 235),
	cold = rgb(175, 205, 245),
	sodium = rgb(255, 172, 92),
	red = rgb(255, 50, 36),
	deadBulb = rgb(60, 58, 50),
	signPlate = rgb(34, 34, 34),
	signText = rgb(214, 196, 150),
	depotPaint = rgb(78, 52, 104), -- muted purple floor paint for the depot
}

return Config
