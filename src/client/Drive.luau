--!strict
-- Driving for whoever sits in a tagged Vehicle's seat (the driver's client owns the physics), plus the
-- visuals every client runs for every vehicle: wheel spin and steer, suspension, skid marks and sound.
-- Tyres are a bicycle model with a Pacejka-style curve; each vehicle's numbers come from Config/Vehicles.
-- Also: Roadster hover flight (Config/Flight, Rules/Flight), thruster, hit detection (NPCs, buildings, Wrecker), features,
-- self-destruct, and flings sent by the server. The cabin moves too: steering wheel, gauge needles, joysticks, the
-- driver's hands, and the bulldozer's crawler tracks (Rules/Tracks), which also let it turn on the spot.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cockpit = require(ReplicatedStorage.Shared.Config.Cockpit)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Flight = require(ReplicatedStorage.Shared.Config.Flight)
local FlightRules = require(ReplicatedStorage.Shared.Rules.Flight)
local Ground = require(ReplicatedStorage.Shared.Ground)
local Impact = require(ReplicatedStorage.Shared.Rules.Impact)
local Net = require(ReplicatedStorage.Shared.Net)
local Smash = require(ReplicatedStorage.Shared.Config.Smash)
local Tracks = require(ReplicatedStorage.Shared.Rules.Tracks)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)

local player = Players.LocalPlayer

local Drive = {}

-- shared with the HUD
Drive.state = {
	driving = false,
	vehicleId = "",
	speedMph = 0,
	reverse = false,
	airborne = false,
	boost = 100, -- Roadster flight meter, 0-100
	thruster = 1, -- 0 = just used, 1 = ready
	bombHold = 0, -- 0-1 while holding self-destruct
}
-- the first-person view (src/client/Cockpit) says when it's on; the car being driven, for it to follow
Drive.view = {
	firstPerson = false,
	car = nil :: Model?,
	steer = 0, -- road-wheel angle, radians, positive left
	accel = Vector3.zero, -- felt acceleration in the car's frame, m/s^2
}
-- held inputs; keyboard and gamepad set them here, and so do the phone buttons
Drive.input = {
	boost = false,
	thrust = false, -- Roadster rear jet, held
	roll = 0,
	feature = false,
	bomb = false,
}

local REGEN = 2.2
local BRAKE = 11.5
local REVERSE_TOP = 6.7
local REVERSE_ACCEL = 4
local DRAG = 1.9e-4
local ROLLING = 0.12
local STEER_RATE = math.rad(110)
local MPH = 2.237
local LEVEL_RATE = 6
local G = 9.81
local FRONT_SHARE = 0.45
local CG_HEIGHT = 0.42
local TYRE_B, TYRE_C = 14, 1.5
local PEAK_SLIP = math.rad(7)
local FRONT_GRIP = 0.96
local FRONT_DRIVE, FRONT_BRAKE = 0.4, 0.7
local KINEMATIC_SPEED = 2.5
local ESC_SLACK, ESC_GAIN = 0.1, 9
local ESC_DRIFT_SLACK, ESC_DRIFT_GAIN = 0.08, 12
-- thruster, the drive constraint's force (no vertical hold on the ground, full hold in flight)
local THRUST_DV, THRUST_TIME, THRUST_COOLDOWN = 25, 0.6, 12
local BIG = 1e8
local GROUND_FORCE = Vector3.new(BIG, 0, BIG)
-- per-tyre ground contact: how far a tyre can ride up and hang down (shares of its radius), and from how
-- far away other cars bother
local WHEEL_TRAVEL, WHEEL_DROOP = 0.6, 0.3
local WHEEL_CONTACT_RANGE = 300
local STEER_WHEEL_RATIO = 4 -- steering wheel turns per road-wheel turn
local wheelParams = RaycastParams.new()
wheelParams.FilterType = Enum.RaycastFilterType.Exclude
wheelParams.CollisionGroup = "Vehicles"
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.CollisionGroup = "Vehicles"
-- cold-gas thruster sounds (Pro Sound Effects, see ASSETS_LICENSES.md): a steady stretch of an air
-- release for the big jets, a short spray burst when a steering nozzle opens
local GAS_LOOP, GAS_LOOP_REGION = "rbxassetid://9116496074", NumberRange.new(1, 3.1)
local GAS_BURST = "rbxassetid://9113046025"
local FLY_FORCE = Vector3.new(BIG, BIG, BIG)
local BOMB_HOLD = 1.5
-- suspension
local ROLL_PER_G = 1.8
local SQUAT_PER_G = 1.1
local DIVE_PER_G = 1.7
local HEAVE_PER_G = 0.035
local RIDE_HZ = 1.7
local RIDE_DAMPING = 0.42

type Surface = { grip: number, rough: number, squeal: boolean, mark: Color3 }
local RUBBER = Color3.fromRGB(20, 20, 22)
local HARD: Surface = { grip = 1, rough = 1, squeal = true, mark = RUBBER }
local SURFACES: { [Enum.Material]: Surface } = {
	[Enum.Material.Grass] = {
		grip = 0.6,
		rough = 4,
		squeal = false,
		mark = Color3.fromRGB(70, 52, 34),
	},
	[Enum.Material.Ground] = {
		grip = 0.6,
		rough = 3.5,
		squeal = false,
		mark = Color3.fromRGB(70, 52, 34),
	},
	[Enum.Material.Sand] = {
		grip = 0.5,
		rough = 3,
		squeal = false,
		mark = Color3.fromRGB(150, 125, 85),
	},
	[Enum.Material.Ice] = {
		grip = 0.12,
		rough = 0.3,
		squeal = false,
		mark = Color3.fromRGB(200, 215, 230),
	},
	[Enum.Material.Wood] = { grip = 0.8, rough = 1.5, squeal = true, mark = RUBBER },
}

-- lift: how far the tyre sits above (+) or below (-) its rest spot, in studs, so it rides on kerbs and
-- ramps instead of sinking into them, and hangs down a little in the air
-- track: "L"/"R" for a crawler's idlers and sprockets (no steering or bobbing, spun by their own track)
type Wheel = {
	weld: Weld,
	base: CFrame,
	front: boolean,
	spin: boolean,
	radius: number,
	lift: number,
	track: string?,
}
-- cabin parts the client moves: gauge needles, joysticks, track rollers and link plates
type Needle = { weld: Weld, base: CFrame, kind: string, at: number }
type Stick = { weld: Weld, base: CFrame, side: string, fwd: number, sway: number }
type Roller = { weld: Weld, base: CFrame, side: string, radius: number }
type Shoe = { weld: Weld, side: string, offset: number, x: number, loop: Tracks.Loop }
type CarState = {
	car: Model,
	stats: Vehicles.Vehicle,
	chassis: BasePart,
	wheels: { Wheel },
	spin: number,
	steer: number,
	radius: number,
	wheelbase: number,
	height: number,
	motor: Sound?,
	road: Sound?,
	wind: Sound?,
	squeal: Sound?,
	lastSpeed: number,
	load: number,
	suspension: Weld?,
	pivot: CFrame,
	roll: number,
	rollV: number,
	pitch: number,
	pitchV: number,
	heave: number,
	heaveV: number,
	lastVel: Vector3,
	accel: Vector3,
	travelled: number,
	surface: Surface,
	surfaceAt: number,
	groundUp: Vector3, -- the smoothed road normal the body tilts to (see Shared/Ground)
	probedAt: number, -- when the driver's corner probes last touched ground
	airborne: boolean,
	frontSlide: number,
	rearSlide: number,
	marks: { { trail: Trail, front: boolean } },
	thrusters: { [string]: { ParticleEmitter } }, -- Roadster gas nozzles by job (see Thrusters below)
	jetSounds: { [string]: Sound }, -- Roadster: Lift, Rear and Puff loops, Burst one-shot
	puffing: boolean,
	dust: ParticleEmitter,
	fall: number, -- fastest m/s down during the current time in the air
	engine: Vehicles.Engine,
	tone: number,
	seat: VehicleSeat?,
	trailer: BasePart?,
	steerWeld: Weld?, -- the cabin steering wheel's weld (cars with an interior)
	steerBase: CFrame,
	ik: { IKControl }, -- the driver's hands on that wheel
	ikFor: Humanoid?,
	needles: { Needle },
	sticks: { Stick },
	rollers: { Roller },
	shoes: { Shoe },
	trackHalf: number, -- studs from the middle to each track
	trackMove: { [string]: number }, -- how far each track's plates have moved round the loop, studs
	trackSpin: { [string]: number }, -- studs each side has rolled (a wheel turns this over its radius)
	throttle: number, -- -1..1, what the joysticks show
	steerIn: number, -- -1..1 (right)
}

local cars: { [Model]: CarState } = {}
local camera = workspace.CurrentCamera
local baseFov = camera.FieldOfView

local function track(car: Instance)
	if not car:IsA("Model") or cars[car] then
		return
	end
	local id = car:GetAttribute("VehicleId")
	local stats = if typeof(id) == "string" then Vehicles.ById[id] else nil
	if not stats then
		return
	end
	if not car.PrimaryPart then
		car:GetPropertyChangedSignal("PrimaryPart"):Once(function()
			track(car)
		end)
		return
	end
	local chassis = car.PrimaryPart
	local wheels: { Wheel } = {}
	local frontZ, rearZ = 0, 0
	local suspension: Weld? = nil
	local radius = (car:GetAttribute("WheelRadius") or 1) :: number
	local spm = Vehicles.StudsPerMetre
	local marks = {}
	-- the trailer's wheels spin and leave marks too, but don't count towards the tractor's wheelbase
	local trailerModel = car:FindFirstChild("Trailer")
	local trailer = if trailerModel and trailerModel:IsA("Model")
		then trailerModel.PrimaryPart
		else nil
	if stats.trailer and not trailer then
		-- a big rig can replicate in pieces: wait for the trailer, or its hits and wheels are never tracked
		task.delay(0.2, function()
			if car.Parent then
				track(car)
			end
		end)
		return
	end
	local welds = chassis:GetChildren()
	if trailer then
		local more = trailer:GetChildren()
		table.move(more, 1, #more, #welds + 1, welds)
	end
	-- the wheel welds can land a moment after the car: wait for all of them, or the wheelbase comes out
	-- near zero and any steering at speed spins the car on the spot
	local found = 0
	for _, w in welds do
		if
			w:IsA("Weld")
			and typeof(w:GetAttribute("Corner")) == "string"
			and w.Part0
			and w.Part1
		then
			found += 1
		end
	end
	if found < ((car:GetAttribute("Wheels") or 0) :: number) then
		task.delay(0.2, function()
			if car.Parent then
				track(car)
			end
		end)
		return
	end
	for _, w in welds do
		local c = w:GetAttribute("Corner")
		if w:IsA("Weld") and typeof(c) == "string" and w.Part0 then
			local front = string.sub(c, 1, 1) == "F"
			local onTrailer = w.Part0 ~= chassis
			local side = w:GetAttribute("Track")
			table.insert(wheels, {
				weld = w,
				base = w.C0,
				front = front,
				spin = w:GetAttribute("Spin") == true,
				radius = if w.Part1 then w.Part1.Size.Y / 2 else 1,
				lift = 0,
				track = if typeof(side) == "string" then side else nil,
			})
			if front then
				frontZ = math.min(frontZ, w.C0.Position.Z)
			elseif not onTrailer then
				rearZ = math.max(rearZ, w.C0.Position.Z)
			end
			local tyre = w.Part1
			if tyre then
				local contact = w.C0.Position - Vector3.new(0, tyre.Size.Y / 2 - 0.08, 0)
				local half = Vector3.new(math.min(tyre.Size.X, 2) * 0.4, 0, 0)
				local a0 = Instance.new("Attachment")
				a0.Position = contact - half
				a0.Parent = w.Part0
				local a1 = Instance.new("Attachment")
				a1.Position = contact + half
				a1.Parent = w.Part0
				local trail = Instance.new("Trail")
				trail.Attachment0 = a0
				trail.Attachment1 = a1
				trail.FaceCamera = false
				trail.Lifetime = 10
				trail.MinLength = 0.3
				trail.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.35),
					NumberSequenceKeypoint.new(0.8, 0.5),
					NumberSequenceKeypoint.new(1, 1),
				})
				trail.Enabled = false
				trail.Parent = chassis
				table.insert(marks, { trail = trail, front = front })
			end
		elseif w:IsA("Weld") and w:GetAttribute("Suspension") then
			suspension = w
		end
	end
	-- the cabin's moving parts hang off the sprung body; rollers and link plates off the chassis
	local needles, sticks, rollers, shoes = {}, {}, {}, {}
	local trackHalf = 0
	local sprung = car:FindFirstChild("Sprung")
	local more = if sprung then sprung:GetChildren() else {}
	table.move(welds, 1, #welds, #more + 1, more)
	for _, w in more do
		if not w:IsA("Weld") then
			continue
		end
		local side = w:GetAttribute("Track")
		local needle, stick = w:GetAttribute("Needle"), w:GetAttribute("Stick")
		if typeof(needle) == "string" then
			table.insert(needles, { weld = w, base = w.C0, kind = needle, at = 0 })
		elseif typeof(stick) == "string" then
			table.insert(sticks, { weld = w, base = w.C0, side = stick, fwd = 0, sway = 0 })
		elseif typeof(side) == "string" and w:GetAttribute("Roller") then
			table.insert(rollers, {
				weld = w,
				base = w.C0,
				side = side,
				radius = if w.Part1 then w.Part1.Size.Y / 2 else 1,
			})
		elseif typeof(side) == "string" and w:GetAttribute("Shoe") then
			local count = (w:GetAttribute("Shoes") or 1) :: number
			local loop: Tracks.Loop = {
				y = (w:GetAttribute("LoopY") or 0) :: number,
				front = (w:GetAttribute("LoopFront") or 0) :: number,
				back = (w:GetAttribute("LoopBack") or 1) :: number,
				radius = (w:GetAttribute("LoopRadius") or 1) :: number,
			}
			local x = (w:GetAttribute("LoopX") or 0) :: number
			trackHalf = math.max(trackHalf, math.abs(x))
			table.insert(shoes, {
				weld = w,
				side = side,
				offset = (w:GetAttribute("Shoe") :: number) * Tracks.length(loop) / count,
				x = x,
				loop = loop,
			})
		end
	end
	if #shoes < ((car:GetAttribute("Shoes") or 0) :: number) then
		task.delay(0.2, function()
			if car.Parent then
				track(car)
			end
		end)
		return
	end
	local _, size = car:GetBoundingBox()
	-- cold-gas nozzles on the Roadster, by job: Lift (four under the floor), Rear (four across the tail),
	-- Nose (two in the nose, S in the air), YawL/YawR (side pairs, front on one side and back on the other) and
	-- RollL/RollR (one up on one flank, one down on the other)
	local function gas(at: Vector3, face: Enum.NormalId, puff: number): ParticleEmitter
		local a = Instance.new("Attachment")
		a.Position = at
		a.Parent = chassis
		local p = Instance.new("ParticleEmitter")
		p.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 212, 222))
		p.LightEmission = 0.15
		p.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, puff * 0.4),
			NumberSequenceKeypoint.new(1, puff * 2.2),
		})
		p.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		p.Lifetime = NumberRange.new(0.25, 0.4)
		p.Speed = NumberRange.new(30, 45)
		p.Drag = 5
		p.SpreadAngle = Vector2.new(8, 8)
		p.EmissionDirection = face
		p.Rate = 50
		p.Enabled = false
		p.Parent = a
		return p
	end
	local thrusters: { [string]: { ParticleEmitter } } = {}
	local jetSounds: { [string]: Sound } = {}
	if Vehicles.has(stats, "Jet") then
		local X, Y, Z = chassis.Size.X, chassis.Size.Y, chassis.Size.Z
		local N = Enum.NormalId
		thrusters.Lift = {}
		for _, x in { -X * 0.32, X * 0.32 } do
			for _, z in { -Z * 0.32, Z * 0.32 } do
				table.insert(thrusters.Lift, gas(Vector3.new(x, -Y / 2, z), N.Bottom, 1.2))
			end
		end
		thrusters.Rear = {}
		for _, x in { -0.36, -0.12, 0.12, 0.36 } do
			table.insert(thrusters.Rear, gas(Vector3.new(x * X, 0, Z / 2 + 0.3), N.Back, 0.8))
		end
		thrusters.Nose = {
			gas(Vector3.new(-X * 0.3, 0, -Z / 2 - 0.3), N.Front, 1.1),
			gas(Vector3.new(X * 0.3, 0, -Z / 2 - 0.3), N.Front, 1.1),
		}
		local side, fore = X / 2 + 0.2, Z * 0.36
		-- turning right: the front blows out to the left and the back out to the right
		thrusters.YawR = {
			gas(Vector3.new(-side, 0, -fore), N.Left, 0.9),
			gas(Vector3.new(side, 0, fore), N.Right, 0.9),
		}
		thrusters.YawL = {
			gas(Vector3.new(side, 0, -fore), N.Right, 0.9),
			gas(Vector3.new(-side, 0, fore), N.Left, 0.9),
		}
		-- rolling right: the left flank blows down and the right flank blows up
		thrusters.RollR = {
			gas(Vector3.new(-side, -Y / 2, 0), N.Bottom, 0.9),
			gas(Vector3.new(side, Y / 2, 0), N.Top, 0.9),
		}
		thrusters.RollL = {
			gas(Vector3.new(side, -Y / 2, 0), N.Bottom, 0.9),
			gas(Vector3.new(-side, Y / 2, 0), N.Top, 0.9),
		}
		for name, pitch in { Lift = 0.85, Rear = 1.15, Puff = 1.6 } do
			local snd = Instance.new("Sound")
			snd.Name = name .. "Jet"
			snd.SoundId = GAS_LOOP
			snd.PlaybackRegionsEnabled = true
			snd.PlaybackRegion = GAS_LOOP_REGION
			snd.LoopRegion = GAS_LOOP_REGION
			snd.Looped = true
			snd.PlaybackSpeed = pitch
			snd.Volume = 0
			snd.RollOffMinDistance = 15
			snd.RollOffMaxDistance = 250
			snd.Parent = chassis
			snd:Play()
			jetSounds[name] = snd
		end
		local burst = Instance.new("Sound")
		burst.Name = "GasBurst"
		burst.SoundId = GAS_BURST
		burst.Volume = 0.7
		burst.RollOffMinDistance = 15
		burst.RollOffMaxDistance = 200
		burst.Parent = chassis
		jetSounds.Burst = burst
	end
	-- a puff of dust when it lands hard
	local dustAt = Instance.new("Attachment")
	dustAt.Position = Vector3.new(0, -chassis.Size.Y / 2, 0)
	dustAt.Parent = chassis
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(Color3.fromRGB(200, 190, 170))
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 7),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime = NumberRange.new(0.6, 1)
	dust.Speed = NumberRange.new(10, 18)
	dust.Drag = 3
	dust.SpreadAngle = Vector2.new(80, 80)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Rate = 0
	dust.Parent = dustAt
	local function loop(name: string): Sound?
		local s = chassis:FindFirstChild(name)
		if s and s:IsA("Sound") then
			s.Volume = 0
			s:Play()
			return s
		end
		return nil
	end
	cars[car] = {
		car = car,
		stats = stats,
		chassis = chassis,
		wheels = wheels,
		spin = 0,
		steer = 0,
		radius = radius,
		wheelbase = math.max(1, math.abs(rearZ - frontZ)),
		height = size.Y,
		motor = loop("Motor"),
		road = loop("Road"),
		wind = loop("Wind"),
		squeal = loop("Squeal"),
		lastSpeed = 0,
		load = 0,
		suspension = suspension,
		pivot = CFrame.new(0, -chassis.Size.Y / 2 + 0.12 * spm, (frontZ + rearZ) / 2),
		roll = 0,
		rollV = 0,
		pitch = 0,
		pitchV = 0,
		heave = 0,
		heaveV = 0,
		lastVel = chassis.AssemblyLinearVelocity,
		accel = Vector3.zero,
		travelled = 0,
		surface = HARD,
		surfaceAt = 0,
		groundUp = Vector3.yAxis,
		probedAt = 0,
		airborne = false,
		frontSlide = 0,
		rearSlide = 0,
		marks = marks,
		thrusters = thrusters,
		jetSounds = jetSounds,
		puffing = false,
		dust = dust,
		fall = 0,
		engine = Vehicles.Engines[stats.engine],
		tone = stats.engineTone or 1,
		seat = car:FindFirstChild("DriverSeat") :: VehicleSeat?,
		trailer = trailer,
		steerWeld = nil,
		steerBase = CFrame.identity,
		ik = {},
		ikFor = nil,
		needles = needles,
		sticks = sticks,
		rollers = rollers,
		shoes = shoes,
		trackHalf = trackHalf,
		trackMove = { L = 0, R = 0 },
		trackSpin = { L = 0, R = 0 },
		throttle = 0,
		steerIn = 0,
	}
end

local speed = 0 -- m/s along the nose
local lateral = 0 -- m/s sideways, positive left
local yawRate = 0
local steer = 0
local escActive = false
local driving: CarState? = nil
local thrustLeft = 0
local thrustReadyAt = 0
local boostUsedAt = 0
local flingUntil = 0
local stuckFor = 0
local flying = false -- Roadster in the air under flight control
local jetOn = false -- its jet is lifting it right now
local rearOn = false -- its rear jet is pushing it along the nose right now
local reversing = false -- its nose jets are pushing it backwards in the air right now
local liftedAt = 0
local flyYaw = 0
local bombHeld = 0
local pivotSpin = 0 -- crawler: rad/s of on-the-spot turn being asked for
local savedZoom = { min = player.CameraMinZoomDistance, max = player.CameraMaxZoomDistance }

local function stopDriving()
	if driving then
		local drive = driving.chassis:FindFirstChild("Drive") :: LinearVelocity?
		local turn = driving.chassis:FindFirstChild("Turn") :: AngularVelocity?
		if drive and turn then
			drive.VectorVelocity = Vector3.zero
			turn.AngularVelocity = Vector3.zero
			drive.Enabled = true
			turn.Enabled = true
			drive.MaxAxesForce = GROUND_FORCE
		end
	end
	driving = nil
	flying, jetOn, rearOn, reversing = false, false, false, false
	speed, lateral, yawRate, steer, pivotSpin = 0, 0, 0, 0, 0
	Drive.state.driving = false
	Drive.view.car = nil
	camera.FieldOfView = baseFov
	player.CameraMinZoomDistance = savedZoom.min
	player.CameraMaxZoomDistance = savedZoom.max
end

local function tyreForce(slip: number, capacity: number): number
	return -capacity * math.sin(TYRE_C * math.atan(TYRE_B * slip))
end

local function stepTyres(
	h: number,
	a: number,
	wheelbase: number,
	grip: number,
	rearGrip: number
): (number, number)
	local toFront = (1 - FRONT_SHARE) * wheelbase
	local toRear = FRONT_SHARE * wheelbase
	local loadF = math.max(0, G * toRear - a * CG_HEIGHT) / (G * wheelbase)
	local loadR = math.max(0, G * toFront + a * CG_HEIGHT) / (G * wheelbase)
	local split = if a > 0 then FRONT_DRIVE else FRONT_BRAKE
	local fx, rx = a * split, a * (1 - split)
	local capF = math.sqrt(math.max(0, (grip * loadF * FRONT_GRIP) ^ 2 - fx * fx))
	local capR = math.sqrt(math.max(0, (grip * loadR * rearGrip) ^ 2 - rx * rx))

	local cosS, sinS = math.cos(steer), math.sin(steer)
	local fy = lateral + toFront * yawRate
	local alphaF =
		math.atan2(-speed * sinS + fy * cosS, math.max(math.abs(speed * cosS + fy * sinS), 0.5))
	local alphaR = math.atan2(lateral - toRear * yawRate, math.max(math.abs(speed), 0.5))
	local forceF = tyreForce(alphaF, capF)
	local forceR = tyreForce(alphaR, capR)

	local yawAccel = (toFront * forceF * cosS - toRear * forceR) / (toFront * toRear)
	escActive = false
	local v = math.abs(speed)
	if v > 5 then
		local limit = grip / v
		local wanted = math.clamp(speed * math.tan(steer) / wheelbase, -limit, limit)
		local over = if math.sign(yawRate) == math.sign(wanted)
			then math.abs(yawRate) - math.abs(wanted)
			else math.abs(yawRate)
		if over > ESC_SLACK then
			yawAccel -= math.sign(yawRate) * ESC_GAIN * (over - ESC_SLACK)
			escActive = true
		end
		local drift = math.atan2(lateral, v)
		if math.abs(drift) > ESC_DRIFT_SLACK then
			yawAccel += ESC_DRIFT_GAIN * (drift - math.sign(drift) * ESC_DRIFT_SLACK)
			escActive = true
		end
	end

	speed += (a - forceF * sinS + yawRate * lateral) * h
	lateral += (forceF * cosS + forceR - yawRate * speed) * h
	yawRate += yawAccel * h

	local w = math.clamp((v - KINEMATIC_SPEED) / KINEMATIC_SPEED, 0, 1)
	if w < 1 then
		local rolling = speed * math.tan(steer) / wheelbase
		yawRate = rolling + (yawRate - rolling) * w
		lateral = rolling * toRear + (lateral - rolling * toRear) * w
	end
	return alphaF, alphaR
end

---------------------------------------------------------------- hits

local hitNpcAt: { [Model]: number } = {}
local hitPropAt: { [Model]: number } = {}
local wreckAt: { [Model]: number } = {}
local loosened: { { part: BasePart, at: number } } = {}
local lastBreakSent = 0

local function npcOf(part: BasePart, npcFolder: Instance): Model?
	local node: Instance? = part
	while node and node.Parent ~= npcFolder do
		node = node.Parent
	end
	return if node and node:IsA("Model") then node else nil
end

local function detectHits(s: CarState, velocity: Vector3)
	local spm = Vehicles.StudsPerMetre
	local metres = velocity.Magnitude / spm
	if metres < Economy.MinHitSpeed then
		return
	end
	local npcFolder = workspace:FindFirstChild("Npcs")
	local map = workspace:FindFirstChild("Map")
	local buildings = map and map:FindFirstChild("Buildings")
	local props = map and map:FindFirstChild("Props")
	local vehiclesFolder = workspace:FindFirstChild("Vehicles")
	local wrecker = player:GetAttribute("PassWrecker") == true
	local include: { Instance } = {}
	if npcFolder then
		table.insert(include, npcFolder)
	end
	-- the same rule the server uses: soft hits only bump, light vehicles break a small patch
	local breakRadius = Impact.smashRadius(s.stats.weight, metres, Smash, s.stats.maxBreak)
	if buildings and breakRadius > 0 then
		table.insert(include, buildings)
	end
	if props then
		table.insert(include, props)
	end
	if wrecker then
		if vehiclesFolder then
			table.insert(include, vehiclesFolder)
		end
		for _, other in Players:GetPlayers() do
			if other ~= player and other.Character then
				table.insert(include, other.Character)
			end
		end
	end
	if #include == 0 then
		return
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	local chassis = s.chassis
	-- the vehicle's outline plus a little look-ahead along the way it's going
	local ahead = math.clamp(velocity.Magnitude * 0.12, 1, 40)
	local size = Vector3.new(chassis.Size.X + 2, s.height + 2, chassis.Size.Z + ahead)
	local localVel = chassis.CFrame:VectorToObjectSpace(velocity)
	local shift = if localVel.Z < 0 then -ahead / 2 else ahead / 2
	local box = chassis.CFrame * CFrame.new(0, s.height / 2 - chassis.Size.Y / 2, shift)
	local parts = workspace:GetPartBoundsInBox(box, size, params)
	local trailer = s.trailer
	if trailer and trailer.Parent then
		local tSize = Vector3.new(trailer.Size.X + 2, s.height + 2, trailer.Size.Z + 2)
		local tBox = trailer.CFrame * CFrame.new(0, s.height / 2 - trailer.Size.Y / 2, 0)
		for _, p in workspace:GetPartBoundsInBox(tBox, tSize, params) do
			table.insert(parts, p)
		end
	end
	local now = os.clock()
	local pieces: { BasePart } = {}
	for _, p in parts do
		if npcFolder and p:IsDescendantOf(npcFolder) then
			local npc = npcOf(p, npcFolder)
			if npc and not npc:GetAttribute("Down") and (hitNpcAt[npc] or 0) + 1 < now then
				hitNpcAt[npc] = now
				Net.waitFor("HitNpc"):FireServer(npc, velocity)
			end
		elseif props and p:IsDescendantOf(props) then
			-- street furniture: every vehicle knocks it flying; drive straight through it here at once
			local prop = p:FindFirstAncestorOfClass("Model")
			while prop and prop.Parent ~= props do
				prop = prop:FindFirstAncestorOfClass("Model")
			end
			if prop and (hitPropAt[prop] or 0) + 1.5 < now then
				hitPropAt[prop] = now
				for _, part in prop:GetDescendants() do
					if part:IsA("BasePart") and part.CanCollide then
						part.CanCollide = false
						table.insert(loosened, { part = part, at = now })
					end
				end
				Net.waitFor("KnockProp"):FireServer(prop, velocity)
			end
		elseif buildings and p:IsDescendantOf(buildings) then
			if p.Anchored and p.CanCollide and not p:GetAttribute("Broken") then
				table.insert(pieces, p)
			end
		elseif wrecker then
			local target: Model? = nil
			if vehiclesFolder and p:IsDescendantOf(vehiclesFolder) then
				local m = p:FindFirstAncestorOfClass("Model")
				while m and m.Parent ~= vehiclesFolder do
					m = m:FindFirstAncestorOfClass("Model")
				end
				if m and m ~= s.car then
					target = m
				end
			else
				local m = p:FindFirstAncestorOfClass("Model")
				if m and Players:GetPlayerFromCharacter(m) then
					target = m
				end
			end
			if target and (wreckAt[target] or 0) + 1 < now then
				wreckAt[target] = now
				Net.waitFor("WreckerHit"):FireServer(target, velocity)
				if target.Parent == vehiclesFolder then
					speed *= 0.85 -- like smashing through a wall
				end
			end
		end
	end
	if #pieces > 0 then
		-- the break centres on the piece nearest the car; only the pieces it reaches let the car through
		local at = pieces[1].Position
		for _, p in pieces do
			if (p.Position - chassis.Position).Magnitude < (at - chassis.Position).Magnitude then
				at = p.Position
			end
		end
		for _, p in pieces do
			if (p.Position - at).Magnitude <= breakRadius + p.Size.Magnitude / 2 then
				-- let the car through at once; the server breaks it for everyone
				p.CanCollide = false
				table.insert(loosened, { part = p, at = now })
			end
		end
		if now - lastBreakSent > 0.12 then
			lastBreakSent = now
			Net.waitFor("BreakAt"):FireServer(at, velocity)
			speed *= 0.9
		end
	end
end

---------------------------------------------------------------- input

local function bind()
	ContextActionService:BindAction("RoyfBoost", function(_, state)
		Drive.input.boost = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("RoyfFeature", function(_, state)
		Drive.input.feature = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.G, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("RoyfThruster", function(_, state)
		Drive.input.thrust = state == Enum.UserInputState.Begin
		if state == Enum.UserInputState.Begin then
			Drive.thruster()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("RoyfBomb", function(_, state)
		Drive.input.bomb = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.X, Enum.KeyCode.DPadDown)
	ContextActionService:BindAction("RoyfRoll", function(_, state, input)
		local dir = if input.KeyCode == Enum.KeyCode.Q
				or input.KeyCode == Enum.KeyCode.ButtonL1
			then -1
			else 1
		if state == Enum.UserInputState.Begin then
			Drive.input.roll = dir
		elseif Drive.input.roll == dir then
			Drive.input.roll = 0
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
end

function Drive.thruster()
	-- a one-shot burst; the Roadster's rear jet is held instead (Drive.input.thrust)
	if
		not driving
		or not Vehicles.has(driving.stats, "Thruster")
		or Vehicles.has(driving.stats, "Jet")
	then
		return
	end
	local now = os.clock()
	if now >= thrustReadyAt then
		thrustReadyAt = now + THRUST_COOLDOWN
		thrustLeft = THRUST_TIME
	end
end

---------------------------------------------------------------- flings from the server

local function onFling(kind: string, velocity: Vector3, spinV: Vector3)
	local character = player.Character
	if kind == "Character" then
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root then
			if humanoid.SeatPart then
				humanoid.Sit = false
			end
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			task.defer(function()
				root.AssemblyLinearVelocity = velocity
				root.AssemblyAngularVelocity = spinV
			end)
			task.delay(2.6, function()
				if humanoid.Parent then
					humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
				end
			end)
		end
	elseif kind == "Vehicle" and driving then
		local chassis = driving.chassis
		flingUntil = os.clock() + 1.4
		local drive = chassis:FindFirstChild("Drive") :: LinearVelocity
		local turn = chassis:FindFirstChild("Turn") :: AngularVelocity
		drive.Enabled = false
		turn.Enabled = false
		chassis.AssemblyLinearVelocity += velocity
		chassis.AssemblyAngularVelocity = spinV
	end
end

---------------------------------------------------------------- the loop

local function features(s: CarState, dt: number)
	local now = os.clock()
	-- vehicle feature (G): taxi yell, jingle once per press; the cannon fires while held
	local feature = if Vehicles.has(s.stats, "Taxi")
		then "Taxi"
		elseif Vehicles.has(s.stats, "Jingle") then "Jingle"
		elseif Vehicles.has(s.stats, "Cannon") then "Cannon"
		else nil
	if feature and Drive.input.feature then
		if feature == "Cannon" then
			Net.waitFor("Feature"):FireServer("Cannon")
			local water = s.chassis:FindFirstChild("Water", true) :: ParticleEmitter?
			if not water then
				local a = Instance.new("Attachment")
				a.Position = Vector3.new(0, s.height * 0.6, -s.chassis.Size.Z / 2)
				a.Parent = s.chassis
				local p = Instance.new("ParticleEmitter")
				p.Name = "Water"
				p.Color = ColorSequence.new(Color3.fromRGB(170, 210, 255))
				p.Size = NumberSequence.new(1.2, 3)
				p.Transparency = NumberSequence.new(0.2, 1)
				p.Speed = NumberRange.new(90, 110)
				p.Acceleration = Vector3.new(0, -80, 0)
				p.Lifetime = NumberRange.new(0.6, 0.8)
				p.SpreadAngle = Vector2.new(4, 4)
				p.EmissionDirection = Enum.NormalId.Front
				p.Rate = 160
				p.Parent = a
				water = p
			end
			(water :: ParticleEmitter).Enabled = true
		else
			Net.waitFor("Feature"):FireServer(feature)
			Drive.input.feature = false
		end
	else
		local water = s.chassis:FindFirstChild("Water", true) :: ParticleEmitter?
		if water then
			water.Enabled = false
		end
	end
	-- self-destruct (Wrecker): hold to arm
	if Drive.input.bomb and player:GetAttribute("PassWrecker") == true then
		bombHeld += dt
		if bombHeld >= BOMB_HOLD then
			bombHeld = 0
			Drive.input.bomb = false
			Net.waitFor("SelfDestruct"):FireServer()
		end
	else
		bombHeld = math.max(0, bombHeld - dt * 3)
	end
	Drive.state.bombHold = bombHeld / BOMB_HOLD
	Drive.state.thruster = if Vehicles.has(s.stats, "Thruster")
			and not Vehicles.has(s.stats, "Jet")
		then math.clamp(1 - (thrustReadyAt - now) / THRUST_COOLDOWN, 0, 1)
		else 1
end

local function step(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart

	local state = if seat
			and seat:IsA("VehicleSeat")
			and seat.Parent
		then cars[seat.Parent :: Model]
		else nil
	if state ~= driving then
		stopDriving()
		driving = state
		if state then
			speed = state.chassis.AssemblyLinearVelocity:Dot(state.chassis.CFrame.LookVector)
				/ Vehicles.StudsPerMetre
			Drive.state.driving = true
			Drive.state.vehicleId = state.stats.id
			Drive.state.boost = 100
			local _, size = state.car:GetBoundingBox()
			player.CameraMinZoomDistance = math.clamp(size.Z * 0.9, 12, 60)
			player.CameraMaxZoomDistance = math.max(savedZoom.max, size.Z * 2.5)
		end
	end

	if driving and seat and seat:IsA("VehicleSeat") then
		local s = driving
		local stats = s.stats
		local chassis = s.chassis
		local spm = Vehicles.StudsPerMetre
		local drive = chassis:FindFirstChild("Drive") :: LinearVelocity
		local turn = chassis:FindFirstChild("Turn") :: AngularVelocity
		local now = os.clock()
		local look = chassis.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude > 0.1 then
			look = look.Unit
		end
		local flatLook = look
		local right = Vector3.new(-look.Z, 0, look.X)
		-- the road's up: on the ground the body tilts to it and drives along it; in the air it tracks the
		-- body's own up, so a landing eases from the pose it lands in
		local n
		if not flying then
			groundParams.FilterDescendantsInstances =
				{ s.car, workspace:FindFirstChild("Npcs") :: Instance, character :: Instance }
			n = Ground.normal(chassis, groundParams)
		end
		if n then
			s.probedAt = now
			s.groundUp = (s.groundUp + (n - s.groundUp) * math.min(1, dt * Vehicles.Ground.follow)).Unit
			look = (look - s.groundUp * look:Dot(s.groundUp)).Unit
			right = look:Cross(s.groundUp)
		else
			s.groundUp = chassis.CFrame.UpVector
		end
		local actual = chassis.AssemblyLinearVelocity / spm
		local actualForward, actualLeft = actual:Dot(look), -actual:Dot(right)
		if math.abs(actualForward - speed) > 2 or math.abs(actualLeft - lateral) > 2 then
			speed, lateral = actualForward, actualLeft
		end
		local spinNow = if n
			then chassis.AssemblyAngularVelocity:Dot(s.groundUp)
			else chassis.AssemblyAngularVelocity.Y
		if math.abs(spinNow - yawRate) > 0.6 then
			yawRate = spinNow
		end

		-- flight meter (Roadster): the lift jet and the rear jet burn it, it fills back up on the ground
		local canFly = Vehicles.has(stats, "Jet")
		local lifting = canFly and Drive.input.boost and Drive.state.boost > 0
		local thrusting = canFly and Drive.input.thrust and Drive.state.boost > 0
		if thrusting then
			Drive.state.boost = math.max(0, Drive.state.boost - Flight.thrustDrain * dt)
		end
		if lifting or thrusting then
			boostUsedAt = now
		elseif not flying and now - boostUsedAt > Flight.refillDelay then
			Drive.state.boost = math.min(100, Drive.state.boost + Flight.refill * dt)
		end
		rearOn = thrusting

		local topSpeed = stats.topSpeed / MPH
		if canFly and (thrusting or speed > topSpeed) then
			-- the rear jet takes it past its top speed; let go and it eases back down
			topSpeed = math.max(topSpeed, if thrusting then Flight.thrustTop else speed - 6 * dt)
		end
		local launch = stats.launch
		local power = stats.power

		local grip = stats.grip * s.surface.grip
		local wheelbase = s.wheelbase / spm
		local throttle = seat.ThrottleFloat
		local wanted
		if throttle > 0 then
			wanted = if speed < -0.3
				then BRAKE
				else math.min(launch, power / math.max(speed, 0.1)) * throttle
					- DRAG * speed * speed
					- ROLLING
		elseif throttle < 0 then
			wanted = if speed > 0.3 then -BRAKE else -REVERSE_ACCEL * -throttle
		else
			local regen = REGEN * math.clamp(math.abs(speed) / 3, 0, 1)
			wanted = -math.sign(speed) * (regen + ROLLING + DRAG * speed * speed)
		end
		if escActive then
			wanted *= 0.4
		end
		local longSlide = math.abs(wanted) / grip
		local cornering = math.min(grip, speed * speed * math.abs(math.tan(steer)) / wheelbase)
		local spare = math.sqrt(math.max(0, (grip * 0.98) ^ 2 - cornering * cornering))
		local a = math.clamp(wanted, -math.max(spare, grip * 0.3), math.max(spare, 0.5))
		if thrusting then
			a += Flight.thrust -- the rear jet pushes the car, not the tyres
		end

		local v = math.abs(speed)
		local maxSteer = math.rad(stats.maxSteer)
		local drift = math.atan2(lateral, math.max(v, 1))
		local limit = math.atan(wheelbase * grip / math.max(v * v, 0.01)) + PEAK_SLIP * 0.8
		local target = -seat.SteerFloat
		if target ~= 0 and math.sign(target) == math.sign(lateral) then
			limit += math.abs(drift)
		end
		target *= math.min(maxSteer, limit)
		local rate = STEER_RATE * (if target == 0 or target * steer < 0 then 1.6 else 1)
		steer += math.clamp(target - steer, -rate * dt, rate * dt)

		local flung = now < flingUntil
		if not flung and (not drive.Enabled or not turn.Enabled) then
			drive.Enabled = true
			turn.Enabled = true
			speed, lateral = actualForward, actualLeft
		end

		-- into flight on lift or off a ramp; back to driving once it's down with the jet off
		if canFly and not flung then
			if not flying and (lifting or s.airborne) then
				flying = true
				liftedAt = if lifting then now else 0
				flyYaw = chassis.AssemblyAngularVelocity.Y
			elseif
				flying
				and not s.airborne
				and not lifting
				and now - liftedAt > Flight.minLift
			then
				flying = false
				drive.MaxAxesForce = GROUND_FORCE
				speed, lateral = actualForward, actualLeft
			end
		end
		jetOn = flying and lifting

		-- S in the air fires the nose jets: they push it backwards along the nose, on the flight meter
		reversing = flying and throttle < 0 and Drive.state.boost > 0
		if reversing then
			Drive.state.boost = math.max(0, Drive.state.boost - Flight.thrustDrain * dt)
			boostUsedAt = now
		end

		local alphaF, alphaR = 0, 0
		if flying and not flung then
			local nose = chassis.CFrame.LookVector
			if jetOn then
				-- the jet holds it: climb, and W/S push along the nose; turning swings the nose first and the
				-- sideways drift dies out after it, like a car, instead of the whole path snapping round
				local f = FlightRules.step({
					forward = actualForward,
					side = actualLeft,
					up = actual.Y,
					fuel = Drive.state.boost,
				}, math.max(throttle, 0), true, dt, Flight)
				Drive.state.boost = f.fuel
				local forward = f.forward
				if thrustLeft > 0 then
					forward += THRUST_DV / THRUST_TIME * math.min(dt, thrustLeft)
					thrustLeft -= dt
				end
				local velocity = look * forward - right * f.side + Vector3.yAxis * f.up
				if thrusting then
					-- the rear jet pushes along wherever the nose points, up, down or rolled
					velocity += nose * Flight.thrust * dt
				end
				if reversing then
					velocity -= nose * Flight.thrust * dt
				end
				drive.MaxAxesForce = FLY_FORCE
				drive.Enabled = true
				drive.VectorVelocity = velocity * spm
			else
				-- lift jet off: it drops, carried by its momentum; the rear jet still pushes along the nose
				drive.Enabled = false
				if reversing then
					chassis.AssemblyLinearVelocity -= nose * Flight.thrust * spm * dt
				end
				if thrusting then
					chassis.AssemblyLinearVelocity += nose * Flight.thrust * spm * dt
				end
				if thrustLeft > 0 then
					chassis.AssemblyLinearVelocity += nose * (THRUST_DV / THRUST_TIME) * spm * math.min(
						dt,
						thrustLeft
					)
					thrustLeft -= dt
				end
			end
			-- A/D turn it, harder the faster it's going, so it can't spin on the spot
			local moving =
				math.clamp(Vector3.new(actual.X, 0, actual.Z).Magnitude / Flight.yawSpeed, 0.25, 1)
			local wantYaw = -seat.SteerFloat * Flight.yawRate * moving
			flyYaw += (wantYaw - flyYaw) * math.min(1, dt * Flight.yawRamp)
			-- stay level (lean into turns, nose down speeding up); Q/E roll it for as long as they're held
			local pose = CFrame.lookAt(Vector3.zero, look)
				* CFrame.Angles(
					math.rad(if jetOn then -Flight.tilt * throttle else 0),
					0,
					math.rad(-Flight.bank * seat.SteerFloat * moving)
				)
			local axis, angle = (pose * chassis.CFrame.Rotation:Inverse()):ToAxisAngle()
			local err = if angle == angle and angle > 1e-4 then axis * angle else Vector3.zero
			local along = nose * err:Dot(nose)
			local roll = Drive.input.roll
			local spin = (err - along) * Flight.level
				+ (if roll ~= 0 then nose * (roll * Flight.rollRate) else along * Flight.rollLevel)
			turn.AngularVelocity = spin + Vector3.yAxis * flyYaw
			speed, lateral, yawRate = actualForward, actualLeft, flyYaw
		elseif not flung and not s.airborne then
			local before = speed
			local steps = math.clamp(math.ceil(dt * 480), 1, 32)
			for _ = 1, steps do
				alphaF, alphaR = stepTyres(dt / steps, a, wheelbase, grip, stats.rearGrip)
			end
			if throttle == 0 and not thrusting and math.sign(speed) ~= math.sign(before) then
				speed, lateral, yawRate = 0, 0, 0
			end
			local crawler = stats.tracks
			if crawler then
				-- slow down and the tracks take over the turning: they run opposite ways and it spins on the spot,
				-- fading into ordinary steering as it picks up speed
				local fade = math.clamp(1 - math.abs(speed) / crawler.pivotFade, 0, 1)
				local want = -seat.SteerFloat * math.rad(crawler.pivotRate)
				pivotSpin += (want - pivotSpin) * math.min(1, dt * crawler.pivotAccel)
				yawRate = yawRate * (1 - fade) + pivotSpin * fade
				lateral *= 1 - fade
			end
			if thrustLeft > 0 then
				speed += THRUST_DV / THRUST_TIME * math.min(dt, thrustLeft)
				thrustLeft -= dt
			end
			local cap = if thrustLeft > 0
				then math.max(topSpeed, speed)
				else math.max(topSpeed, math.min(speed, topSpeed + THRUST_DV) - 8 * dt)
			speed = math.clamp(speed, -REVERSE_TOP, cap)
			drive.Enabled = true
			drive.VectorVelocity = (look * speed - right * lateral) * spm
			-- tilt to the road and yaw about its up
			turn.AngularVelocity = chassis.CFrame.UpVector:Cross(s.groundUp) * LEVEL_RATE
				+ s.groundUp * yawRate
		elseif not flung then
			-- in the air momentum carries the car; the thruster pushes along the nose
			drive.Enabled = false
			local nose = chassis.CFrame.LookVector
			if thrustLeft > 0 then
				chassis.AssemblyLinearVelocity += nose * (THRUST_DV / THRUST_TIME) * spm * math.min(
					dt,
					thrustLeft
				)
				thrustLeft -= dt
			end
			local level = chassis.CFrame.UpVector:Cross(Vector3.yAxis) * (LEVEL_RATE * 0.5)
			turn.AngularVelocity =
				Vector3.new(level.X, chassis.AssemblyAngularVelocity.Y * 0.98, level.Z)
		end
		s.frontSlide = math.clamp(math.abs(alphaF) / PEAK_SLIP - 0.8, 0, 1)
		s.rearSlide = math.max(
			math.clamp(math.abs(alphaR) / PEAK_SLIP - 0.8, 0, 1),
			math.clamp((longSlide - 0.95) * 4, 0, 1)
		)

		-- on its roof (or side) and stopped: put it back on its wheels
		if chassis.CFrame.UpVector.Y < 0.3 and chassis.AssemblyLinearVelocity.Magnitude < 10 then
			stuckFor += dt
			if stuckFor > 1.2 then
				stuckFor = 0
				local at = chassis.Position + Vector3.new(0, s.height + 2, 0)
				s.car:PivotTo(
					CFrame.lookAt(at, at + flatLook) * CFrame.new(0, -chassis.Size.Y / 2, 0)
				)
				chassis.AssemblyLinearVelocity = Vector3.zero
				chassis.AssemblyAngularVelocity = Vector3.zero
			end
		else
			stuckFor = 0
		end

		detectHits(s, chassis.AssemblyLinearVelocity)
		features(s, dt)

		local shown = v * MPH * (if Vehicles.has(stats, "Cart") then 10 else 1)
		Drive.state.speedMph = math.floor(shown + 0.5)
		Drive.state.reverse = speed < -0.1 or (throttle < 0 and v < 0.3)
		Drive.state.airborne = s.airborne
		local inside = Drive.view.firstPerson
		local fov = (if inside then Cockpit.fov else baseFov)
			+ (if inside then Cockpit.fovPunch else 1)
				* (14 * math.clamp(v / 110, 0, 1) ^ 0.75 + 5 * math.clamp(a / 15, 0, 1) + (if flying
					then 6
					else 0))
		camera.FieldOfView += (fov - camera.FieldOfView) * math.min(1, dt * 4)
		s.throttle, s.steerIn = throttle, seat.SteerFloat
		Drive.view.car = s.car
		Drive.view.steer = steer
		Drive.view.accel = s.accel
	end

	-- give back walls this client walked through, once the server has had its say
	local now = os.clock()
	for i = #loosened, 1, -1 do
		local e = loosened[i]
		if now - e.at > 1.5 then
			if e.part.Parent and e.part.Anchored and not e.part:GetAttribute("Broken") then
				e.part.CanCollide = true
			end
			table.remove(loosened, i)
		end
	end

	for car, s in cars do
		if not car.Parent then
			cars[car] = nil
			continue
		end
		local chassis = s.chassis
		local spm = Vehicles.StudsPerMetre
		local forward = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
		local v = forward / spm
		local maxSteer = math.rad(s.stats.maxSteer)

		s.spin = (s.spin - forward / s.radius * dt) % (math.pi * 2)
		local crawling = #s.shoes > 0 or s.stats.tracks ~= nil
		if crawling then
			local left, right =
				Tracks.speeds(forward, chassis.AssemblyAngularVelocity.Y, s.trackHalf)
			for side, run in { L = left, R = right } do
				s.trackMove[side] += run * dt
				s.trackSpin[side] -= run * dt
			end
		end
		local target = s.steer
		if s == driving then
			target = steer
		elseif math.abs(v) > 1 then
			target = math.clamp(
				math.atan(chassis.AssemblyAngularVelocity.Y * (s.wheelbase / spm) / v),
				-maxSteer,
				maxSteer
			)
		end
		s.steer += (target - s.steer) * math.min(1, dt * 12)
		local steerCF = CFrame.Angles(0, s.steer, 0)
		local spinCF = CFrame.Angles(s.spin, 0, 0)
		-- each tyre finds the ground under it (nearby cars only): pushed up over whatever it would sink
		-- into, hanging a little lower when there's nothing below
		local near = (chassis.Position - camera.CFrame.Position).Magnitude < WHEEL_CONTACT_RANGE
		if near then
			wheelParams.FilterDescendantsInstances =
				{ s.car, workspace:FindFirstChild("Npcs") :: Instance, character :: Instance }
		end
		for _, w in s.wheels do
			local settle = 0
			local part0 = w.weld.Part0
			if near and part0 and not w.track then
				local rise, droop = w.radius * WHEEL_TRAVEL, w.radius * WHEEL_DROOP
				local upward = part0.CFrame.UpVector
				local hub = part0.CFrame:PointToWorldSpace(w.base.Position)
				local hit = workspace:Raycast(
					hub + upward * rise,
					-upward * (rise + w.radius + droop),
					wheelParams
				)
				settle = if hit
					then math.clamp(rise - hit.Distance + w.radius, -droop, rise)
					else -droop
			end
			-- up at once (never into the kerb), down gently (springs)
			w.lift = if settle > w.lift
				then settle
				else w.lift + (settle - w.lift) * math.min(1, dt * 14)
			local cf = CFrame.new(0, w.lift, 0) * w.base
			if w.track then
				cf *= CFrame.Angles(s.trackSpin[w.track] / w.radius, 0, 0)
			else
				if w.front then
					cf *= steerCF
				end
				if w.spin then
					cf *= spinCF
				end
			end
			w.weld.C0 = cf
		end
		if crawling and near then
			for _, r in s.rollers do
				r.weld.C0 = r.base * CFrame.Angles(s.trackSpin[r.side] / r.radius, 0, 0)
			end
			for _, sh in s.shoes do
				local y, z, angle = Tracks.at(sh.loop, sh.offset + s.trackMove[sh.side])
				sh.weld.C0 = CFrame.new(sh.x, y, z) * CFrame.Angles(angle, 0, 0)
			end
		end

		-- gauges: the speedo follows speed, the rev needle the engine (idling while someone's in)
		if #s.needles > 0 and near then
			local top = s.stats.topSpeed / MPH * Cockpit.speedoTop
			local occupied = s.seat ~= nil and s.seat.Occupant ~= nil
			local revs = if occupied
				then Cockpit.idleRev + (1 - Cockpit.idleRev) * math.clamp(
					math.abs(v) / (s.stats.topSpeed / MPH) * 0.8 + 0.2 * s.load,
					0,
					1
				)
				else 0
			for _, n in s.needles do
				local want = if n.kind == "Speed" then math.clamp(math.abs(v) / top, 0, 1) else revs
				n.at += (want - n.at) * math.min(1, dt * Cockpit.needleRate)
				n.weld.C0 = n.base
					* CFrame.Angles(0, 0, math.rad(Cockpit.needleZero - Cockpit.needleSweep * n.at))
			end
		end
		-- joysticks lean with the driver's hands: forward with the throttle, sideways with the steering
		for _, k in s.sticks do
			local driven = s == driving
			local fwd = if k.side == "L" and driven then s.throttle else 0
			local sideways = if k.side == "L" and driven then s.steerIn else 0
			local rate = math.min(1, dt * Cockpit.stickRate)
			k.fwd += (fwd - k.fwd) * rate
			k.sway += (sideways - k.sway) * rate
			local lean = math.rad(Cockpit.stickLean)
			k.weld.C0 = k.base * CFrame.Angles(-k.fwd * lean, 0, -k.sway * lean)
		end

		-- the cabin steering wheel turns with the front wheels, and the driver's hands stay on it
		if not s.steerWeld then
			local sprung = s.car:FindFirstChild("Sprung")
			local sw = sprung and sprung:FindFirstChild("SteerWeld")
			if sw and sw:IsA("Weld") then
				s.steerWeld, s.steerBase = sw, sw.C0
			end
		end
		if s.steerWeld then
			s.steerWeld.C0 = s.steerBase
				* CFrame.Angles(0, 0, s.steer * (s.stats.steerRatio or STEER_WHEEL_RATIO))
		end
		local occupant = s.seat and s.seat.Occupant
		if occupant ~= s.ikFor then
			for _, k in s.ik do
				k:Destroy()
			end
			table.clear(s.ik)
			s.ikFor = occupant
			-- the hands' targets: GripL/GripR attachments on the wheel, handlebars or joysticks
			local grips: { [string]: Attachment } = {}
			for _, a in s.car:GetDescendants() do
				if a:IsA("Attachment") and (a.Name == "GripL" or a.Name == "GripR") then
					grips[a.Name] = a
				end
			end
			local body = occupant and occupant.Parent
			local shell = s.car:FindFirstChild("Body")
			if next(grips) and body and shell and shell:IsA("BasePart") and s.stats.showDriver then
				for side, gripName in { Left = "GripL", Right = "GripR" } do
					local hand = body:FindFirstChild(side .. "Hand")
					local upper = body:FindFirstChild(side .. "UpperArm")
					local grip = grips[gripName]
					if hand and upper and grip then
						local k = Instance.new("IKControl")
						k.Name = "RoyfGrip" .. side
						k.Type = Enum.IKControlType.Position
						k.EndEffector = hand :: BasePart
						k.ChainRoot = upper :: BasePart
						k.Target = grip
						k.Parent = occupant
						table.insert(s.ik, k)
					end
				end
			end
		end

		if now - s.surfaceAt > 0.12 then
			s.surfaceAt = now
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances =
				{ s.car, workspace:FindFirstChild("Npcs") :: Instance, character :: Instance }
			params.CollisionGroup = "Vehicles"
			local reach = chassis.Size.Y / 2 + 0.35 * spm
			local hit =
				workspace:Raycast(chassis.Position, -chassis.CFrame.UpVector * reach, params)
			local was = s.airborne
			-- the driver's corner probes count too: a level car nosing onto a ramp has its middle off the road
			s.airborne = hit == nil and now - s.probedAt > 0.2
			if hit then
				s.surface = SURFACES[hit.Material] or HARD
			end
			if was and not s.airborne and s.fall > 6 then
				s.dust:Emit(math.clamp(math.floor(s.fall * 2), 10, 40))
			end
		end
		local up = chassis.AssemblyLinearVelocity.Y / spm
		s.fall = if s.airborne then math.max(s.fall, -up) else 0

		-- the gas jets: the driver knows which are firing; everyone else reads it off the car's motion
		if s.thrusters.Lift then
			local on: { [string]: boolean } = {}
			local spinY = chassis.AssemblyAngularVelocity.Y
			local spinNose = chassis.AssemblyAngularVelocity:Dot(chassis.CFrame.LookVector)
			if s == driving then
				local steerIn = seat and seat:IsA("VehicleSeat") and seat.SteerFloat or 0
				on.Lift, on.Rear, on.Nose = jetOn, rearOn, reversing
				on.YawR, on.YawL = flying and steerIn > 0, flying and steerIn < 0
				on.RollR, on.RollL =
					flying and Drive.input.roll > 0, flying and Drive.input.roll < 0
			else
				local air = s.airborne
				on.Lift = air and up > -1
				on.Rear = s.accel.Z > 1.7 * G
				on.Nose = air and s.accel.Z < -1.2 * G
				on.YawR, on.YawL = air and spinY < -0.5, air and spinY > 0.5
				on.RollR, on.RollL = air and spinNose > 1, air and spinNose < -1
			end
			for job, list in s.thrusters do
				for _, p in list do
					p.Enabled = on[job] == true
				end
			end
			for _, p in s.thrusters.Lift do
				p.Rate = if up > 1 then 90 else 35
			end
			local puffing = on.Nose or on.YawR or on.YawL or on.RollR or on.RollL
			if puffing and not s.puffing then
				s.jetSounds.Burst:Play()
			end
			s.puffing = puffing
			local fade = math.min(1, dt * 12)
			for name, want in
				{
					Lift = if on.Lift then 1.1 else 0,
					Rear = if on.Rear then 1.2 else 0,
					Puff = if puffing then (if on.Nose then 0.9 else 0.5) else 0,
				}
			do
				local snd = s.jetSounds[name]
				snd.Volume += (want - snd.Volume) * fade
			end
		end

		local cf = chassis.CFrame
		local vel = chassis.AssemblyLinearVelocity
		local worldAccel = (vel - s.lastVel) / math.max(dt, 1 / 240) / spm
		s.lastVel = vel
		local feltLocal = Vector3.new(
			worldAccel:Dot(cf.RightVector),
			worldAccel:Dot(cf.UpVector),
			worldAccel:Dot(cf.LookVector)
		)
		local clampG = 3 * G
		feltLocal = Vector3.new(
			math.clamp(feltLocal.X, -clampG, clampG),
			math.clamp(feltLocal.Y, -clampG, clampG),
			math.clamp(feltLocal.Z, -clampG, clampG)
		)
		s.accel = s.accel:Lerp(feltLocal, math.min(1, dt * 14))

		if s.suspension then
			local ax, ay, az = s.accel.X / G, s.accel.Y / G, s.accel.Z / G
			local rollTarget = math.rad(ROLL_PER_G) * ax
			local pitchTarget = math.rad(if az > 0 then SQUAT_PER_G else DIVE_PER_G) * az
			local heaveTarget = if s.airborne then HEAVE_PER_G * 1.5 else -HEAVE_PER_G * ay
			local w = 2 * math.pi * RIDE_HZ
			local h = math.min(dt, 1 / 30)
			s.rollV += (w * w * (rollTarget - s.roll) - 2 * RIDE_DAMPING * w * s.rollV) * h
			s.roll += s.rollV * h
			s.pitchV += (w * w * (pitchTarget - s.pitch) - 2 * RIDE_DAMPING * w * s.pitchV) * h
			s.pitch += s.pitchV * h
			s.heaveV += (w * w * (heaveTarget - s.heave) - 2 * RIDE_DAMPING * w * s.heaveV) * h
			s.heave += s.heaveV * h
			s.roll = math.clamp(s.roll, -math.rad(6), math.rad(6))
			s.pitch = math.clamp(s.pitch, -math.rad(5), math.rad(5))
			s.heave = math.clamp(s.heave, -0.08, 0.08)
			s.travelled += math.abs(v) * dt
			local d = s.travelled
			local buzz = 0.0018
				* s.surface.rough
				* math.clamp(math.abs(v) / 8, 0, 1)
				* (
					math.sin(d * 2.3)
					+ 0.6 * math.sin(d * 5.9 + 1.3)
					+ 0.3 * math.sin(d * 13.1 + 0.4)
				)
			s.suspension.C0 = s.pivot
				* CFrame.new(0, (s.heave + buzz) * spm, 0)
				* CFrame.Angles(s.pitch, 0, s.roll)
				* s.pivot:Inverse()
		end

		if s ~= driving then
			local localVel = cf:VectorToObjectSpace(chassis.AssemblyLinearVelocity / spm)
			local forwardV, leftV = -localVel.Z, -localVel.X
			local toRear = FRONT_SHARE * s.wheelbase / spm
			local alphaR = if math.abs(forwardV) > KINEMATIC_SPEED
				then math.atan2(
					leftV - toRear * chassis.AssemblyAngularVelocity.Y,
					math.abs(forwardV)
				)
				else 0
			s.rearSlide = math.clamp(math.abs(alphaR) / PEAK_SLIP - 0.8, 0, 1)
			s.frontSlide = 0
		end
		local onGround = not s.airborne and math.abs(v) > 1
		for _, m in s.marks do
			local slide = if m.front then s.frontSlide else s.rearSlide
			m.trail.Enabled = onGround and slide > 0.15
			m.trail.Color = ColorSequence.new(s.surface.mark)
		end

		local mag = math.abs(v)
		local accel = (mag - s.lastSpeed) / math.max(dt, 1 / 240)
		s.lastSpeed = mag
		s.load += (math.clamp(math.abs(accel) / 12, 0, 1) - s.load) * math.min(1, dt * 6)
		local frac = math.clamp(mag / (s.stats.topSpeed / MPH), 0, 1.3)
		if s.motor then
			-- pitch follows speed; volume rises with load, and engines that idle keep a low rumble while occupied
			local e = s.engine
			s.motor.PlaybackSpeed = (e.idlePitch + (e.topPitch - e.idlePitch) * frac) * s.tone
			local running = if s.seat and s.seat.Occupant then e.idle else 0
			local moving = math.clamp(mag / 1.5, 0, 1)
				* (0.12 + 0.6 * s.load + 0.28 * math.min(frac, 1))
			s.motor.Volume = e.volume * math.max(running, moving)
		end
		if s.road then
			s.road.PlaybackSpeed = 0.75 + 0.5 * math.clamp(mag / 60, 0, 1)
			s.road.Volume = 0.55 * math.clamp(mag / 45, 0, 1) ^ 0.8
		end
		if s.wind then
			s.wind.PlaybackSpeed = 0.85 + 0.5 * frac
			s.wind.Volume = 0.85 * math.clamp(mag / 110, 0, 1) ^ 1.6
		end
		if s.squeal then
			local slide = math.max(s.frontSlide, s.rearSlide)
			local loud = if s.surface.squeal and not s.airborne
				then slide * math.clamp(mag / 4, 0, 1)
				else 0
			s.squeal.Volume += (0.9 * loud - s.squeal.Volume) * math.min(1, dt * 10)
			s.squeal.PlaybackSpeed = 0.9 + 0.2 * slide
		end
	end
end

function Drive.start()
	for _, car in CollectionService:GetTagged("Vehicle") do
		track(car)
	end
	CollectionService:GetInstanceAddedSignal("Vehicle"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("Vehicle"):Connect(function(car)
		cars[car :: Model] = nil
	end)
	bind()
	Net.waitFor("Fling").OnClientEvent:Connect(onFling)
	RunService.Heartbeat:Connect(step)
end

return Drive
