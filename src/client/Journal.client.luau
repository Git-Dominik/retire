-- G reads the journal once you've picked it up in the lobby (Journal.server).
-- The book rises from the bottom of the screen and starts opening as it nears
-- the centre, while the view tips down and the world behind falls out of focus.
-- The left/right arrow keys turn pages, and the coloured bookmarks jump between
-- sections (Guides, Floor, Money). The cursor is freed to click them; you can keep
-- walking while reading, only the view's up/down angle is held (Camera.client) and
-- the view turns only while the right mouse button is held.
-- Everything moves with the same exponential smoothing as the camera and
-- movement (no tweens), so it chases its target the instant input changes.
-- Guides holds the to-do list for the current phase of the game (see TASKS below):
-- each line is ticked off as the state other scripts publish changes. Floor tracks the
-- current floor's item and the cargo lift; Money shows the Player "Money" attribute
-- (set by Cargo.server, this session only) and the deliveries behind it.
-- The current to-do step also gets a bobbing arrow over its object in the world
-- (the elevator's floor selector, floor item, cargo lift car and send button). Until you
-- take it, the lobby book carries a bobbing arrow marker (built here,
-- so it disappears for you alone). The camera tilt lives in Camera.client, which watches the ReadingJournal
-- attribute this script sets on the local player.
-- The book is laid out at full size each frame, then shrunk towards the camera (BOOK_SCALE)
-- so walls can't clip through it.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Pro Sound Effects leather-bound book foley.
local OPEN_SOUND_ID = "rbxassetid://9118834774" -- Scrapbook Open 4
local CLOSE_SOUND_ID = "rbxassetid://9118833191" -- Scrapbook Close 1
local PAGE_SOUND_ID = "rbxassetid://9118835802" -- Scrapbook Open And Turn Pages 7

-- Aged paper with torn edges (assets/journal_page.png). Until it's uploaded and
-- its image id filled in here, pages fall back to plain straight-edged paper.
local PAPER_IMAGE = ""
local USE_PAPER_IMAGE = PAPER_IMAGE ~= ""

local PAGE_W = 1.25
local PAGE_H = 1.7
-- Studs in front of the camera the open book is held, centred on screen.
local HOLD_DISTANCE = 2
-- The book is shrunk towards the camera by this factor (and its pixel density raised to match),
-- so it looks the same but sits too close for a wall to poke through it.
local BOOK_SCALE = 0.25
-- Where the book waits below the screen, and how far it leans back while down there.
local LOWERED_Y = -2.6
local LOWERED_TILT = 35
-- Smoothing rates, as in the camera script: higher snaps to the target faster.
local RAISE_RATE = 8
local OPEN_RATE = 9
local FLIP_RATE = 10
-- How far up the book has to be before the covers start parting.
local OPEN_AT = 0.55
-- How far shut the covers have to be before a closing book starts to drop.
local DROP_AT = 0.6
-- A SurfaceGui's "up" on a Top face runs along the part's -X, so page parts are
-- built a quarter turn round (length along X) to make lines read left to right.
local PAGE_TURN = CFrame.Angles(0, -math.pi / 2, 0)

local LEATHER = Color3.fromRGB(74, 40, 28)
local PAPER = Color3.fromRGB(228, 216, 192)
local PAPER_EDGE = Color3.fromRGB(196, 178, 146)
local PAPER_AGED = Color3.fromRGB(168, 140, 102)
local INK = Color3.fromRGB(46, 34, 26)
local ACCENT = Color3.fromRGB(112, 30, 26)
local RING = Color3.fromRGB(42, 38, 36)

-- ================= TO-DO LIST =================
-- Tasks are grouped by phase. The phase is the workspace attribute "Phase"
-- ("Night" when unset), so a day cycle only has to set it. Each `done` reads
-- state other scripts already publish; a task stays ticked for the rest of its
-- phase even if that state resets (the cargo value drops to 0 after a send).
local DEFAULT_PHASE = "Night"
local CHECK_INK = "#701e1a"

local function carryingScavenged()
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in { backpack, player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("ScavengedLevel") then
					return true
				end
			end
		end
	end
	return false
end

local function liftAttribute(name)
	local elevator = workspace:FindFirstChild("Elevator")
	local lift = elevator and elevator:FindFirstChild("CargoLift")
	return lift and lift:GetAttribute(name) or 0
end

-- Markers need a BasePart to hang from; fixtures may be parts or models.
local function basePartOf(instance)
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function elevatorChild(...)
	local instance = workspace:FindFirstChild("Elevator")
	for _, name in { ... } do
		instance = instance and instance:FindFirstChild(name)
	end
	return instance
end

local function holdingShopItem()
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("ShopItem") == true
end

-- True once every piece of furniture is full (and there is some).
local function shopStocked()
	local furniture = CollectionService:GetTagged("StockFurniture")
	for _, model in furniture do
		if (model:GetAttribute("FreeSlots") or 0) > 0 then
			return false
		end
	end
	return #furniture > 0
end

local TASKS = {
	Night = {
		{
			id = "descend",
			text = "Ride the elevator down",
			target = function()
				return elevatorChild("FloorSelector")
			end,
			done = function()
				local elevator = workspace:FindFirstChild("Elevator")
				return elevator ~= nil and (elevator:GetAttribute("Level") or 0) >= 1
			end,
		},
		{
			id = "scavenge",
			text = "Find something worth keeping",
			-- Elevator.server tags each floor's item.
			target = function()
				for _, item in CollectionService:GetTagged("ScavengeItem") do
					if item.Transparency == 0 then
						return item
					end
				end
				return nil
			end,
			done = function()
				return carryingScavenged() or liftAttribute("CargoValue") > 0 or liftAttribute("SendSeq") > 0
			end,
		},
		{
			id = "load",
			text = "Load it onto the cargo lift",
			target = function()
				return elevatorChild("CargoLift", "Car")
			end,
			done = function()
				return liftAttribute("CargoValue") > 0 or liftAttribute("SendSeq") > 0
			end,
		},
		{
			id = "send",
			text = "Send the lift up to the shop",
			target = function()
				return elevatorChild("CargoLift", "SendButton")
			end,
			done = function()
				return liftAttribute("SendSeq") > 0
			end,
		},
	},
	-- Nothing sets this phase yet; it's here for when the pawn shop opens by day.
	Day = {
		{
			id = "take",
			text = "Take an item from the racks",
			done = holdingShopItem,
			target = function()
				return CollectionService:GetTagged("RackItem")[1]
			end,
		},
		{
			id = "stock",
			text = "Stock the shelves and cases",
			done = shopStocked,
			target = function()
				for _, model in CollectionService:GetTagged("StockFurniture") do
					if (model:GetAttribute("FreeSlots") or 0) > 0 then
						return model
					end
				end
				return nil
			end,
		},
	},
}

local taskPhase
local doneSet = {}

-- Latches finished tasks and returns the phase's task list plus the first
-- unfinished one. Runs from the marker loop, so ticks don't depend on the book
-- being open.
local function evaluateTasks()
	local phase = workspace:GetAttribute("Phase") or DEFAULT_PHASE
	if phase ~= taskPhase then
		taskPhase = phase
		doneSet = {}
	end
	local list = TASKS[phase] or {}
	local current
	for _, task in list do
		if not doneSet[task.id] and task.done() then
			doneSet[task.id] = true
		end
		if not doneSet[task.id] and not current then
			current = task
		end
	end
	return list, current
end

local function tasksText()
	local lines = {}
	for _, task in (evaluateTasks()) do
		-- Done lines get a red-inked X in the box and struck-through text. Plain ASCII,
		-- since the handwriting font has no glyph for the crossed-box characters.
		table.insert(
			lines,
			doneSet[task.id] and `[<font color="{CHECK_INK}"><b>X</b></font>]  <s>{task.text}</s>`
				or `[  ]  {task.text}`
		)
	end
	return table.concat(lines, "\n\n")
end

-- ================= SECTIONS =================
-- The bookmarks. Each section starts on a left-hand page so its tab can flip straight
-- to it; a section with an odd number of pages gets a blank one to keep the next
-- aligned. `render` pages are redrawn from live state while the book lies open.
local ledger = {} -- money earned this session, one entry per delivered item (never saved)
local lastMoney = player:GetAttribute("Money") or 0
player:GetAttributeChangedSignal("Money"):Connect(function()
	local now = player:GetAttribute("Money") or 0
	if now > lastMoney then
		table.insert(ledger, now - lastMoney)
	end
	lastMoney = now
end)

local function floorPage()
	local elevator = workspace:FindFirstChild("Elevator")
	local level = elevator and elevator:GetAttribute("Level") or 0
	-- Elevator.server tags the one item on the floor you're standing on.
	local item = level > 0 and CollectionService:GetTagged("ScavengeItem")[1]
	if not item then
		return "Floor", "Nothing to track yet.\n\nRide the elevator down and each floor's item is written here."
	end
	local status
	if carryingScavenged() then
		status = "In your hands"
	elseif liftAttribute("CargoValue") > 0 then
		status = "On the cargo lift"
	elseif item.Transparency == 0 then
		status = "Still lying where it fell"
	else
		status = "Sent up to the shop"
	end
	return `Floor {level}`,
		`<b>{item.Name}</b>\n\nWorth ${item:GetAttribute("Value") or 0}\n\n<font color="{CHECK_INK}">{status}</font>`
end

local function liftPage()
	local elevator = workspace:FindFirstChild("Elevator")
	return "Cargo lift",
		`On the lift now\n<b>${liftAttribute("CargoValue")}</b>\n\nTrips left\n<b>{elevator and elevator:GetAttribute("CargoTripsLeft") or 0}</b>`
end

local function moneyPage()
	return "Money",
		`<font size="58"><b>${player:GetAttribute("Money") or 0}</b></font>\n\nearned this session\n{#ledger} {#ledger == 1 and "delivery" or "deliveries"}\n\n<i>Not kept once you leave.</i>`
end

local function ledgerPage()
	local lines = {}
	for i = #ledger, math.max(#ledger - 7, 1), -1 do
		table.insert(lines, `+ ${ledger[i]}`)
	end
	return "Ledger", #lines > 0 and table.concat(lines, "\n") or "Nothing sold yet."
end

local SECTIONS = {
	{
		name = "Guides",
		color = Color3.fromRGB(196, 168, 74),
		side = -1,
		x = 0.5,
		pages = {
			{ title = "Property of", body = "\n—\n\n\nIf found, do not return it to the elevator." },
			{
				render = function()
					return "To do", tasksText()
				end,
			},
			{
				title = "Day 1",
				body = "The lift was waiting with its doors open, as if it knew I was coming. Warm light, a gramophone, a smell of old velvet. Someone had set a place for me.",
			},
			{
				title = "Day 2",
				body = "It wants something from every floor. Not money. Things. A lighter, a music box, once a pocket watch. I don't know what it does with them.",
			},
			{
				title = "The rooms",
				body = "Always quiet. Too quiet for a hotel. The lamps are lit but nobody lit them, and the rugs have never been walked on.",
			},
			{
				title = "Day 4",
				body = "I counted the floors on the dial. There are more ticks than there should be. The needle doesn't care what I count.",
			},
			{
				title = "Note to self",
				body = "- Bring the thing back.\n- Don't run in the halls.\n- Don't answer if it asks your name.",
			},
			{
				title = "Day 7",
				body = "The music only plays when we move. I've started to look forward to it, and that frightens me more than anything down here.",
			},
		},
	},
	{
		name = "Floor",
		color = Color3.fromRGB(150, 52, 46),
		side = 1,
		x = 0.32,
		pages = { { render = floorPage }, { render = liftPage } },
	},
	{
		name = "Money",
		color = Color3.fromRGB(104, 128, 86),
		side = 1,
		x = 0.68,
		pages = { { render = moneyPage }, { render = ledgerPage } },
	},
}

local PAGES = {}
for _, section in SECTIONS do
	section.first = #PAGES + 1
	for _, page in section.pages do
		table.insert(PAGES, page)
	end
	if #PAGES % 2 == 1 then
		table.insert(PAGES, {})
	end
	section.firstSpread = (section.first - 1) // 2
	section.lastSpread = (#PAGES - 1) // 2
end

local function sectionAt(spreadIndex)
	for _, section in SECTIONS do
		if spreadIndex >= section.firstSpread and spreadIndex <= section.lastSpread then
			return section
		end
	end
	return nil
end

-- ================= WORLD MARKERS =================
-- A gold arrow bobbing over an object, with a caption. Built on the client, so
-- each player sees their own. The arrow rides a looping tween; the caption stays put.
local function makeMarker(name, captionText)
	local marker = Instance.new("BillboardGui")
	marker.Name = name
	marker.Size = UDim2.fromOffset(160, 80)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 80
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
	arrow.TextColor3 = Color3.fromRGB(226, 184, 96)
	arrow.TextStrokeTransparency = 0.4
	arrow.Parent = marker

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.Position = UDim2.fromOffset(0, 46)
	caption.Size = UDim2.new(1, 0, 0, 22)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.GothamBold
	caption.Text = captionText
	caption.TextSize = 14
	caption.TextColor3 = Color3.fromRGB(240, 226, 196)
	caption.TextStrokeTransparency = 0.4
	caption.Parent = marker

	local tween = TweenService:Create(
		arrow,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromOffset(0, -6) }
	)
	tween:Play()
	return marker, tween
end

-- Points at the current task's target. Hidden until the journal is taken (the
-- pickup arrow covers that), and while the book is open. The billboard hangs from an
-- invisible part that glides toward the top of the target every frame, so a target
-- that moves (the floor selector rising out of the floor) or changes (the next step)
-- never makes the arrow jump.
local MARKER_FOLLOW_RATE = 9
task.spawn(function()
	local marker = makeMarker("TaskMarker", "")
	local anchor = Instance.new("Part")
	anchor.Name = "TaskMarkerAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Parent = workspace.CurrentCamera
	marker.Adornee = anchor

	local target, shown = nil, false
	local function goalOf()
		-- Targets are parts or models; the arrow floats a little above the top.
		if target:IsA("Model") then
			local cf, size = target:GetBoundingBox()
			return cf.Position + Vector3.new(0, size.Y / 2 + 2, 0)
		end
		return target.Position + Vector3.new(0, target.Size.Y / 2 + 2, 0)
	end

	RunService.Heartbeat:Connect(function(dt)
		if not target or not target.Parent then
			return
		end
		local goal = goalOf()
		-- First appearance snaps; after that it glides.
		anchor.Position = shown and anchor.Position:Lerp(goal, 1 - math.exp(-MARKER_FOLLOW_RATE * dt)) or goal
		shown = true
	end)

	while true do
		local _, current = evaluateTasks()
		local candidate = current and current.target and current.target()
		local show = basePartOf(candidate) ~= nil
			and player:GetAttribute("HasJournal") == true
			and not player:GetAttribute("ReadingJournal")
		target = show and candidate or nil
		if show then
			marker.Caption.Text = current.text
		else
			shown = false
		end
		marker.Enabled = show
		task.wait(0.25)
	end
end)

-- ================= BOOK MODEL =================
local function part(parent, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function stroked(parent, inset, thickness, transparency)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Position = UDim2.fromOffset(inset, inset)
	f.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
	f.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = ACCENT
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.Parent = f
	return f
end

local function diamond(parent, position, size)
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = position
	d.Size = UDim2.fromOffset(size, size)
	d.Rotation = 45
	d.BackgroundColor3 = ACCENT
	d.BorderSizePixel = 0
	d.Parent = parent
	return d
end

local function label(gui, name, font, size, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.RichText = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Parent = gui
	return l
end

local HAND = Font.fromEnum(Enum.Font.Kalam)
local HAND_BOLD = Font.new(HAND.Family, Enum.FontWeight.Bold)

local function surface(p, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 300
	gui.LightInfluence = 0.35
	gui.ClipsDescendants = true
	gui.Parent = p
	return gui
end

-- The paper itself: the torn-paper image (the part underneath is invisible, so
-- the ragged edge shows), or crossed gradients aging plain paper as a fallback.
-- Turning the image half round on alternate pages keeps the stains from repeating.
local function paper(gui, tint, turned)
	if USE_PAPER_IMAGE then
		local image = Instance.new("ImageLabel")
		image.Name = "Paper"
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = PAPER_IMAGE
		image.ImageColor3 = tint
		image.Rotation = turned and 180 or 0
		image.Parent = gui
		return
	end
	for _, rotation in { 0, 90 } do
		local shade = Instance.new("Frame")
		shade.Size = UDim2.fromScale(1, 1)
		shade.BackgroundColor3 = PAPER_AGED
		shade.BorderSizePixel = 0
		shade.Parent = gui
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.16, 1),
			NumberSequenceKeypoint.new(0.84, 1),
			NumberSequenceKeypoint.new(1, 0.3),
		})
		gradient.Parent = shade
	end
end

-- One decorated page face: aged paper, a double ruled border with corner
-- diamonds, a titled entry and a page number.
local function pageGui(p, face, turned)
	local gui = surface(p, face)
	paper(gui, Color3.new(1, 1, 1), turned)

	local border = stroked(gui, 18, 2, 0.15)
	stroked(gui, 25, 1, 0.5)
	for _, corner in { Vector2.zero, Vector2.xAxis, Vector2.yAxis, Vector2.one } do
		diamond(border, UDim2.fromScale(corner.X, corner.Y), 11)
	end
	diamond(border, UDim2.fromScale(0.5, 0), 8)
	diamond(border, UDim2.fromScale(0.5, 1), 8)

	local title = label(gui, "Title", HAND_BOLD, 34, INK)
	title.Position = UDim2.fromOffset(42, 40)
	title.Size = UDim2.new(1, -84, 0, 46)

	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.Position = UDim2.fromOffset(42, 88)
	rule.Size = UDim2.new(1, -84, 0, 2)
	rule.BackgroundColor3 = ACCENT
	rule.BackgroundTransparency = 0.35
	rule.BorderSizePixel = 0
	rule.Parent = gui
	diamond(rule, UDim2.fromScale(1, 0.5), 7)

	local body = label(gui, "Body", HAND, 23, INK)
	body.Position = UDim2.fromOffset(42, 104)
	body.Size = UDim2.new(1, -84, 1, -160)
	body.LineHeight = 1.1

	local number = label(gui, "Number", HAND, 18, INK)
	number.AnchorPoint = Vector2.new(0.5, 1)
	number.Position = UDim2.new(0.5, 0, 1, -30)
	number.Size = UDim2.fromOffset(120, 24)
	number.TextXAlignment = Enum.TextXAlignment.Center
	number.TextTransparency = 0.35
	return gui
end

local function setPage(gui, index)
	local page = PAGES[index]
	local title, body = "", ""
	if page then
		title, body = page.title or "", page.body or ""
		if page.render then
			title, body = page.render()
		end
	end
	gui.Title.Text = title
	gui.Body.Text = body
	gui.Rule.Visible = title ~= ""
	gui.Number.Text = page and `— {index} —` or ""
end

local book = Instance.new("Model")
book.Name = "JournalView"

-- Covers stick out past the pages so a leather border frames the spread.
local COVER_MARGIN = 0.07
local coverSize = Vector3.new(PAGE_W + COVER_MARGIN * 2, 0.04, PAGE_H + COVER_MARGIN * 2)
local rightCover = part(book, "RightCover", coverSize, LEATHER, Enum.Material.Leather)
local leftCover = part(book, "LeftCover", coverSize, LEATHER, Enum.Material.Leather)
local rightBlock = part(book, "RightPages", Vector3.new(PAGE_H, 0.1, PAGE_W), PAPER)
local leftBlock = part(book, "LeftPages", Vector3.new(PAGE_H, 0.1, PAGE_W), PAPER)
local spine = part(book, "Spine", Vector3.new(0.14, 0.04, coverSize.Z), LEATHER, Enum.Material.Leather)
-- Shadow where the pages dip into the binding.
local gutter = part(book, "Gutter", Vector3.new(0.09, 0.002, PAGE_H), Color3.fromRGB(70, 52, 36))
gutter.Transparency = 0.5

-- Slightly darker sheets peeking out past each page's outer and bottom edge,
-- so the block reads as a stack of paper rather than a single card.
local stacks = {}
for layer = 1, 2 do
	for _, side in { -1, 1 } do
		local s = part(book, "Stack", Vector3.new(PAGE_H, 0.04, PAGE_W), PAPER_EDGE:Lerp(PAPER_AGED, layer * 0.3))
		table.insert(stacks, { part = s, side = side, layer = layer })
	end
end

-- Spiral binding: a row of dark metal rods across the spine, each slightly skewed.
local RING_COUNT = 11
local rings = {}
for i = 1, RING_COUNT do
	local r = part(book, "Ring", Vector3.new(0.26, 0.05, 0.05), RING, Enum.Material.Metal)
	r.Shape = Enum.PartType.Cylinder
	local z = (i - (RING_COUNT + 1) / 2) * (PAGE_H * 0.9 / (RING_COUNT - 1))
	table.insert(rings, { part = r, offset = CFrame.new(0, 0.075, z) * CFrame.Angles(0, math.rad(-9), 0) })
end

-- One coloured bookmark per section, poking out of the top edge. The one for the section
-- you're reading stands a little prouder.
local tabs = {}
for _, section in SECTIONS do
	local t = part(book, "Tab", Vector3.new(0.24, 0.012, 0.22), section.color, Enum.Material.Fabric)
	table.insert(tabs, { part = t, section = section, side = section.side, x = section.x, lift = 0 })
end

-- The sheet that swings across the spine while turning a page. Its back is a
-- separate part turned half round, or the back text would come out upside down.
local sheet = part(nil, "Sheet", Vector3.new(PAGE_H, 0.002, PAGE_W), PAPER)
local sheetBackPart = part(sheet, "SheetBack", Vector3.new(PAGE_H, 0.002, PAGE_W), PAPER)

local leftGui = pageGui(leftBlock, Enum.NormalId.Top, false)
local rightGui = pageGui(rightBlock, Enum.NormalId.Top, true)
local sheetFront = pageGui(sheet, Enum.NormalId.Top, true)
local sheetBack = pageGui(sheetBackPart, Enum.NormalId.Bottom, false)

if USE_PAPER_IMAGE then
	for _, p in { leftBlock, rightBlock, sheet, sheetBackPart } do
		p.Transparency = 1
	end
	-- The stacked sheets underneath get the same torn paper, tinted darker.
	for _, s in stacks do
		s.part.Transparency = 1
		paper(surface(s.part, Enum.NormalId.Top), s.part.Color, s.layer == 1)
	end
end

-- A soft reading light in front of the spread, so the book is legible anywhere.
local lightHolder = Instance.new("Attachment")
lightHolder.Position = Vector3.new(0, 1.6, 0.2) * BOOK_SCALE
lightHolder.Parent = spine
local readingLight = Instance.new("PointLight")
readingLight.Color = Color3.fromRGB(255, 210, 160)
readingLight.Range = 6 * BOOK_SCALE
readingLight.Brightness = 0.65
readingLight.Shadows = false
readingLight.Parent = lightHolder

-- ================= SOUNDS =================
local function makeSound(id, volume)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = script
	return s
end
local openSound = makeSound(OPEN_SOUND_ID, 0.25)
local closeSound = makeSound(CLOSE_SOUND_ID, 0.25)
local pageSound = makeSound(PAGE_SOUND_ID, 0.2)

-- ================= FOCUS EFFECTS =================
local focus = Instance.new("DepthOfFieldEffect")
focus.Name = "JournalFocus"
focus.FocusDistance = HOLD_DISTANCE * BOOK_SCALE
focus.InFocusRadius = 0.6
focus.NearIntensity = 0
focus.FarIntensity = 0
focus.Enabled = false
focus.Parent = Lighting

local dim = Instance.new("ColorCorrectionEffect")
dim.Name = "JournalDim"
dim.Enabled = false
dim.Parent = Lighting

-- ================= HINT UI =================
local gui = Instance.new("ScreenGui")
gui.Name = "JournalHint"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")

local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -40)
hint.Size = UDim2.fromOffset(560, 24)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamBold
hint.TextSize = 12
hint.TextColor3 = Color3.fromRGB(222, 202, 160)
hint.TextTransparency = 1
hint.TextStrokeTransparency = 1
hint.Parent = gui

local hintTween
local function showHint(text, visible)
	hint.Text = text or hint.Text
	if hintTween then
		hintTween:Cancel()
	end
	local goal = visible and 0.1 or 1
	hintTween = TweenService:Create(hint, TweenInfo.new(0.3), { TextTransparency = goal, TextStrokeTransparency = visible and 0.6 or 1 })
	hintTween:Play()
end

-- ================= STATE =================
local state = "closed" -- closed, opening, open, switching (shut to jump to a bookmark), closing
-- Each pair is the smoothed value and the target it chases.
local raise, targetRaise = 0, 0 -- 0 below the screen, 1 held up in front of you
local openness, targetOpen = 0, 0 -- 0 shut, 1 lying open
local flipAngle, flipTarget = 0, 0 -- sheet swing, 0 on the right to pi on the left
local flipping = false
local flipDir = 0
local closeSounded = false
local spread = 0
local spreadCount = math.ceil(#PAGES / 2)
local inputBound = false
local refreshTimer = 0
local goalSpread -- a bookmark was clicked: the book shuts, then reopens at this spread
local pageShake = 0 -- kicked on each page turn, decays; jolts the book a little

local function approach(value, goal, rate, dt)
	return value + (goal - value) * (1 - math.exp(-rate * dt))
end

local function showSpread()
	setPage(leftGui, spread * 2 + 1)
	setPage(rightGui, spread * 2 + 2)
end

local function finishFlip()
	spread += flipDir
	showSpread()
	sheet.Parent = nil
	flipping = false
end

local function flip(dir)
	local target = spread + dir
	if state ~= "open" or flipping or target < 0 or target >= spreadCount then
		return
	end
	flipping = true
	flipDir = dir
	pageSound:Play()
	pageShake = 1
	if dir > 0 then
		-- The current right page lifts away, revealing the next right page beneath it.
		setPage(sheetFront, spread * 2 + 2)
		setPage(sheetBack, target * 2 + 1)
		setPage(rightGui, target * 2 + 2)
		flipAngle, flipTarget = 0, math.pi
	else
		setPage(sheetBack, spread * 2 + 1)
		setPage(sheetFront, target * 2 + 2)
		setPage(leftGui, target * 2 + 1)
		flipAngle, flipTarget = math.pi, 0
	end
	sheet.Parent = book
end

-- Clickable labels riding over the tabs. The tabs are parts in the book, so these are
-- repositioned to wherever the tab projects on screen each frame.
for _, tab in tabs do
	local button = Instance.new("TextButton")
	button.Name = tab.section.name
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Size = UDim2.fromOffset(76, 80)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = Color3.fromRGB(240, 226, 196)
	button.TextStrokeTransparency = 0.4
	button.TextYAlignment = Enum.TextYAlignment.Top
	button.Text = string.upper(tab.section.name)
	button.Visible = false
	button.Parent = gui
	button.Activated:Connect(function()
		if state == "open" and not flipping and tab.section.firstSpread ~= spread then
			goalSpread = tab.section.firstSpread
			state = "switching"
			targetOpen = 0
			closeSounded = false
		end
	end)
	tab.button = button
end

-- The render step lays the book out at full size; shrinkBook then squashes it towards the camera.
local bookParts = {}
-- The turning sheet is only parented to the book mid-flip, so it's gathered separately.
local bookPieces = book:GetDescendants()
table.insert(bookPieces, sheet)
for _, d in sheet:GetDescendants() do
	table.insert(bookPieces, d)
end
for _, d in bookPieces do
	if d:IsA("BasePart") then
		table.insert(bookParts, { part = d, size = d.Size })
	elseif d:IsA("SurfaceGui") then
		d.PixelsPerStud /= BOOK_SCALE
	end
end

local function shrinkBook()
	local origin = camera.CFrame.Position
	for _, entry in bookParts do
		local p = entry.part
		p.Size = entry.size * BOOK_SCALE
		p.CFrame = p.CFrame.Rotation + origin + (p.Position - origin) * BOOK_SCALE
	end
end

local function finishClose()
	if flipping then
		finishFlip()
	end
	for _, tab in tabs do
		tab.button.Visible = false
	end
	book.Parent = nil
	state = "closed"
	focus.Enabled = false
	dim.Enabled = false
end

RunService:BindToRenderStep("JournalBook", Enum.RenderPriority.Camera.Value + 10, function(dt)
	if not book.Parent then
		return
	end

	-- Keeps the to-do ticks current while the book lies open on them.
	refreshTimer += dt
	if refreshTimer > 0.25 and state == "open" and not flipping then
		refreshTimer = 0
		showSpread()
	end

	-- The camera script re-locks the mouse every frame; this runs after it. Walking and
	-- the arrow keys are untouched, and the view turns while the right button is held.
	if player:GetAttribute("ReadingJournal") then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end

	raise = approach(raise, targetRaise, RAISE_RATE, dt)
	openness = approach(openness, targetOpen, OPEN_RATE, dt)
	if state == "opening" then
		-- The covers start parting while the book is still on its way up.
		if targetOpen == 0 and raise > OPEN_AT then
			targetOpen = 1
			openSound:Play()
		end
		if openness > 0.97 then
			state = "open"
			showHint("← / →   turn page          click a bookmark   jump          G   close", true)
		end
	elseif state == "switching" then
		if not closeSounded and openness < 0.2 then
			closeSounded = true
			closeSound:Play()
		end
		-- Shut: swap to the bookmarked spread unseen, then reopen through the normal path.
		if openness < 0.05 then
			spread = goalSpread
			goalSpread = nil
			showSpread()
			state = "opening"
		end
	elseif state == "closing" then
		if not closeSounded and openness < 0.2 then
			closeSounded = true
			closeSound:Play()
		end
		if openness < DROP_AT then
			targetRaise = 0
		end
		if raise < 0.01 then
			finishClose()
			return
		end
	end
	if flipping then
		flipAngle = approach(flipAngle, flipTarget, FLIP_RATE, dt)
		if math.abs(flipTarget - flipAngle) < 0.03 then
			finishFlip()
		end
	end

	local lowered = 1 - raise
	local t = os.clock()
	pageShake = approach(pageShake, 0, 7, dt)
	local sway = CFrame.Angles(math.sin(t * 0.9) * 0.008, math.sin(t * 0.6) * 0.006, math.sin(t * 0.7) * 0.008)
		* CFrame.Angles(math.sin(t * 46) * 0.012 * pageShake, math.sin(t * 39) * 0.01 * pageShake, math.sin(t * 43) * 0.015 * pageShake)
	-- Locked to the camera so the spread stays centred. While shut the book is
	-- slid half a page left so the closed book, not the spine, is what's centred.
	local root = camera.CFrame
		* CFrame.new(-PAGE_W / 2 * (1 - openness), LOWERED_Y * lowered, -HOLD_DISTANCE)
		* CFrame.Angles(math.rad(90 - LOWERED_TILT * lowered), 0, 0)
		* sway

	rightBlock.CFrame = root * CFrame.new(PAGE_W / 2, 0, 0) * PAGE_TURN
	rightCover.CFrame = root * CFrame.new(PAGE_W / 2 + COVER_MARGIN, -0.07, 0)
	spine.CFrame = root * CFrame.new(0, -0.07, 0)
	gutter.CFrame = root * CFrame.new(0, 0.051, 0)
	for _, ring in rings do
		ring.part.CFrame = root * ring.offset
	end
	-- The left half hinges at the spine and folds over the right half when shut.
	local hinge = root * CFrame.new(0, 0.05, 0)
	local fold = hinge * CFrame.Angles(0, 0, -math.pi * (1 - openness))
	leftBlock.CFrame = fold * CFrame.new(-PAGE_W / 2, -0.05, 0) * PAGE_TURN
	leftCover.CFrame = fold * CFrame.new(-(PAGE_W / 2 + COVER_MARGIN), -0.12, 0)
	for _, s in stacks do
		local frame = s.side > 0 and root * CFrame.new(0, 0.05, 0) or fold
		local outward = s.layer * 0.012
		s.part.CFrame = frame
			* CFrame.new(s.side * (PAGE_W / 2 + outward), -0.05 - 0.03 - s.layer * 0.004, outward * 1.4)
			* PAGE_TURN
	end
	local reading = sectionAt(spread)
	for _, tab in tabs do
		local frame = tab.side > 0 and root * CFrame.new(0, 0.05, 0) or fold
		tab.lift = approach(tab.lift, tab.section == reading and 0.05 or 0, 14, dt)
		-- Tucked just under the top edge so only the coloured tip shows above the page.
		tab.part.CFrame = frame * CFrame.new(tab.side * tab.x, -0.07, -(PAGE_H / 2 + 0.03 + tab.lift))
		tab.button.Visible = state == "open"
		if tab.button.Visible then
			local tip = camera:WorldToViewportPoint(tab.part.CFrame:PointToWorldSpace(Vector3.new(0, 0, -0.11)))
			tab.button.Position = UDim2.fromOffset(tip.X, tip.Y - 26)
		end
	end
	if sheet.Parent then
		local sheetCf = hinge * CFrame.Angles(0, 0, flipAngle) * CFrame.new(PAGE_W / 2, 0.004, 0) * PAGE_TURN
		sheet.CFrame = sheetCf * CFrame.new(0, 0.001, 0)
		sheetBackPart.CFrame = sheetCf * CFrame.new(0, -0.001, 0) * CFrame.Angles(0, math.pi, 0)
	end
	shrinkBook()
end)

local function setFocus(on)
	focus.Enabled = true
	dim.Enabled = true
	local info = TweenInfo.new(on and 0.6 or 0.4)
	TweenService:Create(focus, info, { FarIntensity = on and 1 or 0 }):Play()
	TweenService:Create(dim, info, { Brightness = on and -0.06 or 0, Saturation = on and -0.2 or 0 }):Play()
end

-- Page turns while the book is up. Only the arrow keys are taken, so WASD still walks.
local function onBookInput(_, inputState, input)
	if inputState == Enum.UserInputState.Begin and state ~= "switching" then
		if input.KeyCode == Enum.KeyCode.Right then
			flip(1)
		elseif input.KeyCode == Enum.KeyCode.Left then
			flip(-1)
		end
	end
	return Enum.ContextActionResult.Sink
end

local function holdInput(on)
	if on == inputBound then
		return
	end
	inputBound = on
	if on then
		ContextActionService:BindActionAtPriority(
			"JournalInput",
			onBookInput,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.Left,
			Enum.KeyCode.Right
		)
	else
		ContextActionService:UnbindAction("JournalInput")
	end
end

-- Tells the server, which floats a book icon over your head for other players.
local readRemote = ReplicatedStorage:WaitForChild("JournalRead")

local function openBook()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if state == "closed" then
		raise, openness = 0, 0
		showSpread()
		book.Parent = camera
	end
	-- Reopening mid-close just turns the book round; it chases the new targets from where it is.
	state = "opening"
	targetRaise, targetOpen = 1, 0
	player:SetAttribute("ReadingJournal", true)
	readRemote:FireServer(true)
	holdInput(true)
	setFocus(true)
end

local function closeBook(instant)
	if state == "closed" then
		return
	end
	state = "closing"
	targetOpen = 0
	closeSounded = openness < 0.2
	showHint(nil, false)
	goalSpread = nil
	-- Back to the crosshair dot (Camera.client hides the system cursor); it re-locks the mouse itself.
	UserInputService.MouseIconEnabled = false
	player:SetAttribute("ReadingJournal", false)
	readRemote:FireServer(false)
	holdInput(false)
	setFocus(false)
	if instant then
		finishClose()
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.KeyCode ~= Enum.KeyCode.G or not player:GetAttribute("HasJournal") then
		return
	end
	if state == "closed" or state == "closing" then
		openBook()
	else
		closeBook(false)
	end
end)

player.CharacterRemoving:Connect(function()
	closeBook(true)
end)

-- ================= PICKUP =================
-- Everyone takes their own copy, so once you have yours the lobby book disappears for you only.
local markerTween

local function removeMarker()
	if markerTween then
		markerTween:Cancel()
		markerTween = nil
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local marker = playerGui and playerGui:FindFirstChild("JournalMarker")
	if marker then
		marker:Destroy()
	end
end

local function hideLobbyBook()
	removeMarker()
	local stand = workspace:FindFirstChild("JournalStand")
	local lobbyBook = stand and stand:FindFirstChild("Journal")
	if not lobbyBook then
		return
	end
	for _, d in lobbyBook:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		elseif d:IsA("ProximityPrompt") or d:IsA("Light") then
			d.Enabled = false
		end
	end
end

local function onHasJournal()
	if not player:GetAttribute("HasJournal") then
		return
	end
	hideLobbyBook()
	showHint("Press G to read your journal", true)
	task.delay(4, function()
		if state == "closed" then
			showHint(nil, false)
		end
	end)
end
player:GetAttributeChangedSignal("HasJournal"):Connect(onHasJournal)
if player:GetAttribute("HasJournal") then
	hideLobbyBook()
end

-- The marker above the lobby book (see makeMarker), so it's obvious
-- what to walk up to. The stand is built by the server and may stream in late.
task.spawn(function()
	local stand = workspace:WaitForChild("JournalStand")
	local cover = stand:WaitForChild("Journal"):WaitForChild("Cover")
	if player:GetAttribute("HasJournal") then
		return
	end
	local marker, tween = makeMarker("JournalMarker", "Take the journal")
	marker.Adornee = cover
	marker.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	marker.Enabled = true
	markerTween = tween
end)
