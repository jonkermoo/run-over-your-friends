--!strict
-- Layout rules for the town buildings: trim bands cut into pieces, where pilasters and cornices go, and the
-- shop-front segments. Pure, so Lune tests it.

local Buildings = {}

export type Span = { from: number, to: number }
export type Seg = { a: number, b: number, k: string }

-- `length` cut into equal pieces no longer than `maxPiece`, from -length/2 to length/2
function Buildings.pieces(length: number, maxPiece: number): { Span }
	local n = math.max(1, math.ceil(length / maxPiece - 1e-9))
	local out = {}
	for k = 0, n - 1 do
		table.insert(
			out,
			{ from = -length / 2 + k * length / n, to = -length / 2 + (k + 1) * length / n }
		)
	end
	return out
end

-- panel boundaries (1..n-1) that get a pilaster: every `every` panels, never on a corner
function Buildings.pilasters(n: number, every: number): { number }
	local out = {}
	local k = every
	while k < n do
		table.insert(out, k)
		k += every
	end
	return out
end

-- storeys split into sections by cornice bands: the lobby, then `every` floors at a time.
-- Each section is { from = first floor, to = floor above the last }; a cornice runs along each `from` > 1.
function Buildings.sections(floors: number, every: number): { Span }
	local out = { { from = 0, to = 1 } }
	local f = 1
	while f < floors do
		table.insert(out, { from = f, to = math.min(f + every, floors) })
		f += every
	end
	return out
end

-- a shop's ground-floor front from -width/2 to width/2: a big window, then the door near one end.
-- Kinds: "s" wall, "sw" shop window, "d" doorway. Also returns the middle of the door.
function Buildings.shopFront(width: number, door: number): ({ Seg }, number)
	local half = width / 2
	local doorB = half - 4
	local doorA = doorB - door
	local winB = doorA - 2
	return {
		{ a = -half, b = -half + 2, k = "s" },
		{ a = -half + 2, b = winB, k = "sw" },
		{ a = winB, b = doorA, k = "s" },
		{ a = doorA, b = doorB, k = "d" },
		{ a = doorB, b = half, k = "s" },
	},
		(doorA + doorB) / 2
end

return Buildings
