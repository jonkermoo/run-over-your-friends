--!strict
-- City traffic on this screen: draws the server's traffic cars (TrafficService snapshots) from pooled copies of
-- the vehicle models, a little in the past so they glide between snapshots; only the nearest few, near the
-- camera. While you drive, running into one at speed reports the crash (the server checks and pays), flings
-- it at once and bumps your own vehicle. A wreck tumbles for a few seconds, fades and goes back to the pool.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Cfg = require(ReplicatedStorage.Shared.Config.Traffic)
local Net = require(ReplicatedStorage.Shared.Net)
local Paints = require(ReplicatedStorage.Shared.Config.Paints)
local Roads = require(ReplicatedStorage.Shared.Rules.Roads)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Drive = require(script.Parent.Drive)

local Traffic = {}

type Snap = { t: number, x: number, z: number, yaw: number, speed: number }
type Copy = {
	kind: number,
	model: Model,
	body: BasePart,
	rel: CFrame, -- body from the car's bottom-centre frame
	paint: BasePart?,
	wheels: { Motor6D },
	halfW: number,
	halfL: number,
	weight: number,
	parts: { { part: BasePart, transparency: number } },
}
type Car = {
	id: number,
	kind: number,
	paint: number,
	gen: number,
	a: Snap?, -- the two snapshots drawn between
	b: Snap,
	copy: Copy?,
	y: number,
	groundAt: number,
	spin: number,
	x: number,
	z: number,
	yaw: number,
}

local folder = Instance.new("Folder")
folder.Name = "Traffic"
folder.Parent = workspace

local cars: { [number]: Car } = {}
local pool: { [number]: { Copy } } = {}
-- car id -> the gen flung here and when: hidden until a new gen shows up, or (if the server didn't agree it
-- was a crash and keeps sending it) shown again after a moment
local wrecked: { [number]: { gen: number, at: number } } = {}
local hitAt: { [number]: number } = {}
local maxShown = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	then Cfg.ShownPhone
	else Cfg.ShownMax

local KEEP = { Body = true, Paint = true, Glass = true }

-- a stripped copy of a vehicle model (body, paint, glass, wheels) welded to its body, anchored, no collisions
local function build(kind: number): Copy?
	local id = Cfg.Kinds[kind].id
	local models = ReplicatedStorage:FindFirstChild("VehicleModels")
	local source = models and models:FindFirstChild(id)
	if not source then
		return nil
	end
	local model = source:Clone() :: Model
	model.WorldPivot = CFrame.identity
	model:ScaleTo(Game.VehicleScale) -- as big as the players' own (VehicleBuilder)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not KEEP[d.Name] and string.sub(d.Name, 1, 6) ~= "Wheel_" then
			d:Destroy()
		end
	end
	local body = model:FindFirstChild("Body") :: BasePart?
	if not body then
		model:Destroy()
		return nil
	end
	local cf, size = model:GetBoundingBox()
	local bottom = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))
	local copy: Copy = {
		kind = kind,
		model = model,
		body = body,
		rel = bottom:Inverse() * body.CFrame,
		paint = model:FindFirstChild("Paint") :: BasePart?,
		wheels = {},
		halfW = size.X / 2,
		halfL = size.Z / 2,
		weight = (Vehicles.ById[id] and Vehicles.ById[id].weight) or 1500,
		parts = {},
	}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = p == body
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = p == body
			p.CollisionGroup = "Vehicles"
			table.insert(copy.parts, { part = p, transparency = p.Transparency })
			if p ~= body then
				if string.sub(p.Name, 1, 6) == "Wheel_" then
					local m = Instance.new("Motor6D")
					m.Part0 = body
					m.Part1 = p
					m.C0 = body.CFrame:Inverse() * p.CFrame
					m.Parent = p
					table.insert(copy.wheels, m)
				else
					local w = Instance.new("WeldConstraint")
					w.Part0 = body
					w.Part1 = p
					w.Parent = p
				end
			end
		end
	end
	if copy.paint then
		copy.paint:SetAttribute("Factory", copy.paint.Color)
	end
	model.Parent = folder
	body.CFrame = CFrame.new(0, -500, 0)
	return copy
end

local function take(kind: number): Copy?
	local list = pool[kind]
	if list and #list > 0 then
		return table.remove(list)
	end
	return build(kind)
end

local function give(copy: Copy)
	copy.body.Anchored = true
	copy.body.CanCollide = false
	copy.body.AssemblyLinearVelocity = Vector3.zero
	copy.body.AssemblyAngularVelocity = Vector3.zero
	for _, e in copy.parts do
		e.part.Transparency = e.transparency
	end
	copy.body.CFrame = CFrame.new(0, -500, 0)
	pool[copy.kind] = pool[copy.kind] or {}
	table.insert(pool[copy.kind], copy)
end

local function setPaint(copy: Copy, paint: number)
	if not copy.paint then
		return
	end
	local p = Paints.List[paint]
	local rgb = p and p.rgb
	copy.paint.Color = if rgb
		then Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		else copy.paint:GetAttribute("Factory") :: Color3
end

-- send a drawn car flying; it tumbles on this screen only, then fades and goes back to the pool
local function fling(car: Car, push: Vector3)
	local copy = car.copy
	car.copy = nil
	wrecked[car.id] = { gen = car.gen, at = os.clock() }
	if not copy then
		return
	end
	copy.body.Anchored = false
	copy.body.CanCollide = true
	copy.body.AssemblyLinearVelocity = push
	copy.body.AssemblyAngularVelocity =
		Vector3.new(math.random() * 10 - 5, math.random() * 10 - 5, math.random() * 10 - 5)
	task.delay(Cfg.WreckSeconds, function()
		for _, e in copy.parts do
			TweenService:Create(e.part, TweenInfo.new(Cfg.FadeSeconds), { Transparency = 1 }):Play()
		end
		task.delay(Cfg.FadeSeconds + 0.1, give, copy)
	end)
end

local function onSnapshot(b: unknown)
	if typeof(b) ~= "buffer" then
		return
	end
	local t = buffer.readf64(b, 0)
	local n = buffer.readu8(b, 8)
	local seen: { [number]: boolean } = {}
	for k = 1, n do
		local o = 9 + (k - 1) * Roads.CarBytes
		local id = buffer.readu8(b, o)
		local kind = buffer.readu8(b, o + 1)
		local paint = buffer.readu8(b, o + 2)
		local gen = buffer.readu8(b, o + 3)
		local snap: Snap = {
			t = t,
			x = buffer.readf32(b, o + 4),
			z = buffer.readf32(b, o + 8),
			yaw = Roads.u16ToYaw(buffer.readu16(b, o + 12)),
			speed = buffer.readu16(b, o + 14) / 10,
		}
		seen[id] = true
		local car = cars[id]
		if car and car.gen ~= gen then
			-- placed again somewhere else: start over
			if car.copy then
				give(car.copy)
			end
			cars[id] = nil
			car = nil
		end
		if not car then
			cars[id] = {
				id = id,
				kind = kind,
				paint = paint,
				gen = gen,
				a = nil,
				b = snap,
				copy = nil,
				y = 0,
				groundAt = 0,
				spin = 0,
				x = snap.x,
				z = snap.z,
				yaw = snap.yaw,
			}
		else
			car.a, car.b = car.b, snap
		end
		local w = wrecked[id]
		if w and (w.gen ~= gen or os.clock() - w.at > 2) then
			wrecked[id] = nil
		end
	end
	-- cars the server no longer sends (wrecked, or gone): let go of their copies; one that gave up waiting
	-- behind a player fades away where it stands
	for id, car in cars do
		if not seen[id] then
			local copy = car.copy
			if copy then
				for _, e in copy.parts do
					TweenService
						:Create(e.part, TweenInfo.new(Cfg.FadeSeconds), { Transparency = 1 })
						:Play()
				end
				task.delay(Cfg.FadeSeconds + 0.1, give, copy)
			end
			cars[id] = nil
		end
	end
end

local function onCrash(id: unknown, gen: unknown, push: unknown, _userId: unknown)
	if typeof(id) ~= "number" or typeof(push) ~= "Vector3" then
		return
	end
	local car = cars[id]
	local w = wrecked[id :: number]
	if car and car.gen == gen and not (w and w.gen == gen) then
		fling(car, push)
	end
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

local function angleLerp(a: number, b: number, k: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * k
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local eye = camera.CFrame.Position
	local now = workspace:GetServerTimeNow()
	local drawAt = now - Cfg.Delay
	local map = workspace:FindFirstChild("Map")
	if map then
		groundParams.FilterDescendantsInstances = { map }
	end
	-- where each car is now
	local order: { Car } = {}
	local dist: { [Car]: number } = {}
	for id, car in cars do
		local a, b = car.a, car.b
		if a and drawAt <= b.t and b.t > a.t then
			local k = math.clamp((drawAt - a.t) / (b.t - a.t), 0, 1)
			car.x = a.x + (b.x - a.x) * k
			car.z = a.z + (b.z - a.z) * k
			car.yaw = angleLerp(a.yaw, b.yaw, k)
		else
			-- past the newest snapshot: carry on along the heading for a moment
			local ahead = math.clamp(drawAt - b.t, 0, 0.5) * b.speed
			car.x = b.x - math.sin(b.yaw) * ahead
			car.z = b.z - math.cos(b.yaw) * ahead
			car.yaw = b.yaw
		end
		local w = wrecked[id]
		if w and w.gen == car.gen then
			continue
		end
		local d2 = (car.x - eye.X) ^ 2 + (car.z - eye.Z) ^ 2
		if d2 < Cfg.DrawRadius ^ 2 then
			table.insert(order, car)
			dist[car] = d2
		elseif car.copy then
			give(car.copy)
			car.copy = nil
		end
	end
	table.sort(order, function(p, q)
		return dist[p] < dist[q]
	end)
	local parts, cframes = {}, {}
	for n, car in order do
		if n > maxShown then
			if car.copy then
				give(car.copy)
				car.copy = nil
			end
			continue
		end
		if not car.copy then
			local copy = take(car.kind)
			if not copy then
				continue
			end
			setPaint(copy, car.paint)
			car.copy = copy
			car.groundAt = 0
		end
		local copy = car.copy :: Copy
		if os.clock() >= car.groundAt then
			car.groundAt = os.clock() + Cfg.GroundEvery
			local hit = workspace:Raycast(
				Vector3.new(car.x, 40, car.z),
				Vector3.new(0, -80, 0),
				groundParams
			)
			car.y = if hit then hit.Position.Y else 0.1
		end
		table.insert(parts, copy.body)
		table.insert(
			cframes,
			CFrame.new(car.x, car.y, car.z) * CFrame.Angles(0, car.yaw, 0) * copy.rel
		)
		-- wheels roll with the car's speed
		car.spin -= car.b.speed * dt / 1.6
		for _, m in copy.wheels do
			m.Transform = CFrame.Angles(car.spin, 0, 0)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- crashes: only the driver's own screen checks its own vehicle
	local mine = Drive.view.car
	local chassis = mine and mine.PrimaryPart
	if not (Drive.state.driving and chassis) then
		return
	end
	local stats = Vehicles.ById[(mine :: Model):GetAttribute("VehicleId") :: any]
	local vel = chassis.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local cf = chassis.CFrame
	local fwd = cf.LookVector * Vector3.new(1, 0, 1)
	if fwd.Magnitude < 0.1 then
		return
	end
	fwd = fwd.Unit
	local clock = os.clock()
	for n, car in order do
		local copy = car.copy
		if n > maxShown or not copy or (hitAt[car.id] or 0) + 1 > clock then
			continue
		end
		local cx, cz = car.x, car.z
		if (cx - cf.Position.X) ^ 2 + (cz - cf.Position.Z) ^ 2 > 50 * 50 then
			continue
		end
		local hx, hz = -math.sin(car.yaw), -math.cos(car.yaw)
		local touching = Roads.overlap(
			cf.Position.X,
			cf.Position.Z,
			fwd.X,
			fwd.Z,
			chassis.Size.X / 2 + 0.5,
			chassis.Size.Z / 2 + 0.5,
			cx,
			cz,
			hx,
			hz,
			copy.halfW,
			copy.halfL
		)
		if not touching then
			continue
		end
		local carVel = Vector3.new(hx, 0, hz) * car.b.speed
		local closing = (vel - carVel).Magnitude / Vehicles.StudsPerMetre
		if closing < Cfg.CrashSpeed then
			continue
		end
		hitAt[car.id] = clock
		Net.waitFor("HitTraffic"):FireServer(car.id, chassis.AssemblyLinearVelocity)
		-- show it at once; the server's word (TrafficCrash) then flings it on everyone else's screen
		fling(
			car,
			(vel - carVel) * Cfg.FlingAlong
				+ Vector3.new(0, Cfg.FlingUp + closing * Cfg.FlingUpPerMs, 0)
		)
		-- the hit costs speed, less the heavier you are
		local w = (stats and stats.weight) or 1500
		local keep = 1 - Cfg.BumpShare * copy.weight / (copy.weight + w)
		chassis.AssemblyLinearVelocity = Vector3.new(
			chassis.AssemblyLinearVelocity.X * keep,
			chassis.AssemblyLinearVelocity.Y,
			chassis.AssemblyLinearVelocity.Z * keep
		)
	end
end

function Traffic.start()
	Net.waitFor("Traffic").OnClientEvent:Connect(onSnapshot)
	Net.waitFor("TrafficCrash").OnClientEvent:Connect(onCrash)
	RunService.RenderStepped:Connect(step)
end

return Traffic
