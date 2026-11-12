--!strict
-- Write the road layout (Rules/RoadLayout) as JSON for the road mesh builder (tools/roads/build_roads.py)
-- and print its hash (stored in Config/RoadMeshes with the meshes).
-- lune run tools/lune/road_layout <out.json>
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local RoadLayout = require("../../src/shared/Rules/RoadLayout")

local layout = RoadLayout.fromConfig()
local hash = RoadLayout.hash(layout)
local out = table.clone(layout) :: any
out.hash = hash
fs.writeFile(process.args[1], serde.encode("json", out))
print(hash)
