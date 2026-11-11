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

	AirTickerSize = 28, -- the air-time count while airborne
	LandingSize = 24, -- "120 STUDS!" over the landing spot (a world label)

	-- the tutorial's arrow over its target (a world label) and the one pinned to the screen edge
	ArrowScale = 0.64, -- of its full drawn size (220 px tall, 38 px label)
	EdgeScale = 0.67, -- the edge chevron, of 150 px
	EdgeTextSize = 15,
	EdgeTextGap = 55, -- px from the chevron's centre to its distance label
})
