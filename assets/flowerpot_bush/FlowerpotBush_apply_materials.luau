-- FlowerpotBush: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material and its region's Color, anchors it as
-- non-colliding dressing and adds the fixture's light.
local map = {
	["FlowerpotBush_Body"] = { Enum.Material.Plastic, Color3.fromHex("#7A5038") },
	["FlowerpotBush_Canopy"] = { Enum.Material.LeafyGrass, Color3.fromHex("#3A4E2C") },
	["FlowerpotBush_CanopyUnder"] = { Enum.Material.LeafyGrass, Color3.fromHex("#26321E") },
	["FlowerpotBush_Foot"] = { Enum.Material.Plastic, Color3.fromHex("#4A3226") },
	["FlowerpotBush_Rim"] = { Enum.Material.Plastic, Color3.fromHex("#94664A") },
	["FlowerpotBush_Soil"] = { Enum.Material.Ground, Color3.fromHex("#3A2E26") },
	["FlowerpotBush_Trunk"] = { Enum.Material.Wood, Color3.fromHex("#4A3426") },
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
		root:SetAttribute("Biome", "Manor")
		root:SetAttribute("Interactable", false)
	end
end

-- Collision helper (guide 9.2): an invisible anchored box round the pot; the meshes don't collide.
for _, root in game:GetService("Selection"):Get() do
	if root:IsA("Model") then
		local cf, size = root:GetBoundingBox()
		local base = cf * CFrame.new(0, -size.Y / 2, 0)
		root.WorldPivot = base
		local old = root:FindFirstChild("COL_Pot")
		if old then
			old:Destroy()
		end
		local p = Instance.new("Part")
		p.Name, p.Size = "COL_Pot", Vector3.new(2.00, 1.95, 2.00)
		p.CFrame = base * CFrame.new(0, 0.975, 0)
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, true, false, false
		p.Transparency, p.CastShadow = 1, false
		p.Parent = root
	end
end
