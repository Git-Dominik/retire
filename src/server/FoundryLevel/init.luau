-- FoundryLevel
-- Procedural generator for the first descent: a steel foundry.
--
-- FoundryLevel.build(base, seed?) -> room Model, item surface CFrame (world space)
--   base  floor-level CFrame at the centre of the elevator doors, +Z away from the elevator
--         (the convention Levels.build uses)
--   seed  optional; a fresh one is rolled on every call so every descent differs
--
-- Plan (see Layout): arrival bay -> melt shop hub (red) with the rolling mill and coil
-- yard (green), the multi-tier casting pit (blue in green) and the depot (purple) on
-- random sides of it, the hub pushed off-centre by a bent arrival corridor.
--
-- While the level exists it also:
--   * applies the foundry look: Atmosphere, ambient, Bloom and a colour grade
--     (Config.Atmosphere / Lighting / Bloom / Grade), with SunRays off
--   * hides the Baseplate, since the melt shop and pit sit below the elevator floor
--   * parks stray workspace props inside the level's footprint
--   * burns anyone standing in molten metal (Config.Settings.MoltenDamage per second)
-- and restores the world exactly when the room is destroyed.
--
-- Depot: holding "Turn in" at the hopper hands over the scavenged item a player carries.
-- It counts toward Elevator.DepotValue and goes to ServerStorage.DeliveredCargo (where
-- Cargo.server also sends items when the shop crate isn't loaded). Loot spots that didn't
-- get the level's item become invisible "LootSpawn" markers (CollectionService tag).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(script.Config)
local Layout = require(script.Layout)
local G = require(script.Geometry)
local buildHub = require(script.Hub)
local buildPit = require(script.Pit)
local Halls = require(script.Halls)

local S = Config.Settings
local M = Enum.Material

local FoundryLevel = {}
FoundryLevel.Config = Config
FoundryLevel.Layout = Layout

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
		glow.Brightness = 6
		task.delay(0.35, function()
			glow.Brightness = 1.8
		end)
	end)
end

-- ================= ENVIRONMENT =================
-- The world's own settings are captured once, while no foundry owns them, and only the
-- level that currently owns them may put them back (Destroying handlers can run deferred,
-- after the next level has already been built).
local environment = { owner = nil, saved = nil }

local function capture()
	local saved = { props = {}, textures = {}, made = {} }
	local function keep(inst, keys)
		if inst then
			local t = {}
			for k in keys do
				t[k] = inst[k]
			end
			saved.props[inst] = t
		end
	end
	keep(Lighting, Config.Lighting)
	keep(Lighting:FindFirstChildOfClass("Atmosphere"), Config.Atmosphere)
	keep(Lighting:FindFirstChildOfClass("BloomEffect"), Config.Bloom)
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then
		saved.props[rays] = { Enabled = rays.Enabled }
	end
	local bp = workspace:FindFirstChild("Baseplate")
	if bp and bp:IsA("BasePart") then
		saved.props[bp] = { Transparency = bp.Transparency, CanCollide = bp.CanCollide, CanQuery = bp.CanQuery, CanTouch = bp.CanTouch }
		for _, d in bp:GetChildren() do
			if d:IsA("Decal") or d:IsA("Texture") then
				saved.textures[d] = d.Transparency
			end
		end
		saved.baseplate = bp
	end
	return saved
end

local function restore(saved)
	for inst, props in saved.props do
		if inst.Parent then
			for k, v in props do
				inst[k] = v
			end
		end
	end
	for d, t in saved.textures do
		if d.Parent then
			d.Transparency = t
		end
	end
	for _, inst in saved.made do
		inst:Destroy()
	end
end

local function applyEnvironment(room)
	if not environment.saved then
		environment.saved = capture()
	end
	local saved = environment.saved
	environment.owner = room

	for k, v in Config.Lighting do
		Lighting[k] = v
	end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atm then
		atm = Instance.new("Atmosphere")
		atm.Parent = Lighting
		table.insert(saved.made, atm)
	end
	for k, v in Config.Atmosphere do
		atm[k] = v
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
		table.insert(saved.made, bloom)
	end
	for k, v in Config.Bloom do
		bloom[k] = v
	end
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then
		rays.Enabled = false
	end
	local grade = Lighting:FindFirstChild("FoundryGrade")
	if not grade then
		grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "FoundryGrade"
		grade.Parent = Lighting
		table.insert(saved.made, grade)
	end
	for k, v in Config.Grade do
		grade[k] = v
	end
	if saved.baseplate then
		local bp = saved.baseplate
		bp.Transparency, bp.CanCollide, bp.CanQuery, bp.CanTouch = 1, false, false, false
		for d in saved.textures do
			if d.Parent then
				d.Transparency = 1
			end
		end
	end

	room.Destroying:Connect(function()
		if environment.owner ~= room then
			return
		end
		restore(environment.saved)
		environment.owner = nil
		environment.saved = nil
	end)
end

-- Loose workspace models/parts inside the level's footprint would poke through walls,
-- so they're parked in ServerStorage while the level exists.
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
						folder.Name = "FoundryParkedProps"
						folder.Parent = ServerStorage
					end
					child.Parent = folder
					table.insert(moved, child)
				end
			end
		end
	end
	if folder then
		room.Destroying:Connect(function()
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

-- Flickering lamps and heat damage share one loop that stops when the level goes.
local function startLevelLoop(room, flicker, molten, rng)
	local alive = true
	room.Destroying:Connect(function()
		alive = false
	end)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { room }
	task.spawn(function()
		local nextBurn = 0
		while alive do
			local dt = task.wait(0.1)
			if #flicker > 0 and rng:NextNumber() < 0.6 then
				local f = flicker[rng:NextInteger(1, #flicker)]
				if f.light.Parent then
					local on = rng:NextNumber() > 0.35
					f.light.Enabled = on
					f.bulb.Material = on and M.Neon or M.Glass
				end
			end
			if S.MoltenDamage > 0 and room.Parent and os.clock() >= nextBurn then
				nextBurn = os.clock() + 0.25
				local burnt = {}
				for _, zone in molten do
					for _, part in workspace:GetPartsInPart(zone, params) do
						local character = part.Parent
						local humanoid = character and character:FindFirstChildOfClass("Humanoid")
						if humanoid and humanoid.Health > 0 and not burnt[humanoid] then
							burnt[humanoid] = true
							humanoid:TakeDamage(S.MoltenDamage * 0.25)
						end
					end
				end
			end
		end
	end)
end

-- ================= BUILD =================
function FoundryLevel.plan(seed)
	return Layout.plan(seed)
end

function FoundryLevel.build(base, seed)
	seed = seed or Random.new():NextInteger(1, 2 ^ 30)
	local plan, rng = Layout.plan(seed)
	if not plan then
		seed = S.FallbackSeed
		plan, rng = Layout.plan(seed)
	end

	local room = Instance.new("Model")
	room.Name = "FoundryLevel"
	room:SetAttribute("Theme", "Foundry")
	room:SetAttribute("Seed", seed)

	local ctx = { base = base, rng = rng, parts = 0, flicker = {}, loot = {}, molten = {} }
	Halls.start(ctx, room, plan.start)
	buildHub(ctx, room, plan.hub)
	buildPit(ctx, room, plan.pit)
	Halls.mill(ctx, room, plan.mill)
	Halls.yard(ctx, room, plan.yard)
	Halls.depot(ctx, room, plan.depot, hookDepot)
	local corridors = G.model(room, "Corridors")
	for name, spec in plan.corridors do
		G.corridor(ctx, corridors, spec, name)
	end

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
			local marker = G.mk(ctx, markers, "LootSpawn", Vector3.new(1, 1, 1), spot.cf * CFrame.new(0, 0.5, 0), Config.Colors.black, M.SmoothPlastic, G.HIDDEN)
			marker:SetAttribute("Area", spot.area)
			CollectionService:AddTag(marker, "LootSpawn")
		end
	end

	applyEnvironment(room)
	local parked = parkStrayProps(room, base, Layout.bounds(plan))
	startLevelLoop(room, ctx.flicker, ctx.molten, rng)
	room:SetAttribute("PartCount", ctx.parts)
	room:SetAttribute("ParkedProps", parked)
	room:SetAttribute("HasLoop", plan.corridors.link ~= nil)
	return room, base * chosen.cf
end

return FoundryLevel
