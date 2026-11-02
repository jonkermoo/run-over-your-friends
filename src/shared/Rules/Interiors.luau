--!strict
-- Inside the town buildings: where the furniture stands and where people sit or stand, worked out from each
-- building's size so the server (people's spots) and every client (the furniture) agree. Positions are in the
-- building's frame, like Config/Interiors: x to the right, z toward the street, y up from the ground floor;
-- (fx, fz) is the way a piece or a person faces. A spot's `via` is the way in from the door (or from the
-- staff hub); two points in a row at the same x, z on different floors are a ride in the lift.
-- Each layout also dresses the room itself: a finished floor, linings on the walls (skirting, wainscot,
-- window ledges), a ceiling with its lights. Those pieces sit just inside the walls and under the slabs, so
-- nothing pokes through the building or fights its faces.
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
	w: number?, -- width, for pieces that stretch (floors, linings, ceilings, partition, counter)
	d: number?, -- depth, for floors and ceilings
	h: number?, -- height, for linings and the lift core
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
-- a ceiling's thickness: it hangs from the slab (or roof) above, its lights flush under it
Interiors.Ceiling = 0.2
local CEIL = Interiors.Ceiling
-- office floor slabs: 1.2 thick, their tops at each floor height
local SLAB = 1.2
-- ceiling lights hang this far under the floor above (flush under the ceiling)
local UNDER = SLAB + CEIL

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
	d: number?,
	h: number?
)
	table.insert(
		l.pieces,
		{ kind = kind, x = x, y = y or 0, z = z, fx = fx or 0, fz = fz or 1, w = w, d = d, h = h }
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
function Interiors.across(width: number, every: number, margin: number): { number }
	local span = width - 2 * margin
	local n = math.max(1, math.floor(span / every) + 1)
	local out = {}
	for k = 0, n - 1 do
		table.insert(out, if n == 1 then 0 else -span / 2 + k * span / (n - 1))
	end
	return out
end
local across = Interiors.across

-- a lining of `kind` on each wall of the room x0..x1, z0..z1 (inside faces), facing in, `h` high from `y`;
-- `sides` picks the walls: b back, f front, l left, r right
local function linings(
	l: Layout,
	kind: string,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	y: number,
	h: number,
	sides: string
)
	local cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
	if string.find(sides, "b", 1, true) then
		piece(l, kind, cx, z0, 0, 1, y, w, nil, h)
	end
	if string.find(sides, "f", 1, true) then
		piece(l, kind, cx, z1, 0, -1, y, w, nil, h)
	end
	if string.find(sides, "l", 1, true) then
		piece(l, kind, x0, cz, 1, 0, y, d, nil, h)
	end
	if string.find(sides, "r", 1, true) then
		piece(l, kind, x1, cz, -1, 0, y, d, nil, h)
	end
end

export type OfficeConfig = {
	FloorHeight: number,
	Plans: { string },
	DeskEvery: number,
	OfficeWall: number?,
	Sill: number?,
}

-- which plan the middle of office floor `f` (1 = the first above the lobby) follows: they take turns up the
-- tower, starting with the first in the list
function Interiors.plan(f: number, plans: { string }): string
	return plans[(f - 1) % #plans + 1]
end

-- an office tower `w` across its front, `d` deep (its walls stand on those edges, half in, half out): a
-- lobby (reception, two waiting corners, a coffee corner, the lift core) and every floor above furnished:
-- desks along the front and back windows, a desk by the lift, a meeting table, and a middle by its plan
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
	local T = cfg.OfficeWall or 1.5
	local ix, iz = hw - T / 2, hd - T / 2 -- the inside faces of the walls
	local sill = cfg.Sill or FH / 4
	-- the lobby: a polished floor with a runner from the door, panelled side and back walls, a ceiling
	local deskZ = zf - 22
	piece(l, "LobbyFloor", 0, 0, 0, 1, 0, 2 * ix, 2 * iz)
	piece(l, "Runner", doorX, (iz + deskZ + 2) / 2, 0, 1, 0, 6, iz - deskZ - 2)
	linings(l, "LobbyWall", -ix, ix, -iz, iz, 0, FH - UNDER, "blr")
	piece(l, "Ceiling", 0, 0, 0, 1, FH - SLAB, 2 * ix, 2 * iz)
	-- reception desk facing the door, the receptionist's chair behind it and a water cooler
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
	-- the lift core in the middle (up to the ceiling), plants either side; two rows of lights
	local liftZ = -6
	piece(l, "LiftCore", doorX, liftZ, 0, 1, 0, nil, nil, FH - UNDER)
	for _, e in { -1, 1 } do
		piece(l, "Plant", doorX + e * 15, liftZ + 3.5)
	end
	for _, x in across(2 * ix, 28, 14) do
		piece(l, "PanelLight", x, zf - 12, 0, 1, FH - UNDER)
		piece(l, "PanelLight", x, -iz + 10, 0, 1, FH - UNDER)
	end
	local liftG = v(doorX - 4, 0, liftZ + 7)
	local toLift = { v(doorX - 12, 0, deskZ + 2), liftG }
	-- upper floors: carpet, linings under the window bands with a ledge, a ceiling; desks along the front and
	-- back windows, people facing out past their screens, a desk by the lift and a meeting table; the open
	-- middle of each floor takes its turn of the plans (open desk pods, cubicles, a break room)
	for f = 1, floors - 1 do
		local y = f * FH
		local plan = Interiors.plan(f, cfg.Plans)
		piece(l, "Carpet", 0, 0, 0, 1, y, 2 * ix, 2 * iz)
		piece(l, "CeilingPlain", 0, 0, 0, 1, y + FH - SLAB, 2 * ix, 2 * iz)
		piece(l, "LiftCore", doorX, liftZ, 0, 1, y, nil, nil, FH - UNDER)
		linings(l, "Sill", -ix, ix, -iz, iz, y, sill, "bflr")
		local liftF = v(liftG.x, y, liftG.z)
		-- the middle, clear of the walks from the lift (straight out to the front aisle, and down the corridor
		-- beside the core): desk pods (behind screens on cubicle floors) or café tables
		for _, z0 in { zf - 20, -hd + 20 } do
			for _, x in across(w, 24, 20) do
				if x < doorX - 26 or x > doorX + 6 then
					if plan == "Break" then
						for _, e in { -1, 1 } do
							local tx = x + e * 5
							piece(l, "CafeTable", tx, z0, 0, 1, y)
							for _, s in { -1, 1 } do
								piece(l, "Chair", tx + s * 2.6, z0, -s, 0, y)
							end
						end
					else
						for _, e in { -1, 1 } do
							for _, side in { -1, 1 } do
								piece(l, "Desk", x + e * 3.2, z0 + side * 1.4, 0, -side, y)
								piece(l, "Chair", x + e * 3.2, z0 + side * 4, 0, -side, y)
							end
						end
						piece(l, "Divider", x, z0, 0, 1, y, 12.8)
						if plan == "Cubicles" then
							for _, e in { -1, 1 } do
								piece(l, "Screen", x + e * 7, z0, -e, 0, y, 7)
							end
						end
					end
				end
			end
		end
		-- a break room's kitchen against the left wall
		if plan == "Break" then
			local kx = -ix + 1.2
			piece(l, "Fridge", -ix + 1.3, -20.5, 1, 0, y)
			piece(l, "Counter", kx, -14, 1, 0, y)
			piece(l, "Counter", kx, -6, 1, 0, y)
			piece(l, "WaterCooler", -ix + 1.2, 6, 1, 0, y)
		end
		-- a desk by the lift, facing the front, its chair behind it, a plant beside it
		local rx, rz = doorX + 18, liftZ + 14
		piece(l, "Reception", rx, rz, 0, 1, y)
		piece(l, "Chair", rx, rz - 2.6, 0, 1, y)
		piece(l, "Plant", rx + 8.5, rz + 2, 0, 1, y)
		for _, e in { -1, 1 } do
			piece(l, "Plant", e * (hw - 4), 0, 0, 1, y)
		end
		-- a meeting table beside the lift, two chairs a side
		local mx, mz = doorX + 28, liftZ + 4
		piece(l, "Rug", mx, mz, 0, 1, y)
		piece(l, "DiningTable", mx, mz, 0, 1, y)
		piece(l, "PanelLamp", mx, mz, 0, 1, y + FH - UNDER)
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
		for k, x in across(w, cfg.DeskEvery, 9) do
			-- every third panel over the desks lights the floor, the rest just glow (lights are dear)
			local lamp = if k % 3 == 2 then "PanelLamp" else "PanelGlow"
			piece(l, lamp, x, zf - 8, 0, 1, y + FH - UNDER)
			piece(l, lamp, x, -hd + 8, 0, 1, y + FH - UNDER)
			-- front window
			piece(l, "Desk", x, zf - 4, 0, 1, y)
			piece(l, "Chair", x, zf - 6.6, 0, 1, y)
			-- straight out of the lift to the front aisle, then along it (clear of the desk pods)
			spot(
				l.spots,
				x,
				zf - 6.6,
				0,
				1,
				true,
				concat(toLift, { liftF, v(liftF.x, y, zf - 11), v(x, y, zf - 11) }),
				y
			)
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

-- a shop `w` wide and `d` deep with a `h` high shop floor and walls `t` thick (inside its footprint):
-- shelves on the side wall and on a stock-room partition, two islands and a window display of the shop's
-- own kind (`island`), and the till counter by the door with the shopkeeper behind it
function Interiors.shop(
	w: number,
	d: number,
	h: number,
	doorX: number,
	island: string,
	t: number?
): Layout
	local l = new()
	local T = t or 1
	local half, zf = w / 2, d / 2
	local ix, izf = half - T, zf - T -- inside faces of the side walls and the front
	local zp = -zf + 18 -- the stock-room partition
	local ceil = h - 0.4 -- the underside of the flat's floor above
	local mid, len = (izf + zp) / 2, izf - zp
	piece(l, "Partition", 0, zp, 0, 1, 0, 2 * ix, nil, ceil)
	piece(l, "Floor", 0, mid, 0, 1, 0, 2 * ix, len - 0.6)
	linings(l, "ShopWall", -ix, ix, zp, izf, 0, ceil - CEIL, "lr")
	-- over the shop window and the door, the front wall's inside is lined too (the glass tops out 4 under
	-- the shop floor's height)
	piece(l, "Header", 0, izf, 0, -1, h - 4, 2 * ix, nil, ceil - CEIL - (h - 4))
	piece(l, "Ceiling", 0, mid, 0, 1, ceil, 2 * ix, len - 0.6)
	for _, x in { -half + 7, -half + 17, -half + 27 } do
		piece(l, "Shelf", x, zp + 1.2, 0, 1)
	end
	for _, z in { zf - 10, zf - 20, zf - 30 } do
		piece(l, "Shelf", -half + 1.9, z, 1, 0)
	end
	-- a track of spotlights over the wall shelves
	piece(l, "TrackLight", -ix + 3, zf - 20, 1, 0, ceil - CEIL, 26)
	local ix0 = -half + 12
	piece(l, island, ix0, zf - 14)
	piece(l, island, ix0, zf - 27)
	piece(l, island, -half + 18, zf - 4, 0, 1)
	-- the counter by the door, the till at the door end
	local cx = doorX - 6
	piece(l, "ShopCounter", cx, -2, 0, 1, 0, 14)
	for _, at in { { ix0, zf - 20 }, { ix0, zf - 6 }, { cx, 6 }, { cx, zp + 8 } } do
		piece(l, "PanelLight", at[1], at[2], 0, 1, ceil - CEIL)
	end
	piece(l, "Plant", half - 2.5, zf - 3.5)
	l.hub = v(doorX - 2, 0, -6)
	l.staffIn = { v(doorX - 16, 0, 0), v(doorX - 16, 0, -6), l.hub :: V }
	spot(l.staff, doorX - 8, -4.8, 0, 1)
	spot(l.staff, -half + 27, zp + 3.5, 0, -1)
	-- customers at the islands, the shelves and the counter
	spot(l.spots, ix0, zf - 17.5, 0, 1)
	spot(l.spots, ix0, zf - 23.5, 0, -1)
	spot(l.spots, -half + 5.3, zf - 10, -1, 0)
	spot(l.spots, -half + 7, zp + 3.5, 0, -1)
	spot(l.spots, doorX - 8, 1.4, 0, -1)
	return l
end

export type RestaurantConfig = {
	Tables: { number },
	TableZ: number,
	RestaurantWall: number?,
	RestaurantHeight: number?,
}

-- the burger place W × D (walls inside the footprint): a checkered dining floor and a tiled kitchen on top
-- of the server's floor (FLOOR thick), chairs at the four tables (the tables and counter themselves are the
-- server's), tills on the counter, fryers and a drinks machine in the kitchen, a beamed ceiling with lamps
-- over the tables
local FLOOR = 0.3
function Interiors.restaurant(W: number, D: number, cfg: RestaurantConfig): Layout
	local l = new()
	local T = cfg.RestaurantWall or 1.5
	local H = cfg.RestaurantHeight or 16
	local ix, iz = W / 2 - T, D / 2 - T
	local ceil = H - 0.4
	local counterZ = -D * 0.1
	local split = counterZ + 1.5 -- the front of the counter: dining in front, kitchen behind
	piece(l, "Checker", 0, (split + iz) / 2, 0, 1, FLOOR, 2 * ix, iz - split)
	piece(l, "KitchenFloor", 0, (split - iz) / 2, 0, 1, FLOOR, 2 * ix, split + iz)
	piece(l, "KitchenWall", 0, -iz, 0, 1, FLOOR, 2 * ix, nil, ceil - CEIL - FLOOR)
	linings(l, "Wainscot", -ix, ix, -iz, iz, FLOOR, 4, "lr")
	piece(l, "Header", 0, iz, 0, -1, H - 4, 2 * ix, nil, ceil - CEIL - (H - 4))
	piece(l, "WoodCeiling", 0, 0, 0, 1, ceil, 2 * ix, 2 * iz)
	for _, z in across(2 * iz, 12, 4) do
		piece(l, "Beam", 0, z, 0, 1, ceil - CEIL, 2 * ix)
	end
	local tz = D * cfg.TableZ
	for _, a in cfg.Tables do
		local tx = a * W
		-- a pendant whose rod reaches the ceiling (the lamp's rod top is 11.7 over its base)
		piece(l, "CeilingLamp", tx, tz, 0, 1, ceil - CEIL - 11.7)
		for _, e in { -1, 1 } do
			piece(l, "Chair", tx + e * 4.6, tz, -e, 0, FLOOR)
			spot(l.spots, tx + e * 4.6, tz, -e, 0, true, { v(tx + e * 4.6, 0, tz + 6.5) }, FLOOR)
		end
	end
	for _, x in { -8, 8 } do
		piece(l, "Register", x, counterZ, 0, 1, 4)
	end
	for _, x in { -8, 0, 8 } do
		spot(l.spots, x, counterZ + 5, 0, -1)
	end
	for _, x in { -14, 14 } do
		piece(l, "PanelLight", x, counterZ + 4, 0, 1, ceil - CEIL)
		piece(l, "PanelLight", x * 2, (counterZ - iz) / 2, 0, 1, ceil - CEIL)
	end
	local kz = -D / 2 + 4.5
	piece(l, "Fryer", -28, kz, 0, 1, FLOOR)
	piece(l, "DrinkMachine", 28, kz, 0, 1, FLOOR)
	for _, e in { -1, 1 } do
		piece(l, "Plant", e * 9, D / 2 - 3.5, 0, 1, FLOOR)
	end
	piece(l, "Bin", 14, D / 2 - 3, 0, 1, FLOOR)
	return l
end

-- the parcel warehouse W × D × H (walls `t` thick, inside the footprint): a sealed concrete floor with
-- painted lines, a kerb band round the walls, steel beams under the roof, high lights, forklifts, packing
-- tables by the bays and a desk by the office door, with staff spots reached along the walkway (`walkway`,
-- z) from the office door (`doorA`, x)
function Interiors.warehouse(
	W: number,
	D: number,
	H: number,
	doorA: number,
	walkway: number,
	t: number?
): Layout
	local l = new()
	local T = t or 2
	local ix, iz = W / 2 - T, D / 2 - T
	piece(l, "ConcreteFloor", 0, 0, 0, 1, 0, 2 * ix, 2 * iz)
	for _, e in { -1, 1 } do
		piece(l, "FloorLine", 0, walkway + e * 3.5, 0, 1, 0, 2 * ix - 4)
	end
	linings(l, "Kerb", -ix, ix, -iz, iz, 0, 4, "blr")
	for _, z in across(2 * iz, 24, 8) do
		piece(l, "Girder", 0, z, 0, 1, H, 2 * ix)
	end
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
	Plans: { string },
	DeskEvery: number,
	Tables: { number },
	TableZ: number,
	OfficeWall: number,
	Sill: number,
	ShopWall: number,
	RestaurantWall: number,
	RestaurantHeight: number,
	WarehouseWall: number,
}

-- the numbers the layouts need, from the shared configs (World, Buildings, Houses, Interiors), so the
-- server and every client build the same rooms
function Interiors.config(world: any, buildings: any, houses: any, interiors: any): Config
	return table.freeze({
		FloorHeight = world.Map.FloorHeight,
		Plans = interiors.Town.FloorPlans,
		DeskEvery = interiors.Town.DeskEvery,
		Tables = buildings.Restaurant.Tables,
		TableZ = buildings.Restaurant.TableZ,
		OfficeWall = world.Map.WallThickness,
		Sill = world.Map.FloorHeight * buildings.Office.SillShare,
		ShopWall = houses.Wall,
		RestaurantWall = buildings.Restaurant.Wall,
		RestaurantHeight = buildings.Restaurant.Height,
		WarehouseWall = buildings.Warehouse.Wall,
	})
end

-- the layout of a building from the attributes the server put on its model (Interior names the kind)
function Interiors.of(a: { [string]: any }, cfg: Config): Layout?
	local kind = a.Interior
	if kind == "Office" then
		return Interiors.office(a.W, a.D, a.Floors, a.DoorX, cfg)
	elseif kind == "Shop" then
		return Interiors.shop(a.W, a.D, a.H, a.DoorX, a.Island, cfg.ShopWall)
	elseif kind == "Restaurant" then
		return Interiors.restaurant(a.W, a.D, cfg)
	elseif kind == "Warehouse" then
		return Interiors.warehouse(a.W, a.D, a.H, a.DoorA, a.Walkway, cfg.WarehouseWall)
	end
	return nil
end

return Interiors
