--!strict
-- Pulls the city map scan rows (tools/map/scan.luau) out of a saved place: lune run tools/map/extract <place.rbxl> <rows.hex>
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local place, out = process.args[1], process.args[2]
local game = roblox.deserializePlace(fs.readFile(place))
local folder = game:GetService("ServerStorage"):FindFirstChild("MapCap")
local rows = {}
for i = 0, 1023 do
	rows[i + 1] = folder:FindFirstChild(string.format("%04d", i)).Value
end
fs.writeFile(out, table.concat(rows, "\n"))
print("rows", #rows)
