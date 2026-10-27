-- The cargo lift built into the elevator's back wall. Players load scavenged items onto
-- its car and press the send button; the car carries them up to the storage racks in
-- the store (StockRacks), where they can be taken off and stocked in the shop.
-- Only MAX_TRIPS trips are allowed per run.
--
-- This script owns the rules and the items. Everything that moves or makes a sound is
-- animated by CargoLift.client from the attributes set here, so it runs at the
-- player's frame rate instead of the network's:
--   CargoLift.CargoValue      total value aboard (drum counter)
--   CargoLift.SendSeq/SendAt  bumped when a trip starts, with the server time it started
--   Elevator.CargoTripsLeft   trips remaining (lamps, gate)
-- plus the timing attributes below, so both sides agree on the schedule.
--
-- Delivered items pay their Value into the Player "Money" attribute of whoever loaded
-- them (the item's Owner). It lives for the session only; Journal.client shows it.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local StockRacks = require(script.Parent:WaitForChild("StockRacks"))

local MAX_TRIPS = 3
local TIMING = {
	PressLead = 0.12, -- button press to gate starting down
	GateTime = 0.45,
	RideTime = 20, -- the long haul up; the car is out of sight after the first few seconds
	TopPause = 1,
	ReturnTime = 2.6,
	Rise = 10, -- studs the car climbs before it's out of sight
}

local elevator = workspace:WaitForChild("Elevator")
local lift = elevator:WaitForChild("CargoLift")
local car = lift.Car
local button = lift.SendButton
local slots = car.Slots:GetChildren()
table.sort(slots, function(a, b)
	return a.Name < b.Name
end)

for name, value in TIMING do
	lift:SetAttribute(name, value)
end

local tripsLeft = MAX_TRIPS
local busy = false
local loaded = {}

elevator:SetAttribute("CargoTripsLeft", tripsLeft)
lift:SetAttribute("CargoValue", 0)
lift:SetAttribute("SendSeq", 0)

local function updateValue()
	local value = 0
	for _, item in loaded do
		value += item:GetAttribute("Value") or 0
	end
	lift:SetAttribute("CargoValue", value)
end

-- ================= PROMPTS =================
local function makePrompt(parent, action, object)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end
local loadPrompt = makePrompt(lift.LoadPoint, "Load item", "Cargo Lift")
local sendPrompt = makePrompt(button.Bezel, "Send up", "Cargo Lift")

local function refreshPrompts()
	local open = not busy and tripsLeft > 0
	loadPrompt.Enabled = open and #loaded < #slots
	sendPrompt.Enabled = open and #loaded > 0
end
refreshPrompts()

-- The equipped scavenged item first, else the first one in the backpack.
local function findItem(player)
	for _, container in { player.Character, player:FindFirstChild("Backpack") } do
		for _, tool in container and container:GetChildren() or {} do
			if tool:IsA("Tool") and tool:GetAttribute("ScavengedLevel") then
				return tool
			end
		end
	end
	return nil
end

-- Floor items carry a RestOffset from their bottom centre (see Levels).
local function restOn(p, surface)
	local offset = p:GetAttribute("RestOffset")
	if offset then
		p.CFrame = surface * offset
	elseif p.Shape == Enum.PartType.Cylinder then
		p.CFrame = surface * CFrame.new(0, p.Size.X / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	else
		p.CFrame = surface * CFrame.new(0, p.Size.Y / 2, 0)
	end
end

loadPrompt.Triggered:Connect(function(player)
	if busy or tripsLeft == 0 or #loaded >= #slots then
		return
	end
	local tool = findItem(player)
	local handle = tool and tool:FindFirstChild("Handle")
	if not handle then
		return
	end
	-- The handle is a clone of the room item, so it carries its Value.
	local item = handle:Clone()
	item.Name = tool.Name
	item.Anchored = true
	item.CanCollide = false
	item:SetAttribute("ScavengedLevel", tool:GetAttribute("ScavengedLevel"))
	item:SetAttribute("Owner", player.UserId)
	restOn(item, slots[#loaded + 1].CFrame * CFrame.Angles(0, math.rad(math.random(-25, 25)), 0))
	item.Parent = car
	table.insert(loaded, item)
	-- Tells the elevator not to put the original back in the room.
	tool:SetAttribute("Stored", true)
	tool:Destroy()
	updateValue()
	refreshPrompts()
end)

-- ================= DELIVERY =================
-- Items land on the storage racks in the store (StockRacks). With every rack full
-- they're kept in ServerStorage so nothing is lost.
local function deliver(item)
	if StockRacks.place(item) then
		return
	end
	local folder = ServerStorage:FindFirstChild("DeliveredCargo") or Instance.new("Folder")
	folder.Name = "DeliveredCargo"
	folder.Parent = ServerStorage
	item.Parent = folder
end

local function send()
	if busy or tripsLeft == 0 or #loaded == 0 then
		return
	end
	busy = true
	refreshPrompts()
	lift:SetAttribute("SendAt", workspace:GetServerTimeNow())
	lift:SetAttribute("SendSeq", lift:GetAttribute("SendSeq") + 1)

	-- The car is out of sight at the top once the ride ends; the cargo is handed over then.
	task.wait(TIMING.PressLead + TIMING.GateTime + TIMING.RideTime)
	local cargo = table.clone(loaded)
	table.clear(loaded)
	for _, item in cargo do
		local owner = Players:GetPlayerByUserId(item:GetAttribute("Owner") or 0)
		if owner then
			owner:SetAttribute(
				"Money",
				(owner:GetAttribute("Money") or 0) + (item:GetAttribute("Value") or 0)
			)
		end
		deliver(item)
	end
	updateValue()
	tripsLeft -= 1
	elevator:SetAttribute("CargoTripsLeft", tripsLeft)

	task.wait(TIMING.TopPause + TIMING.ReturnTime + TIMING.GateTime)
	busy = false
	refreshPrompts()
end

sendPrompt.Triggered:Connect(send)
