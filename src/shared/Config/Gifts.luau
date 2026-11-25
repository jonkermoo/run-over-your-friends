--!strict
-- Play-time gifts: a gift opens at each of these minutes of play in one session (server join to leave), claimed
-- with one tap, in order. A paint prize the player already owns pays its cash instead. Rules/Gifts.
-- Sized against hit pay (tests/gifts): each cash prize, or a paint's cash, is between ShareMin and ShareMax of
-- what the starter car earns by that minute at one hit every HitEvery seconds. Amounts are on the halved economy
-- (dev/car-prices, 2026-11-25): they pass the share check at both the old and the halved hit pay.

export type Prize = { cash: number, paint: string? }

return table.freeze({
	Minutes = table.freeze({ 5, 10, 15, 20 }), -- one every 5 minutes
	Prizes = table.freeze({
		table.freeze({ cash = 250 }),
		table.freeze({ cash = 500 }),
		table.freeze({ cash = 1250, paint = "Pink" }), -- Hot Pink, a shop paint (cash = half its old $2,500 price)
		table.freeze({ cash = 2000, paint = "Chrome" }), -- the rare one: a chest-only paint
	} :: { Prize }),
	Slack = 3, -- seconds the server allows a claim early (clocks and the tap's trip)
	HitEvery = 4,
	ShareMin = 0.1,
	ShareMax = 0.5,
})
