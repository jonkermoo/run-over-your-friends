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

	-- Roblox's dynamic thumbstick takes touches on the left of the screen, from a third of the way down
	ThumbZoneWidth = 0.4,
	ThumbZoneTop = 1 / 3,

	TapPad = 12, -- extra touch area around small buttons on touch screens
})
