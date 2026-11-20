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

	-- suburb front lawns (YardKit.front): a low border along the lawn's street edge (a white picket fence or a
	-- hedge) with gaps for the driveway, the path and the mailbox; bushes at the house's front corners and a
	-- flower bed under a window; on some driveways a bike or a basketball hoop
	Front = table.freeze({
		Border = 0.6, -- share of lots with a border...
		HedgeShare = 0.4, -- ...and of those, hedges (the rest picket fences)
		Inset = 1.2, -- the border this far in from the lawn's street edge
		Reach = 3, -- and this far past the house's sides
		Gap = 1, -- this much room either side of a driveway, a path or the mailbox
		MinRun = 5, -- no border piece shorter than this
		PicketHeight = 3.6,
		PicketDepth = 0.6,
		HedgeHeight = 3.6,
		HedgeDepth = 2.8,
		Corner = 2.6, -- corner bushes this far in from the house's sides...
		BushOut = 2.4, -- ...and this far out from its front wall
		BushSize = table.freeze({ 4, 5.5 }),
		Bushes = 0.8, -- share of lots with corner bushes
		Bed = 0.55, -- share of lots with a flower bed (on the side away from the driveway)
		BedOut = 3.2, -- its middle this far out from the front wall
		DoorClear = 7.5, -- nothing this close beside the door (porches, steps)
		Bike = 0.14,
		BikeLength = 5.4,
		BikeLean = 0.18, -- radians, leaning on its kickstand
		BikeBack = 1, -- on the driveway, this far out from the house...
		BikeEdge = 1.4, -- ...and this far in from its side
		Bikes = table.freeze({
			{ 220, 50, 60 },
			{ 40, 120, 220 },
			{ 250, 200, 40 },
			{ 60, 180, 90 },
			{ 240, 110, 180 },
		}),
		Hoop = 0.16,
		HoopHeight = 10,
		HoopBack = 4.5, -- the pole this far in from the lawn's street edge...
		HoopOff = 1.2, -- ...and this far off the driveway's side
		HoopReach = 2.6, -- the arm out over the driveway
		Board = table.freeze({ 6, 3.8, 0.3 }), -- wide, tall, thick
		BoardColour = { 245, 245, 245 } :: RGB,
		Rim = { 240, 110, 30 } :: RGB,
		HoopPole = { 60, 62, 68 } :: RGB,
		Seed = 5170,
	}),

	-- a pocket park in each suburb, on open grass near a street: a round paved square with a fountain, benches
	-- round it, flower beds, a ring of trees, lamps, and a path out to the sidewalk
	Pocket = table.freeze({
		PerHood = 2,
		Apart = 450, -- parks in one suburb at least this far apart
		Radius = 38, -- the room it needs (to its trees' crowns), kept off streets and gardens
		Grid = 30, -- spots tried this far apart
		Square = 34, -- across
		SquareColour = { 214, 200, 170 } :: RGB,
		Basin = table.freeze({ 10, 1.6 }), -- across, tall
		Stone = { 186, 180, 170 } :: RGB,
		Water = { 80, 170, 220 } :: RGB,
		Pillar = table.freeze({ 1.6, 4.2 }), -- the fountain's middle: across, tall, a bowl on top
		Bowl = table.freeze({ 4.4, 0.7 }),
		Benches = 4,
		BenchAt = 11.5, -- from the middle
		Beds = 3,
		BedAt = 21,
		Trees = 11,
		TreeJitter = 2, -- in or out of their ring by up to this
		TreeAt = 30,
		PathWidth = 6,
		LampOff = 1.5, -- lamps this far off the path's sides and the square's edge
		PathClear = 0.5, -- radians: no tree or bed this close to the path's way
		Seed = 6610,
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
