--!strict
-- The house kit: four house types reused across town (A bungalow, B family house, C corner house with a
-- garage, D townhouse in rows), the palettes they're painted in, and which types each district builds.
-- Studs; colours are { r, g, b }; materials are Enum.Material names.

export type RGB = { number }
export type Palette =
	{ name: string, wall: RGB, trim: RGB, accent: RGB, roof: RGB, material: string }
export type HouseType = { width: number, depth: number, floors: number, perLot: number }

return table.freeze({
	PerSide = 3, -- lots along each of the north and south sidewalks of a home block
	Yard = 4, -- front garden between the sidewalk and the house
	-- its border (YardKit.front, compact) leaves a gap DoorGap either side of the door, and wherever a low part of
	-- the house (lower than Low) reaches more than Proud out from the wall
	Garden = table.freeze({ DoorGap = 2, Proud = 1.5, Low = 4 }), -- (window sills and flower boxes reach 1.2)
	FloorHeight = 12,
	Wall = 1,
	Overhang = 1.5, -- roofs reach this far past the walls
	Plinth = 1.5, -- the darker band along the bottom of every wall
	-- each house's own touches (HouseKit, picked from its name): chances of a roof from the darker set below
	-- instead of its palette's, shutters and flower boxes on its front windows, a canopy over its door, and a
	-- porch (family houses)
	Variety = table.freeze({
		OwnRoof = 0.6,
		Shutters = 0.45,
		Flowers = 0.5,
		Canopy = 0.35,
		Porch = 0.4,
		Roofs = table.freeze({
			{ 58, 62, 70 }, -- charcoal
			{ 150, 62, 48 }, -- brick red
			{ 62, 84, 122 }, -- slate blue
			{ 56, 96, 70 }, -- forest green
			{ 104, 70, 54 }, -- chocolate
			{ 44, 46, 52 }, -- near black
		}),
	}),

	Types = table.freeze({
		A = table.freeze({ width = 30, depth = 26, floors = 1, perLot = 1 }) :: HouseType,
		B = table.freeze({ width = 34, depth = 26, floors = 2, perLot = 1 }) :: HouseType,
		C = table.freeze({ width = 38, depth = 26, floors = 2, perLot = 1 }) :: HouseType,
		D = table.freeze({ width = 16, depth = 24, floors = 3, perLot = 2 }) :: HouseType,
	}),

	-- which types each district builds, by weight
	ByDistrict = table.freeze({
		maple = table.freeze({ A = 0.4, B = 0.35, C = 0.25 }),
		neon = table.freeze({ B = 0.6, C = 0.4 }),
		dock = table.freeze({ A = 0.5, B = 0.5 }),
		stadium = table.freeze({ B = 0.5, C = 0.5 }),
		old = table.freeze({ D = 0.5, B = 0.3, C = 0.2 }),
		canal = table.freeze({ D = 0.5, B = 0.5 }),
	}),

	Palettes = table.freeze({
		{
			name = "Mint Cream",
			wall = { 207, 227, 207 },
			trim = { 255, 255, 255 },
			accent = { 217, 72, 59 },
			roof = { 90, 100, 112 },
			material = "SmoothPlastic",
		},
		{
			name = "Butter",
			wall = { 242, 220, 154 },
			trim = { 255, 250, 240 },
			accent = { 47, 111, 168 },
			roof = { 138, 75, 58 },
			material = "SmoothPlastic",
		},
		{
			name = "Sky Blue",
			wall = { 169, 200, 230 },
			trim = { 255, 255, 255 },
			accent = { 242, 177, 52 },
			roof = { 64, 73, 90 },
			material = "SmoothPlastic",
		},
		{
			name = "Brick Red",
			wall = { 180, 90, 67 },
			trim = { 239, 230, 214 },
			accent = { 46, 94, 78 },
			roof = { 60, 63, 69 },
			material = "Brick",
		},
		{
			name = "Peach",
			wall = { 243, 195, 168 },
			trim = { 255, 255, 255 },
			accent = { 77, 124, 63 },
			roof = { 107, 74, 58 },
			material = "SmoothPlastic",
		},
		{
			name = "Slate",
			wall = { 141, 151, 163 },
			trim = { 244, 244, 242 },
			accent = { 232, 116, 59 },
			roof = { 47, 52, 59 },
			material = "SmoothPlastic",
		},
	}) :: { Palette },
})
