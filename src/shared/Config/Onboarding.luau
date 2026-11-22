--!strict
-- First session: steps, goals, rewards and hint timings.

-- player attribute "Tutorial". Numbers never change meaning; retired ones are in Retired below.
local Steps = table.freeze({
	Spawn = 1,
	Hits = 2,
	Smash = 5,
	Goal = 6,
	Buy = 7,
	Event = 8,
	Done = 99,
})

return table.freeze({
	Steps = Steps,
	Order = table.freeze({
		Steps.Spawn,
		Steps.Hits,
		Steps.Smash,
		Steps.Goal,
		Steps.Buy,
		Steps.Event,
	}),
	-- saved steps no longer in Order, and where they go: 3 meant "save for the next car", 4 was "take a ramp"
	-- (removed 2026-11-20: a quarter of new players quit there)
	Retired = table.freeze({
		[3] = Steps.Done,
		[4] = Steps.Smash,
	}),
	-- first step: the server puts a new player in the starter car on its own (ad players decide in seconds)
	AutoSpawnDelay = 1, -- seconds after the character and data are ready, so the character has landed
	AutoSpawnTries = 5, -- a spawn can fail (character not ready, blocked spot): tries this many times
	AutoSpawnRetry = 2, -- seconds between tries
	GarageFallback = 12, -- seconds after the data loads: still not in a car, the client opens the garage
	HitsGoal = 3,
	HitsReward = 250,
	SmashGoal = 5, -- building pieces
	-- the first goal: a few more hits, then a big CLAIM pop-up that claims itself if left alone
	GoalHits = 4,
	ClaimAutoAfter = 6, -- seconds the CLAIM pop-up waits for a press
	ClaimDelay = 0.6, -- seconds between the last hit and the pop-up, so the hit lands first
	-- paid when the step is done (or was done before you got to it), not when it's skipped
	Rewards = table.freeze({
		[Steps.Smash] = 150,
		[Steps.Goal] = 200,
		[Steps.Event] = 300,
	}),
	Cheers = table.freeze({
		[Steps.Smash] = "BUILDING SMASHED!",
		[Steps.Goal] = "FIRST GOAL CLAIMED!",
		[Steps.Event] = "YOU JOINED AN EVENT!",
	}),
	SpawnCrowd = 12, -- NPCs that always hang around the spawn plaza
	HintAfter = 20, -- seconds stuck on a step before the hint pulses
	SkipAfter = 10, -- seconds on a step before its SKIP button shows
	EventWait = 45, -- seconds the event step waits while no event is live or about to start, then ends itself
	-- markers: GUI pixels kept clear for the off-screen pointer (menu strip on top, speedometer below)
	EdgeMargins = table.freeze({ left = 70, top = 150, right = 70, bottom = 130 }),
	EdgeBox = 120, -- layout px: the edge pointer's size, kept off the controls card and speedometer (Rules/Clear)
	ClearGap = 10, -- layout px between it and them
	TabArrowDrop = 96, -- layout px the job card steps down while the arrow points at a menu tab above it
	BeaconHeight = 500, -- studs: the light column over a building
	BeaconWidth = 14,
	BeaconNear = 70, -- studs: closer than this the column thins out
	SmashMinHeight = 10, -- studs: shorter models in the Buildings folder are not smash targets
})
