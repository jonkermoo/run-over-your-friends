--!strict
-- The path an event vehicle drives (the Money Truck, the Boss Truck): a list of crossings on the road network
-- (Rules/Roads), driven in the right-hand lane with rounded corners, at a steady speed from a start time. The
-- server picks the crossings and puts them in a workspace attribute (encode); every screen builds the same
-- curve from them (build) and places its own copy of the vehicle on it (at), so it glides with nothing sent
-- per frame. Pure (x/z numbers), so Lune tests it.

local Roads = if typeof(script) == "Instance"
	then require(script.Parent.Roads)
	else require("./Roads")

local Route = {}

export type Piece = {
	s0: number, -- studs along the route where this piece starts
	len: number,
	curve: boolean,
	ax: number, -- a line from a to b; a curve from a to b bent towards c
	az: number,
	bx: number,
	bz: number,
	cx: number,
	cz: number,
	cum: { number }?, -- a curve: studs along it at each of CURVE_STEPS even steps of its parameter
}
export type Path = { pieces: { Piece }, length: number }

local CURVE_STEPS = 8

local function bezier(p: Piece, u: number): (number, number)
	local v = 1 - u
	return v * v * p.ax + 2 * v * u * p.cx + u * u * p.bx,
		v * v * p.az + 2 * v * u * p.cz + u * u * p.bz
end

-- a curve's length, and how far along it each parameter step is (so it's driven at an even speed)
local function curveLength(p: Piece): number
	local len, px, pz = 0, p.ax, p.az
	local cum = { 0 }
	for k = 1, CURVE_STEPS do
		local x, z = bezier(p, k / CURVE_STEPS)
		len += math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		cum[k + 1] = len
		px, pz = x, z
	end
	p.cum = cum
	return len
end

-- the drivable curve through crossing centres `points` ({ x, z } each, at least two): each road `lane` studs
-- right of its centre line, corners rounded with up to `radius` studs of road before and after the corner
function Route.build(points: { { number } }, lane: number, radius: number): Path
	local n = #points
	local pieces: { Piece } = {}
	if n < 2 then
		return { pieces = pieces, length = 0 }
	end
	-- each road's direction and length
	local dirs: { { number } } = {}
	for k = 1, n - 1 do
		local dx, dz = points[k + 1][1] - points[k][1], points[k + 1][2] - points[k][2]
		local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
		dirs[k] = { dx / len, dz / len, len }
	end
	-- the lane lines' corner points: where the lane of the road in meets the lane of the road out
	local corner: { { number } } = {}
	for k = 1, n do
		local din, dout = dirs[k - 1] or dirs[k], dirs[k] or dirs[k - 1]
		local rix, riz = -din[2], din[1] -- the right of travel (Roads.lanePoint)
		local rox, roz = -dout[2], dout[1]
		local d = 1 + rix * rox + riz * roz
		if d < 0.1 then -- a U-turn: no meeting point, so just the lane out
			corner[k] = { points[k][1] + rox * lane, points[k][2] + roz * lane }
		else
			corner[k] =
				{ points[k][1] + lane * (rix + rox) / d, points[k][2] + lane * (riz + roz) / d }
		end
	end
	local s = 0
	local function add(p: Piece)
		p.s0 = s
		p.len = if p.curve then curveLength(p) else math.sqrt((p.bx - p.ax) ^ 2 + (p.bz - p.az) ^ 2)
		if p.len > 1e-6 then
			s += p.len
			table.insert(pieces, p)
		end
	end
	local cx, cz = corner[1][1], corner[1][2]
	for k = 2, n - 1 do
		local din, dout = dirs[k - 1], dirs[k]
		local straight = din[1] * dout[1] + din[2] * dout[2] > 0.999
		if straight then
			continue
		end
		local r = math.min(radius, din[3] * 0.45, dout[3] * 0.45)
		local px, pz = corner[k][1], corner[k][2]
		local ex, ez = px - din[1] * r, pz - din[2] * r
		local xx, xz = px + dout[1] * r, pz + dout[2] * r
		add({ s0 = 0, len = 0, curve = false, ax = cx, az = cz, bx = ex, bz = ez, cx = 0, cz = 0 })
		add({ s0 = 0, len = 0, curve = true, ax = ex, az = ez, bx = xx, bz = xz, cx = px, cz = pz })
		cx, cz = xx, xz
	end
	add({
		s0 = 0,
		len = 0,
		curve = false,
		ax = cx,
		az = cz,
		bx = corner[n][1],
		bz = corner[n][2],
		cx = 0,
		cz = 0,
	})
	return { pieces = pieces, length = s }
end

-- where along the path `s` studs from its start is, and the unit way it faces there (clamped to the ends)
function Route.at(path: Path, s: number): (number, number, number, number)
	local pieces = path.pieces
	if #pieces == 0 then
		return 0, 0, 0, -1
	end
	s = math.clamp(s, 0, path.length)
	local p = pieces[#pieces]
	-- binary search for the piece holding s
	local lo, hi = 1, #pieces
	while lo <= hi do
		local mid = (lo + hi) // 2
		local q = pieces[mid]
		if s < q.s0 then
			hi = mid - 1
		elseif s > q.s0 + q.len then
			lo = mid + 1
		else
			p = q
			break
		end
	end
	local u = math.clamp((s - p.s0) / p.len, 0, 1)
	if not p.curve then
		local hx, hz = (p.bx - p.ax) / p.len, (p.bz - p.az) / p.len
		return p.ax + (p.bx - p.ax) * u, p.az + (p.bz - p.az) * u, hx, hz
	end
	-- studs along the curve to its parameter
	local cum = p.cum
	if cum then
		local d = s - p.s0
		for k = 1, CURVE_STEPS do
			if d <= cum[k + 1] or k == CURVE_STEPS then
				local span = math.max(cum[k + 1] - cum[k], 1e-6)
				u = math.clamp((k - 1 + (d - cum[k]) / span) / CURVE_STEPS, 0, 1)
				break
			end
		end
	end
	local x, z = bezier(p, u)
	-- the curve's direction: its derivative
	local v = 1 - u
	local hx = 2 * v * (p.cx - p.ax) + 2 * u * (p.bx - p.cx)
	local hz = 2 * v * (p.cz - p.az) + 2 * u * (p.bz - p.cz)
	local m = math.max(math.sqrt(hx * hx + hz * hz), 1e-6)
	return x, z, hx / m, hz / m
end

-- the crossing after `from` (coming from `prev`, nil at the start): never straight back unless it's a dead
-- end. With a target ({ x, z }) the one that gets closest to it; else straight on `straightWeight` times
-- likelier than each turn, `pick` (0-1) choosing.
function Route.nextNode(
	g: Roads.Graph,
	from: number,
	prev: number?,
	pick: number,
	straightWeight: number,
	target: { number }?
): number
	local here = g.nodes[from]
	local options: { { id: number, w: number, d: number } } = {}
	local total = 0
	local back: number? = nil
	for _, linkId in here.out do
		local l = g.links[linkId]
		if l.b == prev then
			back = l.b
			continue
		end
		local straight = false
		if prev then
			local p = g.nodes[prev]
			local ix, iz = here.x - p.x, here.z - p.z
			local m = math.max(math.sqrt(ix * ix + iz * iz), 1e-6)
			straight = math.abs(ix / m - l.dx) < 1e-6 and math.abs(iz / m - l.dz) < 1e-6
		end
		local to = g.nodes[l.b]
		local d = if target then (to.x - target[1]) ^ 2 + (to.z - target[2]) ^ 2 else 0
		local w = if straight then straightWeight else 1
		table.insert(options, { id = l.b, w = w, d = d })
		total += w
	end
	if #options == 0 then
		return back or from
	end
	if target then
		local best = options[1]
		for _, o in options do
			if o.d < best.d then
				best = o
			end
		end
		return best.id
	end
	local at = pick * total
	for _, o in options do
		at -= o.w
		if at <= 0 then
			return o.id
		end
	end
	return options[#options].id
end

-- crossing centres to a workspace attribute and back: "x,z;x,z;..." to a tenth of a stud
function Route.encode(points: { { number } }): string
	local parts = table.create(#points)
	for i, p in points do
		parts[i] = string.format("%.1f,%.1f", p[1], p[2])
	end
	return table.concat(parts, ";")
end

function Route.decode(text: string): { { number } }
	local out = {}
	for x, z in string.gmatch(text, "(%-?[%d%.]+),(%-?[%d%.]+)") do
		local nx, nz = tonumber(x), tonumber(z)
		if nx and nz then
			table.insert(out, { nx, nz })
		end
	end
	return out
end

return Route
