--!strict
-- Car mastery and upgrade checks (Config/Upgrades, Rules/Upgrades), called from tests/run.

local Config = require("../src/shared/Config/Upgrades")
local Rules = require("../src/shared/Rules/Upgrades")
local Vehicles = require("../src/shared/Config/Vehicles")

return function(check: (string, boolean) -> ())
	-- every car has three upgrades numbered 1-3 with an effect text, and a signature decal name
	for _, v in Vehicles.List do
		local list = Config.ByVehicle[v.id]
		check(`upgrades: {v.id} has three`, list ~= nil and #list == 3)
		if list then
			for n, up in list do
				check(`upgrades: {v.id} {n} numbered in order`, up.n == n)
				check(
					`upgrades: {v.id} {n} says what it does`,
					#up.text > 0 and next(up.effect) ~= nil
				)
			end
		end
		check(`decals: {v.id} has a signature`, Config.Signature[v.id] ~= nil)
	end

	-- levels
	check("mastery: no points is level 0", Rules.level(0) == 0)
	check("mastery: the first level at its points", Rules.level(Config.Levels[1]) == 1)
	check("mastery: just short stays below", Rules.level(Config.Levels[2] - 1) == 1)
	check("mastery: past the top is mastered", Rules.level(1e6) == Config.MaxLevel)
	local lvl, into, span = Rules.progress(Config.Levels[1] + 10)
	check(
		"mastery: progress inside a level",
		lvl == 1 and into == 10 and span == Config.Levels[2] - Config.Levels[1]
	)
	local top, _, topSpan = Rules.progress(1e6)
	check("mastery: a mastered car has nothing left", top == Config.MaxLevel and topSpan == 0)
	check(
		"mastery: levels climb",
		Config.Levels[1] < Config.Levels[2] and Config.Levels[4] < Config.Levels[5]
	)
	check("mastery: upgrade I at level 1", Rules.upgradeOpen(1, 1) and not Rules.upgradeOpen(0, 1))
	check(
		"mastery: upgrade III only when mastered",
		Rules.upgradeOpen(5, 3) and not Rules.upgradeOpen(4, 3)
	)
	check(
		"decals: stripes at 1, signature at 5",
		Rules.decalOpen(1, "Stripes") and not Rules.decalOpen(4, "Signature")
	)

	-- prices: a share of the car's price with a floor; the Roadster priced as its basis
	check(
		"price: free starter pays the floor",
		Rules.price("Hatchback", 0, 1) == Config.PriceFloor[1]
	)
	check("price: taxi upgrade I is 10%", Rules.price("Taxi", 6000, 1) == 600)
	check("price: bulldozer upgrade III is 30%", Rules.price("Bulldozer", 100000, 3) == 30000)
	check("price: roadster uses its basis", Rules.price("Roadster", 1000000, 3) == 60000)

	-- stats
	local sedan = Vehicles.ById.Sedan
	check("stats: nothing on gives the same row", Rules.stats(sedan, {}) == sedan)
	local up1 = Rules.stats(sedan, { 1 })
	check("stats: push bar adds 25% weight", math.abs(up1.weight - sedan.weight * 1.25) < 1e-6)
	check("stats: weight upgrade leaves speed", up1.topSpeed == sedan.topSpeed)
	local up2 = Rules.stats(sedan, { 2 })
	check(
		"stats: sport rear adds accel and speed",
		math.abs(up2.launch - sedan.launch * 1.15) < 1e-6
			and math.abs(up2.topSpeed - sedan.topSpeed * 1.1) < 1e-6
	)
	local dozer = Rules.stats(Vehicles.ById.Bulldozer, { 3 })
	check(
		"stats: ripper spins the tracks faster",
		dozer.tracks ~= nil
			and dozer.tracks.pivotRate > (Vehicles.ById.Bulldozer.tracks :: any).pivotRate
	)
	local hatch = Rules.stats(Vehicles.ById.Hatchback, { 3 })
	check(
		"stats: rally roof makes bigger holes",
		(hatch.maxBreak or 0) > (Vehicles.ById.Hatchback.maxBreak or 0)
	)
	local muscle = Rules.stats(Vehicles.ById.Muscle, { 2 })
	check("stats: wide body tames the tail", muscle.rearGrip >= 1.05)
	local e = Rules.effect("Taxi", { 1, 3 })
	check("effect: taxi range and count", e.taxiRange == 1.5 and e.taxiCount == 2)
	local none = Rules.effect("Taxi", {})
	check(
		"effect: nothing on multiplies by 1",
		none.taxiRange == 1 and none.reach == 0 and none.taxiCount == nil
	)

	-- attributes and saves
	check("encode: sorted list", Rules.encode({ 3, 1 }) == "1,3")
	local back = Rules.decode("3,1,9,x")
	check("decode: known numbers only, sorted", #back == 2 and back[1] == 1 and back[2] == 3)
	check("decode: not a string is none", #Rules.decode(nil) == 0)
	local on = Rules.onList({ ["1"] = true, ["2"] = false, ["3"] = true })
	check("saved: on list skips switched-off ones", #on == 2 and on[1] == 1 and on[2] == 3)
	local m, u, d = Rules.clean(
		{ Sedan = 120, Nope = 5, Taxi = -3 },
		{ Sedan = { ["1"] = true, ["7"] = true, ["2"] = "yes" } },
		{ Sedan = "Flames", Taxi = "Nope" }
	)
	check("clean: keeps known cars' points", m.Sedan == 120 and m.Nope == nil and m.Taxi == nil)
	check(
		"clean: keeps known upgrades",
		u.Sedan ~= nil and u.Sedan["1"] == true and u.Sedan["7"] == nil and u.Sedan["2"] == nil
	)
	check("clean: keeps known decals", d.Sedan == "Flames" and d.Taxi == nil)

	-- buying and decals
	local owned = { Sedan = true }
	check("buy: fine", Rules.buyProblem(owned, 100, nil, 1000, "Sedan", 1) == nil)
	check("buy: needs the car", Rules.buyProblem({}, 100, nil, 1000, "Sedan", 1) == "car")
	check("buy: needs the level", Rules.buyProblem(owned, 99, nil, 1000, "Sedan", 1) == "locked")
	check("buy: needs the money", Rules.buyProblem(owned, 2000, nil, 10, "Sedan", 3) == "money")
	check("buy: once", Rules.buyProblem(owned, 100, { ["1"] = false }, 1000, "Sedan", 1) == "owned")
	check("buy: unknown upgrade", Rules.buyProblem(owned, 100, nil, 1000, "Sedan", 4) == "unknown")
	check(
		"decal: none always fine on an owned car",
		Rules.decalProblem(owned, 0, "Sedan", "None") == nil
	)
	check(
		"decal: locked below its level",
		Rules.decalProblem(owned, 0, "Sedan", "Stripes") == "locked"
	)
	check("decal: open at its level", Rules.decalProblem(owned, 100, "Sedan", "Stripes") == nil)

	-- model parts: a switched-on upgrade drops its stock zone and keeps its rebuilt one, and its wheel set
	-- takes the wheel names
	local sets = Rules.wheelSets({ "U3W_FL1", "Wheel_FL1", "Body" }, { 3 })
	check("parts: wheel set found", sets[3] == true)
	check("parts: stock zone kept when off", Rules.part("Z1", {}, {}) == "keep")
	check("parts: stock zone dropped when on", Rules.part("Z1_Paint", { 1 }, {}) == "drop")
	check("parts: rebuilt zone dropped when off", Rules.part("U2", { 1 }, {}) == "drop")
	check("parts: rebuilt zone kept when on", Rules.part("U2_Paint", { 2 }, {}) == "keep")
	check(
		"parts: stock wheels give way to a wheel set",
		Rules.part("Wheel_FL1", { 3 }, sets) == "drop"
	)
	check(
		"parts: the set's wheels take the names",
		Rules.part("U3W_FL1", { 3 }, sets) == "Wheel_FL1"
	)
	check("parts: an off set's wheels go", Rules.part("U3W_FL1", {}, {}) == "drop")
	check("parts: the body stays", Rules.part("Body", { 1, 2, 3 }, sets) == "keep")

	-- driving points carry studs over
	local pts, left = Rules.drivePoints(Config.Points.StudsPerPoint * 2 + 7)
	check("drive: points and leftover", pts == 2 and left == 7)
end
