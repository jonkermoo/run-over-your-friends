--!strict
-- Server events: one every few minutes, announced ahead, running for a short while.

export type Event = { key: string, title: string, text: string, color: string }

return table.freeze({
	GapSeconds = 360, -- quiet time between events
	FirstAfter = 90, -- the first event comes sooner, so a new server gets one early
	DurationSeconds = 120,
	WarnSeconds = 20, -- the banner counts down before it starts
	List = table.freeze({
		table.freeze({
			key = "LowGravity",
			title = "LOW GRAVITY",
			text = "Everything floats. Launches go to the moon.",
			color = "purple",
		}),
		table.freeze({
			key = "GoldenRush",
			title = "GOLDEN RUSH",
			text = "Golden people are worth 10x. Find them!",
			color = "gold",
		}),
		table.freeze({
			key = "Giant",
			title = "GIANT IN TOWN",
			text = "A giant walks downtown. Hit it 5 times to topple it!",
			color = "red",
		}),
		table.freeze({
			key = "Stampede",
			title = "STAMPEDE",
			text = "Crowds flood the streets and every hit pays double.",
			color = "green",
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
})
