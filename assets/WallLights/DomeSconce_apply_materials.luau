-- DomeSconce: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material and a white Color (the FBX vertex colours show
-- through), anchors it as non-colliding dressing and adds the fixture's light.
local map = {
	["DomeSconce_Brim"] = { Enum.Material.Metal, Color3.new(1, 1, 1) },
	["DomeSconce_Bulb"] = { Enum.Material.Neon, Color3.new(1, 1, 1) },
	["DomeSconce_Iron"] = { Enum.Material.Metal, Color3.new(1, 1, 1) },
	["DomeSconce_Shade"] = { Enum.Material.Metal, Color3.new(1, 1, 1) },
	["DomeSconce_Wood"] = { Enum.Material.Wood, Color3.new(1, 1, 1) },
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
			if p.Name == "DomeSconce_Bulb" and not p:FindFirstChildWhichIsA("Light") then
				local l = Instance.new("PointLight")
				l.Range, l.Brightness, l.Shadows = 14, 1.5, false
				l.Color = Color3.fromHex("#FFD58A")
				l.Parent = p
			end
		end
	end
	if root:IsA("Model") then
		root:SetAttribute("Biome", "Manor")
		root:SetAttribute("LightSource", true)
	end
end
