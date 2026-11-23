--!strict
-- Where street life goes (Config/StreetLife), pure so Lune tests it: which block sides get kerb parking or
-- roadworks, and where a car park's edge bays stand clear of its ramps' runs.

local StreetLife = {}

export type Rect = { number } -- x0, z0, x1, z1
export type Side = { i: number, j: number, side: number }
export type Bay = { x: number, z: number, dx: number, dz: number } -- the bay's middle; (dx, dz) its nose

-- a block's four sides as the way out of it: north, south, west, east
StreetLife.SIDES = table.freeze({
	table.freeze({ 0, -1 }),
	table.freeze({ 0, 1 }),
	table.freeze({ -1, 0 }),
	table.freeze({ 1, 0 }),
})

-- the block sides of these kinds, leaving out any side that faces the spawn block (its ring stays clear)
function StreetLife.sides(
	plan: { [number]: { [number]: string } },
	blocksX: number,
	blocksZ: number,
	kinds: { [string]: boolean }
): { Side }
	local out = {}
	for i = 0, blocksX - 1 do
		for j = 0, blocksZ - 1 do
			if kinds[plan[i][j]] then
				for s, d in StreetLife.SIDES do
					local ni, nj = i + d[1], j + d[2]
					local facesSpawn = ni >= 0
						and ni < blocksX
						and nj >= 0
						and nj < blocksZ
						and plan[ni][nj] == "spawn"
					if not facesSpawn then
						table.insert(out, { i = i, j = j, side = s })
					end
				end
			end
		end
	end
	return out
end

-- whether the box x0..x1, z0..z1 overlaps any of the rects
function StreetLife.hits(rects: { Rect }, x0: number, z0: number, x1: number, z1: number): boolean
	for _, r in rects do
		if x0 < r[3] and x1 > r[1] and z0 < r[4] and z1 > r[2] then
			return true
		end
	end
	return false
end

-- a car park's bays round its edge (`inner` across, from its middle), nose to the edge, none in `keepOut`
function StreetLife.lotBays(
	inner: number,
	bay: { number },
	edge: number,
	corner: number,
	keepOut: { Rect }
): { Bay }
	local bw, bd = bay[1], bay[2]
	local half = inner / 2
	local reach = half - corner -- the rows run between -reach and reach
	local n = math.floor(reach * 2 / bw)
	local out = {}
	local rowAt = half - edge - bd / 2
	for _, d in StreetLife.SIDES do
		local dx, dz = d[1], d[2]
		for k = 0, n - 1 do
			local t = -n * bw / 2 + (k + 0.5) * bw
			-- along the side: across the nose direction
			local x, z = dx * rowAt + dz * t, dz * rowAt + dx * t
			local hx, hz = if dx ~= 0 then bd / 2 else bw / 2, if dx ~= 0 then bw / 2 else bd / 2
			if not StreetLife.hits(keepOut, x - hx, z - hz, x + hx, z + hz) then
				table.insert(out, { x = x, z = z, dx = dx, dz = dz })
			end
		end
	end
	return out
end

-- the boards round a rect (x0, z0, x1, z1), `len` long each, leaving `gate` open in the middle of its east side:
-- each board's middle, its length and whether it runs along x
export type Board = { x: number, z: number, len: number, alongX: boolean }
function StreetLife.hoarding(area: Rect, len: number, gate: number): { Board }
	local out = {}
	local x0, z0, x1, z1 = area[1], area[2], area[3], area[4]
	local function run(a: number, b: number, fixed: number, alongX: boolean, skipMid: boolean)
		local n = math.max(1, math.floor((b - a) / len + 0.5))
		local step = (b - a) / n
		local mid = (a + b) / 2
		for k = 0, n - 1 do
			local t = a + (k + 0.5) * step
			if not (skipMid and math.abs(t - mid) < gate / 2) then
				if alongX then
					table.insert(out, { x = t, z = fixed, len = step, alongX = true })
				else
					table.insert(out, { x = fixed, z = t, len = step, alongX = false })
				end
			end
		end
	end
	run(x0, x1, z0, true, false)
	run(x0, x1, z1, true, false)
	run(z0, z1, x0, false, false)
	run(z0, z1, x1, false, true)
	return out
end

return StreetLife
