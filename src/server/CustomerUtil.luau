-- Shared plumbing for the shop's customer NPCs (CustomerService, ShoplifterService and
-- CounterService all use it): the helper parts in the store, collision groups, walking
-- with PathfindingService (every path swept for collisions first), and moving stock items between shelf slots, hands and the
-- counter. Holds no customer state of its own.
--
-- Helper parts, all invisible, anchored and inside the Grocery Store model so they move
-- with it. Each is made from the store's geometry on first use if it isn't in the place:
--   CustomerSpawn     on the street outside the front door (from DoorTrigger); its
--                     LookVector points into the shop. Customers arrive and leave here.
--   CounterSpot_<n>   on the Service Counter's top, where a customer sets their item down.
--                     LookVector faces the clerk's side; the customer stands opposite.
--   CustomerQueue     where the line for the counter starts; it runs along its LookVector.
-- Stock: StockFurniture models with StockSlot children (Occupied, SlotIndex), each
-- occupied slot holding a "StockedItem" model with an ItemId attribute (StockingService).
-- Taking or returning an item here keeps Occupied and the furniture's FreeSlots current.
--
-- Collision groups: "Customers" (every NPC part and anything they carry) and "Players"
-- (every player character part, set here) never collide with each other, and customers
-- don't collide with one another.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))
local StockItems = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StockItems"))

local CustomerUtil = {}

local store = workspace:WaitForChild("Grocery Store")
CustomerUtil.store = store

local folder = Instance.new("Folder")
folder.Name = "Customers"
folder.Parent = workspace
CustomerUtil.folder = folder

-- The store is parked in ServerStorage while the elevator is down a floor.
function CustomerUtil.storeOpen()
	return store.Parent == workspace
end

-- ================= COLLISION GROUPS =================
PhysicsService:RegisterCollisionGroup("Customers")
PhysicsService:RegisterCollisionGroup("Players")
PhysicsService:CollisionGroupSetCollidable("Customers", "Players", false)
PhysicsService:CollisionGroupSetCollidable("Customers", "Customers", false)

-- Puts every part under the instance, now and later, in the collision group.
function CustomerUtil.setGroup(instance, group)
	local function set(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
	set(instance)
	for _, d in instance:GetDescendants() do
		set(d)
	end
	return instance.DescendantAdded:Connect(set)
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(function(character)
		CustomerUtil.setGroup(character, "Players")
	end)
	if player.Character then
		CustomerUtil.setGroup(player.Character, "Players")
	end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, player in Players:GetPlayers() do
	watchPlayer(player)
end

-- ================= GEOMETRY =================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

-- The floor under a point (searched from a little above it), or nil.
function CustomerUtil.floorBelow(position, above)
	local filter = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = filter
	local origin = position + Vector3.new(0, above or 3, 0)
	local hit = workspace:Raycast(origin, Vector3.new(0, -30, 0), rayParams)
	return hit and hit.Position or nil
end

local function insidePart(part, position)
	local offset = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(offset.X) <= half.X
		and math.abs(offset.Y) <= half.Y
		and math.abs(offset.Z) <= half.Z
end

local function helperPart(name, size, cframe)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Parent = store
	return p
end

-- The way out of the front door: DoorTrigger's thin axis, pointing away from the shop
-- floor (AmbienceZone).
local function doorOutward()
	local trigger = store:FindFirstChild("DoorTrigger", true)
	local zone = store:FindFirstChild("AmbienceZone", true)
	if not trigger then
		return nil
	end
	local size = trigger.Size
	local axis = size.X <= size.Z and trigger.CFrame.RightVector or trigger.CFrame.LookVector
	if zone and axis:Dot(trigger.Position - zone.Position) < 0 then
		axis = -axis
	end
	return trigger, axis
end

function CustomerUtil.spawnPart()
	local spawn = store:FindFirstChild("CustomerSpawn", true)
	if spawn then
		return spawn
	end
	local trigger, outward = doorOutward()
	if not trigger then
		warn("[Customers] No CustomerSpawn or DoorTrigger in the store")
		return nil
	end
	local point = trigger.Position + outward * 7
	local floor = CustomerUtil.floorBelow(point, 2) or point
	local position = floor + Vector3.new(0, 0.1, 0)
	return helperPart(
		"CustomerSpawn",
		Vector3.new(2, 0.2, 2),
		CFrame.lookAt(position, position - outward)
	)
end

-- A spot just inside the front door, the first place customers walk to.
function CustomerUtil.entryPoint()
	local trigger, outward = doorOutward()
	if not trigger then
		local spawn = CustomerUtil.spawnPart()
		return spawn and spawn.Position + spawn.CFrame.LookVector * 10
	end
	local point = trigger.Position - outward * 5
	return CustomerUtil.floorBelow(point, 2) or point
end

-- Every CounterSpot_<n> part, in order. Two are made on the Service Counter if none exist.
function CustomerUtil.counterSpots()
	local spots = {}
	for _, d in store:GetDescendants() do
		local index = d:IsA("BasePart") and tonumber(d.Name:match("^CounterSpot_(%d+)$"))
		if index then
			table.insert(spots, { part = d, index = index })
		end
	end
	if #spots == 0 then
		local counter = store:FindFirstChild("Service Counter", true)
		local zone = store:FindFirstChild("AmbienceZone", true)
		if not counter then
			warn("[Customers] No CounterSpot parts and no Service Counter in the store")
			return spots
		end
		local cf, size = counter:GetBoundingBox()
		-- The clerk's side is the one facing away from the middle of the shop.
		local toShop = zone and (zone.Position - cf.Position) or cf.LookVector
		local clerk = cf.LookVector:Dot(toShop) > 0 and -cf.LookVector or cf.LookVector
		local top = cf.Position.Y + size.Y / 2
		for i, along in { -0.25, 0.15 } do
			local base = cf.Position + cf.RightVector * size.X * along - clerk * (size.Z / 2 - 0.5)
			local position = Vector3.new(base.X, top + 0.6, base.Z)
			local p = helperPart(
				`CounterSpot_{i}`,
				Vector3.new(1.4, 1.2, 0.7),
				CFrame.lookAt(position, position + clerk)
			)
			table.insert(spots, { part = p, index = i })
		end
	end
	table.sort(spots, function(a, b)
		return a.index < b.index
	end)
	return spots
end

-- Where a customer stands to use a counter spot.
function CustomerUtil.counterStand(spot)
	local point = spot.Position - spot.CFrame.LookVector * Config.COUNTER_STAND_DISTANCE
	return CustomerUtil.floorBelow(point, 0) or point
end

-- The start of the counter line and the direction it runs. Made beside the counter's
-- customer side if missing.
function CustomerUtil.queuePart()
	local queue = store:FindFirstChild("CustomerQueue", true)
	if queue then
		return queue
	end
	local spots = CustomerUtil.counterSpots()
	local first = spots[1] and spots[1].part
	if not first then
		return nil
	end
	local stand = CustomerUtil.counterStand(first)
	local along = -first.CFrame.RightVector
	local position = stand + along * Config.QUEUE_SPACING * 1.5 + Vector3.new(0, 0.1, 0)
	return helperPart(
		"CustomerQueue",
		Vector3.new(2, 0.2, 2),
		CFrame.lookAt(position, position + along)
	)
end

function CustomerUtil.queuePoint(index)
	local queue = CustomerUtil.queuePart()
	if not queue then
		return nil
	end
	local point = queue.Position + queue.CFrame.LookVector * Config.QUEUE_SPACING * (index - 1)
	return CustomerUtil.floorBelow(point, 1) or point
end

-- ================= FURNITURE =================
-- A furniture's StockSlot parts in SlotIndex order.
function CustomerUtil.slotsOf(furniture)
	local slots = {}
	for _, child in furniture:GetChildren() do
		if CollectionService:HasTag(child, "StockSlot") then
			table.insert(slots, child)
		end
	end
	table.sort(slots, function(a, b)
		return (a:GetAttribute("SlotIndex") or 0) < (b:GetAttribute("SlotIndex") or 0)
	end)
	return slots
end

-- Same count StockingService keeps; its Stock prompt hides at 0.
function CustomerUtil.updateFreeSlots(furniture)
	local free = 0
	for _, slot in CustomerUtil.slotsOf(furniture) do
		if not slot:GetAttribute("Occupied") then
			free += 1
		end
	end
	furniture:SetAttribute("FreeSlots", free)
end

-- Shop-floor furniture customers may browse: inside the shop (SHOP_ZONE), not in a back
-- room (STAFF_ZONES), and not marked StaffOnly (the shelves behind the service counter).
function CustomerUtil.shopFurniture()
	local shopZone = store:FindFirstChild(Config.SHOP_ZONE, true)
	local zones = {}
	for _, name in Config.STAFF_ZONES do
		local zone = store:FindFirstChild(name, true)
		if zone then
			table.insert(zones, zone)
		end
	end
	local list = {}
	for _, furniture in CollectionService:GetTagged("StockFurniture") do
		if furniture:IsDescendantOf(store) then
			local slots = CustomerUtil.slotsOf(furniture)
			local staff = #slots == 0
				or furniture:GetAttribute("StaffOnly") == true
				or (shopZone and not insidePart(shopZone, slots[1].Position))
			for _, zone in zones do
				if slots[1] and insidePart(zone, slots[1].Position) then
					staff = true
				end
			end
			if not staff then
				table.insert(list, furniture)
			end
		end
	end
	return list
end

-- The stocked item model in a slot, if the slot holds one.
function CustomerUtil.itemIn(slot)
	if not slot:GetAttribute("Occupied") then
		return nil
	end
	local model = slot:FindFirstChild("StockedItem")
	return model and model:GetAttribute("ItemId") and model or nil
end

-- Where to stand in front of a slot: out along its facing until clear of the furniture.
function CustomerUtil.standPoint(furniture, slot)
	local cf, size = furniture:GetBoundingBox()
	local facing = slot.CFrame.LookVector * Vector3.new(1, 0, 1)
	if facing.Magnitude < 0.1 then
		return nil
	end
	facing = facing.Unit
	local gap = Config.FURNITURE_STAND_GAP
	for t = 0, 14, 0.25 do
		local point = slot.Position + facing * t
		local localPoint = cf:PointToObjectSpace(point)
		if
			math.abs(localPoint.X) > size.X / 2 + gap
			or math.abs(localPoint.Z) > size.Z / 2 + gap
		then
			return CustomerUtil.floorBelow(Vector3.new(point.X, cf.Position.Y, point.Z), size.Y / 2)
		end
	end
	return nil
end

-- ================= ITEMS =================
local itemTweens = setmetatable({}, { __mode = "k" }) -- [model] = the tween moving it

local function setParts(model, fn)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			fn(d)
		end
	end
end

-- Lets go of an item: no carry welds, anchored where it is, no tween running.
function CustomerUtil.release(model)
	local tween = itemTweens[model]
	if tween then
		itemTweens[model] = nil
		tween:Cancel()
	end
	for _, d in model:GetDescendants() do
		if d.Name == "CarryWeld" then
			d:Destroy()
		end
	end
	setParts(model, function(p)
		p.Anchored = true
		p.Massless = false
	end)
end

-- Slides an item to a CFrame (anchored) and returns once it's there.
function CustomerUtil.tweenItem(model, goal)
	CustomerUtil.release(model)
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local tween = TweenService:Create(
		value,
		TweenInfo.new(Config.ITEM_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = goal }
	)
	itemTweens[model] = tween
	tween:Play()
	local done = tween.Completed:Wait()
	value:Destroy()
	if itemTweens[model] == tween then
		itemTweens[model] = nil
	end
	return done == Enum.PlaybackState.Completed
end

-- Welds an item to a body part at the given offset (unanchored, so it moves with them).
function CustomerUtil.attach(model, part, offset)
	CustomerUtil.release(model)
	model:PivotTo(part.CFrame * offset)
	setParts(model, function(p)
		local weld = Instance.new("WeldConstraint")
		weld.Name = "CarryWeld"
		weld.Part0 = part
		weld.Part1 = p
		weld.Parent = p
		p.Massless = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Anchored = false
	end)
	-- Welding rebuilds the assembly, which hands it back to automatic ownership.
	local root = part.AssemblyRootPart
	if root and not root.Anchored then
		root:SetNetworkOwner(nil)
	end
end

-- Held in front of the right hand, centred on it.
function CustomerUtil.handOffset(model)
	local size = model:GetExtentsSize()
	return CFrame.new(0, -size.Y / 2, -(size.Z / 2 + 0.2))
end

-- Lifts the item out of its slot. Returns the model, or nil if the slot was empty.
function CustomerUtil.takeFromSlot(slot, newParent)
	local model = CustomerUtil.itemIn(slot)
	if not model then
		return nil
	end
	model.Parent = newParent
	slot:SetAttribute("Occupied", false)
	CustomerUtil.updateFreeSlots(slot.Parent)
	return model
end

local function putInSlot(model, itemId, slot)
	CustomerUtil.release(model)
	setParts(model, function(p)
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = true
		p.CollisionGroup = "Default"
	end)
	model:PivotTo(StockItems.restingCFrame(itemId, slot))
	model.Parent = slot
	slot:SetAttribute("Occupied", true)
	CustomerUtil.updateFreeSlots(slot.Parent)
end

-- Puts a customer's item back on the shelf: its own slot if that's still empty, else the
-- furniture's first free slot. If neither works the item is deleted with a warning.
function CustomerUtil.restore(model, itemId, slot, furniture)
	if slot and slot.Parent and not slot:GetAttribute("Occupied") then
		putInSlot(model, itemId, slot)
		return true
	end
	if furniture and furniture.Parent then
		for _, other in CustomerUtil.slotsOf(furniture) do
			if
				not other:GetAttribute("Occupied")
				and StockItems.fits(itemId, other:GetAttribute("SlotSize"))
			then
				putInSlot(model, itemId, other)
				return true
			end
		end
	end
	warn(
		`[Customers] No free slot to return {itemId} to on {furniture and furniture.Name}; deleting it`
	)
	model:Destroy()
	return false
end

-- ================= WALKING =================
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- The navmesh is coarse, so a computed path can cut a corner through a wall or a piece
-- of furniture, and a customer walking it gets stuck. Each leg is swept with a sphere at
-- knee and chest height against everything a customer collides with (the collision
-- group leaves out players and other customers) before anyone walks it. A blocked leg
-- gets a detour point beside whatever it hit, if one with both halves clear is near.
local PATH_PROBES = { { height = 1.3, radius = 0.8 }, { height = 3.2, radius = 1 } }
local AGENT_RADII = { 1.2, 2 } -- tried in order until a path comes out clear
local DETOUR_OFFSETS = { 1.5, 2.5, 3.5 } -- studs from the hit point
local MAX_DETOURS = 4 -- per route

local sweepParams = RaycastParams.new()
sweepParams.FilterType = Enum.RaycastFilterType.Exclude
sweepParams.RespectCanCollide = true
sweepParams.CollisionGroup = "Customers"

-- What a customer walking the floor-level line from `from` to `to` would bump into
-- first, or nil if they fit.
local function legHit(from, to)
	local delta = to - from
	if delta.Magnitude < 0.05 then
		return nil
	end
	sweepParams.FilterDescendantsInstances = { folder }
	for _, probe in PATH_PROBES do
		local origin = from + Vector3.new(0, probe.height, 0)
		local hit = workspace:Spherecast(origin, probe.radius, delta, sweepParams)
		if hit then
			return hit
		end
	end
	return nil
end

-- A floor point beside the obstacle that blocked from -> to, with both halves clear.
local function detour(from, to, hit)
	local along = flat(to - from)
	if along.Magnitude < 0.05 then
		return nil
	end
	local side = Vector3.new(-along.Z, 0, along.X).Unit
	local base = Vector3.new(hit.Position.X, (from.Y + to.Y) / 2, hit.Position.Z)
	for _, offset in DETOUR_OFFSETS do
		for _, direction in { flat(hit.Normal), side, -side } do
			if direction.Magnitude > 0.1 then
				local floor = CustomerUtil.floorBelow(base + direction.Unit * offset, 2)
				if
					floor
					and math.abs(floor.Y - base.Y) < 1
					and not legHit(from, floor)
					and not legHit(floor, to)
				then
					return floor
				end
			end
		end
	end
	return nil
end

-- The points with detours added where a leg is blocked, or nil if one can't be fixed.
local function cleared(feet, points)
	local route = table.clone(points)
	local from, i, detours = feet, 1, 0
	while i <= #route do
		local hit = legHit(from, route[i])
		if hit then
			detours += 1
			local point = detours <= MAX_DETOURS and detour(from, route[i], hit)
			if not point then
				return nil
			end
			table.insert(route, i, point)
		end
		from = route[i]
		i += 1
	end
	return route
end

-- Floor-level points to walk through to reach target, every leg checked clear, or nil if
-- there's no clear way there.
local function clearRoute(feet, target)
	for _, radius in AGENT_RADII do
		local path = PathfindingService:CreatePath({
			AgentRadius = radius,
			AgentHeight = 5,
			AgentCanJump = false,
			WaypointSpacing = 3,
		})
		local ok = pcall(function()
			path:ComputeAsync(feet, target)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			local points = {}
			for i, waypoint in path:GetWaypoints() do
				if i > 1 then
					table.insert(points, waypoint.Position)
				end
			end
			local route = #points > 0 and cleared(feet, points)
			if route then
				return route
			end
		end
	end
	-- Pathfinding can fail over short hops it should manage; a clear straight line will do.
	return cleared(feet, { CustomerUtil.floorBelow(target, 1) or target })
end

-- Walks a customer to a point along a path checked for collisions first. With no clear
-- way there they don't move at all. Gives up after `timeout` seconds or when they stop
-- making progress. Returns whether they ended up within `reach` studs of it.
function CustomerUtil.walkTo(customer, target, timeout, reach)
	reach = reach or 2
	local humanoid, root = customer.humanoid, customer.root
	local deadline = os.clock() + (timeout or Config.WALK_TIMEOUT)
	local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local points = clearRoute(feet, target)
	if not points then
		return (flat(root.Position - target)).Magnitude <= reach
	end

	for i, point in points do
		local last = i == #points
		local lastPosition, stillSince = root.Position, os.clock()
		humanoid:MoveTo(point)
		local issued = os.clock()
		while (flat(root.Position - point)).Magnitude > (last and reach * 0.5 or 1.5) do
			if os.clock() > deadline or os.clock() - stillSince > 2.5 then
				humanoid:MoveTo(root.Position)
				return (flat(root.Position - target)).Magnitude <= reach
			end
			task.wait(0.1)
			if (root.Position - lastPosition).Magnitude > 0.3 then
				lastPosition, stillSince = root.Position, os.clock()
			end
			-- MoveTo gives up on its own after 8 seconds.
			if os.clock() - issued > 6 then
				humanoid:MoveTo(point)
				issued = os.clock()
			end
		end
	end
	return (flat(root.Position - target)).Magnitude <= reach
end

-- Turns a customer on the spot to look at a point.
function CustomerUtil.face(customer, point)
	local root = customer.root
	local flatPoint = Vector3.new(point.X, root.Position.Y, point.Z)
	if (flatPoint - root.Position).Magnitude > 0.05 then
		root.CFrame = CFrame.lookAt(root.Position, flatPoint)
	end
end

-- ================= BUBBLES =================
-- The speech bubble is the customer model's Bubble / BubbleMood attributes (drawn by
-- CustomerVisuals.client). A timed bubble falls back to the customer's standing one.
function CustomerUtil.say(customer, text, mood, duration)
	local token = {}
	customer.bubbleToken = token
	if not duration then
		customer.standingBubble = text and { text, mood } or nil
	end
	customer.model:SetAttribute("Bubble", text)
	customer.model:SetAttribute("BubbleMood", mood)
	if duration then
		task.delay(duration, function()
			if customer.bubbleToken == token and customer.model.Parent then
				local standing = customer.standingBubble
				customer.model:SetAttribute("Bubble", standing and standing[1])
				customer.model:SetAttribute("BubbleMood", standing and standing[2])
			end
		end)
	end
end

function CustomerUtil.randomRange(range)
	return range[1] + math.random() * (range[2] - range[1])
end

return CustomerUtil
