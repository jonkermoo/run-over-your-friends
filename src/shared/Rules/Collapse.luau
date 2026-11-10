--!strict
-- A whole building coming down: when each storey lets go, how far a piece has fallen, what it pays.
-- Pure numbers (Config/Smash Collapse), so Lune tests it.

local Collapse = {}

export type Config = {
	StartSeconds: number,
	StaggerSeconds: number,
	PayPerPiece: number,
	PayMin: number,
	PayMax: number,
}

-- seconds after the hit a piece lets go; height is 0 at the bottom of the building and 1 at the top
function Collapse.startDelay(height: number, config: Config): number
	return config.StartSeconds + config.StaggerSeconds * math.clamp(height, 0, 1)
end

-- a piece's height t seconds after it lets go, and whether it has landed: it falls from y at vy (up is +)
-- until floorY, then sinks slowly
function Collapse.fallHeight(
	y: number,
	vy: number,
	t: number,
	gravity: number,
	floorY: number,
	sinkSpeed: number
): (number, boolean)
	local height = y + vy * t - 0.5 * gravity * t * t
	if height > floorY then
		return height, false
	end
	-- when it reached the floor: the later root of the fall
	local root = math.sqrt(math.max(vy * vy + 2 * gravity * (y - floorY), 0))
	local landedAt = (vy + root) / gravity
	return floorY - sinkSpeed * math.max(t - landedAt, 0), true
end

-- money for bringing down a building of this many pieces, before passes
function Collapse.payout(pieces: number, config: Config): number
	return math.clamp(math.floor(pieces * config.PayPerPiece), config.PayMin, config.PayMax)
end

return Collapse
