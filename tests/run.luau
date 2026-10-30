--!strict
-- Run with: lune run tests/run
local Economy = require("../src/shared/Config/Economy")
local Game = require("../src/shared/Config/Game")
local Impact = require("../src/shared/Rules/Impact")
local QuestConfig = require("../src/shared/Config/Quests")
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

if failures > 0 then
	error(`{failures} test(s) failed`)
end
