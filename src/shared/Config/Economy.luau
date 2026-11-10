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
	RookieUntil = "Sedan", -- ...until they own this vehicle or one at least as expensive
	MinHitSpeed = 6.7, -- m/s (15 mph): slower bumps don't count
	CannonShare = 0.5, -- fire-truck cannon knockdowns pay this share
	DoubleMoney = 2,
	LikeReward = 5000,
	RoadsterPassMoney = 1000000,
	SelfDestructCooldown = 20,
	NoHitWindow = 3, -- seconds after a spawn or a hit when Wrecker can't hit you again
	AutosaveSeconds = 60,
	-- game pass ids; 0 until the passes exist on the Creator Hub. In Studio the shop toggles them for testing.
	Passes = table.freeze({
		Roadster = 0,
		Wrecker = 0,
		DoubleMoney = 0,
	}),
})
