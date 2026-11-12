--!strict
-- Contest events: a score per player while one runs, the standings, and who gets which prize at the end.
-- "add" contests count up; "max" contests keep each player's best. Ties go to whoever got there first.
-- Pure, so Lune tests it.

local Contest = {}

export type Entry = { score: number, at: number }
export type Scores = { [number]: Entry } -- by userId
export type Place = { id: number, score: number, place: number }

-- adds a score for `id` at time `now`; returns true when it changed their score
function Contest.record(
	scores: Scores,
	id: number,
	mode: "add" | "max",
	amount: number,
	now: number
): boolean
	if amount <= 0 then
		return false
	end
	local e = scores[id]
	if not e then
		scores[id] = { score = amount, at = now }
		return true
	end
	local new = if mode == "add" then e.score + amount else math.max(e.score, amount)
	if new == e.score then
		return false
	end
	e.score, e.at = new, now
	return true
end

-- best first; equal scores rank by who reached theirs first, then by id so the order is fixed
function Contest.standings(scores: Scores): { Place }
	local list: { Place } = {}
	for id, e in scores do
		table.insert(list, { id = id, score = e.score, place = 0 })
	end
	table.sort(list, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		local ta, tb = scores[a.id].at, scores[b.id].at
		if ta ~= tb then
			return ta < tb
		end
		return a.id < b.id
	end)
	for i, p in list do
		p.place = i
	end
	return list
end

-- what each player wins: prizes[place] for the top places, takePart for everyone else who scored.
-- fullField: with fewer players than this taking part, the place prizes shrink in step (1 of 4 taking part
-- gets a quarter), so a contest you're alone in isn't free money; a prize never drops under takePart.
-- Prizes round to $10.
function Contest.prizes(
	standings: { Place },
	prizes: { number },
	takePart: number,
	fullField: number?
): { [number]: number }
	local share = math.min(1, #standings / math.max(fullField or 1, 1))
	local out = {}
	for _, p in standings do
		local prize = prizes[p.place]
		out[p.id] = if prize
			then math.max(takePart, math.floor(prize * share / 10 + 0.5) * 10)
			else takePart
	end
	return out
end

-- "1ST", "2ND", "3RD", "4TH", ... "11TH", "12TH", "13TH", "21ST"
function Contest.ordinal(n: number): string
	local tens = n % 100
	local suffix = "TH"
	if tens < 11 or tens > 13 then
		local ones = n % 10
		suffix = if ones == 1
			then "ST"
			elseif ones == 2 then "ND"
			elseif ones == 3 then "RD"
			else "TH"
	end
	return tostring(n) .. suffix
end

-- "1 piece", "12 pieces": a score rounded, with its unit (units are plural words ending in s)
function Contest.amount(n: number, unit: string): string
	local whole = math.floor(n + 0.5)
	if whole == 1 and string.sub(unit, -1) == "s" then
		unit = string.sub(unit, 1, -2)
	end
	return `{whole} {unit}`
end

return Contest
