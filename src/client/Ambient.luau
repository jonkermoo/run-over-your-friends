--!strict
-- Gentle motion in the city on this screen only (Config/Ambient): spray from fountains and ponds, the spawn
-- plaza's banners swaying, small bird flocks circling over downtown, steam from rooftop vents. The server only
-- tags the pieces; each one streams in with the map, and everything here runs only near the camera. Birds
-- are made once (a fixed pool) and hidden when their flock is out of range.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local A = require(ReplicatedStorage.Shared.Config.Ambient)
local Particles = require(ReplicatedStorage.Shared.Config.Particles)

local Ambient = {}

local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local range = if phone then A.RangePhone else A.Range
local rateShare = if phone then A.PhoneRate else 1
local PUFF = `rbxassetid://{Particles.Puff}`

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function seq(a: number, b: number): NumberSequence
	return NumberSequence.new(a, b)
end

type Emitter = { part: BasePart, emitter: ParticleEmitter }
local emitters: { Emitter } = {}

local function emit(
	part: BasePart,
	lift: number,
	cfg: any,
	speedShare: number,
	up: boolean
): ParticleEmitter
	-- world-upright, whatever way the part is turned (the water discs are cylinders lying on their side)
	local at = Instance.new("Attachment")
	at.Parent = part
	at.WorldCFrame = CFrame.new(part.Position + Vector3.new(0, lift, 0))
	local e = Instance.new("ParticleEmitter")
	e.Texture = PUFF
	e.Color = ColorSequence.new(rgb(cfg.Colour))
	e.Size = seq(cfg.Size[1], cfg.Size[2])
	e.Lifetime = NumberRange.new(cfg.Lifetime[1], cfg.Lifetime[2])
	e.Speed = NumberRange.new(cfg.Speed[1] * speedShare, cfg.Speed[2] * speedShare)
	e.Rate = cfg.Rate * rateShare
	e.EmissionDirection = Enum.NormalId.Top
	e.Enabled = false
	if up then
		-- a jet: narrow, falling back down, fading after 70% of its life
		e.SpreadAngle = Vector2.new(cfg.Spread, cfg.Spread)
		e.Acceleration = Vector3.new(0, -cfg.Gravity, 0)
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, cfg.Transparency[1]),
			NumberSequenceKeypoint.new(0.7, cfg.Transparency[2]),
			NumberSequenceKeypoint.new(1, 1),
		})
	else
		-- steam: slow, spreading, drifting with the wind
		e.SpreadAngle = Vector2.new(cfg.Spread, cfg.Spread)
		e.Acceleration = Vector3.new(cfg.Drift[1], cfg.Drift[2], cfg.Drift[3])
		e.Transparency = seq(cfg.Transparency[1], cfg.Transparency[2])
		e.RotSpeed = NumberRange.new(-cfg.Spin, cfg.Spin)
		e.Rotation = NumberRange.new(0, 360)
	end
	e.Parent = at
	table.insert(emitters, { part = part, emitter = e })
	return e
end

type Flag = { part: BasePart, base: CFrame, hinge: Vector3, phase: number }
local flags: { Flag } = {}

local function addSpray(p: Instance)
	if p:IsA("BasePart") then
		local lift = p:GetAttribute("SprayLift")
		local pond = p:GetAttribute("Pond") == true
		emit(
			p,
			if type(lift) == "number" then lift else A.PondLift,
			A.Spray,
			if pond then A.Spray.PondSpeed else 1,
			true
		)
	end
end

local function addSteam(p: Instance)
	if p:IsA("BasePart") then
		emit(p, p.Size.Y / 2, A.Steam, 1, false)
	end
end

local function addFlag(p: Instance)
	local hinge = p:GetAttribute("Hinge")
	if p:IsA("BasePart") and typeof(hinge) == "Vector3" then
		table.insert(flags, {
			part = p,
			base = p.CFrame,
			hinge = hinge,
			phase = (hinge.X * 0.37 + hinge.Z * 0.21) % (math.pi * 2),
		})
	end
end

local function forget(p: Instance)
	for k = #emitters, 1, -1 do
		if emitters[k].part == p then
			table.remove(emitters, k)
		end
	end
	for k = #flags, 1, -1 do
		if flags[k].part == p then
			table.remove(flags, k)
		end
	end
end

local function watch(tag: string, add: (Instance) -> ())
	for _, p in CollectionService:GetTagged(tag) do
		add(p)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(forget)
end

-- the bird pool: one folder per flock, its birds made once
type Flock = { cfg: A.Flock, birds: { BasePart }, folder: Folder, near: boolean }
local flocks: { Flock } = {}

local function makeFlocks()
	local holder = Instance.new("Folder")
	holder.Name = "AmbientBirds"
	for _, cfg in A.Flocks do
		local folder = Instance.new("Folder")
		local birds = {}
		for _ = 1, A.Birds do
			local b = Instance.new("Part")
			b.Anchored = true
			b.CanCollide = false
			b.CanQuery = false
			b.CanTouch = false
			b.CastShadow = false
			b.Size = Vector3.new(A.BirdSize[1], A.BirdSize[2], A.BirdSize[3])
			b.Color = rgb(A.BirdColour)
			b.Material = Enum.Material.SmoothPlastic
			b.Parent = folder
			table.insert(birds, b)
		end
		table.insert(flocks, { cfg = cfg, birds = birds, folder = folder, near = false })
	end
	holder.Parent = workspace
	return holder
end

function Ambient.start()
	watch(A.Tags.Spray, addSpray)
	watch(A.Tags.Steam, addSteam)
	watch(A.Tags.Flag, addFlag)
	local holder = makeFlocks()
	local camera = workspace.CurrentCamera
	local flagNear: { [BasePart]: boolean } = {}

	-- every CheckEvery: switch emitters, flags and flocks on near the camera, off away from it
	task.spawn(function()
		while true do
			local eye = (workspace.CurrentCamera or camera).CFrame.Position
			for _, e in emitters do
				e.emitter.Enabled = e.part.Parent ~= nil
					and (e.part.Position - eye).Magnitude < range
			end
			for _, f in flags do
				flagNear[f.part] = (f.hinge - eye).Magnitude < range
			end
			for _, fl in flocks do
				local near = (Vector3.new(fl.cfg.x, fl.cfg.height, fl.cfg.z) - eye).Magnitude
					< range + fl.cfg.radius
				if near ~= fl.near then
					fl.near = near
					fl.folder.Parent = if near then holder else nil
				end
			end
			task.wait(A.CheckEvery)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		-- banners sway about their pole
		local sway = math.rad(A.Flag.Degrees)
		local w = math.pi * 2 / A.Flag.Period
		for _, f in flags do
			if flagNear[f.part] and f.part.Parent then
				local a = math.sin(t * w + f.phase) * sway
				f.part.CFrame = CFrame.new(f.hinge)
					* CFrame.Angles(0, a, 0)
					* CFrame.new(-f.hinge)
					* f.base
			end
		end
		-- birds circle, bob and flap
		local flap = math.rad(A.Flap.Degrees)
		local fw = math.pi * 2 / A.Flap.Period
		for k, fl in flocks do
			if fl.near then
				local c = fl.cfg
				local a = t * math.pi * 2 / A.FlockLap + k * 2.1
				local centre = Vector3.new(
					c.x + math.cos(a) * c.radius,
					c.height + math.sin(a * 2) * A.Bob,
					c.z + math.sin(a) * c.radius
				)
				-- flying round the circle: heading along its tangent
				local ahead = Vector3.new(-math.sin(a), 0, math.cos(a))
				local frame = CFrame.lookAt(centre, centre + ahead)
				for n, b in fl.birds do
					local i = n - (A.Birds + 1) / 2 -- 0 at the lead bird
					local back = math.abs(i) * A.BirdGap
					local offset = Vector3.new(i * A.BirdGap, math.sin(i) * A.Stagger, back)
					b.CFrame = frame
						* CFrame.new(offset)
						* CFrame.Angles(0, 0, math.sin(t * fw + n) * flap)
				end
			end
		end
	end)
end

return Ambient
