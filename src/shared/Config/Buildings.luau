--!strict
-- The town buildings in the house-kit style: office towers, shop rows, the burger place and the parcel
-- warehouse. Studs; colours are { r, g, b }; materials are Enum.Material names (Lune checks them).
-- Office and shop walls keep their district's colours and material (Config/Streets).

export type RGB = { number }
export type OfficeLook = { trim: RGB, stone: RGB, roof: RGB }
export type Colours = { wall: RGB, trim: RGB, accent: RGB, roof: RGB, material: string }

return table.freeze({
	-- trim bands are laid in pieces no longer than this, so a hit knocks out a piece, not a whole strip
	BandPiece = 48,
	-- the whole map, measured in Studio; the restyle must keep it under this
	PartBudget = 34000,

	Office = table.freeze({
		PanelWidth = 16, -- wider than other buildings: big windows, fewer parts
		SillShare = 0.25, -- share of each upper floor under the window band (low, so desks and people show)
		DoorHeight = 10,
		CorniceEvery = 3, -- floors between cornice bands (pilasters run between them)
		PilasterEvery = 2, -- panels between pilasters
		Parapet = 3,
		Footprint = { 0.52, 0.75 }, -- tower width and depth, as a share of the block inside its sidewalks
		Setback = 6, -- the tower's front stands this far in from its sidewalk; its car park fills the rest
		Glass = { 96, 140, 170 } :: RGB,
		StoneMaterial = "Limestone", -- the lobby floor
		-- trim, lobby stone and roof per district; the accent is the district's accent
		Looks = table.freeze({
			neon = table.freeze({
				trim = { 230, 226, 214 },
				stone = { 205, 200, 190 },
				roof = { 36, 40, 56 },
			}),
			old = table.freeze({
				trim = { 239, 230, 214 },
				stone = { 216, 205, 184 },
				roof = { 60, 63, 69 },
			}),
			maple = table.freeze({
				trim = { 255, 255, 255 },
				stone = { 200, 192, 176 },
				roof = { 90, 100, 112 },
			}),
			dock = table.freeze({
				trim = { 236, 236, 232 },
				stone = { 176, 172, 164 },
				roof = { 50, 56, 64 },
			}),
			canal = table.freeze({
				trim = { 236, 228, 212 },
				stone = { 196, 184, 166 },
				roof = { 52, 58, 66 },
			}),
			stadium = table.freeze({
				trim = { 250, 250, 250 },
				stone = { 190, 190, 196 },
				roof = { 44, 50, 70 },
			}),
		}) :: { [string]: OfficeLook },
	}),

	Shops = table.freeze({
		PerBlock = 4, -- shop fronts in the row
		Depth = 60,
		Setback = 4, -- forecourt between the sidewalk and the shop fronts
		GroundHeight = 14, -- the shop floor; flats above use the house floor height
		Floors = { 2, 3 }, -- fewest, most
		Door = 5,
		AwningStripes = 8,
		AwningDepth = 4.5,
		AwningWhite = { 250, 250, 245 } :: RGB,
		Sign = { 7, 2.2 }, -- the hanging sign: reach from the wall, height
		-- parody high street, one name per shop in turn
		Names = table.freeze({
			"SOCK SHOP",
			"BUN BAKERY",
			"BIKE BITS",
			"BOOK NOOK",
			"TOY BOX",
			"PHONE FIX",
			"FRESH FRUIT",
			"HAT HUT",
			"PET PALS",
			"SNACK SHACK",
			"LAMP LAND",
			"CHEESE PLEASE",
		}),
		-- inside each shop: what stands on its islands and in its window (a kind from IslandKinds) and the
		-- colours of the goods on its shelves
		IslandKinds = table.freeze({
			"Table",
			"Case",
			"Rack",
			"Bikes",
			"Crates",
			"Lamps",
			"Tanks",
			"Stands",
		}),
		Themes = table.freeze({
			["SOCK SHOP"] = {
				island = "Rack",
				goods = { { 220, 70, 90 }, { 70, 130, 210 }, { 250, 200, 60 } },
			},
			["BUN BAKERY"] = {
				island = "Case",
				goods = { { 214, 160, 90 }, { 180, 120, 64 }, { 240, 214, 170 } },
			},
			["BIKE BITS"] = {
				island = "Bikes",
				goods = { { 40, 40, 46 }, { 200, 60, 50 }, { 160, 166, 174 } },
			},
			["BOOK NOOK"] = {
				island = "Table",
				goods = { { 150, 50, 50 }, { 50, 90, 150 }, { 70, 120, 70 } },
			},
			["TOY BOX"] = {
				island = "Table",
				goods = { { 240, 80, 60 }, { 60, 170, 240 }, { 250, 210, 50 } },
			},
			["PHONE FIX"] = {
				island = "Case",
				goods = { { 30, 32, 38 }, { 200, 204, 210 }, { 80, 140, 220 } },
			},
			["FRESH FRUIT"] = {
				island = "Crates",
				goods = { { 230, 60, 50 }, { 250, 170, 40 }, { 110, 180, 60 } },
			},
			["HAT HUT"] = {
				island = "Stands",
				goods = { { 60, 50, 44 }, { 200, 170, 120 }, { 170, 40, 50 } },
			},
			["PET PALS"] = {
				island = "Tanks",
				goods = { { 200, 150, 90 }, { 90, 160, 210 }, { 230, 120, 60 } },
			},
			["SNACK SHACK"] = {
				island = "Table",
				goods = { { 230, 60, 50 }, { 250, 200, 40 }, { 60, 120, 200 } },
			},
			["LAMP LAND"] = {
				island = "Lamps",
				goods = { { 255, 220, 150 }, { 120, 100, 80 }, { 230, 230, 220 } },
			},
			["CHEESE PLEASE"] = {
				island = "Case",
				goods = { { 250, 210, 80 }, { 240, 180, 50 }, { 250, 236, 190 } },
			},
		}) :: { [string]: { island: string, goods: { RGB } } },
	}),

	Restaurant = table.freeze({
		Colours = table.freeze({
			wall = { 196, 44, 40 },
			trim = { 246, 236, 214 },
			accent = { 250, 196, 40 },
			roof = { 75, 58, 50 },
			material = "SmoothPlastic",
		}) :: Colours,
		Height = 16,
		Wall = 1.5,
		KneeShare = 0.62, -- barn roof: the knee sits this share of the half-width from the middle
		KneeRise = 10,
		PeakRise = 19,
		DriveThru = { 24, 20 }, -- canopy reach from the side wall, length along it
		Tables = { -0.32, -0.12, 0.12, 0.32 }, -- across the width (share of it), a chair either side
		TableZ = 0.28, -- toward the street (share of the depth)
	}),

	Warehouse = table.freeze({
		Colours = table.freeze({
			wall = { 150, 156, 166 },
			trim = { 38, 92, 170 },
			accent = { 255, 140, 20 },
			roof = { 80, 86, 96 },
			material = "Metal",
		}) :: Colours,
		Wall = 2,
		Panel = 12,
		Pilasters = { 3, 6, 9, 12 }, -- panel boundaries along the front with a blue pilaster
		Windows = { 1, 2, 13, 14 }, -- upper-row panels with a framed window (clear of the sign)
		Parapet = 2.5,
	}),
})
