--!strict
-- Which district a city block belongs to: Canal Quarter down the east side, Stadium Row in the north
-- middle, Old Town in the north-west, Dockside on the west edge by the port, Maple Hills across the south,
-- Neon Core (downtown) in between. Works for any grid size by fractions of the grid. Pure, so Lune tests it.

local Districts = {}

export type Key = "neon" | "old" | "maple" | "dock" | "canal" | "stadium"

function Districts.of(i: number, j: number, blocksX: number, blocksZ: number): Key
	local fx, fz = (i + 0.5) / blocksX, (j + 0.5) / blocksZ
	if fx > 0.75 then
		return "canal"
	elseif fz < 0.25 and fx > 0.375 then
		return "stadium"
	elseif fz < 0.375 and fx < 0.375 then
		return "old"
	elseif fx < 0.125 and fz < 0.75 then
		return "dock"
	elseif fz > 0.75 or (fx < 0.25 and fz > 0.375) then
		return "maple"
	end
	return "neon"
end

return Districts
