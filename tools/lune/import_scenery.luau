--!strict
-- Turn the uploaded scenery model (MeshParts named Crown, Blooms, Belt, Pine; tools/blender/export_scenery.py)
-- into assets/Scenery.rbxm: a Folder of template MeshParts at the origin, anchored, plain plastic. The game
-- clones them and sets Size, Color and CFrame (Greenery, OutskirtsKit), so the import scale doesn't matter.
-- lune run tools/lune/import_scenery <raw.rbxm> <out.rbxm>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local raw, out = process.args[1], process.args[2]
local source = roblox.deserializeModel(fs.readFile(raw))[1]
local folder = roblox.Instance.new("Folder")
folder.Name = "SceneryModels"
local found = {}
for _, p in source:GetDescendants() do
	if p:IsA("MeshPart") then
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = true
		p.Material = roblox.Enum.Material.SmoothPlastic
		p.CFrame = roblox.CFrame.new()
		p.Parent = folder
		table.insert(found, p.Name .. " " .. tostring(p.Size))
	end
end
table.sort(found)
print(table.concat(found, "\n"))
fs.writeFile(out, roblox.serializeModel({ folder }))
