--!strict
-- Server events: one every few minutes, announced ahead, running for a short while.
-- A contest event keeps a score per player while it runs (Rules/Contest) and pays the top 3 and everyone
-- who took part when it ends. stat: "Breaks" (building pieces), "Launch" (studs, best one), "Hits" or "Stunt" (one jump's
-- pay, best one).

export type Contest = {
	stat: "Breaks" | "Launch" | "Hits" | "Stunt",
	mode: "add" | "max",
	unit: string,
}
export type Event = { key: string, title: string, text: string, color: string, contest: Contest? }

return table.freeze({
	GapSeconds = 360, -- quiet time between events
	TitleSeconds = 3.6, -- the big title is up this long (fade included); queued cards like the daily streak wait for it
	FirstAfter = 180, -- a new server's first event: 3 minutes in, after a first player's tutorial
	DurationSeconds = 120,
	WarnSeconds = 20, -- the banner counts down before it starts
	-- contests sit between the others, so two in a row never happen
	List = table.freeze({
		table.freeze({
			key = "LowGravity",
			title = "LOW GRAVITY",
			text = "Everything floats. Launches go to the moon.",
			color = "purple",
		}),
		table.freeze({
			key = "WreckingSpree",
			title = "WRECKING SPREE",
			text = "Smash the most building pieces. Top 3 win big!",
			color = "orange",
			contest = table.freeze({ stat = "Breaks", mode = "add", unit = "pieces" }),
		}),
		table.freeze({
			key = "GoldenRush",
			title = "GOLDEN RUSH",
			text = "Golden people are worth 10x. Find them!",
			color = "gold",
		}),
		table.freeze({
			key = "FlingFest",
			title = "FLING FEST",
			text = "Launch someone the farthest. Top 3 win big!",
			color = "blue",
			contest = table.freeze({ stat = "Launch", mode = "max", unit = "studs" }),
		}),
		table.freeze({
			key = "Giant",
			title = "GIANT IN TOWN",
			text = "A giant walks downtown. Hit it 5 times to topple it!",
			color = "red",
		}),
		table.freeze({
			key = "Rampage",
			title = "RAMPAGE",
			text = "Run over the most people. Top 3 win big!",
			color = "pink",
			contest = table.freeze({ stat = "Hits", mode = "add", unit = "hits" }),
		}),
		table.freeze({
			key = "Stampede",
			title = "STAMPEDE",
			text = "Crowds flood the streets and every hit pays double.",
			color = "green",
		}),
		table.freeze({
			key = "AirShow",
			title = "AIR SHOW",
			text = "Land the best jump. Top 3 win big!",
			color = "red",
			contest = table.freeze({ stat = "Stunt", mode = "max", unit = "points" }),
		}),
	}),
	LowGravityScale = 0.35,
	GoldenCount = 8,
	GoldenMultiplier = 10,
	GoldenRespawnChance = 0.25,
	GiantScale = 5,
	GiantHits = 5,
	GiantHitPay = 1500,
	GiantToppleBonus = 5000,
	-- the giant is stood on the real (colliding) ground under its spawn spot: a ray from Up studs over the
	-- spot (clear of kerbs, under lamps and trees) to Down studs below it; the feet start GiantSpawnLift over it
	GiantGroundProbe = table.freeze({ Up = 6, Down = 60 }),
	GiantSpawnLift = 0.5,
	-- finding the giant from anywhere (client/GiantFinder): a light column over it and a pointer on the
	-- screen edge with the distance. Colour: Config/Crowd Tags.Giant.
	GiantFinder = table.freeze({
		BeamHeight = 900, -- studs above the giant's head
		BeamGap = 12, -- studs of clear air between the top of its head and the column's foot
		BeamWidth = 10, -- studs
		BeamMinPixels = 6, -- added on screen, so it stays a few pixels wide from across the map
		BeamTransparency = 0.15,
		BeamCore = 0.35, -- the white middle stripe, as a share of the width
		HideWithin = 90, -- studs: closer than this the pointer hides and the name tag takes over
		EdgeMargin = 70, -- layout px kept clear at the screen edge
		AboveHead = 40, -- layout px: the on-screen marker sits this far above the giant's head
		PlateWidth = 104, -- layout px
		PlateHeight = 50,
		Pointer = 22, -- layout px: the diamond that points the way
		ClearGap = 10, -- layout px kept between the plate and the controls card or speedometer (Rules/Clear)
		ScanSeconds = 0.5, -- how often to look for the giant in the crowd
		Unit = "m", -- distance label: one stud is one of these
	}),
	-- Studio only: set this workspace attribute to an event key (e.g. "Giant") to start that event now
	StudioStartAttribute = "StartEvent",
	StampedeExtraNpcs = 25,
	StampedeMultiplier = 2,
	-- contests: places 1, 2, 3, then everyone else who scored at least once
	ContestPrizes = table.freeze({ 5000, 3000, 2000 }),
	ContestTakePart = 500,
	ContestFullField = 4, -- with fewer taking part, the top-3 prizes shrink in step (Rules/Contest.prizes)
	ContestShown = 3, -- standings sent to each player (the banner shows the leader and you)
	-- the event sign (top centre, src/client/EventBanner): one line (LIVE pill, title, timer) sitting in the
	-- empty middle of Roblox's top bar, plus one slim line under it during a contest. Layout px.
	Card = table.freeze({
		InTopBar = true, -- centred in the top bar; false puts it just under the bar
		Gap = 8, -- the gap under the bar when InTopBar is false
		Height = 42, -- the one-line sign (also NEXT EVENT and the shrunk chip)
		Width = 360, -- warn / live sign
		WidthNarrow = 320, -- on screens under NarrowPx real px wide (Studio, phones)
		NarrowPx = 1000,
		QuietWidth = 250, -- the NEXT EVENT sign
		ContestRow = 20, -- the contest line under the sign
		TitleText = 20,
		TimerText = 18,
		ContestText = 14,
	}),
	ContestSendSeconds = 1, -- standings to each player this often while one runs
	ContestMinLaunch = 10, -- studs: shorter flings don't count for Fling Fest
})
