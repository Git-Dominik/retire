-- Customers for the pawn shop. During the day (workspace.Phase == "Day") a new one walks in
-- from CustomerSpawn every SPAWN_INTERVAL seconds, up to MAX_CUSTOMERS at once (more with
-- more players), while the store is in the world, the shop hasn't failed, and there's at
-- least one item on the shop furniture. At dusk
-- everyone drops what they're doing and walks out; at night nobody is here. If the store is
-- parked (the elevator went down) they vanish on the spot.
--
-- Each customer is a cosmetic NPC that looks like a random friend of someone in the server
-- (CustomerAvatar), shows that friend's display name, and is either a shoplifter
-- (ShoplifterService, odds rising each day) or a normal customer, run here:
--   Enter -> Decide (want an item) -> Browse the shop furniture in a random order ->
--   Found (take it off the shelf) -> ToCounter (a free CounterSpot or the line) -> Place ->
--   Offer / Negotiate (CounterService) -> Sold or NotSold -> Leave
-- Every step has a timeout and every customer a MAX_LIFETIME, so nobody gets stuck. A
-- normal customer never leaves with stock: whatever they hold goes back on the shelf
-- (CustomerUtil.restore) unless it was sold.
--
-- The server owns all of it; the hidden WillingToPay, Patience and type never leave it.
-- NPCs are server-owned (SetNetworkOwner(nil)), can't be hurt, and are in the "Customers"
-- collision group, which players can't touch. Clients only see:
--   Model tagged "Customer" in workspace.Customers, with attributes DisplayName, Bubble and
--   BubbleMood ("want", "happy", "sad", "annoyed"), drawn by CustomerVisuals.client.
-- Walkouts are reported to QuotaService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("ShopConfig"))
local StockItems = require(Shared:WaitForChild("StockItems"))
local CustomerUtil = require(script.Parent:WaitForChild("CustomerUtil"))
local CustomerAvatar = require(script.Parent:WaitForChild("CustomerAvatar"))
local CounterService = require(script.Parent:WaitForChild("CounterService"))
local ShoplifterService = require(script.Parent:WaitForChild("ShoplifterService"))
local QuotaService = require(script.Parent:WaitForChild("QuotaService"))

local customers = {} -- [customer] = true
local pending = 0 -- customers still being built
local queue = {} -- customers waiting for a counter spot, front first
local reserved = {} -- [item model] = the customer heading for it

local function isDay()
	return workspace:GetAttribute("Phase") == "Day"
end

-- Anything on the shop furniture for customers to come in for?
local function hasStock()
	for _, furniture in CustomerUtil.shopFurniture() do
		for _, slot in CustomerUtil.slotsOf(furniture) do
			if CustomerUtil.itemIn(slot) then
				return true
			end
		end
	end
	return false
end

local function canSpawn()
	return isDay() and CustomerUtil.storeOpen() and not QuotaService.failed() and hasStock()
end

local function maxCustomers()
	local extra = math.max(#Players:GetPlayers() - 1, 0)
	return math.min(
		Config.MAX_CUSTOMERS + extra * Config.MAX_CUSTOMERS_PER_EXTRA_PLAYER,
		Config.MAX_CUSTOMERS_CAP
	)
end

local function count()
	local n = pending
	for _ in customers do
		n += 1
	end
	return n
end

-- ================= LEAVING =================
-- Whatever a normal customer is holding goes back on the shelf, unless it was just sold.
-- A shoplifter's pocket is gone for good.
local function dropItems(customer)
	local carried = customer.carried
	customer.carried = nil
	if carried then
		reserved[carried.model] = nil
		local spot = customer.spot
		local sold = spot and spot.outcome and spot.outcome.kind == "sold"
		if sold then
			carried.model:Destroy()
		else
			CustomerUtil.restore(carried.model, carried.itemId, carried.slot, carried.furniture)
		end
	end
	for _, model in customer.pocket do
		model:Destroy()
	end
	table.clear(customer.pocket)
	for model, holder in reserved do
		if holder == customer then
			reserved[model] = nil
		end
	end
end

local function leaveQueue(customer)
	local index = table.find(queue, customer)
	if index then
		table.remove(queue, index)
	end
end

-- Stops the customer's current behaviour, unless that's what is calling.
local function stopThread(customer)
	local thread = customer.thread
	if thread and thread ~= coroutine.running() and coroutine.status(thread) == "suspended" then
		task.cancel(thread)
	end
end

-- Removes the customer at once and tidies up after them.
local function despawn(customer)
	if customer.gone then
		return
	end
	customer.gone = true
	stopThread(customer)
	leaveQueue(customer)
	dropItems(customer)
	CounterService.release(customer)
	customers[customer] = nil
	customer.model:Destroy()
end

-- Walks out through CustomerSpawn and despawns there (or wherever they are when the
-- walk times out).
local function walkOut(customer)
	customer.state = "Leave"
	local spawn = CustomerUtil.spawnPart()
	if spawn and CustomerUtil.storeOpen() then
		CustomerUtil.walkTo(customer, spawn.Position, Config.LEAVE_TIMEOUT)
	end
	despawn(customer)
end

-- Interrupts whatever the customer is doing and sends them out (dusk, overstaying).
local function sendHome(customer)
	if customer.gone or customer.sentHome then
		return
	end
	customer.sentHome = true
	stopThread(customer)
	leaveQueue(customer)
	dropItems(customer)
	CounterService.release(customer)
	customer.humanoid:MoveTo(customer.root.Position)
	CustomerUtil.say(customer, nil)
	customer.thread = task.spawn(walkOut, customer)
end

-- ================= NORMAL CUSTOMERS =================
local function shuffled(list)
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- What they've come in for: something on the shelves WANT_IN_STOCK_CHANCE of the time,
-- otherwise any item at all.
local function pickWanted()
	if math.random() < Config.WANT_IN_STOCK_CHANCE then
		local stocked = {}
		for _, furniture in CustomerUtil.shopFurniture() do
			for _, slot in CustomerUtil.slotsOf(furniture) do
				local model = CustomerUtil.itemIn(slot)
				if model and not reserved[model] then
					table.insert(stocked, model:GetAttribute("ItemId"))
				end
			end
		end
		if #stocked > 0 then
			return stocked[math.random(1, #stocked)]
		end
	end
	local ids = StockItems.ids()
	return ids[math.random(1, #ids)]
end

-- The first slot on the furniture holding the wanted item that nobody else is after.
local function findWanted(furniture, itemId)
	for _, slot in CustomerUtil.slotsOf(furniture) do
		local model = CustomerUtil.itemIn(slot)
		if model and model:GetAttribute("ItemId") == itemId and not reserved[model] then
			return slot, model
		end
	end
	return nil
end

local function holdInHand(customer, model)
	local hand = customer.model:FindFirstChild("RightHand") or customer.root
	CustomerUtil.tweenItem(model, hand.CFrame * CustomerUtil.handOffset(model))
	CustomerUtil.attach(model, hand, CustomerUtil.handOffset(model))
end

-- Visits each piece of shop furniture once, in a random order, looking for the wanted
-- item. Returns true holding it, or false having seen everything.
local function browse(customer)
	for _, furniture in shuffled(CustomerUtil.shopFurniture()) do
		local slots = CustomerUtil.slotsOf(furniture)
		local stand = slots[1] and CustomerUtil.standPoint(furniture, slots[1])
		if stand and CustomerUtil.walkTo(customer, stand) then
			CustomerUtil.face(customer, slots[1].Position)
			task.wait(CustomerUtil.randomRange(Config.BROWSE_PAUSE))
			local slot, model = findWanted(furniture, customer.wantedId)
			if slot then
				reserved[model] = customer
				customer.state = "Found"
				local itemStand = CustomerUtil.standPoint(furniture, slot)
				if itemStand then
					CustomerUtil.walkTo(customer, itemStand, 8)
				end
				CustomerUtil.face(customer, slot.Position)
				reserved[model] = nil
				-- Still there? Someone may have taken it on the way over.
				if CustomerUtil.itemIn(slot) == model then
					CustomerUtil.takeFromSlot(slot, customer.model)
					CustomerUtil.setGroup(model, "Customers")
					customer.carried = {
						model = model,
						itemId = customer.wantedId,
						slot = slot,
						furniture = furniture,
					}
					reserved[model] = customer
					holdInHand(customer, model)
					return true
				end
				customer.state = "Browse"
			end
		end
	end
	return false
end

-- Joins the line and waits to reach a free counter spot. Returns the spot, or nil after
-- QUEUE_TIMEOUT.
local function waitForSpot(customer)
	table.insert(queue, customer)
	local deadline = os.clock() + Config.QUEUE_TIMEOUT
	local walkedTo
	while os.clock() < deadline do
		local index = table.find(queue, customer)
		if index == 1 then
			local spot = CounterService.claimSpot(customer)
			if spot then
				leaveQueue(customer)
				return spot
			end
		end
		if index ~= walkedTo then
			walkedTo = index
			local point = CustomerUtil.queuePoint(index)
			if point then
				CustomerUtil.walkTo(customer, point, 10)
				local ahead = CustomerUtil.queuePoint(index - 1) or point
				CustomerUtil.face(customer, ahead)
			end
		else
			task.wait(0.5)
		end
	end
	leaveQueue(customer)
	return nil
end

local GOODBYES = {
	refused = { "Suit yourself.", "sad" },
	patience = { "I'm done haggling.", "annoyed" },
	timeout = { "Guess nobody's minding the shop.", "sad" },
	aborted = { "Never mind.", "sad" },
}

local function leaveUnsold(customer, text, mood)
	CustomerUtil.say(customer, text, mood)
	dropItems(customer)
	CounterService.release(customer)
	QuotaService.recordWalkout()
	task.wait(1.5)
	CustomerUtil.say(customer, nil)
end

local function runNormal(customer)
	customer.state = "Enter"
	CustomerUtil.walkTo(customer, CustomerUtil.entryPoint())

	customer.state = "Decide"
	customer.wantedId = pickWanted()
	local wanted = StockItems.get(customer.wantedId)
	CustomerUtil.say(customer, `Looking for: {wanted and wanted.name or customer.wantedId}`, "want")

	customer.state = "Browse"
	if not browse(customer) then
		customer.state = "NotFound"
		task.wait(Config.NOT_FOUND_WAIT)
		leaveUnsold(customer, "Nothing here for me...", "sad")
		return
	end
	CustomerUtil.say(customer, "Ah, there it is.", "happy", 2)

	customer.state = "ToCounter"
	local spot = waitForSpot(customer)
	if not spot then
		leaveUnsold(customer, "I can't wait all day.", "annoyed")
		return
	end
	CustomerUtil.say(customer, nil)
	local stand = CustomerUtil.counterStand(spot.part)
	CustomerUtil.walkTo(customer, stand, 12)
	CustomerUtil.face(customer, spot.part.Position)

	customer.state = "Place"
	local carried = customer.carried
	if not carried or not carried.model.Parent then
		leaveUnsold(customer, "Huh. Where'd it go?", "sad")
		return
	end
	CustomerUtil.tweenItem(carried.model, StockItems.restingCFrame(carried.itemId, spot.part))

	customer.state = "Negotiate"
	local outcome = CounterService.negotiate(customer, spot, carried.itemId)
	if outcome.kind == "sold" then
		customer.state = "Sold"
		CustomerUtil.say(customer, "Thank you!", "happy")
		dropItems(customer)
		CounterService.release(customer)
		task.wait(1.5)
		CustomerUtil.say(customer, nil)
	else
		customer.state = "NotSold"
		local goodbye = GOODBYES[outcome.kind] or GOODBYES.aborted
		leaveUnsold(customer, goodbye[1], goodbye[2])
	end
end

-- ================= SPAWNING =================
local function makeHarmless(model, humanoid)
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = Config.WALK_SPEED
	for _, state in
		{
			Enum.HumanoidStateType.Dead,
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Climbing,
			Enum.HumanoidStateType.Seated,
			Enum.HumanoidStateType.Swimming,
		}
	do
		humanoid:SetStateEnabled(state, false)
	end
	local shield = Instance.new("ForceField")
	shield.Visible = false
	shield.Parent = model
end

-- Idle while standing, walk while moving, played on the server so everyone sees them.
local function animate(humanoid, animations)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local function load(id)
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		return ok and track or nil
	end
	local idle, walk = load(animations.idle), load(animations.walk)
	if idle then
		idle.Looped = true
		idle:Play()
	end
	if walk then
		walk.Looped = true
		humanoid.Running:Connect(function(speed)
			if speed > 0.5 then
				if not walk.IsPlaying then
					walk:Play(0.2)
				end
				walk:AdjustSpeed(speed / 10)
			elseif walk.IsPlaying then
				walk:Stop(0.2)
			end
		end)
	end
end

local function facesInShop()
	local faces = {}
	for customer in customers do
		faces[customer.userId] = true
	end
	return faces
end

local function spawnCustomer()
	pending += 1
	local entry = CustomerAvatar.pick(facesInShop())
	local model, name, animations = CustomerAvatar.build(entry)
	pending -= 1
	local spawn = CustomerUtil.spawnPart()
	-- Building yields; the day may have ended meanwhile.
	if not model or not spawn or not canSpawn() then
		if model then
			model:Destroy()
		end
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		model:Destroy()
		return
	end

	local day = workspace:GetAttribute("DayNumber") or 1
	local shoplifter = math.random() < ShoplifterService.chance(day)
	local customer = {
		model = model,
		humanoid = humanoid,
		root = root,
		userId = entry.userId,
		shoplifter = shoplifter,
		willingToPay = CustomerUtil.randomRange(Config.WILLING_TO_PAY),
		pocket = {},
		state = "Spawn",
		spawnedAt = os.clock(),
	}

	model.Name = "Customer"
	model:SetAttribute("DisplayName", name)
	makeHarmless(model, humanoid)
	if shoplifter then
		ShoplifterService.addHat(model)
	end
	CustomerUtil.setGroup(model, "Customers")

	local ground = spawn.Position.Y - spawn.Size.Y / 2
	local height = humanoid.HipHeight + root.Size.Y / 2
	local position = Vector3.new(spawn.Position.X, ground + height, spawn.Position.Z)
	model:PivotTo(CFrame.lookAt(position, position + spawn.CFrame.LookVector))
	model.Parent = CustomerUtil.folder
	root:SetNetworkOwner(nil)
	CollectionService:AddTag(model, "Customer")
	animate(humanoid, animations)

	customers[customer] = true
	customer.thread = task.spawn(function()
		local ok, err = pcall(shoplifter and ShoplifterService.run or runNormal, customer)
		if not ok then
			warn(`[Customers] {customer.state}: {err}`)
			dropItems(customer)
			CounterService.release(customer)
		end
		walkOut(customer)
	end)
end

local nextSpawnAt = os.clock() + Config.FIRST_SPAWN_DELAY
task.spawn(function()
	while true do
		task.wait(0.5)
		if not canSpawn() then
			-- Opening up (dawn, the first item stocked) gives a moment before anyone arrives.
			nextSpawnAt = math.max(nextSpawnAt, os.clock() + Config.FIRST_SPAWN_DELAY)
		elseif os.clock() >= nextSpawnAt then
			nextSpawnAt = os.clock() + CustomerUtil.randomRange(Config.SPAWN_INTERVAL)
			if count() < maxCustomers() then
				task.spawn(spawnCustomer)
			end
		end
	end
end)

-- ================= WATCHERS =================
workspace:GetAttributeChangedSignal("Phase"):Connect(function()
	if isDay() then
		nextSpawnAt = os.clock() + Config.FIRST_SPAWN_DELAY
	else
		for customer in customers do
			sendHome(customer)
		end
	end
end)

-- The store went down with the elevator: there's nowhere for them to be.
CustomerUtil.store.AncestryChanged:Connect(function()
	if not CustomerUtil.storeOpen() then
		for customer in customers do
			despawn(customer)
		end
	end
end)

-- Overstayers are sent home; anyone who fell out of the world or can't get out is removed.
local sinceCheck = 0
RunService.Heartbeat:Connect(function(dt)
	sinceCheck += dt
	if sinceCheck < 1 then
		return
	end
	sinceCheck = 0
	local now = os.clock()
	for customer in customers do
		local age = now - customer.spawnedAt
		local lost = not customer.model.Parent
			or customer.root.Position.Y < workspace.FallenPartsDestroyHeight + 20
		if lost or age > Config.MAX_LIFETIME + Config.LEAVE_TIMEOUT + 5 then
			despawn(customer)
		elseif age > Config.MAX_LIFETIME then
			sendHome(customer)
		end
	end
end)

game:BindToClose(function()
	for customer in customers do
		despawn(customer)
	end
end)
