-- CoffeeMachine: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material and its region's Color, anchors it as
-- non-colliding dressing and adds the fixture's light.
local map = {
	["CoffeeMachine_Base"] = { Enum.Material.Plastic, Color3.fromHex("#2E3033") },
	["CoffeeMachine_Plate"] = { Enum.Material.Metal, Color3.fromHex("#8E9093") },
	["CoffeeMachine_Body"] = { Enum.Material.Plastic, Color3.fromHex("#3C3F43") },
	["CoffeeMachine_Trim"] = { Enum.Material.Plastic, Color3.fromHex("#222326") },
	["CoffeeMachine_Glass"] = { Enum.Material.Glass, Color3.fromHex("#D4DCDE") },
	["CoffeeMachine_Coffee"] = { Enum.Material.SmoothPlastic, Color3.fromHex("#6E3B24") },
	["CoffeeMachine_Window"] = { Enum.Material.Glass, Color3.fromHex("#6F8088") },
	["CoffeeMachine_Switch"] = { Enum.Material.SmoothPlastic, Color3.fromHex("#C2C3BE") },
	["CoffeeMachine_Indicator"] = { Enum.Material.Neon, Color3.fromHex("#FFA25A") },
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
			if p.Name == "CoffeeMachine_Indicator" and not p:FindFirstChildWhichIsA("Light") then
				local l = Instance.new("PointLight")
				l.Range, l.Brightness, l.Shadows = 1.5, 0.4, false
				l.Color = Color3.fromHex("#FFB06A")
				l.Parent = p
			end
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
	{ "COL_Body", Vector3.new(0.900, 1.380, 1.070), Vector3.new(0.033, 0.690, 0.015) },
}
for _, root in game:GetService("Selection"):Get() do
	if root:IsA("Model") and root:FindFirstChild("CoffeeMachine_Body", true) then
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
		for _, p in root:GetDescendants() do
			if p.Name == "CoffeeMachine_Glass" then
				p.Transparency = 0.6
			elseif p.Name == "CoffeeMachine_Window" then
				p.Transparency = 0.35
			end
		end
	end
end
