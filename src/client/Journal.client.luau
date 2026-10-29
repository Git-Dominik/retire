-- G reads the journal once you've picked it up in the lobby (Journal.server).
-- The book rises from the bottom of the screen and starts opening as it nears
-- the centre, while the view tips down and the world behind falls out of focus.
-- The left/right arrow keys turn pages, and the coloured bookmarks jump between
-- sections (Guides, Floor, Money). The cursor is freed to click them; you can keep
-- walking while reading, only the view's up/down angle is held (Camera.client) and
-- the view turns only while the right mouse button is held.
-- Everything moves with the same exponential smoothing as the camera and
-- movement (no tweens), so it chases its target the instant input changes.
-- Guides holds the To do page: the first-time tutorial's steps while it runs, the daily
-- routine after (TutorialClient, which also owns the arrow over each step's object).
-- Floor tracks the current floor's items and the cargo lift; Money shows the Player "Money"
-- attribute (set by Cargo.server, this session only) and the deliveries behind it.
-- Once you've taken your copy, the stand's book (tagged JournalStand) is hidden for you
-- alone, again each time the store comes back from being put away. The camera tilt lives
-- in Camera.client, which watches the ReadingJournal attribute this script sets on the
-- local player.
-- The book is laid out at full size each frame, then shrunk towards the camera (BOOK_SCALE)
-- so walls can't clip through it.
-- The first page shows the current day from the workspace DayNumber attribute
-- (DayNightService), the same one ShopHUD shows, and redraws when it changes.
-- Requests lists the item requests (QuestService, through QuestClient's copy of the
-- ReplicatedStorage QuestList attribute): the active ones as a list with the client's
-- headshot and the item, soonest due first, then what became of the latest finished ones.
-- A page with a `fill` draws its own instances into the page's List frame.

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

local HAND = Font.fromEnum(Enum.Font.Kalam)
local HAND_BOLD = Font.new(HAND.Family, Enum.FontWeight.Bold)

-- ================= TO-DO LIST =================
local TutorialClient = require(script.Parent:WaitForChild("TutorialClient"))
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

-- Up to this many of the floor's items are listed, still-there ones first.
local FLOOR_LINES = 7

local function floorPage()
	local elevator = workspace:FindFirstChild("Elevator")
	local level = elevator and elevator:GetAttribute("Level") or 0
	-- Elevator.server tags the items on the floor you're standing on.
	local items = level > 0 and CollectionService:GetTagged("ScavengeItem") or {}
	if #items == 0 then
		return "Floor", "Nothing to track yet.\n\nRide the elevator down and each floor's finds are written here."
	end
	local left, gone = {}, {}
	for _, item in items do
		local prompt = item:FindFirstChild("TakePrompt")
		table.insert(prompt and prompt.Enabled and left or gone, item)
	end
	local lines = {}
	for _, item in left do
		table.insert(lines, `<b>{item.Name}</b>  ${item:GetAttribute("Value") or 0}`)
	end
	for _, item in gone do
		table.insert(lines, `<s>{item.Name}</s>  <font color="{CHECK_INK}">taken</font>`)
	end
	while #lines > FLOOR_LINES do
		table.remove(lines)
	end
	local status = carryingScavenged() and "Something in your hands"
		or liftAttribute("CargoValue") > 0 and "Something on the cargo lift"
		or `{#left} still lying about`
	return `Floor {level}`,
		`<font size="20">{table.concat(lines, "\n")}</font>\n\n<font color="{CHECK_INK}">{status}</font>`
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

-- ================= REQUESTS =================
-- Active requests fill the first REQUEST_PAGES pages, REQUESTS_PER_PAGE each; the page
-- after them lists the finished ones.
local QuestClient = require(script.Parent:WaitForChild("QuestClient"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
local StockItems = require(Shared:WaitForChild("StockItems"))

local REQUESTS_PER_PAGE = 3
local REQUEST_HEIGHT = 110
local REQUEST_PAGES = math.max(1, math.ceil(ShopConfig.MAX_ACTIVE_QUESTS / REQUESTS_PER_PAGE))
local STOCK_INK = Color3.fromRGB(58, 86, 40)
local STOCK_INK_HEX = "#3a5628"

local function escape(text)
	return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function itemName(itemId)
	local item = StockItems.get(itemId)
	return item and item.name or tostring(itemId)
end

-- "Floor 2, Floor 3", from the item's floorIds and ShopConfig.FLOOR_NAMES.
local function floorsText(itemId)
	local item = StockItems.get(itemId)
	local names = {}
	for _, floor in item and item.floorIds or {} do
		table.insert(names, ShopConfig.FLOOR_NAMES[floor] or `Floor {floor}`)
	end
	return #names > 0 and table.concat(names, ", ") or "nobody knows"
end

local function activeRequests()
	local list = {}
	for _, quest in QuestClient.list() do
		if quest.Status == "Active" then
			table.insert(list, quest)
		end
	end
	table.sort(list, function(a, b)
		if a.DueDay ~= b.DueDay then
			return a.DueDay < b.DueDay
		end
		return a.QuestId < b.QuestId
	end)
	return list
end

local function rounded(gui, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = gui
end

local function inked(gui, color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1.5
	stroke.Transparency = 0.4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = gui
end

-- A small picture of the item: its template from ReplicatedStorage.StockItems, seen from
-- the front and a little above.
local function itemIcon(parent, itemId)
	local view = Instance.new("ViewportFrame")
	view.Name = "Icon"
	view.Position = UDim2.fromOffset(36, 38)
	view.Size = UDim2.fromOffset(32, 32)
	view.BackgroundColor3 = PAPER
	view.BorderSizePixel = 0
	view.Ambient = Color3.fromRGB(190, 176, 150)
	view.LightColor = Color3.fromRGB(255, 236, 210)
	view.LightDirection = Vector3.new(-1, -1, 1)
	view.Parent = parent
	rounded(view, 6)
	inked(view, ACCENT)
	local item = StockItems.get(itemId)
	local folder = ReplicatedStorage:FindFirstChild("StockItems")
	local template = item and folder and folder:FindFirstChild(item.model)
	if not template then
		return
	end
	local model = template:Clone()
	model:PivotTo(CFrame.identity)
	model.Parent = view
	local center, size = model:GetBoundingBox()
	local viewCamera = Instance.new("Camera")
	viewCamera.FieldOfView = 30
	-- Far enough back that the whole item fits the 30° view; the front is the pivot's LookVector.
	local distance = size.Magnitude / 2 / math.tan(math.rad(15))
	viewCamera.CFrame = CFrame.lookAt(center.Position + Vector3.new(0.5, 0.5, -1).Unit * distance, center.Position)
	viewCamera.Parent = view
	view.CurrentCamera = viewCamera
end

-- One active request: headshot with the item beside it, an "In stock" tag under them, and
-- who, what, when, where and how much. Washed in red ink when it's due today.
local function requestEntry(list, order, quest, day)
	local dueToday = quest.DueDay <= day
	local entry = Instance.new("Frame")
	entry.Name = "Request"
	entry.LayoutOrder = order
	entry.Size = UDim2.new(1, 0, 0, REQUEST_HEIGHT)
	entry.BackgroundColor3 = ACCENT
	entry.BackgroundTransparency = dueToday and 0.86 or 1
	entry.BorderSizePixel = 0
	entry.Parent = list
	rounded(entry, 6)

	local face = Instance.new("ImageLabel")
	face.Name = "Headshot"
	face.Position = UDim2.fromOffset(4, 6)
	face.Size = UDim2.fromOffset(52, 52)
	face.BackgroundColor3 = PAPER_EDGE
	face.BorderSizePixel = 0
	face.Image = `rbxthumb://type=AvatarHeadShot&id={quest.ClientUserId}&w=150&h=150`
	face.Parent = entry
	rounded(face, 26)
	inked(face, INK)
	itemIcon(entry, quest.ItemId)

	if quest.InStock then
		local tag = Instance.new("TextLabel")
		tag.Name = "InStock"
		tag.Position = UDim2.fromOffset(2, 78)
		tag.Size = UDim2.fromOffset(66, 22)
		tag.BackgroundTransparency = 1
		tag.FontFace = HAND_BOLD
		tag.TextSize = 15
		tag.TextColor3 = STOCK_INK
		tag.Text = "In stock"
		tag.Parent = entry
		rounded(tag, 4)
		inked(tag, STOCK_INK)
	end

	local left = quest.DueDay - day
	local when = left <= 0 and "today!" or left == 1 and "1 day left" or `{left} days left`
	local due = `Due: Day {quest.DueDay} ({when})`
	if dueToday then
		due = `<font color="{CHECK_INK}"><b>{due}</b></font>`
	end
	local details = Instance.new("TextLabel")
	details.Name = "Details"
	details.Position = UDim2.fromOffset(76, 4)
	details.Size = UDim2.new(1, -78, 1, -4)
	details.BackgroundTransparency = 1
	details.FontFace = HAND
	details.TextSize = 17
	details.TextColor3 = INK
	details.RichText = true
	details.TextWrapped = true
	details.TextXAlignment = Enum.TextXAlignment.Left
	details.TextYAlignment = Enum.TextYAlignment.Top
	details.Text = table.concat({
		`<b>{escape(quest.ClientName)}</b>`,
		`Wants: <b>{escape(itemName(quest.ItemId))}</b>`,
		due,
		`Found on: {floorsText(quest.ItemId)}`,
		`<i>Active</i>  ·  pays <b>${quest.RewardPrice}</b>`,
	}, "\n")
	details.Parent = entry
end

-- Draws this page's share of the active requests. It runs on every page refresh, so the
-- entries are only rebuilt when something on them changes.
local function fillRequests(pageNumber)
	return function(list)
		local day = workspace:GetAttribute("DayNumber") or 1
		local active = activeRequests()
		local shown = {}
		for i = (pageNumber - 1) * REQUESTS_PER_PAGE + 1, math.min(#active, pageNumber * REQUESTS_PER_PAGE) do
			table.insert(shown, active[i])
		end
		local key = { pageNumber, day }
		for _, quest in shown do
			table.insert(key, `{quest.QuestId}:{quest.Status}:{quest.InStock}`)
		end
		local signature = table.concat(key, "|")
		if list:GetAttribute("Signature") == signature then
			return
		end
		list:SetAttribute("Signature", signature)
		for _, child in list:GetChildren() do
			if child.Name == "Request" then
				child:Destroy()
			end
		end
		for i, quest in shown do
			requestEntry(list, i, quest, day)
		end
	end
end

local function requestsPage(pageNumber)
	return {
		render = function()
			if pageNumber == 1 and #activeRequests() == 0 then
				return "Requests",
					"No requests right now.\n\nNow and then someone writes in wanting one thing in particular, and pays well for it. A new one may come at dawn."
			end
			return pageNumber == 1 and "Requests" or "Requests, cont.", ""
		end,
		fill = fillRequests(pageNumber),
	}
end

-- What became of the latest finished requests, newest first.
local function pastRequestsPage()
	local lines = {}
	for _, quest in QuestClient.list() do
		if quest.Status ~= "Active" then
			local outcome = quest.Status == "Completed"
					and `<font color="{STOCK_INK_HEX}">Completed: paid ${quest.RewardPrice}</font>`
				or `<font color="{CHECK_INK}">Failed: not sold on Day {quest.DueDay}</font>`
			table.insert(lines, `<b>{escape(itemName(quest.ItemId))}</b> for {escape(quest.ClientName)}\n{outcome}`)
		end
	end
	return "Past requests",
		#lines > 0 and `<font size="19">{table.concat(lines, "\n\n")}</font>` or "Nothing settled yet."
end

local requestPages = {}
for pageNumber = 1, REQUEST_PAGES do
	table.insert(requestPages, requestsPage(pageNumber))
end
table.insert(requestPages, { render = pastRequestsPage })

local SECTIONS = {
	{
		name = "Guides",
		color = Color3.fromRGB(196, 168, 74),
		side = -1,
		x = 0.5,
		pages = {
			{
				render = function()
					local day = workspace:GetAttribute("DayNumber") or 1
					return "Property of",
						`\n—\n\n<font size="44"><b>Day {day}</b></font>\n\nIf found, do not return it to the elevator.`
				end,
			},
			{
				render = function()
					return "To do", TutorialClient.todoText()
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
	{
		name = "Requests",
		color = Color3.fromRGB(88, 98, 140),
		side = -1,
		x = 0.2,
		pages = requestPages,
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

	-- Where a page with a `fill` puts its own instances (the Requests list), under the title.
	local list = Instance.new("Frame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(42, 100)
	list.Size = UDim2.new(1, -84, 1, -150)
	list.BackgroundTransparency = 1
	list.Visible = false
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list
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
	gui.List.Visible = page ~= nil and page.fill ~= nil
	if gui.List.Visible then
		page.fill(gui.List)
	end
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

-- A new day redraws the open spread straight away (the first page shows it).
workspace:GetAttributeChangedSignal("DayNumber"):Connect(function()
	if book.Parent and not flipping then
		showSpread()
	end
end)

-- ================= PICKUP =================
-- Everyone takes their own copy, so once you have yours the stand's book disappears for you
-- only. The store (and the stand with it) is put away while the elevator is down and comes
-- back as fresh copies, so it's hidden again every time it turns up.
local function hideLobbyBook(stand)
	local lobbyBook = stand:FindFirstChild("Journal")
	if not lobbyBook or not player:GetAttribute("HasJournal") then
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

local function hideAll()
	for _, stand in CollectionService:GetTagged("JournalStand") do
		hideLobbyBook(stand)
	end
end
CollectionService:GetInstanceAddedSignal("JournalStand"):Connect(function(stand)
	-- Its parts may still be arriving.
	stand:WaitForChild("Journal"):WaitForChild("Cover")
	hideLobbyBook(stand)
end)

player:GetAttributeChangedSignal("HasJournal"):Connect(function()
	if not player:GetAttribute("HasJournal") then
		return
	end
	hideAll()
	showHint("Press G to read your journal", true)
	task.delay(4, function()
		if state == "closed" then
			showHint(nil, false)
		end
	end)
end)
hideAll()
