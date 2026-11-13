--!strict
-- The Starter Pack offer (Config/Products): what it is worth, how it compares with the cash packs, its timed
-- discount window and who it's for. Pure, so Lune tests it.

local Offer = {}

export type Sellable = {
	key: string,
	money: number,
	vehicles: { string }?,
	robux: number,
	once: boolean,
	onceKey: string?,
	deal: boolean?,
}

export type Pack = { money: number, robux: number }

-- the key a one-time buy is saved under; the pack and its deal share one
function Offer.onceKey(product: Sellable): string
	return product.onceKey or product.key
end

-- the cash plus what the vehicles in it cost in the garage
function Offer.worth(product: Sellable, priceById: { [string]: number }): number
	local total = product.money
	for _, id in product.vehicles or {} do
		total += priceById[id] or 0
	end
	return total
end

-- how many times more it gives than the same Robux spent on the best-rate cash pack, rounded down (at least 1)
function Offer.valueTimes(worth: number, robux: number, packs: { Pack }): number
	local best = 0
	for _, pack in packs do
		if pack.robux > 0 then
			best = math.max(best, pack.money / pack.robux)
		end
	end
	if robux <= 0 or best <= 0 then
		return 1
	end
	return math.max(1, math.floor(worth / (robux * best)))
end

-- the discount as a whole percent, rounded down to a multiple of 5 so the card never overstates it
function Offer.percentOff(full: number, deal: number): number
	if full <= 0 or deal >= full then
		return 0
	end
	return math.floor((1 - math.max(deal, 0) / full) * 100 / 5) * 5
end

-- the discount window: "fresh" before it ever started (ends 0), "open" while it runs, "over" for good after
function Offer.dealState(ends: number, now: number): string
	if ends <= 0 then
		return "fresh"
	end
	return if now < ends then "open" else "over"
end

-- seconds left as "29:59" (or "1:02:03" past an hour), rounded up so 0:00 only shows at the end
function Offer.clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	local h, m = s // 3600, (s // 60) % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s % 60)
	end
	return string.format("%d:%02d", m, s % 60)
end

-- still near the start: owns no vehicle priced at or above untilPrice
function Offer.eligible(
	owned: { string },
	priceById: { [string]: number },
	untilPrice: number
): boolean
	for _, id in owned do
		local price = priceById[id]
		if price and price >= untilPrice then
			return false
		end
	end
	return true
end

-- may this product be put up for purchase now
function Offer.mayBuy(
	product: Sellable,
	bought: { [string]: boolean },
	ends: number,
	now: number
): boolean
	if product.once and bought[Offer.onceKey(product)] then
		return false
	end
	return not product.deal or Offer.dealState(ends, now) == "open"
end

return Offer
