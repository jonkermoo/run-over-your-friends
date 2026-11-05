--!strict
-- What vehicle features look like on every screen: the fire truck's water-cannon turret (it turns to the
-- aim and sprays) and the ice-cream truck's sign while its jingle plays. The local driver's cannon follows
-- Drive.cannon at once; everyone else's follows the CannonAim / CannonAt attributes the server sets.
-- All parts here are made on this client only.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Game = require(ReplicatedStorage.Shared.Config.Game)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Drive = require(script.Parent.Drive)
local Style = require(script.Parent.Style)

local C, F = Style.colors, Style.fonts

local Features = {}

local SHOW = 320 -- studs from the camera: further turrets hold still
local TURN = 9 -- how fast the turret swings to its aim, per second
local REMOTE_SPRAY = 0.4 -- seconds a remote cannon keeps spraying after the last aim update
local REST_AFTER = 1.5 -- seconds idle before a turret swings back to the front

type Turret = {
	car: Model,
	chassis: BasePart,
	weld: Weld,
	offset: Vector3,
	barrel: Weld,
	water: ParticleEmitter,
	yaw: number, -- radians, in the chassis frame
	pitch: number,
}

type Sign = { car: Model, gui: BillboardGui, scale: UIScale, base: number }

local turrets: { [Model]: Turret } = {}
local signs: { [Model]: Sign } = {}

local function cosmetic(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
end

local function buildTurret(car: Model, chassis: BasePart, n: { number })
	local mount = (car:FindFirstChild("Sprung", true) :: BasePart?) or chassis
	local offset = Vector3.new(n[1], n[2], n[3])
	local base = Instance.new("Part")
	base.Name = "CannonBase"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(1.3, 4.6, 4.6)
	base.Color = Color3.fromRGB(70, 72, 78)
	base.Material = Enum.Material.Metal
	cosmetic(base)
	local barrel = Instance.new("Part")
	barrel.Name = "CannonBarrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(7, 1.5, 1.5)
	barrel.Color = Color3.fromRGB(205, 205, 210)
	barrel.Material = Enum.Material.Metal
	cosmetic(barrel)
	local tip = Instance.new("Part")
	tip.Name = "CannonTip"
	tip.Shape = Enum.PartType.Cylinder
	tip.Size = Vector3.new(1, 2, 2)
	tip.Color = C.yellow
	tip.Material = Enum.Material.SmoothPlastic
	cosmetic(tip)
	-- the turret base turns about the chassis up axis; the barrel pitches on it
	local w = Instance.new("Weld")
	w.Part0 = mount
	w.Part1 = base
	w.C0 = CFrame.new(offset) * CFrame.Angles(0, 0, math.pi / 2)
	w.Parent = base
	local bw = Instance.new("Weld")
	bw.Part0 = base
	bw.Part1 = barrel
	bw.Parent = barrel
	local tw = Instance.new("Weld")
	tw.Part0 = barrel
	tw.Part1 = tip
	tw.C0 = CFrame.new(-3.8, 0, 0)
	tw.Parent = tip
	-- the spray leaves the tip along the barrel (cylinders run along X, so -X is the muzzle)
	local a = Instance.new("Attachment")
	a.CFrame = CFrame.new(-0.5, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
	a.Parent = tip
	local water = Instance.new("ParticleEmitter")
	water.Name = "Water"
	water.Color = ColorSequence.new(Color3.fromRGB(170, 210, 255))
	water.Size = NumberSequence.new(1.2, 3)
	water.Transparency = NumberSequence.new(0.2, 1)
	water.Speed = NumberRange.new(90, 110)
	water.Acceleration = Vector3.new(0, -80, 0)
	water.Lifetime = NumberRange.new(0.6, 0.8)
	water.SpreadAngle = Vector2.new(4, 4)
	water.EmissionDirection = Enum.NormalId.Front
	water.Rate = 160
	water.Enabled = false
	water.Parent = a
	local folder = Instance.new("Folder")
	folder.Name = "Cannon"
	base.Parent = folder
	barrel.Parent = folder
	tip.Parent = folder
	folder.Parent = car
	turrets[car] = {
		car = car,
		chassis = chassis,
		weld = w,
		offset = offset,
		barrel = bw,
		water = water,
		yaw = 0,
		pitch = 0,
	}
end

local function buildSign(car: Model, chassis: BasePart)
	local _, size = car:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "IceCreamSign"
	gui.Size = UDim2.fromOffset(190, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 8, 0)
	gui.MaxDistance = 300
	gui.LightInfluence = 0
	gui.Enabled = false
	gui.Adornee = chassis
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	-- a road-paint plate: asphalt with a yellow edge, a pink band, a cone and the shout
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.BackgroundColor3 = C.panel
	plate.BorderSizePixel = 0
	plate.Size = UDim2.new(1, -8, 1, -8)
	plate.Position = UDim2.fromOffset(2, 2)
	plate.Parent = gui
	Style.stroke(plate, C.yellow, 3, 0)
	Style.shadow(plate, C.ink, 4)
	local band = Instance.new("Frame")
	band.BackgroundColor3 = C.pink
	band.BorderSizePixel = 0
	band.Size = UDim2.new(1, 0, 0, 7)
	band.Parent = plate
	local cone = Style.label(plate, "🍦", 40, F.display, C.text)
	cone.TextScaled = true
	cone.Size = UDim2.fromOffset(46, 46)
	cone.Position = UDim2.fromOffset(6, 12)
	local shout = Style.label(plate, "ICE CREAM!", 26, F.display, C.yellow)
	shout.TextXAlignment = Enum.TextXAlignment.Left
	shout.Size = UDim2.new(1, -60, 0, 30)
	shout.Position = UDim2.fromOffset(56, 10)
	local sub = Style.label(plate, "come and get it", 13, F.heavy, C.text)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Size = UDim2.new(1, -60, 0, 16)
	sub.Position = UDim2.fromOffset(57, 40)
	gui.Parent = car
	signs[car] = { car = car, gui = gui, scale = scale, base = size.Y / 2 + 8 }
end

local function track(car: Instance)
	if not car:IsA("Model") or turrets[car] or signs[car] then
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
	local chassis = car.PrimaryPart :: BasePart
	if Vehicles.has(stats, "Cannon") and stats.nozzle then
		local n, S = stats.nozzle, Game.VehicleScale
		buildTurret(car, chassis, { n[1] * S, n[2] * S, n[3] * S })
	end
	if Vehicles.has(stats, "Jingle") then
		buildSign(car, chassis)
	end
end

local function angleTo(a: number, b: number, k: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * k
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local now = workspace:GetServerTimeNow()
	local k = 1 - math.exp(-TURN * dt)
	for car, t in turrets do
		if not car.Parent then
			turrets[car] = nil
			continue
		end
		local near = (t.chassis.Position - camera.CFrame.Position).Magnitude < SHOW
		local firing, aim, idle = false, nil :: Vector3?, math.huge
		if Drive.cannon.car == car then
			firing, aim = Drive.cannon.firing, Drive.cannon.aim
			idle = if firing then 0 else math.huge
		else
			local at = car.PrimaryPart and car.PrimaryPart:GetAttribute("CannonAt")
			local a = car.PrimaryPart and car.PrimaryPart:GetAttribute("CannonAim")
			if typeof(at) == "number" and typeof(a) == "Vector3" then
				idle = now - at
				firing = idle < REMOTE_SPRAY
				aim = a
			end
		end
		t.water.Enabled = firing and near
		if not near then
			continue
		end
		-- aim in the chassis frame; swing back to the front a while after the last shot
		local yaw, pitch = 0, 0
		if aim and (firing or idle < REST_AFTER or Drive.cannon.car == car) then
			local l = t.chassis.CFrame:VectorToObjectSpace(aim)
			yaw = math.atan2(-l.X, -l.Z)
			pitch = math.asin(math.clamp(l.Y, -1, 1))
		end
		t.yaw = angleTo(t.yaw, yaw, k)
		t.pitch += (pitch - t.pitch) * k
		-- the base is a flat disc (cylinder axis turned up) spun by yaw; the barrel sits on it, pitched, with
		-- its muzzle (-X) turned to the front; both are worked out in the mount's frame
		local baseFrame = CFrame.Angles(0, t.yaw, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local barrelFrame = CFrame.Angles(0, t.yaw, 0)
			* CFrame.Angles(t.pitch, 0, 0)
			* CFrame.new(0, 1.3, -2.6)
			* CFrame.Angles(0, -math.pi / 2, 0)
		t.weld.C0 = CFrame.new(t.offset) * baseFrame
		t.barrel.C0 = baseFrame:Inverse() * barrelFrame
	end
	local beat = os.clock() * math.pi * 2 * 1.6
	for car, s in signs do
		if not car.Parent then
			signs[car] = nil
			continue
		end
		local on = car.PrimaryPart ~= nil and car.PrimaryPart:GetAttribute("JingleOn") == true
		s.gui.Enabled = on
		if on then
			s.scale.Scale = 1 + 0.05 * math.max(0, math.sin(beat))
			s.gui.StudsOffsetWorldSpace = Vector3.new(0, s.base + 0.4 * math.sin(beat / 2), 0)
		end
	end
end

function Features.start()
	for _, car in CollectionService:GetTagged("Vehicle") do
		track(car)
	end
	CollectionService:GetInstanceAddedSignal("Vehicle"):Connect(track)
	RunService.RenderStepped:Connect(step)
end

return Features
