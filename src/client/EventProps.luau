--!strict
-- The new events' things on this screen (server/EventProps): the Money Truck and the Boss Truck are drawn here
-- where the server says they are (the EventPose attribute, drawn Truck.Delay behind and eased between poses),
-- with a health bar over them, thrown as a real body when a hit knocks them, and a crash report when this
-- player's car runs into one at speed (Net HitEventProp; the car bounces off). The
-- Cash Drop's crate is a real part on the street; here it's lifted while it falls. target() tells the finder
-- (client/GiantFinder) what to point at. Numbers: Config/Events.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Events)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Net = require(ReplicatedStorage.Shared.Net)
local Roads = require(ReplicatedStorage.Shared.Rules.Roads)
local EventRules = require(ReplicatedStorage.Shared.Rules.Events)
local VehicleParts = require(ReplicatedStorage.Shared.VehicleParts)
local Drive = require(script.Parent.Drive)
local Style = require(script.Parent.Style)

local EventProps = {}

local C, F = Style.colors, Style.fonts
local KEEP =
	{ Body = true, Paint = true, Glass = true, Lamp = true, Tail = true, Trim = true, Plate = true }

type Copy = {
	which: string,
	model: Model,
	body: BasePart,
	rel: CFrame,
	wheels: { Motor6D },
	parts: { { part: BasePart, transparency: number } },
	halfW: number,
	halfL: number,
	height: number,
	bar: BillboardGui,
	fill: Frame,
	count: TextLabel,
}

local folder = Instance.new("Folder")
folder.Name = "EventVehicles"
local pool: { [string]: Copy } = {}
local copy: Copy? = nil -- the one on the road now
local samples: { { t: number, x: number, z: number, yaw: number } } = {} -- the server's latest poses
local y: number? = nil -- the ground under it
local groundAt, spin = 0, 0
local brokenAt: number? = nil -- the server time it was cracked or beaten, once this screen has thrown it
local knockAt: number? = nil -- the last knock this screen has seen
local flying: { at: number, untilAt: number }? = nil -- thrown: physics has it until untilAt (server time)
local settling: { from: CFrame, at: number }? = nil -- easing back to its pose after a throw
local SETTLE = 0.6 -- seconds
local hitAt = 0

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

local function cfgOf(which: string): typeof(Config.MoneyTruck) | typeof(Config.BossTruck)
	return if which == "BossTruck" then Config.BossTruck else Config.MoneyTruck
end

local function titleOf(which: string): string
	for _, e in Config.List do
		if e.key == which then
			return e.title
		end
	end
	return which
end

-- a stripped, anchored copy of the event vehicle (as client/Traffic makes its cars), painted, with a health bar
local function build(which: string): Copy?
	local cfg = cfgOf(which)
	local models = ReplicatedStorage:FindFirstChild("VehicleModels")
	local source = models and models:FindFirstChild(cfg.Vehicle)
	if not source then
		return nil
	end
	local model = source:Clone() :: Model
	VehicleParts.fit(model, {})
	model.WorldPivot = CFrame.identity
	model:ScaleTo(Game.VehicleScale * cfg.Scale)
	for _, d in model:GetDescendants() do
		if
			d:IsA("BasePart")
			and not KEEP[d.Name]
			and string.sub(d.Name, 1, 6) ~= "Wheel_"
			and not string.match(d.Name, "^Z%d")
		then
			d:Destroy()
		end
	end
	local body = model:FindFirstChild("Body") :: BasePart?
	if not body then
		model:Destroy()
		return nil
	end
	local paint = Color3.fromRGB(cfg.Paint[1], cfg.Paint[2], cfg.Paint[3])
	for _, part in VehicleParts.paintParts(model) do
		part.Color = paint
	end
	if which == "MoneyTruck" then
		local t = Config.MoneyTruck.Trim
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Trim" then
				d.Color = Color3.fromRGB(t[1], t[2], t[3])
			end
		end
	end
	local cf, size = model:GetBoundingBox()
	local bottom = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))
	local c: Copy = {
		which = which,
		model = model,
		body = body,
		rel = bottom:Inverse() * body.CFrame,
		wheels = {},
		parts = {},
		halfW = size.X / 2,
		halfL = size.Z / 2,
		height = size.Y,
		bar = Instance.new("BillboardGui"),
		fill = Instance.new("Frame"),
		count = Instance.new("TextLabel"),
	}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = p == body
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CollisionGroup = "Vehicles"
			table.insert(c.parts, { part = p, transparency = p.Transparency })
			if p ~= body then
				if string.sub(p.Name, 1, 6) == "Wheel_" then
					local m = Instance.new("Motor6D")
					m.Part0 = body
					m.Part1 = p
					m.C0 = body.CFrame:Inverse() * p.CFrame
					m.Parent = p
					table.insert(c.wheels, m)
				else
					local w = Instance.new("WeldConstraint")
					w.Part0 = body
					w.Part1 = p
					w.Parent = p
				end
			end
		end
	end
	-- the health bar: the name over a bar with what's left, as wide as the name needs
	local H = Config.HpBar
	local color = if which == "BossTruck" then C.red else C.gold
	local bar = c.bar
	bar.Name = "HpBar"
	local tall = H.Height + H.Text + 4
	bar.Size = UDim2.fromOffset(H.MinWidth, tall)
	bar.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + H.Above, 0)
	bar.LightInfluence = 0
	bar.AlwaysOnTop = false -- buildings in front hide it, like the finder's column
	bar.MaxDistance = 900
	bar.Adornee = body
	local name = Style.label(bar, titleOf(which), H.Text, F.display, C.text)
	name.Size = UDim2.new(1, 0, 0, H.Text + 2)
	Style.outline(name, 2)
	local back, fill = Style.bar(bar, color)
	back.Position = UDim2.fromOffset(0, H.Text + 4)
	back.Size = UDim2.new(1, 0, 0, H.Height)
	fill.Size = UDim2.fromScale(1, 1)
	c.fill = fill
	local count = Style.label(back, "", H.Count, F.heavy, C.text)
	count.Size = UDim2.fromScale(1, 1)
	count.ZIndex = 2
	Style.outline(count, 1)
	c.count = count
	name:GetPropertyChangedSignal("TextBounds"):Connect(function()
		bar.Size =
			UDim2.fromOffset(math.max(H.MinWidth, math.ceil(name.TextBounds.X) + H.Pad), tall)
	end)
	bar.Parent = body
	model.Parent = folder
	return c
end

-- this player's car ran into the truck: report it and bounce off
local function checkHit(c: Copy, x: number, z: number, hx: number, hz: number, speed: number)
	local mine = Drive.view.car
	local chassis = mine and mine.PrimaryPart
	if not (Drive.state.driving and chassis) or os.clock() < hitAt + Config.HitGap then
		return
	end
	local cf = chassis.CFrame
	local fwd = cf.LookVector * Vector3.new(1, 0, 1)
	if fwd.Magnitude < 0.1 then
		return
	end
	fwd = fwd.Unit
	local touching = Roads.overlap(
		cf.Position.X,
		cf.Position.Z,
		fwd.X,
		fwd.Z,
		chassis.Size.X / 2 + 0.5,
		chassis.Size.Z / 2 + 0.5,
		x,
		z,
		hx,
		hz,
		c.halfW,
		c.halfL
	)
	if not touching then
		return
	end
	local vel = chassis.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local truckVel = Vector3.new(hx, 0, hz) * speed
	if (vel - truckVel).Magnitude / Vehicles.StudsPerMetre < Config.CrashSpeed then
		return
	end
	-- you have to drive into it: a car sat in its way doesn't count
	local toward = Vector3.new(x - cf.Position.X, 0, z - cf.Position.Z)
	if
		toward.Magnitude > 0.1
		and vel:Dot(toward.Unit) / Vehicles.StudsPerMetre < Config.CrashSpeed
	then
		return
	end
	hitAt = os.clock()
	Net.waitFor("HitEventProp"):FireServer(chassis.AssemblyLinearVelocity)
	-- bounce off, away from the truck's middle
	local away = (cf.Position - Vector3.new(x, cf.Position.Y, z)) * Vector3.new(1, 0, 1)
	away = if away.Magnitude > 0.1 then away.Unit else -fwd
	chassis.AssemblyLinearVelocity = away * vel.Magnitude * Config.Bounce
		+ Vector3.new(0, Config.BounceUp, 0)
end

local function reset(c: Copy)
	c.body.Anchored = true
	c.body.AssemblyLinearVelocity = Vector3.zero
	c.body.AssemblyAngularVelocity = Vector3.zero
	for _, e in c.parts do
		e.part.Transparency = e.transparency
		e.part.CanCollide = false
	end
	c.bar.Enabled = true
	c.body.CFrame = CFrame.new(0, -500, 0)
end

-- the cracked or beaten truck tumbles over and fades on this screen
local function wreck(c: Copy)
	c.bar.Enabled = false
	c.body.Anchored = false
	c.body.CanCollide = true
	c.body.AssemblyLinearVelocity = Vector3.new(0, 60, 0) + c.body.CFrame.LookVector * 20
	c.body.AssemblyAngularVelocity = Vector3.new(math.random() * 4 - 2, 0, math.random() * 4 - 2)
	task.delay(4, function()
		if copy ~= c then
			return
		end
		for _, e in c.parts do
			TweenService:Create(e.part, TweenInfo.new(1.5), { Transparency = 1 }):Play()
		end
	end)
end

-- where the server says the truck is, Truck.Delay seconds back (between the two poses either side of then):
-- x, z, unit heading hx, hz, speed studs/s. nil before the first pose.
local function poseAt(rt: number): (number?, number, number, number, number)
	local n = #samples
	if n == 0 then
		return nil, 0, 0, 0, 0
	end
	local a, b = samples[1], samples[1]
	for i = 2, n do
		b = samples[i]
		if b.t >= rt then
			a = samples[i - 1]
			break
		end
		a = b
	end
	local dt = b.t - a.t
	local k = if dt > 1e-3 then math.clamp((rt - a.t) / dt, 0, 1.5) else 1
	local turn = (b.yaw - a.yaw + math.pi) % (math.pi * 2) - math.pi
	local yaw = a.yaw + turn * math.min(k, 1)
	local speed = if dt > 1e-3 then math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2) / dt else 0
	return a.x + (b.x - a.x) * k, a.z + (b.z - a.z) * k, -math.sin(yaw), -math.cos(yaw), speed
end

-- a new pose from the server (EventPose: x, seconds since it set off, z, turned to its heading)
local function takePose(cf: CFrame)
	local t = cf.Position.Y
	local last = samples[#samples]
	if last and t <= last.t then
		if t < last.t - 1 then
			table.clear(samples) -- a new truck
		else
			return
		end
	end
	local look = cf.LookVector
	table.insert(
		samples,
		{ t = t, x = cf.Position.X, z = cf.Position.Z, yaw = math.atan2(-look.X, -look.Z) }
	)
	if #samples > 20 then
		table.remove(samples, 1)
	end
end

-- a hit throws this screen's copy as a real body: off it flies and tumbles, and once the server has it stopped
-- it eases back to where the server says it is
local function throw(c: Copy, kv: Vector3, kat: number, which: string)
	local K = cfgOf(which).Knock
	local g = workspace.Gravity
	local air = EventRules.airTime(kv.Y, g)
	local flat = kv * Vector3.new(1, 0, 1)
	local skid = flat.Magnitude / Config.Truck.SkidDecel
	local axis = if flat.Magnitude > 0.1
		then Vector3.new(0, 1, 0):Cross(flat.Unit)
		else Vector3.new(1, 0, 0)
	local turns = math.max(K.Flips, 0)
	local rate = if air > 0 and turns > 0 then math.pi * 2 * turns / air else 0.8
	c.body.Anchored = false
	c.body.CanCollide = true
	c.body.AssemblyLinearVelocity = kv
	c.body.AssemblyAngularVelocity = axis * rate + Vector3.new(0, (math.random() - 0.5) * 1.5, 0)
	flying = { at = kat, untilAt = kat + air + skid + 0.3 }
end

local function stepTruck(dt: number)
	local which = workspace:GetAttribute("EventProp")
	local epoch = workspace:GetAttribute("EventEpoch")
	if (which ~= "MoneyTruck" and which ~= "BossTruck") or typeof(epoch) ~= "number" then
		if copy then
			reset(copy)
			copy = nil
		end
		table.clear(samples)
		brokenAt, flying, settling, knockAt = nil, nil, nil, nil
		return
	end
	local pose = workspace:GetAttribute("EventPose")
	if typeof(pose) == "CFrame" then
		takePose(pose)
	end
	if not copy or copy.which ~= which then
		if copy then
			reset(copy)
		end
		local c = pool[which] or build(which)
		if not c then
			return
		end
		pool[which] = c
		reset(c)
		copy = c
		groundAt, brokenAt, flying, settling, knockAt = 0, nil, nil, nil, nil
		y = nil
	end
	local c = copy :: Copy
	local now = workspace:GetServerTimeNow()
	local x, z, hx, hz, speed = poseAt(now - epoch - Config.Truck.Delay)
	if not x then
		return
	end
	-- health
	local hp, hpMax = workspace:GetAttribute("EventHp"), workspace:GetAttribute("EventHpMax")
	if typeof(hp) == "number" and typeof(hpMax) == "number" and hpMax > 0 then
		c.fill.Size = UDim2.fromScale(math.clamp(hp / hpMax, 0, 1), 1)
		c.count.Text = `{math.ceil(hp)} / {math.ceil(hpMax)}`
	end
	local broken = workspace:GetAttribute("EventBroken")
	if typeof(broken) == "number" then
		if brokenAt ~= broken then
			brokenAt = broken
			wreck(c)
		end
		return
	end
	-- a new knock: throw it
	local kv, kat = workspace:GetAttribute("EventKnock"), workspace:GetAttribute("EventKnockAt")
	if typeof(kv) == "Vector3" and typeof(kat) == "number" and kat ~= knockAt then
		knockAt = kat
		if now - kat < 1 then
			throw(c, kv, kat, which)
		end
	end
	if os.clock() >= groundAt or y == nil then
		groundAt = os.clock() + 0.25
		local map = workspace:FindFirstChild("Map")
		if map then
			groundParams.FilterDescendantsInstances = { map }
			-- from just over the last ground, so a roof or floor above isn't taken for it
			local from = if y then y + 8 else 200
			local hit = workspace:Raycast(
				Vector3.new(x, from, z),
				Vector3.new(0, -(from + 60), 0),
				groundParams
			)
			y = if hit then hit.Position.Y else (y or 0)
		end
	end
	local yaw = math.atan2(-hx, -hz)
	local place = CFrame.new(x, y :: number, z) * CFrame.Angles(0, yaw, 0) * c.rel
	local f = flying
	if f then
		if now < f.untilAt then
			return -- physics has it
		end
		flying = nil
		settling = { from = c.body.CFrame, at = os.clock() }
		c.body.Anchored = true
		c.body.CanCollide = false
	end
	local s = settling
	if s then
		local k = math.clamp((os.clock() - s.at) / SETTLE, 0, 1)
		k = k * k * (3 - 2 * k)
		c.body.CFrame = s.from:Lerp(place, k)
		if k >= 1 then
			settling = nil
		end
		return
	end
	c.body.CFrame = place
	spin -= speed * dt / (1.6 * cfgOf(which).Scale)
	for _, m in c.wheels do
		m.Transform = CFrame.Angles(spin, 0, 0)
	end
	checkHit(c, x, z, hx, hz, speed)
end

-- the airdrop: lifted on this screen while it falls (the server keeps it where it lands), swaying under its
-- canopy about the crate's top
type Fall = {
	landAt: number,
	height: number,
	pivot: CFrame,
	parts: { { part: BasePart, rel: CFrame } },
}
local fall: Fall? = nil

local function stepCrate()
	local props = workspace:FindFirstChild("EventProps")
	local model = props and props:FindFirstChild("CashDrop") :: Model?
	local crate = model and model.PrimaryPart
	local landAt = model and model:GetAttribute("LandAt")
	if not (model and crate and typeof(landAt) == "number") then
		fall = nil
		return
	end
	local f = fall
	if not f or f.landAt ~= landAt then
		local h = model:GetAttribute("FallHeight")
		-- sway about the middle of the crate's lid
		local pivot = crate.CFrame + Vector3.new(0, crate.Size.Y / 2, 0)
		local parts = {}
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") and p.Name ~= "Ring" then
				table.insert(parts, { part = p, rel = pivot:ToObjectSpace(p.CFrame) })
			end
		end
		f = {
			landAt = landAt,
			height = if typeof(h) == "number" then h else 0,
			pivot = pivot,
			parts = parts,
		}
		fall = f
	end
	local ff = f :: Fall
	local left = ff.landAt - workspace:GetServerTimeNow()
	local lift = math.max(left, 0) / Config.CashDrop.FallSeconds * ff.height
	local sway = if left > 0 then math.sin(os.clock() * 1.3) * 0.12 else 0
	local at = (ff.pivot + Vector3.new(0, lift, 0)) * CFrame.Angles(sway, 0, sway * 0.6)
	for _, e in ff.parts do
		e.part.CFrame = at * e.rel
	end
end

-- what the finder points at now: a part, the word on its plate and its colour
function EventProps.target(): (BasePart?, string, Color3)
	local which = workspace:GetAttribute("EventProp")
	local c = copy
	if c and c.which == which and not brokenAt then
		local cfg = cfgOf(c.which)
		return c.body, cfg.Mark, if c.which == "BossTruck" then C.red else C.gold
	end
	if which == "CashDrop" then
		local props = workspace:FindFirstChild("EventProps")
		local model = props and props:FindFirstChild("CashDrop")
		local crate = model and (model :: Model).PrimaryPart
		if crate then
			return crate, Config.CashDrop.Mark, C.money
		end
	end
	return nil, "", C.gold
end

function EventProps.start()
	folder.Parent = workspace
	RunService.RenderStepped:Connect(function(dt)
		stepTruck(dt)
		stepCrate()
	end)
end

return EventProps
