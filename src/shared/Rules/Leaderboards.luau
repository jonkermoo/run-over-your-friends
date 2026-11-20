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
	allEarned: number?, -- money earned by playing, all time (nil until LeaderboardService seeds it)
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
	elseif key == "Earned" then
		stats.allEarned = (stats.allEarned or 0) + value
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
	elseif key == "HitsAll" then
		return stats.allHits
	elseif key == "Earned" then
		return stats.allEarned or 0
	end
	return 0
end

-- where the all-time money count starts for a player who had none: what they hold now plus what the cars
-- they own cost (money they must have earned before the count existed)
function Leaderboards.earnedSeed(money: number, carPrices: { number }): number
	local total = if money == money and money > 0 then money else 0
	for _, price in carPrices do
		if price == price and price > 0 then
			total += price
		end
	end
	return math.floor(total)
end

-- entries without the hidden user ids (a ban list), order kept
function Leaderboards.visible(entries: { Entry }, hidden: { [number]: boolean }): { Entry }
	local out = {}
	for _, e in entries do
		if not hidden[e.userId] then
			table.insert(out, e)
		end
	end
	return out
end

export type You = {
	rank: number?, -- nil = not in the ranked list (shown as "<listed>+")
	value: number,
	gap: number?, -- how much more to pass the one above; nil at #1 or when unranked
}

-- a player's own row: their place among `ranked` (highest first, ties by lower id, the board's first `limit`
-- places) and how much more passes the one above. Past `limit` places there's no rank.
function Leaderboards.you(ranked: { Entry }, userId: number, value: number, limit: number): You
	if value ~= value or value <= 0 then
		return { value = 0 }
	end
	local ahead = 0
	for _, e in ranked do
		if e.userId ~= userId and (e.value > value or (e.value == value and e.userId < userId)) then
			ahead += 1
		end
	end
	if ahead >= limit then
		return { value = value }
	end
	-- the entry just above (skipping the player's own entry)
	local above: Entry? = nil
	local n = 0
	for _, e in ranked do
		if e.userId ~= userId then
			n += 1
			if n == ahead then
				above = e
				break
			end
		end
	end
	return {
		rank = ahead + 1,
		value = value,
		gap = if above
			then math.max(1, above.value - value + (if above.userId < userId then 1 else 0))
			else nil,
	}
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
