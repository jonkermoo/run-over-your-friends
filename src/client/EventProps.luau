--!strict
-- The new events' things on this screen (server/EventProps): the Money Truck and the Boss Truck are drawn here
-- from the route in workspace attributes (Rules/Route), with a health bar over them, the boss's slam ring, and
-- a crash report when this player's car runs into one at speed (Net HitEventProp; the car bounces off). The
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
local Route = require(ReplicatedStorage.Shared.Rules.Route)
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
local routeText = ""
local path: Route.Path? = nil
local y, groundAt, spin = 0, 0, 0
local brokenAt: number? = nil -- the server time it was cracked or beaten, once this screen has thrown it
local hitAt = 0
local ring: BasePart? = nil

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
	-- the health bar: the name over a bar with what's left
	local H = Config.HpBar
	local color = if which == "BossTruck" then C.red else C.gold
	local bar = c.bar
	bar.Name = "HpBar"
	bar.Size = UDim2.fromOffset(H.Width, H.Height + H.Text + 4)
	bar.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + H.Above, 0)
	bar.LightInfluence = 0
	bar.AlwaysOnTop = true
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
	local count = Style.label(back, "", H.Height - 6, F.heavy, C.text)
	count.Size = UDim2.fromScale(1, 1)
	count.ZIndex = 2
	Style.outline(count, 2)
	c.count = count
	bar.Parent = body
	model.Parent = folder
	return c
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

local function slamRing(): BasePart
	local r = ring
	if r then
		return r
	end
	local part = Instance.new("Part")
	part.Name = "SlamRing"
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = C.red
	part.Transparency = 1
	part.Parent = folder
	ring = part
	return part
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

local function stepTruck(dt: number)
	local which = workspace:GetAttribute("EventProp")
	local text = workspace:GetAttribute("EventRoute")
	local at = workspace:GetAttribute("EventRouteAt")
	if
		(which ~= "MoneyTruck" and which ~= "BossTruck")
		or typeof(text) ~= "string"
		or typeof(at) ~= "number"
	then
		if copy then
			reset(copy)
			copy = nil
		end
		if ring then
			ring.Transparency = 1
		end
		routeText, path, brokenAt = "", nil, nil
		return
	end
	if text ~= routeText then
		routeText = text
		path = Route.build(Route.decode(text), Config.RouteLane, Config.RouteCorner)
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
		groundAt, brokenAt = 0, nil
	end
	local c = copy :: Copy
	local p = path :: Route.Path
	local now = workspace:GetServerTimeNow()
	local speed = cfgOf(which).Speed
	local x, z, hx, hz = Route.at(p, speed * (now - at))
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
		if ring then
			ring.Transparency = 1
		end
		return
	end
	if os.clock() >= groundAt then
		groundAt = os.clock() + 0.25
		local map = workspace:FindFirstChild("Map")
		if map then
			groundParams.FilterDescendantsInstances = { map }
			local hit =
				workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -240, 0), groundParams)
			y = if hit then hit.Position.Y else y
		end
	end
	local yaw = math.atan2(-hx, -hz)
	c.body.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0) * c.rel
	spin -= speed * dt / (1.6 * cfgOf(which).Scale)
	for _, m in c.wheels do
		m.Transform = CFrame.Angles(spin, 0, 0)
	end
	-- the boss's slam: a red ring grows on the ground before it lands
	if which == "BossTruck" then
		local r = slamRing()
		local slamAt = workspace:GetAttribute("BossSlamAt")
		local left = if typeof(slamAt) == "number" then slamAt - now else math.huge
		local B = Config.BossTruck
		if left <= B.SlamWarn and left > -0.15 then
			local k = math.clamp(1 - left / B.SlamWarn, 0.05, 1)
			local d = B.SlamRadius * 2 * k
			r.Size = Vector3.new(0.4, d, d)
			r.CFrame = CFrame.new(x, y + 0.3, z) * CFrame.Angles(0, 0, math.pi / 2)
			r.Transparency = 0.35 + 0.4 * (1 - k)
		else
			r.Transparency = 1
		end
	end
	checkHit(c, x, z, hx, hz, speed)
end

-- the crate: lifted on this screen while it falls (the server keeps it where it lands)
type Fall = { landAt: number, height: number, crate: CFrame, chute: CFrame }
local fall: Fall? = nil

local function stepCrate()
	local props = workspace:FindFirstChild("EventProps")
	local model = props and props:FindFirstChild("CashDrop")
	local crate = model and model:FindFirstChild("Crate") :: BasePart?
	local chute = model and model:FindFirstChild("Chute") :: BasePart?
	local landAt = model and model:GetAttribute("LandAt")
	if not (model and crate and chute and typeof(landAt) == "number") then
		fall = nil
		return
	end
	local f = fall
	if not f or f.landAt ~= landAt then
		local h = model:GetAttribute("FallHeight")
		f = {
			landAt = landAt,
			height = if typeof(h) == "number" then h else 0,
			crate = crate.CFrame,
			chute = chute.CFrame,
		}
		fall = f
	end
	local ff = f :: Fall
	local left = ff.landAt - workspace:GetServerTimeNow()
	local lift = math.max(left, 0) / Config.CashDrop.FallSeconds * ff.height
	local sway = if left > 0 then math.sin(os.clock() * 1.3) * 0.12 else 0
	local tilt = CFrame.Angles(sway, 0, sway * 0.6)
	crate.CFrame = (ff.crate + Vector3.new(0, lift, 0)) * tilt
	chute.CFrame = (ff.chute + Vector3.new(0, lift, 0)) * tilt
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
		local crate = model and model:FindFirstChild("Crate") :: BasePart?
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
