-- FactoryLevel
-- Procedural generator for the first descent: a dark, wet industrial factory.
--
-- FactoryLevel.build(base, seed?) -> room Model, item surface CFrame (world space)
--   base  floor-level CFrame at the centre of the elevator doors, +Z away from the elevator
--         (the same convention Levels.build uses)
--   seed  optional; a fresh one is rolled on every call so each descent differs
--
-- The plan follows the level-1 diagram (see Layout): start bay -> hub, with side rooms,
-- a multi-floor pit ring and the depot around it, and a loop back to the start corridor.
-- While the level exists it also:
--   * applies the factory fog/ambient light (Config.Atmosphere / Config.Lighting)
--   * hides the Baseplate, since the hub and pit sit below the elevator floor
--   * parks stray workspace props that sit inside the level's footprint
-- and puts all of that back when the room is destroyed.
--
-- Depot: players hold "Turn in" at the hopper to hand over the scavenged item they carry.
-- The item counts toward Elevator.DepotValue and goes to ServerStorage.DeliveredCargo,
-- the same place Cargo.server sends items when the shop crate isn't loaded.
-- Loot spots that didn't get the level's item are left as invisible "LootSpawn" parts
-- (CollectionService tag) for a future loot system.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(script.Config)
local Layout = require(script.Layout)
local Rooms = require(script.Rooms)
local G = require(script.Geometry)

local S = Config.Settings
local M = Enum.Material

local FactoryLevel = {}
FactoryLevel.Config = Config
FactoryLevel.Layout = Layout

-- ================= DEPOT =================
local function findScavenged(player)
	for _, container in { player.Character, player:FindFirstChild("Backpack") } do
		for _, tool in container and container:GetChildren() or {} do
			if tool:IsA("Tool") and tool:GetAttribute("ScavengedLevel") then
				return tool
			end
		end
	end
	return nil
end

local function hookDepot(depotModel, prompt, counter, glow)
	local total = 0
	depotModel:SetAttribute("DepositedValue", 0)
	prompt.Triggered:Connect(function(player)
		local tool = findScavenged(player)
		local handle = tool and tool:FindFirstChild("Handle")
		if not handle then
			return
		end
		local value = handle:GetAttribute("Value") or 0
		local item = handle:Clone()
		item.Name = tool.Name
		item.Anchored = true
		item.CanCollide = false
		item:SetAttribute("ScavengedLevel", tool:GetAttribute("ScavengedLevel"))
		-- Stored tells the elevator not to put the original back in the level.
		tool:SetAttribute("Stored", true)
		tool:Destroy()

		local folder = ServerStorage:FindFirstChild("DeliveredCargo")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "DeliveredCargo"
			folder.Parent = ServerStorage
		end
		item.Parent = folder

		total += value
		depotModel:SetAttribute("DepositedValue", total)
		local elevator = workspace:FindFirstChild("Elevator")
		if elevator then
			elevator:SetAttribute("DepotValue", (elevator:GetAttribute("DepotValue") or 0) + value)
		end
		counter.Text = "$" .. total
		glow.Brightness = 5
		task.delay(0.35, function()
			glow.Brightness = 1.6
		end)
	end)
end

-- ================= ENVIRONMENT =================
local function onCleared(room, fn)
	room.Destroying:Connect(fn)
end

-- The world's own lighting and baseplate are captured once, when no factory level owns
-- them, and only the level that currently owns them may put them back. (Destroying
-- handlers can run deferred, so a new level may be built before the old one's cleanup
-- runs; without this the "original" could be captured as the factory look.)
local environment = { owner = nil, saved = nil }

local function captureEnvironment()
	local saved = { lighting = {}, atmosphere = {}, baseplate = nil, textures = {} }
	for k in Config.Lighting do
		saved.lighting[k] = Lighting[k]
	end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		for k in Config.Atmosphere do
			saved.atmosphere[k] = atm[k]
		end
	end
	saved.atmosphereInstance = atm
	local bp = workspace:FindFirstChild("Baseplate")
	if bp and bp:IsA("BasePart") then
		saved.baseplate = bp
		saved.baseplateProps = { Transparency = bp.Transparency, CanCollide = bp.CanCollide, CanQuery = bp.CanQuery, CanTouch = bp.CanTouch }
		for _, d in bp:GetChildren() do
			if d:IsA("Decal") or d:IsA("Texture") then
				saved.textures[d] = d.Transparency
			end
		end
	end
	return saved
end

local function restoreEnvironment(saved)
	for k, v in saved.lighting do
		Lighting[k] = v
	end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if saved.atmosphereInstance then
		for k, v in saved.atmosphere do
			saved.atmosphereInstance[k] = v
		end
	elseif atm and atm:GetAttribute("FactoryMade") then
		atm:Destroy()
	end
	if saved.baseplate then
		for k, v in saved.baseplateProps do
			saved.baseplate[k] = v
		end
		for d, t in saved.textures do
			if d.Parent then
				d.Transparency = t
			end
		end
	end
end

local function applyEnvironment(room)
	if not environment.saved then
		environment.saved = captureEnvironment()
	end
	environment.owner = room

	for k, v in Config.Lighting do
		Lighting[k] = v
	end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atm then
		atm = Instance.new("Atmosphere")
		atm:SetAttribute("FactoryMade", true)
		atm.Parent = Lighting
	end
	for k, v in Config.Atmosphere do
		atm[k] = v
	end
	-- the hub and pit sit below the elevator floor, i.e. inside the baseplate
	local bp = environment.saved.baseplate
	if bp then
		bp.Transparency, bp.CanCollide, bp.CanQuery, bp.CanTouch = 1, false, false, false
		for d in environment.saved.textures do
			if d.Parent then
				d.Transparency = 1
			end
		end
	end

	onCleared(room, function()
		if environment.owner ~= room then
			return -- a newer level owns the environment now
		end
		restoreEnvironment(environment.saved)
		environment.owner = nil
		environment.saved = nil
	end)
end

-- Loose models/parts left in workspace inside the level's footprint would poke through
-- walls, so they're parked in ServerStorage while the level exists.
local function parkStrayProps(room, base, bounds)
	local folder, moved = nil, {}
	for _, child in workspace:GetChildren() do
		local eligible = child ~= room
			and (child:IsA("Model") or child:IsA("BasePart"))
			and not child:IsA("Terrain")
			and not child:IsA("SpawnLocation")
			and child.Name ~= "Elevator"
			and child.Name ~= "Baseplate"
			and not Players:GetPlayerFromCharacter(child)
			and not child:FindFirstChildOfClass("Humanoid")
		if eligible then
			local ok, cf, size = pcall(function()
				if child:IsA("Model") then
					return child:GetBoundingBox()
				end
				return child.CFrame, child.Size
			end)
			if ok and cf then
				local p = base:PointToObjectSpace(cf.Position)
				local r = size.Magnitude / 2
				if p.X > bounds.minx - r and p.X < bounds.maxx + r and p.Z > bounds.minz - r and p.Z < bounds.maxz + r and p.Y > bounds.miny - r and p.Y < bounds.maxy + r then
					if not folder then
						folder = Instance.new("Folder")
						folder.Name = "FactoryParkedProps"
						folder.Parent = ServerStorage
					end
					child.Parent = folder
					table.insert(moved, child)
				end
			end
		end
	end
	if folder then
		onCleared(room, function()
			for _, child in moved do
				if child.Parent == folder then
					child.Parent = workspace
				end
			end
			folder:Destroy()
		end)
	end
	return #moved
end

local function startFlicker(room, list, rng)
	if #list == 0 then
		return
	end
	local alive = true
	onCleared(room, function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			task.wait(rng:NextNumber(0.05, 0.3))
			local f = list[rng:NextInteger(1, #list)]
			if f.light.Parent then
				local on = rng:NextNumber() > 0.35
				f.light.Enabled = on
				f.bulb.Material = on and M.Neon or M.Glass
			end
		end
	end)
end

-- ================= BUILD =================
-- Rolls a plan from `seed`, re-rolling until nothing overlaps.
function FactoryLevel.plan(seed)
	local rng = Random.new(seed)
	for _ = 1, S.MaxAttempts do
		local plan = Layout.generate(rng)
		if plan and Layout.isClear(plan) then
			return plan, rng
		end
	end
	return nil, rng
end

function FactoryLevel.build(base, seed)
	seed = seed or Random.new():NextInteger(1, 2 ^ 30)
	local plan, rng = FactoryLevel.plan(seed)
	if not plan then
		seed = S.FallbackSeed
		plan, rng = FactoryLevel.plan(seed)
	end

	local room = Instance.new("Model")
	room.Name = "FactoryLevel"
	room:SetAttribute("Theme", "Factory")
	room:SetAttribute("Seed", seed)

	local ctx = { base = base, rng = rng, parts = 0, flicker = {}, loot = {} }
	Rooms.start(ctx, room, plan.start)
	Rooms.hub(ctx, room, plan.hub)
	Rooms.roomA(ctx, room, plan.roomA)
	Rooms.ring(ctx, room, plan.ring)
	Rooms.depot(ctx, room, plan.depot, hookDepot)
	Rooms.roomB(ctx, room, plan.roomB)
	local corridors = G.model(room, "Corridors")
	for _, name in { "c1", "c2", "c3", "c4", "c5", "c6" } do
		local cm = G.model(corridors, name)
		for i, leg in plan[name].legs do
			G.corridorLeg(ctx, cm, leg, "Leg" .. i)
		end
		for _, e in plan[name].elbows or {} do
			G.elbow(ctx, cm, e)
		end
	end

	-- The level's item goes on one primary loot spot; the rest become spawn markers.
	local primaries = {}
	for _, spot in ctx.loot do
		if spot.primary then
			table.insert(primaries, spot)
		end
	end
	local chosen = primaries[rng:NextInteger(1, #primaries)]
	room:SetAttribute("ItemArea", chosen.area)
	local markers = G.model(room, "LootSpawns")
	for _, spot in ctx.loot do
		if spot ~= chosen then
			local marker = G.mk(ctx, markers, "LootSpawn", Vector3.new(1, 1, 1), spot.cf * CFrame.new(0, 0.5, 0), Config.Colors.black, M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
			marker:SetAttribute("Area", spot.area)
			CollectionService:AddTag(marker, "LootSpawn")
		end
	end

	applyEnvironment(room)
	local parked = parkStrayProps(room, base, Layout.bounds(plan))
	startFlicker(room, ctx.flicker, rng)
	room:SetAttribute("PartCount", ctx.parts)
	room:SetAttribute("ParkedProps", parked)
	return room, base * chosen.cf
end

return FactoryLevel
