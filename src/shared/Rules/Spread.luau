--!strict
-- Keeping the city's people where people would be (server/CrowdService, Config/CrowdSpread): which goals are
-- outings, when an outing becomes staying in, and which residents a crowded stretch of the map leaves out.
-- Pure, so Lune tests it.

local Spread = {}

local OUTINGS = table.freeze({
	restaurant = true,
	shop = true,
	park = true,
	plaza = true,
	wander = true,
})

function Spread.isOuting(goal: string): boolean
	return OUTINGS[goal] == true
end

-- the goal someone actually follows: an outing from a home off the sidewalk network becomes staying in
-- (unless `offNetworkOutings`)
function Spread.goal(goal: string, onNetwork: boolean, offNetworkOutings: boolean): string
	if OUTINGS[goal] and not onNetwork and not offNetworkOutings then
		return "stay"
	end
	return goal
end

-- the grid cell a point is in, `size` studs square
function Spread.cell(x: number, z: number, size: number): string
	return `{math.floor(x / size)},{math.floor(z / size)}`
end

export type Resident = { cell: string, home: number }

-- which residents to keep (keep[k] for residents[k]): each cell keeps at most `cap`; a crowded cell drops
-- one at a time from its fullest home (lowest home number on a tie), so homes empty out last
function Spread.thin(residents: { Resident }, cap: number): { boolean }
	local keep: { boolean } = {}
	local byCell: { [string]: { [number]: { number } } } = {}
	local count: { [string]: number } = {}
	for k, r in residents do
		keep[k] = true
		local homes = byCell[r.cell]
		if not homes then
			homes = {}
			byCell[r.cell] = homes
		end
		local list = homes[r.home]
		if not list then
			list = {}
			homes[r.home] = list
		end
		table.insert(list, k)
		count[r.cell] = (count[r.cell] or 0) + 1
	end
	for cell, homes in byCell do
		local n = count[cell]
		while n > cap do
			local fullest, size = nil :: number?, 0
			for home, list in homes do
				if #list > size or (#list == size and fullest ~= nil and home < fullest) then
					fullest, size = home, #list
				end
			end
			local list = homes[fullest :: number]
			keep[table.remove(list) :: number] = false
			n -= 1
		end
	end
	return keep
end

return Spread
