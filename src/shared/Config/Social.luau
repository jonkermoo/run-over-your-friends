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
})
