--!strict
-- Street greenery picks (Config/StreetGreen): which crown shape and tint a street tree takes, and where the
-- beds beside an office tower go. Picks come from positions and block numbers, never from the town's random
-- stream, so adding them moves nothing else. Pure, so Lune tests it.

local StreetGreen = {}

-- a whole number from a spot on the ground
function StreetGreen.spot(x: number, z: number): number
	return math.floor(x) * 7 + math.floor(z) * 13
end

-- which of `n` crown shapes a tree at (x, z) takes
function StreetGreen.shape(x: number, z: number, n: number): number
	return StreetGreen.spot(x, z) % n + 1
end

-- the accent (1, 2) a whole block side takes, or nil for the usual greens: about one side in `every` each
function StreetGreen.accent(i: number, j: number, side: number, every: number): number?
	local k = (i * 31 + j * 17 + side * 7) % every
	if k == 0 then
		return 1
	elseif k == every // 2 then
		return 2
	end
	return nil
end

-- which of `n` greens a tree at (x, z) takes (neighbours along a row differ)
function StreetGreen.green(x: number, z: number, n: number): number
	return (StreetGreen.spot(x, z) // 3) % n + 1
end

export type Run = { x: number, y0: number, y1: number }

-- the beds beside an office tower, in the block's own frame: x across (toward a flank), y toward the tower's
-- front sidewalk, the block's paved middle `inner` square; the tower is `across` wide and `deep` deep, its
-- front `setback` in from the front sidewalk. Each run is a bed's middle line at x, from y0 (back) to y1
-- (front).
function StreetGreen.flankRuns(
	inner: number,
	across: number,
	deep: number,
	setback: number,
	F: { Depth: number, Clear: number, Ends: number, MinRun: number }
): { Run }
	local runs: { Run } = {}
	local flank = (inner - across) / 2
	if flank < F.Depth + F.Clear then
		return runs
	end
	local y1 = inner / 2 - F.Ends
	local y0 = inner / 2 - setback - deep
	if y1 - y0 < F.MinRun then
		return runs
	end
	for _, sx in { -1, 1 } do
		table.insert(runs, { x = sx * (inner / 2 - F.Depth / 2), y0 = y0, y1 = y1 })
	end
	return runs
end

return StreetGreen
