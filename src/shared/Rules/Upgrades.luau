--!strict
-- Car mastery and upgrade rules (Config/Upgrades): levels from points, what a level opens, prices, the stats a car
-- drives with when upgrades are on, and which model parts show. Pure, so Lune tests it.

local Config = if typeof(script) == "Instance"
	then require(script.Parent.Parent.Config.Upgrades)
	else require("../Config/Upgrades")
local VehiclesConfig = if typeof(script) == "Instance"
	then require(script.Parent.Parent.Config.Vehicles)
	else require("../Config/Vehicles")

type Vehicle = VehiclesConfig.Vehicle
type Effect = Config.Effect

local Upgrades = {}

-- the mastery level for a car's points (0 before the first level)
function Upgrades.level(points: number): number
	local lvl = 0
	for i, need in Config.Levels do
		if points >= need then
			lvl = i
		end
	end
	return lvl
end

-- where the points sit inside the current level: level, points into it, points it spans (0 when mastered)
function Upgrades.progress(points: number): (number, number, number)
	local lvl = Upgrades.level(points)
	if lvl >= Config.MaxLevel then
		return lvl, 0, 0
	end
	local from = if lvl == 0 then 0 else Config.Levels[lvl]
	return lvl, points - from, Config.Levels[lvl + 1] - from
end

function Upgrades.upgradeOpen(level: number, n: number): boolean
	local need = Config.UpgradeLevel[n]
	return need ~= nil and level >= need
end

function Upgrades.decal(id: string): Config.Decal?
	for _, d in Config.Decals do
		if d.id == id then
			return d
		end
	end
	return nil
end

function Upgrades.decalOpen(level: number, id: string): boolean
	local d = Upgrades.decal(id)
	return d ~= nil and level >= d.level
end

-- what the car's upgrade n costs
function Upgrades.price(vehicleId: string, carPrice: number, n: number): number
	local basis = Config.PriceBasis[vehicleId] or carPrice
	local share = Config.PriceShare[n] or 0
	local floor = Config.PriceFloor[n] or 0
	return math.max(floor, math.floor(basis * share / 100 + 0.5) * 100)
end

function Upgrades.get(vehicleId: string, n: number): Config.Upgrade?
	local list = Config.ByVehicle[vehicleId]
	return if list then list[n] else nil
end

local ADD = { "speed", "accel", "handling", "weight", "reach", "rearReach", "wide", "trailerWide" }
local TIMES = {
	"throw",
	"pivot",
	"taxiRange",
	"jingleRange",
	"jingleEvery",
	"cannonRange",
	"cannonCone",
	"cannonForce",
	"stuntPay",
	"bounce",
	"thrusterTime",
	"thrusterPush",
	"jetPush",
	"jetTime",
	"flySpeed",
	"flyClimb",
}
local MOST = { "rearGrip", "maxBreak", "taxiCount" }

-- everything the switched-on upgrades do together: shares and studs add up, multipliers multiply (missing = 1),
-- and the set-to values take the biggest
function Upgrades.effect(vehicleId: string, on: { number }): { [string]: number }
	local out: { [string]: number } = {}
	for _, k in ADD do
		out[k] = 0
	end
	for _, k in TIMES do
		out[k] = 1
	end
	for _, n in on do
		local up = Upgrades.get(vehicleId, n)
		if up then
			local e = up.effect :: any
			for _, k in ADD do
				out[k] += e[k] or 0
			end
			for _, k in TIMES do
				out[k] *= e[k] or 1
			end
			for _, k in MOST do
				if e[k] then
					out[k] = math.max(out[k] or 0, e[k])
				end
			end
		end
	end
	return out
end

-- the car's own row with its switched-on upgrades applied (a new frozen row; the same row back when none are on)
function Upgrades.stats(row: Vehicle, on: { number }): Vehicle
	if #on == 0 then
		return row
	end
	local e = Upgrades.effect(row.id, on)
	local copy = table.clone(row) :: any
	copy.topSpeed = row.topSpeed * (1 + e.speed)
	copy.launch = row.launch * (1 + e.accel)
	copy.power = row.power * (1 + e.accel)
	copy.grip = row.grip * (1 + e.handling)
	copy.weight = row.weight * (1 + e.weight)
	if e.rearGrip then
		copy.rearGrip = math.max(row.rearGrip, e.rearGrip)
	end
	if e.maxBreak and row.maxBreak then
		copy.maxBreak = math.max(row.maxBreak, e.maxBreak)
	end
	if row.tracks then
		copy.tracks = table.freeze({
			pivotRate = row.tracks.pivotRate * e.pivot,
			pivotFade = row.tracks.pivotFade,
			pivotAccel = row.tracks.pivotAccel,
		})
	end
	return table.freeze(copy)
end

-- the switched-on upgrade numbers as the model's Upgrades attribute ("1,3") and back
function Upgrades.encode(on: { number }): string
	local s = table.clone(on)
	table.sort(s)
	local parts = {}
	for _, n in s do
		table.insert(parts, tostring(n))
	end
	return table.concat(parts, ",")
end

function Upgrades.decode(text: any): { number }
	local out = {}
	if typeof(text) ~= "string" then
		return out
	end
	for piece in string.gmatch(text, "%d+") do
		local n = tonumber(piece) :: number
		if n >= 1 and n <= 3 and not table.find(out, n) then
			table.insert(out, n)
		end
	end
	table.sort(out)
	return out
end

-- the switched-on upgrades from a saved per-car table ({ ["1"] = true, ["2"] = false }: bought, and whether on)
function Upgrades.onList(saved: { [string]: boolean }?): { number }
	local out = {}
	if saved then
		for key, on in saved do
			local n = tonumber(key)
			if on == true and n and n >= 1 and n <= 3 then
				table.insert(out, n)
			end
		end
	end
	table.sort(out)
	return out
end

-- why upgrade n of a car can't be bought, or nil when it can
function Upgrades.buyProblem(
	owned: { [string]: boolean },
	points: number,
	bought: { [string]: boolean }?,
	money: number,
	vehicleId: any,
	n: any
): string?
	if typeof(vehicleId) ~= "string" or typeof(n) ~= "number" then
		return "unknown"
	end
	local row = VehiclesConfig.ById[vehicleId]
	if not row or not Upgrades.get(vehicleId, n) then
		return "unknown"
	elseif not owned[vehicleId] then
		return "car"
	elseif bought and bought[tostring(n)] ~= nil then
		return "owned"
	elseif not Upgrades.upgradeOpen(Upgrades.level(points), n) then
		return "locked"
	elseif money < Upgrades.price(vehicleId, row.price, n) then
		return "money"
	end
	return nil
end

-- why a decal can't go on a car, or nil when it can ("None" takes it off)
function Upgrades.decalProblem(
	owned: { [string]: boolean },
	points: number,
	vehicleId: any,
	decalId: any
): string?
	if
		typeof(vehicleId) ~= "string"
		or typeof(decalId) ~= "string"
		or not VehiclesConfig.ById[vehicleId]
	then
		return "unknown"
	elseif not owned[vehicleId] then
		return "car"
	elseif decalId == "None" then
		return nil
	elseif not Upgrades.decal(decalId) then
		return "unknown"
	elseif not Upgrades.decalOpen(Upgrades.level(points), decalId) then
		return "locked"
	end
	return nil
end

-- the image a car's decal prints (0 = none or not uploaded)
function Upgrades.image(vehicleId: string, decalId: string?): number
	local byCar = decalId and Config.Images[vehicleId]
	return if byCar then byCar[decalId :: string] or 0 else 0
end

-- what happens to one part of a vehicle model with these upgrades on: "keep", "drop", or the new name for an
-- upgrade's wheel (U<n>W_FL1 -> Wheel_FL1). `wheelSets` holds the upgrade numbers whose wheel sets are on.
function Upgrades.part(name: string, on: { number }, wheelSets: { [number]: boolean }): string
	local kind, digits = string.match(name, "^([ZU])(%d+)")
	if kind then
		local n = tonumber(digits) :: number
		local isOn = table.find(on, n) ~= nil
		local wheel = string.match(name, "^U%d+W_(.+)$")
		if wheel then
			return if isOn then "Wheel_" .. wheel else "drop"
		end
		if kind == "Z" then
			return if isOn then "drop" else "keep"
		end
		return if isOn then "keep" else "drop"
	end
	if string.sub(name, 1, 6) == "Wheel_" and next(wheelSets) ~= nil then
		return "drop"
	end
	return "keep"
end

-- the upgrade numbers among `on` that bring their own wheel set, from a model's part names
function Upgrades.wheelSets(names: { string }, on: { number }): { [number]: boolean }
	local out = {}
	for _, name in names do
		local digits = string.match(name, "^U(%d+)W_")
		local n = digits and tonumber(digits)
		if n and table.find(on, n) then
			out[n] = true
		end
	end
	return out
end

-- saved mastery, upgrades and decals from an old or odd save, kept to known cars, upgrades and decals
function Upgrades.clean(
	mastery: any,
	upgrades: any,
	decal: any
): ({ [string]: number }, { [string]: { [string]: boolean } }, {
	[string]: string,
})
	local m, u, d = {}, {}, {}
	if typeof(mastery) == "table" then
		for id, pts in mastery do
			if VehiclesConfig.ById[id] and typeof(pts) == "number" and pts == pts and pts > 0 then
				m[id] = math.min(pts, 1e9)
			end
		end
	end
	if typeof(upgrades) == "table" then
		for id, set in upgrades do
			if VehiclesConfig.ById[id] and typeof(set) == "table" then
				local out = {}
				for key, on in set do
					local n = tonumber(key)
					if n and Upgrades.get(id, n) and typeof(on) == "boolean" then
						out[tostring(n)] = on
					end
				end
				if next(out) then
					u[id] = out
				end
			end
		end
	end
	if typeof(decal) == "table" then
		for id, name in decal do
			if VehiclesConfig.ById[id] and typeof(name) == "string" and Upgrades.decal(name) then
				d[id] = name
			end
		end
	end
	return m, u, d
end

-- mastery points for a drive of this many studs, carrying the leftover studs over
function Upgrades.drivePoints(studs: number): (number, number)
	local per = Config.Points.StudsPerPoint
	local pts = math.floor(studs / per)
	return pts, studs - pts * per
end

return Upgrades
