--!strict
-- Buildings with a purpose: the burger place, the parcel warehouse, office lobbies, shops and signs, in the
-- town style (Kit, Config/Buildings). Everything is anchored chunks like the rest of the city, so
-- BuildingService smashes and rebuilds it.
-- Each builder returns a Place: where its door is and where people stand inside (paths from the door or
-- from the staff area), which the crowd uses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buildings = require(ReplicatedStorage.Shared.Config.Buildings)
local Crowd = require(ReplicatedStorage.Shared.Config.Crowd)
local CrowdRules = require(ReplicatedStorage.Shared.Rules.Crowd)
local InteriorConfig = require(ReplicatedStorage.Shared.Config.Interiors)
local Layouts = require(ReplicatedStorage.Shared.Rules.Interiors)
local World = require(ReplicatedStorage.Shared.Config.World)
local Kit = require(script.Parent.Kit)

local Places = {}

export type Spot = { path: { Vector3 }, face: Vector3?, sit: boolean? } -- sit: on furniture the client draws
export type Place = {
	kind: CrowdRules.PlaceKind,
	name: string?,
	block: { number }?, -- city block (i, j); off-grid places have none
	door: Vector3, -- just outside the door, on the ground
	entry: Vector3, -- just inside
	hub: Vector3?, -- where staff move between their spots
	staffIn: { Vector3 }?, -- how staff get from the door to the hub (straight in if nil)
	spots: { Spot }, -- where visitors and residents stand (paths start at entry)
	staffSpots: { Spot }, -- paths start at hub
	indoors: boolean,
	node: number?, -- sidewalk node in front of the door (set by the crowd)
}

local Y0 = Kit.Y0

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- a board with big text on its front (and back) face
function Places.sign(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	text: string,
	back: Color3,
	front: Color3,
	bothSides: boolean?
): Part
	local board = part(parent, size, cf, back)
	for _, face in
		if bothSides then { Enum.NormalId.Front, Enum.NormalId.Back } else { Enum.NormalId.Front }
	do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.LightInfluence = 0.2
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = front
		label.Text = text
		label.Parent = gui
		gui.Parent = board
	end
	return board
end

local function rightOf(out: Vector3): Vector3
	return Vector3.new(-out.Z, 0, out.X)
end

-- what the layouts need to know (the client furnishes from the same numbers)
Places.LayoutConfig = table.freeze({
	FloorHeight = World.Map.FloorHeight,
	Floors = InteriorConfig.Town.OfficeFloors,
	DeskEvery = InteriorConfig.Town.DeskEvery,
	Tables = Buildings.Restaurant.Tables,
	TableZ = Buildings.Restaurant.TableZ,
}) :: Layouts.Config

type Inside = { spots: { Spot }, staff: { Spot }, hub: Vector3?, staffIn: { Vector3 }? }

-- the inside of a model that carries an Interior layout (its frame is the model's pivot, mirrored when the
-- Mirror attribute is set), turned into the crowd's spots in the world
local function inside(model: Model): Inside
	local layout = Layouts.of(model:GetAttributes(), Places.LayoutConfig)
	if not layout then
		return { spots = {}, staff = {} }
	end
	local pivot = model.WorldPivot
	local m = if model:GetAttribute("Mirror") then -1 else 1
	local function at(x: number, y: number, z: number): Vector3
		return (pivot * CFrame.new(x * m, y + Y0, -z)).Position
	end
	local function convert(list: { Layouts.Spot }): { Spot }
		local out: { Spot } = {}
		for _, sp in list do
			local path = {}
			for _, p in sp.via do
				table.insert(path, at(p.x, p.y, p.z))
			end
			table.insert(path, at(sp.x, sp.y, sp.z))
			table.insert(out, {
				path = path,
				face = pivot:VectorToWorldSpace(Vector3.new(sp.fx * m, 0, -sp.fz)),
				sit = sp.sit,
			})
		end
		return out
	end
	local hub = layout.hub
	local staffIn: { Vector3 } = {}
	for _, p in layout.staffIn do
		table.insert(staffIn, at(p.x, p.y, p.z))
	end
	return {
		spots = convert(layout.spots),
		staff = convert(layout.staff),
		hub = if hub then at(hub.x, hub.y, hub.z) else nil,
		staffIn = if #staffIn > 0 then staffIn else nil,
	}
end

-- the burger place; `out` points to the street it faces
function Places.restaurant(parent: Instance, c: Vector3, out: Vector3): Place
	local model = Instance.new("Model")
	model.Name = "Restaurant"
	local R = Buildings.Restaurant
	local W, D, H, T = Crowd.RestaurantSize[1], Crowd.RestaurantSize[2], R.Height, R.Wall
	local col = R.Colours
	local red, yellow, cream = Kit.rgb(col.wall), Kit.rgb(col.accent), Kit.rgb(col.trim)
	local ctx = Kit.context(
		model,
		c,
		out,
		false,
		{ wall = red, trim = cream, accent = yellow, roof = Kit.rgb(col.roof) },
		(Enum.Material :: any)[col.material],
		T
	)
	local put, seg = Kit.put, Kit.seg
	local along = rightOf(out)
	local base = Vector3.new(c.X, 0, c.Z)
	local zf, zb, hw = D / 2, -D / 2, W / 2
	local top = Y0 + H
	-- each client draws the chairs, tills, kitchen and lamps from this (Rules/Interiors)
	model.WorldPivot = ctx.base
	model:SetAttribute("Interior", "Restaurant")
	model:SetAttribute("Accent", yellow)
	model:SetAttribute("W", W)
	model:SetAttribute("D", D)
	-- front: four shop windows, the wide door in the middle under a porch
	local wins = { { -hw + 4, -hw + 20 }, { -hw + 22, -6 }, { 6, hw - 22 }, { hw - 20, hw - 4 } }
	Kit.row(ctx, zf, 1, Y0, H, {
		seg(-hw, wins[1][1], "s"),
		seg(wins[1][1], wins[1][2], "sw"),
		seg(wins[1][2], wins[2][1], "s"),
		seg(wins[2][1], wins[2][2], "sw"),
		seg(-6, -4, "s"),
		seg(-4, 4, "d", { bare = true }),
		seg(4, 6, "s"),
		seg(wins[3][1], wins[3][2], "sw"),
		seg(wins[3][2], wins[4][1], "s"),
		seg(wins[4][1], wins[4][2], "sw"),
		seg(wins[4][2], hw, "s"),
	})
	local back = {}
	for k = 0, 6 do
		table.insert(back, seg(-hw + k * W / 7, -hw + (k + 1) * W / 7, "s"))
	end
	Kit.row(ctx, zb, -1, Y0, H, back)
	Kit.sides(ctx, hw, zf, zb, Y0, H, true) -- the side windows are the drive-through hatches
	Kit.trims(ctx, 0, hw, zf, zb, top, true)
	Kit.gambrel(ctx, W, zf, zb, top, R.KneeShare, R.KneeRise, R.PeakRise)
	-- the hay-loft panel in the barn end carries the name
	put(ctx, Vector3.new(16, 8.4, 0.3), 0, top + R.KneeRise / 2, zf + 0.15, cream)
	local loft = Kit.at(ctx, 0, top + R.KneeRise / 2, zf + 0.45)
	Places.sign(
		model,
		Vector3.new(14.4, 6.8, 0.3),
		CFrame.lookAt(loft, loft + out),
		string.upper(Crowd.RestaurantName),
		yellow,
		red
	)
	-- porch over the door: a roof on two posts
	put(ctx, Vector3.new(13, 0.5, 6.5), 0, Y0 + 10.4, zf + 3.1, ctx.roof)
	put(ctx, Vector3.new(13.4, 0.8, 0.4), 0, Y0 + 10.4, zf + 6.4, cream)
	for _, e in { -5.8, 5.8 } do
		put(ctx, Vector3.new(0.8, 10.2, 0.8), e, Y0 + 5.1, zf + 5.8, cream)
	end
	-- striped awnings over the windows
	local tilt = math.rad(22)
	for _, wpair in wins do
		local sw = (wpair[2] - wpair[1]) / 4
		for k = 0, 3 do
			put(
				ctx,
				Vector3.new(sw, 0.3, 3.6),
				wpair[1] + (k + 0.5) * sw,
				Y0 + H - 3.4 - math.sin(tilt) * 1.8,
				zf + math.cos(tilt) * 1.8,
				if k % 2 == 0 then yellow else cream,
				nil,
				CFrame.Angles(-tilt, 0, 0)
			)
		end
	end
	-- drive-through canopy on the right-hand side, over the hatch
	local reach, len = R.DriveThru[1], R.DriveThru[2]
	put(ctx, Vector3.new(reach + 1, 0.6, len), hw + reach / 2, Y0 + 11.3, 0, ctx.roof)
	put(ctx, Vector3.new(0.4, 1, len + 0.4), hw + reach + 0.7, Y0 + 11.3, 0, cream)
	for _, e in { -1, 1 } do
		put(ctx, Vector3.new(0.9, 11, 0.9), hw + reach - 0.5, Y0 + 5.5, e * (len / 2 - 0.6), cream)
	end
	local thru = Kit.at(ctx, hw + reach / 2, Y0 + 12.9, len / 2 - 0.2)
	Places.sign(
		model,
		Vector3.new(14, 2.6, 0.3),
		CFrame.lookAt(thru, thru + out),
		"DRIVE-THRU",
		yellow,
		red,
		true
	)
	-- a giant burger on the ridge, at the street end
	local burger = base + out * (zf - 8) + Vector3.new(0, top + R.PeakRise + 1, 0)
	local function disc(dia: number, h: number, y: number, color: Color3)
		local p = part(
			model,
			Vector3.new(h, dia, dia),
			CFrame.new(burger + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			color
		)
		p.Shape = Enum.PartType.Cylinder
	end
	disc(14, 3, 1.5, Color3.fromRGB(214, 150, 70))
	disc(15.5, 0.8, 3.4, Color3.fromRGB(90, 170, 60))
	disc(15, 2.2, 4.9, Color3.fromRGB(110, 60, 36))
	part(
		model,
		Vector3.new(13, 0.5, 13),
		CFrame.new(burger + Vector3.new(0, 6.2, 0)) * CFrame.Angles(0, math.pi / 4, 0),
		Color3.fromRGB(255, 200, 40)
	)
	local bun = part(
		model,
		Vector3.new(14, 14, 14),
		CFrame.new(burger + Vector3.new(0, 6.6, 0)),
		Color3.fromRGB(222, 160, 76)
	)
	bun.Shape = Enum.PartType.Ball
	-- inside: floor, counter, grill, menu, tables
	part(
		model,
		Vector3.new(W - 2 * T, 0.3, D - 2 * T),
		CFrame.new(base + Vector3.new(0, Y0 + 0.15, 0)),
		cream,
		Enum.Material.Marble
	)
	local counterAt = base - out * (D * 0.1)
	part(
		model,
		Vector3.new(W * 0.6, 4, 3),
		CFrame.lookAt(
			counterAt + Vector3.new(0, Y0 + 2, 0),
			counterAt + out + Vector3.new(0, Y0 + 2, 0)
		),
		red:Lerp(Color3.new(0, 0, 0), 0.2)
	)
	local grillAt = base - out * (D / 2 - 4)
	part(
		model,
		Vector3.new(W * 0.5, 4, 4),
		CFrame.lookAt(
			grillAt + Vector3.new(0, Y0 + 2, 0),
			grillAt + out + Vector3.new(0, Y0 + 2, 0)
		),
		Color3.fromRGB(150, 150, 156),
		Enum.Material.DiamondPlate
	)
	local menuAt = base - out * (D / 2 - T - 0.4) + Vector3.new(0, Y0 + 11, 0)
	Places.sign(
		model,
		Vector3.new(24, 5, 0.4),
		CFrame.lookAt(menuAt, menuAt + out),
		"BURGERS  FRIES  SHAKES",
		Color3.fromRGB(30, 30, 34),
		yellow
	)
	for _, a in R.Tables do
		local at = base + out * (D * R.TableZ) + along * (a * W)
		part(model, Vector3.new(6, 0.6, 6), CFrame.new(at + Vector3.new(0, Y0 + 3, 0)), cream)
		part(
			model,
			Vector3.new(1, 3, 1),
			CFrame.new(at + Vector3.new(0, Y0 + 1.5, 0)),
			Color3.fromRGB(60, 60, 64)
		)
	end
	-- a pole sign by the road
	local poleAt = base + out * (D / 2 + 14) + along * (W / 2 + 4)
	part(
		model,
		Vector3.new(1.6, 26, 1.6),
		CFrame.new(poleAt + Vector3.new(0, Y0 + 13, 0)),
		Color3.fromRGB(70, 70, 76)
	)
	Places.sign(
		model,
		Vector3.new(18, 9, 1.4),
		CFrame.lookAt(
			poleAt + Vector3.new(0, Y0 + 28, 0),
			poleAt + Vector3.new(0, Y0 + 28, 0) + out
		),
		string.upper(Crowd.RestaurantName),
		yellow,
		red,
		true
	)
	model.Parent = parent

	local y = Vector3.new(0, Y0, 0)
	local entry = base + out * (D / 2 - 3) + y
	local hub = base - out * (D * 0.1 + 5) + along * (W * 0.4) + y
	local sideFront = base - out * (D * 0.1 - 5) + along * (W * 0.4) + y
	local pastTables = base + out * (D / 2 - 7) + along * (W * 0.4) + y
	local staffSpots: { Spot } = {}
	for _, a in { -8, 8 } do
		table.insert(
			staffSpots,
			{ path = { base - out * (D * 0.1 + 3) + along * a + y }, face = out }
		)
	end
	for _, a in { -10, 10 } do
		table.insert(staffSpots, { path = { grillAt + out * 4.5 + along * a + y }, face = -out })
	end
	-- customers queue at the tills and sit at the tables
	local spots = inside(model).spots
	return {
		kind = "restaurant",
		name = Crowd.RestaurantName,
		door = base + out * (D / 2 + 3) + y,
		entry = entry,
		hub = hub,
		spots = spots,
		staffSpots = staffSpots,
		indoors = true,
		-- staff walk round the end of the counter from the door
		staffIn = { pastTables, sideFront, hub },
	}
end

-- the parcel warehouse; `out` points to the street with the loading bays
function Places.warehouse(parent: Instance, c: Vector3, out: Vector3): Place
	local model = Instance.new("Model")
	model.Name = "Warehouse"
	local WB = Buildings.Warehouse
	local W, D, H, T =
		Crowd.WarehouseSize[1], Crowd.WarehouseSize[2], Crowd.WarehouseHeight, WB.Wall
	local col = WB.Colours
	local trim = Kit.rgb(col.trim)
	local ctx = Kit.context(model, c, out, false, {
		wall = Kit.rgb(col.wall),
		trim = trim,
		accent = Kit.rgb(col.accent),
		roof = Kit.rgb(col.roof),
	}, (Enum.Material :: any)[col.material], T)
	local put, seg = Kit.put, Kit.seg
	local along = rightOf(out)
	local base = Vector3.new(c.X, 0, c.Z)
	local P = WB.Panel
	local n = math.floor(W / P)
	local zf, zb, hw = D / 2, -D / 2, W / 2
	local half = H / 2
	local top = Y0 + H
	model.WorldPivot = ctx.base
	local bays = { [5] = true, [8] = true, [11] = true }
	local windows: { [number]: boolean } = {}
	for _, k in WB.Windows do
		windows[k] = true
	end
	-- two rows of tall panels; the bays leave the lower row open, the office door sits in panel 2
	local lower, upper, backRow = {}, {}, {}
	for k = 1, n do
		local a, b = -hw + (k - 1) * P, -hw + k * P
		if k == 2 then
			table.insert(lower, seg(a, a + 3.5, "s"))
			table.insert(lower, seg(a + 3.5, b - 3.5, "d"))
			table.insert(lower, seg(b - 3.5, b, "s"))
		else
			table.insert(lower, seg(a, b, if bays[k] then "x" else "s"))
		end
		table.insert(upper, seg(a, b, if windows[k] then "p" else "s"))
		table.insert(backRow, seg(a, b, "s"))
	end
	Kit.row(ctx, zf, 1, Y0, half, lower)
	Kit.row(ctx, zf, 1, Y0 + half, half, upper)
	Kit.row(ctx, zb, -1, Y0, half, backRow)
	Kit.row(ctx, zb, -1, Y0 + half, half, backRow)
	Kit.sides(ctx, hw, zf, zb, Y0, half)
	Kit.sides(ctx, hw, zf, zb, Y0 + half, half)
	Kit.trims(ctx, 0, hw, zf, zb, top, true)
	-- blue pilasters and a band across the front (the band is the header over the bays)
	for _, k in WB.Pilasters do
		local h = H - 2.3
		put(
			ctx,
			Vector3.new(1.6, h, T + 0.6),
			-hw + k * P,
			Y0 + 1.5 + h / 2,
			zf - T / 2 + 0.3,
			trim
		)
	end
	Kit.bandX(ctx, 0, W, Y0 + half, 0.8, T + 0.8, zf - T / 2 + 0.4, trim)
	-- bays framed like a house door, each roll-up door rolled into its drum
	for k in bays do
		local a = -hw + (k - 0.5) * P
		for _, e in { -1, 1 } do
			put(
				ctx,
				Vector3.new(0.8, half, T + 0.6),
				a + e * (P / 2 - 0.4),
				Y0 + half / 2,
				zf - T / 2 + 0.3,
				trim
			)
		end
		put(
			ctx,
			Vector3.new(P - 1.6, 2.4, 1.6),
			a,
			Y0 + half - 1.6,
			zf - T - 0.8,
			Color3.fromRGB(216, 219, 224)
		)
	end
	-- a canopy over the office door, a parapet with a cap along the front
	put(ctx, Vector3.new(8, 0.4, 3), -hw + 1.5 * P, Y0 + 9.5, zf + 1.5, trim)
	Kit.bandX(
		ctx,
		0,
		W + 0.4,
		top + WB.Parapet / 2,
		WB.Parapet,
		T,
		zf - T / 2,
		ctx.wall:Lerp(Color3.new(0, 0, 0), 0.25)
	)
	Kit.bandX(ctx, 0, W + 0.8, top + WB.Parapet + 0.25, 0.5, T + 0.6, zf - T / 2, trim)
	local tx, tz = 4, 3
	for i = 0, tx - 1 do
		for j = 0, tz - 1 do
			local at = base
				+ along * (-W / 2 + (i + 0.5) * W / tx)
				+ out * (-D / 2 + (j + 0.5) * D / tz)
			part(
				model,
				Vector3.new(W / tx, 1.2, D / tz),
				CFrame.lookAt(
					at + Vector3.new(0, Y0 + H + 0.6, 0),
					at + out + Vector3.new(0, Y0 + H + 0.6, 0)
				),
				ctx.roof
			)
		end
	end
	local signAt = base + out * (D / 2 + 1.4) + along * 8 + Vector3.new(0, Y0 + H - 8, 0)
	Places.sign(
		model,
		Vector3.new(70, 9, 1),
		CFrame.lookAt(signAt, signAt + out),
		string.upper(Crowd.WarehouseName),
		trim,
		Color3.new(1, 1, 1)
	)
	local boxAt = signAt - along * 43
	part(
		model,
		Vector3.new(9, 9, 2),
		CFrame.lookAt(boxAt, boxAt + out),
		Color3.fromRGB(196, 150, 96),
		Enum.Material.Cardboard
	)
	part(
		model,
		Vector3.new(1.6, 9.2, 2.2),
		CFrame.lookAt(boxAt, boxAt + out),
		Color3.fromRGB(230, 210, 170)
	)
	-- shelving in aisles that run from the front to the back
	local box = Color3.fromRGB(190, 144, 92)
	local rackLen, rackMid = 50, -(D / 2 - 10 - 25)
	local aisles: { number } = {}
	for k = 0, 5 do
		local a = -60 + k * 24
		local mid = base + along * a + out * rackMid
		for _, e in { -1, 1 } do
			local endAt = mid + out * e * (rackLen / 2)
			part(
				model,
				Vector3.new(4, 14, 1),
				CFrame.lookAt(
					endAt + Vector3.new(0, Y0 + 7, 0),
					endAt + out + Vector3.new(0, Y0 + 7, 0)
				),
				Color3.fromRGB(230, 120, 30),
				Enum.Material.Metal
			)
		end
		for level = 0, 2 do
			local y = Y0 + 1 + level * 5
			part(
				model,
				Vector3.new(4, 0.5, rackLen),
				CFrame.lookAt(mid + Vector3.new(0, y, 0), mid + out + Vector3.new(0, y, 0)),
				Color3.fromRGB(60, 90, 150),
				Enum.Material.Metal
			)
			part(
				model,
				Vector3.new(3.4, 3.4, rackLen - 4),
				CFrame.lookAt(mid + Vector3.new(0, y + 2, 0), mid + out + Vector3.new(0, y + 2, 0)),
				box:Lerp(Color3.fromRGB(150, 110, 70), level * 0.3),
				Enum.Material.Cardboard
			)
		end
		if k < 5 then
			table.insert(aisles, a + 12)
		end
	end
	-- a conveyor by the bays with parcels on it
	local beltAt = base + out * (D / 2 - 26)
	part(
		model,
		Vector3.new(W * 0.55, 3, 4),
		CFrame.lookAt(
			beltAt + Vector3.new(0, Y0 + 1.5, 0),
			beltAt + out + Vector3.new(0, Y0 + 1.5, 0)
		),
		Color3.fromRGB(40, 40, 44),
		Enum.Material.Metal
	)
	for _, a in { -24, -4, 18 } do
		part(
			model,
			Vector3.new(2.6, 2, 2.6),
			CFrame.new(beltAt + along * a + Vector3.new(0, Y0 + 4, 0)),
			box,
			Enum.Material.Cardboard
		)
	end
	-- delivery trucks backed up to two bays, pallets by the third
	for _, k in { 5, 11 } do
		local a = -W / 2 + (k - 0.5) * (W / n)
		local at = base + out * (D / 2 + 14) + along * a
		part(
			model,
			Vector3.new(10, 11, 20),
			CFrame.lookAt(at + Vector3.new(0, Y0 + 7, 0), at + out + Vector3.new(0, Y0 + 7, 0)),
			Color3.fromRGB(240, 240, 240)
		)
		local cab = at + out * 13.5
		part(
			model,
			Vector3.new(10, 8, 7),
			CFrame.lookAt(cab + Vector3.new(0, Y0 + 5, 0), cab + out + Vector3.new(0, Y0 + 5, 0)),
			trim
		)
	end
	local palletAt = base + out * (D / 2 + 5) + along * (-W / 2 + 7.5 * (W / n))
	for s = 0, 2 do
		part(
			model,
			Vector3.new(5, 4, 5),
			CFrame.new(palletAt + along * (s * 6 - 6) + Vector3.new(0, Y0 + 2, 0)),
			box,
			Enum.Material.Cardboard
		)
	end
	model.Parent = parent

	local y = Vector3.new(0, Y0, 0)
	local doorA = -W / 2 + 1.5 * (W / n)
	local hub = base + out * (D / 2 - 6) + along * doorA + y
	local staffSpots: { Spot } = {}
	-- a walkway between the conveyor and the racks keeps everyone clear of both
	local frontRow = rackMid + rackLen / 2 + 4
	local walkway = rackMid + rackLen / 2 + 14
	local w1 = base + out * walkway + along * (doorA + 6) + y
	for _, a in aisles do
		local aisleFront = base + out * frontRow + along * a + y
		local onWalk = base + out * walkway + along * a + y
		table.insert(staffSpots, { path = { w1, onWalk, aisleFront }, face = -out })
		table.insert(staffSpots, {
			path = { w1, onWalk, aisleFront, base + out * (rackMid + 5) + along * a + y },
			face = along,
		})
	end
	for _, a in { -24, -4, 18 } do
		table.insert(staffSpots, {
			path = {
				w1,
				base + out * walkway + along * a + y,
				beltAt - out * 3.5 + along * a + y,
			},
			face = out,
		})
	end
	for _, k in { 5, 8, 11 } do
		local a = -W / 2 + (k - 0.5) * (W / n)
		table.insert(
			staffSpots,
			{ path = { base + out * (D / 2 - 6) + along * a + y }, face = out }
		)
	end
	-- lights, forklifts, packing tables and the office desk, drawn by each client (Rules/Interiors)
	model:SetAttribute("Interior", "Warehouse")
	model:SetAttribute("Accent", Kit.rgb(col.accent))
	model:SetAttribute("W", W)
	model:SetAttribute("D", D)
	model:SetAttribute("H", H)
	model:SetAttribute("DoorA", doorA)
	model:SetAttribute("Walkway", walkway)
	for _, sp in inside(model).staff do
		table.insert(staffSpots, sp)
	end
	return {
		kind = "warehouse",
		name = Crowd.WarehouseName,
		door = base + out * (D / 2 + 3) + along * doorA + y,
		entry = hub,
		hub = hub,
		spots = {},
		staffSpots = staffSpots,
		indoors = true,
	}
end

-- an office tower's name sign and the people inside (the tower is built by TownKit, which marks its
-- interior: the lobby and the desks upstairs); `door` is the middle of the doorway at ground level,
-- `width` the length of that face
function Places.office(
	model: Model,
	door: Vector3,
	out: Vector3,
	width: number,
	top: number,
	name: string
): Place
	local y = Vector3.new(0, Y0, 0)
	local front = Vector3.new(door.X, 0, door.Z)
	local signAt = front - out * 2 + Vector3.new(0, top + 5, 0)
	Places.sign(
		model,
		Vector3.new(math.min(width * 0.8, 60), 8, 1),
		CFrame.lookAt(signAt, signAt + out),
		name,
		Color3.fromRGB(24, 28, 40),
		Color3.new(1, 1, 1),
		true
	)
	local i = inside(model)
	return {
		kind = "office",
		name = name,
		door = front + out * 3 + y,
		entry = front - out * 3 + y,
		hub = i.hub,
		staffIn = i.staffIn,
		spots = i.spots,
		staffSpots = i.staff,
		indoors = true,
	}
end

-- a shop in a row: shoppers browse, the shopkeeper keeps the till (TownKit marks its interior)
function Places.shop(model: Model, front: Vector3, out: Vector3, name: string): Place
	local y = Vector3.new(0, Y0, 0)
	local i = inside(model)
	return {
		kind = "shop",
		name = name,
		door = front + out * 3 + y,
		entry = front - out * 4 + y,
		hub = i.hub,
		staffIn = i.staffIn,
		spots = i.spots,
		staffSpots = i.staff,
		indoors = true,
	}
end

-- an open area (park, plaza, spawn plaza, stunt park): people walk in from `door` to random spots
function Places.open(kind: CrowdRules.PlaceKind, door: Vector3, spots: { Vector3 }): Place
	local list: { Spot } = {}
	for _, s in spots do
		table.insert(list, { path = { Vector3.new(s.X, Y0, s.Z) } })
	end
	return {
		kind = kind,
		door = Vector3.new(door.X, Y0, door.Z),
		entry = Vector3.new(door.X, Y0, door.Z),
		spots = list,
		staffSpots = {},
		indoors = false,
	}
end

return Places
