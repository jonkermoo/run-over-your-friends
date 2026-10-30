--!strict
-- Leaderboard rules: which week it is, keeping a player's weekly bests, and ranking entries.
-- Pure, so Lune tests it.

local Leaderboards = {}

export type Stats = {
	week: number,
	hits: number, -- this week
	launch: number, -- best this week, studs
	combo: number, -- best this week
	allHits: number,
	allLaunch: number,
	allCombo: number,
}

export type Entry = { userId: number, name: string, value: number }

function Leaderboards.week(now: number, length: number, offset: number): number
	return math.floor((now - offset) / length)
end

function Leaderboards.secondsLeft(now: number, length: number, offset: number): number
	return length - ((now - offset) % length)
end

function Leaderboards.fresh(week: number): Stats
	return { week = week, hits = 0, launch = 0, combo = 0, allHits = 0, allLaunch = 0, allCombo = 0 }
end

-- start a new week's numbers when the week changed (all-time numbers stay)
function Leaderboards.roll(stats: Stats, week: number): boolean
	if stats.week == week then
		return false
	end
	stats.week = week
	stats.hits, stats.launch, stats.combo = 0, 0, 0
	return true
end

-- record one event; returns true when a weekly number changed
function Leaderboards.record(stats: Stats, key: string, value: number): boolean
	if value ~= value or value <= 0 then
		return false
	end
	if key == "Hits" then
		stats.hits += value
		stats.allHits += value
		return true
	elseif key == "Launch" then
		stats.allLaunch = math.max(stats.allLaunch, value)
		if value > stats.launch then
			stats.launch = value
			return true
		end
	elseif key == "Combo" then
		stats.allCombo = math.max(stats.allCombo, value)
		if value > stats.combo then
			stats.combo = value
			return true
		end
	end
	return false
end

function Leaderboards.value(stats: Stats, key: string): number
	if key == "Hits" then
		return stats.hits
	elseif key == "Launch" then
		return stats.launch
	elseif key == "Combo" then
		return stats.combo
	end
	return 0
end

-- highest first, ties by lower user id (stable), at most `top`, zeros dropped
function Leaderboards.rank(entries: { Entry }, top: number): { Entry }
	local out = {}
	for _, e in entries do
		if e.value > 0 then
			table.insert(out, e)
		end
	end
	table.sort(out, function(a, b)
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.userId < b.userId
	end)
	while #out > top do
		table.remove(out)
	end
	return out
end

return Leaderboards
