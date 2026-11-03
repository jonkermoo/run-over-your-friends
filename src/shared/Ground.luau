--!strict
-- The road's up under a vehicle: probes in two columns (left, right) and three rows (front, the centre of
-- mass, rear), their normals averaged and capped at Config/Vehicles Ground.maxTilt from flat. The probes that
-- hit also say whether the weight is over the ground (Rules/Balance). Used by the driver's client and by the
-- server for parked cars.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Rules.Balance)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)

local Ground = {}

local COS_MAX = math.cos(math.rad(Vehicles.Ground.maxTilt))
local SIN_MAX = math.sin(math.rad(Vehicles.Ground.maxTilt))

-- tip `n` back toward world up until it is no steeper than maxTilt
function Ground.cap(n: Vector3): Vector3
	if n.Y >= COS_MAX then
		return n
	end
	local flat = Vector3.new(n.X, 0, n.Z)
	if flat.Magnitude < 1e-3 then
		return Vector3.yAxis
	end
	return flat.Unit * SIN_MAX + Vector3.yAxis * COS_MAX
end

-- the averaged ground normal under the chassis (nil when no probe touches anything), and whether the centre
-- of mass sits over the probes that touched
function Ground.probe(chassis: BasePart, params: RaycastParams): (Vector3?, boolean)
	local cf = chassis.CFrame
	local half = chassis.Size / 2
	local inset = Vehicles.Ground.inset
	local com = cf:PointToObjectSpace(chassis.AssemblyCenterOfMass)
	local reachX, reachZ = half.X * inset, half.Z * inset
	local down = -cf.UpVector * (half.Y * 2 + Vehicles.Ground.reach * Vehicles.StudsPerMetre)
	local sum = Vector3.zero
	local touched: { Balance.Point } = {}
	for _, z in { -reachZ, math.clamp(com.Z, -reachZ, reachZ), reachZ } do
		for _, x in { -reachX, reachX } do
			local hit =
				workspace:Raycast(cf:PointToWorldSpace(Vector3.new(x, half.Y, z)), down, params)
			if hit and hit.Normal.Y > 0.2 then
				sum += hit.Normal
				table.insert(touched, { x = x, z = z })
			end
		end
	end
	if #touched == 0 then
		return nil, false
	end
	local margin = Vehicles.Balance.margin * half.Z
	return Ground.cap(sum.Unit), Balance.supported(touched, { x = com.X, z = com.Z }, margin)
end

function Ground.normal(chassis: BasePart, params: RaycastParams): Vector3?
	return (Ground.probe(chassis, params))
end

return Ground
