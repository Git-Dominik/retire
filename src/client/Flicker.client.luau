-- Makes any light tagged "Flicker" stutter now and then, like a failing bulb.
-- Runs on each client so it costs no network traffic; the timing doesn't need
-- to match between players. A Neon bulb the light sits in dims along with it.

local CollectionService = game:GetService("CollectionService")

local TAG = "Flicker"

local function flicker(light)
	local brightness = light.Brightness
	local bulb = light.Parent
	local bulbMaterial = bulb and bulb:IsA("BasePart") and bulb.Material
	while light.Parent and CollectionService:HasTag(light, TAG) do
		-- Long steady stretches, then a short burst of stutters.
		task.wait(math.random() * 6 + 2)
		for _ = 1, math.random(2, 6) do
			if not light.Parent then
				return
			end
			light.Brightness = brightness * (math.random() * 0.25)
			if bulbMaterial == Enum.Material.Neon then
				bulb.Material = Enum.Material.SmoothPlastic
			end
			task.wait(math.random() * 0.1 + 0.03)
			light.Brightness = brightness
			if bulbMaterial == Enum.Material.Neon then
				bulb.Material = Enum.Material.Neon
			end
			task.wait(math.random() * 0.15 + 0.04)
		end
	end
end

local function track(instance)
	if instance:IsA("Light") then
		task.spawn(flicker, instance)
	end
end

for _, light in CollectionService:GetTagged(TAG) do
	track(light)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
