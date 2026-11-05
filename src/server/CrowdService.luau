--!strict
-- The city's people. Everyone (residents, office workers, burger staff, warehouse staff, walkers, the spawn
-- crowd) exists as plain data that walks the sidewalk network, goes in and out of buildings and idles at
-- counters, desks, shelves and windows. Only people near a player get a real character, taken from a pool
-- and dressed for where they are; far away or out of sight inside, they're just numbers moving along.
-- NpcService handles hits, pay and ragdolls on the characters this module puts in workspace.Npcs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Crowd)
local EventConfig = require(ReplicatedStorage.Shared.Config.Events)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Interiors = require(ReplicatedStorage.Shared.Config.Interiors)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Ragdoll = require(ReplicatedStorage.Shared.Ragdoll)
local Routes = require(ReplicatedStorage.Shared.Rules.Routes)
local Rules = require(ReplicatedStorage.Shared.Rules.Crowd)
local World = require(ReplicatedStorage.Shared.Config.World)
local NpcLooks = require(script.Parent.NpcLooks)
local Places = require(script.Parent.Places)

local CrowdService = {}

type Place = Places.Place
type Spot = Places.Spot
export type Friend = { userId: number, name: string, friendOf: string }
type Mode = "walk" | "idle" | "inside" | "down" | "held" | "dormant"
export type Person = {
	role: Rules.Role,
	outfit: Rules.Outfit,
	friendSlot: boolean,
	friend: Friend?,
	look: NpcLooks.Look,
	home: Place?,
	speed: number,
	pos: Vector3, -- feet, on the ground
	route: { Vector3 },
	routeAt: { Place | false }, -- the building each waypoint is inside of
	step: number,
	mode: Mode,
	at: Place?, -- where they are (inside, or at a spot)
	goingTo: Place?,
	goingSpot: Spot?,
	spot: Spot?, -- the spot they hold (nobody else picks it)
	spotPath: { Vector3 }?, -- how they got to it, to walk back out
	fromHub: boolean,
	untilT: number,
	model: Model?,
	golden: boolean,
	giant: boolean,
	extra: boolean,
	lastPaid: { [Player]: number },
	checkAt: number,
	checkPos: Vector3,
	movedAt: number,
	gait: string?,
}

local Y = 0.08 -- ground level on the blocks
local LIFT = 4 -- two waypoints in a row this far apart in height are a ride in an office lift
local folder = Instance.new("Folder")
folder.Name = "Npcs"
folder.Parent = workspace
CrowdService.folder = folder

local people: { Person } = {}
local byModel: { [Model]: Person } = {}
local placesOf: { [string]: { Place } } = {}
local spotTaken: { [Spot]: Person } = {}
local graph: Routes.Graph? = nil
local friendIds: { [number]: boolean } = {}
local cast: { Friend } = {}
local castIds: { [number]: boolean } = {}
local random = Random.new()

local function rand(lo: number, hi: number): number
	return random:NextNumber(lo, hi)
end

local function rng(): number
	return random:NextNumber()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, Y, v.Z)
end

local function nodePos(id: number): Vector3
	local n = (graph :: Routes.Graph).nodes[id]
	local j = Config.LaneJitter
	return Vector3.new(n.x + rand(-j, j), Y, n.z + rand(-j, j))
end

local function isStaff(p: Person): boolean
	return Rules.isStaff(p.role)
end

local function setGait(p: Person, gait: string)
	if p.gait ~= gait then
		p.gait = gait
		if p.model then
			p.model:SetAttribute("Gait", gait)
		end
	end
end

local function releaseSpot(p: Person)
	if p.spot and spotTaken[p.spot] == p then
		spotTaken[p.spot] = nil
	end
	p.spot = nil
end

local function freeSpot(list: { Spot }): Spot?
	if #list == 0 then
		return nil
	end
	local start = random:NextInteger(1, #list)
	for k = 0, #list - 1 do
		local s = list[(start + k - 1) % #list + 1]
		if not spotTaken[s] then
			return s
		end
	end
	return nil
end

-- get up off a seat (a seated root is held still)
local function unseat(p: Person)
	local root = p.model and p.model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and root.Anchored then
		root.Anchored = false
	end
end

-- at a spot: face the right way; on a seat (furniture the client draws), sit down
local function settle(p: Person)
	local spot, m = p.spot, p.model
	local root = m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (spot and root) then
		return
	end
	local face = spot.face or root.CFrame.LookVector
	if spot.sit then
		local seat = spot.path[#spot.path]
		local at = Vector3.new(seat.X, seat.Y + Interiors.SitHeight * Game.BodyScale, seat.Z)
		root.Anchored = true
		root.CFrame = CFrame.lookAt(at, at + face)
		setGait(p, "sit")
	else
		root.CFrame = CFrame.lookAt(root.Position, root.Position + face)
	end
end

-- start walking the route just built (a built character gets its first MoveTo now)
local function startRoute(p: Person)
	unseat(p)
	p.mode = "walk"
	setGait(p, "walk")
	local m = p.model
	if m then
		local humanoid = m:FindFirstChildOfClass("Humanoid")
		if humanoid and p.route[p.step] then
			humanoid:MoveTo(p.route[p.step])
		end
		p.movedAt = os.clock()
		p.checkAt, p.checkPos = os.clock(), p.pos
	end
end

local function push(p: Person, v: Vector3, at: Place | false)
	table.insert(p.route, v)
	table.insert(p.routeAt, at)
end

-- walk back from the spot they're on to the hub or entry (and out of the door if `toDoor`)
local function backOut(p: Person, place: Place, toDoor: boolean)
	if not place.indoors then
		return
	end
	local path = p.spotPath
	if path then
		for k = #path - 1, 1, -1 do
			push(p, path[k], place)
		end
	end
	if p.fromHub and place.hub then
		push(p, place.hub, place)
		if toDoor and place.staffIn then
			for k = #place.staffIn - 1, 1, -1 do
				push(p, place.staffIn[k], place)
			end
		end
	end
	if toDoor or not (p.fromHub and place.hub) then
		push(p, place.entry, place)
	end
	if toDoor then
		push(p, place.door, false)
	end
end

-- a route to `dest` (and into `spot`, or out of sight just inside when nil)
local function goTo(p: Person, dest: Place, spot: Spot?, staff: boolean)
	p.route, p.routeAt, p.step = {}, {}, 1
	local from = p.at
	if from == dest and (p.mode == "inside" or p.mode == "idle") then
		if p.mode == "idle" and p.spot then
			backOut(p, dest, false)
		end
	else
		if from then
			backOut(p, from, true)
		end
		local g = graph
		if g and dest.node then
			local startNode = if from
					and from.node
					and from.indoors
				then from.node
				else Routes.nearest(g, p.pos.X, p.pos.Z)
			local path = Routes.path(g, startNode, dest.node :: number)
			if path then
				for _, id in path do
					push(p, nodePos(id), false)
				end
			end
		end
		push(p, dest.door, false)
		if dest.indoors then
			push(p, dest.entry, dest)
		end
		if staff and dest.hub then
			for _, v in dest.staffIn or { dest.hub :: Vector3 } do
				push(p, v, dest)
			end
		end
	end
	releaseSpot(p)
	if spot then
		spotTaken[spot] = p
		p.spot = spot
		for _, v in spot.path do
			push(p, v, if dest.indoors then dest else false)
		end
	end
	p.goingTo, p.goingSpot = dest, spot
	p.spotPath = if spot then spot.path else nil
	p.fromHub = staff and dest.hub ~= nil
	p.at = from
	startRoute(p)
end

-- somewhere on the sidewalks not far away
local function wander(p: Person)
	local g = graph
	if not g then
		return
	end
	local here = Routes.nearest(g, p.pos.X, p.pos.Z)
	local target = here
	for _ = 1, 10 do
		local id = random:NextInteger(1, #g.nodes)
		local n = g.nodes[id]
		if (Vector3.new(n.x, Y, n.z) - p.pos).Magnitude < 450 then
			target = id
			break
		end
	end
	p.route, p.routeAt, p.step = {}, {}, 1
	local from = p.at
	if from then
		backOut(p, from, true)
	end
	local start = if from and from.indoors and from.node then from.node :: number else here
	for _, id in Routes.path(g, start, target) or { target } do
		push(p, nodePos(id), false)
	end
	releaseSpot(p)
	p.at, p.goingTo, p.goingSpot, p.spotPath, p.fromHub = from, nil, nil, nil, false
	startRoute(p)
end

-- one of the nearest places of a kind
local function nearPlace(kind: string, pos: Vector3): Place?
	local list = placesOf[kind]
	if not list or #list == 0 then
		return nil
	end
	local best: { { place: Place, d: number } } = {}
	for _, pl in list do
		table.insert(best, { place = pl, d = (pl.door - pos).Magnitude })
	end
	table.sort(best, function(a, b)
		return a.d < b.d
	end)
	return best[random:NextInteger(1, math.min(4, #best))].place
end

local function visitorSpot(place: Place): Spot?
	if place.kind == "home" then
		return if rng() < Config.HomeSpotChance then freeSpot(place.spots) else nil
	elseif place.kind == "office" then
		return if rng() < Config.OfficeSpotChance then freeSpot(place.spots) else nil
	elseif place.kind == "shop" then
		return if rng() < Config.ShopSpotChance then freeSpot(place.spots) else nil
	end
	return freeSpot(place.spots)
end

local function decide(p: Person)
	local home = p.home
	local goal = Rules.nextGoal(p.role, p.at ~= nil and p.at == home, rng, Config)
	if goal == "stay" and p.at then
		local spot = visitorSpot(p.at :: Place)
		if spot or p.mode == "idle" then
			goTo(p, p.at :: Place, spot, false)
		else
			p.mode = "inside"
			p.untilT = os.clock() + rand(Config.InsideMin, Config.InsideMax)
		end
	elseif goal == "spot" and home then
		local spot = freeSpot(home.staffSpots)
		if spot then
			goTo(p, home, spot, true)
		else
			p.untilT = os.clock() + rand(Config.SpotIdleMin, Config.SpotIdleMax)
		end
	elseif (goal == "crowd" or goal == "stunt") and home then
		local spot = freeSpot(home.spots)
		p.route, p.routeAt, p.step = {}, {}, 1
		releaseSpot(p)
		if spot then
			spotTaken[spot] = p
			p.spot = spot
			push(p, spot.path[#spot.path], false)
		end
		p.at, p.goingTo, p.goingSpot = home, home, spot
		startRoute(p)
	elseif (goal == "home" or goal == "work") and home then
		goTo(p, home, visitorSpot(home), false)
	elseif goal == "wander" or goal == "stay" then
		wander(p)
	else
		local place = nearPlace(goal, p.pos)
		if place then
			goTo(p, place, visitorSpot(place), false)
		else
			wander(p)
		end
	end
end

local function arrive(p: Person)
	local now = os.clock()
	local dest = p.goingTo
	p.goingTo = nil
	if dest then
		p.at = dest
		if p.goingSpot then
			p.mode = "idle"
			p.untilT = now + rand(Config.SpotIdleMin, Config.SpotIdleMax)
		elseif dest.indoors then
			p.mode = "inside"
			p.spotPath = nil
			p.untilT = now
				+ (if isStaff(p) then rand(4, 10) else rand(Config.InsideMin, Config.InsideMax))
		else
			p.mode = "idle"
			p.untilT = now + rand(Config.PauseMin, Config.PauseMax)
		end
	else
		p.at = nil
		p.mode = "idle"
		p.untilT = now
			+ (if rng() < Config.PauseChance then rand(Config.PauseMin, Config.PauseMax) else 0)
	end
	setGait(p, "idle")
	if p.mode == "idle" and p.spot then
		settle(p)
	end
end

-- a fresh person of a role
local function newPerson(
	role: Rules.Role,
	outfit: Rules.Outfit,
	home: Place?,
	friendSlot: boolean
): Person
	return {
		role = role,
		outfit = outfit,
		friendSlot = friendSlot,
		friend = nil,
		look = NpcLooks.roll(outfit),
		home = home,
		speed = World.Npc.WalkSpeed * rand(Config.SpeedMin, Config.SpeedMax),
		pos = Vector3.new(0, Y, 0),
		route = {},
		routeAt = {},
		step = 1,
		mode = "idle",
		at = nil,
		goingTo = nil,
		goingSpot = nil,
		spot = nil,
		spotPath = nil,
		fromHub = false,
		untilT = 0,
		model = nil,
		golden = false,
		giant = false,
		extra = false,
		lastPaid = {},
		checkAt = 0,
		checkPos = Vector3.zero,
		movedAt = 0,
		gait = nil,
	}
end

local function randomNode(awayFrom: { Vector3 }, minDist: number): Vector3
	local g = graph :: Routes.Graph
	local best = nodePos(random:NextInteger(1, #g.nodes))
	for _ = 1, 12 do
		local v = nodePos(random:NextInteger(1, #g.nodes))
		local ok = true
		for _, a in awayFrom do
			if (a - v).Magnitude < minDist then
				ok = false
				break
			end
		end
		if ok then
			return v
		end
	end
	return best
end

local function playerSpots(): { Vector3 }
	local out = {}
	for _, pl in Players:GetPlayers() do
		local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			table.insert(out, root.Position)
		end
	end
	return out
end

-- where someone starts (or comes back after being knocked down)
local function place(p: Person, fresh: boolean)
	releaseSpot(p)
	p.route, p.routeAt, p.step = {}, {}, 1
	p.goingTo, p.goingSpot, p.spotPath, p.fromHub = nil, nil, nil, false
	local home = p.home
	if p.role == "crowd" or p.role == "spectator" then
		local spots = (home :: Place).spots
		p.pos = flat(spots[random:NextInteger(1, #spots)].path[1])
		p.at = home
		p.mode = "idle"
		p.untilT = os.clock() + rand(0, 3)
	elseif (p.role == "walker") and graph then
		p.pos = randomNode(if fresh then {} else playerSpots(), Config.DeactivateRadius)
		p.at = nil
		p.mode = "idle"
		p.untilT = os.clock() + rand(0, 2)
	elseif home then
		p.at = home
		p.pos = flat(if isStaff(p) and home.hub then home.hub else home.entry)
		p.fromHub = isStaff(p) and home.hub ~= nil
		p.mode = "inside"
		p.untilT = os.clock() + (if fresh then rand(0, 20) else rand(8, 20))
	end
	if p.golden or workspace:GetAttribute("Event") ~= "GoldenRush" then
		p.golden = false
	elseif rng() < EventConfig.GoldenRespawnChance then
		p.golden = true
	end
end

-- everyone in the city, from its places
function CrowdService.setup(placesList: { Place }, grid: Routes.Grid)
	local g = Routes.new(grid)
	for _, pl in placesList do
		placesOf[pl.kind] = placesOf[pl.kind] or {}
		table.insert(placesOf[pl.kind], pl)
		if pl.block then
			pl.node = Routes.addOnSide(g, pl.block[1], pl.block[2], pl.door.X, pl.door.Z)
		end
	end
	Routes.finish(g)
	graph = g
	local kinds: { Rules.PlaceKind } = {}
	for _, pl in placesList do
		table.insert(kinds, pl.kind)
	end
	local roster = Rules.roster(kinds, Config, Onboarding.SpawnCrowd, rng)
	Rules.pickFriends(roster, Config.FriendEvery, rng)
	for _, r in roster do
		local p = newPerson(r.role, r.outfit, if r.home then placesList[r.home] else nil, r.friend)
		place(p, true)
		table.insert(people, p)
	end
	for _ = 1, EventConfig.StampedeExtraNpcs do
		local p = newPerson("walker", "casual", nil, false)
		p.extra = true
		p.mode = "dormant"
		table.insert(people, p)
	end
end

function CrowdService.count(): number
	return #people
end

-- a player's friends join the pool; a few of them become the city's familiar faces
function CrowdService.addFriend(f: Friend)
	if friendIds[f.userId] then
		return
	end
	friendIds[f.userId] = true
	if #cast < Config.FriendRigsMax then
		table.insert(cast, f)
		castIds[f.userId] = true
	elseif rng() < 0.2 then
		local k = random:NextInteger(1, #cast)
		castIds[cast[k].userId] = nil
		cast[k] = f
		castIds[f.userId] = true
	end
end

local function indoorNow(p: Person): boolean
	if p.mode == "walk" then
		return p.routeAt[p.step] ~= false and p.routeAt[p.step] ~= nil
	end
	return p.at ~= nil and (p.at :: Place).indoors
end

local function rootOf(m: Model): BasePart?
	return m:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function activate(p: Person, asFriend: boolean?): boolean
	local model: Model? = nil
	if asFriend and #cast > 0 then
		if not p.friend or not castIds[(p.friend :: Friend).userId] then
			p.friend = cast[random:NextInteger(1, #cast)]
		end
		local f = p.friend :: Friend
		model = NpcLooks.takeFriend(f.userId, f.name, f.friendOf)
	end
	if not model then
		model = NpcLooks.take()
		if not model then
			return false
		end
		NpcLooks.dress(model :: Model, p.look)
	end
	local m = model :: Model
	local humanoid = m:FindFirstChildOfClass("Humanoid")
	local root = rootOf(m)
	if not (humanoid and root) then
		-- a character that lost parts (flung out of the world) is thrown away, not reused
		NpcLooks.forget(m)
		m:Destroy()
		return false
	end
	humanoid.WalkSpeed = p.speed
	humanoid.PlatformStand = false
	local target = p.route[p.step]
	local look = if target and (flat(target) - p.pos).Magnitude > 0.5
		then flat(target) - p.pos
		elseif p.spot and p.spot.face then p.spot.face
		else Vector3.new(rand(-1, 1), 0, rand(-1, 1))
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	end
	local up = humanoid.HipHeight + root.Size.Y / 2
	-- on an upper office floor (walking there, or at a spot up there) the feet go on that floor
	local floorAt = if p.mode == "walk" and target
		then target
		elseif p.spot then p.spot.path[#p.spot.path]
		else nil
	local feet = Vector3.new(p.pos.X, if floorAt then floorAt.Y else p.pos.Y, p.pos.Z)
	m:PivotTo(CFrame.lookAt(feet + Vector3.new(0, up, 0), feet + Vector3.new(0, up, 0) + look))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	p.gait = nil
	p.model = m
	byModel[m] = p
	m.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	setGait(p, if p.mode == "walk" then "walk" else "idle")
	if p.mode == "idle" and p.spot and p.goingTo == nil then
		settle(p)
	end
	if p.golden then
		CrowdService.glow(m, true)
	end
	if target and p.mode == "walk" then
		humanoid:MoveTo(target)
	end
	p.movedAt = os.clock()
	p.checkAt, p.checkPos = os.clock(), p.pos
	return true
end

local function deactivate(p: Person)
	local m = p.model
	if not m then
		return
	end
	local root = rootOf(m)
	if root then
		p.pos = flat(root.Position)
	end
	byModel[m] = nil
	p.model = nil
	if p.giant then
		m:Destroy()
	else
		NpcLooks.give(m)
	end
end

function CrowdService.glow(m: Model, on: boolean)
	local h = m:FindFirstChild("GoldenGlow")
	if on and not h then
		local hl = Instance.new("Highlight")
		hl.Name = "GoldenGlow"
		hl.FillColor = Color3.fromRGB(255, 205, 60)
		hl.FillTransparency = 0.35
		hl.OutlineColor = Color3.fromRGB(255, 240, 160)
		hl.Parent = m
	elseif not on and h then
		h:Destroy()
	end
	m:SetAttribute("Golden", if on then true else nil)
end

function CrowdService.personOf(m: Model): Person?
	return byModel[m]
end

-- characters in the world right now (knocked-down ones included)
function CrowdService.active(): { Model }
	local out = {}
	for m in byModel do
		table.insert(out, m)
	end
	return out
end

function CrowdService.setGolden(m: Model, on: boolean)
	local p = byModel[m]
	if p then
		p.golden = on
	end
	CrowdService.glow(m, on)
end

function CrowdService.clearGolden()
	for _, p in people do
		p.golden = false
		if p.model then
			CrowdService.glow(p.model, false)
		end
	end
end

-- knocked down: stop thinking about them until they're recycled
function CrowdService.down(m: Model)
	local p = byModel[m]
	if p then
		unseat(p)
		p.mode = "down"
		releaseSpot(p)
		setGait(p, "idle")
	end
end

-- after a knock-down: the character goes back to the pool and the person turns up again somewhere sensible
function CrowdService.recycle(m: Model)
	local p = byModel[m]
	if not p then
		if m.Parent then
			m:Destroy()
		end
		return
	end
	Ragdoll.disable(m)
	byModel[m] = nil
	p.model = nil
	if p.giant then
		m:Destroy()
		table.remove(people, table.find(people, p) :: number)
		return
	end
	NpcLooks.give(m)
	p.lastPaid = {}
	place(p, false)
end

function CrowdService.isBusy(m: Model): boolean
	local p = byModel[m]
	return p == nil or p.mode == "held" or p.mode == "down"
end

-- walk (or run) straight at something for a while (taxi call, ice-cream jingle), then carry on
function CrowdService.hold(m: Model, pos: Vector3, seconds: number, run: boolean)
	local p = byModel[m]
	local humanoid = m:FindFirstChildOfClass("Humanoid")
	if not p or not humanoid or p.mode == "down" then
		return
	end
	local root = rootOf(m)
	if root and root.Position.Y > LIFT + 6 then
		return -- upstairs in an office: they can't hear it
	end
	unseat(p)
	releaseSpot(p)
	p.mode = "held"
	p.at, p.goingTo, p.goingSpot, p.spotPath = nil, nil, nil, nil
	p.untilT = os.clock() + seconds
	humanoid.WalkSpeed = if run then p.speed * 2.2 else p.speed
	humanoid:MoveTo(pos)
	setGait(p, if run then "run" else "walk")
end

-- a giant (Giant in Town): a casual passer-by built just for the event, always in the world
function CrowdService.spawnGiant(at: Vector3): Model?
	local p = newPerson("walker", "casual", nil, false)
	p.giant = true
	p.pos = flat(at)
	p.mode = "idle"
	table.insert(people, p)
	if not activate(p) then
		table.remove(people, table.find(people, p) :: number)
		return nil
	end
	local m = p.model :: Model
	m.Destroying:Connect(function()
		if byModel[m] then
			byModel[m] = nil
			local k = table.find(people, p)
			if k then
				table.remove(people, k)
			end
		end
	end)
	return m
end

local function step(p: Person, dt: number, now: number)
	local m = p.model
	if p.mode == "held" then
		if now > p.untilT then
			if m then
				local humanoid = m:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = p.speed
				end
			end
			p.mode = "idle"
			p.untilT = 0
		end
		return
	end
	if p.mode == "idle" or p.mode == "inside" then
		if now > p.untilT then
			decide(p)
		end
		return
	end
	if p.mode ~= "walk" then
		return
	end
	local target = p.route[p.step]
	if not target then
		arrive(p)
		return
	end
	if m then
		local root = rootOf(m)
		local humanoid = m:FindFirstChildOfClass("Humanoid")
		if not (root and humanoid) then
			return
		end
		p.pos = flat(root.Position)
		if (flat(target) - p.pos).Magnitude <= Config.WaypointReach then
			p.step += 1
			local nextTarget = p.route[p.step]
			if nextTarget and math.abs(nextTarget.Y - target.Y) > LIFT then
				-- the next point is on another floor right above or below: ride the lift
				local up = humanoid.HipHeight + root.Size.Y / 2
				m:PivotTo(root.CFrame.Rotation + nextTarget + Vector3.new(0, up, 0))
				p.step += 1
				nextTarget = p.route[p.step]
			end
			if nextTarget then
				humanoid:MoveTo(nextTarget)
				p.movedAt = now
				p.checkAt, p.checkPos = now, p.pos
			else
				arrive(p)
			end
		elseif now - p.checkAt > Config.StuckSeconds then
			-- blocked (a post, a tree, a wreck): give up on this waypoint
			if (p.pos - p.checkPos).Magnitude < 1.5 then
				p.step += 1
				local nextTarget = p.route[p.step]
				if nextTarget then
					humanoid:MoveTo(nextTarget)
					p.movedAt = now
				end
			end
			p.checkAt, p.checkPos = now, p.pos
		elseif now - p.movedAt > 5 then
			humanoid:MoveTo(target) -- MoveTo gives up after 8 s
			p.movedAt = now
		end
	else
		local to = flat(target) - p.pos
		local len = p.speed * dt
		if to.Magnitude <= len then
			p.pos = flat(target)
			p.step += 1
		else
			p.pos += to.Unit * len
		end
	end
end

local stampede = false

local function refreshActive()
	local spots = playerSpots()
	local event = workspace:GetAttribute("Event")
	local nowStampede = event == "Stampede"
	if nowStampede ~= stampede then
		stampede = nowStampede
		for _, p in people do
			if p.extra then
				if stampede and #spots > 0 then
					local near = spots[random:NextInteger(1, #spots)]
					p.pos = randomNode({}, 0)
					local g = graph :: Routes.Graph
					for _ = 1, 20 do
						local id = random:NextInteger(1, #g.nodes)
						local n = g.nodes[id]
						local d = (Vector3.new(n.x, Y, n.z) - near).Magnitude
						if d > 80 and d < 280 then
							p.pos = nodePos(id)
							break
						end
					end
					p.mode = "idle"
					p.untilT = 0
				elseif not stampede and p.mode ~= "down" then
					deactivate(p)
					p.mode = "dormant"
				end
			end
		end
	end
	local cands: { Rules.Candidate } = {}
	local who: { Person } = {}
	local nearestHome, nearestHomeBuilt = math.huge, false
	for _, p in people do
		if p.giant or p.mode == "down" then
			continue
		end
		local hidden = p.mode == "inside" or p.mode == "dormant"
		if hidden then
			if p.model then
				deactivate(p)
			end
			continue
		end
		local best = math.huge
		for _, s in spots do
			local d = (s - p.pos).Magnitude
			if d < best then
				best = d
			end
		end
		-- walkers nobody can see drift back toward players, appearing on a sidewalk just out of view,
		-- so the streets round every player stay busy without millions of people
		if
			p.role == "walker"
			and not p.extra
			and not p.model
			and best > Config.RecallDistance
			and #spots > 0
			and rng() < Config.RecallChance
		then
			local g = graph :: Routes.Graph
			local near = spots[random:NextInteger(1, #spots)]
			for _ = 1, 12 do
				local id = random:NextInteger(1, #g.nodes)
				local n = g.nodes[id]
				local d = (Vector3.new(n.x, Y, n.z) - near).Magnitude
				if d > Config.RecallMin and d < Config.RecallMax then
					releaseSpot(p)
					p.pos = nodePos(id)
					p.route, p.routeAt, p.step = {}, {}, 1
					p.at, p.goingTo, p.goingSpot, p.spotPath = nil, nil, nil, nil
					p.mode, p.untilT = "idle", 0
					best = d
					break
				end
			end
		end
		if p.role == "resident" and p.mode == "idle" and p.spot and best < nearestHome then
			nearestHome, nearestHomeBuilt = best, p.model ~= nil
		end
		table.insert(cands, { dist = best, indoor = indoorNow(p), active = p.model ~= nil })
		table.insert(who, p)
	end
	local cfg = {
		MaxActive = Config.MaxActive + (if stampede then EventConfig.StampedeExtraNpcs else 0),
		ActivateRadius = Config.ActivateRadius,
		DeactivateRadius = Config.DeactivateRadius,
		IndoorRadius = Config.IndoorRadius,
		IndoorLeave = Config.IndoorLeave,
	}
	local keep = Rules.pickActive(cands, cfg)
	local toBuild: { { p: Person, d: number } } = {}
	for k, p in who do
		if keep[k] and not p.model then
			table.insert(toBuild, { p = p, d = cands[k].dist })
		elseif not keep[k] and p.model then
			deactivate(p)
		end
	end
	table.sort(toBuild, function(a, b)
		return a.d < b.d
	end)
	-- about one in FriendEvery of the people shown wear a friend's avatar
	local shown, shownFriends = 0, 0
	for m in byModel do
		shown += 1
		if m:GetAttribute("FriendId") then
			shownFriends += 1
		end
	end
	for n = 1, math.min(#toBuild, Config.BuildsPerTick) do
		local p = toBuild[n].p
		local asFriend = Rules.canBeFriend(p :: any)
			and Rules.wantFriend(shownFriends, shown, Config.FriendEvery)
		if activate(p, asFriend) then
			shown += 1
			if p.model and p.model:GetAttribute("FriendId") then
				shownFriends += 1
			end
		end
	end
	-- numbers for play tests (read the folder's attributes)
	local s = CrowdService.stats()
	folder:SetAttribute("People", s.people)
	folder:SetAttribute("Active", s.active)
	folder:SetAttribute("FriendsShown", s.friendsShown)
	folder:SetAttribute("Inside", s.inside)
	folder:SetAttribute("FriendCast", #cast)
	folder:SetAttribute("HomeSpot", s.homeSpot)
	folder:SetAttribute("HomeHidden", s.homeHidden)
	folder:SetAttribute("NearestHome", math.floor(math.min(nearestHome, 99999)))
	folder:SetAttribute("NearestHomeBuilt", nearestHomeBuilt)
end

function CrowdService.start()
	task.spawn(function()
		NpcLooks.init()
		local last = os.clock()
		local sinceRefresh = math.huge
		while true do
			task.wait(Config.ThinkSeconds)
			local now = os.clock()
			local dt = now - last
			last = now
			-- one bad person or character must never stop the whole city
			for _, p in people do
				local ok, err = pcall(step, p, dt, now)
				if not ok then
					warn("[Crowd] step:", err)
					p.mode, p.untilT = "idle", now + 5
				end
			end
			sinceRefresh += dt
			if sinceRefresh >= 0.5 then
				sinceRefresh = 0
				local ok, err = pcall(refreshActive)
				if not ok then
					warn("[Crowd] refresh:", err)
				end
			end
		end
	end)
end

-- numbers for a performance check (Studio command bar / play test)
function CrowdService.stats(): { [string]: number }
	local s = {
		people = 0,
		active = 0,
		friendsShown = 0,
		walking = 0,
		inside = 0,
		hairs = 0,
		homeSpot = 0,
		homeHidden = 0,
	}
	for _, p in people do
		if p.mode ~= "dormant" then
			s.people += 1
		end
		if p.model then
			s.active += 1
			if p.model:GetAttribute("FriendId") then
				s.friendsShown += 1
			end
		end
		if p.mode == "walk" then
			s.walking += 1
		elseif p.mode == "inside" then
			s.inside += 1
		end
		if p.role == "resident" and p.at and p.at == p.home then
			if p.mode == "idle" and p.spot then
				s.homeSpot += 1
			elseif p.mode == "inside" then
				s.homeHidden += 1
			end
		end
	end
	s.hairs = NpcLooks.hairCount()
	return s
end

return CrowdService
