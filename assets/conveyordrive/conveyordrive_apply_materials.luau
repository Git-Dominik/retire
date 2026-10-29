-- Paste into Studio's command bar with the imported ConveyorDrive model selected.
-- Sets each MeshPart's Roblox Material; Color goes white so the FBX vertex colours show true.
-- ConveyorDrive is static factory dressing: anchored, box collision.
local MATERIALS = {
	ConveyorDrive_Accent = Enum.Material.SmoothPlastic,
	ConveyorDrive_Roller = Enum.Material.Metal,
	ConveyorDrive_Frame = Enum.Material.Metal,
	ConveyorDrive_Dark = Enum.Material.DiamondPlate,
}

local model = game:GetService("Selection"):Get()[1]
assert(model, "Select the imported ConveyorDrive model first")

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local recording = ChangeHistoryService:TryBeginRecording("Apply ConveyorDrive materials")

local done = 0
for _, part in model:GetDescendants() do
	if part:IsA("MeshPart") then
		for meshName, material in MATERIALS do
			if string.find(part.Name, meshName, 1, true) then
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
print(`ConveyorDrive: set {done}/4 meshes`)
