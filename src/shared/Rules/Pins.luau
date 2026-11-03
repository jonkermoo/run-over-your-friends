--!strict
-- Pinned goals: which hourly/daily goals the player keeps on screen. A pin names a set ("Hourly",
-- "Daily"), a goal's place in it and the set's end time, so a new hour's set is noticed. Pure, so Lune
-- tests it.

local Pins = {}

export type Pin = { set: string, index: number, endsAt: number }
export type GoalLike = { done: boolean }
export type SetLike = { goals: { GoalLike }, endsAt: number }
export type Sets = { [string]: SetLike }

-- sets a pin may come from, in the order the default pin looks through them
Pins.Order = table.freeze({ "Hourly", "Daily" })

local function find(pins: { Pin }, set: string, index: number): number?
	for i, p in pins do
		if p.set == set and p.index == index then
			return i
		end
	end
	return nil
end

function Pins.isPinned(pins: { Pin }, set: string, index: number): boolean
	return find(pins, set, index) ~= nil
end

-- pins or unpins one goal; a new pin past `max` is refused. Returns the new list and what happened.
function Pins.toggle(
	pins: { Pin },
	set: string,
	index: number,
	endsAt: number,
	max: number
): ({ Pin }, "pinned" | "unpinned" | "full")
	local out = table.clone(pins)
	local at = find(out, set, index)
	if at then
		table.remove(out, at)
		return out, "unpinned"
	end
	if #out >= max then
		return out, "full"
	end
	table.insert(out, { set = set, index = index, endsAt = endsAt })
	return out, "pinned"
end

-- the next unfinished goal in a set after `index` (wrapping round), skipping ones pinned in either list
local function nextOpen(a: { Pin }, b: { Pin }, set: string, s: SetLike, index: number): number?
	local n = #s.goals
	for step = 1, n do
		local i = (index - 1 + step) % n + 1
		if not s.goals[i].done and not find(a, set, i) and not find(b, set, i) then
			return i
		end
	end
	return nil
end

-- keeps pins pointing at live goals: a set that rolled over keeps the pin's place (it's a new goal
-- there); a finished goal's pin moves to the set's next unfinished goal, or is dropped when there is none.
-- Returns the new list and the pins that were on a finished goal (for the DONE flash).
function Pins.advance(pins: { Pin }, sets: Sets): ({ Pin }, { Pin })
	local out: { Pin } = {}
	local finished: { Pin } = {}
	for _, p in pins do
		local s = sets[p.set]
		if s and #s.goals > 0 then
			local index = math.min(p.index, #s.goals)
			if s.endsAt ~= p.endsAt then
				-- a new set: same place, fresh goal
				if not find(out, p.set, index) then
					table.insert(out, { set = p.set, index = index, endsAt = s.endsAt })
				end
			elseif s.goals[index].done then
				table.insert(finished, p)
				local nextIndex = nextOpen(out, pins, p.set, s, index)
				if nextIndex then
					table.insert(out, { set = p.set, index = nextIndex, endsAt = s.endsAt })
				end
			elseif not find(out, p.set, index) then
				table.insert(out, { set = p.set, index = index, endsAt = p.endsAt })
			end
		end
	end
	return out, finished
end

-- the pins a player starts with: up to `count` unfinished goals, hourly first. Only used while they
-- have never pinned or unpinned anything themselves.
function Pins.default(sets: Sets, count: number): { Pin }
	local out: { Pin } = {}
	for _, name in Pins.Order do
		local s = sets[name]
		if s then
			for i, g in s.goals do
				if #out >= count then
					return out
				end
				if not g.done then
					table.insert(out, { set = name, index = i, endsAt = s.endsAt })
				end
			end
		end
	end
	return out
end

return Pins
