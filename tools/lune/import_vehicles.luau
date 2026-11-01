--!strict
-- Turn the uploaded vehicle model (one flat model, every part named <Id>_Body or <Id>_Wheel_<Corner><n>)
-- into assets/Vehicles.rbxm: one Model per vehicle, true size in studs, centred on X/Z, wheels' bottom at Y = 0.
-- lune run tools/lune/import_vehicles <raw.rbxm> <out.rbxm> <studsInBlender> <paletteImageId>
-- <studsInBlender>: how big the importer made one Blender unit (measured: 47.344, from the export spacing).
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local raw, out = process.args[1], process.args[2]
local factor = 1 / assert(tonumber(process.args[3]), "importer scale")
local texture = roblox.Content.fromUri("rbxassetid://" .. assert(process.args[4], "palette image id"))

local source = roblox.deserializeModel(fs.readFile(raw))[1]
local groups: { [string]: { any } } = {}
for _, part in source:GetChildren() do
	local id = string.match(part.Name, "^([^_]+)_")
	if id then
		groups[id] = groups[id] or {}
		table.insert(groups[id], part)
	end
end

local folder = Instance.new("Folder")
folder.Name = "VehicleModels"
for id, parts in groups do
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, p in parts do
		local half = p.Size * factor / 2
		local c = p.CFrame.Position * factor
		lo = Vector3.new(math.min(lo.X, c.X - half.X), math.min(lo.Y, c.Y - half.Y), math.min(lo.Z, c.Z - half.Z))
		hi = Vector3.new(math.max(hi.X, c.X + half.X), math.max(hi.Y, c.Y + half.Y), math.max(hi.Z, c.Z + half.Z))
	end
	local origin = Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	local model = Instance.new("Model")
	model.Name = id
	for _, p in parts do
		p.Size = p.Size * factor
		p.CFrame = CFrame.new(p.CFrame.Position * factor - origin)
		p.TextureContent = texture
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.Name = string.sub(p.Name, #id + 2)
		-- some source bodies have open or flipped panels (the Roadster's door seams): draw both sides
		if p.Name == "Body" then
			p.DoubleSided = true
		end
		p.Parent = model
	end
	model.Parent = folder
	print(string.format("%-10s %6.1f x %5.1f x %6.1f studs, %d parts", id, hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z, #parts))
end
fs.writeFile(out, roblox.serializeModel({ folder }))
print("wrote", out)
