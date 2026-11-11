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
	-- walls push back: a wall takes this many joules out of the car, so light or slow cars lose a good part of
	-- their speed and heavy, fast ones plough on
	WallEnergy = 2000000,
	PassSeconds = 1, -- seconds: one wall slows a car once, however many pieces it goes through in that time
	-- share of its speed a car always keeps after a break, growing with weight (log scale) so heavy vehicles
	-- plough through: a light car rolls on through its hole, a bulldozer barely notices
	KeptLight = 0.55,
	KeptLightWeight = 1000, -- kg: this light or lighter keeps KeptLight
	KeptHeavy = 0.92,
	KeptHeavyWeight = 20000, -- kg: this heavy or heavier keeps KeptHeavy
	-- joules: a hit this hard brings down the whole building (a Muscle needs about 59 mph, a Semi about 20);
	-- vehicles with a maxBreak (Config/Vehicles) only ever make a hole
	CollapseEnergy = 600000,
	CollapseKept = 0.85, -- share of its speed a car keeps going through a building that is coming down
	Collapse = table.freeze({
		StartSeconds = 0.1, -- the lowest storey lets go this long after the hit
		StaggerSeconds = 1.1, -- ...and the top one this much later
		Gravity = 120, -- studs/s^2 the pieces fall at
		BlastRadius = 18, -- studs: pieces this close to the hit are thrown out, the rest drop
		BlastPush = 0.45, -- share of the car's speed the thrown pieces carry on with
		BlastOut = { 20, 45 }, -- studs/s away from the hit
		BlastUp = { 20, 55 }, -- studs/s up
		BlastSpin = { 1.5, 4 }, -- radians/s
		DropOut = { 2, 9 }, -- studs/s the dropping walls spread outward
		DropSpin = { 0.1, 0.5 }, -- radians/s, low so the walls come straight down
		DriftSeconds = 1.2, -- pieces stop moving sideways after this long
		DustEvery = 0.55, -- seconds between waves of dust
		FeelStuds = 500, -- other players closer than this hear and feel it
		SlowEase = 0.2, -- seconds the slow motion takes to ease back to full speed
		ShowSeconds = 3, -- how long the fall lasts on screen
		SinkSpeed = 4, -- studs/s landed pieces sink into the ground, under the dust
		HideSeconds = 6.5, -- server: the pieces go for good after this (longer than the slowest show)
		MaxPieces = 900, -- most pieces one show moves; any more just vanish in the dust
		MaxShows = 5, -- most falling buildings on one screen; any more just vanish
		FarStuds = 900, -- buildings further from the camera than this just vanish
		SlowSeconds = 0.9, -- slow motion for whoever brought it down
		SlowScale = 0.3, -- how fast time runs in it
		SlowCooldown = 6, -- seconds before the next collapse can slow things down again
		PaySeconds = 2.4, -- when the money lands, after the hit (once the fall has happened, slow motion and all)
		PayPerPiece = 4, -- money per piece that came down
		PayMin = 300,
		PayMax = 2500,
		GoalPieces = 260, -- most pieces one collapse counts for goals and events
		CrumbleBudget = 140, -- most bricks the pieces thrown out near the hit break into (each screen's own)
		CrumbleEach = 8, -- ...and most bricks one of them breaks into
	}),
	-- walls crumble into bricks (Rules/Crumble): the cells of a broken wall near the hit are thrown out as bricks
	-- that only each screen simulates, and the rest stands on as a few blocks until the building rebuilds
	Crumble = table.freeze({
		MinCell = 1.6, -- studs: the smallest brick
		MaxGrid = 300, -- most cells one wall is cut into
		Ragged = 0.35, -- share of the hole's radius each cell's edge wanders in or out, for a broken edge
		MaxFly = 28, -- most bricks one broken wall throws
		Budget = 260, -- most bricks one break throws in all (shared out over the walls it breaks)
		PropFly = 4, -- most pieces one part of a lamp post, bench or sign breaks into
		-- server: leftover blocks are real parts until their building rebuilds
		MaxStay = 12, -- a wall that would stand on as more blocks than this comes down whole
		MinStayShare = 0.15, -- ...and so does one with less than this share of it left
		MaxRemnants = 600, -- most leftover blocks standing across the map at once (the map's part budget)
		ClearStuds = 1, -- the hitting vehicle's way through stays this much wider than it, so it never sticks
		-- each screen: the bricks
		MaxLive = 260, -- most bricks moving or lying about at once; the oldest goes first
		MaxLivePhone = 110, -- ...on a phone or tablet
		FarStuds = 700, -- breaks further from the camera than this throw no bricks (just the dust)
		Shrink = { 0.72, 0.95 }, -- share of its cell a brick fills, so they read as rubble, not a grid
		Shade = 0.12, -- most a brick's colour drifts darker or lighter
		PushShare = 0.55, -- share of the hitter's velocity the bricks carry on with...
		PushSpread = { 0.1, 1 }, -- ...times this, per brick: some spill down at the hole, some fly on in
		DropScatter = 0.15, -- share of Out and Up the walls falling from above the hit get (they mostly drop)
		PropPush = 0.8, -- share of the hitter's velocity a lamp post's or bench's pieces carry on with
		PropLift = 12, -- studs/s up on top
		Out = { 12, 30 }, -- studs/s away from the hit
		Up = { 6, 24 }, -- studs/s up
		Spin = 6, -- radians/s, most in each axis
		SettleAfter = 1.5, -- seconds: from then a brick that has nearly stopped is frozen in place (no physics)
		SettleSpeed = 2.5, -- studs/s
		LifeSeconds = { 8, 12 }, -- a brick lies this long...
		SinkSeconds = 1.2, -- ...then sinks into the ground over this long and goes back to the pool
	}),
})
