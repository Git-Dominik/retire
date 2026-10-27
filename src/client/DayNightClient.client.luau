-- The client half of the day/night cycle (DayNightService owns the clock). Every frame
-- it sets Lighting.ClockTime from the workspace clock anchor (ClockAnchorTime,
-- ClockAnchorHour, DayLength, ClockPaused), so the sun moves smoothly between the
-- server's writes.
-- On a Phase change it tweens the outdoor lighting between the day look (the place's own
-- saved Lighting, read when this script starts) and ShopConfig.NIGHT_LIGHTING /
-- NIGHT_ATMOSPHERE. Joining mid-session snaps straight to the current phase's look.
-- Interior lights and the shop models are never touched.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")

-- The day look, as saved in the place, for every property the night look changes.
local function capture(instance, night)
	local look = {}
	for property in night do
		look[property] = instance[property]
	end
	return look
end
local DAY_LIGHTING = capture(Lighting, Config.NIGHT_LIGHTING)
local DAY_ATMOSPHERE = atmosphere and capture(atmosphere, Config.NIGHT_ATMOSPHERE)

local tweens = {}
local function applyPhase(phase, instant)
	for _, tween in tweens do
		tween:Cancel()
	end
	table.clear(tweens)
	local night = phase == "Night"
	local targets = {
		{ Lighting, night and Config.NIGHT_LIGHTING or DAY_LIGHTING },
		{ atmosphere, night and Config.NIGHT_ATMOSPHERE or DAY_ATMOSPHERE },
	}
	for _, entry in targets do
		local instance, goal = entry[1], entry[2]
		if instance and goal then
			if instant then
				for property, value in goal do
					instance[property] = value
				end
			else
				local info = TweenInfo.new(
					Config.LIGHT_TWEEN_TIME,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut
				)
				local tween = TweenService:Create(instance, info, goal)
				tween:Play()
				table.insert(tweens, tween)
			end
		end
	end
end

-- The server sets these before any client script runs, but don't count on it.
while workspace:GetAttribute("ClockAnchorTime") == nil do
	workspace.AttributeChanged:Wait()
end

applyPhase(workspace:GetAttribute("Phase"), true)
workspace:GetAttributeChangedSignal("Phase"):Connect(function()
	applyPhase(workspace:GetAttribute("Phase"), false)
end)

RunService.RenderStepped:Connect(function()
	local anchorTime = workspace:GetAttribute("ClockAnchorTime")
	local anchorHour = workspace:GetAttribute("ClockAnchorHour")
	local length = workspace:GetAttribute("DayLength")
	if workspace:GetAttribute("ClockPaused") then
		Lighting.ClockTime = anchorHour or Lighting.ClockTime
	elseif anchorTime and anchorHour and length then
		local elapsed = workspace:GetServerTimeNow() - anchorTime
		Lighting.ClockTime = (anchorHour + elapsed * 24 / length) % 24
	end
end)
