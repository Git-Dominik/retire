-- HeatExchanger: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material and its region's Color, anchors it as
-- non-colliding dressing and adds the fixture's light.
local map = {
	["HeatExchanger_Shell"] = { Enum.Material.Metal, Color3.fromHex("#A8A49A") },
	["HeatExchanger_Flanges"] = { Enum.Material.Metal, Color3.fromHex("#7E7A72") },
	["HeatExchanger_Bolts"] = { Enum.Material.Metal, Color3.fromHex("#3E3A36") },
	["HeatExchanger_Pads"] = { Enum.Material.DiamondPlate, Color3.fromHex("#B8862E") },
	["HeatExchanger_Saddles"] = { Enum.Material.Metal, Color3.fromHex("#8A867C") },
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
		root:SetAttribute("Biome", "Mines")
		root:SetAttribute("Interactable", false)
	end
end

-- Collision helpers (guide 9.2): invisible anchored boxes; the meshes above don't collide.
-- Offsets are from the bottom centre; the model is symmetric front to back.
local helpers = {
	{ "COL_Body", Vector3.new(15.000, 4.300, 4.300), Vector3.new(-0.080, 3.300, 0.000) },
	{ "COL_Saddle1", Vector3.new(1.500, 1.150, 3.900), Vector3.new(-3.780, 0.575, 0.000) },
	{ "COL_Saddle2", Vector3.new(1.500, 1.150, 3.900), Vector3.new(1.820, 0.575, 0.000) },
	{ "COL_NozzleTop", Vector3.new(1.600, 1.010, 1.600), Vector3.new(5.620, 5.955, 0.000) },
}
for _, root in game:GetService("Selection"):Get() do
	if root:IsA("Model") and root:FindFirstChild("HeatExchanger_Shell", true) then
		local cf, size = root:GetBoundingBox()
		local base = cf * CFrame.new(0, -size.Y / 2, 0)
		root.WorldPivot = base
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide = true, false
			end
		end
		for _, h in helpers do
			local old = root:FindFirstChild(h[1])
			if old then
				old:Destroy()
			end
			local p = Instance.new("Part")
			p.Name, p.Size = h[1], h[2]
			p.CFrame = base * CFrame.new(h[3])
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, true, false, false
			p.Transparency, p.CastShadow = 1, false
			p.Parent = root
		end
	end
end
