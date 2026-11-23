--!strict
-- The Roadster free trial (server/TrialService, Rules/Trial, client/Trial, the garage's FREE TRIAL button).
-- Offered only in the garage, on the Roadster's card, to a player who has finished the tutorial, doesn't own the
-- car and hasn't had a trial in the last CooldownSeconds. The clock only runs while they sit in its driver seat.

return table.freeze({
	Car = "Roadster", -- Config/Vehicles id
	Seconds = 180, -- driving time in the trial car
	WarnSeconds = 15, -- the warning popup and the red countdown chip start here
	CooldownSeconds = 24 * 60 * 60, -- one trial per player per this long (os.time, saved in the profile)
	-- at zero the swap back waits for the car to be on the ground, but never longer than this
	LandWaitSeconds = 5,
	-- on the ground: something solid within this many studs under the bottom of the car
	GroundGap = 3,
	-- bought the pass or the car within this long of a trial start counts as converted (analytics)
	ConvertSeconds = 7 * 24 * 60 * 60,
	TickSeconds = 0.25, -- how often the server runs the trial clock
	RemoteCooldown = 1, -- seconds between a player's trial requests
})
