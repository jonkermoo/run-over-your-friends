--!strict
-- The town buildings in the house-kit style: office towers, shop rows, the burger place and the parcel
-- warehouse. Studs; colours are { r, g, b }; materials are Enum.Material names (Lune checks them).
-- Office and shop walls take their district's warm facade mix (Facades below) and its material (Config/Streets).

export type RGB = { number }
export type OfficeLook = { stone: RGB, roof: RGB }
export type Colours = { wall: RGB, trim: RGB, accent: RGB, roof: RGB, material: string }

return table.freeze({
	-- trim bands are laid in pieces no longer than this, so a hit knocks out a piece, not a whole strip
	BandPiece = 48,
	SidePanel = 12, -- a house's side wall counts for one piece per this many studs of its length
	-- the whole map, measured in Studio (about 87,000 with the suburbs); with streaming on, each player only
	-- loads what is near them, so this caps the server's map, not a phone's
	PartBudget = 100000,

	-- each building's wall colour, drawn per building from its district's mix (shops, the hero tower and, with
	-- Office.FacadeSpandrels, every tower's spandrels): warm so the city doesn't read white, grey and blue from
	-- the air; the district's wall material (Config/Streets) goes on these colours
	Facades = table.freeze({
		-- downtown: cream and mint listed twice (twice as likely), so the two reds come up a quarter of the time
		neon = {
			{ 232, 216, 190 },
			{ 232, 216, 190 },
			{ 168, 212, 190 },
			{ 168, 212, 190 },
			{ 240, 220, 168 },
			{ 198, 112, 82 },
			{ 226, 132, 108 },
			{ 96, 104, 140 },
		},
		old = {
			{ 170, 82, 60 },
			{ 196, 112, 80 },
			{ 230, 210, 176 },
			{ 222, 126, 100 },
			{ 210, 158, 92 },
		},
		maple = {
			{ 242, 230, 206 },
			{ 188, 222, 198 },
			{ 240, 178, 158 },
			{ 244, 222, 164 },
			{ 246, 206, 182 },
		},
		dock = {
			{ 150, 74, 58 },
			{ 196, 150, 72 },
			{ 72, 122, 118 },
			{ 154, 142, 128 },
			{ 214, 204, 184 },
		},
		canal = {
			{ 150, 70, 52 },
			{ 196, 112, 80 },
			{ 232, 214, 182 },
			{ 160, 202, 182 },
			{ 224, 130, 106 },
		},
		stadium = {
			{ 234, 222, 198 },
			{ 226, 132, 108 },
			{ 220, 140, 40 },
			{ 196, 112, 80 },
			{ 40, 50, 76 },
		},
	}) :: { [string]: { RGB } },

	Office = table.freeze({
		PanelWidth = 16, -- wider than other buildings: big windows, fewer parts
		SillShare = 0.25, -- share of each upper floor under the window band (low, so desks and people show)
		DoorHeight = 10,
		CorniceEvery = 3, -- floors between cornice bands (pilasters run between them)
		PilasterEvery = 2, -- panels between pilasters
		-- above the lobby, this many panels share one spandrel and one pane of glass (fewer parts); each piece
		-- still counts as that many when smashed (the "Pieces" attribute), so pay and goals don't change
		UpperPanels = 3,
		Parapet = 3,
		Footprint = { 0.52, 0.75 }, -- tower width and depth, as a share of the block inside its sidewalks
		Setback = 6, -- the tower's front stands this far in from its sidewalk; its car park fills the rest
		Glass = { 96, 140, 170 } :: RGB,
		StoneMaterial = "Limestone", -- the lobby floor
		-- every tower gets its own glass tint and a crown on the back half of its roof (TowerKit), taken in
		-- turn so neighbours differ; the towers this close to the middle of town (in blocks) stand taller
		Tints = table.freeze({
			{ 96, 140, 170 },
			{ 80, 150, 140 },
			{ 150, 122, 92 },
			{ 150, 162, 178 },
			{ 66, 98, 140 },
			{ 120, 160, 120 },
		}) :: { RGB },
		Crowns = table.freeze({
			"penthouse",
			"spire",
			"garden",
			"pyramid",
			"helipad",
			"watertower",
			"fins",
			"dome",
		}),
		DowntownReach = 1.5,
		DowntownFloors = { 10, 13 },
		-- the hero tower: the office nearest the spawn plaza stands this tall, faces the plaza, wears its own
		-- glass and trim, a spire crown, and the game's name on its roof
		Hero = table.freeze({
			Floors = 22,
			Glass = { 44, 96, 170 },
			Accent = { 255, 208, 0 },
			Trim = { 236, 236, 240 },
			Crown = "spire",
			Sign = "RUN OVER YOUR FRIENDS",
			SignSize = { 64, 13 },
		}),
		RoofTrees = table.freeze({ trunk = { 5, 8 }, crown = { 7, 10 }, shade = 0.25 }), -- the roof garden's
		CrownColours = table.freeze({
			copper = { 92, 158, 132 },
			water = { 132, 96, 64 },
			pad = { 58, 60, 66 },
			grass = { 92, 150, 70 },
		}),
		-- every tower's own frame (pilasters, sill bands, cornices: `trim`) and the panels under its windows
		-- (`spandrel`, used only with FacadeSpandrels off), taken in turn (every FrameStride-th) so neighbours
		-- differ; the hero keeps Hero.Trim
		Frames = table.freeze({
			table.freeze({ trim = { 62, 66, 76 }, spandrel = { 128, 134, 144 } }), -- charcoal
			table.freeze({ trim = { 238, 230, 214 }, spandrel = { 190, 112, 82 } }), -- cream on terracotta
			table.freeze({ trim = { 148, 110, 74 }, spandrel = { 214, 192, 156 } }), -- bronze on sand
			table.freeze({ trim = { 118, 148, 128 }, spandrel = { 222, 224, 212 } }), -- sage
			table.freeze({ trim = { 74, 92, 128 }, spandrel = { 214, 218, 226 } }), -- slate blue
			table.freeze({ trim = { 246, 246, 244 }, spandrel = { 160, 86, 68 } }), -- white on brick
			table.freeze({ trim = { 212, 186, 140 }, spandrel = { 120, 104, 92 } }), -- sand on umber
		}) :: { { trim: RGB, spandrel: RGB } },
		FrameStride = 3,
		-- true: a tower's spandrels take its facade colour (Facades) and only the frame comes from Frames
		FacadeSpandrels = true,
		-- the ground floor of the three street faces (not the back, on the car park): shop windows, each bay
		-- with a coloured fascia and a sloping awning (no collisions); a tower takes two neighbouring colours
		Shopfront = table.freeze({
			Colours = table.freeze({
				{ 214, 84, 72 }, -- tomato
				{ 236, 170, 60 }, -- mustard
				{ 46, 134, 128 }, -- teal
				{ 64, 112, 72 }, -- forest
				{ 60, 84, 140 }, -- navy
				{ 150, 52, 72 }, -- berry
			}) :: { RGB },
			Fascia = 3, -- the coloured band over the window
			LobbyFascia = 3, -- the stone band over a front lobby window when a tower has no shopfront colours
			AwningDepth = 4.5,
			AwningThick = 0.4,
			AwningTilt = 0.3, -- radians down toward the street
			AwningInset = 1, -- each awning stops this short of its bay's edges
		}),
		-- a little clutter on the front half of the roof (TowerKit.clutter), on a grid of Slot-stud squares:
		-- air-con units (a box with a fan on top), vent pipes, the odd stair hut
		Roof = table.freeze({
			Slot = 11,
			Margin = 6, -- clear of the parapet
			Chance = { ac = 0.25, vent = 0.15, hut = 0.04 }, -- per slot, else empty
			Near = 2, -- the zone starts this far in front of the roof's middle (the billboard posts stand 10 back)
			MinZone = 6, -- no clutter on a roof whose zone is shallower than this
			Jitter = { 0.3, 0.7 }, -- where in its slot a unit stands (share of Slot), each way
			Ac = { 7, 4, 5 }, -- wide, tall, deep
			Fan = { 3, 0.5 }, -- across, tall
			Vent = { 1.2, 4 }, -- across, tall
			Hut = { 9, 7, 8 },
			AcColour = { 206, 208, 210 } :: RGB,
			FanColour = { 70, 74, 80 } :: RGB,
			VentColour = { 150, 154, 160 } :: RGB,
			Seed = 5170,
		}),
		-- lobby stone and roof per district (the trim is the tower's frame); the accent is the district's accent
		Looks = table.freeze({
			neon = table.freeze({
				stone = { 205, 200, 190 },
				roof = { 36, 40, 56 },
			}),
			old = table.freeze({
				stone = { 216, 205, 184 },
				roof = { 60, 63, 69 },
			}),
			maple = table.freeze({
				stone = { 200, 192, 176 },
				roof = { 90, 100, 112 },
			}),
			dock = table.freeze({
				stone = { 176, 172, 164 },
				roof = { 50, 56, 64 },
			}),
			canal = table.freeze({
				stone = { 196, 184, 166 },
				roof = { 52, 58, 66 },
			}),
			stadium = table.freeze({
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
		-- a big icon of what each shop sells on its roof (TownKit icon kinds), on a post this tall
		IconLift = 3,
		Icons = table.freeze({
			["SOCK SHOP"] = "sock",
			["BUN BAKERY"] = "donut",
			["BIKE BITS"] = "wheel",
			["BOOK NOOK"] = "book",
			["TOY BOX"] = "gift",
			["PHONE FIX"] = "phone",
			["FRESH FRUIT"] = "apple",
			["HAT HUT"] = "hat",
			["PET PALS"] = "bone",
			["SNACK SHACK"] = "lolly",
			["LAMP LAND"] = "bulb",
			["CHEESE PLEASE"] = "cheese",
		}),
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
