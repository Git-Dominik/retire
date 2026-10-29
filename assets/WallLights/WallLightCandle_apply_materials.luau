-- WallLightCandle: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material + Color3 (no textures), anchors it, makes it
-- non-colliding dressing, and adds the fixture's light inside the bulb.
local map = {
	["WallLightCandle_Plate"] = { Enum.Material.Wood, Color3.fromHex("#4A3024") },
	["WallLightCandle_Bar"] = { Enum.Material.Metal, Color3.fromHex("#2E2724") },
	["WallLightCandle_Sleeve"] = { Enum.Material.SmoothPlastic, Color3.fromHex("#E3C9A0") },
	["WallLightCandle_Bulb"] = { Enum.Material.Neon, Color3.fromHex("#FFD58A") },
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
			if p.Name == "WallLightCandle_Bulb" and not p:FindFirstChildWhichIsA("Light") then
				local l = Instance.new("PointLight")
	l.Range, l.Brightness, l.Shadows = 14, 1.2, false
	l.Color = Color3.fromHex("#FFC77A")
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
