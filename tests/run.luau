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
			id .. " at top speed makes a hole, not a collapse",
			smashTop(id) > 0
				and smashTop(id) <= Vehicles.ById[id].maxBreak
				and smashTop(id) < Smash.FloorsFallFrom
				and not Impact.collapses(
					Vehicles.ById[id].weight,
					Vehicles.ById[id].topSpeed / 2.237,
					Smash,
					Vehicles.ById[id].maxBreak
				)
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
	-- walls push back: early cars lose a good part of their speed, big fast ones plough on
	local function keptAtTop(id: string): number
		local v = Vehicles.ById[id]
		return Impact.wallSpeedKept(v.weight, v.topSpeed / 2.237, Smash)
	end
	for _, id in { "Cart", "Scooter", "Hatchback", "Sedan", "Taxi" } do
		check(
			id .. " rolls on through a wall, slower",
			keptAtTop(id) >= 0.5 and keptAtTop(id) <= 0.7
		)
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
	local function collapsesAt(id: string, mph: number): boolean
		local v = Vehicles.ById[id]
		return Impact.collapses(v.weight, mph / 2.237, Smash, v.maxBreak)
	end
	check("Muscle at 40 mph doesn't bring a building down", not collapsesAt("Muscle", 40))
	check("Muscle at 60 mph brings a building down", collapsesAt("Muscle", 60))
	check("Semi at 25 mph brings a building down", collapsesAt("Semi", 25))
	check("a parked Bulldozer brings nothing down", not collapsesAt("Bulldozer", 3))
	for _, v in Vehicles.List do
		if not v.maxBreak then
			check(v.id .. " can bring a building down", collapsesAt(v.id, v.topSpeed))
		end
	end
	local Fall = require("../src/shared/Rules/Collapse")
	local C = Smash.Collapse
	check("the bottom storey goes first", Fall.startDelay(0, C) < Fall.startDelay(1, C))
	check("heights past the roof stay in range", Fall.startDelay(2, C) == Fall.startDelay(1, C))
	check("every piece starts inside the show", Fall.startDelay(1, C) < C.ShowSeconds)
	check(
		"the pieces only go after the slowest show",
		C.HideSeconds > C.ShowSeconds + C.SlowSeconds * (1 / C.SlowScale - 1)
	)
	local y, landed = Fall.fallHeight(50, 0, 0.5, 120, 0, 4)
	check("a piece falls under gravity", near(y, 50 - 15, 1e-6) and not landed)
	local y2, landed2 = Fall.fallHeight(10, 0, 5, 120, 0, 4)
	check("a landed piece sinks slowly", landed2 and y2 < 0 and y2 > -30)
	check("a tiny shop still pays the minimum", Fall.payout(10, C) == C.PayMin)
	check("a tower pays more than a shop", Fall.payout(200, C) > Fall.payout(80, C))
	check("the payout has a cap", Fall.payout(100000, C) == C.PayMax)
end
check("launch grows with energy", Impact.launchSpeed(1e7) > Impact.launchSpeed(1e4))

-- world
check("roads fit the semi", World.Map.RoadWidth >= 40)

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
check("starter ad waits at least a minute of play", Products.StarterOfferAfter >= 60)
require("./offer")(check)

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
	DiamondPlate = true,
	Plaster = true,
	Pavement = true,
}
do
	check(
		"building surface materials are real and ordered",
		MATERIALS[World.Surfaces.Light] == true
			and MATERIALS[World.Surfaces.Mid] == true
			and MATERIALS[World.Surfaces.Dark] == true
			and MATERIALS[World.Surfaces.Roof] == true
			and World.Surfaces.MidFrom < World.Surfaces.LightFrom
	)
	local A = CrowdConfig.Avatar
	local T = CrowdConfig.Tags
	check(
		"crowd avatars list classic items and tags fade in order",
		#A.Shirts > 0
			and #A.Pants > 0
			and #A.Faces > 0
			and A.HatChance >= 0
			and A.HatChance <= 1
			and T.FadeFrom < T.FadeTo
			and T.GiantFadeFrom < T.GiantFadeTo
			and T.MineSize > T.OtherSize
			and rgbOk(T.Others)
			and rgbOk({ T.Mine, T.Giant })
	)
end
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
-- upper office floors join panels into runs: every panel once, in order, none longer than the limit
do
	local ok = true
	for n = 1, 13 do
		for per = 1, 4 do
			local runs = BuildingRules.runs(n, per)
			local at = 0
			for _, r in runs do
				ok = ok and r.first == at and r.count >= 1 and r.count <= per
				at += r.count
			end
			ok = ok and at == n and #runs == math.ceil(n / per)
		end
	end
	check("office panel runs cover every panel once, at most UpperPanels each", ok)
	check("a 7-panel face in runs of 3 is 3 pieces", #BuildingRules.runs(7, 3) == 3)
end
-- the countryside stays clear of the zones, the ring and the map's edge
do
	local Country = require("../src/shared/Config/Country")
	local ringOuter = 8 * 284 / 2 + 32 + OutskirtsConfig.Ring.Gap + OutskirtsConfig.Ring.Width / 2
	local zones = OutskirtsRules.zones(
		ringOuter,
		OutskirtsConfig.Stunt,
		OutskirtsConfig.Port,
		OutskirtsConfig.Desert,
		OutskirtsConfig.Site
	)
	local function overlaps(p, q)
		return math.abs(p.x - q.x) < (p.w + q.w) / 2 and math.abs(p.z - q.z) < (p.d + q.d) / 2
	end
	local ok = true
	for _, r in { Country.Farm.Rect, Country.Moto.Rect, Country.Forest.Rect } do
		for _, z in zones do
			ok = ok and not overlaps(r, z)
		end
		ok = ok and not overlaps(r, { x = 0, z = 0, w = ringOuter * 2, d = ringOuter * 2 })
		ok = ok and math.abs(r.x) + r.w / 2 < 3000 and math.abs(r.z) + r.d / 2 < 3000
	end
	check("farm, motocross and forest miss the zones and the ring, inside the map", ok)
	local odd = true
	for k, use in Country.Cells.Uses do
		if use == "gas" then
			odd = odd and k % 2 == 1 and #Country.Cells.Uses % 2 == 0
		end
	end
	check(
		"gas stations fall on cells without a billboard",
		odd and OutskirtsConfig.RingCells.BillboardEvery == 2
	)
end
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

-- outskirts: zones round the ring, and clear spots on the grass that never touch a road or zone
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
	local function checkGroves()
		local Wl = OutskirtsConfig.Wilds
		local rects = { ring, z.stunt, z.port, z.desert, z.site }
		local groves =
			OutskirtsRules.clearSpots(half, rects, Wl.Groves, Wl.GroveRadius, Wl.Margin, rng)
		local groveClear = #groves > Wl.Groves / 2
		for ia, g in groves do
			for _, r in rects do
				if OutskirtsRules.distance(r, g.x, g.z) < Wl.GroveRadius + Wl.Margin - 0.01 then
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
		check("groves land on the open grass, apart, clear of roads and zones", groveClear)
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
		local skipsCheap = true
		for _, id in saleIds do
			skipsCheap = skipsCheap and id ~= "Scooter" and id ~= "Sedan" and id ~= "Cart"
		end
		check("the Scooter, Sedan and Shopping Cart are never on sale", skipsCheap)
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
		local ownedHalf, neverOwned = {}, true
		for i, id in saleIds do
			ownedHalf[id] = i % 2 == 0
		end
		for d = first, first + #saleIds * 4 do
			local pick = Daily.pickFor(saleIds, ownedHalf, d, salt)
			neverOwned = neverOwned and pick ~= nil and not ownedHalf[pick]
		end
		check("the car of the day is never one you own", neverOwned)
		local nearOnly = true
		for d = first, first + #saleIds * 4 do
			local pick = Daily.pickFor(saleIds, {}, d, salt, 3)
			nearOnly = nearOnly and pick ~= nil and table.find(saleIds, pick) <= 3
		end
		check("with ahead = 3 the sale is one of the next 3 cars", nearOnly)
		local skipFirst = { [saleIds[1]] = true }
		local nextThree = true
		for d = first, first + 20 do
			local i =
				table.find(saleIds, Daily.pickFor(saleIds, skipFirst, d, salt, 3) :: string) :: number
			nextThree = nextThree and i >= 2 and i <= 4
		end
		check("owned cars don't count toward the next 3", nextThree)
		check(
			"no one owns anything: the pick is the day's car",
			Daily.pickFor(saleIds, {}, first, salt) == Daily.carOfDay(saleIds, first, salt)
		)
		local ownsAll = {}
		for _, id in saleIds do
			ownsAll[id] = true
		end
		check(
			"owning every sale car means no car of the day",
			Daily.pickFor(saleIds, ownsAll, first, salt) == nil
		)
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
	local Clear = require("../src/shared/Rules/Clear")
	local card = { x = 800, y = 400, w = 200, h = 180 } -- bottom right of a 1000 x 600 screen
	local x, y = Clear.slide(930, 480, 100, 100, { card }, 1000, 600, 10)
	check(
		"a pointer on the right edge slides up off the corner card",
		x == 930 and y == 400 - 10 - 50
	)
	local bx, by =
		Clear.slide(520, 560, 100, 60, { { x = 400, y = 520, w = 200, h = 80 } }, 1000, 600, 10)
	check(
		"a pointer on the bottom edge slides sideways off the speedometer, to the nearer side",
		by == 560 and bx == 600 + 10 + 50
	)
	local fx, fy = Clear.slide(100, 100, 50, 50, { card }, 1000, 600, 10)
	check("a pointer clear of every box stays put", fx == 100 and fy == 100)
end

do
	local Garage = require("../src/shared/Rules/Garage")
	local Eco = require("../src/shared/Config/Economy")
	local V = require("../src/shared/Config/Vehicles")
	local function pay(id: string): number
		local v = V.ById[id]
		return Garage.hitPay(v.weight, v.topSpeed, Eco.GaragePaySpeedShare, Eco)
	end
	check(
		"a heavier car shows more pay a hit",
		pay("Monster") > pay("Hatchback") and pay("Semi") > pay("Sedan")
	)
	check(
		"the joke rides show the base pay",
		pay("Cart") == Eco.NpcBase and pay("Scooter") == Eco.NpcBase
	)
	local function topples(id: string): boolean
		local v = V.ById[id]
		return Garage.topples(v.weight, v.topSpeed, Smash, v.maxBreak)
	end
	check(
		"early cars only make holes, the big ones topple buildings",
		not topples("Hatchback")
			and not topples("Taxi")
			and topples("Muscle")
			and topples("Bulldozer")
	)
	local list = {
		{ id = "A", price = 0 },
		{ id = "B", price = 200 },
		{ id = "C", price = 3000 },
		{ id = "R", price = 9e9 },
	}
	local function price(id: string): number
		for _, v in list do
			if v.id == id then
				return v.price
			end
		end
		return 0
	end
	check(
		"next up: the cheapest car you can't afford",
		Garage.nextUp(list, { A = true }, 500, price, { R = true }) == "C"
	)
	check(
		"next up skips owned and pass cars",
		Garage.nextUp(list, { A = true, C = true }, 500, price, { R = true }) == nil
	)
	check(
		"next up skips cars under the minimum price",
		Garage.nextUp(list, { A = true }, 100, price, { R = true }, 1000) == "C"
	)
end

do
	local Social = require("../src/shared/Rules/Social")
	check(
		"the inviter comes from Roblox's referrer, else our launch data",
		Social.inviter(42, nil, 7) == 42
			and Social.inviter(0, "invite:99", 7) == 99
			and Social.inviter(nil, "invite:99", 7) == 99
	)
	check(
		"no inviter for yourself, nonsense or nothing",
		Social.inviter(7, nil, 7) == nil
			and Social.inviter(0, "invite:7", 7) == nil
			and Social.inviter(0, "hello", 7) == nil
			and Social.inviter(nil, nil, 7) == nil
	)
	local pay1, pay2 = Social.inviteReward({}, 5, false, 2500, 1000, 10)
	check("a first invite pays both", pay1 == 2500 and pay2 == 1000)
	pay1, pay2 = Social.inviteReward({ ["5"] = true }, 5, true, 2500, 1000, 10)
	check("the same friend again pays no one", pay1 == 0 and pay2 == 0)
	local ten = {}
	for i = 1, 10 do
		ten[tostring(i)] = true
	end
	pay1, pay2 = Social.inviteReward(ten, 50, false, 2500, 1000, 10)
	check(
		"past the cap the inviter gets nothing, a new friend still gets the welcome",
		pay1 == 0 and pay2 == 1000
	)
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
		check(
			"without a full field a lone player wins full first",
			alone[9] == EventConfig.ContestPrizes[1]
		)
		local solo = Contest.prizes(
			Contest.standings({ [9] = { score = 1, at = 0 } }),
			{ 5000, 3000, 2000 },
			500,
			4
		)
		check("alone in a field of 4: a quarter of first", solo[9] == 1250)
		local pair = Contest.prizes(
			Contest.standings({ [1] = { score = 5, at = 0 }, [2] = { score = 3, at = 0 } }),
			{ 5000, 3000, 2000 },
			500,
			4
		)
		check("two taking part: half prizes", pair[1] == 2500 and pair[2] == 1500)
		local small =
			Contest.prizes(Contest.standings({ [1] = { score = 5, at = 0 } }), { 1000 }, 500, 4)
		check("a shrunk prize never drops under the take-part pay", small[1] == 500)
		local full = Contest.prizes(Contest.standings(best), { 5000, 3000, 2000 }, 500, 4)
		check(
			"a full field gets the full prizes",
			full[3] == 5000 and full[2] == 2000 and full[4] == 500
		)
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
		local stats = { Breaks = true, Launch = true, Hits = true, Stunt = true }
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
		check("four contest events, valid, never two in a row", ok and contests == 4)
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
		local half = Sg.make(def, 1, 1, 0, 600)
		Sg.add(half, def.kind, math.floor(half.target * 0.6), 1, 1)
		check(
			"out of time past the share: helpers get that share of the reward",
			Sg.partialPay(half, 1000, 0.5)
					== math.floor(1000 * half.progress / half.target / 10 + 0.5) * 10
				and Sg.partialPay(half, 1000, 0.5) > 0
		)
		local little = Sg.make(def, 1, 1, 0, 600)
		Sg.add(little, def.kind, 1, 1, 1)
		check("out of time under the share: nothing", Sg.partialPay(little, 1000, 0.5) == 0)
		check(
			"a lone player's server goal is sized for one",
			SgConfig.MinPlayers == 1
				and Sg.make(def, 1, SgConfig.MinPlayers, 0, 600).target == def.perPlayer
		)
		check("server goal kinds take turns", Sg.nextIndex(1, 2) == 2 and Sg.nextIndex(2, 2) == 1)
		local goalKinds = {}
		for _, k in SgConfig.Kinds do
			goalKinds[k.kind] = true
		end
		check(
			"stunt jumps are a server goal too",
			goalKinds.Breaks and goalKinds.Hits and goalKinds.Jumps and #SgConfig.Kinds == 3
		)
		check(
			"three server goal kinds take turns",
			Sg.nextIndex(3, 3) == 1 and Sg.nextIndex(2, 3) == 3
		)
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
		"a car in its lane stays on its own half of the road",
		TrafficConfig.Lane - TrafficConfig.HalfWidth > 0
			and TrafficConfig.Lane + TrafficConfig.HalfWidth < Mp.RoadWidth / 2
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

do
	local function checkPins()
		local Pins = require("../src/shared/Rules/Pins")
		local cfg = QuestConfig.Pins
		local function set(endsAt: number, ...: boolean)
			local list = {}
			for _, d in { ... } do
				table.insert(list, { done = d })
			end
			return { goals = list, endsAt = endsAt }
		end
		local sets =
			{ Hourly = set(100, true, false, false), Daily = set(500, false, false, false) }
		local start = Pins.default(sets, cfg.Default)
		check(
			"the default pin is the first unfinished hourly goal",
			#start == 1 and start[1].set == "Hourly" and start[1].index == 2
		)
		check("no goals, no default pin", #Pins.default({}, cfg.Default) == 0)
		local pins, what = start, ""
		pins, what = Pins.toggle(pins, "Daily", 1, 500, cfg.Max)
		check("pin a second", what == "pinned" and #pins == 2)
		pins, what = Pins.toggle(pins, "Daily", 2, 500, cfg.Max)
		local full
		full, what = Pins.toggle(pins, "Daily", 3, 500, cfg.Max)
		check("no more than three pins", #pins == 3 and what == "full" and #full == 3)
		pins, what = Pins.toggle(pins, "Daily", 1, 500, cfg.Max)
		check(
			"tapping a pinned goal unpins it",
			what == "unpinned" and #pins == 2 and not Pins.isPinned(pins, "Daily", 1)
		)
		check("toggle never edits the list it was given", #full == 3)
		-- the pinned hourly goal (index 2) is finished: the pin moves to index 3
		sets.Hourly.goals[2].done = true
		local moved, finished = Pins.advance(pins, sets)
		check(
			"a finished pin moves to the set's next unfinished goal",
			#finished == 1
				and finished[1].index == 2
				and Pins.isPinned(moved, "Hourly", 3)
				and not Pins.isPinned(moved, "Hourly", 2)
				and Pins.isPinned(moved, "Daily", 2)
		)
		sets.Hourly.goals[3].done = true
		local dropped = Pins.advance(moved, sets)
		check(
			"with nothing left in the set, the pin goes",
			#dropped == 1 and dropped[1].set == "Daily"
		)
		local both = {
			{ set = "Daily", index = 1, endsAt = 500 },
			{ set = "Daily", index = 2, endsAt = 500 },
		}
		sets.Daily.goals[1].done = true
		local after = Pins.advance(both, sets)
		check(
			"a moved pin never lands on a goal already pinned",
			#after == 2 and Pins.isPinned(after, "Daily", 2) and Pins.isPinned(after, "Daily", 3)
		)
		local rolled = Pins.advance({ { set = "Hourly", index = 2, endsAt = 100 } }, {
			Hourly = set(200, false, false, false),
		})
		check(
			"a new hour keeps the pin's place on the fresh goal",
			#rolled == 1 and rolled[1].index == 2 and rolled[1].endsAt == 200
		)
		check(
			"a pin whose set is gone is dropped",
			#Pins.advance({ { set = "Weekly", index = 1, endsAt = 0 } }, sets) == 0
		)
		check("pin numbers", cfg.Max == 3 and cfg.Default >= 1 and cfg.Default <= cfg.Max)

		-- the server goal: one goal after another, with a pause between
		local server = { { set = "Server", index = 1, endsAt = 600 } }
		local doneHere, flashed = Pins.advance(server, { Server = set(600, true) })
		check(
			"a finished server goal keeps its pin (DONE until the next one)",
			#doneHere == 1 and doneHere[1].endsAt == 600 and #flashed == 1
		)
		local waiting = Pins.advance(server, { Server = set(630) })
		check(
			"between server goals the pin waits",
			#waiting == 1 and waiting[1].set == "Server" and waiting[1].endsAt == 600
		)
		local nextGoal = Pins.advance(waiting, { Server = set(1230, false) })
		check(
			"the waiting pin moves on to the next server goal",
			#nextGoal == 1 and nextGoal[1].index == 1 and nextGoal[1].endsAt == 1230
		)
		check(
			"an hourly set without goals still drops its pin",
			#Pins.advance(
					{ { set = "Hourly", index = 1, endsAt = 100 } },
					{ Hourly = set(100) }
				) == 0
		)
		local mixed, why = Pins.toggle(server, "Hourly", 2, 100, cfg.Max)
		mixed, why = Pins.toggle(mixed, "Daily", 1, 500, cfg.Max)
		local _, fourth = Pins.toggle(mixed, "Daily", 2, 500, cfg.Max)
		check(
			"the server pin counts toward the limit",
			why == "pinned" and #mixed == 3 and fourth == "full"
		)
		check("the server goal is pinned by default", cfg.Server == true)
	end
	checkPins()

	local function checkOnboarding()
		local Config = require("../src/shared/Config/Onboarding")
		local Rules = require("../src/shared/Rules/Onboarding")
		local S = Config.Steps
		local none = { jumped = false, pieces = 0, ownsExtra = false }
		check(
			"tutorial: the retired step and unknown saves count as done, live steps stay",
			Rules.migrate(3, Config) == S.Done
				and Rules.migrate(50, Config) == S.Done
				and Rules.migrate(S.Done, Config) == S.Done
				and Rules.migrate(S.Hits, Config) == S.Hits
				and Rules.migrate(S.Event, Config) == S.Event
		)
		local order, at = {}, S.Spawn
		while at ~= S.Done do
			table.insert(order, at)
			at = Rules.after(at, Config)
		end
		check(
			"tutorial: the steps run spawn, hits, ramp, smash, goal, buy, event",
			table.concat(order, ",")
				== table.concat({ S.Spawn, S.Hits, S.Ramp, S.Smash, S.Goal, S.Buy, S.Event }, ",")
		)
		local landing, passed = Rules.landing(S.Ramp, none, Config)
		check("tutorial: nothing done early, no step passed", landing == S.Ramp and #passed == 0)
		landing, passed = Rules.landing(
			S.Ramp,
			{ jumped = true, pieces = Config.SmashGoal, ownsExtra = false },
			Config
		)
		check(
			"tutorial: a jump and a smash done early pass both steps, and stop at the goal",
			landing == S.Goal and #passed == 2
		)
		landing = Rules.landing(
			S.Smash,
			{ jumped = true, pieces = Config.SmashGoal - 1, ownsExtra = true },
			Config
		)
		check("tutorial: too few pieces don't pass the smash step", landing == S.Smash)
		landing, passed =
			Rules.landing(S.Buy, { jumped = false, pieces = 0, ownsExtra = true }, Config)
		check(
			"tutorial: a car bought early passes the buy step",
			landing == S.Event and #passed == 1
		)
		local skippable = true
		for _, s in { S.Ramp, S.Smash, S.Goal, S.Buy, S.Event } do
			skippable = skippable and Rules.canSkip(s, Config)
		end
		check(
			"tutorial: every new step can be skipped, the first two and Done can't",
			skippable
				and not Rules.canSkip(S.Spawn, Config)
				and not Rules.canSkip(S.Hits, Config)
				and not Rules.canSkip(S.Done, Config)
		)
		check(
			"tutorial: the event step ends itself only while quiet and after the wait",
			Rules.eventExpired("quiet", Config.EventWait, Config)
				and not Rules.eventExpired("quiet", Config.EventWait - 1, Config)
				and not Rules.eventExpired("warn", 999, Config)
				and not Rules.eventExpired("live", 999, Config)
				and not Rules.eventExpired(nil, 999, Config)
		)
		for step in Config.Rewards do
			check(`tutorial: reward {step} has its cheer`, Config.Cheers[step] ~= nil)
		end
		local Margins = { left = 70, top = 150, right = 70, bottom = 130 }
		local ahead = Rules.edgePoint(500, 400, 10, 1000, 800, Margins)
		local right = Rules.edgePoint(5000, 410, 10, 1000, 800, Margins)
		local down = Rules.edgePoint(500, 5000, 10, 1000, 800, Margins)
		local behind = Rules.edgePoint(500, 410, -10, 1000, 800, Margins)
		check("tutorial pointer: a target on screen is on screen", ahead.onScreen)
		check(
			"tutorial pointer: off to the right sits on the right edge and points right",
			not right.onScreen and math.abs(right.x - 930) < 0.01 and math.abs(right.angle + 90) < 2
		)
		check(
			"tutorial pointer: below sits on the bottom edge and points down",
			not down.onScreen and math.abs(down.y - 670) < 0.01 and math.abs(down.angle) < 1
		)
		check("tutorial pointer: behind the camera is never on screen", not behind.onScreen)
	end

	local function checkStunts()
		local StuntConfig = require("../src/shared/Config/Stunts")
		local Stunts = require("../src/shared/Rules/Stunts")
		local function jump(over: { [string]: any }): any
			local j = {
				air = 2,
				yaw = 0,
				upright = true,
				gravity = 1,
				topSpeed = 95,
				inPark = false,
				launched = true,
			}
			for k, v in over do
				j[k] = v
			end
			return Stunts.score(j, StuntConfig)
		end
		local plain = jump({})
		check(
			"a clean jump pays for its air",
			plain.counts and plain.clean and plain.pay == 2 * StuntConfig.PerSecond
		)
		local hop = jump({ air = StuntConfig.MinAir - 0.1 })
		check("a bump isn't a jump", not hop.counts and hop.pay == 0 and hop.label == "")
		local roof = jump({ upright = false })
		check(
			"landing on the roof is a wipeout",
			roof.counts and roof.pay == 0 and roof.label == "WIPEOUT"
		)
		check(
			"spins count with a little slack",
			Stunts.turns(300, 60) == 1
				and Stunts.turns(-700, 60) == 2
				and Stunts.turns(290, 60) == 0
		)
		local spun = jump({ yaw = -365 })
		check(
			"a 360 pays its bonus",
			spun.spins == 1 and spun.label == "360" and spun.pay > plain.pay
		)
		check("two turns is a 720", jump({ yaw = 700 }).label == "720")
		check("a long jump is huge air", jump({ air = 3.2 }).label == "HUGE AIR")
		check("the park pays double", jump({ inPark = true }).pay == plain.pay * StuntConfig.Park)
		local slow = jump({ topSpeed = 35 })
		check(
			"slow vehicles are boosted, up to the cap",
			slow.pay == math.floor(plain.pay * StuntConfig.MaxBoost / 10 + 0.5) * 10
				and jump({ topSpeed = 250 }).pay == plain.pay
		)
		local floaty = jump({ air = 4, gravity = 0.35 })
		check("low gravity air is worth less", math.abs(floaty.air - 1.4) < 1e-6)
		check(
			"one jump is capped",
			jump({ air = StuntConfig.MaxAir - 0.1, yaw = 7200, inPark = true }).pay
				== StuntConfig.MaxPay
		)
		local floated = jump({ air = StuntConfig.MaxAir + 0.1 })
		check("a jump over MaxAir is void", not floated.counts and floated.pay == 0)
		check("no real launch, no jump", not jump({ launched = false }).counts)
		local L, H = StuntConfig.MinLaunchSpeed, StuntConfig.MinHeight
		check("a ramp launch is real", Stunts.launched(L + 5, H + 2, 0, StuntConfig))
		check("off a cliff is real too", Stunts.launched(L + 5, 0, H + 10, StuntConfig))
		check("floating up from standing isn't", not Stunts.launched(0, H + 50, 0, StuntConfig))
		check("a kerb bump isn't", not Stunts.launched(L + 20, H / 3, 0, StuntConfig))
	end
	checkStunts()
	checkOnboarding()
end

-- weight and balance: the centre of mass must sit over the probes that touched ground
do
	local Balance = require("../src/shared/Rules/Balance")
	local margin = Vehicles.Balance.margin * 7
	local function at(points: { { number } }): { { x: number, z: number } }
		local out = {}
		for _, p in points do
			table.insert(out, { x = p[1], z = p[2] })
		end
		return out
	end
	local mid = { x = 0, z = 0 }
	local all = at({ { -2, -5 }, { 2, -5 }, { -2, 0 }, { 2, 0 }, { -2, 5 }, { 2, 5 } })
	check("all wheels down is balanced", Balance.supported(all, mid, margin))
	check(
		"rear wheels on a ledge, nose in the air, tips",
		not Balance.supported(at({ { -2, 5 }, { 2, 5 } }), mid, margin)
	)
	check(
		"front wheels only tips",
		not Balance.supported(at({ { -2, -5 }, { 2, -5 } }), mid, margin)
	)
	check(
		"ledge edge past the centre of mass holds",
		Balance.supported(at({ { -2, 0 }, { 2, 0 }, { -2, 5 }, { 2, 5 } }), mid, margin)
	)
	check(
		"centre of mass a little past the edge holds",
		Balance.supported(
			at({ { -2, 0 }, { 2, 0 }, { -2, 5 }, { 2, 5 } }),
			{ x = 0, z = -0.5 },
			margin
		)
	)
	check(
		"centre of mass well past the edge tips",
		not Balance.supported(
			at({ { -2, 0 }, { 2, 0 }, { -2, 5 }, { 2, 5 } }),
			{ x = 0, z = -3 },
			margin
		)
	)
	check(
		"one side over a drop tips",
		not Balance.supported(at({ { -2, -5 }, { -2, 0 }, { -2, 5 } }), mid, margin)
	)
	check("one probe tips", not Balance.supported(at({ { 2, 5 } }), mid, margin))
	check("no ground never counts as balanced", not Balance.supported({}, mid, margin))
	check(
		"three corners still hold the middle",
		Balance.supported(at({ { -2, -5 }, { 2, -5 }, { 2, 5 } }), mid, margin)
	)
	check("hull drops inner points", #Balance.hull(all) == 4)
end

do
	-- parks and ramps: the park's paths and pond fit its block, the ramp deck is a real material
	local Parks = require("../src/shared/Config/Parks")
	local Ramps = require("../src/shared/Config/Ramps")
	local PK = Parks.Park
	local parkInner = World.Map.BlockSize - World.Map.SidewalkWidth * 2
	local lawn = (parkInner / 2 - PK.Path / 2) / 2 - 8
	check(
		"the park's pond, paths and lawns fit its block",
		PK.Pond + PK.Rim * 2 + 8 < parkInner / 2
			and lawn > 24
			and Parks.Tree.Trunk[1] < Parks.Tree.Trunk[2]
	)
	check(
		"ramp trim fits and the deck is a real material",
		MATERIALS[Ramps.Deck] == true and Ramps.Lip > 0 and Ramps.ChevronSpan < 0.5
	)
end

do
	-- bigger everyone: the scales are sane, and the traffic numbers fit the everyday cars at the vehicle scale
	local fs = require("@lune/fs")
	local roblox = require("@lune/roblox")
	local TrafficConfig = require("../src/shared/Config/Traffic")
	local S = Game.VehicleScale
	check(
		"body scale is a modest growth and cars grow at least as much",
		Game.BodyScale >= 1
			and Game.BodyScale <= 1.5
			and S >= Game.BodyScale
			and S <= Game.BodyScale * 1.15
	)
	local models = roblox.deserializeModel(fs.readFile("assets/Vehicles.rbxm"))[1]
	local fits = true
	for _, kind in TrafficConfig.Kinds do
		local m = models:FindFirstChild(kind.id)
		local lo, hi = math.huge, -math.huge
		local wide = 0
		for _, p in (if m then m:GetChildren() else {}) do
			if p.Name == "Body" or string.sub(p.Name, 1, 6) == "Wheel_" then
				local at, size = p.CFrame.Position, p.Size
				lo = math.min(lo, at.Z - size.Z / 2)
				hi = math.max(hi, at.Z + size.Z / 2)
				wide = math.max(wide, math.abs(at.X) + size.X / 2)
			end
		end
		-- queued cars keep CarLength + Gap between centres, so no two bumpers meet; the clear path ahead is a
		-- little wider than the car (the rare ice cream van is a little wider still)
		local spare = if kind.id == "IceCream" then -0.5 else 0.2
		if
			not m
			or (hi - lo) * S > TrafficConfig.CarLength + TrafficConfig.Gap
			or wide * S + spare > TrafficConfig.HalfWidth
		then
			print(`  {kind.id}: length {(hi - lo) * S}, half width {wide * S}`)
			fits = false
		end
	end
	check("traffic spacing and lane width fit the scaled everyday cars", fits)
end

local function checkRookiePay()
	local untilVehicle = Vehicles.ById[Economy.RookieUntil]
	check("rookie pay ends at a real vehicle", untilVehicle ~= nil and untilVehicle.price > 0)
	local price = untilVehicle.price
	local function over(owned: { [string]: boolean }, money: number, done: boolean?): boolean
		return Impact.rookieOver(owned, money, done == true, Vehicles.ById, price)
	end
	check("a new player gets rookie pay", not over({ Hatchback = true }, 0))
	check("just short of the price keeps rookie pay", not over({ Hatchback = true }, price - 1))
	check(
		"cheap joke cars keep rookie pay",
		not over({ Hatchback = true, Scooter = true, Cart = true }, 100)
	)
	check("holding the price in cash ends rookie pay", over({ Hatchback = true }, price))
	check("owning the Sedan ends rookie pay", over({ Hatchback = true, Sedan = true }, 0))
	check("a dearer car ends rookie pay", over({ Hatchback = true, Supercar = true }, 0))
	check("spending back down doesn't bring it back", over({ Hatchback = true }, 0, true))
	check("unknown saved ids are ignored", not over({ Hatchback = true, Gone = true }, 0))
	check("rookie pay is a real boost", Economy.RookieMultiplier > 1)
end
checkRookiePay()

do
	local Layout = require("../src/shared/Rules/Layout")
	local cfg = require("../src/shared/Config/Layout")
	check("layout: a desktop screen is not scaled", Layout.scale(1920, 1019, cfg) == 1)
	check("layout: a laptop screen is not scaled", Layout.scale(1280, 640, cfg) == 1)
	local phone = Layout.scale(848, 395, cfg)
	check("layout: a phone is scaled by its height", math.abs(phone - 395 / 560) < 1e-6)
	check("layout: a tiny screen stops at the minimum", Layout.scale(300, 200, cfg) == cfg.MinScale)
	check("layout: a narrow screen scales by width", Layout.scale(800, 900, cfg) == 0.8)
	check("layout: garage row fits the phone canvas", 395 / phone - 86 - 84 >= 310)
	check(
		"layout: touch buttons keep their minimum size",
		math.abs(phone * Layout.touchBoost(phone, cfg.TouchMinScale) - cfg.TouchMinScale) < 1e-6
	)
	check("layout: no boost at full size", Layout.touchBoost(1, cfg.TouchMinScale) == 1)
	check(
		"layout: a phone clears the small jump button",
		Layout.touchClear(848, 395, cfg) == cfg.TouchClearSmall
	)
	check(
		"layout: a tablet clears the big jump button",
		Layout.touchClear(1024, 768, cfg) == cfg.TouchClearLarge
	)
	check("layout: thumb zone covers lower left", Layout.inThumbZone(100, 200, 848, 395, cfg))
	check("layout: top left is clear of the thumb", not Layout.inThumbZone(100, 100, 848, 395, cfg))
	check(
		"layout: right side is clear of the thumb",
		not Layout.inThumbZone(600, 300, 848, 395, cfg)
	)
	-- the touch rack folds to two rows where its top row would reach the cash box (real GUI px under
	-- Roblox's top bar, measured in Studio's emulator: iPhone 14 749x323; iPhone SE about 667x317)
	local function wideAt(guiW: number, guiH: number): boolean
		local s = Layout.scale(guiW, guiH, cfg)
		local key = math.max(s, cfg.TouchMinScale)
		local clear = Layout.touchClear(guiW, guiH, cfg)
		return Layout.touchWide(guiH, clear, key, 62 * s, cfg.TouchCashGap * s, cfg)
	end
	check("layout: a short phone folds the touch rack", wideAt(667, 317))
	check("layout: a normal phone folds the touch rack", wideAt(749, 323))
	check("layout: a tablet keeps three rows", not wideAt(1024, 732))
	local filled: { [string]: boolean } = {}
	for name, slot in cfg.TouchSlotsWide do
		local k = `{slot[1]},{slot[2]}`
		check(`layout: wide rack slot {name} is free`, not filled[k])
		filled[k] = true
		check(`layout: wide rack has no top row ({name})`, slot[2] >= 0)
	end
	for name in cfg.TouchSlots do
		check(`layout: {name} has a wide slot`, cfg.TouchSlotsWide[name] ~= nil)
	end
end
do
	local Rules = require("../src/shared/Rules/DriveHud")
	local cfg = require("../src/shared/Config/DriveHud")
	local function keyList(rows: { Rules.Row }): string
		local list = {}
		for _, r in rows do
			table.insert(list, r.key)
		end
		return table.concat(list, ",")
	end
	check("drive hud: a plain car lists the basics", keyList(Rules.rows({})) == "WASD,SPACE,V,H,T")
	check(
		"drive hud: the unstuck row counts down",
		Rules.rows({ unstuckWait = 4 })[5].label == "Unstuck (4)"
	)
	check(
		"drive hud: a thruster car adds R",
		keyList(Rules.rows({ thruster = true })) == "WASD,SPACE,V,H,T,R"
	)
	check(
		"drive hud: a jet car lists its flight keys, not the thruster",
		keyList(Rules.rows({ jet = true, thruster = true })) == "WASD,SPACE,V,H,T,SHIFT,Q/E,S,R"
	)
	check(
		"drive hud: a taxi's G row reads Taxi!",
		Rules.rows({ feature = "TAXI!" })[6].label == "Taxi!"
	)
	check(
		"drive hud: the jingle row says what G does next",
		Rules.rows({ feature = "JINGLE", jingleOn = true })[6].label == "Jingle off"
	)
	check(
		"drive hud: the card is open on the first drives",
		Rules.startsOpen(cfg.OpenDrives, false, cfg)
	)
	check("drive hud: then it folds", not Rules.startsOpen(cfg.OpenDrives + 1, false, cfg))
	check(
		"drive hud: returning players see it for fewer drives",
		cfg.OpenDrivesReturning < cfg.OpenDrives
			and not Rules.startsOpen(cfg.OpenDrivesReturning + 1, true, cfg)
	)
end
local function checkPopups()
	local Rules = require("../src/shared/Rules/Popups")
	local Cfg = require("../src/shared/Config/Popups")
	check("popups: on foot counts as still", Rules.isStill(false, 50, 1, Cfg))
	check("popups: stopped with no throttle is still", Rules.isStill(true, 0, 0, Cfg))
	check("popups: throttle held is not still (pushing a wall)", not Rules.isStill(true, 0, 1, Cfg))
	check("popups: driving is not still", not Rules.isStill(true, 40, 0, Cfg))
	check("popups: moving at MovingMph", Rules.isMoving(true, Cfg.MovingMph, Cfg))
	check("popups: on foot is never moving", not Rules.isMoving(false, 99, Cfg))
	check("popups: not while moving", not Rules.mayOpen(100, nil, nil, Cfg))
	check(
		"popups: not the moment they stop",
		not Rules.mayOpen(100, 100 - Cfg.StoppedSeconds / 2, nil, Cfg)
	)
	check("popups: once stopped a moment", Rules.mayOpen(100, 100 - Cfg.StoppedSeconds, nil, Cfg))
	check(
		"popups: not straight after another",
		not Rules.mayOpen(100, 0, 100 - Cfg.GapSeconds / 2, Cfg)
	)
	check("popups: after the gap", Rules.mayOpen(100, 0, 100 - Cfg.GapSeconds, Cfg))
end
checkPopups()

local function checkUnstuck()
	local Rules = require("../src/shared/Rules/Unstuck")
	local Cfg = require("../src/shared/Config/Unstuck")
	local crumbs: { any } = {}
	check("unstuck: first trail point is due", Rules.due(crumbs, 0, 0, Cfg))
	for i = 0, Cfg.MaxCrumbs + 4 do
		Rules.push(crumbs, { x = i * Cfg.Spacing, y = 0, z = 0, lx = 1, lz = 0 }, Cfg)
	end
	check("unstuck: trail is capped", #crumbs == Cfg.MaxCrumbs)
	local lastX = (Cfg.MaxCrumbs + 4) * Cfg.Spacing
	check("unstuck: not due right away", not Rules.due(crumbs, lastX + 1, 0, Cfg))
	check("unstuck: due after Spacing", Rules.due(crumbs, lastX + Cfg.Spacing, 0, Cfg))
	local spots = Rules.spots(crumbs, lastX, 0, Cfg)
	check("unstuck: nearest usable point first", lastX - spots[1].x >= Cfg.MinBack)
	check("unstuck: and not further than needed", lastX - spots[1].x < Cfg.MinBack + Cfg.Spacing)
	check("unstuck: newest first", spots[1].x > spots[2].x)
	check("unstuck: empty trail, no spots", #Rules.spots({}, 0, 0, Cfg) == 0)
	check("unstuck: upright goes back", Rules.action(1, false, false, 0, 0, 10, Cfg) == "back")
	check("unstuck: on its side flips", Rules.action(0, false, false, 0, 0, 10, Cfg) == "flip")
	check("unstuck: cooldown", Rules.action(1, false, false, 0, 11, 10, Cfg) == nil)
	check("unstuck: not at speed", Rules.action(1, false, false, Cfg.MaxMph + 1, 0, 10, Cfg) == nil)
	check("unstuck: not while flying", Rules.action(1, true, false, 0, 0, 10, Cfg) == nil)
	check("unstuck: not while flung", Rules.action(1, false, true, 0, 0, 10, Cfg) == nil)
	local roads = { { { 0, 0 }, { 100, 0 } }, { { 200, -50 }, { 200, 50 } } }
	local rx, rz, dx, dz, d = Rules.nearestRoad(roads, 30, 12)
	check(
		"unstuck: nearest road point",
		rx == 30 and rz == 0 and math.abs(dx :: number) == 1 and dz == 0 and d == 12
	)
	rx, rz, _, dz, d = Rules.nearestRoad(roads, 190, 80)
	check(
		"unstuck: nearest road clamps to its end",
		rx == 200 and rz == 50 and dz ~= 0 and (d :: number) > 30
	)
	check("unstuck: no roads, no point", Rules.nearestRoad({}, 0, 0) == nil)
	local RoadLayout = require("../src/shared/Rules/RoadLayout")
	local L = RoadLayout.fromConfig()
	local lines = {}
	for _, r in L.roads do
		table.insert(lines, r.pts)
	end
	local gx, gz = Rules.nearestRoad(lines, 0, 0)
	check(
		"unstuck: the spawn plaza has a road within reach",
		gx ~= nil and math.sqrt((gx :: number) ^ 2 + (gz :: number) ^ 2) <= Cfg.RoadMax
	)
end
checkUnstuck()

local function checkHitGuard()
	local Rules = require("../src/shared/Rules/HitGuard")
	local Cfg = require("../src/shared/Config/HitGuard")
	local spm = require("../src/shared/Config/Vehicles").StudsPerMetre
	local max = Rules.maxStuds(100, false, spm, Cfg)
	check("hit guard: top speed with slack", max > 100 / Cfg.MphPerMs * spm)
	check("hit guard: the jet allows more", Rules.maxStuds(100, true, spm, Cfg) > max)
	check("hit guard: an honest claim is paid as is", Rules.speed(60, max, 58, Cfg) == 60)
	check(
		"hit guard: a parked car can't claim top speed",
		Rules.speed(max, max, 0, Cfg) == Cfg.ClaimMargin
	)
	check(
		"hit guard: never over the vehicle's limit",
		Rules.speed(max * 3, max, max * 3, Cfg) == max
	)
	check(
		"hit guard: driving at top speed is no teleport",
		not Rules.teleported(max * 0.2, 0.2, max, Cfg)
	)
	check("hit guard: a long jump is", Rules.teleported(500, 0.2, max, Cfg))
end
checkHitGuard()

-- player hits: big cars skip repeat falloff and get a shorter shield; repeats fall off to a floor
do
	local HitConfig = require("../src/shared/Config/PlayerHits")
	local HitRules = require("../src/shared/Rules/PlayerHits")
	local roadster = Vehicles.ById.Roadster.price
	local sedan = Vehicles.ById.Sedan.price
	check("roadster hits as a big car", HitRules.isBig(roadster, HitConfig))
	check("sedan is not a big car", not HitRules.isBig(sedan, HitConfig))
	check("first hit does full launch", HitRules.repeatScale(0, sedan, HitConfig) == 1)
	check("repeat hit does less", HitRules.repeatScale(1, sedan, HitConfig) < 1)
	check(
		"repeat falloff has a floor",
		HitRules.repeatScale(50, sedan, HitConfig) == HitConfig.RepeatFloor
	)
	check("big cars skip repeat falloff", HitRules.repeatScale(5, roadster, HitConfig) == 1)
	local hatch = HitRules.carLaunchCap(Vehicles.ById.Hatchback.price, HitConfig)
	local muscle = HitRules.carLaunchCap(Vehicles.ById.Muscle.price, HitConfig)
	check(
		"cheap cars knock other cars less",
		hatch == HitConfig.CheapCarLaunchCap
			and hatch < muscle
			and muscle < HitConfig.Normal.carLaunchCap
			and HitRules.carLaunchCap(roadster, HitConfig) == HitConfig.Big.carLaunchCap
	)
	local normal, big = HitConfig.Normal, HitConfig.Big
	check(
		"big cars get the shorter shield and stronger hits",
		HitRules.terms(roadster, HitConfig) == big
			and big.shield < normal.shield
			and big.launchCap >= normal.launchCap
			and big.ragdoll >= normal.ragdoll
			and normal.shield > 0
	)
end

-- crumbling walls (Rules/Crumble, Config/Smash Crumble)
local function checkCrumble()
	local Crumble = require("../src/shared/Rules/Crumble")
	local Net = require("../src/shared/Net")
	local C = Smash.Crumble
	check("crumble message is named in Net", Net.Messages.Crumble == "Crumble")
	local k, ka, kb = Crumble.axes(30, 12, 1.5)
	check(
		"a wall's thickness is its thin side, its long side first",
		k == 3 and ka == 1 and kb == 2
	)
	local k2, a2, b2 = Crumble.axes(0.6, 20, 0.6)
	check("a pole is cut along its length", a2 == 2 and k2 ~= 2 and b2 ~= 2)

	-- a light car's hole in a long town wall: a few bricks out, the rest standing as a few blocks
	local A, B = 30, 12
	local cut = Crumble.grid(A, B, 3, C.MaxFly, C)
	check("cells are never smaller than a brick", A / cut.na >= C.MinCell - 1e-6)
	check("a wall is cut into at most MaxGrid cells", cut.na * cut.nb <= C.MaxGrid)
	local thrown = Crumble.hole(cut, A, B, 0, -3, 3, C.MaxFly, 12345, C)
	check("a small hit throws a few bricks", #thrown >= 2 and #thrown <= C.MaxFly)
	local standing = Crumble.mesh(cut, thrown)
	check("what's left stands as a handful of blocks", #standing >= 2 and #standing <= C.MaxStay)
	-- every cell is thrown or in exactly one standing block
	local seen: { [number]: number } = {}
	for _, cell in thrown do
		seen[cell] = (seen[cell] or 0) + 1
	end
	local area = 0
	for _, r in standing do
		for j = r.j0, r.j1 do
			for i = r.i0, r.i1 do
				local cell = j * cut.na + i + 1
				seen[cell] = (seen[cell] or 0) + 1
			end
		end
		local _, _, w, h = Crumble.rectBox(cut, A, B, r)
		area += w * h
	end
	local exact = true
	for cell = 1, cut.na * cut.nb do
		if seen[cell] ~= 1 then
			exact = false
		end
	end
	check("thrown cells and standing blocks cover the wall once", exact)
	check(
		"standing blocks plus thrown bricks make up the wall",
		near(area + #thrown * (A / cut.na) * (B / cut.nb), A * B, 1e-6)
	)
	-- the hole is around the hit, not somewhere else on the wall
	local farthest = 0
	for _, cell in thrown do
		local i, j = (cell - 1) % cut.na, (cell - 1) // cut.na
		local u, v = Crumble.cellCentre(cut, A, B, i, j)
		farthest = math.max(farthest, math.sqrt(u * u + (v + 3) ^ 2))
	end
	check("the bricks come from around the hit", farthest <= 3 * (1 + C.Ragged) + 1e-6)
	check(
		"the same break always cuts the same way",
		table.concat(Crumble.hole(cut, A, B, 0, -3, 3, C.MaxFly, 12345, C), ",")
			== table.concat(thrown, ",")
	)
	local tiny = Crumble.hole(cut, A, B, 0, -3, 0, C.MaxFly, 1, C)
	check("a glancing hit still throws one brick", #tiny == 1)

	-- a big hit over the whole wall: bigger cells so it's still only about MaxFly bricks
	local whole = Crumble.grid(A, B, math.huge, C.MaxFly, C)
	check("a whole wall breaks into about MaxFly bricks", whole.na * whole.nb <= C.MaxFly * 2)
	check("a whole wall is more than one brick", whole.na * whole.nb > 1)
	check("nothing stands of a wall thrown whole", #Crumble.mesh(whole, Crumble.all(whole)) == 0)
	local full = Crumble.hole(whole, A, B, 0, 0, 1000, C.MaxFly, 7, C)
	check("a hole never throws more than its share", #full <= C.MaxFly)

	-- a lamp post breaks into a few lengths, not a heap of slivers
	local pole = Crumble.grid(20, 0.6, math.huge, C.PropFly, C)
	check(
		"a lamp post breaks into a few lengths",
		pole.nb == 1 and pole.na >= 2 and pole.na <= C.PropFly
	)

	-- budgets
	check(
		"one break's bricks are shared out",
		Crumble.share(C.Budget, 100, C.MaxFly) * 100 <= C.Budget
	)
	check(
		"every broken wall throws at least one brick",
		Crumble.share(C.Budget, 10000, C.MaxFly) == 1
	)
	check(
		"one wall never throws more than MaxFly",
		Crumble.share(C.Budget, 1, C.MaxFly) == C.MaxFly
	)
	check("phones keep fewer bricks", C.MaxLivePhone < C.MaxLive and C.MaxLivePhone > 0)
	check("bricks lie a while, then sink", C.LifeSeconds[1] > C.SettleAfter and C.SinkSeconds > 0)
	check("leftover blocks fit the map's part budget", C.MaxRemnants > 0 and C.MaxRemnants <= 1000)
	check(
		"a hole's reach shrinks off the wall's face",
		Crumble.reach(5, 3) == 4 and Crumble.reach(2, 3) == 0
	)
	local spread = 0
	for cell = 1, 200 do
		local x = Crumble.noise(99, cell)
		if x < 0 or x >= 1 then
			spread = -1000
		end
		spread += x
	end
	check(
		"the ragged edge's noise is spread over 0..1",
		spread / 200 > 0.35 and spread / 200 < 0.65
	)
	check("collapse bricks fit the screen's budget", Smash.Collapse.CrumbleBudget <= C.MaxLive)
end
checkCrumble()

-- the car parks: parked cars are real vehicle ids, the ramp lots keep their ramp's run clear
local function checkLots()
	local Lots = require("../src/shared/Config/Lots")
	local VehicleIds = require("../src/shared/Config/Vehicles").ById
	local Country = require("../src/shared/Config/Country")
	local ok = true
	for _, list in { Lots.Cars, Lots.LotCars } do
		for _, id in list do
			ok = ok and VehicleIds[id] ~= nil
		end
	end
	check("parked cars are vehicles that exist", ok)
	-- the ramp lot's south ramp stands at x 30 (MapBuilder), 30 wide; parked bays keep off it
	local L = Country.Lot
	local clear = true
	for _, k in Lots.LotParked do
		local x = L.Shift - L.Bays * L.Bay[1] / 2 + (k - 0.5) * L.Bay[1]
		clear = clear and k >= 1 and k <= L.Bays and math.abs(x - 30) > 15 + L.Bay[1] / 2
	end
	check("ramp lots' parked cars keep clear of the south ramp", clear)
	local yardsOk = true
	for _, y in { Lots.ShopYard, Lots.OfficeLot, Lots.BurgerLot } do
		yardsOk = yardsOk and y.cars <= y.bays and y.bays >= 1
	end
	check("yards park no more cars than they have bays", yardsOk)
end
checkLots()

-- the island (Config/Land): everything the old square map had stays on land inside the walls, and the suburbs
-- fit inside the edge
local function checkLand()
	local LandCfg = require("../src/shared/Config/Land")
	local Land = require("../src/shared/Rules/Land")
	local Suburbs = require("../src/shared/Config/Suburbs")
	local seaEdge = -2203 -- the port's quay (Outskirts zones at the default ring), as measured in Studio
	check("the coast is straight along the beaches", Land.coast(LandCfg, seaEdge, 2999) == seaEdge)
	check("the coast curves inland past them", Land.coast(LandCfg, seaEdge, 4000) > seaEdge + 200)
	local inside = true
	for _, p in
		{
			{ 2650, 2650 },
			{ 2650, -2650 },
			{ -1950, -2800 },
			{ 2400, 0 },
			{ 0, -2700 },
			{ 0, 2700 },
		}
	do
		inside = inside and Land.isLand(LandCfg, seaEdge, p[1], p[2], 200)
	end
	check("the old map's far corners are well inside the island", inside)
	local outline = Land.outline(LandCfg, seaEdge, 120)
	local ok = #outline == 120
	for _, p in outline do
		ok = ok and Land.inBounds(LandCfg, seaEdge, p.x * 0.99, p.z * 0.99)
	end
	check("the walls run round the bounds", ok)
	local fits = true
	for _, h in Suburbs.Hoods do
		local dir = { x = h.dir[1], z = h.dir[2] }
		local perp = { x = -dir.z, z = dir.x }
		local ox, oz = math.abs(dir.z) * h.offset, math.abs(dir.x) * h.offset
		for _, u in { h.start, h.start + h.length + Suburbs.Bulb + 60 } do
			for _, v in { -h.half, h.half } do
				local x, z = ox + dir.x * u + perp.x * v, oz + dir.z * u + perp.z * v
				fits = fits and Land.isLand(LandCfg, seaEdge, x, z, 150)
			end
		end
	end
	check("every suburb's corners are on land, clear of the edge hills", fits)
end
checkLand()

-- the road meshes were built from this exact layout (rebuild them with tools/roads when it changes)
local function checkRoads()
	local RoadLayout = require("../src/shared/Rules/RoadLayout")
	local RoadMeshes = require("../src/shared/Config/RoadMeshes")
	local Suburbs = require("../src/shared/Config/Suburbs")
	local layout = RoadLayout.fromConfig()
	check(
		"the road meshes match the road layout (else run tools/roads, see build_roads.py)",
		RoadLayout.hash(layout) == RoadMeshes.Hash
	)
	local streamA, streamB = RoadLayout.stream(7), RoadLayout.stream(7)
	local repeats, inUnit, spread = true, true, {} :: { [number]: boolean }
	for _ = 1, 200 do
		local x = streamA()
		repeats = repeats and x == streamB()
		inUnit = inUnit and x >= 0 and x < 1
		spread[math.floor(x * 10)] = true
	end
	local buckets = 0
	for _ in spread do
		buckets += 1
	end
	check("the layout's random stream repeats and spreads", repeats and inUnit and buckets == 10)
	local streetsOk = #layout.suburbs == #Suburbs.Hoods
	for _, sub in layout.suburbs do
		streetsOk = streetsOk and #sub.streets >= 3
		for _, street in sub.streets do
			streetsOk = streetsOk and #street.pts >= 4
		end
	end
	check("every suburb has a spine and side streets", streetsOk)
	local named = true
	local seen = {}
	for _, m in RoadMeshes.Meshes do
		named = named
			and not seen[m.name]
			and (m.layer == "Asphalt" or m.layer == "Concrete" or m.layer == "Trim")
		seen[m.name] = true
	end
	check("road meshes have unique names and known layers", named and #RoadMeshes.Meshes > 0)
	-- the same paint as the old StreetKit: lines stop short of crossings, zebras inside the stop lines
	local S = require("../src/shared/Config/Streets")
	local strokes = RoadLayout.segmentStrokes(220, 64, S, true)
	local zebras = 0
	for _, stroke in strokes do
		if stroke.w == S.ZebraLength then
			zebras += 1
		end
	end
	check("a segment has two zebras", zebras == 2 * S.ZebraStripes)
end
checkRoads()

-- the giant keeps to the streets (no doors, desks or benches) and its finder column hovers clear of it
local function checkGiant()
	local onlyWander = true
	for _ = 1, 300 do
		for _, atHome in { true, false } do
			if CrowdRules.nextGoal("giant", atHome, math.random, CrowdConfig) ~= "wander" then
				onlyWander = false
			end
		end
	end
	check("the giant only ever wanders the streets", onlyWander and not CrowdRules.isStaff("giant"))
	local G = EventConfig.GiantFinder
	check(
		"the giant is stood on the ground from a probe that reaches it, and its column hovers over its head",
		EventConfig.GiantGroundProbe.Up > 1
			and EventConfig.GiantGroundProbe.Up < 10
			and EventConfig.GiantGroundProbe.Down >= 20
			and EventConfig.GiantSpawnLift >= 0
			and EventConfig.GiantSpawnLift < 2
			and G.BeamGap > 0
			and G.BeamGap < G.BeamHeight / 10
	)
end
checkGiant()

if failures > 0 then
	error(`{failures} test(s) failed`)
end
