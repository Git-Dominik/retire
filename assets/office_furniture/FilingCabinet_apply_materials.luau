-- FilingCabinet: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material and its region's Color, anchors it as
-- non-colliding dressing and adds the fixture's light.
local map = {
	["FilingCabinet_Plinth"] = { Enum.Material.Metal, Color3.fromHex("#3A3C3C") },
	["FilingCabinet_Carcass"] = { Enum.Material.Metal, Color3.fromHex("#8F928E") },
	["FilingCabinet_Lock"] = { Enum.Material.Metal, Color3.fromHex("#B89B5E") },
	["FilingCabinet_Drawer1"] = { Enum.Material.Metal, Color3.fromHex("#A4A7A2") },
	["FilingCabinet_Drawer1Pull"] = { Enum.Material.Metal, Color3.fromHex("#D0D0C8") },
	["FilingCabinet_Drawer2"] = { Enum.Material.Metal, Color3.fromHex("#A4A7A2") },
	["FilingCabinet_Drawer2Pull"] = { Enum.Material.Metal, Color3.fromHex("#D0D0C8") },
	["FilingCabinet_Drawer3"] = { Enum.Material.Metal, Color3.fromHex("#A4A7A2") },
	["FilingCabinet_Drawer3Pull"] = { Enum.Material.Metal, Color3.fromHex("#D0D0C8") },
	["FilingCabinet_Drawer4"] = { Enum.Material.Metal, Color3.fromHex("#A4A7A2") },
	["FilingCabinet_Drawer4Pull"] = { Enum.Material.Metal, Color3.fromHex("#D0D0C8") },
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
	{ "COL_Body", Vector3.new(1.600, 4.400, 2.200), Vector3.new(0.000, 2.200, 0.070) },
}
for _, root in game:GetService("Selection"):Get() do
	if root:IsA("Model") and root:FindFirstChild("FilingCabinet_Carcass", true) then
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
		-- Each drawer and its pull become one Model, PrimaryPart = the drawer; it opens
		-- by pivoting along the cabinet's -Z (about 1.6 studs fully out).
		for k = 1, 4 do
			local d = root:FindFirstChild("FilingCabinet_Drawer" .. k, true)
			local p = root:FindFirstChild("FilingCabinet_Drawer" .. k .. "Pull", true)
			if d and p and not root:FindFirstChild("Drawer" .. k) then
				local g = Instance.new("Model")
				g.Name = "Drawer" .. k
				g.Parent = root
				d.Parent, p.Parent = g, g
				g.PrimaryPart = d
			end
		end
	end
end
