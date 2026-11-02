--!strict
-- The road's up under a vehicle: four probes near the chassis corners, their normals averaged and capped
-- at Config/Vehicles Ground.maxTilt from flat. Used by the driver's client and by the server for parked cars.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- the averaged ground normal under the chassis, or nil when no probe touches anything
function Ground.normal(chassis: BasePart, params: RaycastParams): Vector3?
	local cf = chassis.CFrame
	local half = chassis.Size / 2
	local inset = Vehicles.Ground.inset
	local down = -cf.UpVector * (half.Y * 2 + Vehicles.Ground.reach * Vehicles.StudsPerMetre)
	local sum, hits = Vector3.zero, 0
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local from =
				cf:PointToWorldSpace(Vector3.new(x * half.X * inset, half.Y, z * half.Z * inset))
			local hit = workspace:Raycast(from, down, params)
			if hit and hit.Normal.Y > 0.2 then
				sum += hit.Normal
				hits += 1
			end
		end
	end
	if hits == 0 then
		return nil
	end
	return Ground.cap(sum.Unit)
end

return Ground
