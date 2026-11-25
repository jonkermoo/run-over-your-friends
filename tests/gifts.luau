--!strict
-- Play-time gift checks (Rules/Gifts, Config/Gifts) and the "come back tomorrow" line (Rules/Daily.tomorrow),
-- called from tests/run.

local Config = require("../src/shared/Config/Gifts")
local Daily = require("../src/shared/Config/Daily")
local Economy = require("../src/shared/Config/Economy")
local Paints = require("../src/shared/Config/Paints")
local Vehicles = require("../src/shared/Config/Vehicles")
local DailyRules = require("../src/shared/Rules/Daily")
local Garage = require("../src/shared/Rules/Garage")
local Gifts = require("../src/shared/Rules/Gifts")

return function(check: (string, boolean) -> ())
	local M, P = Config.Minutes, Config.Prizes
	local ascending = #M == #P and #M > 0
	for i = 2, #M do
		ascending = ascending and M[i] > M[i - 1] and P[i].cash >= P[i - 1].cash
	end
	check("gifts: one prize per minute mark, both rising", ascending)
	local paintsOk = true
	for _, p in P do
		if p.paint then
			paintsOk = paintsOk and Paints.ById[p.paint] ~= nil
		end
	end
	check("gifts: every prize paint exists", paintsOk)

	-- sized against what the starter car earns by then
	local starter = Vehicles.ById[Vehicles.Starter]
	local pay = Garage.hitPay(
		starter.weight,
		starter.topSpeed,
		Economy.GaragePaySpeedShare,
		Economy,
		starter.pay
	)
	local sized = pay > 0
	for i, m in M do
		local earned = m * 60 / Config.HitEvery * pay
		sized = sized
			and P[i].cash >= earned * Config.ShareMin
			and P[i].cash <= earned * Config.ShareMax
	end
	check("gifts: each prize is a fair share of what the starter car earns by then", sized)

	check(
		"gifts: claimed in order, none after the last",
		Gifts.nextIndex(0, M) == 1
			and Gifts.nextIndex(#M - 1, M) == #M
			and Gifts.nextIndex(#M, M) == nil
	)
	check(
		"gifts: open at their minute (with slack), not before",
		not Gifts.open(1, M[1] * 60 - 10, M, 3)
			and Gifts.open(1, M[1] * 60 - 2, M, 3)
			and Gifts.open(2, M[2] * 60, M, 0)
			and not Gifts.open(#M + 1, 1e9, M, 0)
	)
	check(
		"gifts: the wait counts down to 0",
		Gifts.wait(1, 0, M) == M[1] * 60 and Gifts.wait(1, M[1] * 60 + 5, M) == 0
	)
	local cashFirst, noPaint = Gifts.payout(1, P, {})
	local paintPrize = 0
	for i, p in P do
		if p.paint then
			paintPrize = i
			break
		end
	end
	local _, paint = Gifts.payout(paintPrize, P, {})
	local owned = { [P[paintPrize].paint :: string] = true }
	local cashInstead, none = Gifts.payout(paintPrize, P, owned)
	check(
		"gifts: a paint prize gives the paint, or its cash when already owned",
		cashFirst == P[1].cash
			and noPaint == nil
			and paint == P[paintPrize].paint
			and cashInstead == P[paintPrize].cash
			and none == nil
	)

	-- come back tomorrow: only once today's reward is collected, on the first day
	local R = Daily.StreakRewards
	local d2, pay2 = DailyRules.tomorrow({ day = 10, streak = 1 }, 10, R, 1)
	check("tomorrow: day 1 collected today, so day 2 pays tomorrow", d2 == 2 and pay2 == R[2])
	check(
		"tomorrow: nothing before today's reward, on later days, or for a new player",
		DailyRules.tomorrow({ day = 9, streak = 1 }, 10, R, 1) == nil
			and DailyRules.tomorrow({ day = 10, streak = 3 }, 10, R, 1) == nil
			and DailyRules.tomorrow(nil, 10, R, 1) == nil
	)
end
