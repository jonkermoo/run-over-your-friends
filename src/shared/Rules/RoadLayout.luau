--!strict
-- Where every road goes, as plain numbers: the city grid, the highway ring and its stubs, the connectors to
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
	ring: number,
	ringOuter: number,
	roads: { Road },
	bulbs: { { number } },
	strokes: { Stroke },
	manholes: { Pt },
	connectors: { Rect },
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
	map: { BlockSize: number, RoadWidth: number, BlocksX: number, BlocksZ: number },
	ring: { Gap: number, Width: number, Connector: number },
	zones: { [string]: Rect }?, -- filled in by `build` from `zonesOf`
	zonesOf: (ringOuter: number) -> { [string]: Rect },
	paint: PaintCfg,
	suburbs: SuburbCfg & { Hoods: { Hood & { name: string } }, Feeder: { width: number } },
	seed: number,
}

-- the whole road layout
function RoadLayout.build(I: Inputs): Layout
	local B, R = I.map.BlockSize, I.map.RoadWidth
	local pitch = B + R
	local nx, nz = I.map.BlocksX, I.map.BlocksZ
	local spanX, spanZ = nx * pitch + R, nz * pitch + R
	local x0, z0 = -spanX / 2, -spanZ / 2
	local ring = math.max(spanX, spanZ) / 2 + I.ring.Gap
	local RW = I.ring.Width
	local ringOuter = ring + RW / 2
	local roads: { Road } = {}
	local strokes: { Stroke } = {}
	local manholes: { Pt } = {}
	local function rx(k: number): number
		return x0 + R / 2 + k * pitch
	end
	local function rz(k: number): number
		return z0 + R / 2 + k * pitch
	end
	-- city grid, then the stubs out to the ring
	for i = 0, nx do
		table.insert(roads, { kind = "town", pts = { { rx(i), z0 }, { rx(i), -z0 } }, width = R })
		for _, s in { 1, -1 } do
			table.insert(roads, {
				kind = "stub",
				pts = { { rx(i), s * spanZ / 2 }, { rx(i), s * ring } },
				width = R,
			})
		end
	end
	for j = 0, nz do
		table.insert(roads, { kind = "town", pts = { { x0, rz(j) }, { -x0, rz(j) } }, width = R })
		for _, s in { 1, -1 } do
			table.insert(roads, {
				kind = "stub",
				pts = { { s * spanX / 2, rz(j) }, { s * ring, rz(j) } },
				width = R,
			})
		end
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
	for k = 0, nx do
		for m = 0, nz - 1 do
			addStrokes(rx(k), rz(m) + R / 2 + B / 2, false)
		end
	end
	for m = 0, nz do
		for k = 0, nx - 1 do
			addStrokes(rx(k) + R / 2 + B / 2, rz(m), true)
		end
	end
	for k = 0, nx do
		for m = 0, nz do
			table.insert(manholes, { rx(k) + 9, rz(m) + 9 })
		end
	end
	-- the ring: four sides, each running past the corners by half its width so the square closes
	for _, s in { 1, -1 } do
		table.insert(roads, {
			kind = "ring",
			pts = { { s * ring, -ring - RW / 2 }, { s * ring, ring + RW / 2 } },
			width = RW,
		})
		table.insert(roads, {
			kind = "ring",
			pts = { { -ring - RW / 2, s * ring }, { ring + RW / 2, s * ring } },
			width = RW,
		})
	end
	-- connectors from the ring to the zones
	local zones = I.zonesOf(ringOuter)
	local connectors: { Rect } = {}
	for _, key in { "stunt", "port", "desert", "site" } do
		local z = zones[key]
		local alongX = z.z == 0
		local near = if alongX then math.abs(z.x) - z.w / 2 else math.abs(z.z) - z.d / 2
		local len = near - ring + 20
		local mid = ring + len / 2
		local rect: Rect = if alongX
			then { x = math.sign(z.x) * mid, z = 0, w = len, d = I.ring.Connector }
			else { x = 0, z = math.sign(z.z) * mid, w = I.ring.Connector, d = len }
		table.insert(connectors, rect)
		local pts = if alongX
			then { { math.sign(z.x) * ring, 0 }, { math.sign(z.x) * (ring + len), 0 } }
			else { { 0, math.sign(z.z) * ring }, { 0, math.sign(z.z) * (ring + len) } }
		table.insert(roads, { kind = "connector", pts = pts, width = I.ring.Connector })
	end
	-- the suburbs: a feeder out from the ring, then the streets (cul-de-sac bulbs at their ends)
	local suburbs = {}
	local bulbs: { { number } } = {}
	local Sub = I.suburbs
	for n, h in Sub.Hoods do
		local origin, dir = RoadLayout.hoodFrame(h)
		local a = { origin[1] + dir[1] * (ringOuter - 5), origin[2] + dir[2] * (ringOuter - 5) }
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
		ring = ring,
		ringOuter = ringOuter,
		roads = roads,
		bulbs = bulbs,
		strokes = strokes,
		manholes = manholes,
		connectors = connectors,
		suburbs = suburbs,
	}
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
