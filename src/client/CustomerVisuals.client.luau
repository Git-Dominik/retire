-- Draws the shop customers' speech bubbles and name tags, the offer bubble beside an item
-- on the counter, and the floating "+$" when something sells. Local and visual only:
-- CustomerService and CounterService own every bit of state and publish it as:
--   "Customer" tag on each NPC model: DisplayName, Bubble, BubbleMood attributes
--   "CounterSpot" tag on each counter spot part: OfferText attribute
--   SaleEffect remote (position, amount)
-- The billboards live in this player's PlayerGui (adorned to the NPC's head or the spot),
-- so they come and go with the tagged instances as they stream in and out.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The cream-on-dark of the HUD and prompts.
local CREAM = Color3.fromRGB(255, 228, 196)
local PANEL = Color3.fromRGB(28, 17, 12)
local GOLD = Color3.fromRGB(214, 168, 96)
local MOODS = {
	want = GOLD,
	happy = Color3.fromRGB(156, 188, 120),
	sad = Color3.fromRGB(150, 158, 178),
	annoyed = Color3.fromRGB(214, 112, 88),
}
local BUBBLE_DISTANCE = 45

local function new(class, props, parent)
	local instance = Instance.new(class)
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

-- A rounded dark bubble that grows to fit its text, with a mood-coloured rim. Returns the
-- frame and a function to set its text (nil hides it).
local function bubble(parent, anchor, position)
	local frame = new("Frame", {
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.2,
		Visible = false,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, frame)
	local rim = new("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.2 }, frame)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, frame)
	local scale = new("UIScale", {}, frame)
	local label = new("TextLabel", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = CREAM,
		Text = "",
	}, frame)

	return frame,
		function(text, mood)
			frame.Visible = text ~= nil and text ~= ""
			if not frame.Visible or label.Text == text then
				return
			end
			label.Text = text
			rim.Color = MOODS[mood] or GOLD
			scale.Scale = 0.8
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Scale = 1 })
				:Play()
		end
end

-- ================= CUSTOMERS =================
local customerGuis = {}

local function addCustomer(model)
	task.spawn(function()
		local head = model:WaitForChild("Head", 10)
		if not head or not model:IsDescendantOf(workspace) or customerGuis[model] then
			return
		end
		local gui = new("BillboardGui", {
			Name = "CustomerTag",
			Adornee = head,
			Size = UDim2.fromOffset(320, 80),
			StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0),
			MaxDistance = BUBBLE_DISTANCE,
			LightInfluence = 0,
			ResetOnSpawn = false,
		}, playerGui)
		customerGuis[model] = gui
		new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = CREAM,
			TextTransparency = 0.15,
			TextStrokeTransparency = 0.55,
			Text = model:GetAttribute("DisplayName") or "",
		}, gui)
		local _, setText = bubble(gui, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -24))
		local function refresh()
			setText(model:GetAttribute("Bubble"), model:GetAttribute("BubbleMood"))
		end
		model:GetAttributeChangedSignal("Bubble"):Connect(refresh)
		model:GetAttributeChangedSignal("BubbleMood"):Connect(refresh)
		refresh()
	end)
end

local function removeCustomer(model)
	local gui = customerGuis[model]
	customerGuis[model] = nil
	if gui then
		gui:Destroy()
	end
end

CollectionService:GetInstanceAddedSignal("Customer"):Connect(addCustomer)
CollectionService:GetInstanceRemovedSignal("Customer"):Connect(removeCustomer)
for _, model in CollectionService:GetTagged("Customer") do
	addCustomer(model)
end

-- ================= OFFERS =================
local spotGuis = {}

local function addSpot(spot)
	if spotGuis[spot] then
		return
	end
	local gui = new("BillboardGui", {
		Name = "OfferTag",
		Adornee = spot,
		Size = UDim2.fromOffset(200, 40),
		-- Low, just over the item, so it stays clear of the customer's name tag.
		StudsOffsetWorldSpace = Vector3.new(0, 0.5, 0),
		MaxDistance = BUBBLE_DISTANCE,
		LightInfluence = 0,
		ResetOnSpawn = false,
	}, playerGui)
	spotGuis[spot] = gui
	local _, setText = bubble(gui, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5))
	local function refresh()
		setText(spot:GetAttribute("OfferText"), "want")
	end
	spot:GetAttributeChangedSignal("OfferText"):Connect(refresh)
	refresh()
end

CollectionService:GetInstanceAddedSignal("CounterSpot"):Connect(addSpot)
CollectionService:GetInstanceRemovedSignal("CounterSpot"):Connect(function(spot)
	local gui = spotGuis[spot]
	spotGuis[spot] = nil
	if gui then
		gui:Destroy()
	end
end)
for _, spot in CollectionService:GetTagged("CounterSpot") do
	addSpot(spot)
end

-- ================= SALES =================
-- "+$X" rising and fading over the counter.
ReplicatedStorage:WaitForChild("SaleEffect").OnClientEvent:Connect(function(position, amount)
	if typeof(position) ~= "Vector3" or typeof(amount) ~= "number" then
		return
	end
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain
	local gui = new("BillboardGui", {
		Adornee = anchor,
		Size = UDim2.fromOffset(160, 40),
		MaxDistance = 60,
		LightInfluence = 0,
	}, playerGui)
	local label = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 26,
		TextColor3 = MOODS.happy,
		TextStrokeColor3 = PANEL,
		TextStrokeTransparency = 0.3,
		Text = `+${amount}`,
	}, gui)
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0) }):Play()
	TweenService:Create(
		label,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.8),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()
	task.delay(1.7, function()
		gui:Destroy()
		anchor:Destroy()
	end)
end)
