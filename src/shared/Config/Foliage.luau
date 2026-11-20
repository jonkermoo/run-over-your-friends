--!strict
-- The chunky low-poly greenery (assets/Scenery.rbxm, tools/blender/export_scenery.py): tree crowns and bushes
-- in three and two shapes, grass tufts with flowers, rocks, palms and crop rows, and how FoliageKit scatters
-- them over the rolled countryside after everything else is built. Every piece is one MeshPart of one colour
-- (the same mesh draws in one batch), never collides and never blocks a ray, and small ones cast no shadow.
-- Studs; colours are { r, g, b }.

export type RGB = { number }

return table.freeze({
	-- trees (Greenery.tree): a trunk part and a crown mesh picked by position (no extra random draws, so the
	-- town's layout doesn't shift); the crown is `CrownWidth` main-ball sizes across and sinks `CrownSink` of
	-- its height over the trunk's top
	Crowns = table.freeze({ "CrownA", "CrownB", "CrownC" }),
	CrownWidth = 1.55,
	CrownSink = 0.3,
	Bushes = table.freeze({ "BushA", "BushB" }),
	BushWidth = 1.35, -- a bush mesh this many Parks.Bush sizes across

	-- the open-ground scatter: the island in square cells `Cell` wide; a cell gets a cluster with chance `Base`,
	-- or `Verge` from `VergeFrom` to `VergeBand` studs past the level ground's edge (roadsides, field and lot edges); only
	-- on grass the roll reaches by `MinWeight`, never on paths, sand or rock
	Scatter = table.freeze({
		Seed = 9120,
		Cell = 34,
		Base = 0.022,
		Verge = 0.3,
		VergeFrom = 4, -- verges begin this far off the level ground (the road or lot it borders)
		VergeBand = 45,
		MinWeight = 0.15,
		Spread = 9, -- a cluster's pieces lie this far round its middle
		-- what a cluster is, by weight: tufts (some flowering), a bush with tufts, rocks
		Kinds = table.freeze({ tufts = 6, bush = 3, rocks = 1.4 }),
		Tufts = table.freeze({ 3, 5 }),
		TuftHeight = table.freeze({ 4.5, 7 }),
		FlowerShare = 0.3, -- of tufts carry flowers
		Rocks = table.freeze({ 1, 3 }),
		RockSize = table.freeze({ 2.5, 7 }),
		BushSize = table.freeze({ 6, 12 }),
		-- how far each sinks into the ground (rocks: a share of their size), so none shows a gap on a slope
		TuftSink = 0.3,
		RockSink = 0.18,
		BushSink = 0.4,
		RockShadowFrom = 4, -- rocks this big or bigger cast a shadow
		BushDarken = 0.15, -- bushes are this much darker than the tufts round them
	}),
	-- bushes along each strip of woods, front and back, so the trees don't stand on bare lawn
	-- `out`: share of the strip's depth from its middle line, `spread` of its length either way from its middle
	WoodEdge = table.freeze({ per = 4, out = 0.42, spread = 0.45, size = table.freeze({ 5, 9 }) }),

	TuftGreens = table.freeze({ { 78, 132, 54 }, { 92, 146, 60 }, { 66, 118, 48 } }) :: { RGB },
	BeachGrass = { 150, 160, 92 } :: RGB,
	Rocks = table.freeze({ "RockA", "RockB", "RockC" }),
	RockGreys = table.freeze({ { 138, 132, 124 }, { 120, 116, 110 }, { 156, 150, 140 } }) :: { RGB },

	-- palms on the beaches, between the umbrellas and the dunes (shares of the beach's width)
	Palms = table.freeze({
		n = 14,
		from = 0.45,
		to = 0.85,
		height = table.freeze({ 24, 36 }),
		trunk = { 132, 96, 64 } :: RGB,
		leaves = table.freeze({ { 70, 146, 64 }, { 84, 160, 70 } }) :: { RGB },
		clear = 10, -- from umbrellas and the tower
		grass = table.freeze({ 2, 4 }), -- beach-grass tufts at each palm's foot...
		grassRing = table.freeze({ 2, 6 }), -- ...this far out
		sink = 0.6,
		endGap = 50, -- off the beach's ends
	}),

	-- crop rows over the farm's fields, in square tiles `Tile` wide, turned with each field; per crop material:
	-- the rows' colour and height
	CropTile = 26,
	CropSink = 0.4,
	CropStagger = 0.03, -- every other tile this much higher, so neighbours' ends never share a plane
	Crops = table.freeze({
		Sand = table.freeze({ colour = { 222, 190, 90 }, height = 3.2 }),
		Ground = table.freeze({ colour = { 96, 150, 64 }, height = 1.8 }),
		Limestone = table.freeze({ colour = { 84, 128, 56 }, height = 2.4 }),
	}),
})
