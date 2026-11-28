--!strict
-- Where every road goes, as plain numbers: the city grid (ragged: Config/World Map.Mask), the loop road round it and its stubs, the connectors to
-- the zones, the suburbs' feeders and curving streets, and the downtown lane paint. The game builds its
-- road collision and terrain from this, and the road meshes (Config/RoadMeshes, tools/roads) were made from
-- the same numbers: `RoadLayout.hash` of the layout is stored with the meshes, so a test fails if the layout
-- changes without new meshes. Pure, so Lune runs it. Points are { x, z }.

local RoadLayout = {}

export type Pt = { number }
export type Street = { pts: { Pt }, bulb: boolean }
export type Road = { kind: string, pts: { Pt }, width: number }
export type Stroke = { x: number, z: number, w: number, d: number, yellow: boolean }
export type Rect = { x: number, z: number, w: number, d: number }
export type Layout = {
	grid: {
		block: number,
		road: number,
		pitch: number,
		nx: number,
		nz: number,
		x0: number,
		z0: number,
	},
	has: { [number]: { [number]: boolean } }, -- has[i][j]: the block stands (Config/World Map.Mask)
	mask: { string }, -- the same as rows of "X" and "." north to south (1-based, for the JSON tools)
	merged: { [string]: boolean }, -- road segments left out between merged blocks (RoadLayout.mergeKeys)
	plazas: { Rect }, -- where those segments would be: paved for people, no cars
	ring: number, -- the loop's furthest centre-line point from the middle
	ringInner: number, -- and its nearest
	ringOuter: number,
	loop: { Pt }, -- the loop road's centre line, closed (the last point is the first)
	roads: { Road },
	bulbs: { { number } },
	strokes: { Stroke },
	manholes: { Pt },
	connectors: { Rect }, -- each connector's bounding box (for keeping things clear of it)
	links: { { pts: { Pt }, zone: string } }, -- the connectors' centre lines
	suburbs: { { name: string, streets: { Street } } },
}

-- a seeded stream of numbers in [0, 1): murmur3's finaliser on (seed, n), exact in doubles
local function mul32(a: number, b: number): number
	local alo, ahi = a % 65536, a // 65536
	local blo, bhi = b % 65536, b // 65536
	return ((ahi * blo + alo * bhi) % 65536 * 65536 + alo * blo) % 4294967296
end

local function fmix(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85ebca6b)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xc2b2ae35)
	return bit32.bxor(h, bit32.rshift(h, 16))
end

function RoadLayout.stream(seed: number): (lo: number?, hi: number?) -> number
	local base = fmix(seed % 4294967296)
	local n = 0
	return function(lo: number?, hi: number?): number
		n += 1
		local u = fmix(bit32.bxor(base, mul32(n, 0x9e3779b9))) / 4294967296
		if lo and hi then
			return lo + (hi - lo) * u
		end
		return u
	end
end

-- one suburb's streets (Config/Suburbs hood `h`): the spine first, then side streets off both sides
export type SuburbCfg = {
	Step: number,
	SpineWave: { number },
	BranchFirst: number,
	BranchGap: { number },
	BranchStagger: { number },
	BranchBend: number,
	BranchEnd: number,
}
export type Hood = { dir: { number }, offset: number, start: number, length: number, half: number }

function RoadLayout.hoodFrame(h: Hood): (Pt, Pt, Pt)
	local dir = { h.dir[1], h.dir[2] }
	local perp = { -dir[2], dir[1] }
	local origin = { math.abs(dir[2]) * h.offset, math.abs(dir[1]) * h.offset }
	return origin, dir, perp
end

function RoadLayout.streets(h: Hood, cfg: SuburbCfg, seed: number): { Street }
	local random = RoadLayout.stream(seed)
	local origin, dir, perp = RoadLayout.hoodFrame(h)
	local function at(u: number, v: number): Pt
		return { origin[1] + dir[1] * u + perp[1] * v, origin[2] + dir[2] * u + perp[2] * v }
	end
	local streets: { Street } = {}
	local wave = random(cfg.SpineWave[1], cfg.SpineWave[2])
	local spine: { Pt } = {}
	local spineV: { number } = {}
	local u = 0
	while u <= h.length do
		local v = wave * math.sin(u / h.length * math.pi * 1.6)
		table.insert(spine, at(h.start + u, v))
		table.insert(spineV, v)
		u += cfg.Step
	end
	table.insert(streets, { pts = spine, bulb = true })
	for _, s in { -1, 1 } do
		local first = cfg.BranchFirst
			+ (
				if s > 0
					then 0
					else random(cfg.BranchStagger[1], cfg.BranchStagger[2]) * cfg.BranchGap[1]
			)
		local along = first
		while along < h.length - 140 do
			local i = math.floor(along / cfg.Step) + 1
			local baseU = h.start + (i - 1) * cfg.Step
			local v0 = spineV[i]
			local reach = h.half - cfg.BranchEnd - s * v0
			local bend = random(-1, 1) * cfg.BranchBend
			local pts: { Pt } = {}
			local t = 0
			while t <= reach do
				local k = t / reach
				table.insert(pts, at(baseU + bend * k * k, v0 + s * t))
				t += cfg.Step
			end
			if #pts >= 4 then
				table.insert(streets, { pts = pts, bulb = true })
			end
			along += random(cfg.BranchGap[1], cfg.BranchGap[2])
		end
	end
	return streets
end

-- the paint of one downtown road segment (between two crossings), centred on 0; `alongX` for east-west
-- roads. Each stroke is a rectangle: centre (x, z), size w (x) by d (z).
export type PaintCfg = {
	LineWidth: number,
	DashLength: number,
	DashGap: number,
	ZebraStripes: number,
	ZebraLength: number,
	ZebraInset: number,
	StopLineInset: number,
	EndClear: number,
}

function RoadLayout.segmentStrokes(B: number, R: number, S: PaintCfg, alongX: boolean): { Stroke }
	local out: { Stroke } = {}
	local function put(
		along: number,
		across: number,
		lenAlong: number,
		lenAcross: number,
		yellow: boolean
	)
		if alongX then
			table.insert(
				out,
				{ x = along, z = across, w = lenAlong, d = lenAcross, yellow = yellow }
			)
		else
			table.insert(
				out,
				{ x = across, z = along, w = lenAcross, d = lenAlong, yellow = yellow }
			)
		end
	end
	local len = B - 2 * S.EndClear
	put(0, -0.55, len, S.LineWidth, true)
	put(0, 0.55, len, S.LineWidth, true)
	local t = -len / 2
	while t + S.DashLength <= len / 2 do
		put(t + S.DashLength / 2, -R / 4, S.DashLength, S.LineWidth, false)
		put(t + S.DashLength / 2, R / 4, S.DashLength, S.LineWidth, false)
		t += S.DashLength + S.DashGap
	end
	-- zebras where the sidewalk crossings run, one at each end
	for _, e in { -1, 1 } do
		local at = e * (B / 2 - S.ZebraInset)
		for s = 0, S.ZebraStripes - 1 do
			put(
				at,
				-R / 2 + (s + 0.5) * R / S.ZebraStripes,
				S.ZebraLength,
				R / S.ZebraStripes * 0.55,
				false
			)
		end
	end
	-- stop lines on the half where traffic arrives (keep right)
	local right = if alongX then 1 else -1
	put(B / 2 - S.StopLineInset, right * R / 4, 1.2, R / 2 - 2, false)
	put(-(B / 2 - S.StopLineInset), -right * R / 4, 1.2, R / 2 - 2, false)
	return out
end

export type Inputs = {
	map: {
		BlockSize: number,
		RoadWidth: number,
		BlocksX: number,
		BlocksZ: number,
		Mask: { string }?,
		Merges: { { number } }?,
	},
	ring: {
		Gap: number,
		Width: number,
		Connector: number,
		Points: number?,
		Smooth: number?,
		Window: number?,
		StubOut: number?,
	},
	zones: { [string]: Rect }?, -- filled in by `build` from `zonesOf`
	zonesOf: (ringOuter: number) -> { [string]: Rect },
	paint: PaintCfg,
	suburbs: SuburbCfg & { Hoods: { Hood & { name: string } }, Feeder: { width: number } },
	seed: number,
}

-- which blocks stand: `mask[j]` is row j (north to south), one character per block west to east, "X" for a
-- block; no mask means every block
function RoadLayout.blockSet(
	map: { BlocksX: number, BlocksZ: number, Mask: { string }? }
): { [number]: { [number]: boolean } }
	local has = {}
	for i = 0, map.BlocksX - 1 do
		has[i] = {}
		for j = 0, map.BlocksZ - 1 do
			local row = map.Mask and map.Mask[j + 1]
			has[i][j] = row == nil or string.sub(row, i + 1, i + 1) == "X"
		end
	end
	return has
end

-- a merge joins two neighbouring blocks across the road between them (that road is left out); the key
-- names the road segment: "v,k,m" is the north-south segment on line k between crossings m and m + 1,
-- "h,k,m" the east-west one on line m between crossings k and k + 1
function RoadLayout.mergeKeys(merges: { { number } }?): { [string]: boolean }
	local out = {}
	for _, m in merges or {} do
		local i, j, i2, j2 = m[1], m[2], m[3], m[4]
		if j == j2 then
			out[`v,{math.max(i, i2)},{j}`] = true
		else
			out[`h,{i},{math.max(j, j2)}`] = true
		end
	end
	return out
end

-- where a ray from `from` along unit `dir` first meets the closed polyline `loop` (distance along the ray)
function RoadLayout.hitLoop(loop: { Pt }, from: Pt, dir: Pt): number?
	local best: number? = nil
	for n = 1, #loop - 1 do
		local a, b = loop[n], loop[n + 1]
		local ex, ez = b[1] - a[1], b[2] - a[2]
		local den = dir[1] * ez - dir[2] * ex
		if math.abs(den) > 1e-9 then
			local wx, wz = a[1] - from[1], a[2] - from[2]
			local t = (wx * ez - wz * ex) / den
			local s = (wx * dir[2] - wz * dir[1]) / den
			if t > 0 and s >= 0 and s <= 1 and (best == nil or t < best) then
				best = t
			end
		end
	end
	return best
end

-- is the point inside the closed polyline?
function RoadLayout.inside(loop: { Pt }, x: number, z: number): boolean
	local c = false
	local n = #loop
	local j = n
	for i = 1, n do
		local a, b = loop[i], loop[j]
		if (a[2] > z) ~= (b[2] > z) and x < (b[1] - a[1]) * (z - a[2]) / (b[2] - a[2]) + a[1] then
			c = not c
		end
		j = i
	end
	return c
end

-- how far the point is from the polyline (open or closed)
function RoadLayout.distance(pts: { Pt }, x: number, z: number): number
	local best = math.huge
	for n = 1, #pts - 1 do
		local a, b = pts[n], pts[n + 1]
		local ex, ez = b[1] - a[1], b[2] - a[2]
		local len2 = ex * ex + ez * ez
		local t = if len2 > 0
			then math.clamp(((x - a[1]) * ex + (z - a[2]) * ez) / len2, 0, 1)
			else 0
		local dx, dz = x - (a[1] + ex * t), z - (a[2] + ez * t)
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end
	return best
end

-- the whole road layout
function RoadLayout.build(I: Inputs): Layout
	local B, R = I.map.BlockSize, I.map.RoadWidth
	local pitch = B + R
	local nx, nz = I.map.BlocksX, I.map.BlocksZ
	local spanX, spanZ = nx * pitch + R, nz * pitch + R
	local x0, z0 = -spanX / 2, -spanZ / 2
	local RW = I.ring.Width
	local roads: { Road } = {}
	local strokes: { Stroke } = {}
	local manholes: { Pt } = {}
	local has = RoadLayout.blockSet(I.map)
	local mask: { string } = {}
	for j = 0, nz - 1 do
		local row = ""
		for i = 0, nx - 1 do
			row ..= if has[i][j] then "X" else "."
		end
		table.insert(mask, row)
	end
	local merged = RoadLayout.mergeKeys(I.map.Merges)
	local function block(i: number, j: number): boolean
		return i >= 0 and j >= 0 and i < nx and j < nz and has[i][j]
	end
	local function rx(k: number): number
		return x0 + R / 2 + k * pitch
	end
	local function rz(k: number): number
		return z0 + R / 2 + k * pitch
	end
	-- the city's road segments: one wherever a block stands on either side, unless the two sides are merged
	local function vSeg(k: number, m: number): boolean
		return (block(k - 1, m) or block(k, m)) and not merged[`v,{k},{m}`]
	end
	local function hSeg(k: number, m: number): boolean
		return (block(k, m - 1) or block(k, m)) and not merged[`h,{k},{m}`]
	end
	local plazas: { Rect } = {}
	for key in merged do
		local parts = string.split(key, ",")
		local k, m = tonumber(parts[2]) :: number, tonumber(parts[3]) :: number
		if parts[1] == "v" then
			table.insert(plazas, { x = rx(k), z = rz(m) + pitch / 2, w = R, d = B })
		else
			table.insert(plazas, { x = rx(k) + pitch / 2, z = rz(m), w = B, d = R })
		end
	end
	-- runs of segments along each grid line become one road each
	local ends: { { pt: Pt, dir: Pt } } = {} -- the open ends of the grid, where a stub runs out to the loop
	local function runs(count: number, seg: (n: number) -> boolean, at: (n: number) -> Pt, out: Pt)
		local n = 0
		while n < count do
			if seg(n) then
				local first = n
				while n < count and seg(n) do
					n += 1
				end
				table.insert(roads, { kind = "town", pts = { at(first), at(n) }, width = R })
				table.insert(ends, { pt = at(first), dir = { -out[1], -out[2] } })
				table.insert(ends, { pt = at(n), dir = out })
			else
				n += 1
			end
		end
	end
	for k = 0, nx do
		runs(nz, function(m)
			return vSeg(k, m)
		end, function(m)
			return { rx(k), rz(m) }
		end, { 0, 1 })
	end
	for m = 0, nz do
		runs(nx, function(k)
			return hSeg(k, m)
		end, function(k)
			return { rx(k), rz(m) }
		end, { 1, 0 })
	end
	-- downtown paint and manholes (as StreetKit used to draw them)
	local function addStrokes(cx: number, cz: number, alongX: boolean)
		for _, st in RoadLayout.segmentStrokes(B, R, I.paint, alongX) do
			table.insert(
				strokes,
				{ x = cx + st.x, z = cz + st.z, w = st.w, d = st.d, yellow = st.yellow }
			)
		end
	end
	local crossing: { [string]: boolean } = {}
	for k = 0, nx do
		for m = 0, nz - 1 do
			if vSeg(k, m) then
				addStrokes(rx(k), rz(m) + R / 2 + B / 2, false)
				crossing[`{k},{m}`] = true
				crossing[`{k},{m + 1}`] = true
			end
		end
	end
	for m = 0, nz do
		for k = 0, nx - 1 do
			if hSeg(k, m) then
				addStrokes(rx(k) + R / 2 + B / 2, rz(m), true)
				crossing[`{k},{m}`] = true
				crossing[`{k + 1},{m}`] = true
			end
		end
	end
	for k = 0, nx do
		for m = 0, nz do
			if crossing[`{k},{m}`] then
				table.insert(manholes, { rx(k) + 9, rz(m) + 9 })
			end
		end
	end
	-- the loop: round the town at `Gap` past its outer roads, following its ragged edge. For each direction,
	-- the furthest point of the town (blocks grown by their roads) within a window either side, smoothed.
	local outline: { Pt } = {}
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			if has[i][j] then
				local ax, bx = rx(i) - R / 2, rx(i + 1) + R / 2
				local az, bz = rz(j) - R / 2, rz(j + 1) + R / 2
				for _, p in
					{
						{ ax, az },
						{ bx, az },
						{ ax, bz },
						{ bx, bz },
						{ (ax + bx) / 2, az },
						{ (ax + bx) / 2, bz },
						{ ax, (az + bz) / 2 },
						{ bx, (az + bz) / 2 },
					}
				do
					table.insert(outline, p)
				end
			end
		end
	end
	local N = I.ring.Points or 96
	local window = I.ring.Window or math.pi / 9
	local radius: { number } = {}
	for n = 1, N do
		local a = (n - 1) / N * 2 * math.pi
		local far = 0
		for _, p in outline do
			local d = math.abs((math.atan2(p[2], p[1]) - a + math.pi) % (2 * math.pi) - math.pi)
			if d < window then
				far = math.max(far, math.sqrt(p[1] * p[1] + p[2] * p[2]) * math.cos(d))
			end
		end
		radius[n] = far
	end
	for _ = 1, I.ring.Smooth or 3 do
		local was = table.clone(radius)
		for n = 1, N do
			local l, r = was[(n - 2) % N + 1], was[n % N + 1]
			radius[n] = math.max(was[n], (l + 2 * was[n] + r) / 4)
		end
	end
	local loop: { Pt } = {}
	for n = 1, N do
		local a = (n - 1) / N * 2 * math.pi
		local r = radius[n] + I.ring.Gap
		table.insert(loop, { math.cos(a) * r, math.sin(a) * r })
	end
	table.insert(loop, loop[1])
	local ring, ringInner = 0, math.huge
	for n = 1, N do
		local d = math.sqrt(loop[n][1] ^ 2 + loop[n][2] ^ 2)
		ring = math.max(ring, d)
		ringInner = math.min(ringInner, d)
	end
	local ringOuter = ring + RW / 2
	-- the loop road runs one step past its start, so the mesh closes without a seam
	local loopRoad = table.clone(loop)
	table.insert(loopRoad, loop[2])
	table.insert(roads, { kind = "ring", pts = loopRoad, width = RW })
	-- stubs: the open ends of the grid that point out of town run straight on to the loop (an end running
	-- along the town's edge stays a corner)
	for _, e in ends do
		local t = RoadLayout.hitLoop(loop, e.pt, e.dir)
		local d = math.sqrt(e.pt[1] ^ 2 + e.pt[2] ^ 2)
		local out = if d > 0 then (e.pt[1] * e.dir[1] + e.pt[2] * e.dir[2]) / d else 0
		if t and t > R / 2 and out >= (I.ring.StubOut or 0.8) then
			table.insert(roads, {
				kind = "stub",
				pts = { e.pt, { e.pt[1] + e.dir[1] * t, e.pt[2] + e.dir[2] * t } },
				width = R,
			})
		end
	end
	-- connectors from the loop to the zones: from the loop's nearest point to the zone's near side, bowed
	local zones = I.zonesOf(ringOuter)
	local connectors: { Rect } = {}
	local links: { { pts: { Pt }, zone: string } } = {}
	local bow = RoadLayout.stream(I.seed + 77)
	for _, key in { "stunt", "port", "desert", "site" } do
		local z = zones[key]
		local d = math.sqrt(z.x * z.x + z.z * z.z)
		local u = { z.x / d, z.z / d }
		-- the zone's side facing the middle
		local q: Pt = if math.abs(u[1]) * z.d > math.abs(u[2]) * z.w
			then { z.x - math.sign(u[1]) * z.w / 2, z.z }
			else { z.x, z.z - math.sign(u[2]) * z.d / 2 }
		local t = RoadLayout.hitLoop(loop, { 0, 0 }, u) :: number
		local p: Pt = { u[1] * (t - RW / 4), u[2] * (t - RW / 4) }
		local dx, dz = q[1] - p[1], q[2] - p[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local side = bow(-0.18, 0.18) * len
		local c: Pt = { (p[1] + q[1]) / 2 - dz / len * side, (p[2] + q[2]) / 2 + dx / len * side }
		local pts: { Pt } = {}
		local steps = math.max(2, math.ceil(len / 40))
		for s = 0, steps do
			local k = s / steps
			local a, b2, c2 = (1 - k) ^ 2, 2 * (1 - k) * k, k * k
			table.insert(
				pts,
				{ a * p[1] + b2 * c[1] + c2 * q[1], a * p[2] + b2 * c[2] + c2 * q[2] }
			)
		end
		-- run on into the zone a little so the road meets its ground
		table.insert(pts, { q[1] + u[1] * 20, q[2] + u[2] * 20 })
		table.insert(roads, { kind = "connector", pts = pts, width = I.ring.Connector })
		table.insert(links, { pts = pts, zone = key })
		local lx, hx, lz, hz = math.huge, -math.huge, math.huge, -math.huge
		for _, pt in pts do
			lx, hx = math.min(lx, pt[1]), math.max(hx, pt[1])
			lz, hz = math.min(lz, pt[2]), math.max(hz, pt[2])
		end
		local half = I.ring.Connector / 2
		table.insert(connectors, {
			x = (lx + hx) / 2,
			z = (lz + hz) / 2,
			w = hx - lx + 2 * half,
			d = hz - lz + 2 * half,
		})
	end
	-- the suburbs: a feeder from the loop out along the hood's axis, then the streets (bulbs at their ends)
	local suburbs = {}
	local bulbs: { { number } } = {}
	local Sub = I.suburbs
	for n, h in Sub.Hoods do
		local origin, dir = RoadLayout.hoodFrame(h)
		local t = RoadLayout.hitLoop(loop, origin, dir) or h.start
		local a = { origin[1] + dir[1] * (t - RW / 4), origin[2] + dir[2] * (t - RW / 4) }
		local b = { origin[1] + dir[1] * (h.start + 2), origin[2] + dir[2] * (h.start + 2) }
		table.insert(roads, { kind = "feeder", pts = { a, b }, width = Sub.Feeder.width })
		local streets = RoadLayout.streets(h, Sub, I.seed + n)
		for _, st in streets do
			table.insert(roads, { kind = "street", pts = st.pts, width = (Sub :: any).Road })
			if st.bulb then
				local last = st.pts[#st.pts]
				table.insert(bulbs, { last[1], last[2], (Sub :: any).Bulb })
			end
		end
		table.insert(suburbs, { name = h.name, streets = streets })
	end
	return {
		grid = { block = B, road = R, pitch = pitch, nx = nx, nz = nz, x0 = x0, z0 = z0 },
		has = has,
		mask = mask,
		merged = merged,
		plazas = plazas,
		ring = ring,
		ringInner = ringInner,
		ringOuter = ringOuter,
		loop = loop,
		roads = roads,
		bulbs = bulbs,
		strokes = strokes,
		manholes = manholes,
		connectors = connectors,
		links = links,
		suburbs = suburbs,
	}
end

-- do all four roads meet at crossing (k, m)?
function RoadLayout.fourWay(L: Layout, k: number, m: number): boolean
	return RoadLayout.segment(L, k, m, k + 1, m)
		and RoadLayout.segment(L, k - 1, m, k, m)
		and RoadLayout.segment(L, k, m, k, m + 1)
		and RoadLayout.segment(L, k, m - 1, k, m)
end

-- does the road segment between two neighbouring crossings exist? (k, m) to (k2, m2), one step apart
function RoadLayout.segment(L: Layout, k: number, m: number, k2: number, m2: number): boolean
	local nx, nz = L.grid.nx, L.grid.nz
	local function block(i: number, j: number): boolean
		return i >= 0 and j >= 0 and i < nx and j < nz and L.has[i][j]
	end
	if k == k2 then
		local lo = math.min(m, m2)
		return (block(k - 1, lo) or block(k, lo)) and not L.merged[`v,{k},{lo}`]
	end
	local lo = math.min(k, k2)
	return (block(lo, m - 1) or block(lo, m)) and not L.merged[`h,{lo},{m}`]
end

-- the layout from the game's own Config (what the map builder and the mesh tools both use)
local cached: Layout? = nil
function RoadLayout.fromConfig(): Layout
	if cached then
		return cached
	end
	local inRoblox = typeof(script) == "Instance"
	local World = if inRoblox
		then require(script.Parent.Parent.Config.World)
		else require("../Config/World")
	local Out = if inRoblox
		then require(script.Parent.Parent.Config.Outskirts)
		else require("../Config/Outskirts")
	local Streets = if inRoblox
		then require(script.Parent.Parent.Config.Streets)
		else require("../Config/Streets")
	local Suburbs = if inRoblox
		then require(script.Parent.Parent.Config.Suburbs)
		else require("../Config/Suburbs")
	local Land = if inRoblox
		then require(script.Parent.Parent.Config.Land)
		else require("../Config/Land")
	local Zones = if inRoblox then require(script.Parent.Outskirts) else require("./Outskirts")
	cached = RoadLayout.build({
		map = World.Map,
		ring = Out.Ring,
		zonesOf = function(ringOuter: number)
			return Zones.zones(ringOuter, Out.Stunt, Out.Port, Out.Desert, Out.Site) :: any
		end,
		paint = Streets :: any,
		suburbs = Suburbs :: any,
		seed = Land.SuburbSeed,
	})
	return cached :: Layout
end

-- a short fingerprint of everything the meshes were built from
function RoadLayout.hash(L: Layout): string
	local h = 5381
	local function feed(s: string)
		for i = 1, #s do
			h = bit32.bxor((h * 33) % 4294967296, string.byte(s, i))
		end
	end
	local function num(x: number)
		feed(string.format("%.2f;", x))
	end
	num(L.ring)
	num(L.ringOuter)
	for _, p in L.plazas do
		num(p.x)
		num(p.z)
	end
	for _, r in L.roads do
		feed(r.kind)
		num(r.width)
		for _, p in r.pts do
			num(p[1])
			num(p[2])
		end
	end
	for _, b in L.bulbs do
		num(b[1])
		num(b[2])
		num(b[3])
	end
	for _, s in L.strokes do
		num(s.x)
		num(s.z)
		num(s.w)
		num(s.d)
		feed(if s.yellow then "y" else "w")
	end
	for _, m in L.manholes do
		num(m[1])
		num(m[2])
	end
	return string.format("%08x", h)
end

return RoadLayout
