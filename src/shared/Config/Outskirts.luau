--!strict
-- Everything outside the city grid: the highway ring, the stunt park (east), the container port and its sea
-- (west), the desert (south), the construction site (north), the cells between the city and the ring, and the
-- terrain hills that fill the rest of the ground. Studs; colours are { r, g, b }. Zones are placed `Gap` studs
-- beyond the ring's outer edge; `Width` runs east-west, `Depth` north-south.

export type RGB = { number }

return table.freeze({
	Ring = table.freeze({
		Gap = 220, -- from the city's outer road to the ring's centre line
		Width = 90,
		CentreLine = 0.6, -- the ring's double yellow
		Connector = 80, -- the roads out to the stunt park and the port
	}),

	-- low grass mounds, a tree and every other cell a billboard, between the city and the ring
	RingCells = table.freeze({
		MoundHeight = 6,
		BillboardEvery = 2,
		Trees = 1,
	}),

	Stunt = table.freeze({
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
		TyreStacks = 56,
		Flags = 10,
		Stands = 2,
		Spectators = 24, -- crowd spots in front of the stands
		DirtField = 7, -- terrain doubles in the south-west corner
	}),

	Port = table.freeze({
		Gap = 70,
		Width = 700,
		Depth = 1000,
		Rows = 6,
		Cols = 4,
		Cranes = 2,
		Bollards = 10,
		SeaDepth = 12, -- water surface sits 1 stud under the quay
	}),

	Desert = table.freeze({
		Gap = 120,
		Width = 1800,
		Depth = 800,
		Dunes = 34,
		DuneRadius = table.freeze({ 30, 80 }),
		DuneSlope = table.freeze({ 20, 35 }), -- height as a percent of the dune's radius
		Mesas = 4,
		Cacti = 14,
	}),

	Site = table.freeze({
		Gap = 70,
		Width = 760,
		Depth = 600,
		GateWidth = 90,
		HoardingHeight = 10,
		Frames = 3, -- half-built steel towers (smashable)
		FrameFloors = 4,
		FrameSize = 80,
		Cranes = 2,
		DirtPiles = 10,
		PipeStacks = 3,
		Cabins = 3,
		Cones = 30,
		Pallets = 12,
		Workers = 30, -- crowd spots
	}),

	-- terrain hills fill the ground the zones leave empty; they grow toward the map edge
	Hills = table.freeze({
		Spacing = 250,
		Jitter = 70,
		RadiusMin = 40,
		RadiusMax = 150,
		Bury = 0.6, -- share of each hill's radius under the ground
		Margin = 30, -- kept clear around roads and zones
		RockChance = 0.25,
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
		water = { 40, 110, 140 },
	}) :: { [string]: RGB },
})
