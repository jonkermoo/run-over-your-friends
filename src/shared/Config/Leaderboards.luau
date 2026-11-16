--!strict
-- Leaderboards at the spawn plaza. Each board is one stat. The weekly ones stand on the north side; an
-- all-time one (allTime) is the Hall of Fame tower on the island, its list on all four sides.

export type Board = {
	key: string,
	title: string,
	prefix: string,
	suffix: string,
	color: string,
	allTime: boolean?, -- never resets (no week in its store's name); `tag` replaces "THIS WEEK"
	tag: string?,
}

return table.freeze({
	Boards = table.freeze({
		table.freeze({
			key = "Hits",
			title = "MOST RUN OVER",
			prefix = "",
			suffix = "",
			color = "red",
		}),
		table.freeze({
			key = "Launch",
			title = "BIGGEST LAUNCH",
			prefix = "",
			suffix = " studs",
			color = "gold",
		}),
		table.freeze({
			key = "Combo",
			title = "BIGGEST COMBO",
			prefix = "",
			suffix = " hits",
			color = "purple",
		}),
		table.freeze({
			key = "HitsAll",
			title = "HALL OF FAME",
			tag = "MOST RUN OVER, ALL TIME",
			prefix = "",
			suffix = "",
			color = "gold",
			allTime = true,
		}),
	}),
	Top = 10,
	WeekSeconds = 604800,
	WeekStartOffset = 345600, -- unix time 0 was a Thursday; this shifts the week to start on Monday 00:00 UTC
	RefreshSeconds = 60, -- reading the boards
	SaveSeconds = 90, -- writing a player's scores
})
