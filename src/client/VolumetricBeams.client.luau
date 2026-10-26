-- Fades light-shaft beams (tagged "VolumetricBeam") as the camera nears them.
-- Up close a beam reads as a flat sheet with hard edges, which breaks the
-- illusion of a volume of light, so it dissolves before you can walk into it.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "VolumetricBeam"
-- Fully faded at this distance from the shaft's centre line, in studs.
local FADE_NEAR = 2
-- Back to full strength at this distance.
local FADE_FAR = 9

local camera = workspace.CurrentCamera
-- beam -> { original transparency keypoints, last applied fade }
local beams = {}

local function track(beam)
	if not beam:IsA("Beam") then
		return
	end
	local keypoints = {}
	for _, k in beam.Transparency.Keypoints do
		table.insert(keypoints, { k.Time, k.Value })
	end
	beams[beam] = { keypoints = keypoints, fade = 1 }
end

local function untrack(beam)
	beams[beam] = nil
end

for _, beam in CollectionService:GetTagged(TAG) do
	track(beam)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)

-- Distance from point p to the segment a-b.
local function distanceToSegment(p, a, b)
	local ab = b - a
	local lengthSq = ab:Dot(ab)
	if lengthSq < 1e-6 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / lengthSq, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

RunService.RenderStepped:Connect(function()
	local eye = camera.CFrame.Position
	for beam, state in beams do
		local a0, a1 = beam.Attachment0, beam.Attachment1
		if a0 and a1 and beam.Enabled then
			local d = distanceToSegment(eye, a0.WorldPosition, a1.WorldPosition)
			local fade = math.clamp((d - FADE_NEAR) / (FADE_FAR - FADE_NEAR), 0, 1)
			-- Skip tiny changes so far-away beams don't rebuild sequences every frame.
			if math.abs(fade - state.fade) > 0.01 or (fade ~= state.fade and (fade == 0 or fade == 1)) then
				state.fade = fade
				local keypoints = {}
				for _, k in state.keypoints do
					table.insert(keypoints, NumberSequenceKeypoint.new(k[1], 1 - (1 - k[2]) * fade))
				end
				beam.Transparency = NumberSequence.new(keypoints)
			end
		end
	end
end)
