--!strict
-- Inside the town buildings: where the furniture stands and where people sit or stand, worked out from each
-- building's size so the server (people's spots) and every client (the furniture) agree. Positions are in the
-- building's frame, like Config/Interiors: x to the right, z toward the street, y up from the ground floor;
-- (fx, fz) is the way a piece or a person faces. A spot's `via` is the way in from the door (or from the
-- staff hub); two points in a row at the same x, z on different floors are a ride in the lift.
-- Pure, so Lune tests it.

local Interiors = {}

export type V = { x: number, y: number, z: number }
export type Piece = {
	kind: string,
	x: number,
	y: number,
	z: number,
	fx: number,
	fz: number,
	w: number?, -- width, for pieces that stretch (partition, counter, floor)
	d: number?, -- depth, for the floor
}
export type Spot = {
	x: number,
	y: number,
	z: number,
	fx: number,
	fz: number,
	sit: boolean,
	via: { V },
}
export type Layout = {
	pieces: { Piece },
	spots: { Spot }, -- visitors, residents, workers (from the entry)
	staff: { Spot }, -- staff (from the hub)
	hub: V?,
	staffIn: { V }, -- entry to hub
}

-- pieces people sit on: a sitting spot is always on one of these
Interiors.Seats = table.freeze({ Sofa = true, Chair = true })
-- ceiling lights hang this far under the floor above (clear of its slab)
local UNDER = 1.4

local function v(x: number, y: number, z: number): V
	return { x = x, y = y, z = z }
end

local function new(): Layout
	return { pieces = {}, spots = {}, staff = {}, hub = nil, staffIn = {} }
end

local function piece(
	l: Layout,
	kind: string,
	x: number,
	z: number,
	fx: number?,
	fz: number?,
	y: number?,
	w: number?,
	d: number?
)
	table.insert(
		l.pieces,
		{ kind = kind, x = x, y = y or 0, z = z, fx = fx or 0, fz = fz or 1, w = w, d = d }
	)
end

local function spot(
	list: { Spot },
	x: number,
	z: number,
	fx: number,
	fz: number,
	sit: boolean?,
	via: { V }?,
	y: number?
)
	table.insert(
		list,
		{ x = x, y = y or 0, z = z, fx = fx, fz = fz, sit = sit == true, via = via or {} }
	)
end

local function concat(a: { V }, b: { V }): { V }
	local out = table.clone(a)
	for _, p in b do
		table.insert(out, p)
	end
	return out
end

-- evenly spaced x positions across `width`, at most `every` apart, `margin` clear of each end
local function across(width: number, every: number, margin: number): { number }
	local span = width - 2 * margin
	local n = math.max(1, math.floor(span / every) + 1)
	local out = {}
	for k = 0, n - 1 do
		table.insert(out, if n == 1 then 0 else -span / 2 + k * span / (n - 1))
	end
	return out
end

export type OfficeConfig = { FloorHeight: number, Floors: number, DeskEvery: number }

-- an office tower `w` across its front, `d` deep: a lobby (reception, two waiting corners, a coffee corner,
-- the lift core) and desks along the front and back windows of the first few floors above
function Interiors.office(
	w: number,
	d: number,
	floors: number,
	doorX: number,
	cfg: OfficeConfig
): Layout
	local l = new()
	local hw, hd = w / 2, d / 2
	local zf = hd
	local FH = cfg.FloorHeight
	-- reception desk facing the door, the receptionist's chair behind it and a water cooler
	local deskZ = zf - 22
	piece(l, "Reception", doorX, deskZ, 0, 1)
	piece(l, "Chair", doorX, deskZ - 2.6, 0, 1)
	piece(l, "WaterCooler", doorX + 14, deskZ - 6, 0, 1)
	l.hub = v(doorX + 9, 0, deskZ - 4)
	l.staffIn = { v(doorX + 10, 0, deskZ + 4), l.hub :: V }
	spot(l.staff, doorX, deskZ - 2.6, 0, 1, true)
	spot(l.staff, doorX + 14, deskZ - 3.8, 0, -1)
	spot(l.spots, doorX - 2.5, deskZ + 3.2, 0, -1)
	-- waiting corners either side of the door: two sofas over a coffee table
	for _, e in { -1, 1 } do
		local cx, cz = doorX + e * 30, zf - 14
		piece(l, "Rug", cx, cz)
		piece(l, "Sofa", cx - 6, cz, 1, 0)
		piece(l, "Sofa", cx + 6, cz, -1, 0)
		piece(l, "CoffeeTable", cx, cz, 0, 1)
		piece(l, "Plant", cx + e * 11, cz + 6)
		spot(l.spots, cx - 6, cz, 1, 0, true, { v(cx, 0, cz + 6) })
		spot(l.spots, cx + 6, cz, -1, 0, true, { v(cx, 0, cz + 6) })
	end
	-- a coffee corner against the left wall
	local bx = -hw + 2.5
	piece(l, "CoffeeBar", bx, 0, 1, 0)
	spot(l.spots, bx + 4.5, 0, -1, 0, false, { v(doorX - 12, 0, deskZ + 2), v(-hw + 26, 0, 0) })
	for _, tz in { -14, 12 } do
		local tx = -hw + 18
		piece(l, "CafeTable", tx, tz)
		for _, e in { -1, 1 } do
			piece(l, "Chair", tx + e * 3, tz, -e, 0)
			spot(l.spots, tx + e * 3, tz, -e, 0, true, { v(tx, 0, tz + 4.5) })
		end
	end
	-- the lift core in the middle, plants either side; lights over the lobby
	local liftZ = -6
	piece(l, "LiftCore", doorX, liftZ, 0, 1)
	for _, e in { -1, 1 } do
		piece(l, "Plant", doorX + e * 15, liftZ + 3.5)
		piece(l, "PanelLight", doorX + e * 22, zf - 14, 0, 1, FH - UNDER)
	end
	piece(l, "PanelLight", doorX, liftZ + 12, 0, 1, FH - UNDER)
	local liftG = v(doorX - 4, 0, liftZ + 7)
	local toLift = { v(doorX - 12, 0, deskZ + 2), liftG }
	-- upper floors: desks along the front and back windows, people facing out past their screens
	for f = 1, math.min(floors - 1, cfg.Floors) do
		local y = f * FH
		local liftF = v(liftG.x, y, liftG.z)
		piece(l, "LiftCore", doorX, liftZ, 0, 1, y)
		for _, e in { -1, 1 } do
			piece(l, "Plant", e * (hw - 4), 0, 0, 1, y)
		end
		-- a meeting table beside the lift, two chairs a side
		local mx, mz = doorX + 28, liftZ + 4
		piece(l, "Rug", mx, mz, 0, 1, y)
		piece(l, "DiningTable", mx, mz, 0, 1, y)
		piece(l, "PanelGlow", mx, mz, 0, 1, y + FH - UNDER)
		for _, side in { -1, 1 } do
			for _, e in { -1, 1 } do
				local cx, cz = mx + e * 1.3, mz + side * 2.4
				piece(l, "Chair", cx, cz, 0, -side, y)
				local way = if side == 1
					then { liftF, v(cx, y, mz + 5.5) }
					else {
						liftF,
						v(mx + 5, y, mz + 5.5),
						v(mx + 5, y, mz - 5.5),
						v(cx, y, mz - 5.5),
					}
				spot(l.spots, cx, cz, 0, -side, true, concat(toLift, way), y)
			end
		end
		for _, x in across(w, cfg.DeskEvery, 9) do
			piece(l, "PanelGlow", x, zf - 8, 0, 1, y + FH - UNDER)
			piece(l, "PanelGlow", x, -hd + 8, 0, 1, y + FH - UNDER)
			-- front window
			piece(l, "Desk", x, zf - 4, 0, 1, y)
			piece(l, "Chair", x, zf - 6.6, 0, 1, y)
			spot(l.spots, x, zf - 6.6, 0, 1, true, concat(toLift, { liftF, v(x, y, zf - 11) }), y)
			-- back window, round the side of the lift core
			piece(l, "Desk", x, -hd + 4, 0, -1, y)
			piece(l, "Chair", x, -hd + 6.6, 0, -1, y)
			spot(
				l.spots,
				x,
				-hd + 6.6,
				0,
				-1,
				true,
				concat(toLift, {
					liftF,
					v(doorX - 16, y, liftG.z),
					v(doorX - 16, y, -hd + 11),
					v(x, y, -hd + 11),
				}),
				y
			)
		end
	end
	return l
end

-- a shop `w` wide and `d` deep with a `h` high shop floor: shelves on the side wall and on a stock-room
-- partition, two islands and a window display of the shop's own kind (`island`), and the till counter
-- by the door with the shopkeeper behind it
function Interiors.shop(w: number, d: number, h: number, doorX: number, island: string): Layout
	local l = new()
	local half, zf = w / 2, d / 2
	local zp = -zf + 18 -- the stock-room partition
	piece(l, "Partition", 0, zp, 0, 1, 0, w - 2)
	piece(l, "Floor", 0, (zf + zp) / 2, 0, 1, 0, w - 2, zf - zp - 1)
	for _, x in { -half + 7, -half + 17, -half + 27 } do
		piece(l, "Shelf", x, zp + 1.2, 0, 1)
	end
	for _, z in { zf - 10, zf - 20, zf - 30 } do
		piece(l, "Shelf", -half + 1.9, z, 1, 0)
	end
	local ix = -half + 12
	piece(l, island, ix, zf - 14)
	piece(l, island, ix, zf - 27)
	piece(l, island, -half + 18, zf - 4, 0, 1)
	-- the counter by the door, the till at the door end
	local cx = doorX - 6
	piece(l, "ShopCounter", cx, -2, 0, 1, 0, 14)
	for _, at in { { ix, zf - 20 }, { ix, zf - 6 }, { cx, 6 } } do
		piece(l, "PanelLight", at[1], at[2], 0, 1, h - UNDER)
	end
	piece(l, "Plant", half - 2.5, zf - 3.5)
	l.hub = v(doorX - 2, 0, -6)
	l.staffIn = { v(doorX - 16, 0, 0), v(doorX - 16, 0, -6), l.hub :: V }
	spot(l.staff, doorX - 8, -4.8, 0, 1)
	spot(l.staff, -half + 27, zp + 3.5, 0, -1)
	-- customers at the islands, the shelves and the counter
	spot(l.spots, ix, zf - 17.5, 0, 1)
	spot(l.spots, ix, zf - 23.5, 0, -1)
	spot(l.spots, -half + 5.3, zf - 10, -1, 0)
	spot(l.spots, -half + 7, zp + 3.5, 0, -1)
	spot(l.spots, doorX - 8, 1.4, 0, -1)
	return l
end

export type RestaurantConfig = { Tables: { number }, TableZ: number }

-- the burger place W × D: chairs at the four tables (the tables and counter themselves are the server's),
-- tills on the counter, fryers and a drinks machine in the kitchen, lamps over the tables
function Interiors.restaurant(W: number, D: number, cfg: RestaurantConfig): Layout
	local l = new()
	local tz = D * cfg.TableZ
	for _, a in cfg.Tables do
		local tx = a * W
		piece(l, "CeilingLamp", tx, tz, 0, 1, 4)
		for _, e in { -1, 1 } do
			piece(l, "Chair", tx + e * 4.6, tz, -e, 0)
			spot(l.spots, tx + e * 4.6, tz, -e, 0, true, { v(tx + e * 4.6, 0, tz + 6.5) })
		end
	end
	local counterZ = -D * 0.1
	for _, x in { -8, 8 } do
		piece(l, "Register", x, counterZ, 0, 1, 4)
	end
	for _, x in { -8, 0, 8 } do
		spot(l.spots, x, counterZ + 5, 0, -1)
	end
	for _, x in { -14, 14 } do
		piece(l, "PanelLight", x, counterZ + 4, 0, 1, 14.5)
	end
	local kz = -D / 2 + 4.5
	piece(l, "Fryer", -28, kz, 0, 1)
	piece(l, "DrinkMachine", 28, kz, 0, 1)
	for _, e in { -1, 1 } do
		piece(l, "Plant", e * 9, D / 2 - 3.5)
	end
	piece(l, "Bin", 14, D / 2 - 3)
	return l
end

-- the parcel warehouse W × D × H: high lights, forklifts, packing tables by the bays and a desk by the office
-- door, with staff spots reached along the walkway (`walkway`, z) from the office door (`doorA`, x)
function Interiors.warehouse(
	W: number,
	D: number,
	H: number,
	doorA: number,
	walkway: number
): Layout
	local l = new()
	for _, x in { -W / 3, 0, W / 3 } do
		for _, z in { -D / 4, D / 4 } do
			piece(l, "HighBayLight", x, z, 0, 1, H - 2)
		end
	end
	-- forklifts parked at the ends of two racks, clear of the aisles
	for _, x in { -36, 36 } do
		piece(l, "Forklift", x, walkway - 7, 0, -1)
	end
	local w1 = v(doorA + 6, 0, walkway)
	for _, x in { W / 2 - 22, W / 2 - 10 } do
		local z = D / 2 - 22
		piece(l, "PackingTable", x, z, 0, -1)
		spot(l.staff, x, z - 3, 0, 1, false, { w1, v(x, 0, walkway), v(x, 0, z - 3) })
	end
	local dx, dz = -W / 2 + 8, D / 2 - 16
	piece(l, "Desk", dx, dz, -1, 0)
	piece(l, "Chair", dx + 2.6, dz, -1, 0)
	spot(l.staff, dx + 2.6, dz, -1, 0, true)
	return l
end

export type Config = {
	FloorHeight: number,
	Floors: number,
	DeskEvery: number,
	Tables: { number },
	TableZ: number,
}

-- the layout of a building from the attributes the server put on its model (Interior names the kind)
function Interiors.of(a: { [string]: any }, cfg: Config): Layout?
	local kind = a.Interior
	if kind == "Office" then
		return Interiors.office(a.W, a.D, a.Floors, a.DoorX, cfg)
	elseif kind == "Shop" then
		return Interiors.shop(a.W, a.D, a.H, a.DoorX, a.Island)
	elseif kind == "Restaurant" then
		return Interiors.restaurant(a.W, a.D, cfg)
	elseif kind == "Warehouse" then
		return Interiors.warehouse(a.W, a.D, a.H, a.DoorA, a.Walkway)
	end
	return nil
end

return Interiors
