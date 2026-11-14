--!strict
-- Starter Pack offer checks (Rules/Offer, Config/Products), called from tests/run.

local Products = require("../src/shared/Config/Products")
local Vehicles = require("../src/shared/Config/Vehicles")

return function(check: (string, boolean) -> ())
	local Offer = require("../src/shared/Rules/Offer")
	local S, D = Products.Starter, Products.StarterDeal
	local carsOk = #(S.vehicles or {}) > 0
	for _, id in S.vehicles or {} do
		carsOk = carsOk and Vehicles.ById[id] ~= nil
	end
	check("starter pack is once and its vehicles exist", S.once and D.once and carsOk)
	local same = S.money == D.money and #(S.vehicles or {}) == #(D.vehicles or {})
	for i, id in S.vehicles or {} do
		same = same and (D.vehicles or {})[i] == id
	end
	check(
		"the starter deal is the same pack, cheaper, sharing its one-time key",
		same
			and D.deal == true
			and D.robux < S.robux
			and Offer.onceKey(D) == S.key
			and Offer.onceKey(S) == S.key
	)
	check("starter deal window is positive", Products.StarterDealSeconds > 0)
	check("StarterUntil is a vehicle", Vehicles.ById[Products.StarterUntil] ~= nil)
	local prices = {}
	for _, v in Vehicles.List do
		prices[v.id] = v.price
	end
	check(
		"starter pack worth: cash + Muscle + Bulldozer",
		Offer.worth(S, prices) == 275000 + 25000 + 100000
	)
	check(
		"worth ignores unknown vehicles",
		Offer.worth(
			{ key = "x", money = 5, vehicles = { "Nope" }, robux = 1, once = false },
			prices
		) == 5
	)
	-- the best cash rate is the Money Truck's ~2,007 $/R$: 400k for 49 R$ is 4.1x, for 99 R$ 2.0x
	local worth = Offer.worth(S, prices)
	check("deal value times", Offer.valueTimes(worth, D.robux, Products.MoneyPacks) == 4)
	check("full value times", Offer.valueTimes(worth, S.robux, Products.MoneyPacks) == 2)
	check("value times is at least 1", Offer.valueTimes(10, 99, Products.MoneyPacks) == 1)
	check(
		"value times with no packs",
		Offer.valueTimes(10, 99, {}) == 1 and Offer.valueTimes(10, 0, Products.MoneyPacks) == 1
	)
	check(
		"both starter offers beat every cash pack",
		Offer.valueTimes(worth, S.robux, Products.MoneyPacks) >= 2
	)
	check("99 -> 49 is 50% off (never overstated)", Offer.percentOff(99, 49) == 50)
	check(
		"percent off edge cases",
		Offer.percentOff(99, 99) == 0
			and Offer.percentOff(0, 10) == 0
			and Offer.percentOff(100, 0) == 100
			and Offer.percentOff(100, 120) == 0
	)
	check(
		"deal fresh, open, over",
		Offer.dealState(0, 50) == "fresh"
			and Offer.dealState(100, 99) == "open"
			and Offer.dealState(100, 100) == "over"
			and Offer.dealState(100, 500) == "over"
	)
	check(
		"clock",
		Offer.clock(1800) == "30:00"
			and Offer.clock(59.2) == "1:00"
			and Offer.clock(0) == "0:00"
			and Offer.clock(-5) == "0:00"
			and Offer.clock(3723) == "1:02:03"
	)
	local until_ = prices[Products.StarterUntil]
	check(
		"eligible near the start",
		Offer.eligible({ "Hatchback", "Sedan", "Taxi" }, prices, until_)
	)
	check(
		"not eligible with a Muscle Car",
		not Offer.eligible({ "Hatchback", "Muscle" }, prices, until_)
	)
	check("not eligible with a dearer car", not Offer.eligible({ "Supercar" }, prices, until_))
	check("eligible ignores unknown ids", Offer.eligible({ "", "Nope" }, prices, until_))
	check(
		"full pack sells any time until bought",
		Offer.mayBuy(S, {}, 0, 10)
			and Offer.mayBuy(S, {}, 5, 10)
			and not Offer.mayBuy(S, { Starter = true }, 0, 10)
	)
	check(
		"deal sells only while open",
		not Offer.mayBuy(D, {}, 0, 10)
			and Offer.mayBuy(D, {}, 20, 10)
			and not Offer.mayBuy(D, {}, 10, 10)
	)
	check("deal not after the pack was bought", not Offer.mayBuy(D, { Starter = true }, 20, 10))
	check("pack not after the deal was bought", not Offer.mayBuy(S, { Starter = true }, 0, 10))
end
