--!strict
-- The full-screen city map (client/CityMap, server/CityMapService, Rules/CityMap): one top-down picture of the
-- city with a dot per player. The picture was made in Studio by casting a ray straight down for every pixel
-- (tools/map), so it is a true overhead view: north (-z) is up, east (+x) is right. Studs, seconds, layout px.

export type Place = { key: string, name: string, x: number, z: number }

return table.freeze({
	Image = 103558712537964, -- the picture (Decal 119674023637024); 0 draws a plain dark square
	-- world x, z under the picture's middle, and the studs it covers edge to edge both ways (it is square): the
	-- beaches in the west to the far suburbs in the east (tools/map/scan.luau uses the same numbers)
	Centre = table.freeze({ 1350, 50 }),
	Span = 8400,
	Pixels = 1024, -- the picture's size, both ways (tools/map)

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
	SelfArrow = 34, -- you: a big arrow turned the way you face
	FriendDot = 18,
	OtherDot = 11,
	OtherFade = 0.45, -- everyone who isn't a friend: this see-through
	Crown = 24, -- over the live contest's leader
	NameText = 15, -- friends' names under their dots
	TapRadius = 30, -- a tap or click this close to a dot picks it
	PlaceText = 16,
	EventPin = 30, -- the live event's spot (the giant)

	StudioFriends = true, -- in Studio, test players (user id <= 0) count as friends, so the friend look can be tried
	Key = "M", -- PC key
	PadKey = "ButtonSelect", -- gamepad: Back / View

	-- key places, marked on the map (measured from the built map in Studio)
	Places = table.freeze({
		table.freeze({ key = "StuntPark", name = "STUNT PARK", x = 1953, z = -2 }),
		-- the Stadium Row district (Rules/Districts: the north middle of the grid)
		table.freeze({ key = "Stadium", name = "STADIUM ROW", x = 142, z = -852 }),
	}) :: { Place },
})
