--!strict
-- Life on the sea off the west coast (server SeaKit builds it, client SeaLife moves it): boats drifting round
-- long loops, the lighthouse's turning beam after dark, and a foam line along the beaches. Studs, seconds,
-- degrees; colours are { r, g, b }.

export type RGB = { number }
export type Boat = {
	kind: string, -- "motor" (a cabin) or "sail" (a mast and a sail)
	hull: RGB,
	z: number, -- the loop's middle along the coast...
	off: number, -- ...this far out to sea from it
	across: number, -- the loop's radius out to sea...
	along: number, -- ...and along the coast
	lap: number, -- seconds round the loop (negative: the other way round)
	phase: number, -- 0..1, where on the loop it is when the server clock reads 0
}

return table.freeze({
	-- inside the walls (Config/Land SeaReach) and clear of the moored ship at the port (|z| < 500, off < 80)
	Boats = table.freeze({
		table.freeze({
			kind = "motor",
			hull = { 200, 60, 50 },
			z = -1250,
			off = 380,
			across = 120,
			along = 300,
			lap = 260,
			phase = 0.1,
		}),
		table.freeze({
			kind = "sail",
			hull = { 40, 70, 120 },
			z = 800,
			off = 380,
			across = 120,
			along = 250,
			lap = -330,
			phase = 0.5,
		}),
		table.freeze({
			kind = "sail",
			hull = { 250, 250, 250 },
			z = 1250,
			off = 520,
			across = 100,
			along = 300,
			lap = 300,
			phase = 0.8,
		}),
		table.freeze({
			kind = "motor",
			hull = { 230, 170, 40 },
			z = -800,
			off = 520,
			across = 100,
			along = 250,
			lap = -280,
			phase = 0.3,
		}),
		table.freeze({
			kind = "motor",
			hull = { 36, 62, 112 },
			z = 0,
			off = 450,
			across = 100,
			along = 300,
			lap = 240,
			phase = 0.6,
		}),
	}) :: { Boat },
	-- a boat: hull wide, tall, long; the bow's length; a motor boat's cabin and its roof's colour; a sailboat's
	-- sail (wide, tall) and mast; the white wake behind it (wide, long, see-through)
	Hull = { 10, 4, 30 },
	Bow = 8,
	Cabin = { 8, 6, 10 },
	CabinRoof = { 40, 70, 120 } :: RGB,
	Sail = { 14, 24 },
	Mast = 28,
	White = { 248, 246, 240 } :: RGB,
	Wake = { 14, 60 },
	WakeClear = 0.45,
	WaterY = -1, -- the sea's surface (Config/Land: terrain water tops out here)
	-- the gentle rocking: roll and pitch (degrees), heave (studs), one sway every `period` seconds
	Bob = table.freeze({ roll = 2.5, pitch = 1.5, heave = 0.4, period = 4 }),
	-- the lighthouse beam: two long see-through blades from the lamp, a turn every `turn` seconds, shown from
	-- `on` to `off` on the clock (fading over `fade` hours), `clear` see-through at its brightest
	Beam = table.freeze({
		length = 700,
		width = 4,
		height = 6,
		clear = 0.8,
		colour = { 255, 240, 190 } :: RGB,
		turn = 12,
		on = 18.4,
		off = 5.8,
		fade = 0.6,
	}),
	-- the foam line along the beaches: from `from` studs either side of the port's middle out to where the coast
	-- meets the edge, in pieces `step` long, `out` studs out to sea from the coast, `width` wide, `y` high
	Foam = table.freeze({
		from = 560,
		step = 200,
		out = 6,
		width = 5,
		y = -0.92,
		clear = 0.35,
	}),
})
