--!strict
-- Building smashing: every vehicle breaks building pieces once its hit is hard enough. Hit energy is
-- 0.5 * weight (kg) * speed (m/s)^2, so light vehicles need speed and heavy ones break even when slow.
-- Plain numbers only (Rules/Impact.smashRadius reads them).

return table.freeze({
	EnergyLow = 8000, -- joules: softer hits only bump (a Cart needs about 32 of its 40 mph)
	EnergyHigh = 15000000, -- joules: hits this hard break the most
	MinRadius = 3, -- studs: a hit just over EnergyLow chips about one piece
	MaxRadius = 28, -- studs
	-- studs: smaller breaks leave what stands above them up (a light car makes a hole); bigger ones drop the
	-- rest of the storey above the hit, never past a floor slab (slabs and roofs are Fixed and never break)
	FloorsFallFrom = 10,
	MinSpeed = 6.7, -- m/s (15 mph): slower bumps break nothing, however heavy (matches Economy.MinHitSpeed)
	Curve = 2, -- above 1 keeps light and mid hits small and saves the big radii for heavy, fast ones
	-- walls push back: each break takes this many joules out of the car, so light or slow cars lose most of
	-- their speed and heavy, fast ones plough on
	WallEnergy = 2000000,
	-- share of its speed a car always keeps after a break, growing with weight (log scale) so heavy vehicles
	-- plough through: a light car rolls into the hole, a bulldozer barely notices
	KeptLight = 0.2,
	KeptLightWeight = 1000, -- kg: this light or lighter keeps KeptLight
	KeptHeavy = 0.92,
	KeptHeavyWeight = 20000, -- kg: this heavy or heavier keeps KeptHeavy
})
