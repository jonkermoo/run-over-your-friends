--!strict
-- Run with: lune run tests/run
local BuildingConfig = require("../src/shared/Config/Buildings")
local BuildingRules = require("../src/shared/Rules/Buildings")
local CityPlan = require("../src/shared/Rules/CityPlan")
local CrowdConfig = require("../src/shared/Config/Crowd")
local CrowdRules = require("../src/shared/Rules/Crowd")
local Districts = require("../src/shared/Rules/Districts")
local HouseConfig = require("../src/shared/Config/Houses")
local HouseRules = require("../src/shared/Rules/Houses")
local InteriorConfig = require("../src/shared/Config/Interiors")
local InteriorRules = require("../src/shared/Rules/Interiors")
local Streets = require("../src/shared/Config/Streets")
local Economy = require("../src/shared/Config/Economy")
local Game = require("../src/shared/Config/Game")
local Flight = require("../src/shared/Rules/Flight")
local FlightConfig = require("../src/shared/Config/Flight")
local Impact = require("../src/shared/Rules/Impact")
local EventConfig = require("../src/shared/Config/Events")
local EventRules = require("../src/shared/Rules/Events")
local Products = require("../src/shared/Config/Products")
local LbConfig = require("../src/shared/Config/Leaderboards")
local Lb = require("../src/shared/Rules/Leaderboards")
local QuestConfig = require("../src/shared/Config/Quests")
local OutskirtsConfig = require("../src/shared/Config/Outskirts")
local OutskirtsRules = require("../src/shared/Rules/Outskirts")
local Routes = require("../src/shared/Rules/Routes")
local Smash = require("../src/shared/Config/Smash")
local Tiles = require("../src/shared/Rules/Tiles")
local Tracks = require("../src/shared/Rules/Tracks")
local CockpitConfig = require("../src/shared/Config/Cockpit")
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
	"only Roadster has the jet",
	Vehicles.has(Vehicles.ById.Roadster, "Jet") and not Vehicles.has(Vehicles.ById.Supercar, "Jet")
)
check(
	"thruster on Roadster and supercar",
	Vehicles.has(Vehicles.ById.Supercar, "Thruster")
		and Vehicles.has(Vehicles.ById.Roadster, "Thruster")
)

-- cabins, first person and crawler tracks
check(
	"only the bulldozer runs on tracks, and its driver shows",
	Vehicles.ById.Bulldozer.tracks ~= nil
		and Vehicles.ById.Bulldozer.showDriver
		and Vehicles.ById.Hatchback.tracks == nil
)
do
	local okAll = true
	for _, v in Vehicles.List do
		okAll = okAll
			and v.showDriver
			and #v.seat == 3
			and (v.steerRatio == nil or v.steerRatio > 0)
	end
	check("every vehicle has a seat to sit in", okAll)
end
check(
	"first-person numbers are sane",
	CockpitConfig.fov > 40
		and CockpitConfig.fov < 100
		and CockpitConfig.shake > 0
		and CockpitConfig.shake <= 1
		and CockpitConfig.fovPunch <= 1
		and CockpitConfig.glass < 1
		and #CockpitConfig.keys >= 1
		and CockpitConfig.needleSweep > 0
)
do
	local loop: Tracks.Loop = { y = 2, front = -8, back = 10, radius = 2.2 }
	local len = Tracks.length(loop)
	check("track loop length", math.abs(len - (36 + 2 * math.pi * 2.2)) < 1e-6)
	local count = Tracks.count(loop, 1.1)
	check("track plates about 1.1 apart", math.abs(len / count - 1.1) < 0.05)
	-- the loop is closed and smooth: neighbouring points stay close all the way round
	local gaps = 0
	local py, pz = Tracks.at(loop, 0)
	for i = 1, 400 do
		local y, z = Tracks.at(loop, i * len / 400)
		local d = math.sqrt((y - py) ^ 2 + (z - pz) ^ 2)
		if d > len / 400 * 1.01 then
			gaps += 1
		end
		py, pz = y, z
	end
	check("track loop has no jumps", gaps == 0)
	local y0, z0, a0 = Tracks.at(loop, 0)
	check("plates start on the ground run under the idler", y0 == 2 - 2.2 and z0 == -8 and a0 == 0)
	local yt, _, at = Tracks.at(loop, len / 2)
	check(
		"halfway round is the top run, upside down",
		math.abs(yt - 4.2) < 1e-6 and math.abs(at + math.pi) < 1e-6
	)
	local l, r = Tracks.speeds(10, 0.5, 4)
	check("turning left runs the right track faster", r > l and math.abs((l + r) / 2 - 10) < 1e-9)
	local pl, pr = Tracks.speeds(0, 1, 4)
	check("on the spot the tracks run opposite ways", pl == -pr and pl < 0)
end

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
do
	-- building smashing: every vehicle breaks pieces once it's fast enough; light ones break little
	local function smashAt(id: string, mph: number): number
		local v = Vehicles.ById[id]
		return Impact.smashRadius(v.weight, mph / 2.237, Smash, v.maxBreak)
	end
	local function smashTop(id: string): number
		return smashAt(id, Vehicles.ById[id].topSpeed)
	end
	check("parking the Bulldozer against a wall breaks nothing", smashAt("Bulldozer", 3) == 0)
	check("Roadster at full speed breaks a lot", smashTop("Roadster") > 20)
	check("radius stays in range", Impact.breakRadius(1e12, Smash) == Smash.MaxRadius)
	check(
		"just over the line chips a little",
		Impact.breakRadius(Smash.EnergyLow, Smash) == Smash.MinRadius
	)
	for _, v in Vehicles.List do
		check(v.id .. " breaks something at top speed", smashTop(v.id) > 0)
	end
	check("Cart at 20 mph only bumps", smashAt("Cart", 20) == 0)
	check("Cart at top speed breaks little", smashTop("Cart") <= 5)
	check("Scooter at top speed breaks little", smashTop("Scooter") <= 6)
	for _, id in { "Hatchback", "Scooter", "Cart", "Sedan", "Taxi" } do
		check(
			id .. " at top speed knocks out one wall piece",
			smashTop(id) > 0 and smashTop(id) <= Smash.MinRadius
		)
	end
	check("Muscle breaks more than the Sedan", smashTop("Muscle") > smashTop("Sedan") + 5)
	check("Semi breaks more than the Sedan", smashTop("Semi") > smashTop("Sedan") + 5)
	check("Semi breaks at 15 mph", smashAt("Semi", 15) > Smash.MinRadius)
	check(
		"Cart and Scooter never drop the floors above",
		math.max(smashTop("Cart"), smashTop("Scooter")) < Smash.FloorsFallFrom
	)
	check("Semi at 30 mph drops the floors above", smashAt("Semi", 30) >= Smash.FloorsFallFrom)
	check("faster breaks more", smashAt("Semi", 80) > smashAt("Semi", 30))
	-- walls push back: early cars lose most of their speed, big fast ones plough on
	local function keptAtTop(id: string): number
		local v = Vehicles.ById[id]
		return Impact.wallSpeedKept(v.weight, v.topSpeed / 2.237, Smash)
	end
	for _, id in { "Cart", "Scooter", "Hatchback", "Sedan", "Taxi" } do
		check(id .. " loses most of its speed in a wall", keptAtTop(id) <= 0.35)
	end
	check("the Semi ploughs on at top speed", keptAtTop("Semi") > 0.8)
	check("a car always keeps some speed", keptAtTop("Cart") == Smash.KeptLight)
	for _, id in { "Semi", "Bulldozer" } do
		local v = Vehicles.ById[id]
		check(
			id .. " keeps over 80% per piece even when slow",
			Impact.wallSpeedKept(v.weight, 7, Smash) > 0.8
		)
	end
	check(
		"the heaviest keeps KeptHeavy",
		near(Impact.wallSpeedKept(1e6, 1, Smash), Smash.KeptHeavy, 1e-9)
	)
	check(
		"heavier keeps more when slow",
		Impact.wallSpeedKept(9000, 10, Smash) > Impact.wallSpeedKept(3500, 10, Smash)
	)
	check(
		"faster keeps more",
		Impact.wallSpeedKept(15000, 35, Smash) > Impact.wallSpeedKept(15000, 18, Smash)
	)
	check(
		"heavier keeps more",
		Impact.wallSpeedKept(9000, 30, Smash) > Impact.wallSpeedKept(1700, 30, Smash)
	)
	check("standing still keeps everything", Impact.wallSpeedKept(1500, 0, Smash) == 1)
end
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
check("building goals are offered to everyone", breaksOffered)
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
check("starter ad waits at least a minute of play", Products.StarterOfferAfter >= 60)

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

-- flight
local function fly(s: Flight.State, throttle: number, jet: boolean, seconds: number): Flight.State
	for _ = 1, math.floor(seconds * 60) do
		s = Flight.step(s, throttle, jet, 1 / 60, FlightConfig)
	end
	return s
end
local still = { forward = 0, side = 0, up = 0, fuel = 100 }
local climbed = fly(still, 0, true, 2)
check("the jet climbs at the climb rate", near(climbed.up, FlightConfig.climb, 1e-6))
check("the jet burns fuel", near(climbed.fuel, 100 - FlightConfig.drain * 2, 0.5))
check("a full tank lasts 4 s", fly(still, 0, true, 4.1).fuel == 0)
check(
	"letting go drops it like a stone",
	near(fly(climbed, 0, false, 1).up, FlightConfig.climb - FlightConfig.gravity, 0.2)
)
check("no fuel, no climb", fly({ forward = 0, side = 0, up = 0, fuel = 0 }, 0, true, 1).up < -9)
check(
	"jet off keeps its momentum",
	fly({ forward = 30, side = 5, up = 0, fuel = 50 }, 1, false, 1).forward == 30
)
check("W flies at top speed", near(fly(still, 1, true, 3.5).forward, FlightConfig.top, 1e-6))
check("S backs up", near(fly(still, -1, true, 2).forward, -FlightConfig.reverseTop, 1e-6))
local boosted =
	Flight.step({ forward = 80, side = 0, up = 0, fuel = 100 }, 1, true, 1, FlightConfig)
check("over top speed slows by drag", near(boosted.forward, 80 - FlightConfig.drag, 1e-6))
check(
	"no throttle drifts to a stop",
	fly({ forward = 15, side = 0, up = 0, fuel = 100 }, 0, true, 3.5).forward == 0
)
check(
	"sideways drift dies out",
	fly({ forward = 0, side = 9, up = 0, fuel = 100 }, 0, true, 1).side == 0
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
	Limestone = true,
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
check(
	"the plaza fountain fits inside its ring of benches",
	Streets.PlazaFountain.size / 2 + 4 < (World.Map.BlockSize - World.Map.SidewalkWidth * 2) * 0.22
)
check("signals cycle", Streets.SignalSeconds > Streets.AmberSeconds and Streets.AmberSeconds > 0)

-- house kit
check(
	"type picks follow the weight bands",
	HouseRules.pickType({ A = 0.5, B = 0.5 }, 0.1) == "A"
		and HouseRules.pickType({ A = 0.5, B = 0.5 }, 0.9) == "B"
)
check(
	"a single-type district always builds it",
	HouseRules.pickType(HouseConfig.ByDistrict.old, 0.99) == "D"
)
local palOk = true
math.randomseed(7)
local prev = nil
for _ = 1, 500 do
	local k = HouseRules.pickPalette(#HouseConfig.Palettes, prev, math.random())
	palOk = palOk and k >= 1 and k <= #HouseConfig.Palettes and k ~= prev
	prev = k
end
check("neighbours never share a palette", palOk)
check(
	"one palette, no choice",
	HouseRules.pickPalette(1, 1, 0.5) == 1 and HouseRules.pickPalette(3, 9, 0.99) <= 3
)
local lotWidth = (World.Map.BlockSize - 2 * World.Map.SidewalkWidth) / HouseConfig.PerSide
local houseOk = true
for key, t in HouseConfig.Types do
	houseOk = houseOk and t.width * t.perLot <= lotWidth - 2 and t.floors >= 1 and t.perLot >= 1
	houseOk = houseOk
		and (World.Map.BlockSize - 2 * World.Map.SidewalkWidth) / 2
				- HouseConfig.Yard
				- t.depth
			> 20
	for _, w in HouseConfig.ByDistrict do
		if w[key] then
			houseOk = houseOk and w[key] > 0
		end
	end
end
check("every house type fits its lot with a garden behind", houseOk)
local distOk = true
for _, w in HouseConfig.ByDistrict do
	for key in w do
		distOk = distOk and HouseConfig.Types[key] ~= nil
	end
end
for key in Streets.Districts do
	distOk = distOk and HouseConfig.ByDistrict[key] ~= nil
end
check("every district builds known house types", distOk)
local palsOk = #HouseConfig.Palettes >= 4
for _, pal in HouseConfig.Palettes do
	palsOk = palsOk
		and rgbOk({ pal.wall, pal.trim, pal.accent, pal.roof })
		and MATERIALS[pal.material] == true
end
check("house palettes are valid", palsOk)

-- house interiors
local interiorOk, sitOnSeat, spotsInside = true, true, true
for kind, t in HouseConfig.Types do
	local layout = InteriorConfig.Layouts[kind]
	interiorOk = interiorOk and layout ~= nil and #layout.spots >= 3
	if layout then
		local xLo, xHi = -t.width / 2 + 1.5, t.width / 2 - 1.5
		if kind == "C" then
			xHi = -t.width / 2 + 22 - 1.5 -- the two-storey block; the garage is on the right
		end
		local zLim = t.depth / 2 - 1.5
		for _, piece in layout.pieces do
			spotsInside = spotsInside
				and piece.x >= xLo
				and piece.x <= xHi
				and math.abs(piece.z) <= zLim
		end
		for _, sp in layout.spots do
			spotsInside = spotsInside and sp.x >= xLo and sp.x <= xHi and math.abs(sp.z) <= zLim
			if sp.sit then
				local seat = false
				for _, piece in layout.pieces do
					if
						(piece.kind == "Sofa" or piece.kind == "Chair")
						and math.abs(piece.x - sp.x) < 0.01
						and math.abs(piece.z - sp.z) < 0.01
					then
						seat = seat or (piece.fx == sp.fx and piece.fz == sp.fz)
					end
				end
				sitOnSeat = sitOnSeat and seat
			end
		end
	end
end
check("every house type has a furnished ground floor with spots", interiorOk)
check("furniture and spots sit inside the house", spotsInside)
check("people only sit on a sofa or chair, facing its way", sitOnSeat)
check(
	"interior settings sane",
	InteriorConfig.Radius > 0
		and InteriorConfig.MaxFurnished > 0
		and InteriorConfig.SitHeight > 1
		and InteriorConfig.SitHeight < 3.5
)

-- long map parts are tiled under Roblox's 2048-stud cap
local function tilesCover(lenX: number, lenZ: number): boolean
	local list = Tiles.split(lenX, lenZ, 2048)
	local area, ok = 0, true
	for _, t in list do
		area += t.sx * t.sz
		ok = ok and t.sx <= 2048 and t.sz <= 2048
		ok = ok
			and math.abs(t.x) + t.sx / 2 <= lenX / 2 + 1e-6
			and math.abs(t.z) + t.sz / 2 <= lenZ / 2 + 1e-6
	end
	return ok and math.abs(area - lenX * lenZ) < 1e-3
end
check(
	"the 6000-stud ground becomes 9 tiles that cover it",
	#Tiles.split(6000, 6000, 2048) == 9 and tilesCover(6000, 6000)
)
check("a long road becomes 2 tiles", #Tiles.split(64, 2336, 2048) == 2 and tilesCover(64, 2336))
check(
	"a short part stays one piece",
	#Tiles.split(220, 220, 2048) == 1 and Tiles.split(220, 220, 2048)[1].x == 0
)
check("exactly 2048 stays one piece", #Tiles.split(2048, 10, 2048) == 1)

-- town buildings (offices, shops, the burger place, the warehouse)
local function piecesOk(length: number, maxPiece: number): boolean
	local list = BuildingRules.pieces(length, maxPiece)
	local ok = #list >= 1 and math.abs(list[1].from + length / 2) < 1e-6
	for k, sp in list do
		ok = ok and sp.to - sp.from <= maxPiece + 1e-6 and sp.to > sp.from
		if k > 1 then
			ok = ok and math.abs(sp.from - list[k - 1].to) < 1e-6
		end
	end
	return ok and math.abs(list[#list].to - length / 2) < 1e-6
end
check(
	"trim bands are cut into pieces that cover them, none too long",
	piecesOk(130, 48) and piecesOk(48, 48) and piecesOk(10, 48) and piecesOk(168.4, 48)
)
check("a band no longer than a piece stays whole", #BuildingRules.pieces(48, 48) == 1)
local pil = BuildingRules.pilasters(8, 2)
check("pilasters every 2 panels, never on a corner", #pil == 3 and pil[1] == 2 and pil[3] == 6)
check("a narrow face gets no inner pilaster", #BuildingRules.pilasters(2, 2) == 0)
local secOk = true
for floors = 1, 9 do
	local secs = BuildingRules.sections(floors, BuildingConfig.Office.CorniceEvery)
	secOk = secOk and secs[1].from == 0 and secs[1].to == 1 and secs[#secs].to == floors
	for k = 2, #secs do
		secOk = secOk
			and secs[k].from == secs[k - 1].to
			and secs[k].to - secs[k].from <= BuildingConfig.Office.CorniceEvery
	end
end
check("office storeys split into a lobby and sections of at most 3 floors", secOk)
local blockInner = World.Map.BlockSize - 2 * World.Map.SidewalkWidth
local SH = BuildingConfig.Shops
local fw = blockInner / SH.PerBlock
local segs, doorX = BuildingRules.shopFront(fw, SH.Door)
local frontOk = math.abs(segs[1].a + fw / 2) < 1e-6 and math.abs(segs[#segs].b - fw / 2) < 1e-6
local doorW, winW = 0, 0
for k, sg in segs do
	frontOk = frontOk and sg.b > sg.a
	if k > 1 then
		frontOk = frontOk and math.abs(sg.a - segs[k - 1].b) < 1e-6
	end
	if sg.k == "d" then
		doorW = sg.b - sg.a
		frontOk = frontOk and math.abs((sg.a + sg.b) / 2 - doorX) < 1e-6
	elseif sg.k == "sw" then
		winW = sg.b - sg.a
	end
end
check(
	"a shop front covers its width with one door and a big window",
	frontOk and doorW == SH.Door and winW >= 20
)
check(
	"the shop row, its forecourt and a car park fit the block",
	SH.Setback + SH.Depth + 20 < inner
		and fw >= 40
		and SH.Floors[1] >= 2
		and SH.Floors[2] >= SH.Floors[1]
)
local shopNamesOk = #SH.Names >= SH.PerBlock
for _, n in SH.Names do
	shopNamesOk = shopNamesOk and #n > 0 and #n <= 14
end
check("shop names fit their hanging signs", shopNamesOk)
local looksOk = true
for key in Streets.Districts do
	local look = BuildingConfig.Office.Looks[key]
	looksOk = looksOk and look ~= nil and rgbOk({ look.trim, look.stone, look.roof })
	if look then
		-- a trim colour equal to a wall colour would pick up the district's wall material
		for _, c in Streets.Districts[key].walls do
			looksOk = looksOk
				and not (c[1] == look.trim[1] and c[2] == look.trim[2] and c[3] == look.trim[3])
		end
	end
end
check("every district has office trim, lobby stone and roof colours", looksOk)
local landmarkOk = true
for _, colours in { BuildingConfig.Restaurant.Colours, BuildingConfig.Warehouse.Colours } do
	landmarkOk = landmarkOk
		and rgbOk({ colours.wall, colours.trim, colours.accent, colours.roof })
		and MATERIALS[colours.material] == true
end
check(
	"landmark colours and materials are valid",
	landmarkOk
		and rgbOk({ BuildingConfig.Office.Glass, SH.AwningWhite })
		and MATERIALS[BuildingConfig.Office.StoneMaterial] == true
)
local R = BuildingConfig.Restaurant
check(
	"the barn roof has a knee below its ridge",
	R.KneeShare > 0 and R.KneeShare < 1 and R.KneeRise > 0 and R.PeakRise > R.KneeRise
)
local WB = BuildingConfig.Warehouse
local panels = CrowdConfig.WarehouseSize[1] // WB.Panel
local wareOk = true
for _, k in WB.Pilasters do
	-- never beside a bay (5, 8, 11) or the door (2)
	wareOk = wareOk
		and k > 0
		and k < panels
		and k ~= 4
		and k ~= 5
		and k ~= 7
		and k ~= 8
		and k ~= 10
		and k ~= 11
end
for _, k in WB.Windows do
	wareOk = wareOk and k >= 1 and k <= panels
end
check("warehouse pilasters and windows sit on real panels clear of the bays", wareOk)
check("a part budget is set", BuildingConfig.PartBudget > 30000 and BuildingConfig.BandPiece >= 12)

-- town interiors: furniture and people inside each building, seats under every sitting spot
local layoutCfg = InteriorRules.config(World, BuildingConfig, HouseConfig, InteriorConfig)
local function layoutInside(
	l: InteriorRules.Layout,
	hw: number,
	hd: number,
	ceiling: number
): boolean
	local ok = true
	local function inBox(x: number, y: number, z: number)
		ok = ok and math.abs(x) <= hw and math.abs(z) <= hd and y >= 0 and y <= ceiling
	end
	for _, p in l.pieces do
		inBox(p.x, p.y, p.z)
	end
	for _, list in { l.spots, l.staff } do
		for _, sp in list do
			inBox(sp.x, sp.y, sp.z)
			for _, q in sp.via do
				inBox(q.x, q.y, q.z)
			end
		end
	end
	return ok
end
local function seated(l: InteriorRules.Layout): boolean
	local ok = true
	for _, list in { l.spots, l.staff } do
		for _, sp in list do
			if sp.sit then
				local seat = false
				for _, p in l.pieces do
					seat = seat
						or (
							InteriorRules.Seats[p.kind] == true
							and math.abs(p.x - sp.x) < 0.01
							and math.abs(p.z - sp.z) < 0.01
							and math.abs(p.y - sp.y) < 0.01
							and p.fx == sp.fx
							and p.fz == sp.fz
						)
				end
				ok = ok and seat
			end
		end
	end
	return ok
end
-- every change of floor along a way in is a lift ride: two points in a row at the same x, z
local function liftsOk(l: InteriorRules.Layout): boolean
	local ok = true
	for _, sp in l.spots do
		local path = table.clone(sp.via)
		table.insert(path, { x = sp.x, y = sp.y, z = sp.z })
		local prevY = 0
		for k, q in path do
			if math.abs(q.y - prevY) > 0.01 then
				local before = path[k - 1]
				ok = ok
					and before ~= nil
					and math.abs(before.x - q.x) < 0.01
					and math.abs(before.z - q.z) < 0.01
			end
			prevY = q.y
		end
	end
	return ok
end
local officeIn, officeSeats, officeLifts, desksUp, staffAtDesk = true, true, true, true, true
local FH = World.Map.FloorHeight
for _, size in { { 106, 106 }, { 154, 120 }, { 120, 154 } } do
	for _, floors in { 3, 5, 9 } do
		for _, officeDoor in { -8, 0, 8 } do
			local l = InteriorRules.office(size[1], size[2], floors, officeDoor, layoutCfg)
			-- office walls stand on the footprint's edges, half in, half out
			local wallIn = World.Map.WallThickness / 2
			officeIn = officeIn
				and layoutInside(l, size[1] / 2 - wallIn, size[2] / 2 - wallIn, floors * FH)
			officeSeats = officeSeats and seated(l)
			officeLifts = officeLifts and liftsOk(l)
			-- every floor above the lobby has people sitting at it
			local seatedOn = {}
			for _, sp in l.spots do
				if sp.sit then
					seatedOn[math.floor(sp.y / FH + 0.5)] = true
				end
			end
			for f = 1, floors - 1 do
				desksUp = desksUp and seatedOn[f] == true
			end
			staffAtDesk = staffAtDesk and #l.staff >= 1 and l.hub ~= nil and #l.staffIn >= 1
		end
	end
end
check("office furniture and people stay inside the tower", officeIn)
check("office sitters sit on a chair or a sofa", officeSeats)
check("office workers change floors only in the lift", officeLifts)
check("people sit at desks on every floor above the lobby", desksUp)
check("each office lobby has a receptionist's desk", staffAtDesk)
-- every office floor is furnished by its plan, and the walks from the lift stay clear
local function checkOfficeFloors()
	local plans = layoutCfg.Plans
	local planOk = #plans >= 1 and InteriorRules.plan(1, plans) == plans[1]
	for f = 1, 9 do
		planOk = planOk and InteriorRules.plan(f, plans) == plans[(f - 1) % #plans + 1]
	end
	local furnished, walksClear = true, true
	local blocking = {
		Desk = true,
		Chair = true,
		CafeTable = true,
		Screen = true,
		Divider = true,
		Counter = true,
		Fridge = true,
		WaterCooler = true,
		Reception = true,
		Plant = true,
		DiningTable = true,
	}
	for _, size in { { 106, 106 }, { 154, 120 }, { 120, 154 } } do
		for _, officeDoor in { -8, 0, 8 } do
			local floors = 9
			local l = InteriorRules.office(size[1], size[2], floors, officeDoor, layoutCfg)
			local hd = size[2] / 2
			local floorKinds: { [number]: { [string]: number } } = {}
			for _, pc in l.pieces do
				local f = math.floor(pc.y / FH + 0.01)
				floorKinds[f] = floorKinds[f] or {}
				floorKinds[f][pc.kind] = (floorKinds[f][pc.kind] or 0) + 1
				if f >= 1 and blocking[pc.kind] then
					-- straight out of the lift to the front aisle, and down the corridor beside the core
					local front = math.abs(pc.x - (officeDoor - 4)) < 2.5
						and pc.z > 1
						and pc.z < hd - 11
					local back = math.abs(pc.x - (officeDoor - 16)) < 2.5
						and pc.z < 1
						and pc.z > -hd + 11
					walksClear = walksClear and not front and not back
				end
			end
			for f = 1, floors - 1 do
				local k = floorKinds[f] or {}
				local floorPlan = InteriorRules.plan(f, plans)
				furnished = furnished
					and (k.Desk or 0) >= 4
					and (k.Reception or 0) == 1
					and (k.Plant or 0) >= 3
					and (k.DiningTable or 0) == 1
					and (floorPlan ~= "Cubicles" or (k.Screen or 0) >= 2)
					and (floorPlan ~= "Break" or ((k.Fridge or 0) == 1 and (k.CafeTable or 0) >= 2))
			end
		end
	end
	check("office floor plans take turns up the tower", planOk)
	check("every office floor has desks, a lift desk, plants and its plan's furniture", furnished)
	check("office walks from the lift stay clear of furniture", walksClear)
end
checkOfficeFloors()

local SHC = BuildingConfig.Shops
local themesOk, islandKinds = true, {}
for _, k in SHC.IslandKinds do
	islandKinds[k] = true
end
for _, name in SHC.Names do
	local t = SHC.Themes[name]
	themesOk = themesOk and t ~= nil and islandKinds[t.island] == true and #t.goods >= 3
end
check("every shop has a theme with a known island and goods", themesOk)
local shopW = blockInner / SHC.PerBlock
local _, shopDoor = BuildingRules.shopFront(shopW, SHC.Door)
local shopL = InteriorRules.shop(shopW, SHC.Depth, SHC.GroundHeight, shopDoor, "Table")
check(
	"shop furniture and people stay inside the shop floor",
	layoutInside(shopL, shopW / 2 - 0.5, SHC.Depth / 2 - 0.5, SHC.GroundHeight)
)
check(
	"a shopkeeper's counter and shoppers' spots",
	#shopL.staff >= 1 and #shopL.spots >= 4 and shopL.hub ~= nil and seated(shopL)
)

local RS = CrowdConfig.RestaurantSize
local restL = InteriorRules.restaurant(RS[1], RS[2], layoutCfg)
local restSit = 0
for _, sp in restL.spots do
	restSit += if sp.sit then 1 else 0
end
check(
	"burger place: a chair either side of every table",
	restSit == 2 * #BuildingConfig.Restaurant.Tables
)
check(
	"burger place chairs sit on chairs inside",
	seated(restL)
		and layoutInside(restL, RS[1] / 2 - 1.5, RS[2] / 2 - 1.5, BuildingConfig.Restaurant.Height)
)
local WS = CrowdConfig.WarehouseSize
local wareL = InteriorRules.warehouse(WS[1], WS[2], CrowdConfig.WarehouseHeight, -66, 18)
check(
	"warehouse packing tables and desk have staff spots",
	#wareL.staff >= 3
		and seated(wareL)
		and layoutInside(wareL, WS[1] / 2 - 2, WS[2] / 2 - 2, CrowdConfig.WarehouseHeight)
)
check("layouts come from a model's attributes", InteriorRules.of({
	Interior = "Shop",
	W = shopW,
	D = SHC.Depth,
	H = SHC.GroundHeight,
	DoorX = shopDoor,
	Island = "Case",
}, layoutCfg) ~= nil and InteriorRules.of({ Interior = "Nothing" }, layoutCfg) == nil)

-- staff of the shops and offices
local staffPlaces = { "shop", "shop", "office", "home" }
local staffRoster = CrowdRules.roster(staffPlaces :: any, CrowdConfig, 0, math.random)
local keepers, receptionists = 0, 0
for _, p in staffRoster do
	keepers += if p.role == "shopkeeper" and p.outfit == "shop" then 1 else 0
	receptionists += if p.role == "reception" and p.home == 3 then 1 else 0
end
check(
	"every shop has its shopkeeper and every office a receptionist",
	keepers == 2 * CrowdConfig.ShopStaff and receptionists == CrowdConfig.Receptionists
)
check(
	"shopkeepers and receptionists keep to their workplace",
	CrowdRules.nextGoal("shopkeeper", true, math.random, CrowdConfig) == "spot"
		and CrowdRules.nextGoal("reception", false, math.random, CrowdConfig) == "spot"
		and CrowdRules.isStaff("shopkeeper")
		and not CrowdRules.isStaff("office")
)
check(
	"a shopkeeper in an apron is never a friend",
	not CrowdRules.canBeFriend({ role = "shopkeeper", outfit = "shop", friend = false })
)
check(
	"office and shop visitors usually show",
	CrowdConfig.OfficeSpotChance > 0.5
		and CrowdConfig.ShopSpotChance > 0.5
		and #CrowdConfig.Shop.Aprons >= 2
)

-- outskirts: zones round the ring, terrain hills that never touch a road or zone
do
	local MW = World.Map
	local mpitch = MW.BlockSize + MW.RoadWidth
	local span = math.max(MW.BlocksX, MW.BlocksZ) * mpitch + MW.RoadWidth
	local ringOuter = span / 2 + OutskirtsConfig.Ring.Gap + OutskirtsConfig.Ring.Width / 2
	local half = MW.GroundSize / 2
	local z = OutskirtsRules.zones(
		ringOuter,
		OutskirtsConfig.Stunt,
		OutskirtsConfig.Port,
		OutskirtsConfig.Desert,
		OutskirtsConfig.Site
	)
	local ring = { x = 0, z = 0, w = ringOuter * 2, d = ringOuter * 2 }
	local list = { z.stunt, z.port, z.desert, z.site }
	local apart, inside = true, true
	for ia = 1, #list do
		if OutskirtsRules.overlaps(list[ia], ring) then
			apart = false
		end
		for ib = ia + 1, #list do
			if OutskirtsRules.overlaps(list[ia], list[ib]) then
				apart = false
			end
		end
		local r = list[ia]
		if math.abs(r.x) + r.w / 2 > half or math.abs(r.z) + r.d / 2 > half then
			inside = false
		end
	end
	check("outskirts zones never overlap each other or the ring", apart)
	check("outskirts zones lie on the ground", inside)
	local S = OutskirtsConfig.Stunt
	check(
		"stunt lanes and the bowl fit the park",
		S.MegaZ - S.Mega.width / 2 > -S.Depth / 2
			and S.BowlZ + S.BowlHalf + S.BowlLength < S.Depth / 2
			and S.WallRide.foot + S.WallRide.length < S.Width / 2
			and S.Mega.foot + S.Mega.length < S.Landing.foot - S.Landing.length - S.Landing.back
	)
	local seed = 7
	local rng = function()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local H = OutskirtsConfig.Hills
	local hills = OutskirtsRules.hills(half, { ring, z.stunt, z.port, z.desert, z.site }, H, rng)
	local clear = true
	for _, h in hills do
		local f = OutskirtsRules.footprint(h.r, H.Bury)
		for _, r in { ring, z.stunt, z.port, z.desert, z.site } do
			if OutskirtsRules.distance(r, h.x, h.z) < f + H.Margin - 0.01 then
				clear = false
			end
		end
		if
			h.r < H.RadiusMin
			or h.r > H.RadiusMax
			or math.abs(h.x) > half
			or math.abs(h.z) > half
		then
			clear = false
		end
	end
	check("hills fill the empty ground", #hills > 100)
	check("no hill reaches a road or a zone", clear)
	local function checkGroves()
		local Wl = OutskirtsConfig.Wilds
		local rects = { ring, z.stunt, z.port, z.desert, z.site }
		local groves = OutskirtsRules.clearSpots(
			half,
			rects,
			hills,
			H.Bury,
			Wl.Groves,
			Wl.GroveRadius,
			Wl.Margin,
			rng
		)
		local groveClear = #groves > Wl.Groves / 2
		for ia, g in groves do
			for _, r in rects do
				if OutskirtsRules.distance(r, g.x, g.z) < Wl.GroveRadius + Wl.Margin - 0.01 then
					groveClear = false
				end
			end
			for _, h in hills do
				local d = math.sqrt((g.x - h.x) ^ 2 + (g.z - h.z) ^ 2)
				if d < OutskirtsRules.footprint(h.r, H.Bury) + Wl.GroveRadius then
					groveClear = false
				end
			end
			for ib = ia + 1, #groves do
				local o = groves[ib]
				if math.sqrt((g.x - o.x) ^ 2 + (g.z - o.z) ^ 2) < Wl.GroveRadius * 2 then
					groveClear = false
				end
			end
		end
		check("groves land on the open grass, apart, clear of roads, zones and hills", groveClear)
	end
	checkGroves()
	check(
		"a narrow sidewalk still fits benches and clutter",
		Streets.BenchInset + 1 < MW.SidewalkWidth and Streets.KerbInset + 1 < MW.SidewalkWidth - 1.5
	)
end

do
	-- every vehicle has a horn that exists, played at a sane pitch
	local hornsOk = true
	for _, v in Vehicles.List do
		local h = Vehicles.Horns[v.horn]
		local hornPitch = v.hornPitch or 1
		if
			not h
			or not string.match(h.sound, "^rbxassetid://%d+$")
			or hornPitch < 0.7
			or hornPitch > 1.4
		then
			hornsOk = false
		end
		if h and (h.volume <= 0 or h.volume > 2 or (h.start or 0) < 0) then
			hornsOk = false
		end
	end
	check("every vehicle has a known horn at a sane pitch and volume", hornsOk)
	check(
		"the jingle has a tune, a short fade and a lure interval",
		Vehicles.Jingle.fade > 0
			and Vehicles.Jingle.fade < 3
			and World.Npc.JingleEvery > 0.2
			and string.match(Vehicles.Jingle.sound, "^rbxassetid://%d+$") ~= nil
	)
	-- the water cannon: every cannon vehicle has a turret spot on its roof, and the aim arc is sane
	local nozzlesOk = true
	for _, v in Vehicles.List do
		if Vehicles.has(v, "Cannon") and not (v.nozzle and #v.nozzle == 3 and v.nozzle[2] > 0) then
			nozzlesOk = false
		end
	end
	-- people lured to the truck stop just outside it on their own side, never inside it
	local bx, bz = CrowdRules.besideBox(0.5, -0.2, 4, 10, 2)
	local cx, cz = CrowdRules.besideBox(0, 0, 4, 10, 2)
	local fx, fz = CrowdRules.besideBox(30, 80, 4, 10, 2)
	check(
		"lured people stand just outside the vehicle on their side",
		math.abs(bx - 6) < 1e-6
			and bz < 0
			and cx == 6
			and cz == 0
			and math.abs(fz - 12) < 1e-6
			and fx > 0
			and fx < 6
	)
	local N = World.Npc
	check(
		"cannon vehicles have a roof turret and the aim arc holds",
		nozzlesOk and N.CannonDown < 0 and N.CannonUp > 0 and N.CannonUp < 1 and N.CannonSend > 0
	)
end

-- car paint
do
	local PaintConfig = require("../src/shared/Config/Paints")
	local PaintRules = require("../src/shared/Rules/Paints")
	local paintIds, knownIds, pricesOk, freeCount = {}, true, true, 0
	for _, p in PaintConfig.List do
		if paintIds[p.id] or not string.match(p.id, "^%w+$") then
			knownIds = false
		end
		paintIds[p.id] = true
		if p.price < 0 then
			pricesOk = false
		end
		if p.price == 0 then
			freeCount += 1
		end
		if p.id ~= PaintConfig.FactoryId then
			local rgb = p.rgb or {}
			if
				#rgb ~= 3
				or math.min(rgb[1], rgb[2], rgb[3]) < 0
				or math.max(rgb[1], rgb[2], rgb[3]) > 255
			then
				pricesOk = false
			end
		end
	end
	check("paint ids are unique words (they go in a comma list)", knownIds)
	check("paint colours are 0-255 and prices not negative", pricesOk and freeCount >= 2)
	check("Factory paint is free", PaintRules.isOpen({}, PaintConfig.FactoryId))
	local everyCar = true
	for _, v in Vehicles.List do
		if not PaintConfig.Factory[v.id] then
			everyCar = false
		end
	end
	check("every vehicle has a factory paint colour", everyCar)

	local owned = { Sedan = true }
	check(
		"a free colour opens on an owned car",
		PaintRules.setProblem(owned, {}, "Sedan", "Red") == nil
	)
	check(
		"a paid colour stays locked until bought",
		PaintRules.setProblem(owned, {}, "Sedan", "Pink") == "locked"
	)
	check(
		"a bought colour opens",
		PaintRules.setProblem(owned, { Pink = true }, "Sedan", "Pink") == nil
	)
	check(
		"a car you don't own can't be painted",
		PaintRules.setProblem(owned, {}, "Taxi", "Red") == "vehicle"
	)
	check(
		"unknown colours are refused",
		PaintRules.setProblem(owned, {}, "Sedan", "Rainbow") == "locked"
	)
	check(
		"non-string remote arguments are refused",
		PaintRules.setProblem(owned, {}, "Sedan", 5) == "bad"
	)

	check("buying needs the money", PaintRules.buyProblem(100, {}, "Pink") == "money")
	check("buying with enough money works", PaintRules.buyProblem(1e6, {}, "Pink") == nil)
	check(
		"a bought or free colour can't be bought again",
		PaintRules.buyProblem(1e6, { Pink = true }, "Pink") == "owned"
			and PaintRules.buyProblem(1e6, {}, "Red") == "owned"
	)
	check("buying an unknown colour is refused", PaintRules.buyProblem(1e6, {}, {}) == "unknown")

	check(
		"Factory shows the car's own colour",
		PaintRules.colour("Taxi", "Factory") == PaintConfig.Factory.Taxi
	)
	check(
		"an unknown saved colour falls back to factory",
		PaintRules.colour("Taxi", "Nope") == PaintConfig.Factory.Taxi
	)
	check("a chosen colour shows", PaintRules.colour("Taxi", "Red") == PaintConfig.ById.Red.rgb)

	local chosen, paid = PaintRules.clean({
		Sedan = "Pink",
		Taxi = "Red",
		Hatchback = "Factory",
		Ghost = "Red",
		Muscle = "Gold",
		Cart = 3,
	}, { Pink = true, Red = true, Bogus = true, Gold = false })
	check(
		"saved paid colours keep only real paid ones",
		paid.Pink == true and paid.Red == nil and paid.Bogus == nil and paid.Gold == nil
	)
	check(
		"saved choices keep known cars with open colours, Factory not stored",
		chosen.Sedan == "Pink"
			and chosen.Taxi == "Red"
			and chosen.Hatchback == nil
			and chosen.Ghost == nil
			and chosen.Muscle == nil
			and chosen.Cart == nil
	)
	local none, noneBought = PaintRules.clean(nil, "junk")
	check("saves from before paint load empty", next(none) == nil and next(noneBought) == nil)
	local back = PaintRules.decode(PaintRules.encode({ Sedan = "Pink", Taxi = "Red" }))
	check("the paint attribute round-trips", back.Sedan == "Pink" and back.Taxi == "Red")
	check(
		"the paint attribute is sorted",
		PaintRules.encode({ Taxi = "Red", Sedan = "Pink" }) == "Sedan=Pink,Taxi=Red"
	)
end

do
	local function checkDaily()
		local DailyConfig = require("../src/shared/Config/Daily")
		local Daily = require("../src/shared/Rules/Daily")
		local rewards = DailyConfig.StreakRewards
		check(
			"a UTC day starts at midnight",
			Daily.day(86399, 86400) == 0 and Daily.day(86400, 86400) == 1
		)
		check("a first login starts the streak at 1", Daily.next(nil, 500) == 1)
		check(
			"collecting the day after grows the streak",
			Daily.next({ day = 499, streak = 3 }, 500) == 4
		)
		check("a missed day resets the streak", Daily.next({ day = 497, streak = 6 }, 500) == 1)
		check(
			"today can't be collected twice",
			Daily.next({ day = 500, streak = 2 }, 500) == nil
				and Daily.next({ day = 501, streak = 2 }, 500) == nil
		)
		check(
			"streak rewards climb, then stay at the last",
			Daily.reward(1, rewards) == rewards[1]
				and Daily.reward(7, rewards) == rewards[#rewards]
				and Daily.reward(40, rewards) == rewards[#rewards]
				and Daily.reward(0, rewards) == rewards[1]
		)
		local climbs = true
		for i = 2, #rewards do
			climbs = climbs and rewards[i] > rewards[i - 1]
		end
		check("each streak day pays more than the one before", climbs)

		local saleIds = Daily.saleIds(Vehicles.List, DailyConfig.DiscountSkip)
		local skipsFree, skipsRoadster = true, true
		for _, id in saleIds do
			skipsFree = skipsFree and Vehicles.ById[id].price > 0
			skipsRoadster = skipsRoadster and id ~= "Roadster"
		end
		check(
			"free cars and the Roadster are never on sale",
			#saleIds > 2 and skipsFree and skipsRoadster
		)
		local salt = DailyConfig.DiscountSalt
		local repeats, steady, everyCar = false, true, true
		local first = 20000
		for d = first, first + #saleIds * 30 do
			local today = Daily.carOfDay(saleIds, d, salt)
			repeats = repeats or today == Daily.carOfDay(saleIds, d - 1, salt)
			steady = steady and today == Daily.carOfDay(saleIds, d, salt)
		end
		for blockNo = 0, 5 do
			local seen = {}
			local start = (math.floor(first / #saleIds) + blockNo) * #saleIds
			for d = start, start + #saleIds - 1 do
				seen[Daily.carOfDay(saleIds, d, salt) :: string] = true
			end
			for _, id in saleIds do
				everyCar = everyCar and seen[id] == true
			end
		end
		check("the car of the day is the same all day", steady)
		check("the car of the day never repeats yesterday's", not repeats)
		check("every buyable car gets a day before any repeats", everyCar)
		local differs = false
		for d = first, first + 6 do
			differs = differs
				or Daily.carOfDay(saleIds, d, salt)
					~= Daily.carOfDay(saleIds, d + #saleIds * 3, salt)
		end
		check("blocks are shuffled differently", differs)
		local share, round = DailyConfig.DiscountShare, DailyConfig.DiscountRound
		check(
			"the sale price is a quarter off, rounded",
			Daily.salePrice(200, share, round) == 150
				and Daily.salePrice(3000, share, round) == 2250
				and Daily.salePrice(25000, share, round) == 18750
		)
		check(
			"only the car of the day is cheaper",
			Daily.price("Sedan", 3000, "Sedan", share, round) == 2250
				and Daily.price("Taxi", 6000, "Sedan", share, round) == 6000
				and Daily.price("Taxi", 6000, nil, share, round) == 6000
		)
	end
	checkDaily()
	local function checkSocial()
		local SocialConfig = require("../src/shared/Config/Social")
		local Social = require("../src/shared/Rules/Social")
		local per, max = SocialConfig.FriendBonusPer, SocialConfig.FriendBonusMax
		check(
			"friends boost money, capped",
			Social.friendMultiplier(0, per, max) == 1
				and math.abs(Social.friendMultiplier(2, per, max) - 1.2) < 1e-9
				and math.abs(Social.friendMultiplier(9, per, max) - (1 + max)) < 1e-9
		)
		check(
			"the friend chip shows a whole percent",
			Social.friendPercent(1, per, max) == 10 and Social.friendPercent(5, per, max) == 30
		)
		local toastState = Social.newToasts()
		local cfg = SocialConfig
		check("a short flight gets no toast", not Social.allowToast(toastState, 1, 2, 10, 0, cfg))
		check("you can't toast yourself", not Social.allowToast(toastState, 1, 1, 300, 0, cfg))
		check("a long flight gets a toast", Social.allowToast(toastState, 1, 2, 300, 0, cfg))
		check(
			"the launcher waits between toasts",
			not Social.allowToast(toastState, 1, 3, 300, cfg.ToastHitterGap - 0.1, cfg)
				and Social.allowToast(toastState, 1, 3, 300, cfg.ToastHitterGap, cfg)
		)
		check(
			"the same two players wait longer, either way round",
			not Social.allowToast(toastState, 2, 1, 300, cfg.ToastPairGap - 0.1, cfg)
				and Social.allowToast(toastState, 2, 1, 300, cfg.ToastPairGap, cfg)
		)
		Social.forget(toastState, 1)
		local cleared = toastState.hitter[1] == nil
		for key in toastState.pair do
			cleared = cleared and not string.find(key, "^1:") and not string.find(key, ":1$")
		end
		check("a player who leaves is forgotten", cleared)
		local mine, theirs = Social.toastText("Sam", "Alex", 312.4)
		check(
			"both players get a line",
			mine == "You launched Alex 312 studs!" and theirs == "Sam launched you 312 studs!"
		)
	end
	checkSocial()
end

do
	local function checkContest()
		local Contest = require("../src/shared/Rules/Contest")
		local scores = {}
		Contest.record(scores, 1, "add", 3, 0)
		Contest.record(scores, 2, "add", 5, 1)
		Contest.record(scores, 1, "add", 4, 2)
		check("add contests count up", scores[1].score == 7 and scores[2].score == 5)
		check(
			"nothing counts for zero",
			not Contest.record(scores, 3, "add", 0, 3) and scores[3] == nil
		)
		local best = {}
		Contest.record(best, 1, "max", 120, 0)
		local changed = Contest.record(best, 1, "max", 80, 1)
		check(
			"max contests keep the best",
			best[1].score == 120 and best[1].at == 0 and not changed
		)
		Contest.record(best, 2, "max", 120, 5)
		Contest.record(best, 3, "max", 200, 6)
		local standing = Contest.standings(best)
		check(
			"standings: best first, a tie goes to who got there first",
			standing[1].id == 3
				and standing[2].id == 1
				and standing[3].id == 2
				and standing[3].place == 3
		)
		Contest.record(best, 4, "max", 15, 7)
		Contest.record(best, 5, "max", 12, 8)
		local won = Contest.prizes(
			Contest.standings(best),
			EventConfig.ContestPrizes,
			EventConfig.ContestTakePart
		)
		check(
			"top 3 get the prizes, everyone else who scored gets the take-part pay",
			won[3] == EventConfig.ContestPrizes[1]
				and won[1] == EventConfig.ContestPrizes[2]
				and won[2] == EventConfig.ContestPrizes[3]
				and won[4] == EventConfig.ContestTakePart
				and won[5] == EventConfig.ContestTakePart
				and won[6] == nil
		)
		local alone = Contest.prizes(
			Contest.standings({ [9] = { score = 1, at = 0 } }),
			EventConfig.ContestPrizes,
			500
		)
		check("a lone player still wins first", alone[9] == EventConfig.ContestPrizes[1])
		check(
			"no scores, no prizes",
			next(Contest.prizes(Contest.standings({}), EventConfig.ContestPrizes, 500)) == nil
		)
		check(
			"ordinals",
			Contest.ordinal(1) == "1ST"
				and Contest.ordinal(2) == "2ND"
				and Contest.ordinal(3) == "3RD"
				and Contest.ordinal(4) == "4TH"
				and Contest.ordinal(11) == "11TH"
				and Contest.ordinal(13) == "13TH"
				and Contest.ordinal(22) == "22ND"
		)
		check(
			"amounts: one piece, many pieces",
			Contest.amount(1, "pieces") == "1 piece"
				and Contest.amount(12.4, "pieces") == "12 pieces"
				and Contest.amount(0.6, "studs") == "1 stud"
		)
		local ok, contests = true, 0
		local stats = { Breaks = true, Launch = true, Hits = true }
		for i, e in EventConfig.List do
			local c = e.contest
			if c then
				contests += 1
				ok = ok
					and stats[c.stat] == true
					and (c.mode == "add" or c.mode == "max")
					and #c.unit > 0
			end
			local isContest = c ~= nil
			-- the list wraps round, so the last and the first are neighbours too
			local nextOne = EventConfig.List[i % #EventConfig.List + 1]
			ok = ok and not (isContest and nextOne.contest ~= nil)
		end
		check("three contest events, valid, never two in a row", ok and contests == 3)
		local p = EventConfig.ContestPrizes
		check(
			"prizes fall by place and beat taking part",
			p[1] > p[2]
				and p[2] > p[3]
				and p[3] > EventConfig.ContestTakePart
				and EventConfig.ContestTakePart > 0
		)
	end
	checkContest()
end

do
	-- pedestrians reacting to traffic (Rules/Reactions)
	local Reactions = require("../src/shared/Rules/Reactions")
	local RX = CrowdConfig.React
	-- a car 20 studs south of them heading north at 40 studs/s reaches them in half a second, dead on
	local t, gap = Reactions.approach(0, 0, 0, 20, 0, -40)
	check(
		"a car heading straight at someone arrives on time",
		math.abs(t - 0.5) < 1e-6 and gap < 1e-6
	)
	check("that car is a threat", Reactions.threatened(t, gap, 3, RX))
	local t2, gap2 = Reactions.approach(0, 0, 0, 20, 0, 40)
	check("a car driving away is no threat", not Reactions.threatened(t2, gap2, 3, RX))
	local t3, gap3 = Reactions.approach(15, 0, 0, 20, 0, -40)
	check("a car passing well to the side is no threat", not Reactions.threatened(t3, gap3, 3, RX))
	local _, gap4 = Reactions.approach(4, 0, 0, 20, 0, -40)
	check("a car whose side will clip them is a threat", Reactions.threatened(0.5, gap4, 3, RX))
	local t5 = Reactions.approach(0, 0, 0, 200, 0, -40)
	check("a car five seconds off isn't noticed yet", not Reactions.threatened(t5, 0, 3, RX))
	local slow, fast = Reactions.dodgeChance(5, RX), Reactions.dodgeChance(40, RX)
	check(
		"dodging is a slim chance that shrinks with speed (hits stay easy)",
		math.abs(slow - RX.DodgeSlow) < 1e-9
			and math.abs(fast - RX.DodgeFast) < 1e-9
			and slow <= 0.4
			and fast < slow
			and Reactions.dodgeChance(19, RX) < slow
			and Reactions.dodgeChance(19, RX) > fast
	)
	-- someone a little to the east of a car heading north jumps east, off its path
	local dx, dz = Reactions.dodgeDir(1, 0, 0, 20, 0, -40, 0.9)
	check(
		"they jump sideways to the side they're on",
		math.abs(dx - 1) < 1e-6 and math.abs(dz) < 1e-6
	)
	local ex = Reactions.dodgeDir(0, 0, 0, 20, 0, -40, 0.1)
	local wx = Reactions.dodgeDir(0, 0, 0, 20, 0, -40, 0.9)
	check("dead ahead, the coin picks a side", ex * wx < 0 and math.abs(math.abs(ex) - 1) < 1e-6)
	local fx, fz = Reactions.fleePoint(10, 0, 0, 0, 50, 0.3)
	check("people run straight away from a crash", math.abs(fx - 60) < 1e-6 and math.abs(fz) < 1e-6)
	local cx, cz = Reactions.fleePoint(0, 0, 0, 0, 50, 0.3)
	check(
		"someone right on the crash still runs a full distance",
		math.abs(math.sqrt(cx * cx + cz * cz) - 50) < 1e-6
	)
	check(
		"flee and dodge numbers are sane",
		RX.FleeChance <= 1 and RX.FleeSeconds > 0 and RX.DodgeStep > 3 and RX.Look > 0.3
	)
end

do
	local function checkServerGoals()
		local SgConfig = require("../src/shared/Config/ServerGoals")
		local Sg = require("../src/shared/Rules/ServerGoals")
		check(
			"a server goal grows with players, sized for at least the minimum",
			Sg.target(20, 1, 2, 5) == 40 and Sg.target(20, 6, 2, 5) == 120
		)
		check("a server goal target rounds up to its step", Sg.target(7, 3, 1, 5) == 25)
		check("a server goal target is never zero", Sg.target(0, 0, 0, 5) == 5)
		local def = SgConfig.Kinds[2]
		local goal = Sg.make(def, 1, SgConfig.MinPlayers, 1000, SgConfig.Seconds)
		check(
			"a server goal's text shows its target",
			goal.target == def.perPlayer * SgConfig.MinPlayers
				and string.find(goal.text, tostring(goal.target), 1, true) ~= nil
		)
		check(
			"other kinds don't count",
			not Sg.add(goal, "Other", 5, 1, 1001) and goal.progress == 0
		)
		check(
			"progress after the time is up doesn't count",
			not Sg.add(goal, def.kind, 5, 1, 1000 + SgConfig.Seconds) and goal.progress == 0
		)
		local finishedEarly = Sg.add(goal, def.kind, goal.target - 1, 1, 1001)
		local finished = Sg.add(goal, def.kind, 5, 2, 1002)
		check(
			"the add that reaches the target finishes it, once",
			not finishedEarly
				and finished
				and goal.done
				and goal.progress == goal.target
				and not Sg.add(goal, def.kind, 5, 3, 1003)
		)
		check(
			"everyone who added is a helper",
			goal.helpers[1] and goal.helpers[2] and not goal.helpers[3]
		)
		check("server goal kinds take turns", Sg.nextIndex(1, 2) == 2 and Sg.nextIndex(2, 2) == 1)
	end
	checkServerGoals()
end

local function checkTraffic()
	-- traffic: the road network (Rules/Roads) and its numbers (Config/Traffic)
	local Roads = require("../src/shared/Rules/Roads")
	local TrafficConfig = require("../src/shared/Config/Traffic")
	local StreetConfig = require("../src/shared/Config/Streets")
	local Mp = World.Map
	local g = Roads.graph(grid, function(i, j)
		return i == 1 and j == 1
	end)
	local n = (Mp.BlocksX + 1) * (Mp.BlocksZ + 1)
	local roadsAlong = Mp.BlocksX * (Mp.BlocksZ + 1) + Mp.BlocksZ * (Mp.BlocksX + 1)
	check(
		"a node at every crossing and one link each way per road",
		#g.nodes == n and #g.links == roadsAlong * 2
	)
	local ax, az = Roads.crossing(grid, 0, 0)
	check(
		"crossings sit in the middle of the roads",
		math.abs(ax - (grid.x0 + Mp.RoadWidth / 2)) < 1e-6 and az == ax
	)
	-- keep right: heading east (+x), the lane is on the +z side; heading north (-z), on the +x side
	local east = g.between[Roads.nodeId(grid, 0, 0)][Roads.nodeId(grid, 1, 0)]
	local north = g.between[Roads.nodeId(grid, 0, 1)][Roads.nodeId(grid, 0, 0)]
	local _, ez = Roads.lanePoint(g, east, 10, TrafficConfig.Lane)
	local nx = Roads.lanePoint(g, north, 10, TrafficConfig.Lane)
	check(
		"cars keep right",
		math.abs(ez - (az + TrafficConfig.Lane)) < 1e-6
			and math.abs(nx - (ax + TrafficConfig.Lane)) < 1e-6
	)
	check(
		"the lane misses parked cars at the kerb",
		TrafficConfig.Lane + 4 < Mp.RoadWidth / 2 - StreetConfig.ParkedOffset - 3.5
	)
	-- at crossings: never back the way they came while another road is there; straight on is likeliest
	local noU, straights, picks = true, 0, 400
	for k = 1, picks do
		local from = g.links[(k * 37) % #g.links + 1]
		local nextId = Roads.nextLink(g, from.id, math.random(), TrafficConfig.StraightWeight)
		local nl = g.links[nextId]
		if nl.a ~= from.b then
			noU = false
		end
		if nl.b == from.a and #g.nodes[from.b].out > 1 then
			noU = false
		end
		if math.abs(nl.dx - from.dx) < 1e-6 and math.abs(nl.dz - from.dz) < 1e-6 then
			straights += 1
		end
	end
	check("no U-turns at crossings, and the next road starts where the last ended", noU)
	check("straight on is the commonest choice", straights > picks * 0.4)
	-- a right turn's curve starts on the in-lane, ends on the out-lane, and is shorter than going round the corner
	local southFrom = g.between[Roads.nodeId(grid, 1, 0)][Roads.nodeId(grid, 1, 1)] -- heading +z
	local westTo = g.between[Roads.nodeId(grid, 1, 1)][Roads.nodeId(grid, 0, 1)] -- heading -x: a right turn
	local turn = Roads.turn(g, southFrom, westTo, TrafficConfig.Lane)
	local tx0, tz0 = Roads.onTurn(turn, 0)
	local fx, fz = Roads.onTurn(turn, 1)
	local inX, inZ = Roads.lanePoint(
		g,
		southFrom,
		g.links[southFrom].length - Mp.RoadWidth / 2,
		TrafficConfig.Lane
	)
	local outX, outZ = Roads.lanePoint(g, westTo, Mp.RoadWidth / 2, TrafficConfig.Lane)
	check(
		"a turn joins the two lanes",
		math.abs(tx0 - inX) < 1e-6
			and math.abs(tz0 - inZ) < 1e-6
			and math.abs(fx - outX) < 1e-6
			and math.abs(fz - outZ) < 1e-6
	)
	local _, _, hx0, hz0 = Roads.onTurn(turn, 0)
	local _, _, hx1, hz1 = Roads.onTurn(turn, 1)
	check(
		"a turn leaves along the old road and arrives along the new one",
		math.abs(hz0 - 1) < 1e-3
			and math.abs(hx1 + 1) < 1e-3
			and math.abs(hx0) < 1e-3
			and math.abs(hz1) < 1e-3
	)
	check("a turn is a sensible length", turn.length > 5 and turn.length < Mp.RoadWidth * 1.6)
	-- lights: one way green or amber while the other is red, from server time
	local okLights = true
	for t = 0, 60, 0.5 do
		local ns, ew = Roads.lights(t, StreetConfig)
		if (ns ~= "red") == (ew ~= "red") then
			okLights = false
		end
	end
	local ns0 = Roads.lights(0.1, StreetConfig)
	local ns1 = Roads.lights(StreetConfig.SignalSeconds + 0.1, StreetConfig)
	check("only one way goes at a time", okLights and ns0 == "green" and ns1 == "amber")
	check(
		"unlit crossings never stop anyone",
		Roads.lightFor(
			g,
			east,
			StreetConfig.SignalSeconds * 1.5 + StreetConfig.AmberSeconds,
			StreetConfig
		) == "green"
	)
	check(
		"stopping speed falls to zero at the line",
		Roads.stopSpeed(0, 60) == 0 and Roads.stopSpeed(30, 60) == 60
	)
	local gap, who = Roads.gapAhead(
		0,
		0,
		0,
		-1,
		3.5,
		45,
		{ 0.5, 10, 0 },
		{ -20, -5, 10 },
		{ 1.5, 1.5, 1.5 }
	)
	check(
		"they see the nearest person in their lane ahead, not beside or behind",
		math.abs(gap - 18.5) < 1e-6 and who == 1
	)
	check(
		"boxes side by side don't touch, boxes nose to nose do",
		not Roads.overlap(0, 0, 0, -1, 3, 8, 7, 0, 0, -1, 3, 8)
			and Roads.overlap(0, 0, 0, -1, 3, 8, 0, -15, 0, 1, 3, 8)
			and Roads.overlap(0, 0, 0, -1, 3, 8, 5, -9, 1, 0, 3, 8)
	)
	check(
		"headings survive packing",
		math.abs(Roads.u16ToYaw(Roads.yawToU16(1.234)) - 1.234) < 1e-3
			and Roads.yawToU16(-0.5) == Roads.yawToU16(2 * math.pi - 0.5)
	)
	local kindsOk = true
	for _, k in TrafficConfig.Kinds do
		if not Vehicles.ById[k.id] or k.weight <= 0 then
			kindsOk = false
		end
	end
	check("traffic kinds are real vehicles", kindsOk and TrafficConfig.Count <= 255)
	check(
		"traffic waits behind the stop line, out of the crossing",
		TrafficConfig.StopLine > Mp.RoadWidth / 2 and TrafficConfig.StopLine < Mp.BlockSize / 2
	)
end
checkTraffic()

if failures > 0 then
	error(`{failures} test(s) failed`)
end
