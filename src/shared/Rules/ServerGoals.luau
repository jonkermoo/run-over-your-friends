--!strict
-- Server goal rules: sizing a shared goal to the server and counting everyone's progress toward it.
-- Pure, so Lune tests it.

local ServerGoals = {}

export type Goal = {
	kind: string,
	text: string,
	target: number,
	progress: number,
	done: boolean,
	endsAt: number,
	helpers: { [number]: boolean }, -- user ids who added to it
}

-- the target for `players` on the server, rounded up to `step`
function ServerGoals.target(
	perPlayer: number,
	players: number,
	minPlayers: number,
	step: number
): number
	local raw = perPlayer * math.max(players, minPlayers, 1)
	return math.max(step, math.ceil(raw / step) * step)
end

function ServerGoals.make(
	def: { kind: string, text: string, perPlayer: number, step: number },
	players: number,
	minPlayers: number,
	now: number,
	seconds: number
): Goal
	local target = ServerGoals.target(def.perPlayer, players, minPlayers, def.step)
	return {
		kind = def.kind,
		text = (string.gsub(def.text, "{n}", tostring(target))),
		target = target,
		progress = 0,
		done = false,
		endsAt = now + seconds,
		helpers = {},
	}
end

-- add `amount` of `kind` from user `id`; true only on the add that finishes the goal
function ServerGoals.add(goal: Goal, kind: string, amount: number, id: number, now: number): boolean
	if goal.done or goal.kind ~= kind or amount <= 0 or now >= goal.endsAt then
		return false
	end
	goal.progress = math.min(goal.progress + amount, goal.target)
	goal.helpers[id] = true
	if goal.progress >= goal.target then
		goal.done = true
		return true
	end
	return false
end

-- the next goal kind in turn
function ServerGoals.nextIndex(index: number, count: number): number
	return index % math.max(count, 1) + 1
end

return ServerGoals
