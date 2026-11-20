--!strict
-- The leaderboards, the champions' podium and their rules (Config/Leaderboards, Config/Champions,
-- Rules/Leaderboards, World.SpawnPlaza.Podium), called from tests/run.

local LbConfig = require("../src/shared/Config/Leaderboards")
local Lb = require("../src/shared/Rules/Leaderboards")
local World = require("../src/shared/Config/World")

return function(check: (string, boolean) -> ())
	local Champ = require("../src/shared/Config/Champions")
	local P = World.SpawnPlaza.Podium
	local byKey = {}
	for _, b in LbConfig.Boards do
		byKey[b.key] = b
	end
	local stepsOk = #Champ.Steps == #P.Keys and #P.Keys == #P.Heights and #P.Keys == #P.Colours
	for i, step in Champ.Steps do
		stepsOk = stepsOk
			and step.key == P.Keys[i]
			and byKey[step.key] ~= nil
			and Champ.Poses[step.pose] ~= nil
	end
	check("podium: steps match the map's steps, a board and a pose each", stepsOk)
	check(
		"podium: the middle step is the tallest",
		P.Heights[2] > P.Heights[1] and P.Heights[2] > P.Heights[3]
	)
	local R15 = {
		Neck = true,
		Waist = true,
		RightShoulder = true,
		LeftShoulder = true,
		RightElbow = true,
		LeftElbow = true,
		RightWrist = true,
		LeftWrist = true,
		RightHip = true,
		LeftHip = true,
		RightKnee = true,
		LeftKnee = true,
		RightAnkle = true,
		LeftAnkle = true,
	}
	local posesOk = true
	for _, joints in Champ.Poses do
		for name, j in joints do
			posesOk = posesOk and R15[name] == true
			for _, deg in { j.x or 0, j.y or 0, j.z or 0 } do
				posesOk = posesOk and math.abs(deg) <= 180
			end
		end
	end
	check("podium: poses only bend R15 joints, by at most 180 degrees", posesOk)
	check("podium: turns, slowly", Champ.TurnSeconds >= 30 and Champ.Scale > 1 and Champ.Scale < 4)

	local perStand, keys, ok = {}, {}, true
	for _, b in LbConfig.Boards do
		ok = ok and not keys[b.key] and b.stand >= 1 and b.stand <= LbConfig.Stands and b.tag ~= ""
		keys[b.key] = true
		perStand[b.stand] = (perStand[b.stand] or 0) + 1
	end
	for n = 1, LbConfig.Stands do
		ok = ok and (perStand[n] or 0) >= 1
	end
	check("boards: unique keys, every stand used, each board on a stand", ok)
	check(
		"boards: show 10, read up to 100 (one page)",
		LbConfig.Top == 10 and LbConfig.ReadTop <= 100
	)

	-- all-time money
	local st = Lb.fresh(1)
	check("earned: none until seeded", Lb.value(st, "Earned") == 0)
	check(
		"earned: seed is money held plus cars owned",
		Lb.earnedSeed(250.7, { 0, 200, 3000 }) == 3450
	)
	check("earned: seed ignores bad numbers", Lb.earnedSeed(0 / 0, { -5, 0 / 0, 100 }) == 100)
	check(
		"earned: adds up",
		Lb.record(st, "Earned", 40)
			and Lb.record(st, "Earned", 2.5)
			and Lb.value(st, "Earned") == 42.5
	)
	check(
		"earned: bad amounts ignored",
		not Lb.record(st, "Earned", -1) and not Lb.record(st, "Earned", 0 / 0)
	)
	check("earned: a new week keeps it", Lb.roll(st, 2) and Lb.value(st, "Earned") == 42.5)

	-- hidden players
	local seen = Lb.visible({
		{ userId = 1, name = "a", value = 3 },
		{ userId = 2, name = "b", value = 2 },
	}, { [1] = true })
	check("hidden players are left off", #seen == 1 and seen[1].userId == 2)

	-- your own row
	local list = {
		{ userId = 10, name = "a", value = 90 },
		{ userId = 11, name = "b", value = 50 },
		{ userId = 12, name = "c", value = 50 },
	}
	local top = Lb.you(list, 10, 90, 100)
	check("you: #1 has no gap", top.rank == 1 and top.gap == nil)
	local second = Lb.you(list, 11, 50, 100)
	check("you: #2 needs to beat #1", second.rank == 2 and second.gap == 41)
	local third = Lb.you(list, 12, 50, 100)
	check(
		"you: a tie goes to the lower id, and passing it takes 1 more",
		third.rank == 3 and third.gap == 1
	)
	local fresh = Lb.you(list, 99, 60, 100)
	check("you: not listed yet still gets a place", fresh.rank == 2 and fresh.gap == 31)
	local low = Lb.you(list, 99, 5, 3)
	check("you: past the read places there's no rank", low.rank == nil and low.value == 5)
	local none = Lb.you(list, 99, 0, 100)
	check("you: no score, no rank", none.rank == nil and none.value == 0)
end
