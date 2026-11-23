--!strict
-- Analytics checks (Config/Analytics, Rules/Analytics), called from tests/run.

local Cfg = require("../src/shared/Config/Analytics")
local Onboarding = require("../src/shared/Config/Onboarding")
local Rules = require("../src/shared/Rules/Analytics")

return function(check: (string, boolean) -> ())
	local function dev(tenFoot, touch, keyboard, gamepad, shortSide): string
		return Rules.device({
			tenFoot = tenFoot,
			touch = touch,
			keyboard = keyboard,
			gamepad = gamepad,
			shortSide = shortSide,
		}, Cfg)
	end
	check("device: a console's ten-foot screen", dev(true, false, false, true, 1080) == "Console")
	check(
		"device: touch, no keys, small screen is a phone",
		dev(false, true, false, false, 390) == "Phone"
	)
	check(
		"device: touch, no keys, big screen is a tablet",
		dev(false, true, false, false, 820) == "Tablet"
	)
	check("device: keyboard is a PC", dev(false, false, true, false, 1080) == "PC")
	check("device: a touch laptop with keys is a PC", dev(false, true, true, false, 900) == "PC")
	check("device: only a gamepad is a console", dev(false, false, false, true, 1080) == "Console")
	check("device: nothing known", dev(false, false, false, false, 0) == "Unknown")
	check(
		"device: touch before the screen is sized",
		dev(false, true, false, false, 0) == "Unknown"
	)
	for _, d in { "Phone", "Tablet", "PC", "Console", "Unknown" } do
		check(`device: {d} is an allowed value`, Rules.oneOf(Cfg.Devices, d))
	end

	local function act(driving, menu, idle, wreckedAgo): string
		return Rules.activity(
			{ driving = driving, menu = menu, idle = idle, wreckedAgo = wreckedAgo },
			Cfg
		)
	end
	check("left while driving", act(true, false, false, nil) == "Driving")
	check("left on foot", act(false, false, false, nil) == "OnFoot")
	check("left in a menu (even in the car)", act(true, true, false, nil) == "Menu")
	check("left idle", act(true, false, true, nil) == "Idle")
	check("left just wrecked beats everything", act(true, true, true, 3) == "Wrecked")
	check(
		"a wreck long ago doesn't count",
		act(true, false, false, Cfg.WreckedSeconds + 1) == "Driving"
	)

	check("driving: in the driver seat", Rules.wasDriving(true, nil, Cfg))
	check("driving: never sat", not Rules.wasDriving(false, nil, Cfg))
	check("driving: stood up by leaving (car removed)", Rules.wasDriving(false, 0, Cfg))
	check(
		"driving: got out a while ago",
		not Rules.wasDriving(false, Cfg.SeatGraceSeconds + 1, Cfg)
	)

	check("players 1", Rules.countBucket(1, Cfg.PlayerBuckets) == "1")
	check("players 2", Rules.countBucket(2, Cfg.PlayerBuckets) == "2")
	check("players 3", Rules.countBucket(3, Cfg.PlayerBuckets) == "3-4")
	check("players 8", Rules.countBucket(8, Cfg.PlayerBuckets) == "5-8")
	check("players 20", Rules.countBucket(20, Cfg.PlayerBuckets) == "9+")
	check("minutes 0.5", Rules.rangeBucket(0.5, Cfg.MinuteBuckets) == "0-2")
	check("minutes 2", Rules.rangeBucket(2, Cfg.MinuteBuckets) == "2-5")
	check("minutes 90", Rules.rangeBucket(90, Cfg.MinuteBuckets) == "60+")
	check("load 12 s", Rules.rangeBucket(12, Cfg.LoadBuckets) == "10-20")
	check("skip after 12 s", Rules.rangeBucket(12, Cfg.SkipBuckets) == "10-20")
	check("skip after 25 s", Rules.rangeBucket(25, Cfg.SkipBuckets) == "20-40")
	check("skip after 45 s", Rules.rangeBucket(45, Cfg.SkipBuckets) == "40-60")
	check("skip after 300 s", Rules.rangeBucket(300, Cfg.SkipBuckets) == "60+")
	check(
		"skip buckets start where SKIP shows",
		Rules.rangeBucket(Onboarding.SkipAfter, Cfg.SkipBuckets) == "10-20"
	)
	local S = Onboarding.Steps
	check("step name: Hits", Rules.stepName(S.Hits, S) == "Hits")
	check("step name: Smash", Rules.stepName(S.Smash, S) == "Smash")
	check("step name: Goal", Rules.stepName(S.Goal, S) == "Goal")
	check("step name: Buy", Rules.stepName(S.Buy, S) == "Buy")
	check("step name: Event", Rules.stepName(S.Event, S) == "Event")
	check("step name: unknown number", Rules.stepName(1234, S) == "Unknown")
	check("event timeout is its own name", Rules.stepName(S.Event, S) ~= Cfg.EventTimeout)
	-- each bucket list gives few values (Roblox caps distinct field values)
	for _, tops in
		{
			Cfg.PlayerBuckets,
			Cfg.MinuteBuckets,
			Cfg.LoadBuckets,
			Cfg.PlayMinuteBuckets,
			Cfg.SkipBuckets,
		}
	do
		local seen = {}
		for x = 0, 1000 do
			seen[Rules.rangeBucket(x / 2, tops)] = true
			seen[Rules.countBucket(x, tops)] = true
		end
		local n = 0
		for _ in seen do
			n += 1
		end
		check("buckets: a small fixed set", n <= 2 * (#tops + 1))
	end

	check("oneOf: a listed sheet", Rules.oneOf(Cfg.Sheets, "Store"))
	check("oneOf: free text is refused", not Rules.oneOf(Cfg.Sheets, "hello"))
	check("oneOf: a number is refused", not Rules.oneOf(Cfg.Sheets, 3))
	check("seconds: ok", Rules.seconds(7.5, Cfg.MaxLoadSeconds) == 7.5)
	check("seconds: NaN refused", Rules.seconds(0 / 0, Cfg.MaxLoadSeconds) == nil)
	check("seconds: negative refused", Rules.seconds(-1, Cfg.MaxLoadSeconds) == nil)
	check("seconds: huge refused", Rules.seconds(1e9, Cfg.MaxLoadSeconds) == nil)
	check("seconds: text refused", Rules.seconds("5", Cfg.MaxLoadSeconds) == nil)

	check(
		"first car: only the starter owned",
		Rules.firstBought({ Hatchback = true }, "Hatchback", {})
	)
	check(
		"first car: a pass car doesn't count",
		Rules.firstBought({ Hatchback = true, Roadster = true }, "Hatchback", { Roadster = true })
	)
	check(
		"first car: a bought car does",
		not Rules.firstBought({ Hatchback = true, Scooter = true }, "Hatchback", {})
	)

	local bucket = { tokens = Cfg.TrackBurst, at = 0 }
	local passed = 0
	for _ = 1, 100 do
		if Rules.take(bucket, 0, Cfg) then
			passed += 1
		end
	end
	check("track: a burst lets TrackBurst through", passed == Cfg.TrackBurst)
	check("track: empty right after", not Rules.take(bucket, 0, Cfg))
	check("track: refills over time", Rules.take(bucket, 2 / Cfg.TrackPerSecond, Cfg))
	check(
		"track: never above the burst",
		(function()
			local b = { tokens = 0, at = 0 }
			Rules.take(b, 1e6, Cfg)
			return b.tokens <= Cfg.TrackBurst
		end)()
	)
	check("analytics: idle is longer than a state check", Cfg.IdleSeconds > Cfg.StateCheckSeconds)

	-- car progression
	check("cars: count", Rules.carCount({ Hatchback = true, Scooter = true, Sedan = false }) == 2)
	check("cars: count none", Rules.carCount({}) == 0)
	check("cars: bucket 1", Rules.countBucket(1, Cfg.CarBuckets) == "1")
	check("cars: bucket 4-5", Rules.countBucket(4, Cfg.CarBuckets) == "4-5")
	check("cars: bucket 9+", Rules.countBucket(13, Cfg.CarBuckets) == "9+")
	local list = {
		{ id = "Hatchback", price = 0 },
		{ id = "Scooter", price = 200 },
		{ id = "Cart", price = 400 },
		{ id = "Roadster", price = 1000000 },
	}
	local nxt = Rules.nextCar(list, { Hatchback = true })
	check("next car: cheapest unowned", nxt ~= nil and nxt.id == "Scooter")
	nxt = Rules.nextCar(list, { Hatchback = true, Scooter = true, Cart = true })
	check("next car: the Roadster last", nxt ~= nil and nxt.id == "Roadster")
	check(
		"next car: a free car is never next",
		Rules.nextCar(list, { Scooter = true, Cart = true, Roadster = true }) == nil
	)
	check(
		"next car: all owned",
		Rules.nextCar(list, { Hatchback = true, Scooter = true, Cart = true, Roadster = true })
			== nil
	)
	local steps = Cfg.ProgressSteps
	local m = Rules.newMilestones(100, 400, 0, steps)
	check("milestones: 25% reached", #m == 1 and m[1] == 25)
	m = Rules.newMilestones(320, 400, 25, steps)
	check("milestones: 50 and 75 at once", #m == 2 and m[1] == 50 and m[2] == 75)
	m = Rules.newMilestones(320, 400, 75, steps)
	check("milestones: none twice", #m == 0)
	m = Rules.newMilestones(500, 400, 75, steps)
	check("milestones: 100% and over", #m == 1 and m[1] == 100)
	check("milestones: zero price", #Rules.newMilestones(10, 0, 0, steps) == 0)
	check("milestones: no cash", #Rules.newMilestones(0, 400, 0, steps) == 0)
	check("milestones: NaN cash", #Rules.newMilestones(0 / 0, 400, 0, steps) == 0)
	check("trial: stages are fixed values", Rules.oneOf(Cfg.TrialStages, "Converted"))
	check(
		"trial: end reasons",
		Rules.oneOf(Cfg.TrialEnds, "Time") and Rules.oneOf(Cfg.TrialEnds, "Left")
	)
	check("trial: end card is an offer", Rules.oneOf(Cfg.Offers, "Trial"))
end
