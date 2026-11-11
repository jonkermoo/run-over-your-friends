--!strict
-- The countryside that fills the map round the city and its four zones (CountryKit): hills, woods and islands
-- past the map's edge, a farm (north-east), a motocross track (south-east), beaches and a lighthouse on the
-- west coast, a pine forest round a lake (north-west), uses for the cells between the city and the ring, a
-- sidewalk on the city's outer road, and fills for the bare parking lots and plazas. Hills and dirt are
-- terrain (no parts); woods are one-piece meshes (assets/Scenery.rbxm). Studs; colours are { r, g, b }.
-- Rects are { x, z, w, d }: centre and size (w east-west, d north-south).

export type RGB = { number }

return table.freeze({
	-- past the map's edge (outside the invisible walls, so nobody drives there): two rows of terrain hills on
	-- the north, east and south, a belt of woods at their foot, pines on the slopes; the sea runs on in the
	-- west with a few islands
	Edge = table.freeze({
		Spacing = 170, -- between hills along a side
		MoundStep = 4, -- hills are stacked terrain discs this thick
		Overrun = 900, -- the rows run this far past each corner, so corners are closed
		Near = table.freeze({ out = { 60, 220 }, radius = { 220, 340 }, height = { 35, 80 } }), -- out: past the edge
		Far = table.freeze({ out = { 380, 650 }, radius = { 380, 560 }, height = { 140, 300 } }),
		RockFrom = 270, -- far hills this tall are rock, not grass
		BeltOut = 25, -- the woods' centre line, past the edge
		BeltSpacing = 190, -- between belt meshes along a side (each is about 210 long)
		BeltOverrun = 450, -- belts run this far past each corner
		BeltLook = 90, -- a belt sits at the lowest ground found this far either side of its middle
		CoastClear = 120, -- no woods or pines this close to the west coast
		PineOverrun = 400, -- pines spread this far past each corner...
		PineOut = table.freeze({ 80, 700 }), -- ...and this far past the edge
		PineTries = 10, -- spots tried per pine before giving up
		PineMinHeight = 6, -- pines only on slopes at least this high (not in the flat between hills)
		BeltSink = 4, -- woods sit this far into the slope
		BeltColours = table.freeze({ { 58, 112, 60 }, { 66, 126, 64 }, { 52, 100, 56 } }) :: { RGB },
		Pines = 150, -- on the hills, three sides together
		PineHeight = table.freeze({ 30, 55 }),
		PineColours = table.freeze({ { 46, 94, 60 }, { 54, 106, 64 }, { 40, 84, 54 } }) :: { RGB },
		SeaReach = 700, -- the sea runs on this far past the west edge
		Islands = 5,
		IslandRadius = table.freeze({ 90, 200 }),
		IslandHeight = table.freeze({ 30, 70 }),
		IslandOut = table.freeze({ 250, 550 }), -- past the edge
		IslandJitter = 200, -- along the coast, from even spacing
		BeachSpread = 1.15, -- each island's sand skirt, as a share of its radius...
		BeachRise = 0.25, -- ...and of its height
	}),

	-- the open grass inside the walls the zones leave empty (after the groves and ponds): low rolling hills to
	-- drive over (terrain) and strips of woods (one Belt mesh each, scaled down, turned a random way)
	Meadow = table.freeze({
		Hills = 26,
		HillRadius = table.freeze({ 60, 120 }),
		HillHeight = table.freeze({ 5, 14 }),
		Woods = 14,
		WoodScale = table.freeze({ 0.45, 0.75 }),
	}),

	-- what still fills the open grass after the meadow (WildsKit), in this order, each clear of what came before:
	-- rocky knolls (terrain), pine stands (one mesh each), more strips of woods, hedgerows of trees, wildflower
	-- patches with bushes, then rolling hills in the gaps. `n` is how many are tried; a crowded map gets fewer.
	Fill = table.freeze({
		Margin = 16,
		Knolls = table.freeze({ n = 45, radius = 40, rocks = { 3, 6 }, size = { 10, 24 } }), -- rock balls, half sunk
		Pines = table.freeze({ n = 42, radius = 52, trees = { 8, 13 } }),
		Woods = table.freeze({ n = 90, scale = { 0.4, 0.7 } }),
		Hedges = table.freeze({ n = 24, trees = { 5, 8 }, gap = 15 }), -- a straight row of leafy trees
		Flowers = table.freeze({
			n = 38,
			radius = 30,
			beds = { 4, 7 },
			scale = { 1, 1.8 },
			bushes = 2,
		}),
		Hills = table.freeze({ n = 150, radius = { 50, 180 }, height = { 6, 30 } }),
	}),

	-- north-east: fields of crop rows, wind breaks of trees, a red barn, a silo and hay bales
	Farm = table.freeze({
		Rect = table.freeze({ x = 2150, z = -2150, w = 1000, d = 1000 }),
		Fields = table.freeze({ 2, 2 }), -- columns, rows
		FieldGap = 70, -- between fields (grass tracks)
		Rows = 8, -- crop rows per field
		RowHeight = 0.4,
		Crops = table.freeze({
			{ 120, 170, 70 },
			{ 214, 186, 80 },
			{ 96, 150, 64 },
			{ 170, 190, 90 },
		}) :: { RGB },
		Soil = { 116, 86, 60 } :: RGB,
		Barn = table.freeze({ w = 50, d = 70, h = 22, roof = 16 }),
		BarnWall = 1.5, -- wall thickness (the forest cabin too)
		BarnRed = { 168, 44, 40 } :: RGB,
		Silo = table.freeze({ dia = 18, h = 46 }),
		Bales = 14,
		BaleSize = table.freeze({ 6, 5 }), -- across, long
		Hay = { 222, 190, 100 } :: RGB,
	}),

	-- south-east: a dirt track loop with jumps (terrain) and berms, a start gate, tyre stacks
	Moto = table.freeze({
		Rect = table.freeze({ x = 2100, z = 2100, w = 900, d = 900 }),
		Loop = table.freeze({ 640, 560 }), -- the track's centre line, east-west and north-south
		Width = 40,
		Jumps = 8,
		JumpRadius = 28,
		JumpHeight = 9,
		Tyres = 12,
		Dirt = { 150, 116, 80 } :: RGB,
	}),

	-- the west coast north and south of the port: a sand beach, umbrellas, a lifeguard tower, a pier, and a
	-- lighthouse at the south end
	Beach = table.freeze({
		Width = 160, -- inland from the water's edge
		Gap = 40, -- clear of the port
		Umbrellas = 10, -- per beach
		UmbrellaColours = table.freeze({
			{ 236, 84, 96 },
			{ 60, 140, 220 },
			{ 250, 210, 70 },
			{ 240, 240, 240 },
		}) :: { RGB },
		PierLength = 160,
		PierWidth = 16,
		Lighthouse = table.freeze({ dia = 16, h = 70 }),
		LighthouseRed = { 200, 50, 46 } :: RGB,
	}),

	-- north-west: a pine forest round a lake with a jetty and a log cabin
	Forest = table.freeze({
		Rect = table.freeze({ x = -1400, z = -2250, w = 1100, d = 1100 }),
		Pines = 110,
		PineHeight = table.freeze({ 28, 50 }),
		Lake = 130, -- radius
		LakeAt = table.freeze({ 0.1, 0.15 }), -- share of the rect's size from its centre
		Clear = 22, -- pines keep this far from the lake's bank and the cabin
		Log = { 120, 84, 56 } :: RGB,
	}),

	-- the cells between the city and the ring, in turn round the ring (Outskirts RingCells keeps billboards)
	Cells = table.freeze({
		Uses = table.freeze({
			"trees",
			"field",
			"turbines",
			"field",
			"gas",
			"trees",
			"turbines",
			"field",
		}), -- gas on odd cells (billboards take the even ones)
		CornerTrees = 5, -- the four corner cells get a small grove
		Turbine = table.freeze({ h = 90, blade = 34, dia = 4.5 }),
		Gas = table.freeze({ pad = { 80, 46 }, canopy = { 44, 26, 15 }, shop = { 26, 16, 12 } }), -- w, d, h
		GasRed = { 214, 58, 48 } :: RGB,
	}),

	-- terrain grass (hills, knolls) renders lighter than the ground part's Grass; this tint matches them (Studio)
	TerrainGrass = { 66, 120, 50 } :: RGB,

	-- a sidewalk along the outside of the city's outer road
	OuterSidewalk = true,

	-- bare blocks in town: parking bays painted in the lots, market stalls round the plazas
	Lot = table.freeze({
		Bay = table.freeze({ 12, 22 }), -- wide, deep
		Bays = 8, -- per row; two rows back to back in the middle of the lot
		Shift = 20, -- the bays sit this far east of the lot's middle, clear of its west ramp
		Line = 0.6,
		Lamps = 4,
	}),
	Plaza = table.freeze({
		Stalls = 3,
		Stall = table.freeze({ 12, 6, 8 }), -- w, d, h
		Awnings = table.freeze({
			{ 236, 84, 96 },
			{ 60, 140, 220 },
			{ 250, 210, 70 },
			{ 90, 180, 110 },
		}) :: { RGB },
	}),

	-- the desert's rectangle edge, blurred with low sand mounds spilling onto the grass
	DesertEdge = table.freeze({ Mounds = 40, Radius = { 40, 100 }, Height = { 2, 6 }, Cacti = 10 }),
})
