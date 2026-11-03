--!strict
-- The road network traffic drives on: a node at the middle of every crossing of the city grid, two one-way
-- links (one each way) along every road between neighbouring crossings, keep-right lanes, curved turns
-- through crossings, the traffic-light phase every screen and the server agree on (it runs off server time),
-- and the spacing and overlap maths the traffic uses. Pure (x/z numbers), so Lune tests it.

local Roads = {}

export type Grid = {
	blocksX: number,
	blocksZ: number,
	block: number, -- block size, kerb to kerb
	road: number,
	sidewalk: number,
	x0: number, -- west edge of the city grid (outer road edge)
	z0: number,
}
export type Node = { i: number, j: number, x: number, z: number, lit: boolean, out: { number } }
export type Link = {
	id: number,
	a: number, -- from node
	b: number, -- to node
	ax: number,
	az: number,
	bx: number,
	bz: number,
	dx: number, -- unit direction of travel
	dz: number,
	length: number, -- node centre to node centre
	width: number, -- road width
}
export type Graph = {
	grid: Grid,
	nodes: { Node },
	links: { Link },
	between: { [number]: { [number]: number } }, -- between[a][b] = link id
}
export type Light = "green" | "amber" | "red"
export type SignalConfig = { SignalSeconds: number, AmberSeconds: number }
export type Turn = {
	p0x: number,
	p0z: number,
	p1x: number,
	p1z: number,
	p2x: number,
	p2z: number,
	length: number,
}

local function nodeId(grid: Grid, i: number, j: number): number
	return j * (grid.blocksX + 1) + i + 1
end
Roads.nodeId = nodeId

-- the middle of the crossing at road line i (west to east) and j (north to south)
function Roads.crossing(grid: Grid, i: number, j: number): (number, number)
	local pitch = grid.block + grid.road
	return grid.x0 + grid.road / 2 + i * pitch, grid.z0 + grid.road / 2 + j * pitch
end

-- isLit(i, j): whether the crossing has traffic lights (StreetKit puts them only in some districts)
function Roads.graph(grid: Grid, isLit: (number, number) -> boolean): Graph
	local g: Graph = { grid = grid, nodes = {}, links = {}, between = {} }
	for j = 0, grid.blocksZ do
		for i = 0, grid.blocksX do
			local x, z = Roads.crossing(grid, i, j)
			g.nodes[nodeId(grid, i, j)] =
				{ i = i, j = j, x = x, z = z, lit = isLit(i, j), out = {} }
		end
	end
	local function link(a: number, b: number)
		local na, nb = g.nodes[a], g.nodes[b]
		local dx, dz = nb.x - na.x, nb.z - na.z
		local len = math.sqrt(dx * dx + dz * dz)
		local l: Link = {
			id = #g.links + 1,
			a = a,
			b = b,
			ax = na.x,
			az = na.z,
			bx = nb.x,
			bz = nb.z,
			dx = dx / len,
			dz = dz / len,
			length = len,
			width = grid.road,
		}
		table.insert(g.links, l)
		table.insert(na.out, l.id)
		g.between[a] = g.between[a] or {}
		g.between[a][b] = l.id
	end
	for j = 0, grid.blocksZ do
		for i = 0, grid.blocksX do
			local here = nodeId(grid, i, j)
			if i < grid.blocksX then
				link(here, nodeId(grid, i + 1, j))
				link(nodeId(grid, i + 1, j), here)
			end
			if j < grid.blocksZ then
				link(here, nodeId(grid, i, j + 1))
				link(nodeId(grid, i, j + 1), here)
			end
		end
	end
	return g
end

-- a point `dist` studs along a link, `offset` studs to the right of the road's centre line (keep right)
function Roads.lanePoint(g: Graph, linkId: number, dist: number, offset: number): (number, number)
	local l = g.links[linkId]
	-- the right of travel direction (dx, dz) with y up is (-dz, dx)
	return l.ax + l.dx * dist - l.dz * offset, l.az + l.dz * dist + l.dx * offset
end

-- where a car arriving on `fromLink` goes next: straight on most of the time, else a turn; never back the
-- way it came unless that's the only road (`pick` 0-1 chooses; weights are straight vs each turn)
function Roads.nextLink(g: Graph, fromLink: number, pick: number, straightWeight: number): number
	local from = g.links[fromLink]
	local options: { { id: number, w: number } } = {}
	local total = 0
	for _, id in g.nodes[from.b].out do
		local l = g.links[id]
		if l.b ~= from.a then
			local straight = math.abs(l.dx - from.dx) < 1e-6 and math.abs(l.dz - from.dz) < 1e-6
			local w = if straight then straightWeight else 1
			table.insert(options, { id = id, w = w })
			total += w
		end
	end
	if #options == 0 then
		return g.between[from.b][from.a]
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

-- the curve through a crossing from one link to the next: from the in-lane where it meets the crossing's
-- edge to the out-lane on the far edge, bent round the point where the two lane lines meet
function Roads.turn(g: Graph, inLink: number, outLink: number, offset: number): Turn
	local a, b = g.links[inLink], g.links[outLink]
	local edge = g.grid.road / 2
	local p0x, p0z = Roads.lanePoint(g, inLink, a.length - edge, offset)
	local p2x, p2z = Roads.lanePoint(g, outLink, edge, offset)
	-- the lane lines' meeting point (straight on: halfway)
	local cross = a.dx * b.dz - a.dz * b.dx
	local p1x, p1z
	if math.abs(cross) < 1e-6 then
		p1x, p1z = (p0x + p2x) / 2, (p0z + p2z) / 2
	else
		local t = ((p2x - p0x) * b.dz - (p2z - p0z) * b.dx) / cross
		p1x, p1z = p0x + a.dx * t, p0z + a.dz * t
	end
	-- a quadratic curve's length, close enough from its control polygon and chord
	local chord = math.sqrt((p2x - p0x) ^ 2 + (p2z - p0z) ^ 2)
	local poly = math.sqrt((p1x - p0x) ^ 2 + (p1z - p0z) ^ 2)
		+ math.sqrt((p2x - p1x) ^ 2 + (p2z - p1z) ^ 2)
	return {
		p0x = p0x,
		p0z = p0z,
		p1x = p1x,
		p1z = p1z,
		p2x = p2x,
		p2z = p2z,
		length = (2 * chord + poly) / 3,
	}
end

-- position and unit heading on a turn, u from 0 to 1
function Roads.onTurn(t: Turn, u: number): (number, number, number, number)
	local v = 1 - u
	local x = v * v * t.p0x + 2 * v * u * t.p1x + u * u * t.p2x
	local z = v * v * t.p0z + 2 * v * u * t.p1z + u * u * t.p2z
	local hx = 2 * v * (t.p1x - t.p0x) + 2 * u * (t.p2x - t.p1x)
	local hz = 2 * v * (t.p1z - t.p0z) + 2 * u * (t.p2z - t.p1z)
	local len = math.sqrt(hx * hx + hz * hz)
	if len < 1e-6 then
		hx, hz, len =
			t.p2x - t.p0x, t.p2z - t.p0z, math.sqrt((t.p2x - t.p0x) ^ 2 + (t.p2z - t.p0z) ^ 2)
	end
	return x, z, hx / len, hz / len
end

-- the lights at every lit crossing, from server time: north-south green, amber, then east-west green, amber
function Roads.lights(t: number, cfg: SignalConfig): (Light, Light)
	local half = cfg.SignalSeconds + cfg.AmberSeconds
	local p = t % (2 * half)
	if p < cfg.SignalSeconds then
		return "green", "red"
	elseif p < half then
		return "amber", "red"
	elseif p < half + cfg.SignalSeconds then
		return "red", "green"
	end
	return "red", "amber"
end

-- the light a car on this link sees as it arrives at the link's far crossing ("green" where there are none)
function Roads.lightFor(g: Graph, linkId: number, t: number, cfg: SignalConfig): Light
	local l = g.links[linkId]
	if not g.nodes[l.b].lit then
		return "green"
	end
	local ns, ew = Roads.lights(t, cfg)
	return if math.abs(l.dz) > math.abs(l.dx) then ns else ew
end

-- the fastest a car may go and still stop within `gap` studs braking at `brake` studs/s^2
function Roads.stopSpeed(gap: number, brake: number): number
	return math.sqrt(2 * brake * math.max(0, gap))
end

-- how far ahead (studs, along heading hx, hz) the nearest thing in the way is, and which point it is: points
-- within `half` + their own radius of the car's line, at most `look` ahead; math.huge (and 0) when clear
function Roads.gapAhead(
	x: number,
	z: number,
	hx: number,
	hz: number,
	half: number,
	look: number,
	px: { number },
	pz: { number },
	pr: { number }
): (number, number)
	local best, who = math.huge, 0
	for k = 1, #px do
		local dx, dz = px[k] - x, pz[k] - z
		local along = dx * hx + dz * hz
		if along > 0 and along < look then
			local side = math.abs(dx * hz - dz * hx)
			if side < half + pr[k] then
				local gap = along - pr[k]
				if gap < best then
					best, who = gap, k
				end
			end
		end
	end
	return best, who
end

-- do two boxes on the ground overlap? Each is a centre, a unit forward and half its width and length.
function Roads.overlap(
	ax: number,
	az: number,
	afx: number,
	afz: number,
	aw: number,
	al: number,
	bx: number,
	bz: number,
	bfx: number,
	bfz: number,
	bw: number,
	bl: number
): boolean
	local dx, dz = bx - ax, bz - az
	-- separating axes: each box's forward and side
	local axes = { { afx, afz }, { -afz, afx }, { bfx, bfz }, { -bfz, bfx } }
	for _, ax2 in axes do
		local ux, uz = ax2[1], ax2[2]
		local ra = al * math.abs(afx * ux + afz * uz) + aw * math.abs(-afz * ux + afx * uz)
		local rb = bl * math.abs(bfx * ux + bfz * uz) + bw * math.abs(-bfz * ux + bfx * uz)
		if math.abs(dx * ux + dz * uz) > ra + rb then
			return false
		end
	end
	return true
end

-- snapshots: each car packed in 16 bytes (id, kind, paint, flags, x, z as f32, yaw as u16, speed as u16)
Roads.CarBytes = 16

function Roads.yawToU16(yaw: number): number
	return math.floor(((yaw % (2 * math.pi)) / (2 * math.pi)) * 65535 + 0.5)
end

function Roads.u16ToYaw(n: number): number
	return n / 65535 * 2 * math.pi
end

return Roads
