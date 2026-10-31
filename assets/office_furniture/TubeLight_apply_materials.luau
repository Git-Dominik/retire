-- TubeLight: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material and its region's Color, anchors it as
-- non-colliding dressing and adds the fixture's light.
local map = {
	["TubeLight_Housing"] = { Enum.Material.Metal, Color3.fromHex("#26282B") },
	["TubeLight_Tray"] = { Enum.Material.Metal, Color3.fromHex("#B7BABE") },
	["TubeLight_Reflector"] = { Enum.Material.Metal, Color3.fromHex("#9EA2A7") },
	["TubeLight_Tubes"] = { Enum.Material.Neon, Color3.fromHex("#EEF4FF") },
	["TubeLight_Sockets"] = { Enum.Material.Metal, Color3.fromHex("#3A3C40") },
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

for _, root in game:GetService("Selection"):Get() do
	if root:IsA("Model") and root:FindFirstChild("TubeLight_Tubes", true) then
		local tubes = root:FindFirstChild("TubeLight_Tubes", true)
		if tubes and not tubes:FindFirstChildWhichIsA("Light") then
			-- Two layers (guide Sec 8): a small glow, and a shadowed pool on the floor.
			local glow = Instance.new("PointLight")
			glow.Range, glow.Brightness, glow.Shadows = 8, 0.5, false
			glow.Color = Color3.fromHex("#DDE8FF")
			glow.Parent = tubes
			local pool = Instance.new("SpotLight")
			pool.Face, pool.Angle = Enum.NormalId.Bottom, 120
			pool.Range, pool.Brightness, pool.Shadows = 45, 1.5, true
			pool.Color = Color3.fromHex("#E4ECFF")
			pool.Parent = tubes
		end
	end
end
