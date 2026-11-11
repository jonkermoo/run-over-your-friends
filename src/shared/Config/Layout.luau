--!strict
-- How the screen UI fits small screens: everything is laid out at desktop size and drawn smaller when the
-- screen has less room than the layout needs (Rules/Layout, Style.fit). The numbers are GUI pixels.

return table.freeze({
	RefWidth = 1000, -- narrower than this and the UI shrinks
	RefHeight = 560, -- shorter than this and the UI shrinks: the garage's SPAWN row needs this much
	MinScale = 0.6, -- never smaller, so text stays readable

	-- the phone driving buttons stay at least this big, however much the rest shrinks
	TouchMinScale = 0.85,
	-- they sit above Roblox's jump button, which is smaller on small screens
	SmallScreen = 500, -- short side at or under this counts as small (Roblox's own touch-button rule)
	TouchClearSmall = 100,
	TouchClearLarge = 196,
	-- the buttons sit on a grid: TouchKey px keys every TouchPitch px. Slots are {column, row} from the
	-- rack's top-left; row -1 is the top row (VIEW / HONK / STUCK?) over the main block.
	TouchPitch = 80,
	TouchKey = 74,
	TouchSlots = table.freeze({
		View = { 0, -1 },
		Honk = { 1, -1 },
		Stuck = { 2, -1 },
		Feature = { 1, 0 },
		Fly = { 2, 0 },
		RollL = { 0, 1 },
		RollR = { 1, 1 },
		Boost = { 2, 1 },
	}),
	-- on short screens, where that top row would reach the cash box (top right), it folds into the empty
	-- slot and a column on the left: a wider rack two rows tall
	TouchSlotsWide = table.freeze({
		View = { 0, 0 },
		Honk = { -1, 0 },
		Stuck = { -1, 1 },
		Feature = { 1, 0 },
		Fly = { 2, 0 },
		RollL = { 0, 1 },
		RollR = { 1, 1 },
		Boost = { 2, 1 },
	}),
	TouchCashGap = 8, -- layout px kept clear under the cash box

	-- the event card (top centre) on short screens: a one-line strip; a tap opens the full card, which folds
	-- back after EventOpenSeconds or on another tap
	EventStripBelow = 600, -- GUI height in real px under which the strip is used (every phone held sideways)
	EventStripWidth = 290,
	EventStripHeight = 30,
	EventOpenSeconds = 6,

	-- Roblox's dynamic thumbstick takes touches on the left of the screen, from a third of the way down
	ThumbZoneWidth = 0.4,
	ThumbZoneTop = 1 / 3,

	-- world labels (name tags, the tutorial arrow's word, landing text) shrink with the UI on small screens,
	-- but never below this, so their few words stay readable
	BillboardMinScale = 0.8,

	TapPad = 12, -- extra touch area around small buttons on touch screens
})
