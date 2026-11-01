--!strict
-- Run with: lune run tests/run
local CityPlan = require("../src/shared/Rules/CityPlan")
local CrowdConfig = require("../src/shared/Config/Crowd")
local CrowdRules = require("../src/shared/Rules/Crowd")
local Districts = require("../src/shared/Rules/Districts")
local Streets = require("../src/shared/Config/Streets")
local Economy = require("../src/shared/Config/Economy")
local Game = require("../src/shared/Config/Game")
local Impact = require("../src/shared/Rules/Impact")
local EventConfig = require("../src/shared/Config/Events")
local EventRules = require("../src/shared/Rules/Events")
local Products = require("../src/shared/Config/Products")
local LbConfig = require("../src/shared/Config/Leaderboards")
local Lb = require("../src/shared/Rules/Leaderboards")
local QuestConfig = require("../src/shared/Config/Quests")
local Routes = require("../src/shared/Rules/Routes")
local Quests = require("../src/shared/Rules/Quests")
local Vehicles = require("../src/shared/Config/Vehicles")
local World = require("../src/shared/Config/World")

local failures = 0
local function check(name: string, ok: boolean)
	if ok then
		print("PASS " .. name)
	else
		print("FAIL " .. name)
		failures += 1
	end
end

local function near(a: number, b: number, eps: number): boolean
	return math.abs(a - b) <= eps
end

check("WalkSpeed is positive", Game.Player.WalkSpeed > 0)
check("JumpPower is positive", Game.Player.JumpPower > 0)

-- vehicles
check("13 vehicles", #Vehicles.List == 13)
check("starter is free", Vehicles.ById[Vehicles.Starter].price == 0)
check("Roadster costs 1M", Vehicles.ById.Roadster.price == 1000000)
local ids, orders = {}, {}
local allGood = true
for _, v in Vehicles.List do
	if ids[v.id] or orders[v.order] then
		allGood = false
	end
	ids[v.id], orders[v.order] = true, true
	if
		v.weight <= 0
		or v.topSpeed <= 0
		or v.launch <= 0
		or v.power <= 0
		or v.grip <= 0
		or #v.seat ~= 3
	then
		allGood = false
	end
end
check("vehicle ids and orders unique, stats positive", allGood)
local enginesOk, engineKinds = true, {}
for _, v in Vehicles.List do
	local e = Vehicles.Engines[v.engine]
	engineKinds[v.engine] = true
	local tone = v.engineTone or 1
	if
		not e
		or not string.match(e.sound, "^rbxassetid://%d+$")
		or e.idlePitch <= 0
		or e.topPitch <= e.idlePitch
		or e.topPitch * tone * 1.3 > 4
		or e.volume <= 0
		or e.idle < 0
		or e.idle > 1
		or (e.loop and (#e.loop ~= 2 or e.loop[1] < 0 or e.loop[2] - e.loop[1] < 2))
	then
		enginesOk = false
	end
end
check("every vehicle has a sane engine sound", enginesOk)
local kindCount = 0
for _ in engineKinds do
	kindCount += 1
end
check("at least 8 different engine sounds in use", kindCount >= 8)
local electric = 0
for _, v in Vehicles.List do
	if v.engine == "Electric" then
		electric += 1
	end
end
check(
	"electric only on the Roadster",
	Vehicles.ById.Roadster.engine == "Electric" and electric == 1
)
local trailers = 0
local trailersOk = true
for _, v in Vehicles.List do
	local t = v.trailer
	if t then
		trailers += 1
		if
			Vehicles.ById[t.model]
			or #t.hitch ~= 3
			or #t.kingpin ~= 3
			or t.swing <= 20
			or t.swing >= 90
			or t.sideGrip <= 0
			or t.hitch[3] <= 0 -- hitch sits behind the tractor's centre
			or t.kingpin[3] >= 0 -- kingpin sits ahead of the trailer's centre
		then
			trailersOk = false
		end
	end
end
check("the semi pulls a trailer", Vehicles.ById.Semi.trailer ~= nil and trailers == 1)
check("trailer settings sane", trailersOk)
check(
	"early cars don't break buildings",
	not (
			Vehicles.ById.Hatchback.breaksBuildings
			or Vehicles.ById.Sedan.breaksBuildings
			or Vehicles.ById.Muscle.breaksBuildings
		)
)
check(
	"big and fast vehicles break buildings",
	Vehicles.ById.Semi.breaksBuildings and Vehicles.ById.Supercar.breaksBuildings
)
check(
	"only Roadster has the jet",
	Vehicles.has(Vehicles.ById.Roadster, "Jet") and not Vehicles.has(Vehicles.ById.Supercar, "Jet")
)
check(
	"thruster on Roadster and supercar",
	Vehicles.has(Vehicles.ById.Supercar, "Thruster")
		and Vehicles.has(Vehicles.ById.Roadster, "Thruster")
)

-- impact
check("energy formula", near(Impact.energy(2000, 10), 100000, 0.001))
check("energy never negative for bad weight", Impact.energy(-5, 10) == 0)
check(
	"strength 0 at low",
	Impact.strength(Economy.EnergyLow, Economy.EnergyLow, Economy.EnergyHigh) == 0
)
check(
	"strength 1 past high",
	Impact.strength(Economy.EnergyHigh * 10, Economy.EnergyLow, Economy.EnergyHigh) == 1
)
check("combo starts at 1", Impact.comboMultiplier(1, 0.2, 3) == 1)
check("combo grows", near(Impact.comboMultiplier(3, 0.2, 3), 1.4, 1e-9))
check("combo caps", Impact.comboMultiplier(100, 0.2, 3) == 3)
check("combo of 0 hits is 1", Impact.comboMultiplier(0, 0.2, 3) == 1)
local soft = Impact.npcPayout(Impact.energy(150, 7), 1, Economy)
local hard = Impact.npcPayout(Impact.energy(15000, 18), 1, Economy)
check("soft hit pays the base", near(soft, Economy.NpcBase, 1e-6))
check("semi hit pays more than scooter", hard > soft)
check(
	"payout capped",
	Impact.npcPayout(1e12, 1, Economy) <= Economy.NpcBase + Economy.NpcBonusMax + 1e-6
)
-- the draft's claim: a semi at 40 mph hits about as hard as a supercar at 120
local semi = Impact.energy(15000, 40 / 2.237)
local supercar = Impact.energy(1500, 120 / 2.237)
check("semi at 40 ~ supercar at 120", semi / supercar > 0.8 and semi / supercar < 1.4)
check("parking against a wall breaks nothing", Impact.breakRadius(Impact.energy(20000, 1)) == 0)
check("Roadster at full speed breaks a lot", Impact.breakRadius(Impact.energy(2000, 112)) > 20)
check("launch grows with energy", Impact.launchSpeed(1e7) > Impact.launchSpeed(1e4))
check("blast radius bigger for heavier", Impact.blastRadius(20000, 0) > Impact.blastRadius(150, 0))
check("blast radius has a floor", Impact.blastRadius(0, 0) >= 14)

-- world
check("roads fit the semi", World.Map.RoadWidth >= 40)
check("debris budget positive", World.Debris.MaxLoose > 0)

-- goals
local function rngFrom(seed: number): () -> number
	math.randomseed(seed)
	return function()
		return math.random()
	end
end
local function always(_: string): boolean
	return true
end
local function never(_: string): boolean
	return false
end
check(
	"hourly period changes on the hour",
	Quests.period(3599, 3600) == 0 and Quests.period(3600, 3600) == 1
)
check("seconds left counts down", Quests.secondsLeft(3590, 3600) == 10)
local a = Quests.roll(QuestConfig.Hourly.Templates, 3, rngFrom(42), always)
local b = Quests.roll(QuestConfig.Hourly.Templates, 3, rngFrom(42), always)
check("roll gives 3 goals", #a == 3)
local same = true
for i = 1, 3 do
	if a[i].kind ~= b[i].kind or a[i].target ~= b[i].target then
		same = false
	end
end
check("same seed, same goals", same)
local kinds = {}
local distinct = true
for _, g in a do
	if kinds[g.kind] then
		distinct = false
	end
	kinds[g.kind] = true
end
check("goals in a set are different kinds", distinct)
local breaksOffered = false
for seed = 1, 40 do
	for _, g in Quests.roll(QuestConfig.Daily.Templates, 3, rngFrom(seed), never) do
		if g.kind == "Breaks" then
			breaksOffered = true
		end
	end
end
check("no building goal without a breaker vehicle", not breaksOffered)
local inRange = true
for seed = 1, 40 do
	for _, set in { QuestConfig.Hourly, QuestConfig.Daily } do
		for _, g in Quests.roll(set.Templates, set.Count, rngFrom(seed), always) do
			if
				g.target <= 0
				or g.reward < 10
				or g.reward % 10 ~= 0
				or string.find(g.text, "{n}", 1, true)
			then
				inRange = false
			end
		end
	end
end
check("targets positive, rewards rounded, text filled", inRange)
local goals = {
	{ kind = "Hits", mode = "add", text = "", target = 3, reward = 10, progress = 0, done = false },
	{
		kind = "Combo",
		mode = "max",
		text = "",
		target = 5,
		reward = 10,
		progress = 0,
		done = false,
	},
} :: { Quests.Goal }
check("add goal progresses", #Quests.advance(goals, "Hits", 2) == 0 and goals[1].progress == 2)
check("add goal completes once", #Quests.advance(goals, "Hits", 5) == 1 and goals[1].progress == 3)
check("done goal stays done", #Quests.advance(goals, "Hits", 1) == 0)
check("max goal keeps the best", #Quests.advance(goals, "Combo", 3) == 0 and goals[2].progress == 3)
Quests.advance(goals, "Combo", 2)
check("max goal doesn't drop", goals[2].progress == 3)
check("max goal completes", #Quests.advance(goals, "Combo", 6) == 1)
check("bad amounts ignored", #Quests.advance(goals, "Hits", 0 / 0) == 0)

-- leaderboards
local W, OFF = LbConfig.WeekSeconds, LbConfig.WeekStartOffset
-- 2026-10-26 00:00 UTC was a Monday: 1792972800
check("week starts on Monday", Lb.week(1792972800, W, OFF) == Lb.week(1792972800 + W - 1, W, OFF))
check(
	"next Monday is a new week",
	Lb.week(1792972800 - 1, W, OFF) + 1 == Lb.week(1792972800, W, OFF)
)
check("seconds left is a full week at the start", Lb.secondsLeft(1792972800, W, OFF) == W)
local st = Lb.fresh(5)
check(
	"hits add up",
	Lb.record(st, "Hits", 1) and Lb.record(st, "Hits", 2) and st.hits == 3 and st.allHits == 3
)
check(
	"launch keeps the best",
	Lb.record(st, "Launch", 120) and not Lb.record(st, "Launch", 80) and st.launch == 120
)
check("combo keeps the best", Lb.record(st, "Combo", 4) and st.combo == 4)
check(
	"bad values ignored",
	not Lb.record(st, "Hits", 0 / 0) and not Lb.record(st, "Hits", -3) and st.hits == 3
)
check("same week doesn't reset", not Lb.roll(st, 5) and st.hits == 3)
check(
	"new week resets weekly only",
	Lb.roll(st, 6) and st.hits == 0 and st.launch == 0 and st.allHits == 3 and st.allLaunch == 120
)
local ranked = Lb.rank({
	{ userId = 3, name = "c", value = 5 },
	{ userId = 1, name = "a", value = 9 },
	{ userId = 2, name = "b", value = 5 },
	{ userId = 4, name = "d", value = 0 },
}, 2)
check(
	"rank: highest first, ties by id, top N, zeros dropped",
	#ranked == 2 and ranked[1].userId == 1 and ranked[2].userId == 2
)

-- products
local keys, packsOk = {}, true
for _, pack in Products.MoneyPacks do
	if keys[pack.key] or pack.money <= 0 or pack.robux <= 0 or pack.once then
		packsOk = false
	end
	keys[pack.key] = true
end
check("money packs: unique keys, positive, repeatable", packsOk and not keys[Products.Starter.key])
local ascending = true
for i = 2, #Products.MoneyPacks do
	local lo, hi = Products.MoneyPacks[i - 1], Products.MoneyPacks[i]
	if hi.money <= lo.money or hi.money / hi.robux < lo.money / lo.robux then
		ascending = false
	end
end
check("bigger packs give more money per Robux", ascending)
check(
	"starter pack is once and its vehicle exists",
	Products.Starter.once and Vehicles.ById[Products.Starter.vehicle or ""] ~= nil
)

-- events: first at 90 s, 120 s long, then 360 s quiet, 20 s warning
local function ph(t: number, offset: number?)
	return EventRules.phase(t, 4, 90, 360, 120, 20, offset or 0)
end
check("quiet at the start", ph(0).phase == "quiet" and ph(0).index == 1)
check("warning before the first", ph(75).phase == "warn" and math.abs(ph(75).endsIn - 15) < 1e-9)
check("first event live", ph(90).phase == "live" and ph(90).index == 1 and ph(209).phase == "live")
check("quiet after it", ph(210).phase == "quiet" and ph(210).index == 2)
check(
	"second event warns then runs",
	ph(560).phase == "warn" and ph(570).phase == "live" and ph(570).index == 2
)
check("events cycle through the list", ph(90 + 4 * 480).index == 1 and ph(90 + 3 * 480).index == 4)
check("offset rotates the order", ph(90, 2).index == 3)
check("no events, always quiet", EventRules.phase(100, 0, 90, 360, 120, 20, 0).phase == "quiet")
local evKeys = {}
for _, e in EventConfig.List do
	evKeys[e.key] = true
end
check(
	"event list has the four events",
	evKeys.LowGravity and evKeys.GoldenRush and evKeys.Giant and evKeys.Stampede
)

-- city plan
local M = World.Map
local plan = CityPlan.plan(M.BlocksX, M.BlocksZ, M.Seed)
local kindsCount = CityPlan.count(plan)
local ci, cj = CityPlan.centre(M.BlocksX, M.BlocksZ)
check("spawn plaza in the middle, once", plan[ci][cj] == "spawn" and kindsCount.spawn == 1)
check(
	"one delivery warehouse on the west edge",
	kindsCount.warehouse == 1 and plan[0][cj] == "warehouse"
)
check(
	"two fast-food places, one next to spawn",
	kindsCount.restaurant == 2 and plan[ci][cj - 1] == "restaurant"
)
check("plenty of offices", (kindsCount.office or 0) >= 8)
check("lots of home blocks", (kindsCount.homes or 0) >= 12)
check(
	"parks, plazas, shops and parking remain",
	(kindsCount.park or 0) >= 2
		and (kindsCount.plaza or 0) >= 2
		and (kindsCount.shops or 0) >= 2
		and (kindsCount.parking or 0) >= 1
)
local samePlan = CityPlan.plan(M.BlocksX, M.BlocksZ, M.Seed)
local planStable = true
for i = 0, M.BlocksX - 1 do
	for j = 0, M.BlocksZ - 1 do
		if samePlan[i][j] ~= plan[i][j] then
			planStable = false
		end
	end
end
check("same seed, same city", planStable)
local rollsOk, rollBuckets = true, {}
for i = 0, 40 do
	local r = CityPlan.roll(M.Seed, i, i * 3)
	rollsOk = rollsOk and r >= 0 and r < 1
	rollBuckets[math.floor(r * 20)] = true
end
local distinctN = 0
for _ in rollBuckets do
	distinctN += 1
end
check("block rolls spread over [0, 1)", rollsOk and distinctN >= 12)

-- sidewalk routes
local pitch = M.BlockSize + M.RoadWidth
local grid = {
	blocksX = M.BlocksX,
	blocksZ = M.BlocksZ,
	block = M.BlockSize,
	road = M.RoadWidth,
	sidewalk = M.SidewalkWidth,
	x0 = -(M.BlocksX * pitch + M.RoadWidth) / 2,
	z0 = -(M.BlocksZ * pitch + M.RoadWidth) / 2,
}
local graph = Routes.new(grid)
local doors = {}
for i = 0, M.BlocksX - 1 do
	for j = 0, M.BlocksZ - 1 do
		local cx, cz = Routes.blockCentre(grid, i, j)
		table.insert(doors, Routes.addOnSide(graph, i, j, cx + 20, cz - 60))
		table.insert(doors, Routes.addOnSide(graph, i, j, cx - 70, cz + 10))
	end
end
Routes.finish(graph)
local inner = M.BlockSize / 2 - M.SidewalkWidth
local function insideBlock(x: number, z: number): boolean
	for i = 0, M.BlocksX - 1 do
		for j = 0, M.BlocksZ - 1 do
			local cx, cz = Routes.blockCentre(grid, i, j)
			if math.abs(x - cx) < inner - 0.01 and math.abs(z - cz) < inner - 0.01 then
				return true
			end
		end
	end
	return false
end
local linksOk = true
for from, list in graph.links do
	for _, to in list do
		local na, nb = graph.nodes[from], graph.nodes[to]
		for t = 0, 1, 0.25 do
			if insideBlock(na.x + (nb.x - na.x) * t, na.z + (nb.z - na.z) * t) then
				linksOk = false
			end
		end
		if na.x ~= nb.x and na.z ~= nb.z then
			linksOk = false -- every link runs straight along a sidewalk or across a road
		end
	end
end
check("no sidewalk link cuts through a block", linksOk)
local far = Routes.path(
	graph,
	Routes.corner(graph, 0, 0, -1, -1),
	Routes.corner(graph, M.BlocksX - 1, M.BlocksZ - 1, 1, 1)
)
local pathOk = far ~= nil
if far then
	for k = 2, #far do
		local linked = false
		for _, n in graph.links[far[k - 1]] do
			if n == far[k] then
				linked = true
			end
		end
		pathOk = pathOk and linked
	end
end
check("a path crosses the whole city along links", pathOk)
local reachAll = true
for _, d in doors do
	if not Routes.path(graph, doors[1], d) then
		reachAll = false
	end
end
check("every door is reachable", reachAll)
local scx, scz = Routes.blockCentre(grid, 2, 2)
local _, sx, sz = Routes.onSide(grid, 2, 2, scx + 1, scz)
check("a door near the middle snaps onto a sidewalk", math.abs(sx - scx) + math.abs(sz - scz) > 90)
check(
	"nearest node of a corner is that corner",
	Routes.nearest(graph, graph.nodes[5].x, graph.nodes[5].z) == 5
)
check("path to itself is one node", #(Routes.path(graph, 7, 7) :: { number }) == 1)

-- crowd
math.randomseed(42)
local places = {}
for _ = 1, 60 do
	table.insert(places, "home")
end
for _, k in
	{
		"office",
		"office",
		"office",
		"office",
		"restaurant",
		"restaurant",
		"warehouse",
		"spawn",
		"stunt",
		"shop",
		"park",
	}
do
	table.insert(places, k)
end
local people = CrowdRules.roster(places :: any, CrowdConfig, 12, math.random)
local perHome, staff, walkers, crowdN = {}, 0, 0, 0
for _, p in people do
	if p.role == "resident" then
		perHome[p.home :: number] = (perHome[p.home :: number] or 0) + 1
	elseif p.role == "food" or p.role == "warehouse" then
		staff += 1
	elseif p.role == "walker" then
		walkers += 1
	elseif p.role == "crowd" then
		crowdN += 1
	end
end
local homesOk = true
for k = 1, 60 do
	local n = perHome[k] or 0
	homesOk = homesOk and n >= CrowdConfig.ResidentsMin and n <= CrowdConfig.ResidentsMax
end
check("every home has 1 to 3 residents", homesOk)
check(
	"restaurant and warehouse staff",
	staff == 2 * CrowdConfig.RestaurantStaff + CrowdConfig.WarehouseStaff
)
check("walkers and the spawn crowd", walkers == CrowdConfig.Walkers and crowdN == 12)
local friendsN = CrowdRules.pickFriends(people, CrowdConfig.FriendEvery, math.random)
local friendsMarked, staffFriends = 0, 0
for _, p in people do
	if p.friend then
		friendsMarked += 1
		if not CrowdRules.canBeFriend(p) then
			staffFriends += 1
		end
	end
end
check(
	"one in six is a friend",
	friendsN == friendsMarked and friendsMarked == math.floor(#people / 6)
)
check("staff in uniform are never friends", staffFriends == 0)
check(
	"picking friends twice doesn't add more",
	CrowdRules.pickFriends(people, 6, math.random) == friendsMarked
)
check("no friends from a tiny crowd", CrowdRules.pickFriends({ people[1] }, 6, math.random) == 0)
check(
	"first of six shown: no friend yet, then one",
	not CrowdRules.wantFriend(0, 1, 6) and CrowdRules.wantFriend(0, 5, 6)
)
check(
	"one friend in six shown is enough",
	not CrowdRules.wantFriend(1, 6, 6) and CrowdRules.wantFriend(1, 11, 6)
)
local sim, simFriends = 0, 0
for _ = 1, 90 do
	if CrowdRules.wantFriend(simFriends, sim, 6) then
		simFriends += 1
	end
	sim += 1
end
check("building 90 people one by one gives 15 friends", simFriends == 15)
local cands = {}
for k = 1, 200 do
	table.insert(cands, { dist = k * 3, indoor = k % 5 == 0, active = k % 7 == 0 })
end
local act = CrowdRules.pickActive(cands, CrowdConfig)
local actN, actOk = 0, true
for k in act do
	actN += 1
	local c = cands[k]
	local r = if c.indoor
		then (if c.active then CrowdConfig.IndoorLeave else CrowdConfig.IndoorRadius)
		else (if c.active then CrowdConfig.DeactivateRadius else CrowdConfig.ActivateRadius)
	actOk = actOk and c.dist <= r
end
check("active people stay under the cap and in range", actN <= CrowdConfig.MaxActive and actOk)
local edge = CrowdRules.pickActive({
	{ dist = CrowdConfig.ActivateRadius + 10, indoor = false, active = true },
	{ dist = CrowdConfig.ActivateRadius + 10, indoor = false, active = false },
}, CrowdConfig)
check(
	"someone built stays a bit past the edge, a newcomer there doesn't appear",
	edge[1] == true and edge[2] == nil
)
local few = CrowdRules.pickActive(
	{ { dist = 10, indoor = false, active = false }, { dist = 5, indoor = true, active = false } },
	{
		MaxActive = 1,
		ActivateRadius = 100,
		DeactivateRadius = 120,
		IndoorRadius = 50,
		IndoorLeave = 60,
	}
)
check("the cap keeps the nearest", few[2] == true and few[1] == nil)
local goalsOk = true
for _ = 1, 200 do
	goalsOk = goalsOk
		and CrowdRules.nextGoal("food", true, math.random, CrowdConfig) == "spot"
		and CrowdRules.nextGoal("warehouse", false, math.random, CrowdConfig) == "spot"
		and CrowdRules.nextGoal("resident", false, math.random, CrowdConfig) == "home"
		and CrowdRules.nextGoal("office", false, math.random, CrowdConfig) == "work"
		and CrowdRules.nextGoal("crowd", false, math.random, CrowdConfig) == "crowd"
		and CrowdRules.nextGoal("resident", true, math.random, CrowdConfig) ~= "home"
		and CrowdRules.nextGoal("walker", false, math.random, CrowdConfig) ~= "stay"
end
check("staff stay at work, people out go home or back to work", goalsOk)
local stays = 0
for _ = 1, 1000 do
	if CrowdRules.nextGoal("resident", true, math.random, CrowdConfig) == "stay" then
		stays += 1
	end
end
check(
	"residents at home stay in about HomeStayChance of the time",
	math.abs(stays / 1000 - CrowdConfig.HomeStayChance) < 0.06
)
local function rgbOk(list: { { number } }): boolean
	for _, c in list do
		if #c ~= 3 then
			return false
		end
		for _, v in c do
			if v < 0 or v > 255 then
				return false
			end
		end
	end
	return true
end
check(
	"outfit colours are RGB",
	rgbOk(CrowdConfig.Skin)
		and rgbOk(CrowdConfig.Casual.Shirts)
		and rgbOk(CrowdConfig.Casual.Pants)
		and rgbOk(CrowdConfig.Office.Shirts)
		and rgbOk({ CrowdConfig.Food.Shirt, CrowdConfig.Food.Cap, CrowdConfig.Warehouse.Vest })
)
check(
	"walkers reappear out of view but inside the build radius",
	CrowdConfig.RecallMin < CrowdConfig.RecallMax
		and CrowdConfig.RecallMax < CrowdConfig.ActivateRadius
		and CrowdConfig.RecallDistance > CrowdConfig.DeactivateRadius
)
check(
	"activate inside deactivate radius",
	CrowdConfig.ActivateRadius < CrowdConfig.DeactivateRadius
		and CrowdConfig.IndoorRadius < CrowdConfig.IndoorLeave
)
local namesOk = #CrowdConfig.OfficeNames >= 4
local signNames = { CrowdConfig.RestaurantName, CrowdConfig.WarehouseName }
for _, n in CrowdConfig.OfficeNames do
	table.insert(signNames, n)
end
for _, n in signNames do
	local low = string.lower(n)
	if string.find(low, "amazon") or string.find(low, "mcdonald") or string.find(low, "^mc") then
		namesOk = false
	end
end
check("sign names are parodies, not real brands", namesOk)

-- districts and the street kit
local districtCount = {}
for i = 0, 7 do
	for j = 0, 7 do
		local d = Districts.of(i, j, 8, 8)
		districtCount[d] = (districtCount[d] or 0) + 1
	end
end
check(
	"canal quarter is the east two columns",
	districtCount.canal == 16 and Districts.of(7, 0, 8, 8) == "canal"
)
check(
	"old town is the north-west corner",
	Districts.of(0, 0, 8, 8) == "old" and districtCount.old == 9
)
check(
	"stadium row, dockside and maple hills exist",
	districtCount.stadium == 6 and districtCount.dock == 3 and (districtCount.maple or 0) >= 12
)
check(
	"downtown is the middle",
	Districts.of(4, 4, 8, 8) == "neon" and (districtCount.neon or 0) >= 10
)
local MATERIALS = {
	SmoothPlastic = true,
	Brick = true,
	Cobblestone = true,
	WoodPlanks = true,
	CorrodedMetal = true,
	Concrete = true,
	Wood = true,
	Metal = true,
	Slate = true,
}
local stylesOk = true
for key, d in Streets.Districts do
	stylesOk = stylesOk
		and MATERIALS[d.wallMaterial] == true
		and MATERIALS[d.sidewalkMaterial] == true
		and rgbOk(d.walls)
		and rgbOk({ d.sidewalk, d.accent })
		and d.trees >= 0
		and d.trees <= 1
		and districtCount[key] ~= nil
end
check("every district has a valid look and appears on the map", stylesOk)
local pitchS = World.Map.BlockSize
check(
	"crossings sit inside the block span, stop lines behind them",
	Streets.ZebraInset + Streets.ZebraLength / 2 < Streets.StopLineInset
		and Streets.StopLineInset < Streets.EndClear + 4
		and Streets.EndClear * 2 < pitchS
)
check(
	"lane dashes fit",
	Streets.DashLength > 0 and Streets.DashGap > 0 and Streets.ZebraStripes >= 3
)
check("billboards are parodies", #Streets.Billboards >= 4)
check("signals cycle", Streets.SignalSeconds > Streets.AmberSeconds and Streets.AmberSeconds > 0)

if failures > 0 then
	error(`{failures} test(s) failed`)
end
