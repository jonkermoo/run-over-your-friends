--!strict
-- City traffic on the server: Config/Traffic Count cars as plain numbers (a link and a distance along it, or
-- a turn through a crossing), no parts and no physics. They keep right, follow the car in front, wait at red
-- lights (Rules/Roads, the same phase the lamps show), brake for people and players in their lane, and are
-- moved near players when nobody is around them. Every SendEvery a packed snapshot goes to all clients,
-- which draw the cars (src/client/Traffic). A driver's client reports a crash; it's checked here, paid, and
-- the car is flung on every screen and comes back later somewhere else.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Traffic)
local Districts = require(ReplicatedStorage.Shared.Rules.Districts)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Paints = require(ReplicatedStorage.Shared.Config.Paints)
local Roads = require(ReplicatedStorage.Shared.Rules.Roads)
local Streets = require(ReplicatedStorage.Shared.Config.Streets)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local CrowdService = require(script.Parent.CrowdService)
local Data = require(script.Parent.Data)
local Passes = require(script.Parent.Passes)
local RateLimit = require(script.Parent.RateLimit)
local VehicleService = require(script.Parent.VehicleService)

local TrafficService = {}

type Car = {
	id: number,
	kind: number, -- index into Cfg.Kinds
	paint: number, -- index into Paints.List; 0 = the model's own colour
	gen: number, -- bumped every time the car is placed again (clients start a fresh copy)
	link: number,
	s: number, -- studs along the link from its start crossing
	nextLink: number,
	turn: Roads.Turn?,
	u: number, -- 0-1 along the turn
	speed: number,
	offset: number, -- studs right of the centre line: Cfg.Lane, or less while passing a stopped player
	passing: boolean,
	blockedFor: number,
	x: number,
	z: number,
	hx: number,
	hz: number,
	placed: boolean,
	crashedUntil: number,
}

local graph: Roads.Graph? = nil
local cars: { Car } = {}
local random = Random.new()
local edge = 0 -- half a road: where a link meets a crossing
local paintColours: { number } = {} -- Paints.List indexes that have a colour

local function pickKind(): number
	local total = 0
	for _, k in Cfg.Kinds do
		total += k.weight
	end
	local at = random:NextNumber() * total
	for n, k in Cfg.Kinds do
		at -= k.weight
		if at <= 0 then
			return n
		end
	end
	return 1
end

local function updatePose(car: Car)
	local g = graph :: Roads.Graph
	if car.turn then
		car.x, car.z, car.hx, car.hz = Roads.onTurn(car.turn, car.u)
	else
		local l = g.links[car.link]
		car.x, car.z = Roads.lanePoint(g, car.link, car.s, car.offset)
		car.hx, car.hz = l.dx, l.dz
	end
end

local function isStraight(g: Roads.Graph, a: number, b: number): boolean
	local la, lb = g.links[a], g.links[b]
	return math.abs(la.dx - lb.dx) < 1e-6 and math.abs(la.dz - lb.dz) < 1e-6
end

-- where players are (their vehicle, or themselves on foot)
local function playerSpots(): { Vector3 }
	local out = {}
	for _, p in Players:GetPlayers() do
		local v = VehicleService.of(p)
		local part = (v and v.PrimaryPart)
			or (p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?)
		if part then
			table.insert(out, part.Position)
		end
	end
	return out
end

-- put a car on a free spot of a lane somewhere just out of sight of a player
local function place(car: Car, spots: { Vector3 }): boolean
	local g = graph :: Roads.Graph
	for _ = 1, 30 do
		local l = g.links[random:NextInteger(1, #g.links)]
		local lo, hi = edge + Cfg.CarLength, l.length - Cfg.StopLine - Cfg.CarLength
		if hi <= lo then
			continue
		end
		local s = random:NextNumber(lo, hi)
		local x, z = Roads.lanePoint(g, l.id, s, Cfg.Lane)
		local nearest = math.huge
		for _, p in spots do
			nearest = math.min(nearest, math.sqrt((p.X - x) ^ 2 + (p.Z - z) ^ 2))
		end
		if nearest < Cfg.SpawnMin or nearest > Cfg.SpawnMax then
			continue
		end
		local free = true
		for _, other in cars do
			if
				other ~= car
				and other.placed
				and not other.turn
				and other.link == l.id
				and math.abs(other.s - s) < Cfg.CarLength * 2
			then
				free = false
				break
			end
		end
		if free then
			car.link, car.s, car.turn, car.u = l.id, s, nil, 0
			car.nextLink = Roads.nextLink(g, l.id, random:NextNumber(), Cfg.StraightWeight)
			car.speed = Cfg.Cruise * 0.6
			car.offset, car.passing, car.blockedFor = Cfg.Lane, false, 0
			car.kind = pickKind()
			local kind = Cfg.Kinds[car.kind]
			car.paint = if kind.factoryPaint or random:NextNumber() < Cfg.FactoryChance
				then 0
				else paintColours[random:NextInteger(1, #paintColours)]
			car.gen = (car.gen + 1) % 256
			car.placed = true
			car.crashedUntil = 0
			updatePose(car)
			return true
		end
	end
	return false
end

-- people, players on foot and players' vehicles: things a car must not drive into (points from `firstPlayer`
-- on are players', which a car will pass if they stay put)
local function obstacles(): ({ number }, { number }, { number }, number)
	local px, pz, pr = {}, {}, {}
	local function add(p: Vector3, r: number)
		table.insert(px, p.X)
		table.insert(pz, p.Z)
		table.insert(pr, r)
	end
	for _, m in CrowdService.active() do
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and not m:GetAttribute("Down") and root.Position.Y < 8 then
			add(root.Position, 1.5)
		end
	end
	local firstPlayer = #px + 1
	for _, p in Players:GetPlayers() do
		local v = VehicleService.of(p)
		local chassis = v and v.PrimaryPart
		if chassis then
			-- a long vehicle across the lane: its middle and both ends
			local half = chassis.Size.X / 2 + 1
			local reach = math.max(0, chassis.Size.Z / 2 - half)
			add(chassis.Position, half)
			add(chassis.Position + chassis.CFrame.LookVector * reach, half)
			add(chassis.Position - chassis.CFrame.LookVector * reach, half)
		else
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				add(root.Position, 2)
			end
		end
	end
	return px, pz, pr, firstPlayer
end

local function step(dt: number, now: number)
	local g = graph :: Roads.Graph
	local px, pz, pr, firstPlayer = obstacles()
	-- cars on each link, for following
	local onLink: { [number]: { Car } } = {}
	for _, car in cars do
		if car.placed and car.crashedUntil == 0 then
			local key = car.link
			onLink[key] = onLink[key] or {}
			table.insert(onLink[key], car)
		end
	end
	for _, car in cars do
		if not car.placed or car.crashedUntil > 0 then
			continue
		end
		local l = g.links[car.link]
		local straight = isStraight(g, car.link, car.nextLink)
		local target = Cfg.Cruise
		-- where the car would be on its link (a car in a turn is past the end of its in-link)
		local along = if car.turn then l.length - edge + car.u * car.turn.length else car.s
		if not car.turn then
			local toEdge = l.length - edge - car.s
			if not straight then
				target = math.min(
					target,
					math.sqrt(Cfg.TurnSpeed ^ 2 + 2 * Cfg.Brake * math.max(0, toEdge))
				)
			end
			-- the light at the far crossing
			local toLine = l.length - Cfg.StopLine - car.s - Cfg.CarLength / 2
			if toLine > -2 then
				local lamp = Roads.lightFor(g, car.link, now, Streets)
				local mustStop = lamp == "red"
					or (lamp == "amber" and toLine > car.speed * car.speed / (2 * Cfg.Brake))
				if mustStop then
					target = math.min(target, Roads.stopSpeed(toLine, Cfg.Brake))
				end
			end
		elseif not straight then
			target = Cfg.TurnSpeed
		end
		-- the car in front on the same link (and anyone turning off it)
		for _, other in onLink[car.link] or {} do
			if other ~= car then
				local o = if other.turn
					then l.length - edge + other.u * other.turn.length
					else other.s
				if o > along then
					local gap = o - along - Cfg.CarLength - Cfg.Gap
					target = math.min(target, Roads.stopSpeed(gap, Cfg.Brake))
				end
			end
		end
		-- the start of the next link must be clear before going through
		if not car.turn then
			local toEdge = l.length - edge - car.s
			for _, other in onLink[car.nextLink] or {} do
				if not other.turn and other.s < edge + Cfg.CarLength * 1.5 then
					local gap = toEdge + 2 * edge * 0.8 + other.s - edge - Cfg.CarLength - Cfg.Gap
					target = math.min(target, Roads.stopSpeed(gap, Cfg.Brake))
				end
			end
		end
		-- people and players in the way
		local gap, who =
			Roads.gapAhead(car.x, car.z, car.hx, car.hz, Cfg.HalfWidth, Cfg.Look, px, pz, pr)
		if gap < math.huge then
			target = math.min(target, Roads.stopSpeed(gap - Cfg.Gap, Cfg.Brake))
		end
		-- stuck behind a player who stays put: honk, then pull out into the other lane and go round
		if not car.turn then
			local toEdge = l.length - edge - car.s
			if gap < math.huge and who >= firstPlayer and car.speed < 2 then
				car.blockedFor += dt
			else
				car.blockedFor = 0
			end
			if not car.passing and car.blockedFor > Cfg.Patience and toEdge > Cfg.CarLength * 2 then
				-- only into a clear other lane
				local back = g.between[l.b][l.a]
				local clear = true
				for _, other in onLink[back] or {} do
					if
						not other.turn
						and math.abs((l.length - other.s) - car.s) < Cfg.Look * 1.5
					then
						clear = false
					end
				end
				if clear then
					car.passing, car.blockedFor = true, 0
					Net.remote("Fx"):FireAllClients("Honk", Vector3.new(car.x, 2, car.z), 0, 0, 0)
				end
			end
			if car.passing then
				-- back in lane once nothing of a player's is in it from a car length behind to Look ahead
				local lx, lz = Roads.lanePoint(g, car.link, car.s - Cfg.CarLength, Cfg.Lane)
				local laneGap, laneWho =
					Roads.gapAhead(lx, lz, l.dx, l.dz, Cfg.HalfWidth, Cfg.Look, px, pz, pr)
				if laneGap == math.huge or laneWho < firstPlayer or toEdge < Cfg.CarLength then
					car.passing = false
				end
			end
			local want = if car.passing then -Cfg.Lane else Cfg.Lane
			if math.abs(car.offset - want) > 0.05 then
				local stepBy =
					math.clamp(want - car.offset, -Cfg.PassShift * dt, Cfg.PassShift * dt)
				car.offset += stepBy
				target = math.min(target, Cfg.PassSpeed)
			end
			-- never into a crossing out of lane
			if math.abs(car.offset - Cfg.Lane) > 1 then
				target = math.min(target, Roads.stopSpeed(toEdge - 4, Cfg.Brake))
			end
		end
		-- speed up gently, slow down as hard as needed
		if target > car.speed then
			car.speed = math.min(target, car.speed + Cfg.Accel * dt)
		else
			car.speed = math.max(target, car.speed - Cfg.Brake * 2 * dt)
		end
		local move = car.speed * dt
		if car.turn then
			car.u += move / car.turn.length
			if car.u >= 1 then
				local over = (car.u - 1) * car.turn.length
				car.link, car.s, car.turn, car.u = car.nextLink, edge + over, nil, 0
				car.nextLink = Roads.nextLink(g, car.link, random:NextNumber(), Cfg.StraightWeight)
			end
		else
			car.s += move
			if car.s >= l.length - edge then
				car.turn = Roads.turn(g, car.link, car.nextLink, Cfg.Lane)
				car.u = (car.s - (l.length - edge)) / (car.turn :: Roads.Turn).length
			end
		end
		updatePose(car)
	end
end

local function recycle(now: number)
	-- numbers for play tests (read the workspace's attributes)
	local s = TrafficService.stats()
	workspace:SetAttribute("TrafficPlaced", s.placed)
	workspace:SetAttribute("TrafficMoving", s.moving)
	workspace:SetAttribute("TrafficCrashed", s.crashed)
	local spots = playerSpots()
	if #spots == 0 then
		return
	end
	for _, car in cars do
		if car.crashedUntil > 0 then
			if now >= car.crashedUntil then
				car.placed = false
				car.crashedUntil = 0
			else
				continue
			end
		end
		local far = true
		if car.placed then
			for _, p in spots do
				if (p.X - car.x) ^ 2 + (p.Z - car.z) ^ 2 < Cfg.RecycleDistance ^ 2 then
					far = false
					break
				end
			end
		end
		if far then
			if not place(car, spots) then
				car.placed = false
			end
		end
	end
end

local function snapshot(now: number): buffer
	local live = {}
	for _, car in cars do
		if car.placed and car.crashedUntil == 0 then
			table.insert(live, car)
		end
	end
	local b = buffer.create(9 + #live * Roads.CarBytes)
	buffer.writef64(b, 0, now)
	buffer.writeu8(b, 8, #live)
	for n, car in live do
		local o = 9 + (n - 1) * Roads.CarBytes
		buffer.writeu8(b, o, car.id)
		buffer.writeu8(b, o + 1, car.kind)
		buffer.writeu8(b, o + 2, car.paint)
		buffer.writeu8(b, o + 3, car.gen)
		buffer.writef32(b, o + 4, car.x)
		buffer.writef32(b, o + 8, car.z)
		buffer.writeu16(b, o + 12, Roads.yawToU16(math.atan2(-car.hx, -car.hz)))
		buffer.writeu16(b, o + 14, math.clamp(math.floor(car.speed * 10 + 0.5), 0, 65535))
	end
	return b
end

local function onHit(player: Player, id: unknown, velocity: unknown)
	if
		typeof(id) ~= "number"
		or typeof(velocity) ~= "Vector3"
		or velocity ~= velocity
		or not RateLimit.allow(player, "hitTraffic", 0.1)
	then
		return
	end
	local car = cars[id :: number]
	local vehicle = VehicleService.of(player)
	local chassis = vehicle and vehicle.PrimaryPart
	-- why the last report was turned down, for play tests (workspace attribute)
	local function reject(why: string)
		workspace:SetAttribute("TrafficReject", why)
	end
	if not (car and car.placed and car.crashedUntil == 0 and chassis) then
		reject(if car and car.crashedUntil > 0 then "already wrecked" else "no such car")
		return
	end
	local spm = Vehicles.StudsPerMetre
	-- the client can't claim more speed than the vehicle has right now (plus a little for lag)
	local own = chassis.AssemblyLinearVelocity
	local vel = if velocity.Magnitude > own.Magnitude + 15 then own else velocity
	local carVel = Vector3.new(car.hx, 0, car.hz) * car.speed
	local closing = (vel - carVel).Magnitude / spm
	local d = (Vector3.new(car.x, chassis.Position.Y, car.z) - chassis.Position).Magnitude
	-- clients draw cars Delay in the past, so allow for both vehicles' travel since then
	local reach = Cfg.CrashReach
		+ chassis.Size.Magnitude / 2
		+ (vel.Magnitude + car.speed) * Cfg.Delay * 1.5
	if d > reach then
		reject(string.format("too far %.0f > %.0f", d, reach))
		return
	elseif closing < Cfg.CrashSpeed * 0.8 then
		reject(string.format("too slow %.1f m/s", closing))
		return
	end
	car.crashedUntil = os.clock() + Cfg.RespawnSeconds
	local pos = Vector3.new(car.x, chassis.Position.Y, car.z)
	local push = (vel - carVel) * Cfg.FlingAlong
		+ Vector3.new(0, Cfg.FlingUp + closing * Cfg.FlingUpPerMs, 0)
	Net.remote("TrafficCrash"):FireAllClients(car.id, car.gen, push, player.UserId)
	local pay = Cfg.Pay * math.clamp(closing / (Cfg.CrashSpeed * 2), 1, Cfg.PayMax)
	if Passes.has(player, "DoubleMoney") then
		pay *= Economy.DoubleMoney
	end
	Data.addMoney(player, pay)
	Net.remote("Popup"):FireClient(player, `+${math.floor(pay + 0.5)}  WRECKED!`, "money")
	Net.remote("Fx"):FireAllClients("Break", pos, 14, 9, player.UserId)
end

function TrafficService.setup(grid: Roads.Grid)
	local function lit(i: number, j: number): boolean
		-- the same crossings StreetKit puts traffic lights on: inside the grid, touching a district with signals
		if i < 1 or j < 1 or i > grid.blocksX - 1 or j > grid.blocksZ - 1 then
			return false
		end
		for _, b in { { i - 1, j - 1 }, { i, j - 1 }, { i - 1, j }, { i, j } } do
			local d = Districts.of(b[1], b[2], grid.blocksX, grid.blocksZ)
			if (Streets.Districts :: any)[d].signals then
				return true
			end
		end
		return false
	end
	graph = Roads.graph(grid, lit)
	edge = grid.road / 2
	for n, p in Paints.List do
		if p.rgb then
			table.insert(paintColours, n)
		end
	end
	for n = 1, Cfg.Count do
		table.insert(cars, {
			id = n,
			kind = 1,
			paint = 0,
			gen = 0,
			link = 1,
			s = 0,
			nextLink = 1,
			turn = nil,
			u = 0,
			speed = 0,
			offset = Cfg.Lane,
			passing = false,
			blockedFor = 0,
			x = 0,
			z = 0,
			hx = 0,
			hz = -1,
			placed = false,
			crashedUntil = 0,
		})
	end
end

function TrafficService.start()
	if not graph then
		return
	end
	Net.remote("HitTraffic").OnServerEvent:Connect(onHit)
	local remote = Net.remote("Traffic")
	task.spawn(function()
		local last = os.clock()
		local sinceRecycle, sinceSend = math.huge, 0
		while true do
			task.wait(Cfg.Tick)
			local clock = os.clock()
			local dt = math.min(clock - last, 0.5)
			last = clock
			if #Players:GetPlayers() == 0 then
				continue
			end
			local ok, err = pcall(function()
				sinceRecycle += dt
				if sinceRecycle >= Cfg.RecycleEvery then
					sinceRecycle = 0
					recycle(clock)
				end
				step(dt, workspace:GetServerTimeNow())
				sinceSend += dt
				if sinceSend >= Cfg.SendEvery then
					sinceSend = 0
					remote:FireAllClients(snapshot(workspace:GetServerTimeNow()))
				end
			end)
			if not ok then
				warn("[Traffic]", err)
			end
		end
	end)
end

-- numbers for a play test
function TrafficService.stats(): { [string]: number }
	local placed, moving, crashed = 0, 0, 0
	for _, car in cars do
		if car.crashedUntil > 0 then
			crashed += 1
		elseif car.placed then
			placed += 1
			if car.speed > 5 then
				moving += 1
			end
		end
	end
	return { placed = placed, moving = moving, crashed = crashed }
end

return TrafficService
