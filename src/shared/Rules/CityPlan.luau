--!strict
-- What stands on each city block: the spawn plaza in the middle, offices downtown, a fast-food place next to
-- spawn and another out of town, a delivery warehouse on the west edge (by the port), homes, shops, parks,
-- plazas and parking lots. Same seed, same city. Pure, so Lune tests it.

local CityPlan = {}

export type Kind =
	"spawn"
	| "office"
	| "restaurant"
	| "warehouse"
	| "homes"
	| "shops"
	| "park"
	| "plaza"
	| "parking"

-- a 32-bit integer hash (murmur3 finaliser), multiplies split into 16-bit halves so doubles stay exact
local function mul32(a: number, b: number): number
	local aLo, aHi = a % 65536, a // 65536
	return (aLo * b + ((aHi * b) % 65536) * 65536) % 4294967296
end

local function fmix(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xC2B2AE35)
	return bit32.bxor(h, bit32.rshift(h, 16))
end

-- a number in [0, 1) for this block
function CityPlan.roll(seed: number, i: number, j: number): number
	local h = fmix(seed % 4294967296)
	h = fmix(bit32.bxor(h, i * 73856093 % 4294967296))
	h = fmix(bit32.bxor(h, j * 19349663 % 4294967296))
	return h / 4294967296
end

function CityPlan.centre(blocksX: number, blocksZ: number): (number, number)
	return blocksX // 2, blocksZ // 2
end

-- how far a block is from the spawn block, in blocks (the downtown ring is < 2.5)
function CityPlan.distance(i: number, j: number, blocksX: number, blocksZ: number): number
	local ci, cj = CityPlan.centre(blocksX, blocksZ)
	return math.max(math.abs(i - ci + 0.5), math.abs(j - cj + 0.5))
end

-- kinds[i][j] for i in 0..blocksX-1, j in 0..blocksZ-1
function CityPlan.plan(
	blocksX: number,
	blocksZ: number,
	seed: number
): { [number]: { [number]: Kind } }
	local ci, cj = CityPlan.centre(blocksX, blocksZ)
	local fixed: { [string]: Kind } = {
		[`{ci},{cj}`] = "spawn",
		[`{ci},{math.max(cj - 1, 0)}`] = "restaurant",
		[`{0},{cj}`] = "warehouse",
		[`{math.max(ci - 3, 1)},{math.min(cj + 2, blocksZ - 1)}`] = "restaurant",
	}
	local kinds = {}
	for i = 0, blocksX - 1 do
		kinds[i] = {}
		for j = 0, blocksZ - 1 do
			local kind: Kind? = fixed[`{i},{j}`]
			if not kind then
				local r = CityPlan.roll(seed, i, j)
				if CityPlan.distance(i, j, blocksX, blocksZ) < 2.5 then
					kind = if r < 0.64
						then "office"
						elseif r < 0.8 then "plaza"
						elseif r < 0.9 then "park"
						else "parking"
				else
					kind = if r < 0.5
						then "homes"
						elseif r < 0.6 then "shops"
						elseif r < 0.7 then "park"
						elseif r < 0.82 then "plaza"
						elseif r < 0.92 then "parking"
						else "office"
				end
			end
			kinds[i][j] = kind :: Kind
		end
	end
	return kinds
end

function CityPlan.count(kinds: { [number]: { [number]: Kind } }): { [string]: number }
	local out: { [string]: number } = {}
	for _, column in kinds do
		for _, kind in column do
			out[kind] = (out[kind] or 0) + 1
		end
	end
	return out
end

return CityPlan
