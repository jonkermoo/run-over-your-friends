--!strict
-- Playing together: the friend money bonus and the "you launched Alex 300 studs" toasts.

return table.freeze({
	-- each Roblox friend in the server adds this share to hit money, up to the max
	FriendBonusPer = 0.10,
	FriendBonusMax = 0.30,
	-- launch toasts: shown to the launcher and the one launched
	ToastMinStuds = 40, -- shorter flights don't get a toast
	ToastHitterGap = 3, -- seconds between toasts for the same launcher
	ToastPairGap = 8, -- seconds between toasts for the same two players (either way round)
	FlightSamples = 20, -- how long a flight is watched: samples x seconds apart (3 s)
	FlightSampleEvery = 0.15,
	-- Studio test players are never real friends. In Studio only, "all" makes every test player a friend
	-- of every other (YOUR FRIEND look), "others" makes each one a friend of a made-up player called
	-- FakeOwnerName (the softer "friend of" look), "off" uses real friendships. The workspace attribute
	-- FakeFriends overrides this while a test runs.
	StudioFakeFriends = "all",
	FakeOwnerName = "Sam",
	-- how friends who are real players in the server look, on each player's own screen (client/NameTags)
	Look = table.freeze({
		Mine = { 255, 208, 0 } :: { number }, -- your friends: road yellow outline (seen through walls) and tag
		MineSize = 30, -- tag text height in pixels ("YOUR FRIEND"), the name line under it is 0.7 of it
		MineFadeFrom = 150, -- studs from the camera where the tag starts to fade
		MineFadeTo = 220,
		OtherSize = 22, -- another player's friends: name, then "friend of <name>" at half size
		OtherFadeFrom = 45,
		OtherFadeTo = 70,
		OtherOutline = 0.55, -- outline transparency for another player's friends (softer)
		-- another player's friends: one colour per owner, picked by the owner's user id
		Others = table.freeze({
			{ 120, 220, 255 },
			{ 255, 130, 200 },
			{ 150, 240, 120 },
			{ 255, 160, 90 },
			{ 190, 160, 255 },
			{ 110, 240, 210 },
		}) :: { { number } },
		Width = 320, -- tag box in pixels
		Height = 80,
		Lift = 1.6, -- studs above the top of the head
		MaxOutlines = 16, -- Roblox draws at most 31 highlights; your friends come first
	}),
})
