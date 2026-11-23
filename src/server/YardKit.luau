--!strict
-- Lived-in lots (Config/Yards): a shed, a trampoline or a swing set in a back garden, and an office tower's
-- street front (awnings, planters with bushes, a bench). Every piece is a prop (any vehicle knocks it flying,
-- BuildingService stands it back up). Pieces draw from their own random streams, never the layout's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Yards)
local Foliage = require(ReplicatedStorage.Shared.Config.Foliage)
local Parks = require(ReplicatedStorage.Shared.Config.Parks)
local Suburbs = require(ReplicatedStorage.Shared.Config.Suburbs)
local World = require(ReplicatedStorage.Shared.Config.World)
local StreetGreen = require(ReplicatedStorage.Shared.Config.StreetGreen)
local Green = require(ReplicatedStorage.Shared.Rules.StreetGreen)
local Greenery = require(script.Parent.Greenery)
local LotKit = require(script.Parent.LotKit)
local StreetKit = require(script.Parent.StreetKit)

local YardKit = {}

export type Taken = { c: Vector3, half: Vector3 }

-- whether `p` is in (or within `pad` of) any of the boxes
function YardKit.inside(taken: { Taken }, p: Vector3, pad: number): boolean
	for _, t in taken do
		if math.abs(p.X - t.c.X) < t.half.X + pad and math.abs(p.Z - t.c.Z) < t.half.Z + pad then
			return true
		end
	end
	return false
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function pick(random: Random, list: { { number } }): Color3
	return rgb(list[random:NextInteger(1, #list)])
end

local function prop(folder: Instance, kind: string): Model
	local m = Instance.new("Model")
	m.Name = kind
	m:SetAttribute("Prop", kind)
	m.Parent = folder
	return m
end

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material?,
	class: string?
): BasePart
	local p = Instance.new(class or "Part") :: BasePart
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- a garden shed on `at` (the ground), its door facing `face`
local function shed(folder: Instance, at: Vector3, face: Vector3, random: Random)
	local S = Cfg.Shed
	local w, h, d = S.Size[1], S.Size[2], S.Size[3]
	local m = prop(folder, "Shed")
	local cf = CFrame.lookAt(at, at + face)
	part(
		m,
		Vector3.new(w, h, d),
		cf * CFrame.new(0, h / 2, 0),
		pick(random, S.Walls),
		Enum.Material.WoodPlanks
	)
	-- the gable: two wedges meeting along the ridge (front to back), a little proud of the walls
	local roof = rgb(S.RoofColour)
	for _, sx in { -1, 1 } do
		part(
			m,
			Vector3.new(d + 1, S.Roof, w / 2 + 0.6),
			cf
				* CFrame.new(sx * (w / 4 + 0.3), h + S.Roof / 2, 0)
				* CFrame.Angles(0, -sx * math.pi / 2, 0), -- the slope faces out, the tall side meets at the ridge
			roof,
			Enum.Material.Slate,
			"WedgePart"
		)
	end
	part(
		m,
		Vector3.new(w * 0.4, h * 0.8, 0.3),
		cf * CFrame.new(0, h * 0.4, -d / 2 - 0.15),
		rgb(S.Door),
		Enum.Material.Wood
	)
end

-- a round trampoline on `at`: a coloured rim, a black mat and three legs
local function trampoline(folder: Instance, at: Vector3, random: Random)
	local T = Cfg.Trampoline
	local m = prop(folder, "Trampoline")
	local up = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
	local rim = part(
		m,
		Vector3.new(0.5, T.Dia, T.Dia),
		up + Vector3.new(0, T.Height, 0),
		pick(random, T.Rim)
	)
	rim.Shape = Enum.PartType.Cylinder
	local mat = part(
		m,
		Vector3.new(0.3, T.Dia - 1.4, T.Dia - 1.4),
		up + Vector3.new(0, T.Height + 0.2, 0),
		rgb(T.Mat),
		Enum.Material.Fabric
	)
	mat.Shape = Enum.PartType.Cylinder
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3
		local leg = at + Vector3.new(math.cos(a), 0, math.sin(a)) * (T.Dia / 2 - 0.8)
		part(
			m,
			Vector3.new(0.35, T.Height, 0.35),
			CFrame.new(leg + Vector3.new(0, T.Height / 2, 0)),
			rgb(T.Legs),
			Enum.Material.Metal
		)
	end
end

-- a swing set on `at`, its bar running along `along`: two posts, the bar, two seats on ropes
local function swings(folder: Instance, at: Vector3, along: Vector3)
	local S = Cfg.Swings
	local m = prop(folder, "Swings")
	local cf = CFrame.lookAt(at, at + Vector3.new(-along.Z, 0, along.X))
	local frame = rgb(S.Frame)
	for _, sx in { -1, 1 } do
		part(
			m,
			Vector3.new(0.5, S.Height, 0.5),
			cf * CFrame.new(sx * S.Width / 2, S.Height / 2, 0),
			frame,
			Enum.Material.Metal
		)
	end
	part(
		m,
		Vector3.new(S.Width + 0.6, 0.5, 0.5),
		cf * CFrame.new(0, S.Height, 0),
		frame,
		Enum.Material.Metal
	)
	for _, sx in { -0.25, 0.25 } do
		local x = sx * S.Width
		part(m, Vector3.new(1.8, 0.3, 1), cf * CFrame.new(x, S.SeatHeight, 0), rgb(S.Seat))
		for _, rx in { -0.7, 0.7 } do
			part(
				m,
				Vector3.new(0.12, S.Height - S.SeatHeight - 0.1, 0.12),
				cf * CFrame.new(x + rx, S.SeatHeight + 0.1 + (S.Height - S.SeatHeight - 0.1) / 2, 0),
				rgb(S.Rope)
			)
		end
	end
end

-- maybe one thing in a back garden: `corner` is its spot on the ground, `face` toward the house
function YardKit.garden(folder: Instance, corner: Vector3, face: Vector3)
	local G = Cfg.Garden
	local own = Random.new(G.Seed + math.floor(corner.X) * 31 + math.floor(corner.Z) * 7)
	if own:NextNumber() >= G.Chance then
		return
	end
	local total = G.Kinds.shed + G.Kinds.trampoline + G.Kinds.swings
	local roll = own:NextNumber(0, total)
	if roll < G.Kinds.shed then
		shed(folder, corner, face, own)
	elseif roll < G.Kinds.shed + G.Kinds.trampoline then
		trampoline(folder, corner, own)
	else
		swings(folder, corner, face)
	end
end

-- a mesh from assets/Scenery.rbxm laid along a line from `a` to `b` on the ground, `height` tall and `depth`
-- deep; it collides and can be hit like any prop part
local function strip(
	m: Model,
	name: string,
	a: Vector3,
	b: Vector3,
	height: number,
	depth: number,
	colour: Color3
)
	local along = (b - a).Unit
	local mid = (a + b) / 2
	local s = Greenery.place(m, name, mid, nil, height, 0, colour)
	s.Size = Vector3.new((b - a).Magnitude, height, depth)
	s.CFrame = CFrame.fromMatrix(mid + Vector3.new(0, height / 2, 0), along, Vector3.yAxis)
	s.CanCollide = true
	s.CanQuery = true
	s.CanTouch = true
	return s
end

-- a bush prop on `at` (the ground), `size` across
local function frontBush(folder: Instance, at: Vector3, size: number, own: Random)
	local m = prop(folder, "Bush")
	local b = Greenery.place(
		m,
		Foliage.Bushes[own:NextInteger(1, #Foliage.Bushes)],
		at - Vector3.new(0, 0.3, 0),
		size,
		nil,
		own:NextNumber(0, math.pi * 2),
		rgb(Foliage.TuftGreens[own:NextInteger(1, #Foliage.TuftGreens)]):Lerp(
			Color3.new(0, 0, 0),
			0.1
		)
	)
	b.Material = Enum.Material.Grass
	b.CanCollide = true
	b.CanQuery = true
	b.CanTouch = true
end

export type Lot = {
	c: Vector3, -- the house's middle on the ground
	face: Vector3, -- toward the street
	width: number,
	depth: number,
	lawn: number, -- from the house's front wall to the sidewalk
	door: number, -- the door's offset to the house's right (the way `face` turned a quarter clockwise)
	drive: number, -- the driveway's middle, the same way
	driveWidth: number,
	car: boolean, -- a car parked on the driveway (no bike then)
	gaps: { { number } }, -- stretches across the lot (lo, hi, the same way) the border leaves open
	wallGaps: { { number } }, -- and more along the house's front kept clear of planting (a garage door)
	clear: (Vector3) -> boolean, -- whether a point on the ground is far enough off every street for the border
	compact: boolean?, -- a city home's small front garden: the border and small bushes only (Front.Compact)
}

-- a suburb house's front lawn (Config/Yards Front): maybe a picket fence or a hedge along its street edge, bushes
-- at the house's corners, a flower bed, a bike or a basketball hoop by the driveway
function YardKit.front(folder: Instance, lot: Lot)
	local F = Cfg.Front
	local c, face, w = lot.c, lot.face, lot.width
	local own = Random.new(F.Seed + math.floor(c.X) * 29 + math.floor(c.Z) * 11)
	local right = Vector3.new(-face.Z, 0, face.X)
	local wall = c + face * (lot.depth / 2)
	local function inGap(x0: number, x1: number): boolean
		for _, list in { lot.gaps, lot.wallGaps } do
			for _, g in list do
				if x1 > g[1] - F.Gap and x0 < g[2] + F.Gap then
					return true
				end
			end
		end
		return false
	end

	-- the border: runs between the gaps along the lawn's street edge
	if own:NextNumber() < F.Border then
		local hedge = own:NextNumber() < F.HedgeShare
		local colour = if hedge
			then rgb(Foliage.TuftGreens[own:NextInteger(1, #Foliage.TuftGreens)]):Lerp(
				Color3.new(0, 0, 0),
				0.2
			)
			else rgb(Suburbs.Picket)
		local line = wall + face * (lot.lawn - (if lot.compact then F.Compact.Inset else F.Inset))
		local half = w / 2 + (if lot.compact then F.Compact.Reach else F.Reach)
		local cuts = {}
		for _, g in lot.gaps do
			table.insert(cuts, { g[1] - F.Gap, g[2] + F.Gap })
		end
		table.sort(cuts, function(p, q)
			return p[1] < q[1]
		end)
		local runs = {}
		local x = -half
		for _, g in cuts do
			if g[1] > x then
				table.insert(runs, { x, math.min(g[1], half) })
			end
			x = math.max(x, g[2])
		end
		if x < half then
			table.insert(runs, { x, half })
		end
		local m = prop(folder, if hedge then "Hedge" else "Fence")
		for _, r in runs do
			local a, b = line + right * r[1], line + right * r[2]
			if r[2] - r[1] >= F.MinRun and lot.clear(a) and lot.clear(b) then
				if hedge then
					strip(
						m,
						Foliage.Bushes[1],
						a,
						b,
						F.HedgeHeight,
						if lot.compact then F.Compact.HedgeDepth else F.HedgeDepth,
						colour
					).Material =
						Enum.Material.Grass
				else
					strip(m, "Picket", a, b, F.PicketHeight, F.PicketDepth, colour)
				end
			end
		end
		if #m:GetChildren() == 0 then
			m:Destroy()
		end
	end

	-- planting along the house's front: a flower bed under a window on the side away from the driveway, and a
	-- bush at each front corner that is clear (not where the bed went)
	local away = if lot.drive > 0 then -1 else 1
	local bedSide = 0
	if own:NextNumber() < F.Bed and not lot.compact then
		local P = Parks.FlowerBed
		local bx = away * (w / 2 - F.Corner - P.width / 2)
		if
			math.abs(bx - lot.door) - P.width / 2 > F.DoorClear
			and not inGap(bx - P.width / 2, bx + P.width / 2)
		then
			Greenery.flowerBed(folder, wall + face * F.BedOut + right * bx, right, own)
			bedSide = away
		end
	end
	if own:NextNumber() < F.Bushes then
		for _, s in { -1, 1 } do
			local x = s * (w / 2 - F.Corner)
			local sizes = if lot.compact then F.Compact.BushSize else F.BushSize
			local size = own:NextNumber(sizes[1], sizes[2])
			if
				s ~= bedSide
				and math.abs(x - lot.door) > F.DoorClear
				and not inGap(x - size / 2, x + size / 2)
			then
				local out = if lot.compact then F.Compact.BushOut else F.BushOut
				frontBush(folder, wall + face * out + right * x, size, own)
			end
		end
	end
	if lot.compact then
		return -- no driveway in a city front garden
	end

	-- by the driveway: a bike leaning near the house, or a basketball hoop at its street end
	local roll = own:NextNumber()
	local edge = lot.drive + away * (lot.driveWidth / 2 - F.BikeEdge)
	if roll < F.Bike and not lot.car then
		local m = prop(folder, "Bike")
		local at = wall + face * (F.BikeBack + F.BikeLength / 2) + right * edge
		local bike = Greenery.place(
			m,
			"Bike",
			at,
			F.BikeLength,
			nil,
			0,
			rgb(F.Bikes[own:NextInteger(1, #F.Bikes)])
		)
		bike.CFrame = CFrame.fromMatrix(at, face, Vector3.yAxis)
				* CFrame.Angles(F.BikeLean * away, 0, 0)
			+ Vector3.new(0, bike.Size.Y / 2, 0)
		bike.Material = Enum.Material.Metal
		bike.CanCollide = true
		bike.CanQuery = true
		bike.CanTouch = true
	elseif roll < F.Bike + F.Hoop then
		-- the pole on the lawn beside the driveway's street end, the board over the driveway facing the house
		local m = prop(folder, "Hoop")
		local H, B = F.HoopHeight, F.Board
		local out = wall + face * (lot.lawn - F.HoopBack)
		local foot = out + right * (lot.drive + away * (lot.driveWidth / 2 + F.HoopOff))
		local board = out
			+ right * (lot.drive + away * (lot.driveWidth / 2 + F.HoopOff - F.HoopReach))
		local pole = rgb(F.HoopPole)
		part(
			m,
			Vector3.new(0.5, H + 1, 0.5),
			CFrame.new(foot + Vector3.new(0, (H + 1) / 2, 0)),
			pole,
			Enum.Material.Metal
		)
		part(
			m,
			Vector3.new(F.HoopReach, 0.4, 0.4),
			CFrame.lookAt((foot + board) / 2, (foot + board) / 2 + face)
				+ Vector3.new(0, H + 0.6, 0),
			pole,
			Enum.Material.Metal
		)
		local at = board + Vector3.new(0, H + B[2] / 2 - 0.4, 0)
		part(m, Vector3.new(B[1], B[2], B[3]), CFrame.lookAt(at, at - face), rgb(F.BoardColour))
		part(
			m,
			Vector3.new(1.9, 0.2, 1.9),
			CFrame.lookAt(at, at - face) * CFrame.new(0, 0.6 - B[2] / 2, -(B[3] / 2 + 1)),
			rgb(F.Rim),
			Enum.Material.Metal
		)
	end
end

-- a pocket park on `centre` (the ground); `toward` the unit way to the nearest street, `path` how far from the
-- middle the path runs that way (to the sidewalk)
function YardKit.pocketPark(
	folder: Instance,
	props: Instance,
	centre: Vector3,
	toward: Vector3,
	path: number
)
	local K = Cfg.Pocket
	local own = Random.new(K.Seed + math.floor(centre.X) * 19 + math.floor(centre.Z) * 5)
	local cf = CFrame.lookAt(centre, centre + toward)
	local function disc(
		parent: Instance,
		dia: number,
		tall: number,
		y: number,
		colour: Color3,
		material: Enum.Material?
	): BasePart
		local d = part(
			parent,
			Vector3.new(tall, dia, dia),
			CFrame.new(centre + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			colour,
			material
		)
		d.Shape = Enum.PartType.Cylinder
		return d
	end
	local paving = rgb(K.SquareColour)
	disc(folder, K.Square, 0.4, 0.05, paving, Enum.Material.Pavement)
	local half = K.Square / 2 - 1
	local run = path - half
	part(
		folder,
		Vector3.new(K.PathWidth, 0.4, run + 1),
		cf * CFrame.new(0, 0.02, -(half + run / 2)), -- its top just under the square's, no shared face
		paving,
		Enum.Material.Pavement
	)
	-- the fountain: a stone basin with water in it, a pillar with a bowl on top
	local fountain = prop(props, "Fountain")
	local stone = rgb(K.Stone)
	disc(fountain, K.Basin[1], K.Basin[2], K.Basin[2] / 2, stone, Enum.Material.Concrete)
	local water =
		disc(fountain, K.Basin[1] - 1.2, 0.3, K.Basin[2] + 0.05, rgb(K.Water), Enum.Material.Glass)
	water.Transparency = 0.2
	water.Reflectance = 0.2
	disc(
		fountain,
		K.Pillar[1],
		K.Pillar[2],
		K.Basin[2] + K.Pillar[2] / 2,
		stone,
		Enum.Material.Concrete
	)
	disc(
		fountain,
		K.Bowl[1],
		K.Bowl[2],
		K.Basin[2] + K.Pillar[2] + K.Bowl[2] / 2,
		stone,
		Enum.Material.Concrete
	)
	-- benches round the fountain facing it, between the path and the beds
	for k = 0, K.Benches - 1 do
		local a = (k + 0.5) * math.pi * 2 / K.Benches
		local way = (cf * CFrame.Angles(0, a, 0)).LookVector
		StreetKit.bench(props, centre + way * K.BenchAt, -way)
	end
	local function offPath(a: number): boolean
		local d = math.abs((a + math.pi) % (math.pi * 2) - math.pi)
		return d > K.PathClear
	end
	for k = 1, K.Beds do
		local a = k * math.pi * 2 / (K.Beds + 1)
		local way = (cf * CFrame.Angles(0, a, 0)).LookVector
		Greenery.flowerBed(props, centre + way * K.BedAt, Vector3.new(-way.Z, 0, way.X), own)
	end
	for k = 0, K.Trees - 1 do
		local a = (k + own:NextNumber(0.2, 0.8)) * math.pi * 2 / K.Trees
		if offPath(a) then
			local way = (cf * CFrame.Angles(0, a, 0)).LookVector
			Greenery.tree(
				props,
				centre + way * (K.TreeAt + own:NextNumber(-K.TreeJitter, K.TreeJitter)),
				own
			)
		end
	end
	-- lamps either side of where the path meets the square
	for _, s in { -1, 1 } do
		local at = (cf * CFrame.new(s * (K.PathWidth / 2 + K.LampOff), 0, -(half + K.LampOff))).Position
		LotKit.lamp(props, at)
	end
end

-- an office tower's street front: `door` on the ground at the front's middle, `out` toward the street,
-- `width` the front's length
function YardKit.officeFront(folder: Instance, door: Vector3, out: Vector3, width: number)
	local O = Cfg.Office
	local own = Random.new(O.Seed + math.floor(door.X) * 13 + math.floor(door.Z))
	local across = Vector3.new(-out.Z, 0, out.X)
	local colour = pick(own, O.Awnings)
	for _, sx in { -1, 1 } do
		local m = prop(folder, "Awning")
		local at = door + across * sx * width / 2 * O.AwningAt + out * (O.Awning[2] / 2)
		local cf = CFrame.lookAt(at, at + out) * CFrame.Angles(-O.AwningTilt, 0, 0)
		part(
			m,
			Vector3.new(O.Awning[1], O.Awning[3], O.Awning[2]),
			cf + Vector3.new(0, O.AwningHeight, 0),
			colour,
			Enum.Material.Fabric
		)
	end
	for _, sx in { -1, 1 } do
		local m = prop(folder, "Planter")
		local at = door + across * sx * (width / 2 - O.PlanterInset) + out * O.Out
		local P = O.Planter
		part(
			m,
			Vector3.new(P[1], P[2], P[3]),
			CFrame.lookAt(at, at + out) + Vector3.new(0, P[2] / 2, 0),
			rgb(O.PlanterColour),
			Enum.Material.Concrete
		)
		local bush = Greenery.place(
			m,
			Foliage.Bushes[own:NextInteger(1, #Foliage.Bushes)],
			at + Vector3.new(0, P[2] - 0.4, 0),
			O.BushSize,
			nil,
			own:NextNumber(0, math.pi * 2),
			rgb(Foliage.TuftGreens[own:NextInteger(1, #Foliage.TuftGreens)])
		)
		bush.Material = Enum.Material.Grass
	end
	StreetKit.bench(folder, door + across * O.BenchAt + out * O.Out, out)
end

-- beds on the bare paving either side of an office tower (Config/StreetGreen Forecourt, Rules/StreetGreen
-- flankRuns): a flat lawn strip along the sidewalk, a low hedge on the tower's side, flowers on the street's.
-- `centre` is the block's middle on the ground, `out` toward the tower's front, `inner` the paved middle,
-- `across` and `deep` the tower's size, `setback` its front's distance in from the front sidewalk
function YardKit.officeFlanks(
	folder: Instance,
	static: Instance,
	centre: Vector3,
	out: Vector3,
	inner: number,
	across: number,
	deep: number,
	setback: number
)
	local F = StreetGreen.Forecourt
	local side = Vector3.new(-out.Z, 0, out.X)
	for _, run in Green.flankRuns(inner, across, deep, setback, F) do
		local inward = if run.x > 0 then -side else side
		local a = centre + side * run.x + out * run.y0
		local b = centre + side * run.x + out * run.y1
		local len = run.y1 - run.y0
		local lawn = part(
			static,
			Vector3.new(len, F.Top, F.Depth),
			CFrame.fromMatrix((a + b) / 2 + Vector3.new(0, F.Top / 2, 0), out, Vector3.yAxis),
			rgb(StreetGreen.Verge.Colour),
			Enum.Material.Grass
		)
		lawn.CanCollide = false
		lawn.CanQuery = false
		lawn.CanTouch = false
		local m = prop(folder, "Hedge")
		local back = inward * (F.Depth / 2 - F.Hedge.depth / 2)
		strip(
			m,
			"BushA",
			a + back + Vector3.new(0, F.Top, 0),
			b + back + Vector3.new(0, F.Top, 0),
			F.Hedge.height,
			F.Hedge.depth,
			rgb(F.HedgeColour)
		).Material =
			Enum.Material.Grass
		local front = -inward * (F.Depth / 2 - F.BloomSize[3] / 2 - F.BloomEdge)
		for k = 1, F.Blooms do
			local at = a:Lerp(b, (k - 0.5) / F.Blooms) + front
			local bed = prop(folder, "FlowerBed")
			local blooms = Greenery.mesh(
				bed,
				"Blooms",
				1,
				CFrame.fromMatrix(
					at + Vector3.new(0, F.Top + F.BloomSize[2] / 2, 0),
					out,
					Vector3.yAxis
				),
				rgb(StreetGreen.Flowers[Green.spot(at.X, at.Z) % #StreetGreen.Flowers + 1])
			)
			blooms.Size = Vector3.new(F.BloomSize[1], F.BloomSize[2], F.BloomSize[3])
			blooms.Material = Enum.Material.SmoothPlastic
		end
	end
end

-- a slide: a ladder post, a platform and the chute sloping down along `along`
local function slide(folder: Instance, at: Vector3, along: Vector3)
	local M = Cfg.Middle
	local w, h, l = M.Slide[1], M.Slide[2], M.Slide[3]
	local m = prop(folder, "Slide")
	local cf = CFrame.lookAt(at, at + along)
	local colour = rgb(M.SlideColour)
	part(m, Vector3.new(w, 0.5, w), cf * CFrame.new(0, h, 0), colour)
	for _, sx in { -1, 1 } do
		part(
			m,
			Vector3.new(0.4, h, 0.4),
			cf * CFrame.new(sx * (w / 2 - 0.2), h / 2, w / 2 - 0.2),
			rgb(M.SlidePosts),
			Enum.Material.Metal
		)
	end
	local run = math.sqrt(l * l + h * h)
	part(
		m,
		Vector3.new(w - 0.4, 0.4, run),
		cf * CFrame.new(0, h / 2, -w / 2 - l / 2) * CFrame.Angles(-math.atan2(h, l), 0, 0),
		rgb(M.ChuteColour)
	)
end

-- the middle of a block of town homes: `centre` on the ground, `inner` the block's inner size, the hedge line
-- running along x through the middle. Returns the boxes it filled (middle and half size on the ground), so
-- trees can keep out of them
function YardKit.blockMiddle(folder: Instance, centre: Vector3, inner: number): { Taken }
	local M = Cfg.Middle
	local own = Random.new(M.Seed + math.floor(centre.X) * 17 + math.floor(centre.Z) * 3)
	local reach = inner / 2 * M.Reach
	local taken: { Taken } = {}
	local total = reach * 2 - M.HedgeGap * (M.Hedges - 1)
	local len = total / M.Hedges
	for k = 0, M.Hedges - 1 do
		local x = -reach + len / 2 + k * (len + M.HedgeGap)
		local m = prop(folder, "Hedge")
		local h = Greenery.place(
			m,
			Foliage.Bushes[own:NextInteger(1, #Foliage.Bushes)],
			centre + Vector3.new(x, -0.3, 0),
			nil,
			M.HedgeHeight,
			0,
			rgb(Foliage.TuftGreens[own:NextInteger(1, #Foliage.TuftGreens)]):Lerp(
				Color3.new(0, 0, 0),
				0.2
			)
		)
		h.Size = Vector3.new(len, M.HedgeHeight, M.HedgeDepth)
		h.CFrame = CFrame.new(centre + Vector3.new(x, M.HedgeHeight / 2 - 0.3, 0))
		h.Material = Enum.Material.Grass
		h.CanCollide = true
		h.CanQuery = true
		h.CanTouch = true
	end
	table.insert(taken, { c = centre, half = Vector3.new(reach, 0, M.HedgeDepth / 2) })
	-- a playground on every PlayEvery-th block, on one side of the hedge; the beds go on the other side
	local pitch = World.Map.BlockSize + World.Map.RoadWidth -- one block and its road
	local blockIndex = math.floor(centre.X / pitch + 0.5) + math.floor(centre.Z / pitch + 0.5)
	local play = blockIndex % M.PlayEvery == 0
	local playSide = if own:NextNumber() < 0.5 then 1 else -1
	for b = 1, M.Beds do
		local side = if play then -playSide else (if b % 2 == 0 then 1 else -1)
		local at = centre
			+ Vector3.new(own:NextNumber(-reach * 0.7, reach * 0.7), 0, side * M.BedOff)
		Greenery.flowerBed(folder, at, Vector3.new(1, 0, 0), own)
		table.insert(taken, { c = at, half = Vector3.new(6, 0, 3) })
	end
	if play then
		local gap = M.PlaySpacing
		local spot = centre
			+ Vector3.new(
				own:NextNumber(-reach * 0.5, reach * 0.5),
				0,
				playSide * (M.BedOff + M.PlayOff)
			)
		swings(folder, spot, Vector3.new(1, 0, 0))
		slide(folder, spot + Vector3.new(gap, 0, 0), Vector3.new(0, 0, playSide))
		local sand = prop(folder, "Sandpit")
		local S = M.Sand
		part(
			sand,
			Vector3.new(S[1] + 1, S[2] + 0.2, S[1] + 1),
			CFrame.new(spot + Vector3.new(-gap, (S[2] + 0.2) / 2, 0)),
			rgb(M.SandEdge),
			Enum.Material.WoodPlanks
		)
		part(
			sand,
			Vector3.new(S[1], S[2] + 0.3, S[1]),
			CFrame.new(spot + Vector3.new(-gap, (S[2] + 0.3) / 2, 0)),
			rgb(M.SandColour),
			Enum.Material.Sand
		)
		table.insert(taken, { c = spot, half = Vector3.new(gap + S[1] / 2 + 1, 0, M.Slide[3] + 2) })
	end
	return taken
end

return YardKit
