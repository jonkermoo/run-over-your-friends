--!strict
-- Walls crumbling into bricks. A broken block is cut into a grid across its face (its two longest sides); the
-- cells near the hit are thrown out as bricks and the rest stands on as a few merged blocks, so a car makes a
-- ragged hole instead of carrying the whole wall off. Pure numbers (Config/Smash Crumble), so Lune tests it:
-- the server keeps the standing blocks, every client throws the bricks (src/client/Crumble).
-- Cells are numbered from 1, row by row: cell (i, j) (0-based, i along the face's long side) is j * na + i + 1.

local Crumble = {}

export type Config = {
	MinCell: number,
	MaxGrid: number,
	Ragged: number,
}

-- a cut of the face: na cells along its long side, nb along the short one
export type Grid = { na: number, nb: number }

-- a standing block: cells i0..i1 along, j0..j1 across (0-based, inclusive)
export type Rect = { i0: number, j0: number, i1: number, j1: number }

-- which of a box's sides (1 = X, 2 = Y, 3 = Z) is its thickness (the smallest), and which two make its face,
-- the longer one first
function Crumble.axes(sx: number, sy: number, sz: number): (number, number, number)
	local s = { sx, sy, sz }
	local k = 1
	for i = 2, 3 do
		if s[i] < s[k] then
			k = i
		end
	end
	local a, b = if k == 1 then 2 else 1, if k == 3 then 2 else 3
	if s[b] > s[a] then
		a, b = b, a
	end
	return k, a, b
end

-- how to cut a face A x B (A the longer) for a hole of radius r: square-ish cells no smaller than MinCell, sized
-- so the hole holds about maxFly of them and the whole face no more than MaxGrid. A long thin piece (a pole, a
-- band) is cut along its length only, into no more pieces than maxFly. Pass math.huge as r for the whole face.
function Crumble.grid(A: number, B: number, r: number, maxFly: number, config: Config): Grid
	maxFly = math.max(1, maxFly)
	local spanA, spanB = math.min(A, 2 * r), math.min(B, 2 * r)
	local c = math.max(
		config.MinCell,
		math.sqrt(spanA * spanB / maxFly),
		math.sqrt(A * B / config.MaxGrid)
	)
	local na = math.max(1, math.floor(A / c))
	local nb = math.max(1, math.floor(B / c))
	if nb == 1 then
		na = math.min(na, math.max(1, math.ceil(maxFly * A / math.max(spanA, 1e-6))))
	end
	while na * nb > config.MaxGrid do
		if na >= nb then
			na -= 1
		else
			nb -= 1
		end
	end
	return { na = na, nb = nb }
end

-- an exact 32-bit multiply (split in 16-bit halves so doubles never lose a bit)
local function mul32(a: number, b: number): number
	local ah, al = bit32.rshift(a, 16), bit32.band(a, 0xffff)
	return ((al * b) % 4294967296 + ((ah * b) % 65536) * 65536) % 4294967296
end

local function fmix(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85ebca6b)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xc2b2ae35)
	return bit32.bxor(h, bit32.rshift(h, 16))
end

-- a steady random number in [0, 1) for a cell of one break
function Crumble.noise(seed: number, cell: number): number
	local h = fmix(bit32.bxor(fmix(seed % 4294967296), cell % 4294967296))
	return h / 4294967296
end

-- the middle of cell (i, j) on the face, from the face's centre: (along, across)
function Crumble.cellCentre(
	grid: Grid,
	A: number,
	B: number,
	i: number,
	j: number
): (number, number)
	return (i + 0.5) * A / grid.na - A / 2, (j + 0.5) * B / grid.nb - B / 2
end

-- the cells thrown out by a hole of radius r around (u, v) on the face, nearest first: a ragged ring (Ragged
-- share of r in or out per cell), never more than maxFly, and always at least the cell nearest the hit
function Crumble.hole(
	grid: Grid,
	A: number,
	B: number,
	u: number,
	v: number,
	r: number,
	maxFly: number,
	seed: number,
	config: Config
): { number }
	type Cell = { cell: number, d: number }
	local inside: { Cell } = {}
	local nearest: Cell = { cell = 1, d = math.huge }
	for j = 0, grid.nb - 1 do
		for i = 0, grid.na - 1 do
			local cu, cv = Crumble.cellCentre(grid, A, B, i, j)
			local d = math.sqrt((cu - u) ^ 2 + (cv - v) ^ 2)
			local cell = j * grid.na + i + 1
			local reach = r * (1 + config.Ragged * (Crumble.noise(seed, cell) * 2 - 1))
			if d < reach then
				table.insert(inside, { cell = cell, d = d })
			end
			if d < nearest.d then
				nearest = { cell = cell, d = d }
			end
		end
	end
	if #inside == 0 then
		inside = { nearest }
	end
	table.sort(inside, function(x: Cell, y: Cell)
		return x.d < y.d
	end)
	local cells = {}
	for n = 1, math.min(#inside, math.max(1, maxFly)) do
		table.insert(cells, inside[n].cell)
	end
	return cells
end

-- every cell of the grid
function Crumble.all(grid: Grid): { number }
	local cells = table.create(grid.na * grid.nb)
	for n = 1, grid.na * grid.nb do
		cells[n] = n
	end
	return cells
end

-- what stands after the thrown cells go, as few blocks as a greedy merge finds: runs along each row, grown
-- across while the next rows match
function Crumble.mesh(grid: Grid, thrown: { number }): { Rect }
	local na, nb = grid.na, grid.nb
	local gone: { [number]: boolean } = {}
	for _, cell in thrown do
		gone[cell] = true
	end
	local used: { [number]: boolean } = {}
	local function free(i: number, j: number): boolean
		local cell = j * na + i + 1
		return not gone[cell] and not used[cell]
	end
	local rects: { Rect } = {}
	for j = 0, nb - 1 do
		for i = 0, na - 1 do
			if free(i, j) then
				local i1 = i
				while i1 + 1 < na and free(i1 + 1, j) do
					i1 += 1
				end
				local j1 = j
				while j1 + 1 < nb do
					local whole = true
					for x = i, i1 do
						if not free(x, j1 + 1) then
							whole = false
							break
						end
					end
					if not whole then
						break
					end
					j1 += 1
				end
				for y = j, j1 do
					for x = i, i1 do
						used[y * na + x + 1] = true
					end
				end
				table.insert(rects, { i0 = i, j0 = j, i1 = i1, j1 = j1 })
			end
		end
	end
	return rects
end

-- a standing block's middle on the face (from the face's centre) and its size: along, across, width, height
function Crumble.rectBox(
	grid: Grid,
	A: number,
	B: number,
	rect: Rect
): (number, number, number, number)
	local ca, cb = A / grid.na, B / grid.nb
	local w, h = (rect.i1 - rect.i0 + 1) * ca, (rect.j1 - rect.j0 + 1) * cb
	return rect.i0 * ca + w / 2 - A / 2, rect.j0 * cb + h / 2 - B / 2, w, h
end

-- the radius of a hit's sphere where it cuts the face's plane, `out` studs off the block's thickness
function Crumble.reach(radius: number, out: number): number
	return math.sqrt(math.max(radius * radius - out * out, 0))
end

-- how many bricks each of `parts` broken parts may throw when one break may throw `budget` in all
function Crumble.share(budget: number, parts: number, maxEach: number): number
	return math.clamp(math.floor(budget / math.max(parts, 1)), 1, maxEach)
end

return Crumble
