--!strict
-- Play-time gift rules (Config/Gifts): which gift is next, whether it is open yet, and what it pays.

local Gifts = {}

export type Prize = { cash: number, paint: string? }

-- the next gift's number after `claimed` gifts, nil once all are claimed
function Gifts.nextIndex(claimed: number, minutes: { number }): number?
	return if claimed >= 0 and claimed < #minutes then claimed + 1 else nil
end

-- seconds left until gift `index` opens (0 when open), after `played` seconds this session
function Gifts.wait(index: number, played: number, minutes: { number }): number
	local at = (minutes[index] or math.huge) * 60
	return math.max(0, at - played)
end

-- can gift `index` be claimed now? `slack` seconds early is allowed
function Gifts.open(index: number, played: number, minutes: { number }, slack: number): boolean
	return minutes[index] ~= nil and played + slack >= minutes[index] * 60
end

-- what gift `index` gives this player: its paint, or its cash when the paint is owned (or there is none)
function Gifts.payout(
	index: number,
	prizes: { Prize },
	ownedPaints: { [string]: boolean }
): (number, string?)
	local p = prizes[index]
	if not p then
		return 0, nil
	end
	if p.paint and not ownedPaints[p.paint] then
		return 0, p.paint
	end
	return p.cash, nil
end

return Gifts
