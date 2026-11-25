--!strict
-- The full-screen city map (client/CityMap, server/CityMapService, Rules/CityMap): one top-down picture of the
-- city with a dot per player. The picture was made in Studio by casting a ray straight down for every pixel
-- (tools/map), so it is a true overhead view: north (-z) is up, east (+x) is right. Studs, seconds, layout px.

export type Place = { key: string, name: string, x: number, z: number }

return table.freeze({
	-- the picture in TileGrid x TileGrid square tiles (row by row from the top left, image ids; 0 draws a plain dark
	-- square), so it stays sharp zoomed in (Roblox images are at most 1024 px)
	-- (Decals 126830927606578, 103021315203907, 89133872365004, 139739612073418)
	Tiles = table.freeze({ 95819431331767, 123428804733195, 128784584278736, 110697980419299 }),
	TileGrid = 2,
	Pin = 123493636137749, -- (Decal 105196457864314) the player marker (tools/map/pin.py): a white map pin, tinted; its tip is the spot
	-- world x, z under the picture's middle, and the studs it covers edge to edge both ways (it is square): the
	-- beaches in the west to the island's east edge (tools/map/scan.luau uses the same numbers)
	Centre = table.freeze({ 850, 100 }),
	Span = 7000,
	Pixels = 2048, -- the whole picture's size, both ways (tools/map)

	-- the server sends every player's spot to each client that has the map open, this often
	SendEvery = 1,
	OpenSendGap = 0.5, -- seconds: opening sends at once, but no more often than this per player
	Smooth = 0.8, -- seconds a dot takes to slide to its new spot (a little under SendEvery feels steady)

	-- the sheet: as big as the screen allows, between the menu strip and the bottom margin; drawn over the
	-- tutorial's card and arrow (Guide, 5); level with the big moment cards (new ride, podium, trial: 6), which
	-- are made after it and so still draw on top
	DisplayOrder = 6,
	Top = 68,
	Bottom = 18,
	Side = 14,
	Header = 58, -- the title row over the picture
	-- dots, layout px
	SelfArrow = 24, -- you: an arrow turned the way you face
	FriendPin = 20, -- friends' pins (the square picture; the pin is a bit narrower)
	OtherPin = 15, -- everyone else's
	OtherFade = 0.35, -- everyone who isn't a friend: this see-through
	PickedGrow = 1.35, -- the picked player's pin grows this much
	Crown = 20, -- over the live contest's leader
	NameText = 15, -- friends' names under their dots
	TapRadius = 24, -- a tap or click this close to a marker picks it
	PlaceText = 16,
	EventPin = 26, -- the live event's spot (the giant)

	-- zoom and move: mouse wheel, pinch, the + / - buttons (and gamepad Y / X) zoom, dragging (and the right stick)
	-- moves it. Zoom is how many times the window the whole picture is.
	MinZoom = 1,
	MaxZoom = 5,
	ZoomStep = 1.5, -- one press of + or -
	WheelStep = 1.2, -- one notch of the mouse wheel
	DragStart = 6, -- layout px a press must move before it's a drag, not a tap
	PadPan = 700, -- layout px a second the right stick moves it, fully pushed
	PadDead = 0.2, -- stick dead zone
	MeZoom = 2.5, -- the ME button zooms in at least this far, centred on you

	StudioFriends = true, -- in Studio, test players (user id <= 0) count as friends, so the friend look can be tried
	Key = "M", -- PC key
	-- the gamepad key that opens and closes it ("" = none: the menu strip's MAP tab, D-pad right, still does): a
	-- left-stick click, the one button nothing else takes (View is Settings', R3 the cockpit view, the D-pad the
	-- horn, unstuck, menu and the tutorial's SKIP; the driving controls card lists it, Rules/DriveHud)
	PadKey = "ButtonL3",

	-- key places, marked on the map (measured from the built map in Studio)
	Places = table.freeze({
		table.freeze({ key = "StuntPark", name = "STUNT PARK", x = 1811, z = 0 }),
		-- the Stadium Row district (Rules/Districts: the north middle of the grid)
		table.freeze({ key = "Stadium", name = "STADIUM ROW", x = 142, z = -710 }),
	}) :: { Place },
})
