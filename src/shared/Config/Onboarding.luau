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
	Garage = 10, -- the garage tour (added 2026-11-24): car page, upgrades, paint, decals, the next car
	Done = 99,
})

-- the first-join offer, saved per player as profile.offer (player attribute "TutorialOffer" while it waits for
-- an answer, "TutorialTab" while the menu strip's TUTORIAL tab shows)
local Offer = table.freeze({
	New = 0, -- never asked
	Accepted = 1, -- said yes (or was already part way through the tutorial before the offer existed)
	DeclinedOnce = 2, -- said no once: asked once more on a later join, and the TUTORIAL tab shows
	DeclinedTwice = 3, -- said no twice: only the TUTORIAL tab
	Old = 4, -- finished the tutorial before the offer existed: never asked, no tab
})

return table.freeze({
	Steps = Steps,
	Offer = Offer,
	-- the event step comes before the buy step since 2026-11-24: the finish bonus is paid as the lessons end, so
	-- the last step is spending it on a car
	Order = table.freeze({
		Steps.Spawn,
		Steps.Hits,
		Steps.Smash,
		Steps.Garage,
		Steps.Goal,
		Steps.Event,
		Steps.Buy,
	}),
	-- saved steps no longer in Order, and where they go: 3 meant "save for the next car", 4 was "take a ramp"
	-- (removed 2026-11-20: a quarter of new players quit there)
	Retired = table.freeze({
		[3] = Steps.Done,
		[4] = Steps.Smash,
	}),
	-- the card's "TUTORIAL 1/5" tag and the "STEP 1 OF 5" banner count from this step; steps before it (the
	-- spawn, done for you) share number 1
	CountFrom = Steps.Hits,
	-- the banner's line under "STEP n OF m" when a step starts (no entry: no banner)
	StepTitles = table.freeze({
		[Steps.Hits] = "HIT PEOPLE WITH YOUR CAR",
		[Steps.Smash] = "SMASH A BUILDING",
		[Steps.Garage] = "TUNE YOUR CAR",
		[Steps.Goal] = "FINISH YOUR FIRST GOAL",
		[Steps.Buy] = "SPEND YOUR BONUS",
		[Steps.Event] = "JOIN AN EVENT",
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
	-- paid once, the first time the tutorial reaches its last step (or its end) after a yes: enough with the
	-- step rewards for the first real car (the Sedan, Config/Economy RookieUntil)
	FinishBonus = 2500,
	OfferDelay = 1, -- seconds after the data is ready before the offer shows, so the screen has settled
	-- the garage tour's pages, in order (client/Guide; analytics TutorialTour field 01)
	TourPages = table.freeze({ "Open", "Car", "Upgrades", "Paint", "Decals", "NextCar", "Done" }),
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
