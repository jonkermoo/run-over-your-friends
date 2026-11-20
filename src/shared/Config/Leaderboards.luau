--!strict
-- Leaderboards on the stands along the spawn plaza's north side. Each board is one stat; boards that share a
-- `stand` take turns on it (FlipSeconds each). The #1 of the podium's stats also stands on the champions'
-- podium in the middle of the plaza (Config/Champions).

export type Board = {
	key: string,
	title: string,
	tag: string, -- the pill under the title ("THIS WEEK", "ALL TIME")
	prefix: string,
	suffix: string,
	color: string, -- a Style colour
	icon: string, -- Config/Icons name for the header badge
	iconTurn: number?, -- degrees the icon is turned
	stand: number, -- which stand it shows on, 1 = west
	allTime: boolean?, -- never resets (no week in its store's name)
}

return table.freeze({
	Boards = table.freeze({
		table.freeze({
			key = "Hits",
			title = "MOST RUN OVER",
			tag = "THIS WEEK",
			prefix = "",
			suffix = "",
			color = "red",
			icon = "Sign",
			stand = 1,
		}),
		table.freeze({
			key = "HitsAll",
			title = "MOST RUN OVER",
			tag = "ALL TIME",
			prefix = "",
			suffix = "",
			color = "gold",
			icon = "Sign",
			stand = 2,
			allTime = true,
		}),
		table.freeze({
			key = "Earned",
			title = "RICHEST EVER",
			tag = "ALL TIME",
			prefix = "$",
			suffix = "",
			color = "money",
			icon = "Bill",
			stand = 3,
			allTime = true,
		}),
		table.freeze({
			key = "Launch",
			title = "BIGGEST LAUNCH",
			tag = "THIS WEEK",
			prefix = "",
			suffix = " studs",
			color = "blue",
			icon = "Arrow",
			iconTurn = 180,
			stand = 4,
		}),
		table.freeze({
			key = "Combo",
			title = "BIGGEST COMBO",
			tag = "THIS WEEK",
			prefix = "",
			suffix = " hits",
			color = "purple",
			icon = "Sign",
			stand = 4,
		}),
	}),
	-- the stands under the gantry (MapBuilder), centred on the plaza, studs
	Stands = 4,
	StandWidth = 43,
	StandHeight = 46,
	StandStep = 47, -- centre to centre
	FlipSeconds = 15,
	Top = 10, -- rows on a board
	ReadTop = 100, -- entries read per board (one request either way); your own rank is shown up to here
	Hidden = table.freeze({} :: { [number]: boolean }), -- user ids kept off every board and podium (cheaters)
	WeekSeconds = 604800,
	WeekStartOffset = 345600, -- unix time 0 was a Thursday; this shifts the week to start on Monday 00:00 UTC
	RefreshSeconds = 60, -- reading the boards
	LastWeekSeconds = 900, -- reading last week's #1 for the podium, only while nobody has scored this week
	SaveSeconds = 90, -- writing a player's scores
})
