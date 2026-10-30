--!strict
-- Goal rules: which period it is, rolling a period's goals, and progress. Pure, so Lune tests it.
-- Randomness comes in as a function returning [0, 1), so the same seed gives the same goals.

local Quests = {}

export type Template = {
	kind: string,
	mode: "add" | "max",
	text: string,
	min: number,
	max: number,
	step: number,
	perUnit: number,
	needs: string?,
}

export type Goal = {
	kind: string,
	mode: "add" | "max",
	text: string,
	target: number,
	reward: number,
	progress: number,
	done: boolean,
}

export type Set = { period: number, goals: { Goal } }

function Quests.period(now: number, length: number): number
	return math.floor(now / length)
end

function Quests.secondsLeft(now: number, length: number): number
	return length - (now % length)
end

-- a seed that differs per player and per period
function Quests.seed(userId: number, period: number, salt: number): number
	return (userId % 1000003) * 7919 + period * 104729 + salt
end

-- roll `count` goals of different kinds; `has(needs)` filters templates the player can't do
function Quests.roll(
	templates: { Template },
	count: number,
	rng: () -> number,
	has: (string) -> boolean
): { Goal }
	local pool = {}
	for _, tpl in templates do
		if tpl.needs == nil or has(tpl.needs) then
			table.insert(pool, tpl)
		end
	end
	local goals = {}
	while #goals < count and #pool > 0 do
		local i = math.clamp(math.floor(rng() * #pool) + 1, 1, #pool)
		local tpl = table.remove(pool, i) :: Template
		local steps = math.floor((tpl.max - tpl.min) / tpl.step)
		local target = tpl.min + math.clamp(math.floor(rng() * (steps + 1)), 0, steps) * tpl.step
		local reward = math.max(10, math.floor(target * tpl.perUnit / 10 + 0.5) * 10)
		table.insert(goals, {
			kind = tpl.kind,
			mode = tpl.mode,
			text = (string.gsub(tpl.text, "{n}", function()
				return tostring(target)
			end)),
			target = target,
			reward = reward,
			progress = 0,
			done = false,
		})
	end
	return goals
end

-- apply an event; returns the goals it just completed
function Quests.advance(goals: { Goal }, kind: string, amount: number): { Goal }
	local finished = {}
	if amount ~= amount or amount <= 0 then
		return finished
	end
	for _, g in goals do
		if g.kind == kind and not g.done then
			if g.mode == "max" then
				g.progress = math.max(g.progress, amount)
			else
				g.progress += amount
			end
			if g.progress >= g.target then
				g.progress = g.target
				g.done = true
				table.insert(finished, g)
			end
		end
	end
	return finished
end

return Quests
