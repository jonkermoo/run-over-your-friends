--!strict
-- The suburbs on the new land past the old map (SuburbKit): each is reached by a straight road from the highway
-- ring, then a gently curving avenue (the spine) runs on with side streets off both sides, each curving a little
-- and ending in a cul-de-sac. Detached houses (the house kit) face every street across a front lawn with a
-- driveway, a path, a mailbox and maybe a tree and a car; fenced back gardens, some with a pool.
-- Studs; colours are { r, g, b }. `dir` is the way the road runs out from the ring (x, z), `offset` where it
-- crosses the ring (x for a north/south road, z for an east/west one), `start` how far out the spine begins,
-- `length` the spine's length, `half` how far either side of the spine the side streets reach.

export type RGB = { number }
export type Hood = {
	name: string,
	dir: { number },
	offset: number,
	start: number,
	length: number,
	half: number,
	types: { [string]: number },
}

return table.freeze({
	Hoods = table.freeze({
		table.freeze({
			name = "SUNNY VALE",
			dir = { 1, 0 },
			offset = -800,
			start = 2900,
			length = 1650,
			half = 750,
			types = { A = 0.35, B = 0.4, C = 0.25 },
		}),
		table.freeze({
			name = "OAK HOLLOW",
			dir = { 0, -1 },
			offset = 600,
			start = 2500,
			length = 1350,
			half = 650,
			types = { B = 0.45, C = 0.55 },
		}),
		table.freeze({
			name = "SEASIDE",
			dir = { 0, 1 },
			offset = -1000,
			start = 2650,
			length = 1350,
			half = 450,
			types = { A = 0.6, B = 0.4 },
		}),
	}) :: { Hood },

	Feeder = table.freeze({ width = 40, line = 0.6 }), -- the road out from the ring, a double yellow
	Road = 26, -- street width
	Verge = 3, -- grass between the kerb and the sidewalk
	Sidewalk = 6,
	Step = 20, -- streets are laid in straight pieces this long
	SpineWave = table.freeze({ 40, 80 }), -- the avenue's sideways sway
	BranchFirst = 130, -- the first side street leaves the spine this far in...
	BranchGap = table.freeze({ 300, 360 }), -- ...then one every this far along it
	BranchStagger = table.freeze({ 0.4, 0.6 }), -- the other side's start, as a share of a gap (T-junctions)
	BranchBend = 90, -- side streets drift this far along the spine by their end
	BranchEnd = 90, -- side streets stop this far short of the edge
	Bulb = 34, -- cul-de-sac radius
	-- lots: the front lawn between the sidewalk and the house, houses this far apart along a street
	Lawn = 14,
	LotGap = 62,
	HouseClear = 42, -- house centres keep this far from each other
	Driveway = 11,
	Path = 3,
	Garden = 24, -- back garden depth (the fence)
	FenceHeight = 4.5,
	Fence = { 196, 160, 116 } :: RGB,
	Picket = { 245, 245, 240 } :: RGB,
	Concrete = { 196, 196, 190 } :: RGB,
	Mailbox = { 60, 70, 90 } :: RGB,
	Pool = table.freeze({ 18, 11 }), -- the water; a white rim round it
	PoolWater = { 70, 180, 230 } :: RGB,
	-- shares of lots that get each
	Chances = table.freeze({
		tree = 0.65,
		backTree = 0.55,
		car = 0.4,
		fence = 0.75,
		picket = 0.35,
		pool = 0.22,
	}),
	-- trees scattered on the open grass between the back gardens
	Spinney = table.freeze({ n = 70, tries = 30, clear = 26, trees = { 2, 4 } }),
	LampEvery = 150,
	Sign = table.freeze({ 46, 9 }), -- the name board at the entrance, wide and tall
	SignColour = { 46, 92, 60 } :: RGB,
})
