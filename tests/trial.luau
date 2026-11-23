--!strict
-- Roadster free trial checks (Config/Trial, Rules/Trial), called from tests/run.

local Cfg = require("../src/shared/Config/Trial")
local Economy = require("../src/shared/Config/Economy")
local Rules = require("../src/shared/Rules/Trial")
local Vehicles = require("../src/shared/Config/Vehicles")

return function(check: (string, boolean) -> ())
	check("trial: the car exists", Vehicles.ById[Cfg.Car] ~= nil)
	check("trial: the car has a pass", (Economy.Passes :: any)[Cfg.Car] ~= nil)
	check("trial: warning inside the trial", Cfg.WarnSeconds > 0 and Cfg.WarnSeconds < Cfg.Seconds)
	check("trial: 3 minutes", Cfg.Seconds == 180)
	check("trial: once a day", Cfg.CooldownSeconds == 86400)
	check("trial: lands within 5 s", Cfg.LandWaitSeconds == 5)

	local now = 1_800_000_000
	local function facts(over: { [string]: any }): Rules.Facts
		local f: any =
			{ tutorialDone = true, ownsCar = false, lastAt = 0, now = now, active = false }
		for k, v in over do
			f[k] = v
		end
		return f
	end
	check("trial: a first trial", Rules.problem(facts({}), Cfg) == nil)
	check(
		"trial: not before the tutorial is done",
		Rules.problem(facts({ tutorialDone = false }), Cfg) == "Tutorial"
	)
	check("trial: not for owners", Rules.problem(facts({ ownsCar = true }), Cfg) == "Owned")
	check("trial: not twice at once", Rules.problem(facts({ active = true }), Cfg) == "Active")
	check(
		"trial: not again inside 24 h",
		Rules.problem(facts({ lastAt = now - 86399 }), Cfg) == "Cooldown"
	)
	check("trial: again after 24 h", Rules.problem(facts({ lastAt = now - 86400 }), Cfg) == nil)
	check("trial: next at", Rules.nextAt(100, Cfg) == 100 + 86400 and Rules.nextAt(0, Cfg) == 0)

	check("clock: runs in the seat", Rules.tick(180, 1, true) == 179)
	check("clock: stops out of the seat", Rules.tick(180, 1, false) == 180)
	check("clock: never below zero", Rules.tick(0.5, 1, true) == 0)
	check(
		"clock: ignores a bad dt",
		Rules.tick(10, 0 / 0, true) == 10 and Rules.tick(10, -1, true) == 10
	)
	check(
		"chip: rounds up",
		Rules.shown(179.2) == 180 and Rules.shown(0.01) == 1 and Rules.shown(0) == 0
	)
	check("chip: whole numbers stay", Rules.shown(15) == 15)
	check("warn: once at the mark", Rules.warnNow(15.2, 14.9, Cfg))
	check("warn: not before", not Rules.warnNow(16, 15.5, Cfg))
	check("warn: not after", not Rules.warnNow(14, 13, Cfg))

	check("swap: not while time is left", not Rules.swapNow(1, true, true, 0, Cfg))
	check("swap: on the ground", Rules.swapNow(0, true, true, 0, Cfg))
	check("swap: waits in the air", not Rules.swapNow(0, true, false, 4.9, Cfg))
	check("swap: no longer than 5 s", Rules.swapNow(0, true, false, 5, Cfg))
	check("swap: at once out of the car", Rules.swapNow(0, false, false, 0, Cfg))

	check("convert: within 7 days", Rules.converted(now, now + 6 * 86400, Cfg))
	check("convert: not after 7 days", not Rules.converted(now, now + 7 * 86400 + 1, Cfg))
	check("convert: no trial", not Rules.converted(0, now, Cfg))
	check("convert: not before the trial", not Rules.converted(now, now - 10, Cfg))

	check("bar: half", Rules.progress(500000, 1000000) == 0.5)
	check("bar: clamps", Rules.progress(2e6, 1e6) == 1 and Rules.progress(-5, 1e6) == 0)
	check("bar: free car", Rules.progress(0, 0) == 1)
end
