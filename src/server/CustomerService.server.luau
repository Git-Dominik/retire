-- Customers for the pawn shop. During the day (workspace.Phase == "Day") a new one walks in
-- from CustomerSpawn every SPAWN_INTERVAL seconds while the store is in the world and the
-- shop hasn't failed. There are never more customers than unsold items (on the shop
-- furniture or in a customer's hands), and never more than MAX_CUSTOMERS (more with more
-- players), so nobody comes to an empty shop. At dusk everyone drops what they're doing
-- and walks out; at night nobody is here. If the store is parked (the elevator went down)
-- they vanish on the spot.
--
-- Each customer is a cosmetic NPC that looks like a random friend of someone in the server
-- (CustomerAvatar), shows that friend's display name, and is either a shoplifter
-- (ShoplifterService, odds rising each day) or a normal customer, run here:
--   Enter -> Decide (want an item) -> Browse the shop furniture in a random order ->
--   Found (take it off the shelf) -> ToCounter (a free CounterSpot or the line) -> Place ->
--   Pay (CounterService rings it up by itself) -> Leave
-- Nobody has to be at the counter: the players' only job is keeping the shelves stocked.
-- Normal customers never want an item an active request (QuestService) is waiting for.
--
-- Request clients: on a request's due day QuestService hands over a client to send in
-- (takeDueVisit), who looks like the request's ClientUserId, has no hat and runs:
--   Enter -> Browse for the requested item ("Requested: <item>") -> Found -> ToCounter ->
--   Place -> Pay (a player holds Sell; CounterService.questCheckout) -> Leave
-- Not on any shelf after a full search, they watch the shelves for QUEST_NOT_FOUND_WAIT
-- (so an item stocked meanwhile still counts) before leaving. Leaving without the sale,
-- for any reason (not found, the counter wait, dusk, despawning, an error), fails the
-- request; the item goes back on a shelf as with any customer.
-- Every step has a timeout and every customer a MAX_LIFETIME, so nobody gets stuck. A
-- normal customer never leaves with stock: whatever they hold goes back on the shelf
-- (CustomerUtil.restore) unless it was sold.
--
-- The server owns all of it; whether a customer is a shoplifter never leaves it.
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
local QuestService = require(script.Parent:WaitForChild("QuestService"))

local customers = {} -- [customer] = true
local pending = 0 -- customers still being built
local queue = {} -- customers waiting for a counter spot, front first
local reserved = {} -- [item model] = the customer heading for it

local function isDay()
	return workspace:GetAttribute("Phase") == "Day"
end

-- The shop's unsold stock: items on the shop furniture, plus the ones customers have
-- picked up and are bringing to the counter.
local function stockCount()
	local n = 0
	for _, furniture in CustomerUtil.shopFurniture() do
		for _, slot in CustomerUtil.slotsOf(furniture) do
			if CustomerUtil.itemIn(slot) then
				n += 1
			end
		end
	end
	for customer in customers do
		if customer.carried then
			n += 1
		end
	end
	return n
end

local function shopOpen()
	return isDay() and CustomerUtil.storeOpen() and not QuotaService.failed()
end

local function canSpawn()
	return shopOpen() and stockCount() > 0
end

-- One customer per unsold item, up to the per-player limit.
local function maxCustomers()
	local extra = math.max(#Players:GetPlayers() - 1, 0)
	return math.min(
		stockCount(),
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
		if customer.sold then
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
	-- A request client gone without the sale has failed (a no-op once it's completed).
	if customer.quest then
		QuestService.fail(customer.quest)
	end
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
-- otherwise any item at all. Never an item a request is waiting for, so it isn't sold out
-- from under the request.
local function pickWanted()
	if math.random() < Config.WANT_IN_STOCK_CHANCE then
		local stocked = {}
		for _, furniture in CustomerUtil.shopFurniture() do
			for _, slot in CustomerUtil.slotsOf(furniture) do
				local model = CustomerUtil.itemIn(slot)
				local itemId = model and model:GetAttribute("ItemId")
				if model and not reserved[model] and not QuestService.isRequested(itemId) then
					table.insert(stocked, itemId)
				end
			end
		end
		if #stocked > 0 then
			return stocked[math.random(1, #stocked)]
		end
	end
	local ids = {}
	for _, id in StockItems.ids() do
		if not QuestService.isRequested(id) then
			table.insert(ids, id)
		end
	end
	if #ids == 0 then
		ids = StockItems.ids()
	end
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

-- Visits each piece of shop furniture once (or each in `list`), in a random order, looking
-- for the wanted item. Returns true holding it, or false having seen everything.
local function browse(customer, list)
	for _, furniture in shuffled(list or CustomerUtil.shopFurniture()) do
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

	customer.state = "Pay"
	if not CounterService.checkout(customer, spot, carried.itemId) then
		leaveUnsold(customer, "Never mind.", "sad")
		return
	end
	customer.state = "Sold"
	customer.sold = true
	CustomerUtil.say(customer, "Thank you!", "happy")
	dropItems(customer)
	CounterService.release(customer)
	task.wait(1.5)
	CustomerUtil.say(customer, nil)
end

-- ================= REQUEST CLIENTS =================
-- Shop furniture with the item on it that nobody is already after, or nil.
local function furnitureHolding(itemId)
	for _, furniture in CustomerUtil.shopFurniture() do
		if findWanted(furniture, itemId) then
			return furniture
		end
	end
	return nil
end

-- A request client's visit (see the header): no haggling and no queue-jumping, just the
-- requested item at the fixed reward, sold when a player holds Sell.
local function runQuest(customer)
	local quest = customer.quest
	customer.state = "Enter"
	CustomerUtil.walkTo(customer, CustomerUtil.entryPoint())

	customer.state = "Decide"
	customer.wantedId = quest.ItemId
	local wanted = StockItems.get(quest.ItemId)
	CustomerUtil.say(customer, `Requested: {wanted and wanted.name or quest.ItemId}`, "want")

	customer.state = "Browse"
	local found = browse(customer)
	-- Players may still be stocking it: keep an eye on the shelves before giving up.
	local deadline = os.clock() + Config.QUEST_NOT_FOUND_WAIT
	while not found and os.clock() < deadline do
		customer.state = "NotFound"
		task.wait(1)
		local furniture = furnitureHolding(quest.ItemId)
		if furniture then
			customer.state = "Browse"
			found = browse(customer, { furniture })
		end
	end
	if not found then
		QuestService.fail(quest)
		leaveUnsold(customer, "You didn't get it for me...", "sad")
		return
	end
	CustomerUtil.say(customer, "That's the one!", "happy", 2)

	customer.state = "ToCounter"
	local spot = waitForSpot(customer)
	if not spot then
		QuestService.fail(quest)
		leaveUnsold(customer, "I can't wait all day.", "annoyed")
		return
	end
	CustomerUtil.say(customer, nil)
	CustomerUtil.walkTo(customer, CustomerUtil.counterStand(spot.part), 12)
	CustomerUtil.face(customer, spot.part.Position)

	customer.state = "Place"
	local carried = customer.carried
	if not carried or not carried.model.Parent then
		QuestService.fail(quest)
		leaveUnsold(customer, "Huh. Where'd it go?", "sad")
		return
	end
	CustomerUtil.tweenItem(carried.model, StockItems.restingCFrame(carried.itemId, spot.part))

	customer.state = "Pay"
	CustomerUtil.say(customer, `As agreed: ${quest.RewardPrice}`, "want")
	if not CounterService.questCheckout(customer, spot, quest) then
		QuestService.fail(quest)
		leaveUnsold(customer, "I'll take my business elsewhere.", "annoyed")
		return
	end
	customer.state = "Sold"
	CustomerUtil.say(customer, "Exactly what I wanted. Thank you!", "happy")
	dropItems(customer)
	CounterService.release(customer)
	task.wait(1.5)
	CustomerUtil.say(customer, nil)
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

-- Sends in a customer: a random one, or the client of `quest` (a request due today).
-- Returns whether they made it in.
local function spawnCustomer(quest)
	pending += 1
	local entry = quest and { userId = quest.ClientUserId, name = quest.ClientName }
		or CustomerAvatar.pick(facesInShop())
	local model, name, animations = CustomerAvatar.build(entry)
	pending -= 1
	local spawn = CustomerUtil.spawnPart()
	-- Building yields; the day may have ended (or the request been settled) meanwhile.
	local stillWanted = if quest then shopOpen() and quest.Status == "Active" else canSpawn()
	if not model or not spawn or not stillWanted then
		if model then
			model:Destroy()
		end
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		model:Destroy()
		return false
	end

	local day = workspace:GetAttribute("DayNumber") or 1
	local shoplifter = not quest and math.random() < ShoplifterService.chance(day)
	local customer = {
		model = model,
		humanoid = humanoid,
		root = root,
		userId = entry.userId,
		shoplifter = shoplifter,
		quest = quest,
		pocket = {},
		state = "Spawn",
		spawnedAt = os.clock(),
	}

	model.Name = "Customer"
	-- A request client keeps the name the journal shows, even on a fallback face.
	model:SetAttribute("DisplayName", quest and quest.ClientName or name)
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
		local run = if quest
			then runQuest
			elseif shoplifter then ShoplifterService.run
			else runNormal
		local ok, err = pcall(run, customer)
		if not ok then
			warn(`[Customers] {customer.state}: {err}`)
			dropItems(customer)
			CounterService.release(customer)
		end
		walkOut(customer)
	end)
	return true
end

local nextSpawnAt = os.clock() + Config.FIRST_SPAWN_DELAY
task.spawn(function()
	while true do
		task.wait(0.5)
		-- A request client due now comes in on top of the usual customers.
		local quest = shopOpen() and QuestService.takeDueVisit()
		if quest then
			task.spawn(function()
				if not spawnCustomer(quest) then
					QuestService.visitNotStarted(quest)
				end
			end)
		end
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
