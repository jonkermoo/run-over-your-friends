--!strict
-- How the screen UI fits small screens: everything is laid out at desktop size and drawn smaller when the
-- screen has less room than the layout needs (Rules/Layout, Style.fit). The numbers are GUI pixels.

return table.freeze({
	RefWidth = 1000, -- narrower than this and the UI shrinks
	RefHeight = 596, -- shorter than this and the UI shrinks: the garage's SPAWN row needs this much
	MinScale = 0.6, -- never smaller, so text stays readable

	-- the menu sheets (Garage, Store, Goals) stay between the menu strip and the bottom margin and sit in
	-- the middle of the screen when they're shorter than that (Rules/Layout.sheetCentre)
	SheetTop = 104,
	SheetBottom = 18,
	SheetMaxWidth = 1100, -- the garage and store sheet never grows past this on big screens
	SheetMaxHeight = 760,
	-- the garage, two pages: every vehicle in a list (GarageColumns across, rows GarageRowHeight tall), then
	-- one vehicle's page: its picture (GaragePictureShare of the width) over its SPAWN / BUY button, and the
	-- STATS / UPGRADES / PAINT / DECALS tabs beside it (client/UpgradePanel)
	GarageColumns = 2,
	GarageRowHeight = 70,
	GarageHeader = 70, -- the title row: BACK, the name, < >, X (GarageHeaderButton square)
	GarageHeaderButton = 48, -- sits 11 px down, clear of the sign's edge and the header line
	GaragePictureShare = 0.45,
	GarageActionHeight = 70,
	GarageTabsHeight = 60,
	GoalsWidth = 420, -- the goals sheet, which hangs from the top left

	-- the phone driving buttons stay at least this big, however much the rest shrinks
	TouchMinScale = 0.85,
	SmallScreen = 500, -- short side at or under this counts as small (Roblox's own touch-button rule)
	-- they fan out from Roblox's jump button: slots are {left, up} steps from it (the jump button is {0, 0});
	-- the first step clears the jump button's edge by TouchGap, each further step is TouchPitch. Layout px.
	TouchPitch = 80,
	TouchKey = 74,
	TouchGap = 5,
	TouchSlots = table.freeze({
		Honk = { 1, 0 },
		Fly = { 2, 0 },
		View = { 0, 1 },
		Feature = { 1, 1 },
		Stuck = { 2, 1 },
		RollR = { 0, 2 },
		RollL = { 1, 2 },
		Boost = { 2, 2 },
	}),
	-- where Roblox puts its jump button when it can't be read from the screen (TouchGui): size and its gaps to
	-- the right and bottom edges, real px, on small and large screens
	JumpSmall = table.freeze({ size = 70, right = 25, bottom = 20 }),
	JumpLarge = table.freeze({ size = 120, right = 50, bottom = 90 }),

	-- Roblox's dynamic thumbstick takes touches on the left of the screen, from a third of the way down
	ThumbZoneWidth = 0.4,
	ThumbZoneTop = 1 / 3,

	-- world labels (name tags, the tutorial arrow's word, landing text) shrink with the UI on small screens,
	-- but never below this, so their few words stay readable
	BillboardMinScale = 0.8,

	-- the HUD (layout px). Top left: the menu, square tiles on an asphalt bar with a lane line, each tile's icon
	-- poking out of its top and its name on its bottom edge. Top right: one column, Right in from the edge:
	-- the settings tile beside the cash, then the next-car road, then the gift; the feed runs on under them.
	Menu = table.freeze({
		Left = 14,
		Top = 4,
		Tile = 64,
		Gap = 14,
		Pad = 14,
		Height = 92,
		Icon = 54,
		Poke = 14,
	}),
	Column = table.freeze({
		Right = 14,
		Top = 12,
		Width = 284,
		CashWidth = 220,
		Gap = 12,
		Row = 54, -- the cash and the settings tile
		NextCar = 74,
		Gift = 50,
		FeedTop = 12 + 54 + 74 + 50 + 12 * 3, -- under the gift: Top + Row + NextCar + Gift + 3 gaps
	}),

	TapPad = 12,
	-- a store section counts as in view once its top is within this many layout px of the page's top
	SectionSlack = 40, -- extra touch area around small buttons on touch screens
})
