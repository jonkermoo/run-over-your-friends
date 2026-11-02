--!strict
-- Daily login streak and the car of the day. Days are UTC days (unix seconds // DaySeconds).

return table.freeze({
	DaySeconds = 86400,
	-- streak day 1, 2, ... 7; every day after the 7th pays the last one
	StreakRewards = table.freeze({ 500, 1000, 1500, 2500, 3500, 5000, 10000 }),
	-- one car a day is this share off; every buyable car gets a day before any repeats
	DiscountShare = 0.25,
	DiscountRound = 10, -- the sale price rounds to this many dollars
	DiscountSkip = table.freeze({ Roadster = true }), -- never on sale (free cars never are either)
	DiscountSalt = 7121,
})
