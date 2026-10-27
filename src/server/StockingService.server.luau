-- Shop stocking. Players take a cardboard box off the storage racks in the
-- elevator room and stock its items onto the display cases, shelves and
-- cupboards out in the shop, one item per press of the furniture's Stock prompt.
--
-- The server owns every bit of state: who holds which box, whether that box is
-- open and when it closes again, which slots are taken, how many items each box
-- has left, and the stocked item models. StockingClient only plays the visuals
-- (the flaps and the item flights), told what to play over the Stocking remote.
--
-- The box you carry is a Tool, so it's held up in your hand by the same arm IK as
-- every other carried item (Arms.client). Switching to another tool, unequipping
-- it, dying or leaving all put the box back on its rack.
--
-- Placed in Studio, not built here:
--   StockBox        tag on the main part of each rack box, with ItemId, Count
--                   and Capacity attributes
--   StockFurniture  tag on each furniture model
--   StockSlot       tag on the invisible slot parts under each furniture model,
--                   with Occupied, SlotIndex and SlotSize attributes
-- The rest of a box (front panel, bevel, tape) is found by position at startup.
--
-- Runtime attributes the client reads: HeldBy (box, a UserId or 0) and
-- FreeSlots (furniture).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("StockingConfig"))
local StockItems = require(Shared:WaitForChild("StockItems"))

local store = workspace:WaitForChild("Grocery Store")

local remote = Instance.new("RemoteEvent")
remote.Name = "Stocking"
remote.Parent = ReplicatedStorage

local FLIGHT_TIME = Config.ITEM_POP_TIME + Config.ITEM_APPROACH_TIME + Config.ITEM_FLIGHT_TIME
local BOX_PIECES = { Box = true, BoxBevel = true, Tape = true }
-- The carried box: cardboard thickness, and how far its flaps fold back when open (degrees).
local WALL = 0.035
local LONG_FLAP_OPEN = 115
local SHORT_FLAP_OPEN = 100

local boxes = {} -- [box main part] = { pieces, prompt, pending }
local holds = {} -- [player] = { box, tool, open, openUntil, closeThread, lastPlace }
local reserved = {} -- [slot] = true while an item is on its way there

-- ================= HELPERS =================
local function playSound(parent, sound)
	local s = Instance.new("Sound")
	s.SoundId = sound.id
	s.Volume = sound.volume
	s.PlaybackSpeed = sound.speed
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = 40
	s.Parent = parent
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function itemsLeft(box)
	return (box:GetAttribute("Count") or 0) - boxes[box].pending
end

local function itemName(box)
	local item = StockItems.get(box:GetAttribute("ItemId"))
	return item and item.name or "Stock"
end

-- ================= FURNITURE =================
-- The furniture's slots in fill order (SlotIndex runs left to right, bottom to top).
local function slotsOf(furniture)
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

local function nextFreeSlot(furniture)
	for _, slot in slotsOf(furniture) do
		if not slot:GetAttribute("Occupied") and not reserved[slot] then
			return slot
		end
	end
	return nil
end

-- Keeps the FreeSlots attribute current; clients hide the prompt when it hits 0.
local function updateFreeSlots(furniture)
	local free = 0
	for _, slot in slotsOf(furniture) do
		if not slot:GetAttribute("Occupied") and not reserved[slot] then
			free += 1
		end
	end
	furniture:SetAttribute("FreeSlots", free)
end

-- The furniture's main part, which carries its Stock prompt: the one with the most
-- surface (a shelf unit's back panel, a case's cabinet), so the prompt sits at its
-- middle rather than down on a kick plate.
local function mainPartOf(furniture)
	local best, bestArea
	for _, d in furniture:GetDescendants() do
		if d:IsA("BasePart") and not CollectionService:HasTag(d, "StockSlot") then
			local s = d.Size
			local area = s.X * s.Y + s.Y * s.Z + s.X * s.Z
			if not best or area > bestArea then
				best, bestArea = d, area
			end
		end
	end
	return best
end

local function isStockable(furniture)
	return typeof(furniture) == "Instance"
		and furniture:IsDescendantOf(store)
		and CollectionService:HasTag(furniture, "StockFurniture")
end

-- ================= BOX LOOK =================
local function setBoxHidden(box, hidden)
	for piece, original in boxes[box].pieces do
		piece.Transparency = hidden and 1 or original.transparency
		piece.CanCollide = not hidden and original.canCollide
		piece.CanQuery = not hidden and original.canQuery
	end
end

-- Empty boxes go dark and lose their tape, so they read as used up from across the room.
local function updateEmptyLook(box)
	local empty = (box:GetAttribute("Count") or 0) <= 0
	local hidden = (box:GetAttribute("HeldBy") or 0) ~= 0
	for piece, original in boxes[box].pieces do
		piece.Color = empty and original.color:Lerp(Color3.new(), 1 - Config.EMPTY_BOX_SHADE)
			or original.color
		if piece.Name == "Tape" and not hidden then
			piece.Transparency = empty and 1 or original.transparency
		end
	end
end

local function updateBoxPrompt(box)
	local count = box:GetAttribute("Count") or 0
	local prompt = boxes[box].prompt
	prompt.ObjectText = count > 0 and `{itemName(box)} ×{count}` or "Empty box"
end

-- The box you carry, as a Tool: an open-topped box in the rack box's colours, the
-- same size whichever box it came from, with four flaps. Its floor is the Handle. Each flap hangs on a Weld named FlapHinge
-- whose Hinge, Center and Open attributes let clients swing it (StockingClient).
local function buildBoxTool(box)
	local w, h, d = Config.BOX_HELD_SIZE.X, Config.BOX_HELD_SIZE.Y, Config.BOX_HELD_SIZE.Z

	local tool = Instance.new("Tool")
	tool.Name = "Stock box"
	tool.ToolTip = itemName(box)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = Config.BOX_GRIP
	-- Held in both hands, one on each side (Arms.client).
	local side = Vector3.new(w / 2 + Config.BOX_HAND_GAP, -Config.BOX_HAND_DROP, 0)
	tool:SetAttribute("HoldPoint", Config.BOX_HOLD_CENTER + side)
	tool:SetAttribute("LeftHoldPoint", Config.BOX_HOLD_CENTER - side * Vector3.new(1, -1, 1))
	-- Where items come out: the middle of the open top, above the handle.
	tool:SetAttribute("TopOffset", h - WALL / 2)

	local function piece(name, size, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color or box.Color
		p.Material = material or box.Material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = tool
		return p
	end
	local function weld(part0, part1, c0, name)
		local joint = Instance.new("Weld")
		joint.Name = name or "Weld"
		joint.Part0 = part0
		joint.Part1 = part1
		joint.C0 = c0
		joint.Parent = part1
		return joint
	end

	local handle = piece("Handle", Vector3.new(w, WALL, d))
	-- The rest is laid out around the box's centre, which sits above the floor.
	local center = CFrame.new(0, h / 2 - WALL / 2, 0)
	local function wall(name, size, offset, color)
		weld(handle, piece(name, size, color), center * offset)
	end
	wall("Wall", Vector3.new(w, h, WALL), CFrame.new(0, 0, d / 2 - WALL / 2))
	wall("Wall", Vector3.new(w, h, WALL), CFrame.new(0, 0, -d / 2 + WALL / 2))
	wall("Wall", Vector3.new(WALL, h, d - WALL * 2), CFrame.new(w / 2 - WALL / 2, 0, 0))
	wall("Wall", Vector3.new(WALL, h, d - WALL * 2), CFrame.new(-w / 2 + WALL / 2, 0, 0))
	-- Shadowy lining so the open box reads as hollow.
	local inside = box.Color:Lerp(Color3.new(), 0.5)
	wall(
		"Lining",
		Vector3.new(w - WALL * 2.2, 0.01, d - WALL * 2.2),
		CFrame.new(0, -h / 2 + WALL + 0.006, 0),
		inside
	)
	wall(
		"Lining",
		Vector3.new(w - WALL * 2.2, h - WALL * 2, 0.01),
		CFrame.new(0, 0, -d / 2 + WALL + 0.006),
		inside
	)

	-- The long flaps (front and back) lie on top of the short ones, as on a real box.
	local flaps = {
		{
			long = true,
			hinge = CFrame.new(0, h / 2, d / 2),
			center = CFrame.new(0, WALL * 1.5, -d / 4),
			size = Vector3.new(w, WALL, d / 2),
			open = CFrame.Angles(math.rad(LONG_FLAP_OPEN), 0, 0),
		},
		{
			long = true,
			hinge = CFrame.new(0, h / 2, -d / 2),
			center = CFrame.new(0, WALL * 1.5, d / 4),
			size = Vector3.new(w, WALL, d / 2),
			open = CFrame.Angles(math.rad(-LONG_FLAP_OPEN), 0, 0),
		},
		{
			long = false,
			hinge = CFrame.new(w / 2, h / 2, 0),
			center = CFrame.new(-w / 4, WALL / 2, 0),
			size = Vector3.new(w / 2, WALL, d),
			open = CFrame.Angles(0, 0, math.rad(-SHORT_FLAP_OPEN)),
		},
		{
			long = false,
			hinge = CFrame.new(-w / 2, h / 2, 0),
			center = CFrame.new(w / 4, WALL / 2, 0),
			size = Vector3.new(w / 2, WALL, d),
			open = CFrame.Angles(0, 0, math.rad(SHORT_FLAP_OPEN)),
		},
	}
	local taped = false
	for rackPiece in boxes[box].pieces do
		taped = taped or rackPiece.Name == "Tape"
	end
	local tapeWidth = 0.1
	for _, flap in flaps do
		local part = piece("Flap", flap.size)
		local hinge = weld(handle, part, center * flap.hinge * flap.center, "FlapHinge")
		hinge:SetAttribute("Hinge", center * flap.hinge)
		hinge:SetAttribute("Center", flap.center)
		hinge:SetAttribute("Open", flap.open)
		hinge:SetAttribute("Long", flap.long)
		if taped and flap.long then
			-- Half the strip of tape over the seam rides on each long flap.
			local tape = piece(
				"Tape",
				Vector3.new(w * 0.98, 0.006, tapeWidth),
				Color3.fromRGB(214, 196, 160),
				Enum.Material.SmoothPlastic
			)
			local towardSeam = flap.center.Z > 0 and 1 or -1
			weld(part, tape, CFrame.new(0, WALL / 2 + 0.003, towardSeam * (d / 4 - tapeWidth / 2)))
		end
	end
	return tool
end

-- Tells the holder, and everyone near enough to see, to play something.
local function fireNearby(player, ...)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	remote:FireClient(player, ...)
	for _, other in Players:GetPlayers() do
		local otherRoot = other ~= player and rootOf(other)
		if
			root
			and otherRoot
			and (otherRoot.Position - root.Position).Magnitude <= Config.REPLICATE_RADIUS
		then
			remote:FireClient(other, ...)
		end
	end
end

-- ================= HOLDING =================
local function closeBox(player, hold)
	if holds[player] ~= hold or not hold.open then
		return
	end
	hold.open = false
	if hold.closeThread then
		task.cancel(hold.closeThread)
		hold.closeThread = nil
	end
	fireNearby(player, "Close", hold.tool)
end

-- Puts the box back on its rack. Any items already in flight still land.
local function release(player, reason)
	local hold = holds[player]
	if not hold then
		return
	end
	holds[player] = nil
	if hold.closeThread then
		task.cancel(hold.closeThread)
	end
	local box = hold.box
	box:SetAttribute("HeldBy", 0)
	setBoxHidden(box, false)
	updateEmptyLook(box)
	hold.tool:Destroy()
	if reason ~= "left" then
		playSound(box, Config.SOUNDS.putBack)
		remote:FireClient(player, "Release", box, reason)
	end
end

local function take(player, box)
	local root = rootOf(player)
	if holds[player] or not root then
		return
	end
	if (box:GetAttribute("HeldBy") or 0) ~= 0 or itemsLeft(box) <= 0 then
		return
	end
	if (root.Position - box.Position).Magnitude > Config.MAX_BOX_DISTANCE then
		return
	end
	local character = root.Parent
	local tool = buildBoxTool(box)
	local hold = {
		box = box,
		tool = tool,
		open = false,
		openUntil = 0,
		lastPlace = -math.huge,
	}
	holds[player] = hold
	box:SetAttribute("HeldBy", player.UserId)
	setBoxHidden(box, true)
	playSound(box, Config.SOUNDS.take)

	-- Whatever was in hand goes back in the backpack and the box is equipped instead.
	character:FindFirstChildOfClass("Humanoid"):UnequipTools()
	tool.Parent = character
	-- Unequipping it (or the character going away) puts it back on the rack.
	tool.AncestryChanged:Connect(function()
		if holds[player] == hold and tool.Parent ~= character then
			release(player, "unequipped")
		end
	end)
	remote:FireClient(player, "Hold", box, tool)
end

-- ================= STOCKING =================
local function reject(player, reason)
	remote:FireClient(player, "Reject", reason)
end

-- The item has landed: it becomes a real anchored model in its slot.
local function finishPlacement(slot, box, itemId, furniture)
	local model = StockItems.create(itemId, slot:GetAttribute("SlotSize"))
	if model then
		model.Name = "StockedItem"
		model:SetAttribute("ItemId", itemId)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
			end
		end
		model:PivotTo(StockItems.restingCFrame(itemId, slot))
		model.Parent = slot
	end
	slot:SetAttribute("Occupied", true)
	reserved[slot] = nil
	boxes[box].pending -= 1
	box:SetAttribute("Count", math.max((box:GetAttribute("Count") or 0) - 1, 0))
	updateFreeSlots(furniture)
	updateBoxPrompt(box)
	playSound(slot, Config.SOUNDS.place)

	-- Out of items: close up and put the box back, now empty.
	if itemsLeft(box) <= 0 then
		local holder = Players:GetPlayerByUserId(box:GetAttribute("HeldBy") or 0)
		local hold = holder and holds[holder]
		if hold and hold.box == box then
			closeBox(holder, hold)
			task.delay(Config.BOX_CLOSE_TIME + 0.05, function()
				if holds[holder] == hold then
					release(holder, "empty")
				end
			end)
		end
	end
end

local function stock(player, furniture)
	local hold = holds[player]
	if not hold or not isStockable(furniture) then
		return
	end
	local now = os.clock()
	if now - hold.lastPlace < Config.PLACE_COOLDOWN then
		return -- Spam inside the cooldown is dropped without a word.
	end
	local root = rootOf(player)
	local prompt = furniture:FindFirstChild("StockPrompt", true)
	if not root or not prompt then
		return
	end
	if (root.Position - prompt.Parent.Position).Magnitude > Config.MAX_STOCK_DISTANCE then
		return reject(player, "far")
	end
	local box = hold.box
	if itemsLeft(box) <= 0 then
		return reject(player, "empty")
	end
	local slot = nextFreeSlot(furniture)
	if not slot then
		-- Someone else got the last slot first; make sure the prompt goes away.
		updateFreeSlots(furniture)
		return reject(player, "full")
	end

	-- Accepted. The slot is reserved now, so nobody else gets it mid-flight.
	hold.lastPlace = now
	reserved[slot] = true
	boxes[box].pending += 1
	updateFreeSlots(furniture)

	local playOpen = not hold.open
	local delay = 0
	if playOpen then
		hold.open = true
		hold.openUntil = now + Config.BOX_OPEN_TIME
		delay = Config.BOX_OPEN_TIME
	else
		-- Still opening from a click a moment ago: wait for the flaps.
		delay = math.max(hold.openUntil - now, 0)
	end
	local landsIn = delay + FLIGHT_TIME

	local itemId = box:GetAttribute("ItemId")
	fireNearby(player, "Place", {
		holder = player,
		box = box,
		tool = hold.tool,
		slot = slot,
		itemId = itemId,
		playOpen = playOpen,
		delay = delay,
	})

	task.delay(landsIn, finishPlacement, slot, box, itemId, furniture)

	-- Every placement restarts the idle timer; only the latest one ever fires.
	if hold.closeThread then
		task.cancel(hold.closeThread)
	end
	hold.closeThread = task.delay(landsIn + Config.AUTO_CLOSE_DELAY, function()
		hold.closeThread = nil
		closeBox(player, hold)
	end)
end

-- ================= SETUP =================
local function setupBox(box)
	if boxes[box] or not box:IsA("BasePart") then
		return
	end
	-- The box's other pieces sit on or just outside its main part.
	local pieces = {}
	for _, part in box.Parent:GetChildren() do
		if part:IsA("BasePart") and BOX_PIECES[part.Name] then
			local offset = box.CFrame:PointToObjectSpace(part.Position)
			local reach = box.Size / 2 + Vector3.new(0.25, 0.25, 0.25)
			if
				math.abs(offset.X) <= reach.X
				and math.abs(offset.Y) <= reach.Y
				and math.abs(offset.Z) <= reach.Z
			then
				pieces[part] = {
					transparency = part.Transparency,
					color = part.Color,
					canCollide = part.CanCollide,
					canQuery = part.CanQuery,
				}
			end
		end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StockBoxPrompt"
	prompt.ActionText = "Take box"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = Config.BOX_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = box

	boxes[box] = { pieces = pieces, prompt = prompt, pending = 0 }
	box:SetAttribute("HeldBy", 0)
	updateBoxPrompt(box)
	updateEmptyLook(box)

	-- The same prompt takes the box, or puts it back if it's yours.
	prompt.Triggered:Connect(function(player)
		local hold = holds[player]
		if hold and hold.box == box then
			release(player, "putBack")
		else
			take(player, box)
		end
	end)
end

local function setupFurniture(furniture)
	if not furniture:IsA("Model") or furniture:FindFirstChild("StockPrompt", true) then
		return
	end
	local main = mainPartOf(furniture)
	if not main then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StockPrompt"
	prompt.ActionText = "Stock"
	prompt.ObjectText = furniture.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.STOCK_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = main

	for _, slot in slotsOf(furniture) do
		if slot:GetAttribute("Occupied") == nil then
			slot:SetAttribute("Occupied", false)
		end
	end
	updateFreeSlots(furniture)

	-- Slots added later count straight away.
	furniture.ChildAdded:Connect(function(child)
		if CollectionService:HasTag(child, "StockSlot") then
			updateFreeSlots(furniture)
		end
	end)

	prompt.Triggered:Connect(function(player)
		stock(player, furniture)
	end)
end

for _, box in CollectionService:GetTagged("StockBox") do
	setupBox(box)
end
CollectionService:GetInstanceAddedSignal("StockBox"):Connect(setupBox)

for _, furniture in CollectionService:GetTagged("StockFurniture") do
	setupFurniture(furniture)
end
CollectionService:GetInstanceAddedSignal("StockFurniture"):Connect(setupFurniture)

-- ================= CLEANUP =================
-- Dying, respawning, leaving or picking up a tool all put the box back.
local function watchCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(function()
			release(player, "died")
		end)
	end
	character.ChildAdded:Connect(function(child)
		local hold = holds[player]
		if child:IsA("Tool") and hold and child ~= hold.tool then
			release(player, "tool")
		end
	end)
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		release(player, "died")
	end)
	if player.Character then
		watchCharacter(player, player.Character)
	end
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in Players:GetPlayers() do
	watchPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	release(player, "left")
end)

-- The client asks to put the box down (its put-down key, or switching to the journal).
remote.OnServerEvent:Connect(function(player, action)
	if action == "PutDown" then
		release(player, "putBack")
	end
end)
