-- FloorGrate: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material and its region's Color, anchors it as
-- non-colliding dressing and adds the fixture's light.
local map = {
	["FloorGrate_Frame"] = { Enum.Material.DiamondPlate, Color3.fromHex("#4A4744") },
	["FloorGrate_Liner"] = { Enum.Material.Metal, Color3.fromHex("#2C2926") },
	["FloorGrate_PitFloor"] = { Enum.Material.DiamondPlate, Color3.fromHex("#363431") },
	["FloorGrate_Grate"] = { Enum.Material.DiamondPlate, Color3.fromHex("#3E3430") },
	["FloorGrate_PipeCream"] = { Enum.Material.DiamondPlate, Color3.fromHex("#A89E8A") },
	["FloorGrate_Fittings"] = { Enum.Material.Metal, Color3.fromHex("#8A847A") },
	["FloorGrate_PipeBlue"] = { Enum.Material.DiamondPlate, Color3.fromHex("#525C7A") },
	["FloorGrate_PipeDark"] = { Enum.Material.Metal, Color3.fromHex("#3E3A36") },
	["FloorGrate_PipeRed"] = { Enum.Material.DiamondPlate, Color3.fromHex("#7A3C3A") },
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

-- Collision helper (guide 9.2): one invisible deck box over the grate and frame; the
-- meshes above don't collide.
for _, root in game:GetService("Selection"):Get() do
	if root:IsA("Model") and root:FindFirstChild("FloorGrate_Grate", true) then
		local cf, size = root:GetBoundingBox()
		root.WorldPivot = cf * CFrame.new(0, -size.Y / 2, 0)
		local old = root:FindFirstChild("COL_Deck")
		if old then
			old:Destroy()
		end
		local p = Instance.new("Part")
		p.Name, p.Size = "COL_Deck", Vector3.new(11.5, 0.3, 11.5)
		p.CFrame = root.WorldPivot * CFrame.new(0, 2.85, 0)
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, true, false, false
		p.Transparency, p.CastShadow = 1, false
		p.Parent = root
	end
end
