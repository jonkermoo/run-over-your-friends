--!strict
-- The city map's scan (Config/CityMap): run in Studio's EDIT mode on a copy of the place (not the published
-- one). It builds the map, casts one ray straight down per sample (SS x SS samples a pixel, averaged), and
-- stores each picture row as hex r g b h (h = (y + 50) / 2) in ServerStorage.MapCap. Save the copy, then
-- `lune run tools/map/extract <place.rbxl> rows.hex` and `python tools/map/render.py rows.hex citymap.png`.
-- Keep CX, CZ, SPAN in step with Config/CityMap Centre and Span.
--
-- Road meshes collide as boxes, so they're switched to precise collision for the scan and coloured by their
-- layer (Asphalt dark, Concrete pale; Trim, the paint and kerbs, is skipped). The invisible drive surfaces
-- under the city's roads count as asphalt (low) or sidewalk (raised). Other see-through parts, the far
-- skyline stand-ins and anything outside workspace.Map are skipped.

local CX, CZ, SPAN, OUT, SS = 850, 100, 7000, 2048, 2
local ASPH = Color3.fromRGB(58, 60, 66)
local WALK = Color3.fromRGB(176, 174, 168)

local root = game:GetService("ServerScriptService"):WaitForChild("Server")
local world = require(root:WaitForChild("MapBuilder")).build()
pcall(function()
	require(root:WaitForChild("LookService")).apply(world.buildings)
end)
pcall(function()
	require(root:WaitForChild("StreetLife")).build(world)
end)
local map = workspace:WaitForChild("Map")
local roads = map:WaitForChild("Static"):WaitForChild("Roads")
local skyline = map:FindFirstChild("Skyline")

local layer: { [Instance]: string } = {}
local surf: { [Instance]: boolean } = {}
for _, p in workspace:GetDescendants() do
	if p:IsA("BasePart") then
		local q
		if p:IsDescendantOf(roads) and p:IsA("MeshPart") then
			local l = p.Name:match("_(%a+)$") or ""
			p.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
			layer[p] = l
			q = l ~= "Trim"
		elseif not p:IsDescendantOf(map) or (skyline and p:IsDescendantOf(skyline)) then
			q = false
		elseif p.Transparency >= 0.6 then
			q = p.Name == "Part" and p.Parent == map.Static
			if q then
				surf[p] = true
			end
		else
			q = true
		end
		p.CanQuery = q
	end
end

local folder = game:GetService("ServerStorage"):FindFirstChild("MapCap") or Instance.new("Folder")
folder.Name = "MapCap"
folder:ClearAllChildren()
folder.Parent = game:GetService("ServerStorage")

local T = workspace.Terrain
local params = RaycastParams.new()
params.IgnoreWater = false
local N = OUT * SS
local step = SPAN / N
local x0, z0 = CX - SPAN / 2, CZ - SPAN / 2
local matCol: { [Enum.Material]: Color3 } = {}
local function colOf(r: RaycastResult?): (number, number, number, number)
	if not r then
		return 0.08, 0.09, 0.1, -50
	end
	local inst = r.Instance
	local c: Color3
	if inst == T then
		local m = r.Material
		if m == Enum.Material.Water then
			c = T.WaterColor
		else
			local known = matCol[m]
			if not known then
				local ok, v = pcall(function()
					return T:GetMaterialColor(m)
				end)
				known = if ok then v else Color3.new(0.4, 0.6, 0.3)
				matCol[m] = known
			end
			c = known
		end
	elseif layer[inst] then
		c = if layer[inst] == "Concrete" then WALK else ASPH
	elseif surf[inst] then
		c = if r.Position.Y > 0.3 then WALK else ASPH
	else
		c = (inst :: BasePart).Color
	end
	return c.R, c.G, c.B, r.Position.Y
end

local down = Vector3.new(0, -2000, 0)
for oy = 0, OUT - 1 do
	local row = table.create(OUT)
	for ox = 0, OUT - 1 do
		local R, G, B, H = 0, 0, 0, 0
		for sy = 0, SS - 1 do
			for sx = 0, SS - 1 do
				local at = Vector3.new(x0 + (ox * SS + sx + 0.5) * step, 1500, z0 + (oy * SS + sy + 0.5) * step)
				local a, b, c, h = colOf(workspace:Raycast(at, down, params))
				R += a
				G += b
				B += c
				H += h
			end
		end
		local k = SS * SS
		row[ox + 1] = string.format(
			"%02x%02x%02x%02x",
			math.round(R / k * 255),
			math.round(G / k * 255),
			math.round(B / k * 255),
			math.clamp(math.round((H / k + 50) / 2), 0, 255)
		)
	end
	local v = Instance.new("StringValue")
	v.Name = string.format("%04d", oy)
	v.Value = table.concat(row)
	v.Parent = folder
	task.wait()
end
-- only the rows need saving
map.Parent = nil
print("city map scan done")
