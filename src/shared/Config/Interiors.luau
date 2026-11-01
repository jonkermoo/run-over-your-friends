--!strict
-- House interiors: what stands on the ground floor of each house type and where residents sit or stand.
-- The server uses the spots (so people sit on the sofa the client draws); each client builds the furniture
-- and lamps only for houses near its camera. Positions are in the house's own frame (studs): x to the right,
-- z toward the street, floor level; (fx, fz) is the way a piece or a person faces. Mirrored houses flip x.

export type Piece = { kind: string, x: number, z: number, fx: number, fz: number }
export type Spot = { x: number, z: number, fx: number, fz: number, sit: boolean }
export type Layout = { pieces: { Piece }, spots: { Spot } }

local function piece(kind: string, x: number, z: number, fx: number?, fz: number?): Piece
	return { kind = kind, x = x, z = z, fx = fx or 0, fz = fz or 1 }
end

local function spot(x: number, z: number, fx: number, fz: number, sit: boolean?): Spot
	return { x = x, z = z, fx = fx, fz = fz, sit = sit == true }
end

-- living room on the left, kitchen and dining on the right; `s` stretches it to the house's width
local function detached(s: number): Layout
	return {
		pieces = {
			piece("Rug", -8.5 * s, 3),
			piece("Sofa", -4 * s, 3, -1, 0),
			piece("CoffeeTable", -8.5 * s, 3, 1, 0),
			piece("TV", -14 * s + 0.7, 3, 1, 0),
			piece("FloorLamp", -14 * s + 1.2, -2.5),
			piece("Bookshelf", -9 * s, -11.4),
			piece("Plant", 3.8, 10.4),
			piece("Counter", 7.5 * s, -10.9),
			piece("Fridge", 14 * s - 1.6, -10.6),
			piece("DiningTable", 8 * s, 3),
			piece("Chair", 8 * s, 5.4, 0, -1),
			piece("Chair", 8 * s, 0.6, 0, 1),
			piece("CeilingLamp", 8 * s, 3),
		},
		spots = {
			spot(-4 * s, 3, -1, 0, true),
			spot(8 * s, 5.4, 0, -1, true),
			spot(8 * s, 0.6, 0, 1, true),
			spot(7.5 * s, -8.4, 0, -1),
			spot(-8.5 * s, 8.6, 0, 1),
		},
	}
end

return table.freeze({
	Radius = 170, -- clients furnish houses this close to the camera...
	MaxFurnished = 24, -- ...at most this many at once, nearest first
	SitHeight = 2.35, -- a seated person's root above the floor
	SitAnim = 2506281703, -- Roblox's standard R15 sit
	LampRange = 13,
	LampBrightness = 1.4,

	Layouts = table.freeze({
		A = detached(1),
		B = detached(34 / 30),
		-- C: living room and kitchen in the two-storey block (x -19 to 3), the garage on the right
		C = {
			pieces = {
				piece("Rug", -13, 4),
				piece("Sofa", -9.5, 4, -1, 0),
				piece("CoffeeTable", -13, 4, 1, 0),
				piece("TV", -17.3, 4, 1, 0),
				piece("FloorLamp", -17, -2),
				piece("Counter", -12, -10.9),
				piece("Fridge", -16.4, -10.6),
				piece("DiningTable", -10, -4),
				piece("Chair", -10, -1.6, 0, -1),
				piece("Chair", -10, -6.4, 0, 1),
				piece("CeilingLamp", -10, -4),
				piece("Plant", -0.8, 10.4),
			},
			spots = {
				spot(-9.5, 4, -1, 0, true),
				spot(-10, -1.6, 0, -1, true),
				spot(-10, -6.4, 0, 1, true),
				spot(-12, -8.4, 0, -1),
				spot(-13, 9, 0, 1),
			},
		} :: Layout,
		-- D: a sofa looking out of the bay window, kitchen at the back
		D = {
			pieces = {
				piece("Rug", -3.5, 6),
				piece("Sofa", -3.5, 4.4, 0, 1),
				piece("CoffeeTable", -3.5, 7.6, 0, 1),
				piece("FloorLamp", -6.2, 9.4),
				piece("Bookshelf", -6.3, -1, 1, 0),
				piece("Counter", 0, -10.4),
				piece("Fridge", 5.4, -10.1),
				piece("DiningTable", -1.5, -4),
				piece("Chair", -1.5, -1.6, 0, -1),
				piece("Chair", -1.5, -6.4, 0, 1),
				piece("CeilingLamp", -1.5, -4),
				piece("Plant", 6, 4),
			},
			spots = {
				spot(-3.5, 4.4, 0, 1, true),
				spot(-1.5, -1.6, 0, -1, true),
				spot(-1.5, -6.4, 0, 1, true),
				spot(0, -8, 0, -1),
				spot(4.5, 6.5, 0, 1),
			},
		} :: Layout,
	}),
})
