--!strict
-- Builds a drivable rig from a vehicle model (Body + Wheel_<Corner><n> meshes, plus the cabin: Glass, Interior,
-- Mirror, Steer, NeedleSpeed/NeedleRev, bulldozer StickL/StickR, and tiny marker parts SteerPivot, StickLPivot,
-- StickRPivot, GripL, GripR that are read and removed; crawler vehicles add RollerL<n>/RollerR<n> and one
-- TrackShoe copied round each loop; base centre at the origin, front facing -Z): an invisible box Chassis that collides and carries the Drive/Turn constraints,
-- a Sprung part the body hangs from (the client animates its weld for suspension), wheel welds
-- tagged with Corner and Spin, a VehicleSeat and the sound loops. A vehicle with a trailer row also gets the
-- trailer model as a child Model "Trailer": its own collider on a ball-joint hitch, with tyres that resist sliding.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cockpit = require(ReplicatedStorage.Shared.Config.Cockpit)
local Tracks = require(ReplicatedStorage.Shared.Rules.Tracks)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)

local VehicleBuilder = {}

local SOUNDS = {
	Road = "rbxassetid://113702622207540",
	Wind = "rbxassetid://79950968390736",
	Squeal = "rbxassetid://71105905939198",
}
local BIG = 1e8
local GLASS_SEE_THROUGH = 0.45
local MIRROR_SHINE = 0.25 -- any more and the sky turns it into a white slab
local STEER_TILT = 22 -- degrees the cabin steering wheel leans back towards the driver, unless the row says

local function weld(name: string, part0: BasePart, part1: BasePart): Weld
	local w = Instance.new("Weld")
	w.Name = name
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	w.Parent = part0
	return w
end

-- a weld that turns `part` about `pivot` (world point): C1 carries the offset, so rotating C0 turns it in place
local function pivotWeld(
	name: string,
	part0: BasePart,
	part: BasePart,
	pivot: Vector3,
	lean: CFrame
): Weld
	local w = Instance.new("Weld")
	w.Name = name
	w.Part0 = part0
	w.Part1 = part
	w.C0 = part0.CFrame:ToObjectSpace(CFrame.new(pivot)) * lean
	w.C1 = part.CFrame:ToObjectSpace(CFrame.new(pivot))
	w.Parent = part0
	return w
end

-- a marker part's position, and the marker gone
local function takeMark(model: Model, name: string): Vector3?
	local m = model:FindFirstChild(name)
	if m and m:IsA("BasePart") then
		local at = m.Position
		m:Destroy()
		return at
	end
	return nil
end

local function addGrip(part: BasePart, name: string, at: Vector3)
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = part.CFrame:ToObjectSpace(CFrame.new(at))
	a.Parent = part
end

local function skidBall(model: Instance, chassis: BasePart, at: Vector3, radius: number)
	local ball = Instance.new("Part")
	ball.Name = "Skid"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * radius * 2
	ball.CFrame = CFrame.new(at)
	ball.Transparency = 1
	ball.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 1)
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Parent = model
	weld("SkidWeld", chassis, ball)
end

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

-- The trailer: moved so its kingpin sits on the tractor's hitch, an invisible collider riding on two rear
-- balls (the hitch carries the front), a ball joint that lets it swing and pitch but not flip, and a capped
-- sideways hold at the rear axle so it follows the tractor like real tyres until it's flung too hard.
local function buildTrailer(model: Model, chassis: BasePart, spec: Vehicles.Trailer)
	local template =
		ReplicatedStorage:WaitForChild("VehicleModels"):FindFirstChild(spec.model) :: Model
	assert(template, "no trailer model " .. spec.model)
	local trailer = template:Clone()
	trailer.Name = "Trailer"
	local hitch = vec(spec.hitch)
	local offset = CFrame.new(hitch - vec(spec.kingpin))
	local wheels: { BasePart } = {}
	local wheelRadius, axleZ = 0, 0
	for _, p in trailer:GetChildren() do
		if p:IsA("BasePart") then
			p.CFrame = offset * p.CFrame
			if string.sub(p.Name, 1, 6) == "Wheel_" then
				table.insert(wheels, p)
				wheelRadius = math.max(wheelRadius, p.Size.Y / 2)
				axleZ += p.Position.Z
			end
		end
	end
	axleZ /= math.max(#wheels, 1)
	local body = trailer:FindFirstChild("Body") :: BasePart
	local cf, size = trailer:GetBoundingBox()
	local skid = math.clamp(wheelRadius * 0.8, 0.8, 2)
	local height = math.clamp(body.Size.Y * 0.35, 1.6, 5)
	local box = Instance.new("Part")
	box.Name = "TrailerChassis"
	box.Size = Vector3.new(size.X * 0.82, height, size.Z * 0.9)
	box.CFrame = CFrame.new(0, skid * 0.7 + height / 2, cf.Position.Z)
	box.Transparency = 1
	box.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 1)
	box.Parent = trailer
	trailer.PrimaryPart = box
	for _, sx in { -1, 1 } do
		skidBall(trailer, box, Vector3.new(sx * (box.Size.X / 2 - skid), skid, axleZ), skid)
	end
	weld("BodyWeld", box, body)
	for _, w in wheels do
		local wl = weld("Wheel_" .. string.sub(w.Name, 7), box, w)
		wl:SetAttribute("Corner", string.sub(w.Name, 7, 8))
		wl:SetAttribute("Spin", true)
	end

	-- attachments point backwards (+Z) so the joint's cone is centred on a straight trailer
	local axis = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, Vector3.yAxis)
	local a0 = Instance.new("Attachment")
	a0.Name = "Hitch"
	a0.CFrame = chassis.CFrame:ToObjectSpace(CFrame.new(hitch)) * axis
	a0.Parent = chassis
	local a1 = Instance.new("Attachment")
	a1.Name = "Kingpin"
	a1.CFrame = box.CFrame:ToObjectSpace(CFrame.new(hitch)) * axis
	a1.Parent = box
	local joint = Instance.new("BallSocketConstraint")
	joint.Name = "HitchJoint"
	joint.Attachment0 = a0
	joint.Attachment1 = a1
	joint.LimitsEnabled = true
	joint.UpperAngle = spec.swing
	joint.TwistLimitsEnabled = true
	joint.TwistLowerAngle = -spec.twist
	joint.TwistUpperAngle = spec.twist
	joint.Parent = chassis

	local axle = Instance.new("Attachment")
	axle.Name = "Axle"
	axle.CFrame = box.CFrame:ToObjectSpace(CFrame.new(0, box.Position.Y, axleZ))
	axle.Parent = box
	local grip = Instance.new("LinearVelocity")
	grip.Name = "SideGrip"
	grip.Attachment0 = axle
	grip.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	grip.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	grip.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	grip.VectorVelocity = Vector3.zero
	grip.Parent = box

	trailer.Parent = model
	local mass = 0
	for _, p in trailer:GetDescendants() do
		if p:IsA("BasePart") and not p.Massless then
			mass += p:GetMass()
		end
	end
	grip.MaxAxesForce = Vector3.new(mass * spec.sideGrip * Vehicles.StudsPerMetre, 0, 0)
end

-- crawler tracks: rollers spin on the chassis; one TrackShoe template is copied round each side's loop (front
-- idler Wheel_FL1/FR1 to rear sprocket Wheel_RL1/RR1), each copy on a weld the client slides along the loop
local function buildTracks(model: Model, chassis: BasePart)
	for _, p in model:GetChildren() do
		local side = string.match(p.Name, "^Roller([LR])%d+$")
		if side and p:IsA("BasePart") then
			local rw = weld(p.Name .. "Weld", chassis, p)
			rw:SetAttribute("Track", side)
			rw:SetAttribute("Roller", true)
		end
	end
	local shoe = model:FindFirstChild("TrackShoe") :: BasePart?
	if not shoe then
		return
	end
	shoe.Parent = nil
	for _, side in { "L", "R" } do
		local idler = model:FindFirstChild("Wheel_F" .. side .. "1") :: BasePart?
		local sprocket = model:FindFirstChild("Wheel_R" .. side .. "1") :: BasePart?
		if idler and sprocket then
			-- the loop in the chassis's frame (it isn't turned at build time), as the shoe welds' C0 are
			local base = chassis.Position
			local x, y = idler.Position.X - base.X, idler.Position.Y - base.Y
			local loop: Tracks.Loop = {
				y = y,
				front = idler.Position.Z - base.Z,
				back = sprocket.Position.Z - base.Z,
				radius = idler.Size.Y / 2 + shoe.Size.Y / 2,
			}
			local count = Tracks.count(loop, Cockpit.shoePitch)
			local length = Tracks.length(loop)
			for i = 0, count - 1 do
				local copy = shoe:Clone()
				copy.Name = "Shoe" .. side .. i
				local py, pz, angle = Tracks.at(loop, i * length / count)
				copy.CFrame = CFrame.new(base + Vector3.new(x, py, pz)) * CFrame.Angles(angle, 0, 0)
				copy.Parent = model
				local sw = weld(copy.Name .. "Weld", chassis, copy)
				sw:SetAttribute("Track", side)
				sw:SetAttribute("Shoe", i)
				sw:SetAttribute("Shoes", count)
				sw:SetAttribute("LoopX", x)
				sw:SetAttribute("LoopY", y)
				sw:SetAttribute("LoopFront", loop.front)
				sw:SetAttribute("LoopBack", loop.back)
				sw:SetAttribute("LoopRadius", loop.radius)
			end
		end
	end
	shoe:Destroy()
end

-- colour a vehicle's painted panels (0-255 sRGB); everyone sees it, as the server sets it
function VehicleBuilder.paint(model: Model, rgb: { number }?)
	local part = model:FindFirstChild("Paint")
	if rgb and part and part:IsA("BasePart") then
		part.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	end
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
	local track = 0 -- half the width across the outside of the tyres
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and string.sub(p.Name, 1, 6) == "Wheel_" then
			table.insert(wheels, p)
			wheelRadius = math.max(wheelRadius, p.Size.Y / 2)
			track = math.max(track, math.abs(p.Position.X - cf.Position.X) + p.Size.X / 2)
		end
	end

	-- the chassis: a box up to about the bumpers, a little inside the body's outline but at least as wide
	-- as the tyres (so they can't push into walls), riding on four invisible balls at its corners so kerbs
	-- and ramp lips roll under instead of stopping it dead
	local skid = math.clamp(wheelRadius * 0.8, 0.8, 2)
	local lift = skid * 0.7
	local chassisHeight = math.clamp(body.Size.Y * 0.35, 1.6, 5)
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size =
		Vector3.new(math.max(width * 0.82, track * 2, 3), chassisHeight, math.max(length * 0.86, 4))
	chassis.CFrame = CFrame.new(0, lift + chassisHeight / 2, cf.Position.Z)
	chassis.Transparency = 1
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 1)
	chassis.CollisionGroup = "Vehicles"
	chassis.Parent = model
	model.PrimaryPart = chassis
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			skidBall(
				model,
				chassis,
				Vector3.new(
					sx * (chassis.Size.X / 2 - skid),
					skid,
					cf.Position.Z + sz * (chassis.Size.Z / 2 - skid)
				),
				skid
			)
		end
	end

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
	-- the painted panels: their own untextured part, so the server can recolour them (Config/Paints)
	local paint = model:FindFirstChild("Paint") :: BasePart?
	if paint then
		weld("PaintWeld", sprung, paint)
	end
	-- the cabin rides on the suspension with the body: see-through glass, seats and dash, and a steering
	-- wheel the client turns (its weld is tagged Steer; the driver's hands reach for its Grip attachments)
	local glass = model:FindFirstChild("Glass") :: BasePart?
	if glass then
		glass.Transparency = GLASS_SEE_THROUGH
		glass.CastShadow = false
		weld("GlassWeld", sprung, glass)
	end
	local interior = model:FindFirstChild("Interior") :: BasePart?
	if interior then
		weld("InteriorWeld", sprung, interior)
	end
	local mirror = model:FindFirstChild("Mirror") :: BasePart?
	if mirror then
		mirror.Reflectance = MIRROR_SHINE
		mirror.CastShadow = false
		weld("MirrorWeld", sprung, mirror)
	end
	-- the steering wheel (or handlebars) is modelled upright and leaned back by its weld, about its middle or
	-- the SteerPivot marker; hands go on the GripL/GripR markers (given in its leaned pose) or the rim's sides
	local gripL, gripR = takeMark(model, "GripL"), takeMark(model, "GripR")
	local steerPivot = takeMark(model, "SteerPivot")
	local steerPart = model:FindFirstChild("Steer") :: BasePart?
	if steerPart then
		local tilt = math.rad(stats.steerTilt or STEER_TILT)
		local pivot = steerPivot or steerPart.Position
		local sw = pivotWeld("SteerWeld", sprung, steerPart, pivot, CFrame.Angles(-tilt, 0, 0))
		sw:SetAttribute("Steer", true)
		local unlean = CFrame.new(pivot) * CFrame.Angles(tilt, 0, 0) * CFrame.new(-pivot)
		if gripL and gripR then
			addGrip(steerPart, "GripL", unlean * gripL)
			addGrip(steerPart, "GripR", unlean * gripR)
		else
			local reach = steerPart.Size.X * 0.45
			addGrip(steerPart, "GripL", steerPart.CFrame * Vector3.new(-reach, 0, 0))
			addGrip(steerPart, "GripR", steerPart.CFrame * Vector3.new(reach, 0, 0))
		end
	end
	-- gauge needles are modelled upright and pointing up; their welds lean them onto the dials (the client
	-- swings them about their Z)
	for _, kind in { "Speed", "Rev" } do
		local needle = model:FindFirstChild("Needle" .. kind) :: BasePart?
		if needle then
			local nw = pivotWeld(
				"Needle" .. kind .. "Weld",
				sprung,
				needle,
				needle.Position,
				CFrame.Angles(-math.rad(Cockpit.gaugeTilt), 0, 0)
			)
			nw:SetAttribute("Needle", kind)
		end
	end
	-- joysticks lean about their pivots; the left one drives, the right one works the blade
	for _, side in { "L", "R" } do
		local stick = model:FindFirstChild("Stick" .. side) :: BasePart?
		local pivot = takeMark(model, "Stick" .. side .. "Pivot")
		if stick then
			local kw = pivotWeld(
				"Stick" .. side .. "Weld",
				sprung,
				stick,
				pivot or stick.Position,
				CFrame.identity
			)
			kw:SetAttribute("Stick", side)
			local hand = if side == "L" then gripL else gripR
			if hand and not steerPart then
				addGrip(stick, "Grip" .. side, hand)
			end
		end
	end

	for _, w in wheels do
		local corner = string.sub(w.Name, 7, 8)
		local wl = weld("Wheel_" .. string.sub(w.Name, 7), chassis, w)
		wl:SetAttribute("Corner", corner)
		wl:SetAttribute("Spin", true)
		if stats.tracks then
			-- idlers and sprockets: no steering, no bobbing, spun by their own track
			wl:SetAttribute("Track", string.sub(corner, 2, 2))
		end
	end
	if stats.tracks then
		buildTracks(model, chassis)
	end

	local seatPos = stats.seat
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.CFrame = CFrame.new(seatPos[1], seatPos[2], seatPos[3])
	if model:FindFirstChild("Interior") then
		-- a thin seat with its top flush with the cabin cushion, so the driver sits in it rather than on top
		seat.Size = Vector3.new(2, 0.2, 2)
		seat.CFrame = CFrame.new(seatPos[1], seatPos[2] + 0.075, seatPos[3])
	end
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

	local sounds = table.clone(SOUNDS)
	local engine = Vehicles.Engines[stats.engine]
	sounds.Motor = engine.sound
	for name, sid in sounds do
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = sid
		s.Looped = true
		s.Volume = 0
		s.RollOffMinDistance = 15
		s.RollOffMaxDistance = 250
		if name == "Motor" and engine.loop then
			s.PlaybackRegionsEnabled = true
			s.PlaybackRegion = NumberRange.new(engine.loop[1], engine.loop[2])
			s.LoopRegion = s.PlaybackRegion
		end
		s.Parent = chassis
	end
	-- one-shots made once here so they play on time: the horn (each client plays it) and the jingle (server)
	local hornDef = Vehicles.Horns[stats.horn]
	local horn = Instance.new("Sound")
	horn.Name = "Horn"
	horn.SoundId = hornDef.sound
	horn.Volume = hornDef.volume
	horn.PlaybackSpeed = stats.hornPitch or 1
	horn.RollOffMinDistance = 25
	horn.RollOffMaxDistance = 400
	horn.Parent = chassis
	if Vehicles.has(stats, "Jingle") then
		local jingle = Instance.new("Sound")
		jingle.Name = "Jingle"
		jingle.SoundId = Vehicles.Jingle.sound
		jingle.Volume = Vehicles.Jingle.volume
		jingle.Looped = true
		jingle.RollOffMinDistance = 30
		jingle.RollOffMaxDistance = 300
		jingle.Parent = chassis
	end

	if stats.trailer then
		buildTrailer(model, chassis, stats.trailer)
	end

	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CollisionGroup = "Vehicles"
			if p ~= chassis and p.Name ~= "Skid" and p.Name ~= "TrailerChassis" then
				p.CanCollide = false
			end
		end
	end

	model:SetAttribute("VehicleId", id)
	model:SetAttribute("StudsPerMetre", Vehicles.StudsPerMetre)
	model:SetAttribute("WheelRadius", math.max(wheelRadius, 0.5))
	-- clients wait until they have this many wheel welds before they start driving it
	local wheelCount = 0
	for _, w in model:GetDescendants() do
		if w:IsA("Weld") and w:GetAttribute("Corner") then
			wheelCount += 1
		end
	end
	model:SetAttribute("Wheels", wheelCount)
	-- and this many track link plates
	local shoeCount = 0
	for _, w in chassis:GetChildren() do
		if w:IsA("Weld") and w:GetAttribute("Shoe") then
			shoeCount += 1
		end
	end
	model:SetAttribute("Shoes", shoeCount)
	model:SetAttribute("Length", length)
	model.WorldPivot = CFrame.new()
	CollectionService:AddTag(model, "Vehicle")
	return model
end

return VehicleBuilder
