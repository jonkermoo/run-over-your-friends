--!strict
-- Server goals: the whole server works on one shared goal at a time. Finishing it starts the next server
-- event straight away and pays everyone who helped. Targets grow with the players on when it starts.

export type Kind = { kind: string, text: string, perPlayer: number, step: number }

return table.freeze({
	Kinds = table.freeze({
		table.freeze({
			kind = "Breaks",
			text = "Smash {n} building pieces together",
			perPlayer = 60,
			step = 10,
		}) :: Kind,
		table.freeze({
			kind = "Hits",
			text = "Run over {n} people together",
			perPlayer = 20,
			step = 5,
		}) :: Kind,
		table.freeze({
			kind = "Jumps", -- clean stunt landings (StuntService)
			text = "Land {n} stunt jumps together",
			perPlayer = 5,
			step = 5,
		}) :: Kind,
	}),
	MinPlayers = 2, -- a small server's target is sized as if this many were on
	Seconds = 600, -- time to finish one goal
	Pause = 30, -- seconds between one goal ending and the next
	Reward = 1000, -- paid to each player who added to a finished goal
})
