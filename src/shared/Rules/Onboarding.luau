--!strict
-- First-session rules: which step comes next, what can be skipped, and where the off-screen pointer goes.

local Rules = {}

export type Config = {
	Steps: { [string]: number },
	Order: { number },
	SmashGoal: number,
	EventWait: number,
}

-- what the player has done this session
export type Facts = { jumped: boolean, pieces: number, ownsExtra: boolean }

-- a saved step: the retired one (3) and anything unknown count as finished
function Rules.migrate(saved: number, config: Config): number
	return if table.find(config.Order, saved) then saved else config.Steps.Done
end

function Rules.after(step: number, config: Config): number
	local i = table.find(config.Order, step)
	return if i and config.Order[i + 1] then config.Order[i + 1] else config.Steps.Done
end

function Rules.alreadyDone(step: number, facts: Facts, config: Config): boolean
	local S = config.Steps
	return (step == S.Ramp and facts.jumped)
		or (step == S.Smash and facts.pieces >= config.SmashGoal)
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

function Rules.canSkip(step: number, config: Config): boolean
	local S = config.Steps
	return step == S.Ramp or step == S.Smash or step == S.Goal or step == S.Buy or step == S.Event
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
