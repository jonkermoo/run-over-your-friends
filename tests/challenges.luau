--!strict
-- Daily and weekly challenge checks (Config/Challenges, Rules/Challenges, the chest paints in Rules/Paints),
-- called from tests/run.

local Cfg = require("../src/shared/Config/Challenges")
local PaintConfig = require("../src/shared/Config/Paints")
local Vehicles = require("../src/shared/Config/Vehicles")

return function(check: (string, boolean) -> ())
	local C = require("../src/shared/Rules/Challenges")
	local PaintRules = require("../src/shared/Rules/Paints")

	-- dates: days are UTC days, weeks start Monday 00:00 UTC
	local mon = 1763337600 -- 2025-11-17 00:00 UTC, a Monday
	check(
		"challenges: a week starts on Monday",
		C.week(mon, Cfg) == C.week(mon + 6 * 86400 + 86399, Cfg)
	)
	check("challenges: Sunday night is last week", C.week(mon - 1, Cfg) == C.week(mon, Cfg) - 1)
	check(
		"challenges: the week ends next Monday",
		C.weekEnds(C.week(mon, Cfg), Cfg) == mon + 7 * 86400
	)
	local d = C.day(mon + 3600, Cfg)
	check("challenges: the day ends at midnight UTC", C.dayEnds(d, Cfg) == mon + 86400)

	-- the same date gives the same challenges; most days differ
	local a, b = C.daily(d, Cfg), C.daily(d, Cfg)
	local same = #a == #b
	for i in a do
		same = same and a[i].id == b[i].id and a[i].target == b[i].target and a[i].car == b[i].car
	end
	check("challenges: the same day gives the same three", same and #a == #Cfg.Daily.Slots)
	local shapes, cars, targetsOk, carsOk, textOk = {}, {}, true, true, true
	local kinds = 0
	for day = d, d + 199 do
		local list = C.daily(day, Cfg)
		local key = {}
		for s, c in list do
			table.insert(key, `{c.id}{c.target}`)
			local tpl
			for _, t in Cfg.Daily.Slots[s] do
				if t.id == c.id then
					tpl = t
				end
			end
			targetsOk = targetsOk
				and tpl ~= nil
				and c.target >= tpl.min
				and c.target <= tpl.max
				and (c.target - tpl.min) % tpl.step == 0
			if c.car then
				cars[c.car] = true
				carsOk = carsOk and table.find(Cfg.Cars, c.car) ~= nil
			end
			textOk = textOk and not string.find(c.text, "{", 1, true)
		end
		local k = table.concat(key, ",")
		if not shapes[k] then
			shapes[k] = true
			kinds += 1
		end
	end
	check("challenges: targets inside each template's range", targetsOk)
	check("challenges: text filled in", textOk)
	check("challenges: car challenges name only the cheap cars", carsOk)
	check("challenges: every cheap car comes up", #Cfg.Cars == (function()
		local n = 0
		for _ in cars do
			n += 1
		end
		return n
	end)())
	check("challenges: 200 days give many different sets", kinds > 60)
	local cheap = true
	for _, id in Cfg.Cars do
		cheap = cheap and Vehicles.ById[id] ~= nil and Vehicles.ById[id].price <= 3000
	end
	check("challenges: the named cars exist and cost $3,000 or less", cheap)
	local weeks = {}
	for w = 0, 49 do
		weeks[C.weekly(w, Cfg)[1].id] = true
	end
	local weekKinds = 0
	for _ in weeks do
		weekKinds += 1
	end
	check("challenges: every weekly template comes up", weekKinds == #Cfg.Weekly)
	local ids = {}
	local idsOk = true
	for _, slot in Cfg.Daily.Slots do
		for _, t in slot do
			idsOk = idsOk and not ids[t.id]
			ids[t.id] = true
		end
	end
	for _, t in Cfg.Weekly do
		idsOk = idsOk and not ids[t.id]
		ids[t.id] = true
	end
	check("challenges: template ids are unique", idsOk)

	-- named car text
	local list = C.daily(d, Cfg, function(id)
		return "<" .. id .. ">"
	end)
	local named = true
	for _, c in list do
		if c.car then
			named = string.find(c.text, "<" .. c.car .. ">", 1, true) ~= nil
		end
	end
	check("challenges: the car's name goes in the text", named)

	-- progress
	local hits: C.Challenge =
		{ id = "H", kind = "Hits", mode = "add", text = "", target = 5, car = "Scooter" }
	local combo: C.Challenge = { id = "C", kind = "Combo", mode = "max", text = "", target = 6 }
	local prog: C.Progress = { period = 1, progress = {}, done = {} }
	local cl = { hits, combo }
	check(
		"progress: wrong car doesn't count",
		#C.advance(cl, prog, "Hits", 3, "Sedan") == 0 and prog.progress.H == nil
	)
	check(
		"progress: on foot doesn't count for a car one",
		#C.advance(cl, prog, "Hits", 3, nil) == 0
	)
	C.advance(cl, prog, "Hits", 3, "Scooter")
	check("progress: adds up", prog.progress.H == 3)
	local fin = C.advance(cl, prog, "Hits", 4, "Scooter")
	check(
		"progress: finishes once, capped at the target",
		#fin == 1 and prog.done.H and prog.progress.H == 5
	)
	check("progress: no more after done", #C.advance(cl, prog, "Hits", 4, "Scooter") == 0)
	C.advance(cl, prog, "Combo", 4, nil)
	C.advance(cl, prog, "Combo", 2, nil)
	check("progress: max keeps the best", prog.progress.C == 4 and not prog.done.C)
	check(
		"progress: any car counts for a car-free one",
		#C.advance(cl, prog, "Combo", 7, "Semi") == 1
	)
	check(
		"progress: zero, negative and NaN do nothing",
		#C.advance(cl, prog, "Hits", 0 / 0, "Scooter") == 0
			and #C.advance(
					{ combo },
					{ period = 1, progress = {}, done = {} },
					"Combo",
					-3,
					nil
				)
				== 0
	)

	-- saved data
	local fresh = C.clean(nil, 10, 2)
	check(
		"saved: an old profile starts empty",
		fresh.daily.period == 10
			and fresh.weekly.period == 2
			and fresh.chests.Daily == 0
			and fresh.chests.Weekly == 0
	)
	local old = {
		daily = { period = 9, progress = { H = 3 }, done = { H = true } },
		weekly = {
			period = 2,
			progress = { W = 40, X = "bad", Y = 0 / 0 },
			done = { W = false, Z = true },
		},
		chests = { Daily = 3.7, Weekly = -2 },
	}
	local c2 = C.clean(old, 10, 2)
	check(
		"saved: yesterday's progress starts over",
		next(c2.daily.progress) == nil and next(c2.daily.done) == nil
	)
	check(
		"saved: this week's progress kept, bad values dropped",
		c2.weekly.progress.W == 40
			and c2.weekly.progress.X == nil
			and c2.weekly.progress.Y == nil
			and c2.weekly.done.Z
			and not c2.weekly.done.W
	)
	check(
		"saved: unopened chests kept as whole numbers",
		c2.chests.Daily == 3 and c2.chests.Weekly == 0
	)
	check("saved: junk is fine", C.clean("junk", 1, 1).chests.Daily == 0)
	C.addChest(c2, "Daily")
	C.addChest(c2, "Nope")
	check("chests: add one", c2.chests.Daily == 4)
	c2.chests.Weekly = 99
	C.addChest(c2, "Weekly")
	check("chests: capped", c2.chests.Weekly == 99)

	-- chests
	local paints = PaintConfig.ChestIds
	check("paints: six chest-only paints", #paints == 6)
	local hasNone = {}
	local p1 = C.prize("Daily", 0.1, 0.5, paints, hasNone, Cfg)
	check("chest: a low roll gives a paint and no cash", p1.paint ~= nil and p1.cash == 0)
	local p2 = C.prize("Daily", 0.5, 0.5, paints, hasNone, Cfg)
	check("chest: else cash and no paint", p2.paint == nil and p2.cash > 0)
	local all = {}
	for _, id in paints do
		all[id] = true
	end
	local p3 = C.prize("Daily", 0.1, 0.99, paints, all, Cfg)
	check("chest: every paint owned gives cash", p3.paint == nil and p3.cash > 0)
	local w1 = C.prize("Weekly", 0.7, 0.3, paints, hasNone, Cfg)
	check("weekly chest: a paint and cash", w1.paint ~= nil and w1.cash == 10000)
	local w2 = C.prize("Weekly", 0.7, 0.3, paints, all, Cfg)
	check(
		"weekly chest: all paints owned pays more cash",
		w2.paint == nil and w2.cash == Cfg.Chests.Weekly.NoPaintCash
	)
	local only = {
		[paints[1]] = true,
		[paints[2]] = true,
		[paints[3]] = true,
		[paints[4]] = true,
		[paints[5]] = true,
	}
	check(
		"chest: only a paint you don't own",
		C.prize("Weekly", 0.1, 0.1, paints, only, Cfg).paint == paints[6]
	)
	-- the cash weights hold over many rolls
	math.randomseed(11)
	local seen, paintN, n = {}, 0, 20000
	for _ = 1, n do
		local p = C.prize("Daily", math.random(), math.random(), paints, hasNone, Cfg)
		if p.paint then
			paintN += 1
		else
			seen[p.cash] = (seen[p.cash] or 0) + 1
		end
	end
	local weightsOk = math.abs(paintN / n - Cfg.Chests.Daily.PaintChance) < 0.02
	local total = 0
	for _, row in Cfg.Chests.Daily.Cash do
		total += row.weight
	end
	for _, row in Cfg.Chests.Daily.Cash do
		local share = (seen[row.amount] or 0) / (n - paintN)
		weightsOk = weightsOk and math.abs(share - row.weight / total) < 0.02
	end
	check("chest: odds match the weights", weightsOk)
	local odds = C.odds("Daily", Cfg)
	local sum = odds.paint
	for _, row in odds.cash do
		sum += row.share
	end
	check("chest: odds add up to 1", math.abs(sum - 1) < 1e-9)

	-- chest paints: never for sale, kept once won
	local id = paints[1]
	check("chest paint is shut until won", not PaintRules.isOpen({}, id))
	check("chest paint can't be bought", PaintRules.buyProblem(1e9, {}, id) == "chest")
	check("chest paint opens once won", PaintRules.isOpen({ [id] = true }, id))
	local _, kept = PaintRules.clean({ Sedan = id }, { [id] = true })
	check("chest paint survives a profile clean", kept[id] == true)
	local chosen = PaintRules.clean({ Sedan = id }, {})
	check("a chest paint not won is dropped from a car", chosen.Sedan == nil)
end
