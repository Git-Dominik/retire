-- OfficeChair: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material and its region's Color, anchors it as
-- non-colliding dressing and adds the fixture's light.
local map = {
	["OfficeChair_Base"] = { Enum.Material.Plastic, Color3.fromHex("#333538") },
	["OfficeChair_Wheels"] = { Enum.Material.Plastic, Color3.fromHex("#1F2022") },
	["OfficeChair_Column"] = { Enum.Material.Metal, Color3.fromHex("#6A6D71") },
	["OfficeChair_Frame"] = { Enum.Material.Metal, Color3.fromHex("#3E4044") },
	["OfficeChair_Under"] = { Enum.Material.Plastic, Color3.fromHex("#2E3035") },
	["OfficeChair_Pad"] = { Enum.Material.Sand, Color3.fromHex("#56647A") },
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
	{ "COL_Seat", Vector3.new(1.340, 1.740, 1.200), Vector3.new(0.000, 0.870, -0.057) },
	{ "COL_Back", Vector3.new(1.360, 1.080, 0.370), Vector3.new(0.000, 2.540, 0.768) },
}
for _, root in game:GetService("Selection"):Get() do
	if root:IsA("Model") and root:FindFirstChild("OfficeChair_Pad", true) then
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
