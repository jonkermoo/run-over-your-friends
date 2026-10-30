--!strict
-- Builds a drivable rig from a vehicle model (Body + Wheel_<Corner><n> meshes, base centre at the origin,
-- front facing -Z): an invisible box Chassis that collides and carries the Drive/Turn constraints,
-- a Sprung part the body hangs from (the client animates its weld for suspension), wheel welds
-- tagged with Corner and Spin, a VehicleSeat and the sound loops.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)

local VehicleBuilder = {}

local SOUNDS = {
	Motor = "rbxassetid://73461257901277",
	Road = "rbxassetid://113702622207540",
	Wind = "rbxassetid://79950968390736",
	Squeal = "rbxassetid://71105905939198",
}
local BIG = 1e8

local function weld(name: string, part0: BasePart, part1: BasePart): Weld
	local w = Instance.new("Weld")
	w.Name = name
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	w.Parent = part0
	return w
end

function VehicleBuilder.build(id: string): Model
	local stats = assert(Vehicles.ById[id], "unknown vehicle " .. id)
	local template = ReplicatedStorage:WaitForChild("VehicleModels"):FindFirstChild(id) :: Model
	assert(template, "no model for " .. id)
	local model = template:Clone()
	model.Name = id

	local body = model:FindFirstChild("Body") :: BasePart
	local cf, size = model:GetBoundingBox()
	local length, width = size.Z, size.X
	local wheels: { BasePart } = {}
	local wheelRadius = 0
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and string.sub(p.Name, 1, 6) == "Wheel_" then
			table.insert(wheels, p)
			wheelRadius = math.max(wheelRadius, p.Size.Y / 2)
		end
	end

	-- the chassis: a box from the ground up to about the bumpers, a little inside the body's outline
	local chassisHeight = math.clamp(body.Size.Y * 0.35, 1.6, 5)
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(math.max(width * 0.82, 3), chassisHeight, math.max(length * 0.86, 4))
	chassis.CFrame = CFrame.new(0, chassisHeight / 2, cf.Position.Z)
	chassis.Transparency = 1
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 1)
	chassis.CollisionGroup = "Vehicles"
	chassis.Parent = model
	model.PrimaryPart = chassis

	local sprung = Instance.new("Part")
	sprung.Name = "Sprung"
	sprung.Size = Vector3.one
	sprung.CFrame = chassis.CFrame
	sprung.Transparency = 1
	sprung.CanCollide = false
	sprung.CanQuery = false
	sprung.CanTouch = false
	sprung.Massless = true
	sprung.Parent = model
	weld("Suspension", chassis, sprung):SetAttribute("Suspension", true)
	weld("BodyWeld", sprung, body)

	for _, w in wheels do
		local corner = string.sub(w.Name, 7, 8)
		local wl = weld("Wheel_" .. string.sub(w.Name, 7), chassis, w)
		wl:SetAttribute("Corner", corner)
		wl:SetAttribute("Spin", true)
	end

	local seatPos = stats.seat
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.CFrame = CFrame.new(seatPos[1], seatPos[2], seatPos[3])
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanTouch = true
	seat.Massless = true
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.HeadsUpDisplay = false
	seat.Parent = model
	weld("SeatWeld", chassis, seat)

	local att = Instance.new("Attachment")
	att.Name = "Centre"
	att.Parent = chassis
	local drive = Instance.new("LinearVelocity")
	drive.Name = "Drive"
	drive.Attachment0 = att
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	drive.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	drive.MaxAxesForce = Vector3.new(BIG, 0, BIG)
	drive.VectorVelocity = Vector3.zero
	drive.Parent = chassis
	local turn = Instance.new("AngularVelocity")
	turn.Name = "Turn"
	turn.Attachment0 = att
	turn.RelativeTo = Enum.ActuatorRelativeTo.World
	turn.MaxTorque = BIG
	turn.AngularVelocity = Vector3.zero
	turn.Parent = chassis

	for name, sid in SOUNDS do
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = sid
		s.Looped = true
		s.Volume = 0
		s.RollOffMinDistance = 15
		s.RollOffMaxDistance = 250
		s.Parent = chassis
	end

	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			if p ~= chassis then
				p.CanCollide = false
				p.CollisionGroup = "Vehicles"
			end
		end
	end

	model:SetAttribute("VehicleId", id)
	model:SetAttribute("StudsPerMetre", Vehicles.StudsPerMetre)
	model:SetAttribute("WheelRadius", math.max(wheelRadius, 0.5))
	model:SetAttribute("Length", length)
	model.WorldPivot = CFrame.new()
	CollectionService:AddTag(model, "Vehicle")
	return model
end

return VehicleBuilder
