--!strict
-- First-session rules: which step comes next, what can be skipped, and where the off-screen pointer goes.

local Rules = {}

export type Config = {
	Steps: { [string]: number },
	Order: { number },
	Retired: { [number]: number },
	SmashGoal: number,
	EventWait: number,
	CountFrom: number,
	Offer: { [string]: number },
	BonusAt: number,
}

-- what the player has done this session
export type Facts = { pieces: number, ownsExtra: boolean }

-- a saved step: a retired one goes where Retired sends it, anything unknown counts as finished
function Rules.migrate(saved: number, config: Config): number
	if table.find(config.Order, saved) then
		return saved
	end
	return config.Retired[saved] or config.Steps.Done
end

function Rules.after(step: number, config: Config): number
	local i = table.find(config.Order, step)
	return if i and config.Order[i + 1] then config.Order[i + 1] else config.Steps.Done
end

function Rules.alreadyDone(step: number, facts: Facts, config: Config): boolean
	local S = config.Steps
	return (step == S.Smash and facts.pieces >= config.SmashGoal)
		or (step == S.Buy and facts.ownsExtra)
end

-- the first step from `step` on that still needs doing, and the steps passed on the way there
function Rules.landing(step: number, facts: Facts, config: Config): (number, { number })
	local passed = {}
	while step ~= config.Steps.Done and Rules.alreadyDone(step, facts, config) do
		table.insert(passed, step)
		step = Rules.after(step, config)
	end
	return step, passed
end

-- the step's number as the player sees it, and how many there are (steps before CountFrom share number 1);
-- nil for a step not in Order (done, unknown)
function Rules.stepNumber(step: number, config: Config): (number?, number)
	local from = table.find(config.Order, config.CountFrom) or 1
	local total = #config.Order - from + 1
	local i = table.find(config.Order, step)
	if not i then
		return nil, total
	end
	return math.max(1, i - from + 1), total
end

function Rules.canSkip(step: number, config: Config): boolean
	local S = config.Steps
	return step == S.Smash or step == S.Goal or step == S.Buy or step == S.Event or step == S.Garage
end

-- has the tutorial got as far as `mark` (or finished)? Steps run in Order, not by number
function Rules.reached(step: number, mark: number, config: Config): boolean
	if step == config.Steps.Done then
		return true
	end
	local i, m = table.find(config.Order, step), table.find(config.Order, mark)
	return i ~= nil and m ~= nil and i >= m
end

-- the first-join offer: "First" for a new player who hasn't answered, "Again" on the join after one "No
-- thanks", nil when it shouldn't show (answered, asked twice, bonus already paid, from before the offer)
function Rules.offerWhere(state: number, step: number, bonusPaid: boolean, config: Config): string?
	local O = config.Offer
	if bonusPaid then
		return nil
	elseif state == O.New and step ~= config.Steps.Done then
		return "First"
	elseif state == O.DeclinedOnce and step == config.Steps.Done then
		return "Again"
	end
	return nil
end

-- the saved answer after a "No thanks"
function Rules.declined(state: number, config: Config): number
	return if state == config.Offer.New
		then config.Offer.DeclinedOnce
		else config.Offer.DeclinedTwice
end

-- the menu strip's TUTORIAL tab: for a player who said no and hasn't done the tutorial since
function Rules.tabShows(state: number, step: number, bonusPaid: boolean, config: Config): boolean
	local O = config.Offer
	return not bonusPaid
		and step == config.Steps.Done
		and (state == O.DeclinedOnce or state == O.DeclinedTwice)
end

-- the finish bonus: paid once, when a player who said yes lands on BonusAt or past it
function Rules.bonusDue(state: number, landing: number, bonusPaid: boolean, config: Config): boolean
	return not bonusPaid
		and state == config.Offer.Accepted
		and Rules.reached(landing, config.BonusAt, config)
end

-- a save from before the offer existed: finished players are never asked, players part way through carry on
function Rules.migrateOffer(saved: unknown, step: number, config: Config): number
	local n = tonumber(saved)
	if n then
		for _, v in config.Offer do
			if v == n then
				return n
			end
		end
	end
	return if step == config.Steps.Done then config.Offer.Old else config.Offer.Accepted
end

-- the event step ends by itself once nothing is live or about to start and it has waited long enough
function Rules.eventExpired(phase: string?, waited: number, config: Config): boolean
	return phase == "quiet" and waited >= config.EventWait
end

export type EdgePoint = { x: number, y: number, angle: number, onScreen: boolean }

-- (px, py, pz) from Camera:WorldToScreenPoint, a screen of w by h. Where the pointer sits on the edge of the
-- area left by the margins, and its rotation (0 points down the screen, a chevron's natural way).
function Rules.edgePoint(
	px: number,
	py: number,
	pz: number,
	w: number,
	h: number,
	margins: { left: number, top: number, right: number, bottom: number }
): EdgePoint
	local x0, y0, x1, y1 = margins.left, margins.top, w - margins.right, h - margins.bottom
	local onScreen = pz > 0 and px >= x0 and px <= x1 and py >= y0 and py <= y1
	local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
	local dx, dy = px - cx, py - cy
	if pz <= 0 then
		dx, dy = -dx, -dy
	end
	if math.abs(dx) < 1e-6 and math.abs(dy) < 1e-6 then
		dy = 1
	end
	local k = math.min(
		(x1 - x0) / 2 / math.max(math.abs(dx), 1e-6),
		(y1 - y0) / 2 / math.max(math.abs(dy), 1e-6)
	)
	return {
		x = cx + dx * k,
		y = cy + dy * k,
		angle = math.deg(math.atan2(dy, dx)) - 90,
		onScreen = onScreen,
	}
end

return Rules
