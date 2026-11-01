--!strict
-- Buildings with a purpose: homes, the burger place, the parcel warehouse, office lobbies and signs.
-- Everything is anchored chunks like the rest of the city, so BuildingService smashes and rebuilds it.
-- Each builder returns a Place: where its door is and where people stand inside (paths from the door or
-- from the staff area), which the crowd uses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crowd = require(ReplicatedStorage.Shared.Config.Crowd)
local CrowdRules = require(ReplicatedStorage.Shared.Rules.Crowd)

local Places = {}

export type Spot = { path: { Vector3 }, face: Vector3? }
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

local GLASS = Color3.fromRGB(96, 140, 170)
local Y0 = 0.08 -- top of the block's sidewalk slab: floor level for everything on a block

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

local function glass(parent: Instance, size: Vector3, cf: CFrame): Part
	local g = part(parent, size, cf, GLASS, Enum.Material.Glass)
	g.Transparency = 0.25
	g:SetAttribute("Glass", true)
	return g
end

-- a wedge whose high edge points along -toward and whose slope runs down toward `toward`
local function wedge(
	parent: Instance,
	size: Vector3,
	centre: Vector3,
	toward: Vector3,
	color: Color3
): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = CFrame.lookAt(centre, centre - toward)
	w.Color = color
	w.Material = Enum.Material.SmoothPlastic
	w.Parent = parent
	return w
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

-- one storey of wall along a face. kinds per segment: "solid", "window", "door", "shop" (tall glass)
local function face(
	parent: Instance,
	centre: Vector3, -- middle of the face at floor level
	out: Vector3,
	along: Vector3,
	segments: { { from: number, to: number, kind: string } },
	y0: number,
	height: number,
	thick: number,
	color: Color3
)
	for _, s in segments do
		local len = s.to - s.from
		local mid = centre + along * ((s.from + s.to) / 2)
		local cf = CFrame.lookAt(mid, mid + out)
		local function slab(h0: number, h1: number)
			part(
				parent,
				Vector3.new(len, h1 - h0, thick),
				cf + Vector3.new(0, y0 + (h0 + h1) / 2, 0),
				color
			)
		end
		if s.kind == "solid" then
			slab(0, height)
		elseif s.kind == "door" then
			slab(8.5, height)
		elseif s.kind == "window" then
			slab(0, 4)
			glass(
				parent,
				Vector3.new(len, height - 7, thick * 0.6),
				cf + Vector3.new(0, y0 + 4 + (height - 7) / 2, 0)
			)
			slab(height - 3, height)
		elseif s.kind == "upper" then
			slab(0, 4)
			glass(
				parent,
				Vector3.new(len, height - 4, thick * 0.6),
				cf + Vector3.new(0, y0 + 4 + (height - 4) / 2, 0)
			)
		elseif s.kind == "shop" then
			slab(0, 1.5)
			glass(
				parent,
				Vector3.new(len, height - 4.5, thick * 0.6),
				cf + Vector3.new(0, y0 + 1.5 + (height - 4.5) / 2, 0)
			)
			slab(height - 3, height)
		end
	end
end

-- even segments across a length, every one the same kind except those listed in `special`
local function split(
	length: number,
	n: number,
	kind: string,
	special: { [number]: string }?
): { { from: number, to: number, kind: string } }
	local out = {}
	local w = length / n
	for k = 1, n do
		table.insert(out, {
			from = -length / 2 + (k - 1) * w,
			to = -length / 2 + k * w,
			kind = (special and special[k]) or kind,
		})
	end
	return out
end

local function rightOf(out: Vector3): Vector3
	return Vector3.new(-out.Z, 0, out.X)
end

-- a family home on a lot; `out` points from the house to the street
function Places.house(
	parent: Instance,
	c: Vector3,
	out: Vector3,
	floors: number,
	wall: Color3,
	roof: Color3,
	name: string
): Place
	local model = Instance.new("Model")
	model.Name = name
	local w, d, fh, T = Crowd.HouseWidth, Crowd.HouseDepth, Crowd.HouseFloorHeight, 1
	local along = rightOf(out)
	local base = Vector3.new(c.X, 0, c.Z)
	local doorHalf = 3
	face(model, base + out * (d / 2 - T / 2), out, along, {
		{ from = -w / 2, to = -doorHalf, kind = "window" },
		{ from = -doorHalf, to = doorHalf, kind = "door" },
		{ from = doorHalf, to = w / 2, kind = "window" },
	}, Y0, fh, T, wall)
	face(
		model,
		base - out * (d / 2 - T / 2),
		-out,
		along,
		split(w, 3, "window", { [2] = "solid" }),
		Y0,
		fh,
		T,
		wall
	)
	for _, s in { 1, -1 } do
		face(
			model,
			base + along * s * (w / 2 - T / 2),
			along * s,
			out,
			split(d - 2 * T, 2, "solid", { [2] = "window" }),
			Y0,
			fh,
			T,
			wall
		)
	end
	if floors > 1 then
		part(
			model,
			Vector3.new(w, 0.8, d),
			CFrame.new(base + Vector3.new(0, Y0 + fh, 0)),
			Color3.fromRGB(200, 196, 188)
		)
		face(
			model,
			base + out * (d / 2 - T / 2),
			out,
			along,
			split(w, 2, "upper"),
			Y0 + fh,
			fh,
			T,
			wall
		)
		face(
			model,
			base - out * (d / 2 - T / 2),
			-out,
			along,
			split(w, 2, "upper"),
			Y0 + fh,
			fh,
			T,
			wall
		)
		for _, s in { 1, -1 } do
			face(
				model,
				base + along * s * (w / 2 - T / 2),
				along * s,
				out,
				split(d - 2 * T, 2, "upper"),
				Y0 + fh,
				fh,
				T,
				wall
			)
		end
	end
	-- gable roof: two wedges meeting at a ridge that runs along the street
	local top = Y0 + floors * fh
	local rh = 7
	local roofSize = Vector3.new(w + 2, rh, d / 2 + 1)
	wedge(model, roofSize, base + out * (d / 4 + 0.5) + Vector3.new(0, top + rh / 2, 0), out, roof)
	wedge(model, roofSize, base - out * (d / 4 + 0.5) + Vector3.new(0, top + rh / 2, 0), -out, roof)
	-- a wooden floor and a sofa, so a window shows a home
	part(
		model,
		Vector3.new(w - 2 * T, 0.3, d - 2 * T),
		CFrame.new(base + Vector3.new(0, Y0 + 0.15, 0)),
		Color3.fromRGB(150, 110, 74),
		Enum.Material.WoodPlanks
	)
	local sofaAt = base - out * (d / 2 - 3) + along * (w / 4)
	part(
		model,
		Vector3.new(9, 3, 3.5),
		CFrame.lookAt(
			sofaAt + Vector3.new(0, Y0 + 1.5, 0),
			sofaAt + out + Vector3.new(0, Y0 + 1.5, 0)
		),
		wall:Lerp(Color3.fromRGB(60, 60, 70), 0.6),
		Enum.Material.Fabric
	)
	model.Parent = parent
	local entry = base + out * (d / 2 - 3) + Vector3.new(0, Y0, 0)
	local living = base + out * (d / 2 - 5) - along * (w / 4) + Vector3.new(0, Y0, 0)
	local back = base - out * (d / 2 - 7) - along * (w / 5) + Vector3.new(0, Y0, 0)
	return {
		kind = "home",
		name = name,
		door = base + out * (d / 2 + 3) + Vector3.new(0, Y0, 0),
		entry = entry,
		spots = {
			{ path = { living }, face = out },
			{ path = { base + Vector3.new(0, Y0, 0), back }, face = along },
		},
		staffSpots = {},
		indoors = true,
	}
end

-- the burger place; `out` points to the street it faces
function Places.restaurant(parent: Instance, c: Vector3, out: Vector3): Place
	local model = Instance.new("Model")
	model.Name = "Restaurant"
	local W, D, H, T = Crowd.RestaurantSize[1], Crowd.RestaurantSize[2], 16, 1.5
	local red, yellow, cream =
		Color3.fromRGB(196, 44, 40), Color3.fromRGB(250, 196, 40), Color3.fromRGB(246, 236, 214)
	local along = rightOf(out)
	local base = Vector3.new(c.X, 0, c.Z)
	face(
		model,
		base + out * (D / 2 - T / 2),
		out,
		along,
		split(W, 7, "shop", { [4] = "door" }),
		Y0,
		H,
		T,
		red
	)
	face(model, base - out * (D / 2 - T / 2), -out, along, split(W, 7, "solid"), Y0, H, T, red)
	for _, s in { 1, -1 } do
		face(
			model,
			base + along * s * (W / 2 - T / 2),
			along * s,
			out,
			split(D - 2 * T, 3, "solid", { [2] = "shop" }),
			Y0,
			H,
			T,
			red
		)
	end
	for _, s in { -1, 1 } do
		part(
			model,
			Vector3.new(W / 2, 1.2, D),
			CFrame.new(base + along * s * (W / 4) + Vector3.new(0, Y0 + H + 0.6, 0)),
			yellow
		)
	end
	-- awning over the door, signs, and a giant burger on the roof
	part(
		model,
		Vector3.new(W, 0.6, 5),
		CFrame.lookAt(
			base + out * (D / 2 + 2.5) + Vector3.new(0, Y0 + H - 3, 0),
			base + out * (D / 2 + 10) + Vector3.new(0, Y0 + H - 3, 0)
		),
		yellow
	)
	local roofSign = base + out * (D / 2 - 2) + Vector3.new(0, Y0 + H + 6, 0)
	Places.sign(
		model,
		Vector3.new(46, 9, 1),
		CFrame.lookAt(roofSign, roofSign + out),
		string.upper(Crowd.RestaurantName),
		red,
		yellow,
		true
	)
	local burger = base - out * 6 + Vector3.new(0, Y0 + H + 1.2, 0)
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
	local tables: { Vector3 } = {}
	for _, a in { -0.32, -0.12, 0.12, 0.32 } do
		local at = base + out * (D * 0.28) + along * (a * W)
		part(model, Vector3.new(6, 0.6, 6), CFrame.new(at + Vector3.new(0, Y0 + 3, 0)), cream)
		part(
			model,
			Vector3.new(1, 3, 1),
			CFrame.new(at + Vector3.new(0, Y0 + 1.5, 0)),
			Color3.fromRGB(60, 60, 64)
		)
		table.insert(tables, at)
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
	local spots: { Spot } = {}
	for _, a in { -8, 0, 8 } do
		table.insert(spots, { path = { base - out * (D * 0.1 - 5) + along * a + y }, face = -out })
	end
	for _, at in tables do
		table.insert(spots, { path = { at + out * 4.5 + y }, face = -out })
	end
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
	local W, D, H, T = Crowd.WarehouseSize[1], Crowd.WarehouseSize[2], Crowd.WarehouseHeight, 2
	local wall, trim = Color3.fromRGB(150, 156, 166), Color3.fromRGB(38, 92, 170)
	local along = rightOf(out)
	local base = Vector3.new(c.X, 0, c.Z)
	local n = math.floor(W / 12)
	local lower: { [number]: string } = { [2] = "door", [5] = "bay", [8] = "bay", [11] = "bay" }
	local half = H / 2
	-- two rows of tall panels; bays leave the lower row out, the door leaves a lintel
	for _, front in { true, false } do
		local o = if front then out else -out
		local lowerRow = split(W, n, "solid")
		for k, s in lowerRow do
			local kind = if front then lower[k] else nil
			if kind == "bay" then
				s.kind = "skip"
			elseif kind == "door" then
				s.kind = "door"
			end
		end
		local centre = base + o * (D / 2 - T / 2)
		for _, s in lowerRow do
			if s.kind ~= "skip" then
				face(model, centre, o, along, { s }, Y0, half, T, wall)
			end
		end
		face(model, centre, o, along, split(W, n, "solid"), Y0 + half, half, T, wall)
	end
	for _, s in { 1, -1 } do
		local o = along * s
		local rows = split(D - 2 * T, math.floor(D / 12), "solid")
		face(model, base + o * (W / 2 - T / 2), o, out, rows, Y0, half, T, wall)
		face(model, base + o * (W / 2 - T / 2), o, out, rows, Y0 + half, half, T, wall)
	end
	part(
		model,
		Vector3.new(W + 1, 2, 2.2),
		CFrame.lookAt(
			base + out * (D / 2) + Vector3.new(0, Y0 + H - 1, 0),
			base + out * (D / 2 + 1) + Vector3.new(0, Y0 + H - 1, 0)
		),
		trim
	)
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
				Color3.fromRGB(110, 114, 122)
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

-- an office tower's lobby desk and name sign (the tower itself, with its glass lobby and door, is built by
-- MapBuilder); `door` is the middle of the doorway at ground level, `width` the length of that face
function Places.office(
	model: Model,
	door: Vector3,
	out: Vector3,
	width: number,
	top: number,
	name: string,
	trim: Color3
): Place
	local along = rightOf(out)
	local y = Vector3.new(0, Y0, 0)
	local front = Vector3.new(door.X, 0, door.Z)
	local deskAt = front - out * 14 + along * 10
	part(
		model,
		Vector3.new(10, 3.6, 3),
		CFrame.lookAt(
			deskAt + Vector3.new(0, Y0 + 1.8, 0),
			deskAt + out + Vector3.new(0, Y0 + 1.8, 0)
		),
		trim
	)
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
	local entry = front - out * 3 + y
	return {
		kind = "office",
		name = name,
		door = front + out * 3 + y,
		entry = entry,
		hub = deskAt - out * 3 + y,
		spots = {
			{ path = { front - out * 8 - along * 8 + y }, face = out },
			{ path = { front - out * 10 - along * 16 + y }, face = along },
			{ path = { front - out * 6 + along * 22 + y }, face = out },
		},
		staffSpots = { { path = { deskAt - out * 3 + y }, face = out } },
		indoors = true,
	}
end

-- a shop in a row (people go in and out of sight)
function Places.shop(front: Vector3, out: Vector3, name: string): Place
	local y = Vector3.new(0, Y0, 0)
	return {
		kind = "shop",
		name = name,
		door = front + out * 3 + y,
		entry = front - out * 4 + y,
		spots = {},
		staffSpots = {},
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
