-- Couch: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material and its region's Color, anchors it as
-- non-colliding dressing and adds the fixture's light.
local map = {
	["Couch_Feet"] = { Enum.Material.Wood, Color3.fromHex("#362D28") },
	["Couch_Frame"] = { Enum.Material.Wood, Color3.fromHex("#4A3E35") },
	["Couch_Trim"] = { Enum.Material.Wood, Color3.fromHex("#6A584A") },
	["Couch_Studs"] = { Enum.Material.Metal, Color3.fromHex("#C0B9AE") },
	["Couch_Upholstery"] = { Enum.Material.Sand, Color3.fromHex("#8A6656") },
	["Couch_Padding"] = { Enum.Material.Sand, Color3.fromHex("#A07D6A") },
	["Couch_Pillows"] = { Enum.Material.Sand, Color3.fromHex("#A8845A") },
	["Couch_Tufts"] = { Enum.Material.Sand, Color3.fromHex("#7A5E40") },
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

-- Collision helpers (guide 9.2): invisible anchored boxes; the meshes above don't collide.
-- Offsets are from the bottom centre, z towards the back; the back's side is read off the
-- pillows (they sit behind the pivot) so an import that flips z still lines up.
local helpers = {
	{ "COL_Base", Vector3.new(8.300, 2.040, 3.680), Vector3.new(0.000, 1.020, -0.127), 0.0 },
	{ "COL_ArmL", Vector3.new(1.700, 1.200, 3.640), Vector3.new(-3.400, 2.640, -0.207), 0.0 },
	{ "COL_ArmR", Vector3.new(1.700, 1.200, 3.640), Vector3.new(3.400, 2.640, -0.207), 0.0 },
	{ "COL_Back", Vector3.new(5.200, 2.780, 0.850), Vector3.new(0.000, 3.471, 1.425), 10 },
}
for _, root in game:GetService("Selection"):Get() do
	local pillows = root:IsA("Model") and root:FindFirstChild("Couch_Pillows", true)
	if pillows then
		local cf, size = root:GetBoundingBox()
		local base = cf * CFrame.new(0, -size.Y / 2, 0)
		root.WorldPivot = base
		local back = base:PointToObjectSpace(pillows.Position).Z >= 0 and 1 or -1
		for _, h in helpers do
			local old = root:FindFirstChild(h[1])
			if old then
				old:Destroy()
			end
			local p = Instance.new("Part")
			p.Name, p.Size = h[1], h[2]
			p.CFrame = base * CFrame.new(h[3].X, h[3].Y, h[3].Z * back) * CFrame.Angles(math.rad(h[4]) * back, 0, 0)
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, true, false, false
			p.Transparency, p.CastShadow = 1, false
			p.Parent = root
		end
	end
end
