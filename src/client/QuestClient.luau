-- The client's copy of the item requests (QuestService), and the "New request" notice.
-- Display only: the server decides everything. Reads the ReplicatedStorage attribute
-- QuestList (a JSON array of active requests, soonest due first, then the latest finished
-- ones, newest first). Each entry: QuestId, ClientUserId, ClientName, ItemId, IssuedDay,
-- DueDay, RewardPrice, Status ("Active", "Completed", "Failed") and InStock.
--
-- Required by Journal.client, which draws the Requests pages from QuestClient.list(). The
-- notice slides in at the top of the screen, in ShopHUD's cream-on-dark style, whenever a
-- request appears that wasn't in the list before. The list a player joins with is taken
-- as already known, so joining doesn't announce old requests.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local StockItems = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StockItems"))

local player = Players.LocalPlayer

-- ShopHUD's palette.
local CREAM = Color3.fromRGB(255, 228, 196)
local PANEL = Color3.fromRGB(28, 17, 12)
local GOLD = Color3.fromRGB(214, 168, 96)
local MARGIN = 26
local NOTICE_TIME = 5

local QuestClient = {}

local quests = {}
local known = {} -- [QuestId] = true for every request seen

-- Every request the server lists: active ones first (soonest due), then recent finished.
function QuestClient.list()
	return quests
end

-- ================= NOTICE =================
local gui = Instance.new("ScreenGui")
gui.Name = "QuestNotice"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")

local notice = Instance.new("Frame")
notice.AnchorPoint = Vector2.new(0.5, 1)
notice.Position = UDim2.fromScale(0.5, 0)
notice.Size = UDim2.fromOffset(0, 36)
notice.AutomaticSize = Enum.AutomaticSize.X
notice.BackgroundColor3 = PANEL
notice.BackgroundTransparency = 0.25
notice.BorderSizePixel = 0
notice.Visible = false
notice.Parent = gui
Instance.new("UICorner").Parent = notice
local rim = Instance.new("UIStroke")
rim.Color = GOLD
rim.Thickness = 1.5
rim.Transparency = 0.35
rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
rim.Parent = notice
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 16)
padding.PaddingRight = UDim.new(0, 16)
padding.Parent = notice

local noticeText = Instance.new("TextLabel")
noticeText.Size = UDim2.fromScale(0, 1)
noticeText.AutomaticSize = Enum.AutomaticSize.X
noticeText.BackgroundTransparency = 1
noticeText.Font = Enum.Font.GothamBold
noticeText.TextSize = 15
noticeText.TextColor3 = CREAM
noticeText.RichText = true
noticeText.Parent = notice

local noticeToken
local SLIDE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Slides the notice down from the top edge, holds it, and slides it back up. A newer
-- notice replaces one still showing.
local function showNotice(text)
	local token = {}
	noticeToken = token
	noticeText.Text = text
	notice.Visible = true
	TweenService:Create(notice, SLIDE, { Position = UDim2.new(0.5, 0, 0, MARGIN + 36) }):Play()
	task.delay(NOTICE_TIME, function()
		if noticeToken ~= token then
			return
		end
		local out = TweenService:Create(notice, SLIDE, { Position = UDim2.fromScale(0.5, 0) })
		out:Play()
		out.Completed:Wait()
		if noticeToken == token then
			notice.Visible = false
		end
	end)
end

-- ================= DATA =================
local function load(announce)
	local raw = ReplicatedStorage:GetAttribute("QuestList")
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw or "[]")
	if not ok or typeof(list) ~= "table" then
		return
	end
	quests = list
	for _, quest in list do
		if not known[quest.QuestId] then
			known[quest.QuestId] = true
			if announce and quest.Status == "Active" then
				local item = StockItems.get(quest.ItemId)
				showNotice(
					`<font color="#d6a860">New request:</font> {item and item.name or quest.ItemId} by day {quest.DueDay}`
				)
			end
		end
	end
end

ReplicatedStorage:GetAttributeChangedSignal("QuestList"):Connect(function()
	load(true)
end)
load(false)

return QuestClient
