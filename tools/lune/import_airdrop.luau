--!strict
-- Put the Cash Drop event's airdrop (tools/blender/export_airdrop.py, uploaded as an Open Cloud Model) into
-- assets/EventModels.rbxm as ServerStorage.EventModels.Airdrop: true size in studs, the crate's bottom centre at
-- 0, each part one plain colour (LOOK), anchored and not colliding. The Chute parts are hidden in game once the
-- crate lands (server/EventProps).
-- lune run tools/lune/import_airdrop <place.rbxl> <out.rbxm>
-- <place.rbxl>: a place saved with the uploaded model (InsertService:LoadAsset) in ServerStorage as AirdropRaw.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Color3 = roblox.Color3

local BOX = "CSGPHS\0\0\0\0BLOCK" -- what Studio saves as a Box mesh's collision data
local LOOK: { [string]: { number } } = {
	Crate = { 92, 104, 52 }, -- olive boards
	Crate_Band = { 44, 46, 50 }, -- steel
	Crate_Trim = { 196, 174, 120 }, -- khaki straps, stencils and pallet
	Chute = { 222, 58, 52 }, -- red gores
	Chute_Stripe = { 242, 240, 234 }, -- white gores
	Chute_Lines = { 210, 210, 205 },
}
local DOUBLE = { Chute = true, Chute_Stripe = true }

local place, out = process.args[1], assert(process.args[2], "out.rbxm")
local game = roblox.deserializePlace(fs.readFile(place))
local raw = game:GetService("ServerStorage"):FindFirstChild("AirdropRaw")
assert(raw, "no ServerStorage.AirdropRaw in the place")

local model = Instance.new("Model")
model.Name = "Airdrop"
local count = 0
for _, p in raw:GetDescendants() do
	if p:IsA("MeshPart") and p.Name ~= "Origin" then
		local rgb = assert(LOOK[p.Name], "no look for " .. p.Name)
		p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		p.Material = roblox.Enum.Material.SmoothPlastic
		p.DoubleSided = DOUBLE[p.Name] == true
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = p.Name ~= "Chute_Lines"
		p.CollisionFidelity = roblox.Enum.CollisionFidelity.Box
		p.PhysicalConfigData = BOX
		p.Parent = model
		count += 1
	end
end
model.PrimaryPart = model:FindFirstChild("Crate")
assert(model.PrimaryPart, "no Crate part")

local root = Instance.new("Folder")
root.Name = "EventModels"
model.Parent = root
fs.writeFile(out, roblox.serializeModel({ root }))
print(string.format("Airdrop: %d parts -> %s", count, out))
