-- Paste into Studio's command bar with the imported Forklift model selected.
-- Sets each MeshPart's Roblox Material; Color goes white so the FBX vertex colours show true.
-- Forklift is static factory dressing: anchored, box collision.
local MATERIALS = {
	Forklift_Paint = Enum.Material.Metal,
	Forklift_Frame = Enum.Material.DiamondPlate,
	Forklift_Tyres = Enum.Material.Rubber,
	Forklift_Seat = Enum.Material.Leather,
}

local model = game:GetService("Selection"):Get()[1]
assert(model, "Select the imported Forklift model first")

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local recording = ChangeHistoryService:TryBeginRecording("Apply forklift materials")

local done = 0
for _, part in model:GetDescendants() do
	if part:IsA("MeshPart") then
		for name, material in MATERIALS do
			if string.find(part.Name, name, 1, true) then
				part.Material = material
				part.Color = Color3.new(1, 1, 1)
				part.Anchored = true
				part.CanTouch = false
				part.CastShadow = true
				part.CollisionFidelity = Enum.CollisionFidelity.Box
				done += 1
				break
			end
		end
	end
end
model:SetAttribute("Biome", "Mines")
model:SetAttribute("Interactable", false)

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print(`Forklift: set {done}/4 meshes`)
