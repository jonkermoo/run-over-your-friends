--!strict
-- The city's people and the buildings they use: how many, where they live and work, what they wear,
-- how far from a player they show up, and the names on the signs. Studs and seconds.
-- Colours are { r, g, b } (0-255) so Lune can test them.

export type RGB = { number }

return table.freeze({
	-- who lives in the city
	Walkers = 160, -- casual people out on the sidewalks
	ResidentsMin = 1, -- per home
	ResidentsMax = 3,
	OfficeWorkersMin = 5, -- per office building
	OfficeWorkersMax = 9,
	Receptionists = 1, -- per office, at the lobby desk
	ShopStaff = 1, -- per shop, behind the counter
	RestaurantStaff = 4, -- two at the counter, two at the grill
	WarehouseStaff = 10,
	Spectators = 14, -- watching at the stunt park
	FriendEvery = 6, -- one person in this many wears a friend's avatar (never staff in uniform)

	-- showing people only near players keeps a big city cheap
	MaxActive = 90, -- built characters in the world at once (all players together)
	ActivateRadius = 330, -- outdoors: build a character this close to a player...
	DeactivateRadius = 400, -- ...and put it away past this
	IndoorRadius = 150, -- people inside buildings show only this close
	IndoorLeave = 190,
	BuildsPerTick = 4, -- new characters made per think tick (avatar building is slow)
	PoolSpare = 24, -- spare ordinary characters kept ready
	FriendRigsMax = 30, -- built friend characters kept (each friend avatar is its own rig)
	-- Studio test players (Test tab, Clients: 2) have no Roblox friends, so in Studio test player N (user id
	-- -N) gets list N here as its friends (real accounts, so their avatars load); lists wrap round
	StudioFakeFriends = table.freeze({
		table.freeze({ 1, 156, 261 }), -- Roblox, builderman, Shedletsky
		table.freeze({ 2, 3 }), -- John Doe, Jane Doe
	}) :: { { number } },
	ThinkSeconds = 0.25,
	RecallDistance = 900, -- a walker this far from every player...
	RecallChance = 0.08, -- ...has this chance per half second...
	RecallMin = 240, -- ...to reappear on a sidewalk this far from a player
	RecallMax = 320,

	-- moving
	SpeedMin = 0.85, -- times World.Npc.WalkSpeed, per person
	SpeedMax = 1.15,
	WaypointReach = 2.6,
	LaneJitter = 3.5, -- people spread across the sidewalk instead of walking one line
	StuckSeconds = 2.5,
	PauseChance = 0.12, -- chance to stop at a sidewalk corner for a moment
	PauseMin = 2,
	PauseMax = 6,
	SpotIdleMin = 6, -- standing at a counter, desk, shelf or window
	SpotIdleMax = 18,
	InsideMin = 20, -- out of sight inside a building
	InsideMax = 70,
	HomeStayChance = 0.8, -- a resident at home stays in for another round (homes look lived in)
	HomeSpotChance = 0.85, -- a resident at home sits or stands somewhere you can see (else out of sight)
	OfficeStayChance = 0.75, -- an office worker at work stays in for another round
	OfficeSpotChance = 0.85, -- an office worker inside sits at a desk or in the lobby (else out of sight)
	ShopSpotChance = 0.75, -- a shopper browses somewhere you can see (else out of sight)
	OfficeLunchChance = 0.3, -- an office worker who comes out heads for the restaurant

	-- reacting to traffic (Rules/Reactions): a vehicle coming at someone gets one roll to dodge; a crash
	-- nearby sends people running. Speeds in m/s, the rest studs and seconds.
	React = table.freeze({
		Look = 1.1, -- seconds ahead they notice a vehicle coming
		Reach = 3, -- studs beside its path that still counts as in the way (people are Game.BodyScale big)
		MinSpeed = 4, -- slower vehicles are ignored
		SlowSpeed = 8, -- at or under this, DodgeSlow...
		FastSpeed = 30, -- ...falling to DodgeFast at this (75 mph is about 33 m/s)
		DodgeSlow = 0.35,
		DodgeFast = 0.08,
		DodgeStep = 10, -- how far they jump aside
		DodgeSeconds = 1,
		RollAgain = 1.5, -- seconds before the same vehicle gets another roll on them
		FleeRadius = 60, -- after a knock-down, people this close...
		FleeChance = 0.8, -- ...this often...
		FleeDistance = 50, -- ...run this far away from it...
		FleeSeconds = 4, -- ...for this long
		ScreamVoices = 3, -- client: panicked screams at once round a crash
	}),

	-- animation (client): ordinary people use the Rthro set, friends their own
	AnimRadius = 260, -- animate characters this close to the camera; further ones hold still
	RthroIdle = { 2510196951, 2510197257 },
	RthroWalk = 2510202577,
	RthroRun = 2510198475,
	RthroFall = 2510195892,
	WalkAnimSpeed = 9, -- WalkSpeed at which the walk animation plays at normal speed (for an everyday-sized person)
	WalkAnimMin = 0.5, -- the walk animation's speed is held between these (Rules/Crowd.walkAnimSpeed)
	WalkAnimMax = 1.6,
	-- rigs bigger than everyday size (the giant): their animation's hip sway is scaled twice by the engine,
	-- so it's cut back to scale with the body, and the body lifted so the feet stay on the ground
	-- (client/Crowd, Rules/Crowd.bigSway)
	BigRig = table.freeze({
		MinSize = 1.5, -- times an everyday person; smaller rigs are left alone
		LiftPerSize = 0.32, -- studs the hips go up per size step: an everyday person's feet dip about this far
	}),

	-- clothes
	Skin = table.freeze({
		{ 255, 224, 196 },
		{ 241, 194, 156 },
		{ 214, 160, 118 },
		{ 176, 120, 82 },
		{ 128, 84, 56 },
		{ 92, 60, 40 },
	}) :: { RGB },
	Hair = table.freeze({ 63690008, 376548738, 451220849, 451221329, 16630147 }),
	-- everyday people look like basic Roblox avatars: the classic head, a classic face, and free classic
	-- clothes made by Roblox (catalog ids; each is loaded once at start). Casual.Shirts/Pants colours are the
	-- fallback if an item doesn't load.
	Avatar = table.freeze({
		Head = 86498048, -- "Man Head", shows classic faces
		Faces = table.freeze({
			144075659,
			7074786,
			7074729,
			209995366,
			7075434,
			141728790,
			7131886,
		}),
		Shirts = table.freeze({
			144076358, -- Blue and Black Motorcycle Shirt
			144076436, -- Grey Striped Shirt with Denim Jacket
			382537085, -- I <3 Pizza Shirt
			382538295, -- Guitar Tee with Black Jacket
			382538059, -- Green Jersey
			382537702, -- Teal Shirt
			398634295, -- Pastel Starburst Top with Gray Jacket
			398635081, -- Blue Plaid Shirt
			398633584, -- Denim Jacket with White Hoodie
			607785314, -- ROBLOX Jacket
			855766176, -- Roblox Green Shirt
			855768342, -- Roblox Orange Shirt
			855777286, -- Roblox Purple Shirt
			855779323, -- Roblox Yellow Shirt
		}),
		Pants = table.freeze({
			144076760, -- Dark Green Jeans
			382537569, -- Black Jeans
			382538503, -- Black Jeans with Sneakers
			382537806, -- Jean Shorts
			382537950, -- Jean Shorts with White Shoes
			398634487, -- Beautiful You Jeans
			398633812, -- Black Jeans with White Shoes
			855781078, -- Roblox Green Shorts
		}),
		Hats = table.freeze({ 607702162 }), -- Roblox Baseball Cap
		HatChance = 0.15,
	}),
	-- name tags over friends and giants, drawn on each player's own screen (client/NameTags)
	Tags = table.freeze({
		FadeFrom = 30, -- studs from the camera where a tag starts to fade
		FadeTo = 45, -- gone from here
		GiantFadeFrom = 120,
		GiantFadeTo = 170,
		Lift = 1.3, -- studs above the top of the head
		Width = 240, -- tag box in pixels (text is centred in it); world labels shrink on small screens
		Height = 60,
		FadeEvery = 0.1, -- seconds between fade updates
		Mine = { 255, 208, 0 } :: RGB, -- your own friends: road yellow, big and bold
		MineSize = 20, -- text height in pixels (name), sub-line is half
		-- your own friends also get a yellow outline (only where you can see them) and a longer-range tag
		MineFadeFrom = 80,
		MineFadeTo = 110,
		MaxOutlines = 12, -- outlines drawn at once, nearest first (Roblox draws at most 31 highlights)
		OtherSize = 16, -- another player's friends: smaller, in one of these colours (fixed per friend)
		Others = table.freeze({
			{ 120, 220, 255 },
			{ 255, 130, 200 },
			{ 150, 240, 120 },
			{ 255, 160, 90 },
			{ 190, 160, 255 },
			{ 110, 240, 210 },
		}) :: { RGB },
		Giant = { 255, 84, 60 } :: RGB,
		GiantSize = 24,
	}),
	Casual = table.freeze({
		Shirts = table.freeze({
			{ 52, 120, 200 },
			{ 200, 60, 60 },
			{ 60, 160, 90 },
			{ 230, 190, 60 },
			{ 120, 80, 170 },
			{ 240, 240, 240 },
			{ 40, 40, 46 },
			{ 240, 140, 160 },
			{ 90, 190, 200 },
			{ 150, 110, 80 },
		}) :: { RGB },
		Pants = table.freeze({
			{ 52, 76, 120 },
			{ 70, 96, 150 },
			{ 190, 170, 130 },
			{ 36, 36, 40 },
			{ 110, 110, 116 },
			{ 70, 90, 60 },
		}) :: { RGB },
		Shoes = table.freeze({
			{ 240, 240, 240 },
			{ 30, 30, 34 },
			{ 120, 80, 50 },
			{ 200, 60, 60 },
		}) :: { RGB },
		ShortSleeves = 0.6,
		CapChance = 0.2,
	}),
	Food = table.freeze({
		Shirt = { 205, 45, 40 } :: RGB,
		Pants = { 34, 34, 38 } :: RGB,
		Cap = { 250, 200, 40 } :: RGB,
		Apron = { 245, 245, 240 } :: RGB,
	}),
	Shop = table.freeze({
		Aprons = table.freeze({ { 40, 110, 70 }, { 160, 40, 50 }, { 40, 70, 140 }, { 90, 60, 40 } }) :: { RGB },
	}),
	Warehouse = table.freeze({
		Shirts = table.freeze({ { 40, 56, 90 }, { 90, 92, 98 } }) :: { RGB },
		Pants = table.freeze({ { 52, 76, 120 }, { 36, 36, 40 } }) :: { RGB },
		Vest = { 255, 140, 20 } :: RGB,
		Stripe = { 225, 225, 225 } :: RGB,
	}),
	Office = table.freeze({
		Shirts = table.freeze({ { 245, 245, 245 }, { 196, 216, 240 }, { 240, 210, 220 } }) :: { RGB },
		Pants = table.freeze({ { 48, 50, 58 }, { 34, 40, 64 }, { 28, 28, 30 } }) :: { RGB },
		Ties = table.freeze({ { 150, 30, 40 }, { 30, 60, 130 }, { 40, 90, 60 }, { 80, 40, 90 } }) :: { RGB },
		JacketChance = 0.5,
	}),

	-- buildings (parody names only)
	RestaurantName = "Burger Barn",
	WarehouseName = "Parcel Planet",
	OfficeNames = table.freeze({
		"Synergy Corp",
		"Paperclip Inc.",
		"MegaCorp",
		"Cubicle & Co.",
		"Spreadsheet Systems",
		"Big Meeting LLC",
		"Quarterly Partners",
		"Memo Group",
	}),
	RestaurantSize = { 84, 58 },
	WarehouseSize = { 168, 112 },
	WarehouseHeight = 30,
})
