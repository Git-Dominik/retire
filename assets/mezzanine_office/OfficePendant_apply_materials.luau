-- OfficePendant: run in the Studio command bar with the imported model selected.
-- Sets each MeshPart's built-in Material and its region's Color, anchors it as
-- non-colliding dressing and adds the fixture's light.
local map = {
	["OfficePendant_Hanger"] = { Enum.Material.Metal, Color3.fromHex("#3F423D") },
	["OfficePendant_Shade"] = { Enum.Material.Metal, Color3.fromHex("#4E5E55") },
	["OfficePendant_ShadeIn"] = { Enum.Material.SmoothPlastic, Color3.fromHex("#D8CDB4") },
	["OfficePendant_Bulb"] = { Enum.Material.Neon, Color3.fromHex("#FFE3A8") },
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
		root:SetAttribute("LightSource", true)
	end
end

-- Placement: fit onto the placeholder Parts built in Studio, keep its lights.
local office = workspace.FactoryRoomEditCopies.PipeGallery:FindFirstChild("MezzanineOffice")
local holders = office and office:FindFirstChild("BlenderPlaceholders")
for _, root in game:GetService("Selection"):Get() do
	local bulb = root:FindFirstChild("OfficePendant_Bulb", true)
	if root:IsA("Model") and bulb and holders then
		local ph = holders:FindFirstChild("Placeholder_PendantLamp")
		if ph then
			local cf, size = root:GetBoundingBox()
			root.WorldPivot = cf * CFrame.new(0, size.Y / 2, 0)
			root:PivotTo(ph:GetAttribute("Mount"))
			for _, p in root:GetDescendants() do
				if p:IsA("BasePart") and p.Material == Enum.Material.Glass then
					p.Transparency = 0.5
				end
			end
			for _, l in ph:GetChildren() do
				if l:IsA("Light") then
					l.Parent = bulb
				end
			end
			root.Name = "OfficePendant"
			root:SetAttribute("LightSource", true)
			root.Parent = office.Lights
			ph:Destroy()
		end
	end
end
