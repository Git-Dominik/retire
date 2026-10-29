-- WallLightHood: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material + Color3 (no textures), anchors it, makes it
-- non-colliding dressing, and adds the fixture's light inside the bulb.
local map = {
	["WallLightHood_Plate"] = { Enum.Material.Metal, Color3.fromHex("#2E2724") },
	["WallLightHood_Arm"] = { Enum.Material.Metal, Color3.fromHex("#2E2724") },
	["WallLightHood_Shade"] = { Enum.Material.Metal, Color3.fromHex("#8C6E50") },
	["WallLightHood_Bulb"] = { Enum.Material.Neon, Color3.fromHex("#FFD58A") },
}
for _, root in game:GetService("Selection"):Get() do
	local parts = root:GetDescendants()
	table.insert(parts, root)
	for _, p in parts do
		local m = p:IsA("MeshPart") and map[p.Name]
		if m then
			p.Material, p.Color = m[1], m[2]
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
			p.CastShadow = m[1] ~= Enum.Material.Neon
			p.CollisionFidelity = Enum.CollisionFidelity.Box
			if p.Name == "WallLightHood_Bulb" and not p:FindFirstChildWhichIsA("Light") then
				local l = Instance.new("SpotLight")
	l.Face, l.Angle = Enum.NormalId.Bottom, 70
	l.Range, l.Brightness, l.Shadows = 14, 1.6, true
				if l.Color == Color3.new(1, 1, 1) then l.Color = Color3.fromHex("#FFD58A") end
				l.Parent = p
			end
		end
	end
	if root:IsA("Model") then
		root:SetAttribute("Biome", "Manor")
		root:SetAttribute("Interactable", false)
		root:SetAttribute("LightSource", true)
	end
end
