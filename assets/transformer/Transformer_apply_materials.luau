-- Transformer: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material and its region's Color, anchors it as
-- non-colliding dressing and adds the fixture's light.
local map = {
	["Transformer_Skids"] = { Enum.Material.Metal, Color3.fromHex("#3E423F") },
	["Transformer_Tank"] = { Enum.Material.Metal, Color3.fromHex("#7E847F") },
	["Transformer_Fins"] = { Enum.Material.Metal, Color3.fromHex("#959B95") },
	["Transformer_Cover"] = { Enum.Material.Metal, Color3.fromHex("#676C68") },
	["Transformer_Bolts"] = { Enum.Material.Metal, Color3.fromHex("#3A3D3B") },
	["Transformer_Hardware"] = { Enum.Material.Metal, Color3.fromHex("#B8B5AA") },
	["Transformer_Porcelain"] = { Enum.Material.SmoothPlastic, Color3.fromHex("#6E3A2C") },
	["Transformer_Breather"] = { Enum.Material.Plastic, Color3.fromHex("#D6D0C0") },
	["Transformer_CageFrame"] = { Enum.Material.Metal, Color3.fromHex("#55595C") },
	["Transformer_CageMesh"] = { Enum.Material.Metal, Color3.fromHex("#8A8E90") },
	["Transformer_GateFrame"] = { Enum.Material.Metal, Color3.fromHex("#55595C") },
	["Transformer_GateMesh"] = { Enum.Material.Metal, Color3.fromHex("#8A8E90") },
	["Transformer_GateGrip"] = { Enum.Material.Metal, Color3.fromHex("#C8A23A") },
	["Transformer_SignPlate"] = { Enum.Material.SmoothPlastic, Color3.fromHex("#E3DCC8") },
	["Transformer_SignBlack"] = { Enum.Material.SmoothPlastic, Color3.fromHex("#1E1E1E") },
	["Transformer_SignYellow"] = { Enum.Material.SmoothPlastic, Color3.fromHex("#E8A21E") },
	["Transformer_SignBand"] = { Enum.Material.SmoothPlastic, Color3.fromHex("#8E2A26") },
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
-- Offsets are from the model's bottom centre, front -Z.
local helpers = {
	{ "COL_Tank", Vector3.new(4.400, 4.080, 3.600), Vector3.new(0.000, 2.040, 0.000) },
	{ "COL_CageFront", Vector3.new(3.120, 6.600, 0.240), Vector3.new(-1.440, 3.300, -2.600) },
	{ "COL_CageBack", Vector3.new(6.000, 6.600, 0.240), Vector3.new(0.000, 3.300, 2.600) },
	{ "COL_CageLeft", Vector3.new(0.240, 6.600, 5.200), Vector3.new(-3.000, 3.300, 0.000) },
	{ "COL_CageRight", Vector3.new(0.240, 6.600, 5.200), Vector3.new(3.000, 3.300, 0.000) },
}
for _, root in game:GetService("Selection"):Get() do
	if root:IsA("Model") and root:FindFirstChild("Transformer_Tank", true) then
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
		-- Maintenance gate: a SwingDoor (SwingDoors.client) whose one leaf is the gate's meshes,
		-- pivoted on the corner post's hinge line; the door's pivot is the opening's centre.
		if not root:FindFirstChild("MaintenanceGate") then
			local door = Instance.new("Model")
			door.Name = "MaintenanceGate"
			door.Parent = root
			local leaf = Instance.new("Model")
			leaf.Name = "Leaf"
			leaf.Parent = door
			for _, name in { "Transformer_GateFrame", "Transformer_GateMesh", "Transformer_GateGrip" } do
				local p = root:FindFirstChild(name, true)
				if p then
					p.Parent = leaf
				end
			end
			leaf.WorldPivot = base * CFrame.new(3.000, 3.200, -2.600)
			door.WorldPivot = base * CFrame.new(1.500, 3.200, -2.600)
			door:SetAttribute("OpenAngle", 100)
			game:GetService("CollectionService"):AddTag(door, "SwingDoor")
		end
	end
end
