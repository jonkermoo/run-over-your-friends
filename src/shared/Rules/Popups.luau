--!strict
-- Whether a card nobody asked for may open now (Config/Popups). Pure, so Lune tests it.

local Popups = {}

export type Config = {
	StoppedMph: number,
	StoppedSeconds: number,
	MovingMph: number,
	GapSeconds: number,
}

function Popups.isStill(driving: boolean, mph: number, throttle: number, cfg: Config): boolean
	return not driving or (mph <= cfg.StoppedMph and throttle == 0)
end

function Popups.isMoving(driving: boolean, mph: number, cfg: Config): boolean
	return driving and mph >= cfg.MovingMph
end

-- stillSince: when the player last became still, nil while they aren't. closedAt: when the last card was answered.
function Popups.mayOpen(now: number, stillSince: number?, closedAt: number?, cfg: Config): boolean
	if stillSince == nil or now - stillSince < cfg.StoppedSeconds then
		return false
	end
	return closedAt == nil or now - closedAt >= cfg.GapSeconds
end

export type Card = { open: boolean, group: number, since: number }

-- the queue's order: the card on screen stays first, then things to collect (a lower group) before progress
-- nudges, and in each group the one that has waited longest
function Popups.before(a: Card, b: Card): boolean
	if a.open ~= b.open then
		return a.open
	end
	if a.group ~= b.group then
		return a.group < b.group
	end
	return a.since < b.since
end

return Popups
