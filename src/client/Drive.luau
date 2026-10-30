--!strict
-- Driving for whoever sits in a tagged Vehicle's seat (the driver's client owns the physics), plus the
-- visuals every client runs for every vehicle: wheel spin and steer, suspension, skid marks and sound.
-- Tyres are a bicycle model with a Pacejka-style curve; each vehicle's numbers come from Config/Vehicles.
-- Also: Roadster jet and air control, thruster, hit detection (NPCs, buildings, Wrecker), features,
-- self-destruct, and flings sent by the server.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
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
	boost = 100, -- Roadster jet meter, 0-100
	thruster = 1, -- 0 = just used, 1 = ready
	bombHold = 0, -- 0-1 while holding self-destruct
}
-- held inputs; keyboard and gamepad set them here, and so do the phone buttons
Drive.input = {
	boost = false,
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
-- jet, thruster, air control
local JET_ACCEL = 12
local JET_POWER = 1.8
local JET_TOP_MPH = 330
local JET_DRAIN, JET_REFILL, JET_REFILL_DELAY = 25, 8, 1
local THRUST_DV, THRUST_TIME, THRUST_COOLDOWN = 25, 0.6, 12
local AIR_RATE, AIR_RAMP = 5.5, 10
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

type Wheel = { weld: Weld, base: CFrame, front: boolean, spin: boolean }
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
	airborne: boolean,
	frontSlide: number,
	rearSlide: number,
	marks: { { trail: Trail, front: boolean } },
	jet: ParticleEmitter?,
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
	for _, w in chassis:GetChildren() do
		local c = w:GetAttribute("Corner")
		if w:IsA("Weld") and typeof(c) == "string" then
			local front = string.sub(c, 1, 1) == "F"
			table.insert(
				wheels,
				{ weld = w, base = w.C0, front = front, spin = w:GetAttribute("Spin") == true }
			)
			if front then
				frontZ = math.min(frontZ, w.C0.Position.Z)
			else
				rearZ = math.max(rearZ, w.C0.Position.Z)
			end
			local tyre = w.Part1
			if tyre then
				local contact = w.C0.Position - Vector3.new(0, tyre.Size.Y / 2 - 0.08, 0)
				local half = Vector3.new(math.min(tyre.Size.X, 2) * 0.4, 0, 0)
				local a0 = Instance.new("Attachment")
				a0.Position = contact - half
				a0.Parent = chassis
				local a1 = Instance.new("Attachment")
				a1.Position = contact + half
				a1.Parent = chassis
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
	local _, size = car:GetBoundingBox()
	-- the Roadster's jet flame, at the tail
	local jet: ParticleEmitter? = nil
	if Vehicles.has(stats, "Jet") then
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(0, chassis.Size.Y * 0.2, chassis.Size.Z / 2 + 0.5)
		a.Parent = chassis
		local p = Instance.new("ParticleEmitter")
		p.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255), Color3.fromRGB(80, 140, 255))
		p.LightEmission = 1
		p.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.6),
			NumberSequenceKeypoint.new(1, 0),
		})
		p.Transparency = NumberSequence.new(0.1, 1)
		p.Lifetime = NumberRange.new(0.12, 0.22)
		p.Speed = NumberRange.new(40, 60)
		p.EmissionDirection = Enum.NormalId.Back
		p.Rate = 220
		p.Enabled = false
		p.Parent = a
		jet = p
	end
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
		airborne = false,
		frontSlide = 0,
		rearSlide = 0,
		marks = marks,
		jet = jet,
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
local airSpin = Vector3.zero
local bombHeld = 0
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
		end
		if driving.jet then
			driving.jet.Enabled = false
		end
	end
	driving = nil
	speed, lateral, yawRate, steer = 0, 0, 0, 0
	Drive.state.driving = false
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
	local vehiclesFolder = workspace:FindFirstChild("Vehicles")
	local wrecker = player:GetAttribute("PassWrecker") == true
	local include: { Instance } = {}
	if npcFolder then
		table.insert(include, npcFolder)
	end
	if buildings and s.stats.breaksBuildings then
		table.insert(include, buildings)
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
	local ahead = math.clamp(velocity.Magnitude * 0.08, 1, 14)
	local size = Vector3.new(chassis.Size.X + 2, s.height + 2, chassis.Size.Z + ahead)
	local localVel = chassis.CFrame:VectorToObjectSpace(velocity)
	local shift = if localVel.Z < 0 then -ahead / 2 else ahead / 2
	local box = chassis.CFrame * CFrame.new(0, s.height / 2 - chassis.Size.Y / 2, shift)
	local parts = workspace:GetPartBoundsInBox(box, size, params)
	local now = os.clock()
	local breakSum, breakCount = Vector3.zero, 0
	for _, p in parts do
		if npcFolder and p:IsDescendantOf(npcFolder) then
			local npc = npcOf(p, npcFolder)
			if npc and not npc:GetAttribute("Down") and (hitNpcAt[npc] or 0) + 1 < now then
				hitNpcAt[npc] = now
				Net.waitFor("HitNpc"):FireServer(npc, velocity)
			end
		elseif buildings and p:IsDescendantOf(buildings) then
			if p.Anchored and p.CanCollide and not p:GetAttribute("Broken") then
				-- let the car through at once; the server breaks it for everyone
				p.CanCollide = false
				table.insert(loosened, { part = p, at = now })
				breakSum += p.Position
				breakCount += 1
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
	if breakCount > 0 and now - lastBreakSent > 0.12 then
		lastBreakSent = now
		Net.waitFor("BreakAt"):FireServer(breakSum / breakCount, velocity)
		speed *= 0.9
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
	if not driving or not Vehicles.has(driving.stats, "Thruster") then
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
		local right = Vector3.new(-look.Z, 0, look.X)
		local actual = chassis.AssemblyLinearVelocity / spm
		local actualForward, actualLeft = actual:Dot(look), -actual:Dot(right)
		if math.abs(actualForward - speed) > 2 or math.abs(actualLeft - lateral) > 2 then
			speed, lateral = actualForward, actualLeft
		end
		if math.abs(chassis.AssemblyAngularVelocity.Y - yawRate) > 0.6 then
			yawRate = chassis.AssemblyAngularVelocity.Y
		end

		-- jet meter (Roadster)
		local hasJet = Vehicles.has(stats, "Jet")
		local jetting = hasJet and Drive.input.boost and Drive.state.boost > 0
		if jetting then
			Drive.state.boost = math.max(0, Drive.state.boost - JET_DRAIN * dt)
			boostUsedAt = now
		elseif now - boostUsedAt > JET_REFILL_DELAY then
			Drive.state.boost = math.min(100, Drive.state.boost + JET_REFILL * dt)
		end
		if s.jet then
			s.jet.Enabled = jetting
		end

		local topSpeed = stats.topSpeed / MPH
		if hasJet and (jetting or speed > topSpeed) then
			topSpeed = math.max(
				topSpeed,
				math.min(JET_TOP_MPH / MPH, if jetting then JET_TOP_MPH / MPH else speed - 6 * dt)
			)
		end
		local launch = stats.launch * (if jetting then 1.2 else 1)
		local power = stats.power * (if jetting then JET_POWER else 1)

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
		if jetting then
			a += JET_ACCEL -- the jet pushes the car, not the tyres
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

		local alphaF, alphaR = 0, 0
		if not flung and not s.airborne then
			local before = speed
			local steps = math.clamp(math.ceil(dt * 480), 1, 32)
			for _ = 1, steps do
				alphaF, alphaR = stepTyres(dt / steps, a, wheelbase, grip, stats.rearGrip)
			end
			if throttle == 0 and math.sign(speed) ~= math.sign(before) then
				speed, lateral, yawRate = 0, 0, 0
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
			local level = chassis.CFrame.UpVector:Cross(Vector3.yAxis) * LEVEL_RATE
			turn.AngularVelocity = Vector3.new(level.X, yawRate, level.Z)
			airSpin = Vector3.zero
		elseif not flung then
			-- in the air momentum carries the car; the jet and thruster push along the nose
			drive.Enabled = false
			local nose = chassis.CFrame.LookVector
			if jetting then
				chassis.AssemblyLinearVelocity += nose * JET_ACCEL * spm * dt
			end
			if thrustLeft > 0 then
				chassis.AssemblyLinearVelocity += nose * (THRUST_DV / THRUST_TIME) * spm * math.min(
					dt,
					thrustLeft
				)
				thrustLeft -= dt
			end
			if hasJet then
				-- Rocket League air control: pitch on throttle, yaw on steer, roll on Q/E
				local want = Vector3.new(-throttle, -seat.SteerFloat, -Drive.input.roll) * AIR_RATE
				airSpin = airSpin:Lerp(want, math.min(1, dt * AIR_RAMP))
				turn.AngularVelocity = chassis.CFrame:VectorToWorldSpace(airSpin)
			else
				local level = chassis.CFrame.UpVector:Cross(Vector3.yAxis) * (LEVEL_RATE * 0.5)
				turn.AngularVelocity =
					Vector3.new(level.X, chassis.AssemblyAngularVelocity.Y * 0.98, level.Z)
			end
		end
		s.frontSlide = math.clamp(math.abs(alphaF) / PEAK_SLIP - 0.8, 0, 1)
		s.rearSlide = math.max(
			math.clamp(math.abs(alphaR) / PEAK_SLIP - 0.8, 0, 1),
			math.clamp((longSlide - 0.95) * 4, 0, 1)
		)

		detectHits(s, chassis.AssemblyLinearVelocity)
		features(s, dt)

		local shown = v * MPH * (if Vehicles.has(stats, "Cart") then 10 else 1)
		Drive.state.speedMph = math.floor(shown + 0.5)
		Drive.state.reverse = speed < -0.1 or (throttle < 0 and v < 0.3)
		Drive.state.airborne = s.airborne
		local fov = baseFov
			+ 14 * math.clamp(v / 110, 0, 1) ^ 0.75
			+ 5 * math.clamp(a / 15, 0, 1)
			+ (if jetting then 6 else 0)
		camera.FieldOfView += (fov - camera.FieldOfView) * math.min(1, dt * 4)
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
		for _, w in s.wheels do
			local cf = w.base
			if w.front then
				cf *= steerCF
			end
			if w.spin then
				cf *= spinCF
			end
			w.weld.C0 = cf
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
			s.airborne = hit == nil
			if hit then
				s.surface = SURFACES[hit.Material] or HARD
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
			s.motor.PlaybackSpeed = 0.3 + 2.2 * frac
			s.motor.Volume = math.clamp(mag / 1.5, 0, 1) * (0.08 + 0.6 * s.load)
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
