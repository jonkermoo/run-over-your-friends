--!strict
-- A copy of a vehicle model trimmed to its switched-on mastery upgrades (Rules/Upgrades.part): the stock zones of
-- switched-on upgrades and the rebuilt zones of the rest are removed, and an upgrade's wheel set takes over the
-- Wheel_ names. Every place that clones a template (the built car, garage pictures, traffic, parked cars) goes
-- through here, so no copy ever shows a stock zone and its rebuilt zone together.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeRules = require(ReplicatedStorage.Shared.Rules.Upgrades)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)

local VehicleParts = {}

function VehicleParts.fit(model: Model, on: { number })
	local names = {}
	for _, p in model:GetChildren() do
		table.insert(names, p.Name)
	end
	local sets = UpgradeRules.wheelSets(names, on)
	local renames: { [Instance]: string } = {}
	for _, p in model:GetChildren() do
		local what = UpgradeRules.part(p.Name, on, sets)
		if what == "drop" then
			p:Destroy()
		elseif what ~= "keep" then
			renames[p] = what
		end
	end
	for p, name in renames do
		p.Name = name
	end
end

-- the painted parts: the car's Paint plus the painted pieces of its zones
function VehicleParts.paintParts(model: Model): { BasePart }
	local out = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and (p.Name == "Paint" or string.sub(p.Name, -6) == "_Paint") then
			table.insert(out, p)
		end
	end
	return out
end

-- print a car's decal on its painted parts (nil or "None" takes it off): a copy of its SurfaceAppearance from
-- ReplicatedStorage.VehicleDecals (tools/lune/build_decals), in Overlay mode so the paint colour shows where the
-- decal is clear
function VehicleParts.decal(model: Model, vehicleId: string, decalId: string?)
	local folder = ReplicatedStorage:FindFirstChild("VehicleDecals")
	local look = folder and decalId and folder:FindFirstChild(`{vehicleId}_{decalId}`)
	for _, p in VehicleParts.paintParts(model) do
		local old = p:FindFirstChild("Decal")
		if old then
			old:Destroy()
		end
		if look then
			local copy = look:Clone()
			copy.Name = "Decal"
			copy.Parent = p
		end
	end
end

-- a parts list that counts as the car's body for sizing and welding: everything but the wheels and markers
function VehicleParts.isBody(name: string): boolean
	return name == "Body"
		or name == "Paint"
		or string.match(name, "^[ZU]%d+$") ~= nil
		or string.match(name, "^[ZU]%d+_Paint$") ~= nil
end

-- a built car's row with its switched-on upgrades applied (its VehicleId and Upgrades attributes)
function VehicleParts.stats(car: Instance): Vehicles.Vehicle?
	local id = car:GetAttribute("VehicleId")
	local row = if typeof(id) == "string" then Vehicles.ById[id] else nil
	return if row
		then UpgradeRules.stats(row, UpgradeRules.decode(car:GetAttribute("Upgrades")))
		else nil
end

-- what a built car's switched-on upgrades do together (Rules/Upgrades.effect)
function VehicleParts.effect(car: Instance): { [string]: number }
	local id = car:GetAttribute("VehicleId")
	return UpgradeRules.effect(
		if typeof(id) == "string" then id else "",
		UpgradeRules.decode(car:GetAttribute("Upgrades"))
	)
end

return VehicleParts
