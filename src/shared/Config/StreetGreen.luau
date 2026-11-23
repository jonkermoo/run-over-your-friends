--!strict
-- The city's street greenery (StreetKit, Rules/StreetGreen): rows of street trees in three shapes and a few
-- tints, a grass verge along each kerb, flowers in the street planters and beds on the wide office and shop
-- forecourts. Every piece reuses a mesh already in assets/Scenery.rbxm (no new assets). Studs; colours are
-- { r, g, b }.

export type RGB = { number }
export type Shape = {
	mesh: string, -- a crown in assets/Scenery.rbxm
	width: number, -- the crown this wide
	stretch: number, -- and its height times this (a tall column > 1)
	trunk: number, -- the trunk this tall
	sink: number, -- the crown's foot this share of its height below the trunk's top...
	foot: number?, -- ...or, when set, this far over the ground
}

return table.freeze({
	-- the trees along each block side: at these shares of the block from the side's middle, this far in from
	-- the kerb; only in districts whose Config/Streets `trees` chance is drawn
	Trees = table.freeze({
		At = table.freeze({ -0.32, -0.16, 0.16, 0.32 }),
		SpawnAt = table.freeze({ -0.32, 0.32 }), -- the spawn plaza's sides: clear of its exits
		Inset = 2.5,
		TrunkWidth = 1.3,
		Trunk = { 110, 78, 52 } :: RGB,
		-- picked by spot (no random draws, so nothing else in the town moves)
		Shapes = table.freeze({
			table.freeze({ mesh = "CrownA", width = 15, stretch = 1, trunk = 14, sink = 0.35 }) :: Shape, -- round
			table.freeze({ mesh = "CrownC", width = 18, stretch = 1.15, trunk = 12, sink = 0.35 }) :: Shape, -- wide, flat top
			table.freeze({
				mesh = "CrownB",
				width = 9.5,
				stretch = 1.9,
				trunk = 11,
				sink = 0,
				foot = 6,
			}) :: Shape, -- tall column
		}),
		Greens = table.freeze({
			{ 86, 156, 70 },
			{ 64, 128, 62 },
			{ 118, 170, 72 },
			{ 76, 142, 92 },
		}) :: { RGB },
		-- whole block sides in one accent: blossom, early autumn; about one side in `AccentEvery` gets one
		Accents = table.freeze({ { 240, 168, 186 }, { 232, 156, 64 } }) :: { RGB },
		AccentEvery = 13,
	}),

	-- a flat grass strip along the kerb of each block side with trees, under them: its middle this far in from
	-- the kerb, this wide, this share of the block long, its top this far over the sidewalk; it never collides
	Verge = table.freeze({
		Inset = 2.6,
		Width = 3.4,
		Length = 0.86,
		Top = 0.12,
		Colour = { 104, 146, 70 } :: RGB,
	}),

	-- the street planters (StreetKit) hold soil and a row of blooms instead of a flat green block
	PlanterBlooms = table.freeze({
		Size = table.freeze({ 4.4, 1.6, 1.6 }), -- the Blooms mesh, long, tall, deep
		SoilTop = 1.9, -- the soil's top over the ground (it sits on the 1.6-tall box)...
		SoilThick = 0.3,
		Sink = 0.2, -- ...and the blooms sink this far into it
		Soil = { 92, 66, 46 } :: RGB,
	}),

	-- beds on the bare paving either side of an office tower (YardKit.officeFlanks, Rules/StreetGreen): along
	-- the sidewalk's inner edge, from `Ends` short of the front sidewalk back to the tower's back wall (never
	-- into the car park behind it); a lawn strip `Depth` deep with a low hedge on the tower's side and
	-- flowers on the street's; only where the flank is at least `Depth + Clear` wide and the run `MinRun` long
	Forecourt = table.freeze({
		Depth = 7,
		Clear = 2,
		Ends = 4,
		MinRun = 20,
		Top = 0.12,
		Hedge = table.freeze({ height = 2.6, depth = 2.4 }),
		HedgeColour = { 70, 122, 60 } :: RGB,
		Blooms = 2, -- per bed, spread along it
		BloomSize = table.freeze({ 9, 1.4, 2.4 }),
		BloomEdge = 0.3, -- the flowers keep this far in from the bed's street edge
	}),

	-- flower colours for planters and beds
	Flowers = table.freeze({
		{ 236, 84, 96 },
		{ 250, 210, 70 },
		{ 240, 240, 240 },
		{ 186, 110, 220 },
		{ 255, 150, 60 },
	}) :: { RGB },
})
