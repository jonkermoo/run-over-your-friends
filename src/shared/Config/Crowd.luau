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
	OfficeWorkersMin = 3, -- per office building
	OfficeWorkersMax = 6,
	RestaurantStaff = 4, -- two at the counter, two at the grill
	WarehouseStaff = 8,
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
	HomeStayChance = 0.55, -- a resident at home stays in for another round
	OfficeLunchChance = 0.3, -- an office worker who comes out heads for the restaurant

	-- animation (client): ordinary people use the Rthro set, friends their own
	AnimRadius = 260, -- animate characters this close to the camera; further ones hold still
	RthroIdle = { 2510196951, 2510197257 },
	RthroWalk = 2510202577,
	RthroRun = 2510198475,
	RthroFall = 2510195892,
	WalkAnimSpeed = 9, -- WalkSpeed at which the walk animation plays at normal speed

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
