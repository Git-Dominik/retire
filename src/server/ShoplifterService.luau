-- Shoplifters: customers in a grey robber hat, the only thing that gives them away. They
-- walk in, go to a random piece of shop furniture that has stock, take SHOPLIFTER_ITEMS
-- items off it one after another (each into the hand, then out of sight in a pocket), and
-- walk straight back out. No bubble, no counter, nothing to stop them. With nothing on
-- the shelves they wander for a bit and leave.
--
-- Pocketed items are gone for good: their base prices go to QuotaService's
-- DayStolenValue as they're taken, and they're destroyed with the shoplifter. Leaving
-- (and despawning) is CustomerService's job; run() just returns when they're done.
--
-- The hat: with ShopConfig.HAT_ASSET_ID set, that accessory is loaded (InsertService).
-- Otherwise it's built here as a flat-topped octagonal crown on a small brim, each piece a
-- square with one flat chamfer per corner (core, two _Strip sides and four _Bevel wedges,
-- as hand-built boxes are in this game), in HAT_COLOR matte plastic. It's an Accessory on
-- the head's HatAttachment, so it replicates and stays on. Its parts can't be anchored:
-- they ride the head.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("ShopConfig"))
local StockItems = require(Shared:WaitForChild("StockItems"))
local CustomerUtil = require(script.Parent:WaitForChild("CustomerUtil"))
local QuotaService = require(script.Parent:WaitForChild("QuotaService"))

local ShoplifterService = {}

-- Sizes for the default R15 head (1.2 studs across); scaled to the actual head.
local HEAD_SIZE = 1.2
local HAT = {
	crownWidth = 1.3,
	crownHeight = 0.5,
	crownCut = 0.28,
	brimWidth = 1.52,
	brimHeight = 0.08,
	brimCut = 0.33,
	-- How far down the head the crown's bottom sits, below the head's top.
	sink = 0.3,
}

-- ================= HAT =================
local function hatPart(class, parent, name, size, cframe)
	local p = Instance.new(class)
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = Config.HAT_COLOR
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = parent
	return p
end

-- A square slab with each vertical corner cut by one flat 45 degree chamfer: a core, two
-- side strips and four corner wedges, none overlapping. Returns the core.
local function chamferedSlab(parent, name, width, height, cut, cframe)
	local core = hatPart("Part", parent, name, Vector3.new(width - cut * 2, height, width), cframe)
	core:SetAttribute("Bevelled", true)
	for _, side in { -1, 1 } do
		hatPart(
			"Part",
			parent,
			`{name}_Strip`,
			Vector3.new(cut, height, width - cut * 2),
			cframe * CFrame.new(side * (width - cut) / 2, 0, 0)
		)
	end
	-- A wedge stood on end (its length up the slab), its right angle toward the middle.
	local upright = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.xAxis, -Vector3.zAxis)
	local corner = (width - cut) / 2
	for turn = 0, 3 do
		hatPart(
			"WedgePart",
			parent,
			`{name}_Bevel`,
			Vector3.new(height, cut, cut),
			cframe
				* CFrame.Angles(0, turn * math.pi / 2, 0)
				* CFrame.new(corner, 0, corner)
				* upright
		)
	end
	return core
end

local function buildHat(scale)
	local accessory = Instance.new("Accessory")
	accessory.Name = "RobberHat"
	accessory.AccessoryType = Enum.AccessoryType.Hat

	local h = {}
	for key, value in HAT do
		h[key] = value * scale
	end
	local handle =
		chamferedSlab(accessory, "Handle", h.crownWidth, h.crownHeight, h.crownCut, CFrame.identity)
	local brimY = -h.crownHeight / 2 + h.brimHeight / 2 - 0.01 * scale
	chamferedSlab(accessory, "Brim", h.brimWidth, h.brimHeight, h.brimCut, CFrame.new(0, brimY, 0))
	for _, p in accessory:GetChildren() do
		if p:IsA("BasePart") and p ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = p
			weld.Parent = p
		end
	end

	-- The head's HatAttachment is on its top; the crown's bottom sits `sink` below that.
	local attachment = Instance.new("Attachment")
	attachment.Name = "HatAttachment"
	attachment.Position = Vector3.new(0, h.sink - h.crownHeight / 2, 0)
	attachment.Parent = handle
	return accessory
end

local function loadHatAsset()
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(Config.HAT_ASSET_ID)
	end)
	local accessory = ok and asset:FindFirstChildWhichIsA("Accessory", true)
	if not accessory then
		warn(`[Customers] Couldn't load hat asset {Config.HAT_ASSET_ID}; building one`)
		return nil
	end
	for _, d in accessory:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	accessory.Parent = nil
	return accessory
end

-- Puts the grey robber hat on a customer rig.
function ShoplifterService.addHat(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	if not humanoid or not head then
		return
	end
	local hat = Config.HAT_ASSET_ID ~= 0 and loadHatAsset()
	if not hat then
		hat = buildHat(math.clamp(head.Size.X / HEAD_SIZE, 0.8, 1.6))
	end
	humanoid:AddAccessory(hat)
	CustomerUtil.setGroup(hat, "Customers")
end

-- ================= BEHAVIOUR =================
function ShoplifterService.chance(day)
	return math.min(
		Config.SHOPLIFTER_CHANCE + Config.SHOPLIFTER_CHANCE_PER_DAY * (day - 1),
		Config.SHOPLIFTER_CHANCE_MAX
	)
end

local function stockedSlots(furniture)
	local slots = {}
	for _, slot in CustomerUtil.slotsOf(furniture) do
		if CustomerUtil.itemIn(slot) then
			table.insert(slots, slot)
		end
	end
	return slots
end

-- Takes one item: into the hand, then into a pocket (welded to the torso, out of sight).
local function pocket(customer, slot)
	local model = CustomerUtil.takeFromSlot(slot, customer.model)
	if not model then
		return
	end
	local itemId = model:GetAttribute("ItemId")
	local item = StockItems.get(itemId)
	QuotaService.recordStolen(item and item.basePrice or 0)
	table.insert(customer.pocket, model)
	CustomerUtil.setGroup(model, "Customers")

	local hand = customer.model:FindFirstChild("RightHand")
	if hand then
		CustomerUtil.tweenItem(model, hand.CFrame * CustomerUtil.handOffset(model))
	end
	local torso = customer.model:FindFirstChild("LowerTorso") or customer.root
	CustomerUtil.attach(model, torso, CFrame.new(0, -0.2, 0))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.Transparency = 1
		end
	end
end

-- The shoplifter's visit, from the door to having pocketed what they came for (or given
-- up). CustomerService walks them out afterwards.
function ShoplifterService.run(customer)
	customer.state = "Enter"
	CustomerUtil.walkTo(customer, CustomerUtil.entryPoint())

	customer.state = "Target"
	local targets = {}
	for _, furniture in CustomerUtil.shopFurniture() do
		if #stockedSlots(furniture) > 0 then
			table.insert(targets, furniture)
		end
	end
	if #targets == 0 then
		-- Nothing worth taking: drift past a shelf or two, then go.
		local all = CustomerUtil.shopFurniture()
		local until_ = os.clock() + Config.SHOPLIFTER_WANDER_TIME
		while os.clock() < until_ and #all > 0 do
			local furniture = all[math.random(1, #all)]
			local slot = CustomerUtil.slotsOf(furniture)[1]
			local stand = slot and CustomerUtil.standPoint(furniture, slot)
			if stand then
				CustomerUtil.walkTo(customer, stand, until_ - os.clock())
			else
				task.wait(1)
			end
		end
		return
	end

	local furniture = targets[math.random(1, #targets)]
	local slots = stockedSlots(furniture)
	local stand = CustomerUtil.standPoint(furniture, slots[1])
	if stand then
		CustomerUtil.walkTo(customer, stand)
	end

	customer.state = "Take"
	CustomerUtil.face(customer, furniture:GetBoundingBox().Position)
	local count = math.random(Config.SHOPLIFTER_ITEMS[1], Config.SHOPLIFTER_ITEMS[2])
	for i = 1, count do
		slots = stockedSlots(furniture)
		if #slots == 0 then
			break
		end
		if i > 1 then
			task.wait(Config.SHOPLIFTER_TAKE_PAUSE)
		end
		pocket(customer, slots[math.random(1, #slots)])
	end
end

return ShoplifterService
