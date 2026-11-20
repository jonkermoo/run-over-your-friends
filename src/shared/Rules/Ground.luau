--!strict
-- The countryside's gentle roll (Config/Country Roll): the open grass rises and dips a few studs in long,
-- smooth swells, so the land isn't a flat sheet. The roll is zero on and near everything that must stay level
-- (the city and its ring, roads, zones, suburbs, ponds, lakes, the yard of the farm) and fades in over `Fade`
-- studs past a `Margin`; it also fades out toward the island's edge and the coast. GroundKit raises the
-- terrain by it and lifts what stands on the grass by the same amount. Worn dirt paths are polylines whose
-- nearness is measured here too. Pure, so Lune tests it.

local Outskirts = if typeof(script) == "Instance"
	then require(script.Parent.Outskirts)
	else require("./Outskirts")
local Land = if typeof(script) == "Instance" then require(script.Parent.Land) else require("./Land")

local Ground = {}

export type Rect = Outskirts.Rect
export type Octave = { len: number, amp: number }
export type Roll = {
	Octaves: { Octave },
	Margin: number, -- level this far round every kept-level rect
	Fade: number, -- then the roll fades in over this far
	EdgeFade: number, -- and fades out over this far inside the island's edge and the coast
	Seed: number,
	Cell: number, -- the rect index's bucket size
}
export type Index = {
	cell: number,
	reach: number,
	buckets: { [number]: { Rect } },
}
-- a field outline's waves: lengths along u and v (two each) and the second wave's share
export type Waves = { u: { number }, v: { number }, second: number }
export type Segment = { ax: number, az: number, bx: number, bz: number }
export type SegIndex = {
	cell: number,
	reach: number,
	buckets: { [number]: { Segment } },
}

local KEY_OFFSET = 4096

local function key(ix: number, iz: number): number
	return (ix + KEY_OFFSET) * 8192 + (iz + KEY_OFFSET)
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
Ground.smooth = smooth

-- the rects, sorted into buckets `cell` wide, each bucket holding every rect within `reach` of it
function Ground.index(rects: { Rect }, reach: number, cell: number): Index
	local buckets: { [number]: { Rect } } = {}
	for _, r in rects do
		local x0 = math.floor((r.x - r.w / 2 - reach) / cell)
		local x1 = math.floor((r.x + r.w / 2 + reach) / cell)
		local z0 = math.floor((r.z - r.d / 2 - reach) / cell)
		local z1 = math.floor((r.z + r.d / 2 + reach) / cell)
		for ix = x0, x1 do
			for iz = z0, z1 do
				local k = key(ix, iz)
				local list = buckets[k]
				if not list then
					list = {}
					buckets[k] = list
				end
				table.insert(list, r)
			end
		end
	end
	return { cell = cell, reach = reach, buckets = buckets }
end

-- how far (x, z) is from the nearest indexed rect (0 inside one), at most the index's reach
function Ground.clearance(index: Index, x: number, z: number): number
	local list = index.buckets[key(math.floor(x / index.cell), math.floor(z / index.cell))]
	local best = index.reach
	if list then
		for _, r in list do
			local d = Outskirts.distance(r, x, z)
			if d < best then
				best = d
				if d <= 0 then
					return 0
				end
			end
		end
	end
	return best
end

-- 0 on and near the kept-level rects, rising smoothly to 1 past Margin + Fade
function Ground.weight(roll: Roll, index: Index, x: number, z: number): number
	return smooth((Ground.clearance(index, x, z) - roll.Margin) / roll.Fade)
end

-- a repeatable 0..1 value for a lattice point
local function hash(ix: number, iz: number, seed: number): number
	local n = bit32.bxor(
		(ix * 73856093) % 4294967296,
		(iz * 19349663) % 4294967296,
		(seed * 83492791) % 4294967296
	)
	n = bit32.bxor(n, bit32.rshift(n, 13))
	n = (n * 1274126177) % 4294967296
	n = bit32.bxor(n, bit32.rshift(n, 16))
	return n / 4294967296
end

-- smooth value noise, 0..1
local function valueNoise(x: number, z: number, seed: number): number
	local ix, iz = math.floor(x), math.floor(z)
	local fx, fz = smooth(x - ix), smooth(z - iz)
	local a = hash(ix, iz, seed)
	local b = hash(ix + 1, iz, seed)
	local c = hash(ix, iz + 1, seed)
	local d = hash(ix + 1, iz + 1, seed)
	return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fz
end

-- the roll's full height at (x, z) before any fading: 0 .. the octaves' summed amp
function Ground.noise(roll: Roll, x: number, z: number): number
	local h = 0
	for i, o in roll.Octaves do
		h += o.amp * valueNoise(x / o.len, z / o.len, roll.Seed + i * 101)
	end
	return h
end

-- the most the roll can ever be
function Ground.maxRise(roll: Roll): number
	local h = 0
	for _, o in roll.Octaves do
		h += o.amp
	end
	return h
end

-- how far inside the land (x, z) is: from the island's edge and from the coast
function Ground.inland(shape: Land.Shape, seaEdge: number, x: number, z: number): number
	return math.min(Land.inset(shape, x, z), x - Land.coast(shape, seaEdge, z))
end

-- how much the ground at (x, z) rises: the roll, faded near kept-level rects, the edge and the coast
function Ground.lift(
	roll: Roll,
	index: Index,
	shape: Land.Shape,
	seaEdge: number,
	x: number,
	z: number
): number
	local w = Ground.weight(roll, index, x, z)
	if w <= 0 then
		return 0
	end
	w *= smooth(Ground.inland(shape, seaEdge, x, z) / roll.EdgeFade)
	if w <= 0 then
		return 0
	end
	return w * Ground.noise(roll, x, z)
end

-- path segments, sorted into buckets `cell` wide, each holding every segment within `reach` of it
function Ground.segIndex(paths: { { { number } } }, reach: number, cell: number): SegIndex
	local buckets: { [number]: { Segment } } = {}
	for _, pts in paths do
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local s = { ax = a[1], az = a[2], bx = b[1], bz = b[2] }
			for ix = math.floor((math.min(s.ax, s.bx) - reach) / cell), math.floor((math.max(s.ax, s.bx) + reach) / cell) do
				for iz = math.floor((math.min(s.az, s.bz) - reach) / cell), math.floor((math.max(s.az, s.bz) + reach) / cell) do
					local k = key(ix, iz)
					local list = buckets[k]
					if not list then
						list = {}
						buckets[k] = list
					end
					table.insert(list, s)
				end
			end
		end
	end
	return { cell = cell, reach = reach, buckets = buckets }
end

-- how far (x, z) is from the nearest path (at most the index's reach)
function Ground.pathDistance(index: SegIndex, x: number, z: number): number
	local list = index.buckets[key(math.floor(x / index.cell), math.floor(z / index.cell))]
	local best = index.reach
	if list then
		for _, s in list do
			local dx, dz = s.bx - s.ax, s.bz - s.az
			local len2 = dx * dx + dz * dz
			local t = if len2 > 0
				then math.clamp(((x - s.ax) * dx + (z - s.az) * dz) / len2, 0, 1)
				else 0
			local px, pz = s.ax + dx * t - x, s.az + dz * t - z
			local d = math.sqrt(px * px + pz * pz)
			if d < best then
				best = d
			end
		end
	end
	return best
end

-- a wandering path from (x, z) heading `angle`: `steps` legs of `step` studs, turning by up to `turn` radians
-- each leg (`rng` gives 0..1); it stops early where `ok(x, z)` says no
function Ground.wander(
	x: number,
	z: number,
	angle: number,
	steps: number,
	step: number,
	turn: number,
	rng: () -> number,
	ok: (number, number) -> boolean
): { { number } }
	local pts = { { x, z } }
	for _ = 1, steps do
		angle += (rng() * 2 - 1) * turn
		local nx, nz = x + math.cos(angle) * step, z + math.sin(angle) * step
		if not ok(nx, nz) then
			break
		end
		x, z = nx, nz
		table.insert(pts, { x, z })
	end
	return pts
end

-- a point in a field's own frame: `u` along its rows, `v` across them (the field turned `angle` about its centre)
function Ground.fieldFrame(
	cx: number,
	cz: number,
	angle: number,
	x: number,
	z: number
): (number, number)
	local dx, dz = x - cx, z - cz
	local c, s = math.cos(angle), math.sin(angle)
	return dx * c + dz * s, -dx * s + dz * c
end

-- whether a field (w along its rows, d across, turned `angle`) covers (x, z); its edges wobble by `wobble`
-- studs so the outline isn't ruler-straight
function Ground.inField(
	cx: number,
	cz: number,
	w: number,
	d: number,
	angle: number,
	wobble: number,
	waves: Waves,
	x: number,
	z: number
): boolean
	local u, v = Ground.fieldFrame(cx, cz, angle, x, z)
	local second = wobble * waves.second
	local wu = wobble * math.sin(v / waves.v[1] + cx * 0.01)
		+ second * math.sin(v / waves.v[2] + cz * 0.02)
	local wv = wobble * math.sin(u / waves.u[1] + cz * 0.01)
		+ second * math.sin(u / waves.u[2] + cx * 0.02)
	return math.abs(u) < w / 2 + wu and math.abs(v) < d / 2 + wv
end

return Ground
