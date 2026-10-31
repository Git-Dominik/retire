-- OfficeDesk: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material and its region's Color, anchors it as
-- non-colliding dressing and adds the fixture's light.
local map = {
	["OfficeDesk_Top"] = { Enum.Material.Wood, Color3.fromHex("#6E5B49") },
	["OfficeDesk_Grommets"] = { Enum.Material.Plastic, Color3.fromHex("#B5B3AD") },
	["OfficeDesk_Frame"] = { Enum.Material.Metal, Color3.fromHex("#8A8D90") },
	["OfficeDesk_Feet"] = { Enum.Material.Plastic, Color3.fromHex("#2A2B2D") },
	["OfficeDesk_Modesty"] = { Enum.Material.Wood, Color3.fromHex("#54463A") },
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

-- Collision helpers (guide 9.2): invisible anchored boxes; the meshes above don't collide.
-- Offsets are from the model's bottom centre, front -Z.
local helpers = {
	{ "COL_Top", Vector3.new(4.600, 0.250, 2.400), Vector3.new(0.000, 2.475, 0.000) },
	{ "COL_LegL", Vector3.new(0.220, 2.350, 2.150), Vector3.new(-2.050, 1.175, -0.025) },
	{ "COL_LegR", Vector3.new(0.220, 2.350, 2.150), Vector3.new(2.050, 1.175, -0.025) },
	{ "COL_Modesty", Vector3.new(3.880, 1.380, 0.100), Vector3.new(0.000, 1.540, 0.650) },
}
for _, root in game:GetService("Selection"):Get() do
	if root:IsA("Model") and root:FindFirstChild("OfficeDesk_Top", true) then
		for _, h in helpers do
			local old = root:FindFirstChild(h[1])
			if old then
				old:Destroy()
			end
		end
		local cf, size = root:GetBoundingBox()
		local base = cf * CFrame.new(0, -size.Y / 2, 0)
		root.WorldPivot = base
		for _, h in helpers do
			local p = Instance.new("Part")
			p.Name, p.Size = h[1], h[2]
			p.CFrame = base * CFrame.new(h[3])
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, true, false, false
			p.Transparency, p.CastShadow = 1, false
			p.Parent = root
		end
	end
end
