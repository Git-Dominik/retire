-- WallSpeaker: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material and its region's Color, anchors it as
-- non-colliding dressing and adds the fixture's light.
local map = {
	["WallSpeaker_Body"] = { Enum.Material.Plastic, Color3.fromHex("#4B5059") },
	["WallSpeaker_Grille"] = { Enum.Material.Metal, Color3.fromHex("#34373C") },
	["WallSpeaker_GrilleBack"] = { Enum.Material.Plastic, Color3.fromHex("#1C1D20") },
	["WallSpeaker_Panel"] = { Enum.Material.Plastic, Color3.fromHex("#26282C") },
	["WallSpeaker_LedGreen"] = { Enum.Material.Neon, Color3.fromHex("#5CFF6E") },
	["WallSpeaker_LedAmber"] = { Enum.Material.Neon, Color3.fromHex("#FF9A50") },
}
for _, root in game:GetService("Selection"):Get() do
	local parts = root:GetDescendants()
	table.insert(parts, root)
	for _, p in parts do
		local m = p:IsA("MeshPart") and map[p.Name]
		if m then
			p.Material, p.Color = m[1], m[2]
			p.Anchored, p.CanCollide, p.CanTouch = true, false, false
			p.CastShadow = m[1] ~= Enum.Material.Neon
			p.CollisionFidelity = Enum.CollisionFidelity.Box
		end
	end
	if root:IsA("Model") then
		root:SetAttribute("Biome", "Office")
		root:SetAttribute("Interactable", false)
	end
end

for _, root in game:GetService("Selection"):Get() do
	if root:IsA("Model") and root:FindFirstChild("WallSpeaker_Body", true) then
		for name, hex in { WallSpeaker_LedGreen = "#5CFF6E", WallSpeaker_LedAmber = "#FF9A50" } do
			local led = root:FindFirstChild(name, true)
			if led and not led:FindFirstChildWhichIsA("Light") then
				local l = Instance.new("PointLight")
				l.Range, l.Brightness, l.Shadows = 1, 0.3, false
				l.Color = Color3.fromHex(hex)
				l.Parent = led
			end
		end
	end
end
