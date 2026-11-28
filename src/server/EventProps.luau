--!strict
-- The things the new events put in town (Config/Events): the Money Truck and the Boss Truck, and the Cash Drop's
-- crate. The trucks are steered here and have no parts on the server: they drive the road network (Rules/Route)
-- and leave it when they have to (the Boss Truck chasing a player it sees, a knocked truck finding its way
-- back), smashing whatever is in their way (props, traffic, people, walls). Where a truck is goes out about ten
-- times a second in the EventPose attribute and every screen draws its own copy (client/EventProps), which
-- reports a crash (Net HitEventProp); it's checked here against where the truck is. Other attributes: EventProp,
-- EventEpoch, EventHp, EventHpMax, EventBroken, EventKnock, EventKnockAt. The crate is a real model, made once
-- and kept for the next event.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config.Events)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local HitConfig = require(ReplicatedStorage.Shared.Config.PlayerHits)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local HitRules = require(ReplicatedStorage.Shared.Rules.PlayerHits)
local Impact = require(ReplicatedStorage.Shared.Rules.Impact)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Ragdoll = require(ReplicatedStorage.Shared.Ragdoll)
local Roads = require(ReplicatedStorage.Shared.Rules.Roads)
local Route = require(ReplicatedStorage.Shared.Rules.Route)
local Rules = require(ReplicatedStorage.Shared.Rules.Events)
local Analytics = require(script.Parent.Analytics)
local BuildingService = require(script.Parent.BuildingService)
local Data = require(script.Parent.Data)
local NpcService = require(script.Parent.NpcService)
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

local MT, CD, BT, TR = Config.MoneyTruck, Config.CashDrop, Config.BossTruck, Config.Truck
local random = Random.new()
local hooks: Hooks? = nil
local kind: string? = nil -- the live one: "MoneyTruck" | "BossTruck" | "CashDrop"
local beaten = false

-- the truck: where it is (x, z), its unit heading (hx, hz) and speed (studs/s), and what it's doing:
-- "road" (on its route), "chase" (the Boss Truck after a player, off the road), "air" (knocked flying, then
-- skidding to a stop) or "back" (driving straight back to the road)
local mode = "road"
local x, z, hx, hz, v = 0, 0, 0, -1, 0
local y = 0 -- the ground under it
local halfW, halfL, height = 0, 0, 0
local hp, hpMax = 0, 0
local epoch = 0 -- server time it set off
-- on the road
local nodes: { number } = {}
local points: { { number } } = {}
local path: Route.Path? = nil
local roadAt = 0 -- server time it joined this route
-- off the road
local target: Player? = nil
local chaseUntil, restUntil = 0, 0
local kv = Vector3.zero -- the knock's velocity
local airEnd, skidEnd = 0, 0
local goal: { number }? = nil -- where "back" drives to: the start of nextPath
local nextNodes: { number } = {}
local nextPath: Route.Path? = nil
local lastHit: { [Player]: number } = {} -- server time each player last hit it (not run over just then)
local lastRun: { [Player]: number } = {} -- server time each player was last run over

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

-- the ground under (gx, gz), looked for from a little over `from` so a roof or floor above isn't taken for it
local function groundY(gx: number, gz: number, from: number): number
	local map = workspace:FindFirstChild("Map")
	if map then
		groundParams.FilterDescendantsInstances = { map }
		local hit = workspace:Raycast(
			Vector3.new(gx, from + 8, gz),
			Vector3.new(0, -(from + 68), 0),
			groundParams
		)
		if hit then
			return hit.Position.Y
		end
	end
	return from
end

-- a player's spot: their car's middle when they have one out and sit in it, else their body
local function spotOf(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function safe(at: Vector3): boolean
	return HitRules.inSafeZone(
		at,
		workspace:GetAttribute("SafeZoneCentre"),
		workspace:GetAttribute("SafeZoneHalf")
	)
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

local function cfgOf(which: string?): typeof(MT) | typeof(BT)
	return if which == "BossTruck" then BT else MT
end

---------------------------------------------------------------- routes

-- a player for the Boss Truck to head for along the roads: the nearest one this close to a crossing
local function roadTarget(fromX: number, fromZ: number): { number }?
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

-- keep RouteAhead crossings planned past the truck on its route
local function extend(g: Roads.Graph)
	local ahead = Config.RouteAhead * g.links[1].length
	local s = cfgOf(kind).Speed * (now() - roadAt)
	while path and path.length - s < ahead do
		local last = nodes[#nodes]
		local prev = nodes[#nodes - 1]
		local here = g.nodes[last]
		local toward = if kind == "BossTruck" then roadTarget(here.x, here.z) else nil
		local nextNode =
			Route.nextNode(g, last, prev, random:NextNumber(), Config.RouteStraight, toward)
		table.insert(nodes, nextNode)
		table.insert(points, { g.nodes[nextNode].x, g.nodes[nextNode].z })
		path = Route.build(points, Config.RouteLane, Config.RouteCorner)
	end
end

-- a route starting at crossing `first`: its crossings, and the path
local function routeFrom(g: Roads.Graph, first: number): ({ number }, Route.Path)
	local second = Route.nextNode(g, first, nil, random:NextNumber(), Config.RouteStraight, nil)
	local pts = { { g.nodes[first].x, g.nodes[first].z }, { g.nodes[second].x, g.nodes[second].z } }
	return { first, second }, Route.build(pts, Config.RouteLane, Config.RouteCorner)
end

local function onRoad(list: { number }, p: Route.Path, g: Roads.Graph)
	nodes = list
	points = {}
	for _, id in list do
		table.insert(points, { g.nodes[id].x, g.nodes[id].z })
	end
	path = p
	roadAt = now()
	mode = "road"
	extend(g)
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

-- leave whatever it's doing and drive straight to the start of a route from the nearest crossing
local function headBack()
	local g = TrafficService.graph()
	if not g then
		return
	end
	local best, bestD = 1, math.huge
	for id, n in g.nodes do
		local d = (n.x - x) ^ 2 + (n.z - z) ^ 2
		if d < bestD and #n.out > 0 then
			best, bestD = id, d
		end
	end
	local list, p = routeFrom(g, best)
	nextNodes, nextPath = list, p
	local gx, gz = Route.at(p, 0)
	goal = { gx, gz }
	target = nil
	mode = "back"
end

-- half the truck's width and length on the ground and its height, from its model at its size
local function sizeOf(vehicle: string, scale: number): (number, number, number)
	local models = ReplicatedStorage:FindFirstChild("VehicleModels")
	local source = models and models:FindFirstChild(vehicle) :: Model?
	if not source then
		return 6 * scale, 12 * scale, 10 * scale
	end
	local size = source:GetExtentsSize() * Game.VehicleScale * scale
	return size.X / 2, size.Z / 2, size.Y
end

local function startTruck(which: string)
	local g = TrafficService.graph()
	if not g then
		return
	end
	local cfg = cfgOf(which)
	halfW, halfL, height = sizeOf(cfg.Vehicle, cfg.Scale)
	v = cfg.Speed
	epoch = now()
	target, chaseUntil, restUntil, goal = nil, 0, 0, nil
	table.clear(lastHit)
	table.clear(lastRun)
	local list, p = routeFrom(g, startNode(g))
	onRoad(list, p, g)
	x, z, hx, hz = Route.at(p, 0)
	y = groundY(x, z, 200)
	local n = #Players:GetPlayers()
	hpMax = if which == "BossTruck"
		then Rules.needed(BT.Hp, BT.HpPerPlayer, n)
		else Rules.needed(MT.Hits, MT.HitsPerPlayer, n, MT.HitsMax)
	hp = hpMax
	workspace:SetAttribute("EventEpoch", epoch)
	workspace:SetAttribute("EventHp", hp)
	workspace:SetAttribute("EventHpMax", hpMax)
	workspace:SetAttribute("EventBroken", nil)
	workspace:SetAttribute("EventProp", which)
end

---------------------------------------------------------------- driving

-- turn toward (tx, tz) no faster than Truck.TurnRate and get up to `top` studs/s, then move on
local function steer(tx: number, tz: number, top: number, dt: number)
	local dx, dz = tx - x, tz - z
	local d = math.sqrt(dx * dx + dz * dz)
	if d > 0.5 then
		local want = math.atan2(dx, dz)
		local have = math.atan2(hx, hz)
		local turn = (want - have + math.pi) % (math.pi * 2) - math.pi
		local most = TR.TurnRate * dt
		local a = have + math.clamp(turn, -most, most)
		hx, hz = math.sin(a), math.cos(a)
		-- slower through a sharp turn
		top *= math.clamp(1 - math.abs(turn) / math.pi, 0.45, 1)
	end
	v = if v < top then math.min(top, v + TR.Accel * dt) else math.max(top, v - TR.Accel * dt)
	local step = math.min(v * dt, d)
	x += hx * step
	z += hz * step
end

-- a player for the Boss Truck to go after: the nearest one it can see from here, out of the safe zone
local function seen(): Player?
	local best, bestD = nil, BT.Sight
	for _, p in Players:GetPlayers() do
		local at = spotOf(p)
		if at and not safe(at) then
			local d = math.sqrt((at.X - x) ^ 2 + (at.Z - z) ^ 2)
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

local function drive(dt: number)
	local g = TrafficService.graph()
	local t = now()
	if mode == "road" then
		local p = path
		if not (p and g) then
			return
		end
		extend(g)
		v = cfgOf(kind).Speed
		x, z, hx, hz = Route.at(path :: Route.Path, v * (t - roadAt))
		if kind == "BossTruck" and t >= restUntil then
			local who = seen()
			if who then
				target, mode, chaseUntil = who, "chase", t + BT.ChaseMax
			end
		end
	elseif mode == "chase" then
		local who = target
		local at = if who and who.Parent then spotOf(who) else nil
		if not at then
			restUntil = t + BT.ChaseRest
			headBack()
			return
		end
		local d = math.sqrt((at.X - x) ^ 2 + (at.Z - z) ^ 2)
		if d > BT.LoseRange or t >= chaseUntil or safe(at) then
			restUntil = t + BT.ChaseRest
			headBack()
			return
		end
		-- aim a little past them so it drives through rather than stopping on top
		local ax, az = at.X, at.Z
		if d > 1 then
			ax += (ax - x) / d * 20
			az += (az - z) / d * 20
		end
		steer(ax, az, BT.ChaseSpeed, dt)
	elseif mode == "air" then
		local flat = kv * Vector3.new(1, 0, 1)
		local dir = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zero
		if t < airEnd then
			x += flat.X * dt
			z += flat.Z * dt
		else
			v = math.max(0, v - TR.SkidDecel * dt)
			x += dir.X * v * dt
			z += dir.Z * v * dt
			if t >= skidEnd then
				v = 0
				headBack()
			end
		end
	elseif mode == "back" then
		local to = goal
		local p = nextPath
		if not (to and g and p) then
			return
		end
		steer(to[1], to[2], TR.BackSpeed, dt)
		if (to[1] - x) ^ 2 + (to[2] - z) ^ 2 < 16 then
			onRoad(nextNodes, p, g)
			goal = nil
		end
	end
end

-- run a player over (the Boss Truck, or a knocked Money Truck): they're thrown on along its way
local function runOver(p: Player, push: Vector3)
	local character = p.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid) or humanoid.Health <= 0 then
		return
	end
	local shield = p:GetAttribute("NoHitUntil")
	if typeof(shield) == "number" and shield > now() then
		return
	end
	local R = TR.RunOver
	local flat = push * Vector3.new(1, 0, 1)
	local dir = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(hx, 0, hz)
	local velocity = dir * math.max(R.Push, flat.Magnitude) + Vector3.new(0, R.Up, 0)
	local spinV =
		Vector3.new(random:NextNumber(-6, 6), random:NextNumber(-6, 6), random:NextNumber(-6, 6))
	local car = VehicleService.of(p)
	local seat = humanoid.SeatPart
	local driving = car ~= nil
		and seat ~= nil
		and seat.Name == "DriverSeat"
		and seat:IsDescendantOf(car)
	if driving then
		Net.remote("Fling"):FireClient(p, "Vehicle", velocity, spinV * 0.6, R.Seconds)
	else
		p:SetAttribute("HitAt", now())
		Ragdoll.enable(character)
		Net.remote("Fling"):FireClient(p, "Character", velocity, spinV, R.Seconds)
		task.delay(R.Seconds, function()
			if character.Parent then
				Ragdoll.disable(character)
			end
		end)
	end
end

-- everything in the truck's way: props, traffic and people go flying; off the road, walls break too
local function smash()
	local t = now()
	local moving = if mode == "air" then kv * Vector3.new(1, 0, 1) else Vector3.new(hx, 0, hz) * v
	if mode == "air" and t >= airEnd then
		moving = moving.Unit * v
	end
	if moving.Magnitude < TR.SmashSpeed then
		return
	end
	-- a knocked truck high in the air flies over things
	if mode == "air" and t < airEnd then
		local since = t - (airEnd - Rules.airTime(kv.Y, workspace.Gravity))
		if kv.Y * since - workspace.Gravity * since * since / 2 > height * 0.8 then
			return
		end
	end
	local w, l = halfW + TR.SmashReach, halfL + TR.SmashReach
	TrafficService.wreckWithin(x, z, hx, hz, w, l, moving)
	BuildingService.knockPropsWithin(x, z, hx, hz, w, l, moving)
	local centre = Vector3.new(x, y + height / 2, z)
	for _, npc in NpcService.inRadius(centre, math.max(w, l) + height) do
		local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local dx, dz = root.Position.X - x, root.Position.Z - z
			if math.abs(dx * hx + dz * hz) <= l and math.abs(dx * hz - dz * hx) <= w then
				NpcService.knock(npc, moving * TR.NpcThrow + Vector3.new(0, TR.NpcUp, 0), 0, nil, 0)
			end
		end
	end
	-- the Boss Truck runs people over all the time; the Money Truck only once it's knocked loose
	if kind == "BossTruck" or mode ~= "road" then
		local R = TR.RunOver
		for _, p in Players:GetPlayers() do
			local at = spotOf(p)
			if
				at
				and t - (lastHit[p] or -math.huge) > R.AfterHit
				and t - (lastRun[p] or -math.huge) > R.Gap
				and at.Y < y + height + 4
				and not safe(at)
			then
				local dx, dz = at.X - x, at.Z - z
				if
					math.abs(dx * hx + dz * hz) <= halfL + 2
					and math.abs(dx * hz - dz * hx) <= halfW + 2
				then
					lastRun[p] = t
					runOver(p, moving * R.Carry)
				end
			end
		end
	end
	-- off the road it drives through walls
	if mode ~= "road" then
		BuildingService.breakAt(centre, math.max(halfW, height / 2) + TR.SmashReach, moving)
	end
end

---------------------------------------------------------------- hits

-- a hit knocks the truck flying like a hit car (Config/Events MoneyTruck.Knock, BossTruck.Knock); every screen
-- throws its copy from the EventKnock velocity at EventKnockAt (client/EventProps)
local function knock(player: Player, vel: Vector3, toward: Vector3, closing: number)
	local K = cfgOf(kind).Knock
	local id = player:GetAttribute("VehicleId")
	local spec = if typeof(id) == "string" then Vehicles.ById[id] else nil
	local weight = if spec then spec.weight else Config.HitterWeight
	local price = if spec then spec.price else 0
	local launch = Rules.knockSpeed(
		Impact.launchSpeed(Impact.energy(weight, closing)),
		weight,
		HitRules.carLaunchCap(price, HitConfig),
		K
	)
	local flat = vel * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.1 then
		flat = toward * Vector3.new(1, 0, 1)
	end
	local dir = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, -1)
	kv = (dir + Vector3.new(0, K.Lift, 0)).Unit * launch
	local t = now()
	airEnd = t + Rules.airTime(kv.Y, workspace.Gravity)
	v = (kv * Vector3.new(1, 0, 1)).Magnitude
	skidEnd = airEnd + v / TR.SkidDecel
	mode = "air"
	target = nil
	workspace:SetAttribute("EventKnock", kv)
	workspace:SetAttribute("EventKnockAt", t)
end

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
	if mode == "air" and now() < skidEnd then
		return -- it's flying
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
	local truckVel = Vector3.new(hx, 0, hz) * v
	local closing = ((vel - truckVel) * Vector3.new(1, 0, 1)).Magnitude / spm
	local d = (Vector3.new(x, 0, z) - chassis.Position * Vector3.new(1, 0, 1)).Magnitude
	local reach = math.max(halfW, halfL)
		+ chassis.Size.Magnitude / 2
		+ Config.CrashReach
		+ (vel.Magnitude + v) * 0.3
	-- the hitter has to be driving into it, not sat in its way
	local toward = (Vector3.new(x, 0, z) - chassis.Position * Vector3.new(1, 0, 1))
	local driven = if toward.Magnitude > 0.1
		then (vel * Vector3.new(1, 0, 1)):Dot(toward.Unit) / spm
		else closing
	if d > reach or closing < Config.CrashSpeed * 0.8 or driven < Config.CrashSpeed * 0.8 then
		return
	end
	lastHit[player] = now()
	Analytics.tookPart(player)
	local at = Vector3.new(x, chassis.Position.Y, z)
	Net.remote("Fx"):FireAllClients("Hit", at, 1, 0, player.UserId)
	if kind == "MoneyTruck" then
		hp -= 1
		if hp <= 0 then
			beaten = true
			local cash = pay(player, MT.Jackpot, "Jackpot")
			Net.remote("Popup"):FireClient(player, Loc.msg("TruckJackpot", { pay = cash }), "big")
			toAll("TruckCracked", { name = player.DisplayName })
			Net.remote("Fx"):FireAllClients("Break", at, 30, 24, player.UserId)
		else
			local cash = pay(player, MT.HitPay, "Hit")
			Net.remote("Popup"):FireClient(player, Loc.msg("TruckHit", { left = hp }), "big")
			Net.remote("Popup"):FireClient(player, Loc.msg("CashGrab", { pay = cash }), "money")
			knock(player, vel, toward, closing)
		end
	else
		local id = player:GetAttribute("VehicleId")
		local spec = if typeof(id) == "string" then Vehicles.ById[id] else nil
		local dmg = math.min(
			Rules.damage(closing, if spec then spec.weight else Config.HitterWeight, BT),
			hp
		)
		hp -= dmg
		if hooks then
			hooks.score(player, dmg)
		end
		Net.remote("Popup"):FireClient(player, Loc.msg("BossHit", { dmg = dmg }), "big")
		if hp <= 0 then
			beaten = true
			toAll("BossBeaten", { name = player.DisplayName })
			Net.remote("Fx"):FireAllClients("Break", at, 40, 30, player.UserId)
		else
			knock(player, vel, toward, closing)
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

---------------------------------------------------------------- the crate

local crate: Model? = nil
local crateRest = CFrame.identity -- the crate part's place in the model, from the crate's bottom centre

-- the canopy and its lines: shown while it falls, gone once it lands
local function chute(model: Model, on: boolean)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and string.sub(p.Name, 1, 5) == "Chute" then
			p.Transparency = if on then 0 else 1
		end
	end
end

-- the airdrop (ServerStorage.EventModels.Airdrop, tools/lune/import_airdrop) and a landing ring on the street
local function makeCrate(): Model
	local models = ServerStorage:FindFirstChild("EventModels")
	local source =
		assert(models and models:FindFirstChild("Airdrop"), "no EventModels.Airdrop") :: Model
	local model = source:Clone()
	model.Name = "CashDrop"
	crateRest = (model.PrimaryPart :: BasePart).CFrame
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, CD.RingSize, CD.RingSize)
	ring.Color = Color3.fromRGB(255, 208, 0)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.7
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Parent = model
	return model
end

-- a road spot CashDrop.From studs from a player picked at random (any road if none fits)
local function dropSpot(g: Roads.Graph): Vector3
	local list = Players:GetPlayers()
	local who = if #list > 0 then list[random:NextInteger(1, #list)] else nil
	local at = who and spotOf(who)
	local px, pz = 0, 0
	for _ = 1, 60 do
		local l = g.links[random:NextInteger(1, #g.links)]
		px, pz = Roads.lanePoint(g, l.id, l.length / 2, 0)
		if not at then
			break
		end
		local d = math.sqrt((px - at.X) ^ 2 + (pz - at.Z) ^ 2)
		if d >= CD.From[1] and d <= CD.From[2] then
			break
		end
	end
	return Vector3.new(px, groundY(px, pz, 200), pz)
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
	local ring = model:FindFirstChild("Ring") :: BasePart
	-- the server keeps it on the street; each screen lifts it while it falls (client/EventProps)
	model:PivotTo(
		CFrame.new(spot) * CFrame.Angles(0, random:NextNumber() * math.pi * 2, 0) * crateRest
	)
	chute(model, true)
	ring.CFrame = CFrame.new(spot + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2)
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
	local lines = model:FindFirstChild("Chute") :: BasePart
	if lines.Transparency < 1 then
		chute(model, false) -- landed: the canopy and its lines are gone
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
	airEnd, skidEnd = 0, 0
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
	target = nil
	crateSpot = nil
	if crate then
		crate.Parent = store
	end
	for _, a in
		{
			"EventProp",
			"EventEpoch",
			"EventPose",
			"EventHp",
			"EventHpMax",
			"EventBroken",
			"EventKnock",
			"EventKnockAt",
		}
	do
		workspace:SetAttribute(a, nil)
	end
end

-- send where the truck is: position (x, z) with the seconds since it set off as y, turned to its heading
local function publish()
	local yaw = math.atan2(-hx, -hz)
	workspace:SetAttribute("EventPose", CFrame.new(x, now() - epoch, z) * CFrame.Angles(0, yaw, 0))
end

function EventProps.start()
	folder.Parent = workspace
	Net.remote("HitEventProp").OnServerEvent:Connect(onHit)
	Players.PlayerRemoving:Connect(function(p)
		lastHit[p] = nil
		lastRun[p] = nil
		if target == p then
			target = nil
		end
	end)
	task.spawn(function()
		local tick = 0
		while true do
			local dt = task.wait(TR.Tick)
			local ok, err = pcall(function()
				if kind == "CashDrop" then
					checkCrate()
				elseif (kind == "MoneyTruck" or kind == "BossTruck") and path and not beaten then
					drive(math.min(dt, 0.5))
					tick += 1
					if tick % 3 == 0 then
						y = groundY(x, z, y)
					end
					smash()
					publish()
				end
			end)
			if not ok then
				warn("[EventProps]", err)
			end
		end
	end)
end

return EventProps
