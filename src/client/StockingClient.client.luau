-- Visuals for shop stocking (StockingService owns all the state). The box you
-- carry is a Tool, held up by the arm IK like any carried item (Arms.client).
-- Its flaps hang on welds that swing open and shut with CFrame tweens, and each
-- stocked item pops out of the box and flies to its slot. Everyone nearby sees
-- the flaps and flights, played from the box in the holder's hand.
--
-- Also decides, for this player only, which prompts show: Take box / Put back
-- on the rack boxes, and Stock on furniture while you carry a box with items
-- left and the furniture has a free slot.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("StockingConfig"))
local StockItems = require(Shared:WaitForChild("StockItems"))

local remote = ReplicatedStorage:WaitForChild("Stocking")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local held -- { box, tool } while you carry a box

-- ================= SOUND =================
local function playSound(sound)
	local s = Instance.new("Sound")
	s.SoundId = sound.id
	s.Volume = sound.volume
	s.PlaybackSpeed = sound.speed
	s.Parent = script
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

-- ================= FLAPS =================
local boxStates = setmetatable({}, { __mode = "k" }) -- [tool] = { flaps, open }

-- The flaps of a carried box, each with a CFrameValue for its rotation about the
-- hinge (identity is shut); tweening that value swings the flap.
local function stateOf(tool)
	local state = boxStates[tool]
	if state then
		return state
	end
	state = { flaps = {}, open = false }
	for _, weld in tool:GetDescendants() do
		if weld:IsA("Weld") and weld.Name == "FlapHinge" then
			local flap = {
				hinge = weld:GetAttribute("Hinge"),
				center = weld:GetAttribute("Center"),
				open = weld:GetAttribute("Open"),
				long = weld:GetAttribute("Long"),
				angle = Instance.new("CFrameValue"),
			}
			flap.angle.Changed:Connect(function(rotation)
				weld.C0 = flap.hinge * rotation * flap.center
			end)
			table.insert(state.flaps, flap)
		end
	end
	boxStates[tool] = state
	return state
end

local function tweenFlaps(tool, open, time)
	local state = stateOf(tool)
	for _, flap in state.flaps do
		if flap.tween then
			flap.tween:Cancel()
		end
		-- Long flaps lead when opening and follow when closing.
		local leads = flap.long == open
		local info = TweenInfo.new(
			time * 0.7,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out,
			0,
			false,
			leads and 0 or time * 0.3
		)
		flap.tween =
			TweenService:Create(flap.angle, info, { Value = open and flap.open or CFrame.identity })
		flap.tween:Play()
	end
	state.open = open
end

-- A rejected attempt: the box gives a quick side-to-side shake in your hand. It
-- turns the hand's grip weld locally (setting Tool.Grip on the client wouldn't
-- re-weld the box).
local function shake(tool)
	local character = tool.Parent
	local hand = character and character:FindFirstChild("RightHand")
	local grip = hand and hand:FindFirstChild("RightGrip")
	if not grip then
		return
	end
	local angle = math.rad(Config.REJECT_SHAKE_ANGLE)
	local step = Config.REJECT_SHAKE_TIME / 4
	local offset = Instance.new("CFrameValue")
	offset.Changed:Connect(function(rotation)
		if grip.Parent then
			grip.C1 = tool.Grip * rotation
		end
	end)
	task.spawn(function()
		for _, a in { angle, -angle, angle * 0.5, 0 } do
			local tween = TweenService:Create(
				offset,
				TweenInfo.new(step, Enum.EasingStyle.Sine),
				{ Value = CFrame.Angles(0, 0, a) }
			)
			tween:Play()
			tween.Completed:Wait()
		end
		offset:Destroy()
	end)
end

-- ================= ITEM FLIGHT =================
local function tweenValue(value, goal, time, style, direction)
	local tween =
		TweenService:Create(value, TweenInfo.new(time, style, direction), { Value = goal })
	tween:Play()
	tween.Completed:Wait()
end

-- The middle of the box's open top, turned so an item there faces this player.
local function boxTop(tool)
	local handle = tool and tool.Parent and tool:FindFirstChild("Handle")
	if not handle then
		return nil
	end
	local top = (handle.CFrame * CFrame.new(0, tool:GetAttribute("TopOffset") or 0, 0)).Position
	local toward = (camera.CFrame.Position - top) * Vector3.new(1, 0, 1)
	if toward.Magnitude < 0.05 then
		return CFrame.new(top)
	end
	return CFrame.lookAt(top, top + toward)
end

-- One item: up out of the box, across to a point a little in front of its slot,
-- then eased into place. Snaps exactly onto the slot at the end and stays until
-- the server's real copy of the item has arrived, so there's no gap.
local function flyItem(placement)
	local slot, tool = placement.slot, placement.tool
	if not slot or not slot.Parent then
		return
	end
	local lastOrigin = boxTop(tool)
	if not lastOrigin then
		return
	end

	local model = StockItems.create(placement.itemId, slot:GetAttribute("SlotSize"))
	if not model then
		return
	end
	model.Name = "StockFlight"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	local _, itemSize = model:GetBoundingBox()
	local final = StockItems.restingCFrame(placement.itemId, slot)

	-- 1. Rises out of the box, following it as the holder moves.
	local rise = Instance.new("NumberValue")
	local follow = RunService.RenderStepped:Connect(function()
		lastOrigin = boxTop(tool) or lastOrigin
		local y = -itemSize.Y + (itemSize.Y + Config.ITEM_POP_HEIGHT) * rise.Value
		model:PivotTo(lastOrigin * CFrame.new(0, y, 0))
	end)
	model.Parent = workspace
	tweenValue(rise, 1, Config.ITEM_POP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	follow:Disconnect()

	-- 2. Leaves the box for a point a couple of studs out from the slot, toward the holder.
	local toward = (lastOrigin.Position - final.Position) * Vector3.new(1, 0, 1)
	local distance = toward.Magnitude
	local direction = distance > 0.05 and toward.Unit or final.LookVector
	local out = math.min(Config.ITEM_FLIGHT_START_DISTANCE, math.max(distance - 1, 0.5))
	local start = final.Position
		+ direction * out
		+ Vector3.new(0, Config.ITEM_FLIGHT_START_RISE, 0)
	local path = Instance.new("CFrameValue")
	path.Value = model:GetPivot()
	path.Changed:Connect(function(cf)
		model:PivotTo(cf)
	end)
	tweenValue(
		path,
		CFrame.new(start) * path.Value.Rotation:Lerp(final.Rotation, 0.5),
		Config.ITEM_APPROACH_TIME,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)

	-- 3. Eases into its final position and rotation, then snaps exactly onto the slot.
	tweenValue(
		path,
		final,
		Config.ITEM_FLIGHT_TIME,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	model:PivotTo(final)

	local deadline = os.clock() + 2
	while os.clock() < deadline and not slot:FindFirstChild("StockedItem") do
		task.wait()
	end
	model:Destroy()
end

local function onPlace(placement)
	local tool = placement.tool
	if tool and placement.playOpen then
		tweenFlaps(tool, true, Config.BOX_OPEN_TIME)
		if placement.holder == player then
			playSound(Config.SOUNDS.flapOpen)
		end
	end
	task.delay(placement.delay, flyItem, placement)
end

-- ================= PROMPTS =================
local furniturePrompts = {}

local function stockPromptOf(furniture)
	local prompt = furniturePrompts[furniture]
	if not prompt or not prompt.Parent then
		prompt = furniture:FindFirstChild("StockPrompt", true)
		furniturePrompts[furniture] = prompt
	end
	return prompt
end

local function refreshPrompts()
	local box = held and held.box
	local count = box and box:GetAttribute("Count") or 0
	local name
	if box then
		local item = StockItems.get(box:GetAttribute("ItemId"))
		name = item and item.name or "Stock"
	end

	for _, rackBox in CollectionService:GetTagged("StockBox") do
		local prompt = rackBox:FindFirstChild("StockBoxPrompt")
		if prompt then
			local heldBy = rackBox:GetAttribute("HeldBy") or 0
			if heldBy == player.UserId and rackBox == box then
				prompt.ActionText = "Put back"
				prompt.Enabled = true
			else
				prompt.ActionText = "Take box"
				prompt.Enabled = heldBy == 0
					and not box
					and (rackBox:GetAttribute("Count") or 0) > 0
			end
		end
	end

	for _, furniture in CollectionService:GetTagged("StockFurniture") do
		local prompt = stockPromptOf(furniture)
		if prompt then
			prompt.Enabled = box ~= nil
				and count > 0
				and (furniture:GetAttribute("FreeSlots") or 0) > 0
			if box then
				prompt.ObjectText = `{name} ×{count}`
			end
		end
	end
end

-- Refreshes at most once a frame, whenever anything it depends on changes.
local dirty = true
local function markDirty()
	dirty = true
end
RunService.Heartbeat:Connect(function()
	if dirty then
		dirty = false
		refreshPrompts()
	end
end)

local function watch(instance)
	instance.AttributeChanged:Connect(markDirty)
	instance.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			markDirty()
		end
	end)
	markDirty()
end
for _, tag in { "StockBox", "StockFurniture" } do
	for _, instance in CollectionService:GetTagged(tag) do
		watch(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
end

-- ================= EVENTS =================
remote.OnClientEvent:Connect(function(action, ...)
	if action == "Hold" then
		local box, tool = ...
		held = { box = box, tool = tool }
	elseif action == "Place" then
		onPlace(...)
	elseif action == "Close" then
		local tool = ...
		if tool and stateOf(tool).open then
			tweenFlaps(tool, false, Config.BOX_CLOSE_TIME)
			if held and held.tool == tool then
				playSound(Config.SOUNDS.flapClose)
			end
		end
	elseif action == "Release" then
		local box = ...
		if held and held.box == box then
			held = nil
		end
	elseif action == "Reject" then
		if held and held.tool.Parent then
			shake(held.tool)
		end
		playSound(Config.SOUNDS.reject)
	end
	markDirty()
end)

-- Your put-down key, or pulling out the journal, puts the box back.
local function putDown()
	if held then
		remote:FireServer("PutDown")
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Config.PUT_DOWN_KEY then
		putDown()
	end
end)

player:GetAttributeChangedSignal("ReadingJournal"):Connect(function()
	if player:GetAttribute("ReadingJournal") then
		putDown()
	end
end)

player.CharacterRemoving:Connect(function()
	held = nil
	markDirty()
end)
