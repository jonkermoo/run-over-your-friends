--!strict
-- Build assets/Decals.rbxm (ReplicatedStorage.VehicleDecals): one SurfaceAppearance per car per decal, named
-- <Vehicle>_<Decal>, with the decal image (Config/Upgrades Images) as its colour map in Overlay mode, so the clear
-- parts of the image show the painted part's Color. The game clones one onto each painted part (Shared/VehicleParts).
-- A SurfaceAppearance's map can't be set from game scripts, hence this file.
-- lune run tools/lune/build_decals <out.rbxm>

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Upgrades = require("../../src/shared/Config/Upgrades")

local out = assert(process.args[1], "usage: lune run tools/lune/build_decals <out.rbxm>")
local folder = roblox.Instance.new("Folder")
folder.Name = "VehicleDecals"
local count = 0
for vehicleId, images in Upgrades.Images do
	for decalId, imageId in images do
		local sa = roblox.Instance.new("SurfaceAppearance")
		sa.Name = `{vehicleId}_{decalId}`
		sa.ColorMapContent = roblox.Content.fromUri(`rbxassetid://{imageId}`)
		sa.AlphaMode = roblox.Enum.AlphaMode.Overlay
		sa.Parent = folder
		count += 1
	end
end
fs.writeFile(out, roblox.serializeModel({ folder }))
print("wrote", out, count, "decals")
