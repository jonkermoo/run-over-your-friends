--!strict
-- Small things that make lots look lived in (YardKit): a garden shed, a trampoline or a swing set in back
-- gardens, and a street front for office towers (striped awnings over the ground floor, planters with
-- bushes, a bench). Each is a smashable prop built from a few parts. Studs; colours are { r, g, b }.

export type RGB = { number }

return table.freeze({
	-- back gardens (SuburbKit.garden, town homes and the suburbs): this share get one thing, picked by weight;
	-- it stands in the garden's far corner from the tree, `Inset` in from the side and the fence
	Garden = table.freeze({
		Chance = 0.6,
		Kinds = table.freeze({ shed = 3, trampoline = 2, swings = 2 }),
		Inset = 7,
		Seed = 7710,
	}),
	Shed = table.freeze({
		Size = table.freeze({ 8, 7, 6 }), -- wide, wall height, deep
		Roof = 3, -- the gable's rise
		Walls = table.freeze({
			{ 196, 160, 116 },
			{ 150, 186, 160 },
			{ 220, 200, 160 },
			{ 170, 120, 100 },
		}),
		RoofColour = { 80, 76, 84 } :: RGB,
		Door = { 120, 84, 56 } :: RGB,
	}),
	Trampoline = table.freeze({
		Dia = 11,
		Height = 2.6,
		Rim = table.freeze({ { 60, 140, 220 }, { 90, 190, 90 }, { 236, 84, 96 } }),
		Mat = { 30, 30, 34 } :: RGB,
		Legs = { 70, 70, 76 } :: RGB,
	}),
	Swings = table.freeze({
		Width = 10,
		Height = 8,
		Frame = { 236, 84, 96 } :: RGB,
		Seat = { 250, 210, 70 } :: RGB,
		SeatHeight = 2.2,
		Rope = { 60, 60, 64 } :: RGB,
	}),

	-- the lawn in the middle of a block of town homes (between the back gardens): a hedge across it in a few
	-- lengths with gaps, flower beds, and on every `PlayEvery`th block a little playground (swings, a slide,
	-- a sandpit); `Reach` of the block's inner half either way
	Middle = table.freeze({
		Reach = 0.78,
		Hedges = 3,
		HedgeGap = 10,
		HedgeHeight = 5,
		HedgeDepth = 5,
		Beds = 2,
		BedOff = 14, -- beds stand this far off the hedge line
		PlayEvery = 3,
		Slide = table.freeze({ 3, 7, 12 }), -- wide, top height, long
		SlideColour = { 60, 140, 220 } :: RGB,
		SlidePosts = { 70, 70, 76 } :: RGB,
		ChuteColour = { 250, 210, 70 } :: RGB,
		PlaySpacing = 16, -- the slide and the sandpit stand this far either side of the swings
		PlayOff = 6, -- the playground this much further off the hedge than the beds
		Sand = table.freeze({ 12, 0.5 }), -- across, tall
		SandColour = { 226, 204, 150 } :: RGB,
		SandEdge = { 150, 112, 76 } :: RGB,
		Seed = 9310,
	}),

	-- office towers' street fronts (MapBuilder after TownKit.office): two awnings either side of the door,
	-- `AwningAt` of the front's half-width out; planters at the front's ends; a bench by the door
	Office = table.freeze({
		AwningAt = 0.55,
		Awning = table.freeze({ 16, 5, 0.5 }), -- long, deep, thick
		AwningHeight = 10,
		AwningTilt = 0.25, -- radians down toward the street
		Awnings = table.freeze({
			{ 236, 84, 96 },
			{ 60, 140, 220 },
			{ 90, 170, 110 },
			{ 250, 180, 60 },
		}),
		Planter = table.freeze({ 6, 2.2, 3 }), -- long, tall, deep
		PlanterColour = { 120, 116, 110 } :: RGB,
		PlanterInset = 5, -- in from the front's ends
		BushSize = 5,
		Out = 2.2, -- planters and the bench stand this far out from the wall
		BenchAt = 9, -- the bench this far to the side of the door
		Seed = 8130,
	}),
})
