--!strict
-- Take the baked island terrain out of a saved place into assets/Terrain.rbxm, which default.project.json puts
-- in as Workspace.Terrain, so servers start with the terrain already there (server/Terra).
-- First, in Studio (Edit mode, command bar): require(game.ServerScriptService.Server.MapBuilder).bake(), then
-- save the place. Then:
-- lune run tools/lune/bake_terrain <saved.rbxl> <out.rbxm>   (from the repo root, on the code the bake was made from)

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local TerrainSource = require("./terrain_source")

local placePath, outPath = process.args[1], process.args[2]
assert(placePath and outPath, "usage: lune run tools/lune/bake_terrain <saved.rbxl> <out.rbxm>")

local game = roblox.deserializePlace(fs.readFile(placePath))
local terrain = game:GetService("Workspace"):FindFirstChildOfClass("Terrain")
assert(terrain, "the place has no Terrain")
local label = terrain:GetAttribute("BakedTerrain")
assert(
	type(label) == "string",
	"the terrain has no BakedTerrain label: run MapBuilder.bake() in Studio first"
)

local out = terrain:Clone()
-- only the voxels and their settings: the game adds clouds and anything else under it itself
for _, child in out:GetChildren() do
	child:Destroy()
end
-- the code it was drawn from, so tests/run can tell when the map changed since (tools/lune/terrain_source)
out:SetAttribute("BakedSource", TerrainSource.hash())
fs.writeFile(outPath, roblox.serializeModel({ out }))
print(`wrote {outPath}: terrain {label}, {#fs.readFile(outPath)} bytes`)
