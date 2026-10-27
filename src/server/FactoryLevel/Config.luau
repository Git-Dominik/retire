-- Tunables, palette and wall styles for the factory level.

local M = Enum.Material

local Config = {}

Config.Settings = {
	CorridorLength = { 12, 18 }, -- studs between connected rooms
	CorridorWidth = 5.5,
	CorridorHeight = 8.5,
	DoorHeight = 8,
	Wall = 1, -- wall thickness
	Chamfer = 0.9, -- leg of the 45-degree cut on wall/ceiling edges

	HubSides = 16,
	HubRadius = { 17, 19 },
	HubHeight = 27,
	HubDrop = { 4, 6 }, -- how far the hub floor sits below the elevator
	CatwalkHeight = 9, -- first tier above the hub floor
	BridgeHeight = 17, -- high bridge above the hub floor

	RingSides = 12,
	RingRadius = { 12, 14 },
	RingWalk = 4.5, -- width of the catwalk ring around the pit
	RingHeight = 14,
	PitDepth = { 10, 13 },

	MaxAttempts = 60, -- re-rolls before falling back to a known-good seed
	FallbackSeed = 1,
	AmbientSound = "rbxassetid://9112797280", -- same machinery hum the elevator uses
}

Config.Colors = {
	floor = Color3.fromRGB(38, 39, 41),
	ceiling = Color3.fromRGB(26, 27, 29),
	wall = Color3.fromRGB(56, 54, 52),
	brick = Color3.fromRGB(58, 30, 26),
	brickDark = Color3.fromRGB(44, 27, 24),
	rust = Color3.fromRGB(54, 44, 38),
	panel = Color3.fromRGB(48, 51, 52),
	pit = Color3.fromRGB(44, 48, 44),
	pillar = Color3.fromRGB(64, 62, 58),
	steel = Color3.fromRGB(58, 60, 62),
	darkSteel = Color3.fromRGB(30, 31, 33),
	grate = Color3.fromRGB(46, 47, 48),
	drain = Color3.fromRGB(22, 23, 24),
	pipe = Color3.fromRGB(78, 60, 48),
	copper = Color3.fromRGB(122, 74, 46),
	boiler = Color3.fromRGB(70, 50, 40),
	yellow = Color3.fromRGB(196, 150, 38),
	black = Color3.fromRGB(18, 18, 18),
	wood = Color3.fromRGB(92, 66, 44),
	puddle = Color3.fromRGB(10, 11, 12),
	water = Color3.fromRGB(22, 34, 36),
	cold = Color3.fromRGB(196, 214, 236),
	sodium = Color3.fromRGB(255, 168, 86),
	red = Color3.fromRGB(255, 36, 28),
	purple = Color3.fromRGB(150, 70, 255),
	deadBulb = Color3.fromRGB(60, 58, 50),
	signPlate = Color3.fromRGB(36, 34, 30),
	signText = Color3.fromRGB(214, 190, 120),
}

local C = Config.Colors

-- band: brick wainscot height above the floor; ribs: spacing of steel ribs;
-- chamfer: 45-degree cut along the floor edge; topChamfer: along the ceiling edge.
Config.Styles = {
	room = {
		wall = C.wall, wallMat = M.Concrete,
		band = 4, bandColor = C.brick, bandMat = M.Brick,
		upperColor = C.panel, upperMat = M.Metal,
		ribs = 6, chamfer = true, topChamfer = true,
	},
	hub = {
		wall = C.wall, wallMat = M.Concrete,
		band = 5.5, bandColor = C.brick, bandMat = M.Brick,
		upperColor = C.rust, upperMat = M.Slate,
		ribs = 3.6, chamfer = true, topChamfer = true,
	},
	corridor = {
		wall = C.wall, wallMat = M.Concrete,
		band = 3, bandColor = C.brickDark, bandMat = M.Brick,
		upperColor = C.panel, upperMat = M.Metal,
		chamfer = true, topChamfer = true,
	},
	ramp = { -- sloped corridors: no horizontal bands to fight the slope
		wall = C.wall, wallMat = M.Concrete,
		upperColor = C.panel, upperMat = M.Metal,
		topChamfer = true,
	},
	pit = {
		wall = C.pit, wallMat = M.Concrete,
		ribs = 3.4, chamfer = true,
	},
}

-- Applied to Lighting while the level exists, restored when it's cleared.
Config.Atmosphere = {
	Density = 0.42,
	Offset = 0.05,
	Color = Color3.fromRGB(70, 76, 84),
	Decay = Color3.fromRGB(30, 28, 32),
	Glare = 0,
	Haze = 2,
}
Config.Lighting = {
	Ambient = Color3.fromRGB(14, 14, 18),
	OutdoorAmbient = Color3.fromRGB(18, 18, 22),
}

return Config
