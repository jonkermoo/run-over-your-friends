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

-- how far a block is from the middle of the grid, in blocks (the downtown ring is < 2.5); on an odd grid the
-- middle is the spawn block itself
function CityPlan.distance(i: number, j: number, blocksX: number, blocksZ: number): number
	return math.max(math.abs(i - (blocksX - 1) / 2), math.abs(j - (blocksZ - 1) / 2))
end

-- does block (i, j) stand? `mask` rows north to south, "X" a block (Config/World Map.Mask); no mask, all do
function CityPlan.stands(mask: { string }?, i: number, j: number): boolean
	local row = mask and mask[j + 1]
	return row == nil or string.sub(row, i + 1, i + 1) == "X"
end

-- kinds[i][j] for i in 0..blocksX-1, j in 0..blocksZ-1; nil where no block stands (`mask`)
function CityPlan.plan(
	blocksX: number,
	blocksZ: number,
	seed: number,
	mask: { string }?
): { [number]: { [number]: Kind } }
	local ci, cj = CityPlan.centre(blocksX, blocksZ)
	local fixed: { [string]: Kind } = {}
	-- a fixed block goes on its spot, or the nearest standing block to it that is still free
	local function fix(i: number, j: number, kind: Kind)
		local bi, bj, bd = -1, -1, math.huge
		for oi = 0, blocksX - 1 do
			for oj = 0, blocksZ - 1 do
				local d = (oi - i) ^ 2 + (oj - j) ^ 2
				if CityPlan.stands(mask, oi, oj) and not fixed[`{oi},{oj}`] and d < bd then
					bi, bj, bd = oi, oj, d
				end
			end
		end
		if bi >= 0 then
			fixed[`{bi},{bj}`] = kind
		end
	end
	fix(ci, cj, "spawn")
	fix(ci, math.max(cj - 1, 0), "restaurant")
	fix(0, cj, "warehouse")
	fix(math.max(ci - 3, 1), math.min(cj + 2, blocksZ - 1), "restaurant")
	local kinds = {}
	for i = 0, blocksX - 1 do
		kinds[i] = {}
		for j = 0, blocksZ - 1 do
			if not CityPlan.stands(mask, i, j) then
				continue
			end
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
