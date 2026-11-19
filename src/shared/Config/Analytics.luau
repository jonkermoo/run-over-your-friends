--!strict
-- Analytics tuning (src/server/Analytics, src/client/Track, Rules/Analytics; events listed in docs/ANALYTICS.md).
-- Every field value comes from a small fixed set: Roblox caps how many different values a field may have.

return table.freeze({
	-- client -> server Track messages: a bucket of this many, refilled at TrackPerSecond; extra ones are dropped
	TrackBurst = 20,
	TrackPerSecond = 1,
	-- no input for this long counts as idle (client/Track)
	IdleSeconds = 60,
	-- how often the client looks at menu / idle state, and sends it only when it changed
	StateCheckSeconds = 1,
	-- a player flung by another player's car within this long counts as "just wrecked" when they leave
	WreckedSeconds = 20,
	-- the join is logged when the client says it's ready (with its device); no word by then, it's logged anyway
	ReadyWaitSeconds = 120,
	-- longest load time believed; anything longer is a bad report and dropped
	MaxLoadSeconds = 600,
	-- a phone's or tablet's shorter screen side (in GUI points) under this counts as a phone
	PhoneShortSide = 600,

	-- buckets: a value goes in the first bucket whose top it doesn't pass; past the last top it's "<top>+"
	PlayerBuckets = table.freeze({ 1, 2, 4, 8 }), -- players in the server: 1, 2, 3-4, 5-8, 9+
	MinuteBuckets = table.freeze({ 2, 5, 15, 30, 60 }), -- minutes: 0-2, 2-5, 5-15, 15-30, 30-60, 60+
	LoadBuckets = table.freeze({ 5, 10, 20, 40 }), -- seconds: 0-5, 5-10, 10-20, 20-40, 40+
	PlayMinuteBuckets = table.freeze({ 10, 30, 60, 120, 240 }), -- total minutes played: 0-10 ... 240+

	-- the fixed values the client may send (Rules/Analytics checks them; anything else is ignored)
	Devices = table.freeze({ "Phone", "Tablet", "PC", "Console", "Unknown" }),
	Sheets = table.freeze({ "Store", "Garage" }),
	StoreSections = table.freeze({ "DEALS", "MONEY", "PASSES", "FREE" }),
	Offers = table.freeze({ "Starter", "Upsell" }),
	OfferStages = table.freeze({ "Shown", "Pressed" }),
	States = table.freeze({ "Menu", "Idle", "Active" }),
})
