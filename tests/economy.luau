--!strict
-- The car economy (Config/Vehicles prices and `pay`, Config/Economy): the price ladder in tiers under the cap,
-- every step up the garage pays more a hit, something to buy every few minutes early on, and the Roadster about
-- 6 hours of play away for a free player. Called from tests/run.

local Challenges = require("../src/shared/Config/Challenges")
local Daily = require("../src/shared/Config/Daily")
local Economy = require("../src/shared/Config/Economy")
local Garage = require("../src/shared/Rules/Garage")
local Onboarding = require("../src/shared/Config/Onboarding")
local Products = require("../src/shared/Config/Products")
local Quests = require("../src/shared/Config/Quests")
local ServerGoals = require("../src/shared/Config/ServerGoals")
local Upgrades = require("../src/shared/Config/Upgrades")
local UpgradeRules = require("../src/shared/Rules/Upgrades")
local Vehicles = require("../src/shared/Config/Vehicles")

-- the model's play assumptions (not game numbers): an average player's hits a minute while hunting, the share
-- of hourly and daily goals they finish, an average player's event pay an hour (about 14 events an hour and an
-- average share of contest prizes, Cash Drop, Money Truck and Boss Truck), the share of server goals they help
-- finish, and one play day for each hour played
local HITS_A_MINUTE = 17
local GOAL_SHARE = 2 / 3
local EVENT_PAY_AN_HOUR = 6000
local SERVER_GOAL_SHARE = 0.5
local MINUTES_A_DAY = 60

return function(check: (string, boolean) -> ())
	local function pay(v: Vehicles.Vehicle): number
		return Garage.hitPay(v.weight, v.topSpeed, Economy.GaragePaySpeedShare, Economy, v.pay)
	end
	local function priceOf(id: string): number
		return Vehicles.ById[id].price
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
		check(`economy: {v.id} costs at most the cap`, v.price <= Economy.PriceCap)
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
	check("economy: the Roadster costs the cap", Vehicles.ById.Roadster.price == Economy.PriceCap)

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

	-- tiers: choices at about the same price, each tier dearer than the last, every paid car in one tier
	-- except the joke rides
	local inTier = {}
	local lastTop = 0
	for i, tier in Economy.Tiers do
		local low, high = math.huge, 0
		for _, id in tier do
			check(`economy: tier car {id} is a vehicle`, Vehicles.ById[id] ~= nil)
			inTier[id] = true
			low, high = math.min(low, priceOf(id)), math.max(high, priceOf(id))
		end
		check(`economy: tier {i}'s cars cost about the same`, high <= low * Economy.TierSpread)
		check(`economy: tier {i} costs more than the tier before`, low > lastTop)
		lastTop = high
	end
	for _, v in Vehicles.List do
		local joke = v.id == "Scooter" or v.id == "Cart"
		check(
			`economy: {v.id} is in a tier (or a free or joke ride)`,
			inTier[v.id] == true or v.price == 0 or joke
		)
		if joke then
			check(
				`economy: joke ride {v.id} costs less than tier 1`,
				v.price < priceOf(Economy.Tiers[1][1])
			)
		end
	end

	-- the targets the ladder was built for: the Muscle Car about $35 a hit, the Roadster about $75
	local muscle, roadster = pay(Vehicles.ById.Muscle), pay(Vehicles.ById.Roadster)
	check("economy: the Muscle Car pays about $35 a hit", muscle >= 30 and muscle <= 40)
	check("economy: the Roadster pays about $75 a hit", roadster >= 65 and roadster <= 85)
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

	local tutorialCash = Onboarding.FinishBonus + Onboarding.HitsReward
	for _, reward in Onboarding.Rewards do
		tutorialCash += reward
	end
	local rookiePrice = priceOf(Economy.RookieUntil)
	check(
		"economy: the tutorial's rewards and finish bonus buy the rookie car",
		tutorialCash >= rookiePrice
	)

	-- one player's run along a path (one car a tier), a minute at a time. hitsOnly: only hit pay, buying the
	-- path's next car once affordable, else the car's next upgrade once its mastery opens it and it's affordable;
	-- returns the minutes of every purchase. Otherwise the full day (goals, events, streak and the first
	-- upgrade of each car bought) until the last car; returns the minute each car was bought.
	local function run(
		cars: { string },
		hitsOnly: boolean,
		untilMinute: number
	): ({ number }, { [string]: number })
		local step = 1 / 12
		local cash, best, minute, rookie = tutorialCash, starter, 0, true
		local points, car, nextCar, nextUp = 0, Vehicles.Starter, 1, 1
		local bought, buys = {}, {}
		local function avg(templates: { Quests.Template }): number
			local sum = 0
			for _, t in templates do
				sum += (t.min + t.max) / 2 * t.perUnit
			end
			return sum / #templates
		end
		local chest = 0
		for _, c in Challenges.Chests.Daily.Cash do
			chest += c.amount * c.weight / 100
		end
		chest *= 1 - Challenges.Chests.Daily.PaintChance
		local perMinute = 0
		if not hitsOnly then
			local hourly = avg(Quests.Hourly.Templates) * Quests.Hourly.Count * GOAL_SHARE
			local daily = avg(Quests.Daily.Templates) * Quests.Daily.Count * GOAL_SHARE + chest
			local serverGoals = ServerGoals.Reward
				* SERVER_GOAL_SHARE
				* 3600
				/ (ServerGoals.Seconds + ServerGoals.Pause)
			perMinute = (hourly + EVENT_PAY_AN_HOUR + serverGoals) / 60 + daily / MINUTES_A_DAY
		end
		local day = 0
		while minute < untilMinute and nextCar <= #cars do
			if not hitsOnly and minute >= day * MINUTES_A_DAY then
				day += 1
				cash += Daily.StreakRewards[math.min(day, #Daily.StreakRewards)]
			end
			if rookie and cash >= rookiePrice then
				rookie = false
			end
			local rate = HITS_A_MINUTE * best * (if rookie then Economy.RookieMultiplier else 1)
				+ perMinute
			cash += rate * step
			points += HITS_A_MINUTE * Upgrades.Points.Npc * step
			minute += step
			local id = cars[nextCar]
			if cash >= priceOf(id) then
				cash -= priceOf(id)
				bought[id] = minute
				table.insert(buys, minute)
				car, best, points, nextCar, nextUp = id, pay(Vehicles.ById[id]), 0, nextCar + 1, 1
				rookie = rookie and priceOf(id) < rookiePrice
				if not hitsOnly and id ~= "Roadster" then
					cash -= UpgradeRules.price(id, priceOf(id), 1)
				end
			elseif hitsOnly and nextUp <= #Upgrades.UpgradeLevel then
				local opens = Upgrades.Levels[Upgrades.UpgradeLevel[nextUp]]
				local cost = UpgradeRules.price(car, priceOf(car), nextUp)
				if points >= opens and cash >= cost then
					cash -= cost
					table.insert(buys, minute)
					nextUp += 1
				end
			end
		end
		return buys, bought
	end
	local cheap, dear = {}, {}
	for _, tier in Economy.Tiers do
		local low, high = tier[1], tier[1]
		for _, id in tier do
			if priceOf(id) < priceOf(low) then
				low = id
			end
			if priceOf(id) > priceOf(high) then
				high = id
			end
		end
		table.insert(cheap, low)
		table.insert(dear, high)
	end

	-- early on (hits alone, the first three tiers' cars and their upgrades) something to buy every 10 minutes
	for name, cars in { cheap = cheap, dear = dear } do
		local first = { cars[1], cars[2], cars[3] }
		local buys = run(first, true, 180)
		local gap, last = 0, 0
		for _, m in buys do
			gap, last = math.max(gap, m - last), m
		end
		check(`economy: early {name} path buys all three cars`, #buys >= 3)
		check(
			`economy: early {name} path buys something every 10 minutes ({string.format("%.1f", gap)} min)`,
			gap <= 10
		)
	end

	-- the Roadster: about 6 hours of play for a free player, along either path
	for name, cars in { cheap = cheap, dear = dear } do
		local _, bought = run(cars, false, 12 * 60)
		local hours = (bought.Roadster or math.huge) / 60
		check(
			`economy: {name} path reaches the Roadster in about 6 hours ({string.format(
				"%.1f",
				hours
			)} h)`,
			hours >= 5.5 and hours <= 6.5
		)
	end

	check(
		"economy: the starter pack's cash doesn't buy the car before the Roadster",
		Products.Starter.money < path[#path - 1].price
	)
	-- no cash pack buys the Roadster outright (the Roadster pass stays the way to skip it)
	for _, pack in Products.MoneyPacks do
		check(
			`economy: {pack.key} doesn't buy the Roadster`,
			pack.money < Vehicles.ById.Roadster.price
		)
	end

	-- upgrade prices: no car's upgrades cost more than the Roadster's
	local roadsterTop = UpgradeRules.price("Roadster", Vehicles.ById.Roadster.price, 3)
	for _, v in Vehicles.List do
		check(
			`economy: {v.id} upgrades cost no more than the Roadster's`,
			UpgradeRules.price(v.id, v.price, 3) <= roadsterTop
		)
	end
end
