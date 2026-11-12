--!strict
-- How big the cheers, pointers and world labels are drawn, and where the centre-screen ones sit. Text sizes
-- are layout pixels: screen text shrinks with the rest of the UI on small screens (Config/Layout), world
-- labels (billboards) by Layout.BillboardMinScale at most. Name tags over friends and giants: Config/Crowd
-- Tags.

return table.freeze({
	-- Heights (Top) are layout px below Roblox's top bar, so the cheers sit high up but under the live event
	-- card at the top centre (client/EventBanner, about 215 px tall); a share of the screen would land on it
	-- on phones.

	-- combo words after a hit (2x, 3x...), right of centre and up, out of the road ahead
	ComboSize = 40, -- at a 2-hit combo
	ComboStep = 1.8, -- added per hit in the combo, up to ComboMaxHits
	ComboMaxHits = 10,
	ComboX = 0.66, -- share of the screen width
	ComboTop = 265,

	-- a whole building down: DEMOLISHED! and the pay, in the middle near the top
	BigSize = 60,
	BigTop = 250,
	BigAmountSize = 48,
	BigAmountTop = 312,

	-- the tutorial's step cheer (BUILDING SMASHED!) and the line under it
	CheerSize = 38,
	CheerTop = 250,
	CheerSubSize = 16,

	-- the middle of the screen is shared (client/Style.stage): big callouts wait their turn, one after another
	StageGap = 0.4, -- seconds between one big callout going and the next
	BigHold = 1.1, -- DEMOLISHED! and its amount: seconds it holds the middle (the slam and its fade)
	CheerHold = 3.4, -- a cheer (tutorial step, SERVER GOAL, SO CLOSE, contest winners): seconds before it fades
	CheerFade = 0.5, -- ...and the fade itself
	NewRideHold = 1.8, -- a new car turns on its turntable this long before the NEW RIDE! cheer (client/NewRide)
	NewRideTurn = 1.6, -- seconds for one full turn
	PodiumHold = 4, -- the contest podium stays up this long (client/Podium)
	CashBigGain = 1000, -- a gain this big makes the cash box bump harder, flash green and throw coins
	CashSparks = 8, -- coins it throws
	AirTickerSize = 28, -- the air-time count while airborne
	LandingSize = 24, -- "120 STUDS!" over the landing spot (a world label)

	-- the tutorial's arrow over its target (a world label) and the one pinned to the screen edge
	ArrowScale = 0.64, -- of its full drawn size (220 px tall, 38 px label)
	EdgeScale = 0.67, -- the edge chevron, of 150 px
	EdgeTextSize = 15,
	EdgeTextGap = 55, -- px from the chevron's centre to its distance label
})
