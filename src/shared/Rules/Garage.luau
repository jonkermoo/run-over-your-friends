--!strict
-- What the garage cards say about a car beyond its stat bars: about what one hit on a person pays, whether it
-- can bring a whole building down, and which car is NEXT UP. Pure, so Lune tests it.

local Impact = if typeof(script) == "Instance"
	then require(script.Parent.Impact)
	else require("./Impact")

local Garage = {}

local MPH = 0.44704 -- metres a second in one mph

-- about what one hit on a person pays (no combo, no boosts), at `share` of the car's top speed, to the dollar
function Garage.hitPay(
	weightKg: number,
	topSpeedMph: number,
	share: number,
	economy: Impact.PayoutConfig
): number
	local speed = topSpeedMph * share * MPH
	local pay = Impact.npcPayout(Impact.energy(weightKg, speed), 1, economy)
	return math.floor(pay + 0.5)
end

-- can it bring a whole building down, flat out?
function Garage.topples(
	weightKg: number,
	topSpeedMph: number,
	smash: Impact.SmashConfig,
	maxBreak: number?
): boolean
	return Impact.collapses(weightKg, topSpeedMph * MPH, smash, maxBreak)
end

-- the car to save for: the cheapest one not owned that costs more than the cash in hand and at least
-- minPrice (so cheap joke rides that are a step down aren't pushed); skip: ones that aren't bought with cash,
-- like a pass car. nil when every car is owned or affordable.
function Garage.nextUp(
	list: { { id: string, price: number } },
	owned: { [string]: boolean },
	cash: number,
	priceOf: (string) -> number,
	skip: { [string]: boolean },
	minPrice: number?
): string?
	local best, bestPrice = nil, math.huge
	for _, v in list do
		local price = priceOf(v.id)
		if
			not owned[v.id]
			and not skip[v.id]
			and v.price >= (minPrice or 0)
			and price > cash
			and price < bestPrice
		then
			best, bestPrice = v.id, price
		end
	end
	return best
end

return Garage
