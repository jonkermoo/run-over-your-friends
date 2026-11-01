--!strict
-- Picking houses: a type by the district's weights, and a palette that differs from the neighbour's.
-- Pure, so Lune tests it. `r` is a number in [0, 1).

local Houses = {}

-- the type whose weight band `r` falls in (keys in a fixed order, so the same r gives the same type)
function Houses.pickType(weights: { [string]: number }, r: number): string
	local keys = {}
	local total = 0
	for k, w in weights do
		table.insert(keys, k)
		total += w
	end
	table.sort(keys)
	local x = r * total
	for _, k in keys do
		x -= weights[k]
		if x < 0 then
			return k
		end
	end
	return keys[#keys]
end

-- a palette index from 1..count, never the same as `previous` (when there's more than one)
function Houses.pickPalette(count: number, previous: number?, r: number): number
	if count <= 1 then
		return 1
	end
	local avoid = if previous and previous >= 1 and previous <= count then previous else nil
	local options = if avoid then count - 1 else count
	local k = 1 + math.min(math.floor(r * options), options - 1)
	if avoid and k >= avoid then
		k += 1
	end
	return k
end

return Houses
