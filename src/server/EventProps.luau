--!strict
-- The things the new events put in town (Config/Events): the Money Truck and the Boss Truck, which drive the
-- road network (Rules/Route), and the Cash Drop's crate, plus the cash bundles a truck spills.
-- The trucks have no parts on the server: the route goes in workspace attributes (EventProp, EventRoute,
-- EventRouteAt, EventHp, EventHpMax, EventBroken, BossSlamAt) and every screen draws its own copy
-- (client/EventProps), which reports a crash (Net HitEventProp); it's checked here against where the route says
-- the truck is. The crate and the cash bundles are real parts, made once and kept for the next event.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config.Events)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Roads = require(ReplicatedStorage.Shared.Rules.Roads)
local Route = require(ReplicatedStorage.Shared.Rules.Route)
local Rules = require(ReplicatedStorage.Shared.Rules.Events)
local Analytics = require(script.Parent.Analytics)
local Data = require(script.Parent.Data)
local Passes = require(script.Parent.Passes)
local RateLimit = require(script.Parent.RateLimit)
local TrafficService = require(script.Parent.TrafficService)
local VehicleService = require(script.Parent.VehicleService)

local EventProps = {}

export type Hooks = {
	score: (player: Player, amount: number) -> (), -- the Boss Truck's damage, for the live contest
	won: () -> (), -- claimed, cracked or beaten: the event can end
	paid: (player: Player, kind: string, amount: number) -> (),
}

local MT, CD, BT, CASH = Config.MoneyTruck, Config.CashDrop, Config.BossTruck, Config.Cash
local random = Random.new()
local hooks: Hooks? = nil
local kind: string? = nil -- the live one: "MoneyTruck" | "BossTruck" | "CashDrop"
local beaten = false

-- the route
local nodes: { number } = {}
local points: { { number } } = {}
local path: Route.Path? = nil
local startAt = 0 -- server time it set off
local speed = 0
local halfW, halfL = 0, 0
local hp, hpMax = 0, 0

-- the crate
local crateSpot: Vector3? = nil
local landAt = 0

local folder = Instance.new("Folder")
folder.Name = "EventProps"
local store = Instance.new("Folder")
store.Name = "EventPropsPool"
store.Parent = ServerStorage

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

local function now(): number
	return workspace:GetServerTimeNow()
end

local function groundY(x: number, z: number): number
	local map = workspace:FindFirstChild("Map")
	if map then
		groundParams.FilterDescendantsInstances = { map }
		local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), groundParams)
		if hit then
			return hit.Position.Y
		end
	end
	return 0.1
end

-- a player's spot: their car's middle when they have one out and sit in it, else their body
local function spotOf(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function pay(player: Player, amount: number, what: string): number
	local cash = math.floor(amount * Config.PayScale * Passes.moneyMultiplier(player) + 0.5)
	Data.addMoney(player, cash)
	Analytics.tookPart(player)
	if hooks then
		hooks.paid(player, what, cash)
	end
	return cash
end

local function toAll(key: string, args: { [string]: any })
	for _, p in Players:GetPlayers() do
		Net.remote("Popup"):FireClient(p, Loc.msg(key, args), "big")
	end
end

---------------------------------------------------------------- cash bundles

type Bundle = { part: BasePart, value: number, ends: number }
local bundles: { Bundle } = {}
local spare: { BasePart } = {}

local function makeBundle(): BasePart
	local s = CASH.Size
	local part = Instance.new("Part")
	part.Name = "Cash"
	part.Size = Vector3.new(s[1], s[2], s[3])
	part.Color = Color3.fromRGB(CASH.Color[1], CASH.Color[2], CASH.Color[3])
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(34, 34)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 260
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "$"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 220, 60)
	label.TextStrokeTransparency = 0
	label.Parent = tag
	tag.Parent = part
	return part
end

local function dropBundle(b: Bundle)
	b.part.Parent = store
	table.insert(spare, b.part)
end

-- throw `count` bundles worth `value` each on the street round (x, z)
local function spill(x: number, z: number, count: number, value: number)
	for _ = 1, count do
		if #bundles >= CASH.Max then
			dropBundle(table.remove(bundles, 1) :: Bundle)
		end
		local a = random:NextNumber() * math.pi * 2
		local r = CASH.Spread[1] + random:NextNumber() * (CASH.Spread[2] - CASH.Spread[1])
		local bx, bz = x + math.cos(a) * r, z + math.sin(a) * r
		local part = table.remove(spare) or makeBundle()
		part.CFrame = CFrame.new(bx, groundY(bx, bz) + CASH.Size[2] / 2 + 0.3, bz)
			* CFrame.Angles(0, random:NextNumber() * math.pi, 0)
		part.Parent = folder
		table.insert(bundles, { part = part, value = value, ends = os.clock() + CASH.Life })
	end
end

local function grabBundles()
	if #bundles == 0 then
		return
	end
	local clock = os.clock()
	local spots: { [Player]: Vector3 } = {}
	for _, p in Players:GetPlayers() do
		spots[p] = spotOf(p)
	end
	for i = #bundles, 1, -1 do
		local b = bundles[i]
		local taken: Player? = nil
		for p, at in spots do
			if (at - b.part.Position).Magnitude <= CASH.Radius then
				taken = p
				break
			end
		end
		if taken then
			local cash = pay(taken, b.value, "Cash")
			Net.remote("Popup"):FireClient(taken, Loc.msg("CashGrab", { pay = cash }), "money")
		end
		if taken or clock >= b.ends then
			table.remove(bundles, i)
			dropBundle(b)
		end
	end
end

---------------------------------------------------------------- routes

local function routeS(): number
	return speed * (now() - startAt)
end

-- where the truck is now (x, z, unit heading x, z)
local function truckAt(): (number, number, number, number)
	if not path then
		return 0, 0, 0, -1
	end
	return Route.at(path, routeS())
end

-- a target for the Boss Truck: the nearest player to the end of its route, if one is close enough
local function chaseTarget(fromX: number, fromZ: number): { number }?
	local best, bestD = nil, BT.ChaseRange
	for _, p in Players:GetPlayers() do
		local at = spotOf(p)
		if at then
			local d = math.sqrt((at.X - fromX) ^ 2 + (at.Z - fromZ) ^ 2)
			if d < bestD then
				best, bestD = { at.X, at.Z }, d
			end
		end
	end
	return best
end

-- keep RouteAhead crossings planned past the truck; true when the route grew
local function extend(g: Roads.Graph): boolean
	local grew = false
	local ahead = Config.RouteAhead * g.links[1].length
	local s = routeS()
	while path and path.length - s < ahead do
		local last = nodes[#nodes]
		local prev = nodes[#nodes - 1]
		local here = g.nodes[last]
		local target = if kind == "BossTruck" then chaseTarget(here.x, here.z) else nil
		local nextNode =
			Route.nextNode(g, last, prev, random:NextNumber(), Config.RouteStraight, target)
		table.insert(nodes, nextNode)
		table.insert(points, { g.nodes[nextNode].x, g.nodes[nextNode].z })
		path = Route.build(points, Config.RouteLane, Config.RouteCorner)
		grew = true
	end
	return grew
end

-- a crossing StartFrom studs from a player picked at random (any crossing if none fits)
local function startNode(g: Roads.Graph): number
	local list = Players:GetPlayers()
	local who = if #list > 0 then list[random:NextInteger(1, #list)] else nil
	local at = who and spotOf(who)
	if at then
		local fits = {}
		for id, n in g.nodes do
			local d = math.sqrt((n.x - at.X) ^ 2 + (n.z - at.Z) ^ 2)
			if d >= Config.StartFrom[1] and d <= Config.StartFrom[2] and #n.out > 0 then
				table.insert(fits, id)
			end
		end
		if #fits > 0 then
			return fits[random:NextInteger(1, #fits)]
		end
	end
	return random:NextInteger(1, #g.nodes)
end

-- half the truck's width and length on the ground, from its model at its size
local function sizeOf(vehicle: string, scale: number): (number, number)
	local models = ReplicatedStorage:FindFirstChild("VehicleModels")
	local source = models and models:FindFirstChild(vehicle) :: Model?
	if not source then
		return 6 * scale, 12 * scale
	end
	local size = source:GetExtentsSize() * Game.VehicleScale * scale
	return size.X / 2, size.Z / 2
end

local function startTruck(which: string)
	local g = TrafficService.graph()
	if not g then
		return
	end
	local cfg = if which == "BossTruck" then BT else MT
	local first = startNode(g)
	nodes = { first }
	points = { { g.nodes[first].x, g.nodes[first].z } }
	-- a second crossing straight away, so the route has a way to face
	local second = Route.nextNode(g, first, nil, random:NextNumber(), Config.RouteStraight, nil)
	table.insert(nodes, second)
	table.insert(points, { g.nodes[second].x, g.nodes[second].z })
	path = Route.build(points, Config.RouteLane, Config.RouteCorner)
	speed = cfg.Speed
	startAt = now()
	halfW, halfL = sizeOf(cfg.Vehicle, cfg.Scale)
	extend(g)
	local n = #Players:GetPlayers()
	hpMax = if which == "BossTruck"
		then Rules.needed(BT.Hp, BT.HpPerPlayer, n)
		else Rules.needed(MT.Hits, MT.HitsPerPlayer, n, MT.HitsMax)
	hp = hpMax
	workspace:SetAttribute("EventRoute", Route.encode(points))
	workspace:SetAttribute("EventRouteAt", startAt)
	workspace:SetAttribute("EventHp", hp)
	workspace:SetAttribute("EventHpMax", hpMax)
	workspace:SetAttribute("EventBroken", nil)
	workspace:SetAttribute("EventProp", which)
end

---------------------------------------------------------------- hits

local function onHit(player: Player, velocity: unknown)
	if
		(kind ~= "MoneyTruck" and kind ~= "BossTruck")
		or beaten
		or typeof(velocity) ~= "Vector3"
		or velocity ~= velocity
		or not RateLimit.allow(player, "eventProp", Config.HitGap)
	then
		return
	end
	local vehicle = VehicleService.of(player)
	local chassis = vehicle and vehicle.PrimaryPart
	if not chassis then
		return
	end
	local spm = Vehicles.StudsPerMetre
	local own = chassis.AssemblyLinearVelocity
	-- the client can't claim more speed than its vehicle has (plus a little for lag)
	local vel = if velocity.Magnitude > own.Magnitude + 15 then own else velocity
	local x, z, hx, hz = truckAt()
	local truckVel = Vector3.new(hx, 0, hz) * speed
	local closing = ((vel - truckVel) * Vector3.new(1, 0, 1)).Magnitude / spm
	local d = (Vector3.new(x, 0, z) - chassis.Position * Vector3.new(1, 0, 1)).Magnitude
	local reach = math.max(halfW, halfL)
		+ chassis.Size.Magnitude / 2
		+ Config.CrashReach
		+ (vel.Magnitude + speed) * 0.3
	-- the hitter has to be driving into it, not sat in its way
	local toward = (Vector3.new(x, 0, z) - chassis.Position * Vector3.new(1, 0, 1))
	local driven = if toward.Magnitude > 0.1
		then (vel * Vector3.new(1, 0, 1)):Dot(toward.Unit) / spm
		else closing
	if d > reach or closing < Config.CrashSpeed * 0.8 or driven < Config.CrashSpeed * 0.8 then
		return
	end
	Analytics.tookPart(player)
	local at = Vector3.new(x, chassis.Position.Y, z)
	Net.remote("Fx"):FireAllClients("Hit", at, 1, 0, player.UserId)
	if kind == "MoneyTruck" then
		hp -= 1
		spill(x, z, MT.SpillCount, MT.SpillValue)
		if hp <= 0 then
			beaten = true
			local cash = pay(player, MT.Jackpot, "Jackpot")
			spill(x, z, MT.JackpotSpill, MT.SpillValue)
			Net.remote("Popup"):FireClient(player, Loc.msg("TruckJackpot", { pay = cash }), "big")
			toAll("TruckCracked", { name = player.DisplayName })
			Net.remote("Fx"):FireAllClients("Break", at, 30, 24, player.UserId)
		else
			Net.remote("Popup"):FireClient(player, Loc.msg("TruckHit", { left = hp }), "big")
		end
	else
		local id = player:GetAttribute("VehicleId")
		local spec = if typeof(id) == "string" then Vehicles.ById[id] else nil
		local dmg = math.min(Rules.damage(closing, if spec then spec.weight else 1500, BT), hp)
		hp -= dmg
		if hooks then
			hooks.score(player, dmg)
		end
		Net.remote("Popup"):FireClient(player, Loc.msg("BossHit", { dmg = dmg }), "big")
		if hp <= 0 then
			beaten = true
			toAll("BossBeaten", { name = player.DisplayName })
			Net.remote("Fx"):FireAllClients("Break", at, 40, 30, player.UserId)
		end
	end
	workspace:SetAttribute("EventHp", math.max(hp, 0))
	if beaten then
		workspace:SetAttribute("EventBroken", now())
		if hooks then
			hooks.won()
		end
	end
end

-- the Boss Truck slams the ground: everyone near is thrown away from it
local function slam()
	local x, z = truckAt()
	local centre = Vector3.new(x, groundY(x, z), z)
	Net.remote("Fx"):FireAllClients("Break", centre, 20, BT.SlamRadius / 2, 0)
	for _, p in Players:GetPlayers() do
		local at = spotOf(p)
		if not at then
			continue
		end
		local flat = (at - centre) * Vector3.new(1, 0, 1)
		if flat.Magnitude > BT.SlamRadius then
			continue
		end
		local away = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(1, 0, 0)
		local velocity = away * BT.SlamPush + Vector3.new(0, BT.SlamUp, 0)
		local spin = Vector3.new(random:NextNumber() - 0.5, random:NextNumber() - 0.5, 0) * 6
		local character = p.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local car = VehicleService.of(p)
		local driving = humanoid ~= nil
			and car ~= nil
			and humanoid.SeatPart ~= nil
			and humanoid.SeatPart.Name == "DriverSeat"
			and humanoid.SeatPart:IsDescendantOf(car)
		Net.remote("Fling")
			:FireClient(p, if driving then "Vehicle" else "Character", velocity, spin, BT.SlamDown)
	end
end

---------------------------------------------------------------- the crate

local crate: Model? = nil

local function ropes(model: Model, on: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("Beam") then
			d.Enabled = on
		end
	end
end

local function makeCrate(): Model
	local model = Instance.new("Model")
	model.Name = "CashDrop"
	local box = Instance.new("Part")
	box.Name = "Crate"
	box.Size = Vector3.one * CD.CrateSize
	box.Color = Color3.fromRGB(214, 160, 60)
	box.Material = Enum.Material.WoodPlanks
	local chute = Instance.new("Part")
	chute.Name = "Chute"
	chute.Size = Vector3.new(CD.ChuteSize[1], CD.ChuteSize[2], CD.ChuteSize[1])
	chute.Color = Color3.fromRGB(230, 40, 40)
	chute.Material = Enum.Material.Fabric
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = chute
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, CD.RingSize, CD.RingSize)
	ring.Color = Color3.fromRGB(255, 208, 0)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.7
	for _, p in { box, chute, ring } do
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = model
	end
	-- ropes from the crate's top corners to the canopy's rim
	local h = CD.CrateSize / 2
	for i, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(c[1] * h, h, c[2] * h)
		a0.Parent = box
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(
			c[1] * CD.ChuteSize[1] * 0.35,
			-CD.ChuteSize[2] * 0.2,
			c[2] * CD.ChuteSize[1] * 0.35
		)
		a1.Parent = chute
		local rope = Instance.new("Beam")
		rope.Name = "Rope" .. i
		rope.Attachment0 = a0
		rope.Attachment1 = a1
		rope.Width0, rope.Width1 = 0.3, 0.3
		rope.Color = ColorSequence.new(Color3.new(1, 1, 1))
		rope.LightInfluence = 0
		rope.FaceCamera = true
		rope.Parent = box
	end
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(60, 60)
	tag.StudsOffsetWorldSpace = Vector3.new(0, h + 3, 0)
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "$"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(60, 220, 100)
	label.TextStrokeTransparency = 0
	label.Parent = tag
	tag.Parent = box
	model.PrimaryPart = box
	return model
end

-- a road spot CashDrop.From studs from a player picked at random (any road if none fits)
local function dropSpot(g: Roads.Graph): Vector3
	local list = Players:GetPlayers()
	local who = if #list > 0 then list[random:NextInteger(1, #list)] else nil
	local at = who and spotOf(who)
	local x, z = 0, 0
	for _ = 1, 60 do
		local l = g.links[random:NextInteger(1, #g.links)]
		x, z = Roads.lanePoint(g, l.id, l.length / 2, 0)
		if not at then
			break
		end
		local d = math.sqrt((x - at.X) ^ 2 + (z - at.Z) ^ 2)
		if d >= CD.From[1] and d <= CD.From[2] then
			break
		end
	end
	return Vector3.new(x, groundY(x, z), z)
end

local function startCrate()
	local g = TrafficService.graph()
	if not g then
		return
	end
	local spot = dropSpot(g)
	crateSpot = spot
	landAt = now() + CD.FallSeconds
	local model = crate or makeCrate()
	crate = model
	local box = model:FindFirstChild("Crate") :: BasePart
	local chute = model:FindFirstChild("Chute") :: BasePart
	local ring = model:FindFirstChild("Ring") :: BasePart
	-- the server keeps it on the street; each screen lifts it while it falls (client/EventProps)
	box.CFrame = CFrame.new(spot + Vector3.new(0, CD.CrateSize / 2, 0))
	chute.CFrame = box.CFrame + Vector3.new(0, CD.CrateSize / 2 + CD.ChuteSize[1] * 0.45, 0)
	chute.Transparency = 0
	ropes(model, true)
	ring.CFrame = CFrame.new(spot + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	box.Transparency = 0
	model:SetAttribute("LandAt", landAt)
	model:SetAttribute("FallHeight", CD.FallHeight)
	model.Parent = folder
	workspace:SetAttribute("EventProp", "CashDrop")
end

local function checkCrate()
	local spot = crateSpot
	local model = crate
	if not spot or not model or beaten or now() < landAt then
		return
	end
	local chute = model:FindFirstChild("Chute") :: BasePart
	if chute.Transparency < 1 then
		chute.Transparency = 1 -- landed: the canopy and its ropes are gone
		ropes(model, false)
	end
	local centre = spot + Vector3.new(0, CD.CrateSize / 2, 0)
	for _, p in Players:GetPlayers() do
		local at = spotOf(p)
		if at and (at - centre).Magnitude <= CD.Radius then
			beaten = true
			local cash = pay(p, CD.Value, "Crate")
			Net.remote("Popup"):FireClient(p, Loc.msg("CrateWon", { pay = cash }), "big")
			toAll("CrateClaimed", { name = p.DisplayName })
			Net.remote("Fx"):FireAllClients("Break", centre, 24, 16, p.UserId)
			model.Parent = store
			crateSpot = nil
			if hooks then
				hooks.won()
			end
			return
		end
	end
end

---------------------------------------------------------------- the event

-- where the live event's thing is (the truck, or where the crate lands), for the city map
function EventProps.spot(): Vector3?
	if kind == "CashDrop" then
		return crateSpot
	elseif (kind == "MoneyTruck" or kind == "BossTruck") and path and not beaten then
		local x, z = truckAt()
		return Vector3.new(x, 0, z)
	end
	return nil
end

-- the Boss Truck was beaten (its pot pays in full)
function EventProps.beaten(): boolean
	return beaten
end

function EventProps.begin(key: string, h: Hooks)
	hooks = h
	beaten = false
	kind = key
	if key == "MoneyTruck" or key == "BossTruck" then
		startTruck(key)
	elseif key == "CashDrop" then
		startCrate()
	end
end

function EventProps.finish()
	kind = nil
	hooks = nil
	path = nil
	crateSpot = nil
	if crate then
		crate.Parent = store
	end
	-- spilled cash stays to be grabbed until it times out (grabBundles)
	for _, a in
		{
			"EventProp",
			"EventRoute",
			"EventRouteAt",
			"EventHp",
			"EventHpMax",
			"EventBroken",
			"BossSlamAt",
		}
	do
		workspace:SetAttribute(a, nil)
	end
end

function EventProps.start()
	folder.Parent = workspace
	Net.remote("HitEventProp").OnServerEvent:Connect(onHit)
	task.spawn(function()
		local nextSlam = 0
		while true do
			task.wait(0.1)
			local ok, err = pcall(function()
				grabBundles()
				if kind == "CashDrop" then
					checkCrate()
				elseif (kind == "MoneyTruck" or kind == "BossTruck") and path and not beaten then
					local g = TrafficService.graph()
					if g and extend(g) then
						workspace:SetAttribute("EventRoute", Route.encode(points))
					end
					if kind == "BossTruck" then
						local t = now()
						local warned = workspace:GetAttribute("BossSlamAt")
						if typeof(warned) ~= "number" then
							nextSlam = t + BT.SlamEvery
							workspace:SetAttribute("BossSlamAt", nextSlam)
						elseif t >= nextSlam then
							slam()
							nextSlam = t + BT.SlamEvery
							workspace:SetAttribute("BossSlamAt", nextSlam)
						end
					end
				end
			end)
			if not ok then
				warn("[EventProps]", err)
			end
		end
	end)
end

return EventProps
