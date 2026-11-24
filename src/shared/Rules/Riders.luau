--!strict
-- Who may ride in whose car (Config/Riders): plain rules, tested by Lune.

local Riders = {}

export type Config = { Modes: { string }, Default: string }

-- a saved or sent mode, or the default when it isn't one we know (old saves have none)
function Riders.mode(value: any, cfg: Config): string
	if typeof(value) == "string" and table.find(cfg.Modes, value) then
		return value
	end
	return cfg.Default
end

-- may this player ride with the owner (never in their own car)
function Riders.allowed(mode: string, isOwner: boolean, isFriend: boolean): boolean
	if isOwner then
		return false
	end
	if mode == "Everyone" then
		return true
	elseif mode == "Friends" then
		return isFriend
	end
	return false
end

-- the free seat nearest a point: seats are { pos, taken }, nil when all are taken
function Riders.nearestFree(seats: { { pos: Vector3, taken: boolean } }, from: Vector3): number?
	local best, bestD = nil, math.huge
	for i, s in seats do
		local d = (s.pos - from).Magnitude
		if not s.taken and d < bestD then
			best, bestD = i, d
		end
	end
	return best
end

-- the side a rider steps out on: their seat's side, the right when it's on the middle line
function Riders.exitSide(x: number): number
	return if x < -0.01 then -1 else 1
end

return table.freeze(Riders)
