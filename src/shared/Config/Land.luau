--!strict
-- The island's shape: a wobbly round edge (mountains past it) cut on the west by the coast, which runs straight
-- past the port and the beaches and then curves inland. Rules/Land works it out; OutskirtsKit fills the ground
-- (terrain), the sea and the walls from it. Studs; angles in radians (0 = east, pi/2 = south).

export type Wave = { k: number, amp: number, phase: number }

return table.freeze({
	Radius = 2600, -- the edge's mean distance from the middle (was 5100, then 4000: every area sits close to the town)
	-- the edge wobbles by these waves round the circle: k bumps, `amp` studs in and out
	Waves = table.freeze({
		-- phased so the bulges fall where the suburbs and lakes reach furthest, which the tests check
		table.freeze({ k = 2, amp = 60, phase = 1.4 }),
		table.freeze({ k = 3, amp = 55, phase = 3.4 }),
		table.freeze({ k = 5, amp = 30, phase = 4.0 }),
		table.freeze({ k = 7, amp = 15, phase = 1.3 }),
		table.freeze({ k = 11, amp = 8, phase = 5.2 }),
	}) :: { Wave },
	CoastReach = 1450, -- the beaches run this far north and south of the middle (the round edge meets the coast past it)
	CoastStraight = 3000, -- the coast runs straight this far north and south of the middle (port, beaches)...
	CoastBend = 2600, -- ...then curves inland by (|z| - straight)^2 / bend
	-- and wiggles past the straight part: `k` here is the wave's length in studs
	CoastWaves = table.freeze({
		table.freeze({ k = 900, amp = 120, phase = 0.4 }),
		table.freeze({ k = 370, amp = 45, phase = 1.9 }),
	}) :: { Wave },
	SeaReach = 700, -- the walls stand in the sea this far off the coast
	Overrun = 1500, -- the ground runs on under the mountains this far past the edge
	FillBand = 300, -- open-ground fills (hills, woods) keep this far inside the edge
	Cell = 16, -- the ground and sea are filled in squares this big
	GroundDepth = 12,
	-- terrain's surface draws 2 studs above a filled block's top (half the top voxel); sunk this far, the grass
	-- sits a hair under y = 0, below the roads and sidewalks (measured in Studio)
	GroundSink = 2.2,
	WallSegments = 240,
	Shore = 40, -- a sand strip along the whole coast (not the port's quay)
	-- the sea bed: a sand shelf runs gently down from the shore to the port's depth (Outskirts Port.SeaDepth)
	-- over `Shelf` studs, then down again to `DeepDepth` by `DeepFrom` off the coast, so the water is pale
	-- turquoise in the shallows and darkens further out. The port's quay drops straight to the port's depth.
	Shelf = 150,
	ShelfTop = -0.6, -- the shelf's top at the water's edge (the water's surface is at -1)
	DeepFrom = 480,
	DeepDepth = 44,
	-- the beaches' inland edge wanders (sand into grass, no straight seam): waves of `k` studs, `amp` studs
	BeachWaves = table.freeze({
		table.freeze({ k = 260, amp = 22, phase = 0.3 }),
		table.freeze({ k = 95, amp = 9, phase = 2.2 }),
	}) :: { Wave },
	BeachTaper = 300, -- the beaches narrow to nothing over this far at their ends
	WaterWave = 0.35, -- terrain water: gentle waves (was 0.15, near flat)...
	WaterWaveSpeed = 12, -- ...rolling a little faster than the default 10
	WaterClear = 0.3, -- terrain water transparency
	SuburbSeed = 20261111, -- the suburbs' own random stream (Config/Suburbs)
})
