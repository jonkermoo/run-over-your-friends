--!strict
-- First session: steps, goals, rewards and hint timings.

-- player attribute "Tutorial". 3 is retired: it meant "save for the next car", and saves holding it count as done.
local Steps = table.freeze({
	Spawn = 1,
	Hits = 2,
	Ramp = 4,
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
		Steps.Ramp,
		Steps.Smash,
		Steps.Goal,
		Steps.Buy,
		Steps.Event,
	}),
	HitsGoal = 3,
	HitsReward = 250,
	SmashGoal = 5, -- building pieces
	-- paid when the step is done (or was done before you got to it), not when it's skipped
	Rewards = table.freeze({
		[Steps.Ramp] = 100,
		[Steps.Smash] = 150,
		[Steps.Goal] = 200,
		[Steps.Event] = 300,
	}),
	Cheers = table.freeze({
		[Steps.Ramp] = "NICE JUMP!",
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
	BeaconHeight = 500, -- studs: the light column over a ramp or a building
	BeaconWidth = 14,
	BeaconNear = 70, -- studs: closer than this the column thins out
	SmashMinHeight = 10, -- studs: shorter models in the Buildings folder are not smash targets
})
