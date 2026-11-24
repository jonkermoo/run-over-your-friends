--!strict
-- Money, hits, passes. Plain numbers only.

return table.freeze({
	StartMoney = 0,
	-- NPC payout: base + a bonus that grows with impact energy (log scale), times the combo
	NpcBase = 10,
	NpcBonusMax = 50,
	EnergyLow = 30000, -- joules: no bonus at or under this
	EnergyHigh = 10000000, -- joules: full bonus at or over this
	ComboWindow = 3, -- seconds between hits to keep a combo going
	ComboStep = 0.2,
	ComboMax = 3,
	RepeatWindow = 30, -- the same NPC again inside this many seconds pays half
	RookieMultiplier = 2, -- hits on people pay this much more for new players...
	RookieUntil = "Sedan", -- ...until they first hold this vehicle's price in cash or own one at least as dear
	MinHitSpeed = 6.7, -- m/s (15 mph): slower bumps don't count
	GaragePaySpeedShare = 0.5, -- the garage's "about $N a hit" is one hit at this share of the car's top speed
	-- each car's own pay multiplier is Config/Vehicles `pay`. Along the cash cars in price order the garage's
	-- pay a hit always rises (tests/economy), except these side cars that trade pay for something else
	PaySideCars = table.freeze({ "Bulldozer" }), -- slow, but brings whole buildings down
	CannonShare = 0.5, -- fire-truck cannon knockdowns pay this share
	DoubleMoney = 2,
	-- VIP pass: hit cash times this. The money passes multiply: 2x Money alone 2, VIP alone 1.25, both 2.5
	-- (Rules/PassMoney). Covers what 2x Money covers: NPC, giant, traffic and building hits.
	VipMoney = 1.25,
	-- one-time cash for joining the game's Roblox group; 0 = no group yet (the row is hidden live, a test grant in Studio)
	GroupId = 987419590,
	GroupReward = 25000,
	RoadsterPassMoney = 50000, -- a head start, not enough to skip the garage
	AutosaveSeconds = 60,
	-- game pass ids; 0 until the passes exist on the Creator Hub. In Studio the shop toggles them for testing.
	Passes = table.freeze({
		Roadster = 2089071744,
		DoubleMoney = 2089341746,
		VIP = 2087931824, -- 99 R$: gold VIP tag (Config/Vip), VipMoney, the VIP Gold paint (Config/Paints)
	}),
})
