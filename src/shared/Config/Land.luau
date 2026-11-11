--!strict
-- The island's shape: a wobbly round edge (mountains past it) cut on the west by the coast, which runs straight
-- past the port and the beaches and then curves inland. Rules/Land works it out; OutskirtsKit fills the ground
-- (terrain), the sea and the walls from it. Studs; angles in radians (0 = east, pi/2 = south).

export type Wave = { k: number, amp: number, phase: number }

return table.freeze({
	Radius = 5100, -- the edge's mean distance from the middle
	-- the edge wobbles by these waves round the circle: k bumps, `amp` studs in and out
	Waves = table.freeze({
		table.freeze({ k = 2, amp = 220, phase = 0.7 }),
		table.freeze({ k = 3, amp = 260, phase = 2.1 }),
		table.freeze({ k = 5, amp = 150, phase = 4.0 }),
		table.freeze({ k = 7, amp = 80, phase = 1.3 }),
		table.freeze({ k = 11, amp = 40, phase = 5.2 }),
	}) :: { Wave },
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
	Shore = 40, -- a sand strip along the coast past the beaches
	SuburbSeed = 20261111, -- the suburbs' own random stream (Config/Suburbs)
})
