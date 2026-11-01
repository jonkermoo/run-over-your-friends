--!strict
-- The sidewalk network people walk on: a node at every block corner (on the middle of the sidewalk), extra
-- nodes in front of doors, sidewalk links along each block side and crosswalks over the roads to the next
-- block. Paths only follow links, so nobody cuts through a building. Pure (x/z numbers), so Lune tests it.

local Routes = {}

export type Node = { x: number, z: number }
export type Grid = {
	blocksX: number,
	blocksZ: number,
	block: number, -- block size, kerb to kerb
	road: number,
	sidewalk: number,
	x0: number, -- west edge of the city grid (outer road edge)
	z0: number,
}
export type Graph = {
	grid: Grid,
	nodes: { Node },
	links: { { number } },
	corners: { [string]: number },
	sides: { [string]: { number } }, -- nodes along each block side, before linking
}

local SIDES = { N = { 0, -1 }, S = { 0, 1 }, W = { -1, 0 }, E = { 1, 0 } }

-- centre of block (i, j)
function Routes.blockCentre(grid: Grid, i: number, j: number): (number, number)
	local pitch = grid.block + grid.road
	return grid.x0 + grid.road + i * pitch + grid.block / 2,
		grid.z0 + grid.road + j * pitch + grid.block / 2
end

local function addNode(g: Graph, x: number, z: number): number
	table.insert(g.nodes, { x = x, z = z })
	table.insert(g.links, {})
	return #g.nodes
end

function Routes.link(g: Graph, a: number, b: number)
	if a == b then
		return
	end
	for _, n in g.links[a] do
		if n == b then
			return
		end
	end
	table.insert(g.links[a], b)
	table.insert(g.links[b], a)
end

-- corner node of block (i, j); sx, sz are -1 or 1 (west/east, north/south)
function Routes.corner(g: Graph, i: number, j: number, sx: number, sz: number): number
	return g.corners[`{i},{j},{sx},{sz}`]
end

function Routes.new(grid: Grid): Graph
	local g: Graph = { grid = grid, nodes = {}, links = {}, corners = {}, sides = {} }
	local inset = grid.block / 2 - grid.sidewalk / 2
	for i = 0, grid.blocksX - 1 do
		for j = 0, grid.blocksZ - 1 do
			local cx, cz = Routes.blockCentre(grid, i, j)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					g.corners[`{i},{j},{sx},{sz}`] = addNode(g, cx + sx * inset, cz + sz * inset)
				end
			end
			for side in SIDES do
				g.sides[`{i},{j},{side}`] = {}
			end
		end
	end
	return g
end

-- which block side a point is nearest to, and the point moved onto that side's sidewalk line
function Routes.onSide(
	grid: Grid,
	i: number,
	j: number,
	x: number,
	z: number
): (string, number, number)
	local cx, cz = Routes.blockCentre(grid, i, j)
	local inset = grid.block / 2 - grid.sidewalk / 2
	local dx, dz = x - cx, z - cz
	local side
	if math.abs(dx) > math.abs(dz) then
		side = if dx > 0 then "E" else "W"
	else
		side = if dz > 0 then "S" else "N"
	end
	local s = SIDES[side]
	local clampedX = math.clamp(dx, -inset, inset)
	local clampedZ = math.clamp(dz, -inset, inset)
	if s[1] ~= 0 then
		return side, cx + s[1] * inset, cz + clampedZ
	end
	return side, cx + clampedX, cz + s[2] * inset
end

-- a node on the sidewalk of block (i, j) nearest to (x, z), e.g. in front of a door; returns its id
function Routes.addOnSide(g: Graph, i: number, j: number, x: number, z: number): number
	local side, px, pz = Routes.onSide(g.grid, i, j, x, z)
	local id = addNode(g, px, pz)
	table.insert(g.sides[`{i},{j},{side}`], id)
	return id
end

-- join everything up: each side's nodes in order between its two corners, then crosswalks
function Routes.finish(g: Graph)
	local grid = g.grid
	for i = 0, grid.blocksX - 1 do
		for j = 0, grid.blocksZ - 1 do
			for side, s in SIDES do
				local a, b
				if s[1] ~= 0 then
					a, b = Routes.corner(g, i, j, s[1], -1), Routes.corner(g, i, j, s[1], 1)
				else
					a, b = Routes.corner(g, i, j, -1, s[2]), Routes.corner(g, i, j, 1, s[2])
				end
				local line = table.clone(g.sides[`{i},{j},{side}`])
				local alongX = s[1] == 0
				table.sort(line, function(p, q)
					if alongX then
						return g.nodes[p].x < g.nodes[q].x
					end
					return g.nodes[p].z < g.nodes[q].z
				end)
				local prev = a
				for _, id in line do
					Routes.link(g, prev, id)
					prev = id
				end
				Routes.link(g, prev, b)
			end
			if i + 1 < grid.blocksX then
				for _, sz in { -1, 1 } do
					Routes.link(
						g,
						Routes.corner(g, i, j, 1, sz),
						Routes.corner(g, i + 1, j, -1, sz)
					)
				end
			end
			if j + 1 < grid.blocksZ then
				for _, sx in { -1, 1 } do
					Routes.link(
						g,
						Routes.corner(g, i, j, sx, 1),
						Routes.corner(g, i, j + 1, sx, -1)
					)
				end
			end
		end
	end
end

function Routes.nearest(g: Graph, x: number, z: number): number
	local best, bestD = 1, math.huge
	for id, n in g.nodes do
		local d = (n.x - x) ^ 2 + (n.z - z) ^ 2
		if d < bestD then
			best, bestD = id, d
		end
	end
	return best
end

local function dist(a: Node, b: Node): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- shortest path (A*) as a list of node ids from `from` to `to`, both included; nil if unreachable
function Routes.path(g: Graph, from: number, to: number): { number }?
	if from == to then
		return { from }
	end
	local goal = g.nodes[to]
	local cost: { [number]: number } = { [from] = 0 }
	local came: { [number]: number } = {}
	local open: { number } = { from }
	local score: { [number]: number } = { [from] = dist(g.nodes[from], goal) }
	local closed: { [number]: boolean } = {}
	while #open > 0 do
		local bestK, bestS = 1, math.huge
		for k, id in open do
			if score[id] < bestS then
				bestK, bestS = k, score[id]
			end
		end
		local current = open[bestK]
		open[bestK] = open[#open]
		open[#open] = nil
		if current == to then
			local out = { to }
			while came[out[1]] do
				table.insert(out, 1, came[out[1]])
			end
			return out
		end
		closed[current] = true
		for _, n in g.links[current] do
			if not closed[n] then
				local c = cost[current] + dist(g.nodes[current], g.nodes[n])
				if cost[n] == nil or c < cost[n] then
					if cost[n] == nil then
						table.insert(open, n)
					end
					cost[n] = c
					came[n] = current
					score[n] = c + dist(g.nodes[n], goal)
				end
			end
		end
	end
	return nil
end

return Routes
