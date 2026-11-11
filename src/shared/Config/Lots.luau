--!strict
-- Life in the town's car parks and yards (LotKit): painted bays with parked cars along the shop rows' backs,
-- behind the office towers and the burger place, parked cars in the ramp lots' bays, picnic tables at the
-- burger place, pallet stacks round the warehouse. Parked cars, dumpsters, tables and pallets are props any
-- vehicle knocks flying. Studs; colours are { r, g, b }.

export type RGB = { number }
export type Yard = {
	bays: number, -- most bays in the row (fewer when the lot is narrow)
	cars: number, -- parked in random bays of the row
	dumpsters: number, -- at the row's ends, against the building
	lamps: number, -- along the lot's far side
	trees: number, -- along the lot's far side, when the lot is at least TreesFrom deep
	island: boolean, -- a planted island down the middle (Island), when the lot is deep enough
}

return table.freeze({
	Bay = table.freeze({ 14, 28 }), -- wide, deep (a parked sedan is about 12 x 25 at the vehicle scale)
	Line = 0.6, -- painted line width
	Edge = 2, -- the bay row stands this far off the lot's edge by the building
	EndClear = 10, -- the row keeps this far off the lot's ends
	TreesFrom = 60, -- a lot this deep has room for trees on its far side
	Ground = 0.11, -- the lots' asphalt top
	CarSink = 0.15, -- parked cars sit this far into the asphalt (the meshes' wheels end a hair below their box)

	-- ReplicatedStorage.VehicleModels[id]; Lot = small enough for the ramp lots' 12-wide bays
	Cars = table.freeze({ "Hatchback", "Hatchback", "Sedan", "Sedan", "Sedan", "Muscle", "Taxi" }), -- picked evenly
	LotCars = table.freeze({ "Hatchback" }),
	KeepFactory = table.freeze({ Taxi = true }), -- these keep their own paint
	Paints = table.freeze({
		{ 236, 236, 232 },
		{ 160, 165, 172 },
		{ 34, 34, 38 },
		{ 200, 40, 36 },
		{ 43, 100, 205 },
		{ 54, 160, 80 },
		{ 120, 130, 150 },
	}) :: { RGB },

	-- per kind of yard
	ShopYard = table.freeze({
		bays = 12,
		cars = 4,
		dumpsters = 2,
		lamps = 2,
		trees = 4,
		island = true,
	}) :: Yard,
	OfficeLot = table.freeze({
		bays = 10,
		cars = 3,
		dumpsters = 0,
		lamps = 0,
		trees = 3,
		island = false,
	}) :: Yard,
	BurgerLot = table.freeze({
		bays = 12,
		cars = 4,
		dumpsters = 1,
		lamps = 2,
		trees = 0,
		island = false,
	}) :: Yard,
	-- the island: one grass part (width across the lot, length as a share of the bay row), trees on it, cars
	-- parked along its building side; `shift` moves it toward the far side
	Island = table.freeze({
		from = 110,
		width = 8,
		height = 0.8,
		length = 0.7,
		trees = 3,
		cars = 2,
		shift = 4,
	}),

	-- the ramp lots' south bay row (Config/Country Lot): these bays (1 = west end) get a car; the rest stay
	-- clear of the south ramp's run
	LotParked = table.freeze({ 1, 2, 8 }),

	-- burger place: rows of picnic tables on its forecourt, on the side away from the sign and drive-through
	Picnic = table.freeze({ rows = 2, gap = 14, rowGap = 14, size = { 8, 3.4, 4 } }), -- size: long, high, wide (the top)
	Wood = { 150, 112, 76 } :: RGB,

	-- warehouse yard: pallet stacks (a pallet and a load of parcels) in the corners front and back
	Pallet = table.freeze({ 7, 1, 7 }),
	Load = table.freeze({ 6, 5, 6 }),
	PalletStacks = 8,
	-- truck lanes painted out from the loading bays (bays: along the front from its middle, to the right
	-- looking out; Places.warehouse puts them in panels 5, 8 and 11 of 12 studs) and stacks between them
	Dock = table.freeze({ bays = { -30, 6, 42 }, lane = 16, length = 30, pallets = { -12, 24 } }),
	Cardboard = { 190, 144, 92 } :: RGB,

	-- the shops' backs (on their car park): a service door and an air-con box on the ground beside it
	Back = table.freeze({
		door = { 5, 9 }, -- wide, high
		doorColour = { 84, 88, 96 },
		ac = { 5, 4, 3.5 }, -- wide, high, deep
		acColour = { 176, 180, 184 },
		WallOut = 0.3, -- the back wall's face stands this far past half the shop's depth
	}),
	Dumpster = table.freeze({ 9, 5, 5 }), -- long, high, deep
	DumpsterColours = table.freeze({ { 46, 110, 70 }, { 40, 80, 140 } }) :: { RGB },
	LampHeight = 18,
})
