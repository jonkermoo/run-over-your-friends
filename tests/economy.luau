--!strict
-- The car economy (Config/Vehicles prices and `pay`, Config/Economy): every step up the garage pays clearly
-- more a hit, called from tests/run.

local Economy = require("../src/shared/Config/Economy")
local Garage = require("../src/shared/Rules/Garage")
local Onboarding = require("../src/shared/Config/Onboarding")
local Products = require("../src/shared/Config/Products")
local Upgrades = require("../src/shared/Config/Upgrades")
local UpgradeRules = require("../src/shared/Rules/Upgrades")
local Vehicles = require("../src/shared/Config/Vehicles")

return function(check: (string, boolean) -> ())
	local function pay(v: Vehicles.Vehicle): number
		return Garage.hitPay(v.weight, v.topSpeed, Economy.GaragePaySpeedShare, Economy, v.pay)
	end
	local side = {}
	for _, id in Economy.PaySideCars do
		check(`economy: side car {id} is a vehicle`, Vehicles.ById[id] ~= nil)
		side[id] = true
	end

	-- the main path: every car in price order but the side cars; each pays more a hit than the one before
	local path = {}
	for _, v in Vehicles.List do
		check(`economy: {v.id} has a pay multiplier`, v.pay > 0)
		if not side[v.id] then
			table.insert(path, v)
		end
	end
	table.sort(path, function(a, b)
		return a.price < b.price
	end)
	for i = 2, #path do
		local a, b = path[i - 1], path[i]
		check(`economy: {b.id} costs more than {a.id}`, b.price > a.price)
		check(`economy: {b.id} pays more a hit than {a.id}`, pay(b) > pay(a))
	end
	check("economy: the Roadster pays the most a hit", path[#path].id == "Roadster")

	-- the shop order follows the price
	local byOrder = table.clone(Vehicles.List)
	table.sort(byOrder, function(a, b)
		return a.order < b.order
	end)
	for i = 2, #byOrder do
		check(
			`economy: {byOrder[i].id} sits after {byOrder[i - 1].id} in the garage and costs more`,
			byOrder[i].order > byOrder[i - 1].order and byOrder[i].price > byOrder[i - 1].price
		)
	end

	-- the targets the rework was built for: the Muscle Car about $70 a hit, the Roadster about $150
	local muscle, roadster = pay(Vehicles.ById.Muscle), pay(Vehicles.ById.Roadster)
	check("economy: the Muscle Car pays about $70 a hit", muscle >= 60 and muscle <= 80)
	check("economy: the Roadster pays about $150 a hit", roadster >= 130 and roadster <= 170)
	-- no joke ride pays less than the free starter
	local starter = pay(Vehicles.ById[Vehicles.Starter])
	for _, v in Vehicles.List do
		check(`economy: {v.id} pays at least the starter`, pay(v) >= starter)
	end
	-- a side car still pays well, just less than the cars around it
	for id in side do
		check(
			`economy: side car {id} pays more than the Taxi`,
			pay(Vehicles.ById[id]) > pay(Vehicles.ById.Taxi)
		)
	end

	-- the pacing: early on a next car every 15 minutes or less at base pay (17 hits a minute, the rookie boost
	-- until RookieUntil), and never a cheap car out of reach of the tutorial's money
	local hitsAMinute = 17
	local rookie = Vehicles.ById[Economy.RookieUntil].price
	local best = 0
	for i, v in path do
		if i > 1 and v.price <= Vehicles.ById[Products.StarterUntil].price then
			local rate = best
				* hitsAMinute
				* (if v.price <= rookie then Economy.RookieMultiplier else 1)
			local minutes = (v.price - path[i - 1].price) / rate
			check(`economy: {v.id} comes within 15 minutes of the car before`, minutes <= 15)
		end
		best = math.max(best, pay(v))
	end
	local tutorialCash = Onboarding.FinishBonus + Onboarding.HitsReward
	for _, reward in Onboarding.Rewards do
		tutorialCash += reward
	end
	check(
		"economy: the tutorial's rewards and finish bonus buy the rookie car",
		tutorialCash >= rookie
	)
	check(
		"economy: the starter pack's cash doesn't buy the car before the Roadster",
		Products.Starter.money < path[#path - 1].price
	)

	-- upgrade prices: no car's upgrades cost more than the Roadster's
	local roadsterTop = UpgradeRules.price("Roadster", Vehicles.ById.Roadster.price, 3)
	for _, v in Vehicles.List do
		check(
			`economy: {v.id} upgrades cost no more than the Roadster's`,
			UpgradeRules.price(v.id, v.price, 3) <= roadsterTop
		)
	end
	check(
		"economy: the Supercar's upgrades are priced on a basis",
		Upgrades.PriceBasis.Supercar ~= nil
	)
end
