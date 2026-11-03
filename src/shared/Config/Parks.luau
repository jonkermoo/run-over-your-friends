--!strict
-- Trees, bushes and flower beds (every one a prop any vehicle knocks flying) and the city park's layout.
-- Studs; colours are { r, g, b }.

export type RGB = { number }

return table.freeze({
	Tree = table.freeze({
		Trunk = table.freeze({ 9, 14 }), -- height, shortest to tallest
		TrunkWidth = 1.6,
		Crown = table.freeze({ 9, 13 }), -- the main ball's size; two smaller lumps sit off its sides
		Lumps = 0.65, -- the side lumps' size as a share of the main ball
	}),
	Bush = table.freeze({ 4, 6.5 }),
	FlowerBed = table.freeze({ width = 10, depth = 4, flowers = 7 }),

	Greens = table.freeze({
		{ 70, 140, 70 },
		{ 84, 158, 72 },
		{ 58, 122, 66 },
		{ 104, 166, 74 },
	}) :: { RGB },
	Trunk = { 104, 74, 50 } :: RGB,
	Soil = { 92, 66, 46 } :: RGB,
	Edging = { 150, 112, 76 } :: RGB,
	Flowers = table.freeze({
		{ 236, 84, 96 },
		{ 250, 210, 70 },
		{ 240, 240, 240 },
		{ 186, 110, 220 },
		{ 255, 150, 60 },
	}) :: { RGB },

	-- the park: two paths crossing at a round pond, trees and bushes in the four lawns, flower beds,
	-- benches and lamps along the paths, and the kicker ramp on one lawn
	Park = table.freeze({
		Path = 12, -- wide
		PathColour = { 214, 200, 170 } :: RGB,
		Pond = 34, -- across, inside the stone rim
		Rim = 4,
		TreesPerLawn = 4,
		BushesPerLawn = 3,
		Benches = 2, -- per path arm, facing the path
		Lamps = 1, -- per path arm
	}),
	HomeTrees = 3, -- in the gardens behind each street of homes
})
