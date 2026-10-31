-- Whiteboard: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material and its region's Color, anchors it as
-- non-colliding dressing and adds the fixture's light.
local map = {
	["Whiteboard_Stand"] = { Enum.Material.Metal, Color3.fromHex("#3A3C40") },
	["Whiteboard_Wheels"] = { Enum.Material.Plastic, Color3.fromHex("#1F2022") },
	["Whiteboard_Hubs"] = { Enum.Material.Metal, Color3.fromHex("#2C2E31") },
	["Whiteboard_Knobs"] = { Enum.Material.Metal, Color3.fromHex("#B9B9B3") },
	["Whiteboard_Board"] = { Enum.Material.SmoothPlastic, Color3.fromHex("#E2E3DF") },
	["Whiteboard_Frame"] = { Enum.Material.Metal, Color3.fromHex("#4A4D52") },
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
	{ "COL_StandL", Vector3.new(0.300, 5.380, 2.200), Vector3.new(-3.950, 2.690, 0.000) },
	{ "COL_StandR", Vector3.new(0.300, 5.380, 2.200), Vector3.new(3.950, 2.690, 0.000) },
	{ "COL_Board", Vector3.new(7.440, 4.400, 0.900), Vector3.new(0.000, 4.000, 0.000) },
}
for _, root in game:GetService("Selection"):Get() do
	if root:IsA("Model") and root:FindFirstChild("Whiteboard_Board", true) then
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
