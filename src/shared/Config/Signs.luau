--!strict
-- The map's signs as drawn brand artwork (tools/signs: a cartoon emblem and lettering per brand, each image the
-- aspect of its board): image ids by sign key. A board whose key has an image shows it as a Decal on each face
-- it used to letter; a key with no image keeps the old text sign.

return table.freeze({
	Images = table.freeze({
		-- the spawn plaza's food stalls (World.SpawnPlaza.Stalls, by text)
		["Stall_HOT DOGS"] = 118804476036121,
		["Stall_ICE CREAM"] = 130706810152573,
		["Stall_TACOS"] = 111447917913796,
		["Stall_DONUTS"] = 77434219695600,
		-- Burger Barn: hay-loft panel, pole sign, drive-thru, menu board
		BarnLoft = 77451616699400,
		BarnPole = 98657571652677,
		BarnDrive = 75598660178530,
		BarnMenu = 138855249538444,
		ParcelPlanet = 70451666684499,
		Hero = 92819554770798, -- the game's name on the tower over spawn
		-- office name signs (Crowd.OfficeNames)
		["Office_Synergy Corp"] = 132486570068934,
		["Office_Paperclip Inc."] = 121505841553209,
		["Office_MegaCorp"] = 138117602727697,
		["Office_Cubicle & Co."] = 93162852321046,
		["Office_Spreadsheet Systems"] = 85628681849167,
		["Office_Big Meeting LLC"] = 123027361005078,
		["Office_Quarterly Partners"] = 100380428252948,
		["Office_Memo Group"] = 113135400364893,
		-- the high street's hanging signs (Buildings.Shops.Names)
		["Shop_SOCK SHOP"] = 98683036539719,
		["Shop_BUN BAKERY"] = 89961060544634,
		["Shop_BIKE BITS"] = 117118527347850,
		["Shop_BOOK NOOK"] = 77551470937522,
		["Shop_TOY BOX"] = 94375504012429,
		["Shop_PHONE FIX"] = 98245542563987,
		["Shop_FRESH FRUIT"] = 140523392385798,
		["Shop_HAT HUT"] = 114990660187474,
		["Shop_PET PALS"] = 120934429948485,
		["Shop_SNACK SHACK"] = 120742782393804,
		["Shop_LAMP LAND"] = 75274410470123,
		["Shop_CHEESE PLEASE"] = 87058201246165,
		-- billboards on office roofs and by the country road (Streets.Billboards)
		["Ad_SNAKKO CHIPS"] = 87391147825299,
		["Ad_DRINK FIZZLE"] = 129616879500589,
		["Ad_SPEED BUMPS R US"] = 124543416740879,
		["Ad_CLEAN SOCKS DAILY"] = 87787234449518,
		["Ad_TRY THE BARN BURGER"] = 118966401928679,
		["Ad_HONK IF YOU'RE HAPPY"] = 88233540722529,
		["Ad_MEGACORP IS HIRING"] = 118387770842495,
		-- the country road
		Gas = 136388751641387,
		GasPrice = 135700971275511, -- draws Country.GasStation.Price ($2.49): redraw it if the price changes
		Mart = 114079575259639,
		Motocross = 73615613105000,
		-- the outskirts
		StuntPark = 76646366842186,
		["Hoard_MEGACORP TOWER"] = 119368425241724,
		["Hoard_COMING SOON"] = 80657274001077,
		-- the suburbs' entrance boards (Suburbs, by name)
		["Suburb_SUNNY VALE"] = 84287036960584,
		["Suburb_OAK HOLLOW"] = 76708715910788,
		["Suburb_SEASIDE"] = 91984929523304,
	}),
	-- images that repeat along a long board (a Texture) instead of stretching over it: tile width per stud of height
	Tiled = table.freeze({
		["Hoard_MEGACORP TOWER"] = 8,
		["Hoard_COMING SOON"] = 8,
	}),
	OfficeAspect = 7.5, -- an office name board keeps its art's width:height, however narrow the tower
})
