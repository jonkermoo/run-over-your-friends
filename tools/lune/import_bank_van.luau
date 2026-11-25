--!strict
-- Put the Money Truck event's bank van (tools/blender/export_bank_van.py, uploaded as an Open Cloud Model) into
-- assets/Vehicles.rbxm as VehicleModels.BankVan, built like the other vehicles: true size in studs, centred on X/Z
-- from its Body and wheels, wheels' bottom at Y = 0, front -Z. The Body and wheels wear the pack palette (as
-- tools/lune/import_vehicles does); Paint and Trim are plain colours client/EventProps repaints from
-- Config/Events MoneyTruck.
-- lune run tools/lune/import_bank_van <raw.rbxm> <vehicles.rbxm> <paletteImageId>
-- <raw.rbxm>: the uploaded model as Studio loaded it (InsertService:LoadAsset, saved out of a place).
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Color3 = roblox.Color3

local BOX = "CSGPHS\0\0\0\0BLOCK" -- what Studio saves as a Box mesh's collision data
local LENGTH = 33.47 -- studs, bumper to bumper: the Body's length in the Blender build (its PART line)
-- plain colours (nil: the palette texture)
local LOOK: { [string]: { number }? } = {
	Body = nil,
	Wheel = nil,
	Paint = { 52, 78, 60 },
	Trim = { 255, 196, 40 },
}

local raw, out = process.args[1], process.args[2]
local texture =
	roblox.Content.fromUri("rbxassetid://" .. assert(process.args[3], "palette image id"))
local parts: { any } = {}
for _, root in roblox.deserializeModel(fs.readFile(raw)) do
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, d in list do
		if d:IsA("MeshPart") and d.Name ~= "Origin" then
			table.insert(parts, d)
		end
	end
end
local function find(name: string): any
	for _, p in parts do
		if p.Name == name then
			return p
		end
	end
	error("no " .. name)
end

-- the scale: the Body's long side is LENGTH studs
local body = find("Body")
local factor = LENGTH / math.max(body.Size.X, body.Size.Z)
-- the front faces -Z: the front wheels must be ahead of the Body's middle
local turn = if find("Wheel_FL1").CFrame.Position.Z > body.CFrame.Position.Z
	then CFrame.Angles(0, math.pi, 0)
	else CFrame.identity

local lo = Vector3.new(math.huge, math.huge, math.huge)
local hi = -lo
for _, p in parts do
	if p.Name == "Body" or string.sub(p.Name, 1, 6) == "Wheel_" then
		local c = (turn * p.CFrame).Position * factor
		local half = (turn * p.CFrame - (turn * p.CFrame).Position):VectorToWorldSpace(
			p.Size * factor / 2
		)
		half = Vector3.new(math.abs(half.X), math.abs(half.Y), math.abs(half.Z))
		lo = Vector3.new(
			math.min(lo.X, c.X - half.X),
			math.min(lo.Y, c.Y - half.Y),
			math.min(lo.Z, c.Z - half.Z)
		)
		hi = Vector3.new(
			math.max(hi.X, c.X + half.X),
			math.max(hi.Y, c.Y + half.Y),
			math.max(hi.Z, c.Z + half.Z)
		)
	end
end
local origin = Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)

local model = Instance.new("Model")
model.Name = "BankVan"
for _, p in parts do
	local cf = turn * p.CFrame
	p.Size = p.Size * factor
	p.CFrame = (cf - cf.Position) + (cf.Position * factor - origin)
	local kind = if string.sub(p.Name, 1, 6) == "Wheel_" then "Wheel" else p.Name
	assert(kind == "Body" or kind == "Wheel" or LOOK[kind], "no look for " .. p.Name)
	local rgb = LOOK[kind]
	if rgb then
		p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	else
		p.TextureContent = texture
	end
	if p.Name == "Body" or p.Name == "Paint" then
		p.DoubleSided = true -- the pack bodies have open panels (as import_vehicles)
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	if p.Name ~= "Body" then
		p.CollisionFidelity = roblox.Enum.CollisionFidelity.Box
		p.PhysicalConfigData = BOX
	end
	p.Parent = model
end

local vehicles = roblox.deserializeModel(fs.readFile(out))[1]
local old = vehicles:FindFirstChild("BankVan")
if old then
	old:Destroy()
end
model.Parent = vehicles
fs.writeFile(out, roblox.serializeModel({ vehicles }))
print(
	string.format(
		"BankVan %.1f x %.1f x %.1f studs, %d parts, factor %.4f%s",
		hi.X - lo.X,
		hi.Y - lo.Y,
		hi.Z - lo.Z,
		#parts,
		factor,
		if turn == CFrame.identity then "" else ", turned 180"
	)
)
