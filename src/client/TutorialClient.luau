-- The first-time tutorial: a bobbing gold arrow leads a new player through their first
-- night and morning, one step at a time, and the thing to use glows gold (a Highlight;
-- no on-screen panel, the owner found it ugly). Every step ticks off from state other scripts already publish, so
-- it keeps up with whatever other players do in the same server:
--   1. take the journal (HasJournal, Journal.server)
--   2. read the boss's note on the break room table (ReadBossNote, set by BossNote.client)
--   3. call the elevator (Elevator DoorState / Level)
--   4. choose a floor on the floor selector (Elevator Level)
--   5. send three loads up the cargo lift (Elevator CargoTripsLeft): the arrow goes to the
--      nearest floor item, then the lift car, then the send button, and round again
--   6. ride back up to the shop
--   7. stock the shop: the nearest item on the storage racks, then the nearest furniture
--      it fits (StockingClient's StockPrompt), until the shop is full or the racks are empty
-- A step only leads while it can be done where the player is (the journal and note stay in
-- the store), so someone who joins mid-night starts on the lift and comes back for them.
--
-- Whether it has been played is saved per player by Tutorial.server: the TutorialDone
-- attribute (unset while loading) and the TutorialFinished remote fired at the end.
-- Nothing runs while it's true. Required by Journal.client, whose To do page shows
-- TutorialClient.todoText(). The arrow and highlight hide while the journal (ReadingJournal) or the
-- note (ReadingNote) is open and during a ride.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local finishedRemote = ReplicatedStorage:WaitForChild("TutorialFinished")

-- How long the stocking step waits after arriving back before it can finish, so racks and
-- furniture still streaming in don't read as empty.
local STOCK_SETTLE = 3
local CHECK_INK = "#701e1a"

local TutorialClient = {}

-- ================= WORLD STATE =================
local function elevator()
	return workspace:FindFirstChild("Elevator")
end

local function level()
	local e = elevator()
	return e and e:GetAttribute("Level") or 0
end

local function elevatorChild(...)
	local instance = elevator()
	for _, name in { ... } do
		instance = instance and instance:FindFirstChild(name)
	end
	return instance
end

local function liftAttribute(name)
	local lift = elevatorChild("CargoLift")
	return lift and lift:GetAttribute(name) or 0
end

local function tripsLeft()
	local e = elevator()
	return e and e:GetAttribute("CargoTripsLeft") or 0
end

-- The lift is away from the slot from its send until the car is back with the gate up
-- (Cargo.server's timing attributes).
local function liftBusy()
	local tripTime = liftAttribute("PressLead")
		+ liftAttribute("GateTime") * 2
		+ liftAttribute("RideTime")
		+ liftAttribute("TopPause")
		+ liftAttribute("ReturnTime")
	return liftAttribute("SendSeq") > 0
		and workspace:GetServerTimeNow() - liftAttribute("SendAt") < tripTime
end

local function heldTools()
	local tools = {}
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		for _, child in container and container:GetChildren() or {} do
			if child:IsA("Tool") then
				table.insert(tools, child)
			end
		end
	end
	return tools
end

local function carrying(attribute)
	for _, tool in heldTools() do
		if tool:GetAttribute(attribute) then
			return true
		end
	end
	return false
end

local function rootPosition()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function positionOf(instance)
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return instance.Position
end

local function nearest(candidates)
	local from = rootPosition()
	if not from then
		return nil
	end
	local best, bestDistance
	for _, candidate in candidates do
		local distance = (positionOf(candidate) - from).Magnitude
		if not bestDistance or distance < bestDistance then
			best, bestDistance = candidate, distance
		end
	end
	return best
end

local function store()
	return workspace:FindFirstChild("Grocery Store")
end

-- ================= STEP TARGETS =================
local function journalCover()
	local stand = CollectionService:GetTagged("JournalStand")[1]
	local book = stand and stand:FindFirstChild("Journal")
	return book and book:FindFirstChild("Cover")
end

local function callPlate()
	local s = store()
	local panel = s and s:FindFirstChild("Call Panel", true)
	return panel and panel:FindFirstChild("Call Plate")
end

-- Elevator.server tags every floor item; taking one disables its prompt until it's back.
local function floorLoot()
	local items = {}
	for _, item in CollectionService:GetTagged("ScavengeItem") do
		local prompt = item:FindFirstChild("TakePrompt")
		if prompt and prompt.Enabled then
			table.insert(items, item)
		end
	end
	return items
end

local function scavengeGuide()
	if carrying("ScavengedLevel") then
		return elevatorChild("CargoLift", "Car"),
			liftBusy() and "Wait for the lift to come back" or "Load it onto the cargo lift"
	end
	if liftAttribute("CargoValue") > 0 and not liftBusy() then
		local left = tripsLeft()
		return elevatorChild("CargoLift", "SendButton"),
			`Send it up ({left} {left == 1 and "load" or "loads"} left)`
	end
	local item = nearest(floorLoot())
	if item then
		return item, `Take the {item.Name}`
	end
	local selector = elevatorChild("FloorSelector")
	if selector and not selector:GetAttribute("Locked") then
		return selector, "Nothing left here. Try another floor"
	end
	return nil
end

-- Shop furniture players can stock: it has a Stock prompt (the storage room's large
-- shelves only take cargo, so they have none).
local function shopFurniture()
	local list = {}
	for _, model in CollectionService:GetTagged("StockFurniture") do
		local prompt = model:FindFirstChild("StockPrompt", true)
		if prompt then
			table.insert(list, { model = model, prompt = prompt })
		end
	end
	return list
end

-- Everything waiting to go out on the shop floor: items on the storage racks' boards, on
-- the large shelves' slots, and anything dropped.
local function waitingStock()
	local list = {}
	for _, tag in { "RackItem", "DroppedItem" } do
		for _, item in CollectionService:GetTagged(tag) do
			table.insert(list, item)
		end
	end
	for _, slot in CollectionService:GetTagged("StockSlot") do
		local racks = slot:FindFirstAncestor("StorageRacks")
		if racks and slot:GetAttribute("Occupied") then
			table.insert(list, slot)
		end
	end
	return list
end

local function shopHasRoom()
	for _, entry in shopFurniture() do
		if (entry.model:GetAttribute("FreeSlots") or 0) > 0 then
			return true
		end
	end
	return false
end

local function stockGuide()
	if carrying("ShopItem") then
		-- StockingClient enables a furniture's prompt only where the held item fits.
		local points = {}
		for _, entry in shopFurniture() do
			if entry.prompt.Enabled and entry.prompt.Parent then
				table.insert(points, entry.prompt.Parent)
			end
		end
		local point = nearest(points)
		return point, point and "Stock it here"
	end
	local item = nearest(waitingStock())
	return item, item and "Take it off the rack"
end

-- ================= STEPS =================
local wentDown = false
local stockSince

local function atStore()
	return level() == 0
end

local function onFloor()
	return level() >= 1
end

local STEPS = {
	{
		id = "journal",
		task = "Take the journal",
		available = atStore,
		done = function()
			return player:GetAttribute("HasJournal") == true
		end,
		guide = function()
			return journalCover(), "Take the journal"
		end,
	},
	{
		id = "note",
		task = "Read the boss's note",
		available = atStore,
		done = function()
			return player:GetAttribute("ReadBossNote") == true
		end,
		guide = function()
			return CollectionService:GetTagged("BossNote")[1], "Read the note"
		end,
	},
	{
		id = "call",
		task = "Call the elevator",
		available = atStore,
		done = function()
			local e = elevator()
			return level() > 0 or (e ~= nil and e:GetAttribute("DoorState") == "Open")
		end,
		guide = function()
			return callPlate(), "Call the elevator"
		end,
	},
	{
		id = "ride",
		task = "Choose a floor on the floor selector",
		available = function()
			return true
		end,
		done = onFloor,
		guide = function()
			return elevatorChild("FloorSelector"), "Choose a floor"
		end,
	},
	{
		id = "scavenge",
		task = "Send three loads up the cargo lift",
		available = onFloor,
		done = function()
			return tripsLeft() == 0 or (wentDown and atStore())
		end,
		guide = scavengeGuide,
	},
	{
		id = "return",
		task = "Ride back up to the shop",
		available = onFloor,
		done = function()
			return wentDown and atStore()
		end,
		guide = function()
			return elevatorChild("FloorSelector"), "Return to the shop"
		end,
	},
	{
		id = "stock",
		task = "Stock the shop",
		available = atStore,
		done = function()
			if not stockSince or os.clock() - stockSince < STOCK_SETTLE then
				return false
			end
			return not shopHasRoom() or (not carrying("ShopItem") and #waitingStock() == 0)
		end,
		guide = stockGuide,
	},
}

local doneSet = {}
local finished = false

local function active()
	return player:GetAttribute("TutorialDone") == false and not finished
end

-- Latches finished steps and returns the first unfinished one that can be done here.
local function evaluate()
	if onFloor() then
		wentDown = true
	end
	local current
	for _, step in STEPS do
		if not doneSet[step.id] and step.done() then
			doneSet[step.id] = true
		end
		if not doneSet[step.id] and not current and step.available() then
			current = step
		end
	end
	-- The stocking step's settle time runs from when it first leads.
	if current and current.id == "stock" then
		stockSince = stockSince or os.clock()
	else
		stockSince = nil
	end
	return current
end

local function allDone()
	for _, step in STEPS do
		if not doneSet[step.id] then
			return false
		end
	end
	return true
end

-- The To do page in the journal: the steps while the tutorial runs, the routine after.
function TutorialClient.todoText()
	if not active() then
		return "Every night\nRide down, send three loads up the cargo lift, ride back up.\n\nEvery day\nTake the stock off the racks and fill the shop before the customers clear it out."
	end
	local lines = {}
	for _, step in STEPS do
		-- Done lines get a red-inked X in the box and struck-through text. Plain ASCII,
		-- since the handwriting font has no glyph for the crossed-box characters.
		table.insert(
			lines,
			doneSet[step.id] and `[<font color="{CHECK_INK}"><b>X</b></font>]  <s>{step.task}</s>`
				or `[  ]  {step.task}`
		)
	end
	return `<font size="20">{table.concat(lines, "\n")}</font>`
end

-- ================= HIGHLIGHT =================
-- The target itself glows gold through walls, so it's easy to find from across a room.
-- An attachment target (a Stock prompt's point) lights up the furniture it belongs to.
local CREAM = Color3.fromRGB(255, 228, 196)
local GOLD = Color3.fromRGB(214, 168, 96)

local highlight = Instance.new("Highlight")
highlight.Name = "TutorialHighlight"
highlight.FillColor = GOLD
highlight.FillTransparency = 0.8
highlight.OutlineColor = GOLD:Lerp(CREAM, 0.3)
highlight.OutlineTransparency = 0
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
highlight.Enabled = false
highlight.Parent = player:WaitForChild("PlayerGui")

local function highlightOf(instance)
	if instance:IsA("Attachment") then
		return instance:FindFirstAncestorOfClass("Model") or instance.Parent
	end
	return instance
end

-- ================= MARKER =================
-- A gold arrow bobbing over the target, with a caption. The billboard hangs from an
-- invisible part that glides toward the top of the target every frame, so a target that
-- moves (the floor selector rising out of the floor) or changes (the next step) never
-- makes the arrow jump.
local MARKER_FOLLOW_RATE = 9

local marker = Instance.new("BillboardGui")
marker.Name = "TutorialMarker"
marker.Size = UDim2.fromOffset(200, 80)
marker.AlwaysOnTop = true
-- Floor 1 is a big works; its loot can be a long way off.
marker.MaxDistance = 1000
marker.ResetOnSpawn = false
marker.Enabled = false
marker.Parent = player:WaitForChild("PlayerGui")

local arrow = Instance.new("TextLabel")
arrow.Position = UDim2.fromOffset(0, 8)
arrow.Size = UDim2.new(1, 0, 0, 44)
arrow.BackgroundTransparency = 1
arrow.Font = Enum.Font.GothamBold
arrow.Text = "▼"
arrow.TextSize = 40
arrow.TextColor3 = GOLD:Lerp(CREAM, 0.15)
arrow.TextStrokeTransparency = 0.4
arrow.Parent = marker
TweenService:Create(
	arrow,
	TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Position = UDim2.fromOffset(0, -6) }
):Play()

local caption = Instance.new("TextLabel")
caption.Position = UDim2.fromOffset(0, 46)
caption.Size = UDim2.new(1, 0, 0, 22)
caption.BackgroundTransparency = 1
caption.Font = Enum.Font.GothamBold
caption.TextSize = 14
caption.TextColor3 = Color3.fromRGB(240, 226, 196)
caption.TextStrokeTransparency = 0.4
caption.Parent = marker

local anchor = Instance.new("Part")
anchor.Name = "TutorialMarkerAnchor"
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanQuery = false
anchor.CanTouch = false
anchor.Transparency = 1
anchor.Size = Vector3.one
anchor.Parent = workspace.CurrentCamera
marker.Adornee = anchor

local target, shown = nil, false

-- A little above the top of the target.
local function goalOf()
	if target:IsA("Attachment") then
		return target.WorldPosition + Vector3.new(0, 1.5, 0)
	elseif target:IsA("Model") then
		local cf, size = target:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y / 2 + 2, 0)
	end
	return target.Position + Vector3.new(0, target.Size.Y / 2 + 2, 0)
end

RunService.Heartbeat:Connect(function(dt)
	if not target or not target:IsDescendantOf(workspace) then
		return
	end
	local goal = goalOf()
	-- First appearance snaps; after that it glides.
	anchor.Position = shown and anchor.Position:Lerp(goal, 1 - math.exp(-MARKER_FOLLOW_RATE * dt))
		or goal
	shown = true
end)

-- ================= LOOP =================
player:GetAttributeChangedSignal("TutorialDone"):Connect(function()
	-- The dev menu's reset starts it over from the top.
	if player:GetAttribute("TutorialDone") == false then
		table.clear(doneSet)
		finished = false
		wentDown = false
		player:SetAttribute("ReadBossNote", nil)
	end
end)

task.spawn(function()
	while true do
		local current = active() and evaluate()
		if active() and allDone() then
			finished = true
			finishedRemote:FireServer()
		end

		local candidate, text
		if current then
			candidate, text = current.guide()
		end
		local e = elevator()
		local show = candidate ~= nil
			and candidate:IsDescendantOf(workspace)
			and not player:GetAttribute("ReadingJournal")
			and not player:GetAttribute("ReadingNote")
			and not (e and e:GetAttribute("Descending"))
		highlight.Adornee = show and highlightOf(candidate) or nil
		highlight.Enabled = show
		if show then
			target = candidate
			caption.Text = text or current.task
		else
			target, shown = nil, false
		end
		marker.Enabled = show
		task.wait(0.1)
	end
end)

return TutorialClient
