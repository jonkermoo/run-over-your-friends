--!strict
-- The loading cover (ReplicatedFirst/Loading): roadside signs on asphalt that hide the bare terrain and the HUD
-- while the map streams in around the spawn plaza, then fade away.
-- Seconds unless noted.

return table.freeze({
	MinShow = 1, -- the cover stays at least this long, so it never just flickers
	Timeout = 25, -- after this the cover goes no matter what, so nobody is ever stuck on it
	Fade = 0.4, -- the fade out at the end
	StreamTimeout = 10, -- the longest one RequestStreamAroundAsync call may take before we stop waiting on it
	GroundDepth = 40, -- studs below the character to look for a streamed-in floor part (not terrain)
	TipEvery = 3, -- a new tip line this often
	Advance = 0.35, -- the ease of the fresh paint line and the car on the sign as each step finishes
	-- the finish: the car taps the friend off the sign, the sign is knocked crooked, then the fade starts
	Finish = table.freeze({
		hit = 0.2, -- the car's last push into the friend
		fly = 0.45, -- the friend tumbling off the sign
		knock = 0.35, -- the sign swinging crooked on its post
		knockAngle = 11, -- degrees it ends up leaning
		hold = 0.6, -- from the hit to the start of the fade
	}),
	-- how much of the road each step has painted (0..1)
	Steps = table.freeze({
		start = 0.08,
		game = 0.3, -- the game's own scripts and settings arrived
		character = 0.5, -- the character spawned
		streamed = 0.8, -- the area around the spawn streamed in
		ground = 0.95, -- there is a real floor under the character
	}),
	Tips = table.freeze({
		"Smash into friends for big cash!",
		"Bigger cars hit harder. Check the Garage!",
		"Ramps + speed = huge combos!",
		"Knock down walls for bonus cash.",
		"Invite friends to run them over for real!",
		"Grab the daily goals for free rewards.",
		"Paint your ride in the Garage.",
		"Find the giant somewhere in the city!",
	}),
})
