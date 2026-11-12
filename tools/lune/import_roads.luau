--!strict
-- Turn the uploaded road meshes (tools/roads + tools/blender/export_roads.py) into assets/Roads.rbxm: a Folder
-- of template MeshParts (Road_<i>_<j>_<Asphalt|Concrete|Trim>) at the origin, each with a SurfaceAppearance
-- holding its texture (the trim's alpha cuts it out). RoadKit clones them and sets Size and CFrame from
-- Config/RoadMeshes, so the import scale doesn't matter.
-- lune run tools/lune/import_roads <raw.rbxm> <out.rbxm> <asphaltImageId> <concreteImageId> <trimImageId>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local raw, out = process.args[1], process.args[2]
local images = { Asphalt = process.args[3], Concrete = process.args[4], Trim = process.args[5] }
local folder = roblox.Instance.new("Folder")
folder.Name = "RoadModels"
local count, byLayer = 0, {}
for _, root in roblox.deserializeModel(fs.readFile(raw)) do
	for _, p in root:GetDescendants() do
		if p:IsA("MeshPart") then
			local layer = string.match(p.Name, "_(%a+)$")
			local image = layer and images[layer]
			assert(image, "unknown road mesh " .. p.Name)
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = roblox.Enum.Material.SmoothPlastic
			p.Color = roblox.Color3.new(1, 1, 1)
			p.RenderFidelity = roblox.Enum.RenderFidelity.Precise
			p.CFrame = roblox.CFrame.new()
			local sa = roblox.Instance.new("SurfaceAppearance")
			-- Lune drops the old string property; the Content one is what gets saved
			sa.ColorMapContent = roblox.Content.fromUri("rbxassetid://" .. image)
			sa.AlphaMode = if layer == "Trim"
				then roblox.Enum.AlphaMode.Transparency
				else roblox.Enum.AlphaMode.Overlay
			sa.Parent = p
			p.Parent = folder
			count += 1
			byLayer[layer] = (byLayer[layer] or 0) + 1
		end
	end
end
print(count, "meshes", byLayer.Asphalt, byLayer.Concrete, byLayer.Trim)
fs.writeFile(out, roblox.serializeModel({ folder }))
