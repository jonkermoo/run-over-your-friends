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
	FirstAfter = 90, -- the first event comes sooner, so a new server gets one early
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
	StampedeExtraNpcs = 25,
	StampedeMultiplier = 2,
	-- contests: places 1, 2, 3, then everyone else who scored at least once
	ContestPrizes = table.freeze({ 5000, 3000, 2000 }),
	ContestTakePart = 500,
	ContestShown = 3, -- names on the banner
	ContestSendSeconds = 1, -- standings to each player this often while one runs
	ContestMinLaunch = 10, -- studs: shorter flings don't count for Fling Fest
})
