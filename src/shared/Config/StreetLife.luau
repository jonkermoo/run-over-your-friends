--!strict
-- Street life (server/StreetLife), added once the map stands: cars parked at the kerb on the downtown and shop
-- streets, rows of parked cars round the car parks' edges, lawns, food trucks and tables on the plazas, one
-- building site in a car park, and a few roadworks in the kerb lane. Cars, trees, tables, boards, barriers,
-- cones and pallets are props any vehicle knocks flying; the lawns, bay paint, dug patches, the site's ground,
-- slab, frame, mounds and crane stay put. Studs; colours are { r, g, b }; positions in a
-- block are from its middle (x east, z south).

export type RGB = { number }
export type Rect = { number } -- x0, z0, x1, z1 from a block's middle

return table.freeze({
	SeedOffset = 7, -- its own random stream (World.Map.Seed + this), so the rest of the map never moves

	-- parked cars: ReplicatedStorage.VehicleModels ids, picked evenly; KeepFactory ones keep their own paint.
	-- A parked car keeps its body, paint, glass, wheels and stock zones (about 12 parts).
	Cars = table.freeze({ "Hatchback", "Hatchback", "Sedan", "Sedan", "Sedan", "Muscle", "Taxi" }),
	KeepFactory = table.freeze({ Taxi = true, IceCream = true }),
	Paints = table.freeze({
		{ 236, 236, 232 },
		{ 160, 165, 172 },
		{ 34, 34, 38 },
		{ 200, 40, 36 },
		{ 43, 100, 205 },
		{ 54, 160, 80 },
		{ 120, 130, 150 },
	}) :: { RGB },
	Ground = 0.11, -- the road, lot and plaza top cars stand on
	CarSink = 0.15, -- into the ground (the meshes' wheels end a hair below their box)

	-- kerb parking: on block sides of these kinds, never on the spawn block's ring
	Kerb = table.freeze({
		On = false, -- off to keep within the map's part budget (about 950 parts with it on)
		Kinds = table.freeze({ office = true, shops = true, restaurant = true, plaza = true }),
		Out = 117, -- car centre from the block's middle (19-31 studs off the road's centre; traffic runs 11 off it)
		Slots = table.freeze({ -50, -17, 17, 50 }), -- along the side; the ends stay clear of the crossings
		PerSide = table.freeze({ 0, 1, 1, 1 }), -- cars on a side: one of these, picked evenly
		Jitter = 2, -- studs each car shifts along the kerb
	}),

	-- car parks (the ramp lots): rows of bays round the lot's edge, cars nose to the edge
	Lot = table.freeze({
		Bay = table.freeze({ 14, 28 }), -- wide, deep
		Edge = 2, -- the row stands this far off the lot's edge
		Corner = 30, -- the rows stop this far short of the lot's corners
		Fill = 0.45, -- share of the free bays that get a car
		Line = 0.6,
		-- where the ramps' runs and flights pass (x0, z0, x1, z1 from the block's middle): no bays there
		KeepOut = table.freeze({
			table.freeze({ -102, -50, 102, -10 }), -- the west ramp's run east
			table.freeze({ 10, -102, 50, 102 }), -- the south ramp's run north
		}) :: { Rect },
	}),

	-- the building site in one car park's north-west corner, clear of both ramps' runs
	Site = table.freeze({
		Block = table.freeze({ 568, 568 }), -- the car park's middle (world x, z): the south-east one
		Area = table.freeze({ -100, -100, -14, -54 }) :: Rect,
		Ground = { 150, 120, 88 } :: RGB,
		Hoarding = 12, -- one board this long round the site (each a prop), the gate left open
		HoardingHeight = 8,
		HoardingColour = { 232, 226, 210 } :: RGB,
		Gate = 18, -- the open gap in the east side
		Slab = table.freeze({ 44, 2, 28 }), -- the ground floor slab
		Columns = 3, -- along the slab's long side, two rows
		Storey = 12, -- the frame's height to its upper slab
		Concrete = { 184, 184, 188 } :: RGB,
		Mounds = 3,
		MoundSize = table.freeze({ 12, 4 }), -- across, high (a ball that wide, sunk so this much shows)
		Earth = { 120, 92, 64 } :: RGB,
		Pallet = table.freeze({ 7, 1, 7 }),
		Load = table.freeze({ 6, 4, 6 }), -- the parcels on a pallet
		Crate = { 190, 144, 92 } :: RGB,
		Pallets = 3,
		Cones = 4,
		Cabin = table.freeze({ 16, 7, 7 }), -- the site office: long, high, deep
		CabinColour = { 240, 190, 40 } :: RGB,
		CabGlass = { 70, 74, 80 } :: RGB,
		HookLine = { 40, 40, 44 } :: RGB,
		-- the tower crane: mast, jib, counter-jib, cab, counterweight, hook line
		Crane = table.freeze({ mast = 70, jib = 44, back = 14, colour = { 245, 196, 40 } }),
	}),

	-- plazas: four lawns round the fountain (each a tree and a bush), food trucks with tables and umbrellas
	Plaza = table.freeze({
		Lawn = 22,
		LawnAt = 50, -- from the middle along each diagonal (x and z)
		LawnColour = { 104, 160, 82 } :: RGB,
		Trucks = 2,
		TruckIds = table.freeze({ "IceCream" }),
		TruckAt = 78, -- from the middle; tried at these turns (radians) until one is clear
		TruckTurns = table.freeze({ 1.571, 4.712, 0.524, 2.618, 3.665, 5.76 }), -- between the planters
		Tables = 2, -- per truck, between it and the fountain
		TableIn = 18, -- from the truck toward the middle
		TableGap = 12, -- apart along the truck
		Table = table.freeze({ 8, 3.4, 4 }), -- the top: long, high, wide
		Wood = { 150, 112, 76 } :: RGB,
		Umbrella = table.freeze({ 8, 9 }), -- pole high, canopy across
		Canopies = table.freeze({
			{ 236, 84, 96 },
			{ 60, 140, 220 },
			{ 250, 210, 70 },
			{ 240, 240, 236 },
		}) :: { RGB },
	}),

	-- roadworks in the kerb lane on the quieter streets: a dug patch, barriers round it, cones before it
	Works = table.freeze({
		Count = 0, -- boxes; 0 keeps within the map's part budget (each box is about 11 parts)
		Kinds = table.freeze({ homes = true, park = true, warehouse = true, parking = true }),
		Spread = 40, -- a box's middle lands up to this far either way of the side's middle
		Patch = table.freeze({ 7, 18 }), -- across, along
		PatchColour = { 104, 80, 60 } :: RGB,
		Barrier = 9, -- each barrier's length
		BarrierHeight = 3.2,
		BarrierColours = table.freeze({ { 236, 110, 30 }, { 240, 240, 236 } }) :: { RGB },
		Cones = 3, -- in a taper before the patch
		ConeGap = 6,
		Cone = { 245, 110, 30 } :: RGB,
		ConeSize = table.freeze({ 2.2, 2.4, 1.3 }), -- base across, high, across
	}),

	-- placements are skipped where they would stand in an existing prop or building
	Clearance = 1,
})
