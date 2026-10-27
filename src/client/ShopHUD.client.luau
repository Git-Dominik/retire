-- The shop's UI, in the HUD's cream-on-dark style:
--   top right     the time of day
--   notice board  the day, today's earnings against the quota (with strikes) and the till,
--                 handwritten on the papers pinned in the break room (see NOTICE BOARD)
--   centre        the haggling window, while you hold a counter negotiation
--   centre        the end-of-day summary, SUMMARY_TIME seconds after each dusk
-- Display only. It reads workspace DayNumber / Phase / the clock anchor (DayNightService)
-- and the ReplicatedStorage attributes ShopMoney, DayEarnings, Quota, Strikes,
-- MaxStrikes, ShopFailed (QuotaService). The day here and in the journal both come from
-- DayNumber, so they always agree.
-- Remotes: Haggle (open / update / close, from CounterService) and HaggleAction (our
-- button presses; the server checks every one), DaySummary and ShopFailed (QuotaService).
-- While the haggling window is open the cursor is freed, the way the journal frees it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))

local player = Players.LocalPlayer

local CREAM = Color3.fromRGB(255, 228, 196)
local MUTED = Color3.fromRGB(196, 172, 142)
local PANEL = Color3.fromRGB(28, 17, 12)
local WOOD = Color3.fromRGB(58, 36, 24)
local GOLD = Color3.fromRGB(214, 168, 96)
local GREEN = Color3.fromRGB(150, 182, 112)
local OXBLOOD = Color3.fromRGB(150, 58, 46)
local PANEL_T = 0.25
local MARGIN = 26

local function new(class, props, parent)
	local instance = Instance.new(class)
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function round(parent, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end

local function rim(parent, color, transparency)
	return new("UIStroke", {
		Color = color or GOLD,
		Thickness = 1.5,
		Transparency = transparency or 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function text(parent, props)
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or CREAM
	props.Font = props.Font or Enum.Font.GothamBold
	return new("TextLabel", props, parent)
end

local gui = new("ScreenGui", {
	Name = "ShopHUD",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 6,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

local function shop(name)
	return ReplicatedStorage:GetAttribute(name) or 0
end

-- ================= CLOCK =================
local panel = new("Frame", {
	Name = "Clock",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -MARGIN, 0, MARGIN),
	Size = UDim2.fromOffset(110, 34),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = PANEL_T,
	BorderSizePixel = 0,
}, gui)
round(panel, 10)
rim(panel)
local clockLabel = text(panel, {
	Size = UDim2.fromScale(1, 1),
	TextSize = 15,
	TextColor3 = GOLD,
})

local function clockText()
	local anchorTime = workspace:GetAttribute("ClockAnchorTime")
	local anchorHour = workspace:GetAttribute("ClockAnchorHour")
	local length = workspace:GetAttribute("DayLength")
	if not (anchorTime and anchorHour and length) then
		return ""
	end
	local hour = workspace:GetAttribute("ClockPaused") and anchorHour
		or (anchorHour + (workspace:GetServerTimeNow() - anchorTime) * 24 / length) % 24
	-- Five-minute steps; at this clock speed single minutes would flicker past.
	local minutes = math.floor(hour * 12) * 5
	local h, m = minutes // 60, minutes % 60
	local twelve = h % 12 == 0 and 12 or h % 12
	return string.format("%d:%02d %s", twelve, m, h < 12 and "AM" or "PM")
end

-- ================= NOTICE BOARD =================
-- The day, the quota and the till are written by hand on the papers pinned to the break
-- room's notice board: parts tagged ShopNote (place-only), each with a Shows attribute of
-- "Day", "Quota" or "Money". Each gets a SurfaceGui on its Front face, kept in PlayerGui
-- so the papers themselves are never changed, and rebuilt if a paper streams back in.
local HAND = Font.fromEnum(Enum.Font.Kalam)
local HAND_BOLD = Font.new(HAND.Family, Enum.FontWeight.Bold)
local INK = Color3.fromRGB(46, 34, 26)
local RED_INK = Color3.fromRGB(112, 30, 26)
local GREEN_INK = Color3.fromRGB(58, 86, 40)

local function line(parent, order, height, font, value)
	return new("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		FontFace = font,
		TextScaled = true,
		TextColor3 = INK,
		Text = value or "",
	}, parent)
end

-- A paper's writing surface: a column of lines, centred, inset from the edges.
local function noteGui(paper)
	local surface = new("SurfaceGui", {
		Name = "ShopNote",
		Adornee = paper,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 240,
		LightInfluence = 0.6,
		ClipsDescendants = true,
		ResetOnSpawn = false,
	}, gui.Parent)
	local column = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.82, 0.86),
		BackgroundTransparency = 1,
	}, surface)
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	}, column)
	return surface, column
end

-- Each kind of note: build(column) returns the function that rewrites it.
local NOTES = {
	Day = function(column)
		line(column, 1, 44, HAND, "Today is")
		local day = line(column, 2, 96, HAND_BOLD)
		local phase = line(column, 3, 40, HAND)
		return function()
			day.Text = `Day {workspace:GetAttribute("DayNumber") or 1}`
			local closed = workspace:GetAttribute("Phase") == "Night"
			phase.Text = closed and "closed for the night" or "open"
			phase.TextColor3 = closed and RED_INK or INK
		end
	end,
	Quota = function(column)
		line(column, 1, 54, HAND_BOLD, "Quota")
		local earned = line(column, 2, 78, HAND_BOLD)
		local target = line(column, 3, 40, HAND)
		-- A box drawn in ink, filled in as the day's takings come in.
		local box = new("Frame", {
			LayoutOrder = 4,
			Size = UDim2.new(0.9, 0, 0, 26),
			BackgroundTransparency = 1,
		}, column)
		new("UIStroke", { Color = INK, Thickness = 3, Transparency = 0.15 }, box)
		local fillBar = new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
		}, box)
		local strikes = line(column, 5, 38, HAND)
		return function()
			local taken, quota = shop("DayEarnings"), shop("Quota")
			local progress = quota > 0 and math.clamp(taken / quota, 0, 1) or 0
			earned.Text = `${taken}`
			target.Text = progress >= 1 and `of ${quota} - met!` or `of ${quota}`
			target.TextColor3 = progress >= 1 and GREEN_INK or INK
			fillBar.Size = UDim2.fromScale(progress, 1)
			if ReplicatedStorage:GetAttribute("ShopFailed") then
				strikes.Text = "SHOP FAILED"
				strikes.TextColor3 = RED_INK
			else
				strikes.Text = `strikes {shop("Strikes")} / {shop("MaxStrikes")}`
				strikes.TextColor3 = shop("Strikes") > 0 and RED_INK or INK
			end
		end
	end,
	Money = function(column)
		line(column, 1, 54, HAND_BOLD, "In the till")
		local money = line(column, 2, 90, HAND_BOLD)
		return function()
			money.Text = `${shop("ShopMoney")}`
		end
	end,
}

local notes = {} -- [paper] = { gui, refresh }

local function refreshNotes()
	for _, note in notes do
		note.refresh()
	end
end

local function addNote(paper)
	local build = NOTES[paper:GetAttribute("Shows")]
	if not build or notes[paper] or not paper:IsA("BasePart") then
		return
	end
	local surface, column = noteGui(paper)
	notes[paper] = { gui = surface, refresh = build(column) }
	notes[paper].refresh()
end

CollectionService:GetInstanceAddedSignal("ShopNote"):Connect(addNote)
CollectionService:GetInstanceRemovedSignal("ShopNote"):Connect(function(paper)
	local note = notes[paper]
	notes[paper] = nil
	if note then
		note.gui:Destroy()
	end
end)
for _, paper in CollectionService:GetTagged("ShopNote") do
	addNote(paper)
end

for _, name in { "DayEarnings", "Quota", "ShopMoney", "Strikes", "MaxStrikes", "ShopFailed" } do
	ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refreshNotes)
end
workspace:GetAttributeChangedSignal("DayNumber"):Connect(refreshNotes)
workspace:GetAttributeChangedSignal("Phase"):Connect(refreshNotes)

-- ================= HAGGLING =================
local haggleRemote = ReplicatedStorage:WaitForChild("Haggle")
local actionRemote = ReplicatedStorage:WaitForChild("HaggleAction")

local window = new("Frame", {
	Name = "Haggle",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -170),
	Size = UDim2.fromOffset(340, 214),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	Visible = false,
}, gui)
round(window, 12)
rim(window, GOLD, 0.2)
new("UIPadding", {
	PaddingLeft = UDim.new(0, 18),
	PaddingRight = UDim.new(0, 18),
	PaddingTop = UDim.new(0, 14),
	PaddingBottom = UDim.new(0, 14),
}, window)

local itemLabel = text(window, {
	Size = UDim2.new(1, -30, 0, 22),
	TextSize = 19,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local tagLabel = text(window, {
	Position = UDim2.fromOffset(0, 24),
	Size = UDim2.new(1, 0, 0, 16),
	TextSize = 12,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local offerLabel = text(window, {
	Position = UDim2.fromOffset(0, 46),
	Size = UDim2.new(1, 0, 0, 30),
	TextSize = 24,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local function button(parent, label, color, props)
	local b = new("TextButton", {
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.1,
		AutoButtonColor = true,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = props.TextSize or 14,
		TextColor3 = CREAM,
		Text = label,
	}, parent)
	round(b, 8)
	rim(b, CREAM, 0.7)
	return b
end

local closeButton = button(window, "×", WOOD, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(26, 26),
	TextSize = 18,
})

-- The counter price stepper: − $price (percent) +
local stepRow = new("Frame", {
	Position = UDim2.fromOffset(0, 86),
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = WOOD,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
}, window)
round(stepRow, 8)
local minusButton =
	button(stepRow, "−", PANEL, { Size = UDim2.fromOffset(40, 34), TextSize = 20 })
local plusButton = button(stepRow, "+", PANEL, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(40, 34),
	TextSize = 20,
})
local counterLabel = text(stepRow, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -90, 1, 0),
	TextSize = 16,
})

local buttonRow = new("Frame", {
	Position = UDim2.fromOffset(0, 130),
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundTransparency = 1,
}, window)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 8),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, buttonRow)
local third = UDim2.new(1 / 3, -6, 1, 0)
local acceptButton = button(buttonRow, "Accept", Color3.fromRGB(70, 92, 52), { Size = third })
local counterButton = button(buttonRow, "Counter", Color3.fromRGB(122, 90, 44), { Size = third })
local refuseButton = button(buttonRow, "Refuse", OXBLOOD, { Size = third })

local timerTrack = new("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 4),
	BackgroundColor3 = WOOD,
	BorderSizePixel = 0,
}, window)
round(timerTrack, 2)
local timerFill = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = MUTED,
	BorderSizePixel = 0,
}, timerTrack)
round(timerFill, 2)

local deal -- the open negotiation's public numbers, or nil
local counterPercent = 100
local timerSpan = 1

local function counterPrice()
	return math.floor(deal.basePrice * counterPercent / 100 + 0.5)
end

local function refreshWindow()
	if not deal then
		return
	end
	itemLabel.Text = deal.itemName
	tagLabel.Text = `Tag price ${deal.basePrice}`
	offerLabel.Text = `Their offer: ${deal.offer}`
	counterLabel.Text = `${counterPrice()}  ({counterPercent}%)`
	minusButton.Visible = counterPercent > deal.range[1]
	plusButton.Visible = counterPercent < deal.range[2]
end

local function showDeal(data)
	local first = deal == nil or deal.spot ~= data.spot
	deal = data
	if first then
		-- Start the counter one step above their offer.
		local step = data.step
		local above = math.ceil(data.offer / data.basePrice * 100 / step) * step + step
		counterPercent = math.clamp(above, data.range[1], data.range[2])
	end
	timerSpan = math.max(data.deadline - workspace:GetServerTimeNow(), 1)
	window.Visible = true
	refreshWindow()
end

local function hideDeal()
	deal = nil
	window.Visible = false
	-- Hand the cursor back; the camera re-locks it next frame.
	UserInputService.MouseIconEnabled = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

local function send(action, value)
	if deal then
		actionRemote:FireServer(deal.spot, action, value)
	end
end

minusButton.Activated:Connect(function()
	if deal then
		counterPercent = math.max(counterPercent - deal.step, deal.range[1])
		refreshWindow()
	end
end)
plusButton.Activated:Connect(function()
	if deal then
		counterPercent = math.min(counterPercent + deal.step, deal.range[2])
		refreshWindow()
	end
end)
acceptButton.Activated:Connect(function()
	send("accept")
end)
counterButton.Activated:Connect(function()
	send("counter", counterPercent)
end)
refuseButton.Activated:Connect(function()
	send("refuse")
end)
closeButton.Activated:Connect(function()
	send("close")
	hideDeal()
end)

haggleRemote.OnClientEvent:Connect(function(kind, data)
	if kind == "open" or kind == "update" then
		showDeal(data)
	elseif kind == "close" and (not deal or deal.spot == data) then
		hideDeal()
	end
end)

-- After the camera, so the freed cursor wins over its first-person lock; also runs the
-- response timer bar.
RunService:BindToRenderStep("ShopHaggle", Enum.RenderPriority.Camera.Value + 15, function()
	if not deal then
		return
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	local left = math.max(deal.deadline - workspace:GetServerTimeNow(), 0)
	timerFill.Size = UDim2.fromScale(math.clamp(left / timerSpan, 0, 1), 1)
	timerFill.BackgroundColor3 = left < 10 and OXBLOOD or MUTED
end)

player.CharacterRemoving:Connect(function()
	if deal then
		hideDeal()
	end
end)

-- ================= END OF DAY =================
local summary = new("Frame", {
	Name = "DaySummary",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(320, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	Visible = false,
}, gui)
round(summary, 12)
local summaryRim = rim(summary, GOLD, 0.2)
new("UIPadding", {
	PaddingLeft = UDim.new(0, 22),
	PaddingRight = UDim.new(0, 22),
	PaddingTop = UDim.new(0, 18),
	PaddingBottom = UDim.new(0, 18),
}, summary)
new("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, summary)
local summaryScale = new("UIScale", {}, summary)

local summaryTitle = text(summary, {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 26),
	TextSize = 20,
})
local summaryRows = {}
for i, caption in { "Earned", "Quota", "Sales", "Left without buying", "Stolen" } do
	local row = new("Frame", {
		LayoutOrder = 1 + i,
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
	}, summary)
	text(row, {
		Size = UDim2.fromScale(0.65, 1),
		TextSize = 14,
		TextColor3 = MUTED,
		Text = caption,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	summaryRows[caption] = text(row, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.35, 1),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
end
local summaryResult = text(summary, {
	LayoutOrder = 10,
	Size = UDim2.new(1, 0, 0, 30),
	TextSize = 16,
	TextWrapped = true,
})

local summaryToken
local function showSummary(data, hold)
	summaryTitle.Text = `Day {data.day} — closing time`
	summaryRows["Earned"].Text = `${data.earned}`
	summaryRows["Quota"].Text = `${data.quota}`
	summaryRows["Sales"].Text = tostring(data.sales)
	summaryRows["Left without buying"].Text = tostring(data.walkouts)
	summaryRows["Stolen"].Text = data.stolen > 0 and `${data.stolen}` or "—"
	if data.failed then
		summaryResult.Text = "Quota missed. The shop has failed."
		summaryResult.TextColor3 = Color3.fromRGB(214, 112, 88)
		summaryRim.Color = OXBLOOD
	elseif data.met then
		summaryResult.Text = "Quota met."
		summaryResult.TextColor3 = GREEN
		summaryRim.Color = GOLD
	else
		summaryResult.Text = `Quota missed. Strike {data.strikes} of {data.maxStrikes}.`
		summaryResult.TextColor3 = Color3.fromRGB(214, 112, 88)
		summaryRim.Color = OXBLOOD
	end

	local token = {}
	summaryToken = token
	summary.Visible = true
	summaryScale.Scale = 0.9
	TweenService:Create(
		summaryScale,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
	task.delay(hold, function()
		if summaryToken == token then
			summary.Visible = false
		end
	end)
end

ReplicatedStorage:WaitForChild("DaySummary").OnClientEvent:Connect(function(data)
	if typeof(data) == "table" then
		-- A failure stays up a little longer.
		showSummary(data, data.failed and Config.SUMMARY_TIME * 1.5 or Config.SUMMARY_TIME)
	end
end)
ReplicatedStorage:WaitForChild("ShopFailed").OnClientEvent:Connect(refreshNotes)

-- ================= CLOCK =================
local sinceClock = math.huge
RunService.Heartbeat:Connect(function(dt)
	sinceClock += dt
	if sinceClock >= 0.25 then
		sinceClock = 0
		clockLabel.Text = clockText()
	end
end)
