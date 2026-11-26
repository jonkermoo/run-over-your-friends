--!strict
-- Everything outside the city grid: the highway ring, the stunt park (east), the container port and its sea
-- (west), the desert (south), the construction site (north), the cells between the city and the ring, and the
-- groves and ponds on the flat grass that fills the rest of the ground. Studs; colours are { r, g, b }. Zones are placed `Gap` studs
-- beyond the ring's outer edge; `Width` runs east-west, `Depth` north-south.

export type RGB = { number }

return table.freeze({
	Ring = table.freeze({
		Gap = 110, -- from the town's outer roads to the loop's centre line (the loop follows the ragged edge)
		Width = 90,
		Points = 96, -- the loop's centre line, this many points round
		Window = 0.2, -- radians: each point clears the town this far either side of its direction...
		Smooth = 4, -- ...then this many passes of smoothing over its radius
		StubOut = 0.8, -- a grid road's end runs on to the loop when it points this straight out of town
		CentreLine = 0.6, -- the ring's double yellow
		Connector = 80, -- the roads out to the stunt park and the port
	}),

	-- the empty lattice cells inside the loop: every other one gets a billboard (what else stands there:
	-- Config/Country); a cell is used when all of it is inside the loop and this far clear of its edge
	RingCells = table.freeze({
		BillboardEvery = 2,
		LoopClear = 10,
	}),

	-- each zone's centre (At), round the loop road: the island is small, so every area sits close to it
	Stunt = table.freeze({
		At = { 1700, 0 },
		Gap = 70,
		Width = 900,
		Depth = 1100,
		-- north lane: the mega ramp, a gap, a landing slope and a wall ride at the end
		MegaZ = -330,
		Mega = table.freeze({ width = 60, height = 70, length = 260, foot = -380 }),
		-- back = a slope up the landing's gap side, so a short jump rolls up it instead of hitting a wall
		Landing = table.freeze({ height = 40, length = 200, foot = 220, back = 60 }),
		WallRide = table.freeze({ width = 150, height = 60, length = 30, foot = 395 }),
		-- tabletops that grow along the second lane
		TableZ = -130,
		Tables = 5,
		TableWidth = 30,
		TableSpacing = 150,
		TableDeck = 16,
		-- container jump on the third lane: a kicker, smashable containers, a landing
		JumpZ = 20,
		Jump = table.freeze({
			height = 14,
			length = 40,
			foot = -300,
			containers = 3,
			containerGap = 9, -- between the jump's containers
			landingFoot = -80,
		}),
		-- dirt rollers (terrain) on the same lane, east of the containers
		Rollers = 6,
		RollerRadius = 18,
		RollerHeight = 6,
		RollerStart = 60,
		RollerSpacing = 38,
		-- the bowl: four quarter pipes that meet, corner wedges closing it
		BowlZ = 310,
		BowlHalf = 180, -- from the bowl centre to each quarter pipe's foot
		BowlHeight = 30,
		BowlLength = 50,
		TyreStacks = 64,
		Flags = 10,
		Stands = 2,
		Spectators = 24, -- crowd spots in front of the stands
		DirtField = 7, -- terrain doubles in the south-west corner
	}),

	Port = table.freeze({
		At = { -1725, 0 },
		Gap = 70,
		Width = 700,
		Depth = 1000,
		Rows = 6,
		Cols = 4,
		Cranes = 2,
		Fenders = 20, -- tyres on the quay's face
		-- tall ship-to-shore cranes along the quay (static scenery, clear of the two smashable gantries at z
		-- -160 and 160): at these z offsets from the port's middle, colours taking turns. Legs `Leg` thick, `Span`
		-- apart across the quay (centred `Inland` from its edge) and `Depth` along it, `Height` tall, a tie `Tie`
		-- below the top; a boom `Boom` long, `Reach` of it out over the water; an A-frame `Frame` above the boom
		Sts = table.freeze({
			At = table.freeze({ -420, -20, 300, 450 }),
			Colours = table.freeze({ { 200, 60, 50 }, { 235, 235, 230 } }),
			Inland = 24,
			Span = 40,
			Depth = 30,
			Leg = 3,
			Height = 95,
			Tie = 30,
			Boom = 170,
			Reach = 110,
			Frame = 40,
		}),
		-- stacks along the yard's north and south edges, `Inset` in from them, from `From` past the quay to `To`
		-- short of the land side, `Gap` apart, `Heights` containers tall (own random stream, `Seed`)
		EdgeStacks = table.freeze({
			Inset = 40,
			From = 120,
			To = 60,
			Gap = 6,
			Heights = table.freeze({ 1, 5 }),
			Seed = 5150,
		}),
		Dock = { 150, 150, 146 }, -- the yard's concrete (darker than the plazas, so it doesn't blow out in the sun)
		LaneColour = { 240, 196, 40 },
		SeaDepth = 12, -- water surface sits 1 stud under the quay
		-- the cargo ship off the quay: hull width, length (bow tip to stern), the bow's taper, keel and deck heights
		Ship = table.freeze({
			Width = 40,
			Length = 260,
			Bow = 40,
			Keel = -10,
			Deck = 6,
			Topsides = { 34, 52, 84 },
		}),
	}),

	-- shipping containers (the port's stacks and the stunt park's jump): a 40-foot box in proportion, painted one
	-- of these colours, with overlay images (0 = none) for the corrugated walls, the frame and the doors
	Container = table.freeze({
		Size = { 16, 17, 72 }, -- wide, tall, long
		JumpSize = { 16, 16, 56 }, -- the stunt park's jump containers (shorter, to fit its lane)
		Gap = 2, -- between the two containers side by side in a stack
		RibStuds = 2.2, -- one rib of the corrugation
		Ribs = 76189861431152,
		Frame = 133617883462700,
		Door = 89850448249829,
		Colours = table.freeze({
			{ 232, 112, 40 }, -- orange
			{ 28, 128, 140 }, -- teal
			{ 186, 50, 44 }, -- red
			{ 36, 62, 112 }, -- navy
			{ 226, 224, 216 }, -- white
			{ 62, 122, 74 }, -- green
			{ 240, 190, 30 }, -- yellow
			{ 214, 78, 136 }, -- pink
		}),
	}),

	Desert = table.freeze({
		At = { 0, 1500 },
		Gap = 120,
		Width = 1000,
		Depth = 500,
		Dunes = 48,
		DuneRadius = table.freeze({ 30, 80 }),
		DuneSlope = table.freeze({ 20, 35 }), -- height as a percent of the dune's radius
		Mesas = 7,
		-- each mesa is stepped: `Tiers` layers of a few overlapping turned slabs, each layer `Shrink` of the one
		-- below, on a skirt of sand (talus) `Talus` of its width out
		MesaTiers = 3,
		MesaSeed = 8800,
		MesaShrink = table.freeze({ 0.62, 0.8 }),
		MesaSlabs = table.freeze({ 2, 4 }),
		MesaTalus = 0.3,
		-- each slab: its size a share of its tier's, off the middle by up to MesaOffset of it, its height a share of
		-- the tier's, turned up to MesaTwist radians from the mesa's turn
		MesaSlabSize = table.freeze({ 0.6, 1 }),
		MesaOffset = 0.2,
		MesaSlabHeight = table.freeze({ 0.85, 1.15 }),
		MesaTwist = 0.4,
		MesaTall = 2.2, -- the old flat slabs' heights times this
		MesaTalusRise = 0.15, -- the sand skirt's height, as a share of the mesa's
		Cacti = 36,
		Outcrops = 26, -- clusters of half-sunk sandstone balls (terrain)
		OutcropSize = table.freeze({ 10, 26 }),
		EdgeSpill = 160, -- ragged squares of sand past the floor's edges...
		SpillSize = table.freeze({ 24, 90 }), -- ...this big...
		SpillOut = 70, -- ...reaching this far out
		TerrainSand = { 200, 162, 104 } :: RGB, -- dunes and outcrops: terrain sand draws lighter, so darker here
	}),

	Site = table.freeze({
		At = { -350, -1550 },
		Gap = 70,
		Width = 760,
		Depth = 600,
		GateWidth = 90,
		HoardingHeight = 10,
		Frames = 3, -- half-built steel towers (smashable)
		FrameFloors = 4,
		FrameSize = 80,
		Cranes = 2,
		DirtPiles = 16,
		PipeStacks = 3,
		Cabins = 3,
		Cones = 48,
		Pallets = 26,
		Workers = 30, -- crowd spots
	}),

	-- the flat grass: groves of trees (props), ponds (flat discs) with a sandy bank
	Wilds = table.freeze({
		Margin = 20,
		Groves = 50,
		GroveRadius = 28,
		GroveTrees = table.freeze({ 3, 5 }), -- fewest, most
		Ponds = 14,
		PondRadius = 40,
	}),

	Colours = table.freeze({
		dirt = { 132, 104, 74 },
		sitePad = { 168, 136, 98 }, -- the Ground material darkens a part, so the pad is lighter than the terrain dirt
		steel = { 70, 76, 86 },
		crane = { 240, 186, 30 },
		hoarding = { 36, 70, 120 },
		cone = { 245, 110, 30 },
		tyre = { 30, 30, 32 },
		deckRed = { 196, 64, 52 },
		deckBlue = { 52, 110, 190 },
		deckOrange = { 236, 140, 40 },
		bowl = { 70, 150, 200 },
		cactus = { 70, 130, 70 },
		ship = { 160, 40, 36 },
		water = { 20, 120, 150 }, -- deep teal
	}) :: { [string]: RGB },
})
