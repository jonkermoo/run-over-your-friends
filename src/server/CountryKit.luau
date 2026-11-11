--!strict
-- The countryside from Config/Country: hills, woods and islands past the map's edge, the farm, the motocross
-- track, the west-coast beaches and lighthouse, the pine forest and lake, the desert's blurred edge, and the
-- small fills used by OutskirtsKit (ring cells) and MapBuilder (outer sidewalk, parking bays, plaza stalls).
-- Hills and dirt are terrain (no parts); woods and pines are one-piece meshes; smashable things go in the
-- buildings folder, knockable things are props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Country)
local Outskirts = require(ReplicatedStorage.Shared.Config.Outskirts)
local Greenery = require(script.Parent.Greenery)
local Places = require(script.Parent.Places)

local CountryKit = {}

export type Rect = { x: number, z: number, w: number, d: number }
export type Ctx = {
	static: Folder,
	buildings: Folder,
	props: Folder,
	random: Random,
	half: number, -- half the ground's size
	seaEdge: number, -- x of the west coast (the port's quay)
	port: Rect,
	desert: Rect,
	connectors: { Rect },
}

local SEA_DEPTH = Outskirts.Port.SeaDepth -- the sea past the edge is as deep as the port's
local MOUND_STEP = Cfg.Edge.MoundStep
local BELT_SIZE = (ReplicatedStorage:WaitForChild("SceneryModels"):WaitForChild("Belt") :: MeshPart).Size
local BELT_HEIGHT = BELT_SIZE.Y
CountryKit.beltLength = BELT_SIZE.X -- the woods mesh's long side, at full size

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local WHITE = Color3.fromRGB(240, 240, 236)
local STEEL = Color3.fromRGB(70, 74, 80)
local ROAD = Color3.fromRGB(58, 60, 66)
local SAND = Color3.fromRGB(222, 196, 140)
local WATER = Color3.fromRGB(40, 110, 140)
local WOOD = Color3.fromRGB(150, 112, 76)

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

local function paint(parent: Instance, size: Vector3, cf: CFrame, color: Color3): Part
	local p = part(parent, size, cf, color)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- an upright cylinder standing on `at`
local function post(parent: Instance, height: number, dia: number, at: Vector3, color: Color3): Part
	local p = part(
		parent,
		Vector3.new(height, dia, dia),
		CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- a flat disc lying on the ground at `at`
local function disc(parent: Instance, thick: number, dia: number, at: Vector3, color: Color3): Part
	return post(parent, thick, dia, at, color)
end

local function prop(folder: Instance, kind: string): Model
	local m = Instance.new("Model")
	m.Name = kind
	m:SetAttribute("Prop", kind)
	m.Parent = folder
	return m
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function between(random: Random, range: { number }): number
	return random:NextNumber(range[1], range[2])
end

local function pick(random: Random, list: { { number } }): Color3
	return rgb(list[random:NextInteger(1, #list)])
end

local function inside(r: Rect, x: number, z: number, pad: number): boolean
	return math.abs(x - r.x) < r.w / 2 + pad and math.abs(z - r.z) < r.d / 2 + pad
end

-- terrain mounds (buried balls); `hills` keeps them so things can be stood on the slopes
type Ball = { x: number, z: number, cy: number, r: number }
local function mound(
	hills: { Ball }?,
	x: number,
	z: number,
	radius: number,
	height: number,
	material: Enum.Material
)
	local r = (radius * radius / height + height) / 2
	local cy = height - r
	-- the cap of a ball this big is too large for one FillBall, so stack it in flat discs from the sea floor up
	local step = MOUND_STEP
	local y = -SEA_DEPTH
	while y < height do
		local top = math.min(y + step, height)
		local mid = (y + top) / 2
		local d = math.sqrt(math.max(r * r - (mid - cy) ^ 2, 0))
		if d > 1 then
			workspace.Terrain:FillCylinder(
				CFrame.new(x, mid, z),
				top - y,
				math.min(d, radius * 1.1),
				material
			)
		end
		y = top
	end
	if hills then
		table.insert(hills, { x = x, z = z, cy = cy, r = r })
	end
end

-- the ground's height at (x, z) under the mounds in `hills` (0 where there are none)
local function heightAt(hills: { Ball }, x: number, z: number): number
	local y = 0
	for _, b in hills do
		local dx, dz = x - b.x, z - b.z
		local d2 = dx * dx + dz * dz
		if d2 < b.r * b.r then
			y = math.max(y, b.cy + math.sqrt(b.r * b.r - d2))
		end
	end
	return y
end

local function pine(folder: Instance, at: Vector3, height: number, random: Random)
	local p = Greenery.mesh(
		folder,
		"Pine",
		height,
		CFrame.new(at + Vector3.new(0, height / 2 - 1, 0))
			* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0),
		pick(random, Cfg.Edge.PineColours)
	)
	p.CanCollide = true
	return p
end

-- hills, woods and pines past the north, east and south edges; the sea and islands past the west
local function edges(ctx: Ctx)
	local E = Cfg.Edge
	local random, half = ctx.random, ctx.half
	local hills: { Ball } = {}
	-- each side: (along, out) as unit vectors in x/z; west is the sea
	local sides = {
		{ along = Vector3.new(1, 0, 0), out = Vector3.new(0, 0, -1) },
		{ along = Vector3.new(0, 0, 1), out = Vector3.new(1, 0, 0) },
		{ along = Vector3.new(1, 0, 0), out = Vector3.new(0, 0, 1) },
	}
	for _, s in sides do
		for _, row in { E.Near, E.Far } do
			local t = -half - E.Overrun
			while t <= half + E.Overrun do
				local radius = between(random, row.radius)
				local height = between(random, row.height)
				local at = s.along * (t + random:NextNumber(-0.3, 0.3) * E.Spacing)
					+ s.out * (half + between(random, row.out))
				-- the west end of the north and south rows runs out over the sea: no hills there
				if at.X > ctx.seaEdge then
					local material = if height >= E.RockFrom
						then Enum.Material.Rock
						else Enum.Material.Grass
					mound(hills, at.X, at.Z, radius, height, material)
				end
				t += E.Spacing
			end
		end
	end
	-- a belt of woods along each side's foot, just outside the walls
	for _, s in sides do
		local t = -half - E.BeltOverrun
		while t <= half + E.BeltOverrun do
			local at = s.along * t + s.out * (half + E.BeltOut)
			if at.X > ctx.seaEdge + E.CoastClear then
				local y = math.min(
					heightAt(hills, at.X - s.along.X * E.BeltLook, at.Z - s.along.Z * E.BeltLook),
					heightAt(hills, at.X, at.Z),
					heightAt(hills, at.X + s.along.X * E.BeltLook, at.Z + s.along.Z * E.BeltLook)
				)
				local belt = Greenery.mesh(
					ctx.static,
					"Belt",
					1,
					CFrame.lookAt(at, at + s.out)
						+ Vector3.new(0, y - E.BeltSink + BELT_HEIGHT / 2, 0),
					pick(random, E.BeltColours)
				)
				belt.CanCollide = false
				belt.CanQuery = false
			end
			t += E.BeltSpacing
		end
	end
	-- pines up the slopes
	local placed = 0
	local tries = 0
	while placed < E.Pines and tries < E.Pines * E.PineTries do
		tries += 1
		local s = sides[random:NextInteger(1, #sides)]
		local at = s.along * random:NextNumber(-half - E.PineOverrun, half + E.PineOverrun)
			+ s.out * (half + between(random, E.PineOut))
		if at.X > ctx.seaEdge + E.CoastClear then
			local y = heightAt(hills, at.X, at.Z)
			if y > E.PineMinHeight then
				local p = pine(
					ctx.static,
					Vector3.new(at.X, y, at.Z),
					between(random, E.PineHeight),
					random
				)
				p.CanCollide = false
				p.CanQuery = false
				placed += 1
			end
		end
	end
	-- the sea runs on past the west edge, islands on the horizon
	local seaW = E.SeaReach
	local depth = SEA_DEPTH
	workspace.Terrain:FillBlock(
		CFrame.new(-half - seaW / 2, -depth - 2, 0),
		Vector3.new(seaW, 4, half * 2 + E.Overrun * 2),
		Enum.Material.Sand
	)
	workspace.Terrain:FillBlock(
		CFrame.new(-half - seaW / 2, -depth / 2 - 0.5, 0),
		Vector3.new(seaW, depth - 1, half * 2 + E.Overrun * 2),
		Enum.Material.Water
	)
	for k = 1, E.Islands do
		local z = -half
			+ (k - 0.5) / E.Islands * half * 2
			+ random:NextNumber(-E.IslandJitter, E.IslandJitter)
		local x = -half - between(random, E.IslandOut)
		local radius = between(random, E.IslandRadius)
		mound(
			nil,
			x,
			z,
			radius * E.BeachSpread,
			between(random, E.IslandHeight) * E.BeachRise,
			Enum.Material.Sand
		)
		mound(nil, x, z, radius, between(random, E.IslandHeight), Enum.Material.Grass)
	end
end

-- crop rows on a field of soil, w along x
local function field(parent: Instance, centre: Vector3, w: number, d: number, crop: Color3)
	local F = Cfg.Farm
	part(
		parent,
		Vector3.new(w, 1, d),
		CFrame.new(centre + Vector3.new(0, -0.44, 0)),
		rgb(F.Soil),
		Enum.Material.Ground
	)
	local pitch = d / F.Rows
	for k = 0, F.Rows - 1 do
		paint(
			parent,
			Vector3.new(w - 6, F.RowHeight, pitch * 0.55),
			CFrame.new(centre + Vector3.new(0, 0.06 + F.RowHeight / 2, -d / 2 + (k + 0.5) * pitch)),
			crop
		).Material =
			Enum.Material.LeafyGrass
	end
end

-- a gable-roofed shed w x d (w along `along`), walls h, roof rising `roof` more; smashable
local function barn(
	parent: Instance,
	at: Vector3,
	out: Vector3,
	w: number,
	d: number,
	h: number,
	roof: number,
	wall: Color3,
	name: string
)
	local m = model(parent, name)
	local cf = CFrame.lookAt(at, at + out)
	local T = Cfg.Farm.BarnWall
	part(
		m,
		Vector3.new(w, h, T),
		cf * CFrame.new(0, h / 2, -d / 2 + T / 2),
		wall,
		Enum.Material.WoodPlanks
	)
	part(
		m,
		Vector3.new(w, h, T),
		cf * CFrame.new(0, h / 2, d / 2 - T / 2),
		wall,
		Enum.Material.WoodPlanks
	)
	for _, e in { -1, 1 } do
		part(
			m,
			Vector3.new(T, h, d - 2 * T),
			cf * CFrame.new(e * (w / 2 - T / 2), h / 2, 0),
			wall,
			Enum.Material.WoodPlanks
		)
	end
	-- gable ends: two wedges each, roof slopes over them
	for _, zf in { -1, 1 } do
		for _, e in { -1, 1 } do
			local wg = Instance.new("WedgePart")
			wg.Anchored = true
			wg.Size = Vector3.new(T, roof, w / 2)
			wg.CFrame = cf
				* CFrame.new(e * w / 4, h + roof / 2, zf * (d / 2 - T / 2))
				* CFrame.Angles(0, -e * math.pi / 2, 0) -- the wedge's tall end (its +Z) toward the ridge
			wg.Color = wall
			wg.Material = Enum.Material.WoodPlanks
			wg.Parent = m
		end
	end
	local slope = math.sqrt((w / 2) ^ 2 + roof ^ 2) + 2
	local tilt = math.atan2(roof, w / 2)
	for _, e in { -1, 1 } do
		part(
			m,
			Vector3.new(slope, 0.8, d + 3),
			cf * CFrame.new(e * w / 4, h + roof / 2 + 0.4, 0) * CFrame.Angles(0, 0, -e * tilt),
			Color3.fromRGB(70, 66, 64),
			Enum.Material.CorrodedMetal
		)
	end
	-- the big white-framed door on the front gable
	part(m, Vector3.new(w * 0.4, h * 0.75, 0.4), cf * CFrame.new(0, h * 0.375, -d / 2 - 0.2), WHITE)
	return m
end

local function farm(ctx: Ctx)
	local F = Cfg.Farm
	local r = F.Rect
	local random = ctx.random
	local folder = model(ctx.static, "Farm")
	local cols, rows = F.Fields[1], F.Fields[2]
	-- fields fill the western three quarters, the yard the east
	local fw = (r.w * 0.72 - F.FieldGap * (cols + 1)) / cols
	local fd = (r.d - F.FieldGap * (rows + 1)) / rows
	local left = r.x - r.w / 2
	local top = r.z - r.d / 2
	local crop = 0
	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			crop += 1
			local c = Vector3.new(
				left + F.FieldGap + fw / 2 + i * (fw + F.FieldGap),
				0,
				top + F.FieldGap + fd / 2 + j * (fd + F.FieldGap)
			)
			field(folder, c, fw, fd, rgb(F.Crops[(crop - 1) % #F.Crops + 1]))
			-- a wind break of trees along the field's north side
			local belt = Greenery.mesh(
				folder,
				"Belt",
				fw / 230,
				CFrame.new(c + Vector3.new(0, 0, -fd / 2 - F.FieldGap / 2))
					+ Vector3.new(0, 19 * fw / 230 - 2, 0),
				pick(random, Cfg.Edge.BeltColours)
			)
			belt.Size = Vector3.new(belt.Size.X, belt.Size.Y, 12)
		end
	end
	-- the yard: barn and silo facing west toward the fields, hay bales round them
	local yard = Vector3.new(r.x + r.w * 0.36, 0, r.z)
	local B = F.Barn
	barn(
		ctx.buildings,
		yard + Vector3.new(0, 0, -40),
		Vector3.new(-1, 0, 0),
		B.d,
		B.w,
		B.h,
		B.roof,
		rgb(F.BarnRed),
		"Barn"
	)
	local silo = model(ctx.buildings, "Silo")
	local S = F.Silo
	local at = yard + Vector3.new(10, 0, 30)
	post(silo, S.h, S.dia, at, Color3.fromRGB(200, 200, 204)).Material = Enum.Material.Metal
	local dome = part(
		silo,
		Vector3.one * S.dia,
		CFrame.new(at + Vector3.new(0, S.h, 0)),
		Color3.fromRGB(150, 156, 164)
	)
	dome.Shape = Enum.PartType.Ball
	for k = 1, F.Bales do
		local a = k / F.Bales * math.pi * 2
		local p = yard + Vector3.new(math.cos(a) * 75, 0, math.sin(a) * 90)
		local bale = prop(ctx.props, "Bale")
		local b = part(
			bale,
			Vector3.new(F.BaleSize[2], F.BaleSize[1], F.BaleSize[1]),
			CFrame.new(p + Vector3.new(0, F.BaleSize[1] / 2, 0)) * CFrame.Angles(0, a, 0),
			rgb(F.Hay),
			Enum.Material.Fabric
		)
		b.Shape = Enum.PartType.Cylinder
	end
end

local function moto(ctx: Ctx)
	local M = Cfg.Moto
	local r = M.Rect
	local random = ctx.random
	local folder = model(ctx.static, "Motocross")
	local lx, lz = M.Loop[1] / 2, M.Loop[2] / 2
	local W = M.Width
	local dirt = rgb(M.Dirt)
	-- straights (north and south, east and west) and corner pads: a rounded box loop of packed dirt
	part(
		folder,
		Vector3.new(M.Loop[1] + W, 1, W),
		CFrame.new(r.x, -0.42, r.z - lz),
		dirt,
		Enum.Material.Ground
	)
	part(
		folder,
		Vector3.new(M.Loop[1] + W, 1, W),
		CFrame.new(r.x, -0.42, r.z + lz),
		dirt,
		Enum.Material.Ground
	)
	part(
		folder,
		Vector3.new(W, 1, M.Loop[2] - W),
		CFrame.new(r.x - lx, -0.42, r.z),
		dirt,
		Enum.Material.Ground
	)
	part(
		folder,
		Vector3.new(W, 1, M.Loop[2] - W),
		CFrame.new(r.x + lx, -0.42, r.z),
		dirt,
		Enum.Material.Ground
	)
	-- a cross-track through the middle with a big table-top
	part(
		folder,
		Vector3.new(W, 1, M.Loop[2] - W),
		CFrame.new(r.x, -0.42, r.z),
		dirt,
		Enum.Material.Ground
	)
	mound(nil, r.x, r.z, M.JumpRadius * 2.2, M.JumpHeight * 1.6, Enum.Material.Ground)
	-- jumps along the straights, berms on the outside of the corners
	for k = 1, M.Jumps do
		local t = (k - 0.5) / M.Jumps
		local x, z
		if k % 2 == 0 then
			x, z = r.x + (t * 2 - 1) * lx * 0.8, r.z + (if k % 4 == 0 then lz else -lz)
		else
			x, z = r.x + (if k % 4 == 1 then lx else -lx), r.z + (t * 2 - 1) * lz * 0.8
		end
		mound(nil, x, z, M.JumpRadius, M.JumpHeight, Enum.Material.Ground)
	end
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		mound(
			nil,
			r.x + c[1] * (lx + W * 0.9),
			r.z + c[2] * (lz + W * 0.9),
			W * 1.4,
			10,
			Enum.Material.Ground
		)
	end
	-- the start gate on the south straight: two posts and a banner
	local gate = Vector3.new(r.x - lx * 0.4, 0, r.z + lz)
	for _, e in { -1, 1 } do
		post(folder, 16, 1.6, gate + Vector3.new(0, 0, e * (W / 2 + 2)), STEEL)
	end
	Places.sign(
		folder,
		Vector3.new(1, 6, W + 4),
		CFrame.new(gate + Vector3.new(0, 15, 0)) * CFrame.Angles(0, math.pi / 2, 0),
		"MOTOCROSS",
		Color3.fromRGB(30, 30, 32),
		Color3.fromRGB(250, 210, 70),
		true
	)
	for _ = 1, M.Tyres do
		local a = random:NextNumber(0, math.pi * 2)
		local p = Vector3.new(r.x, 0, r.z)
			+ Vector3.new(math.cos(a) * (lx - W), 0, math.sin(a) * (lz - W))
		local m = prop(ctx.props, "Tyres")
		post(m, 4, 5, p, Color3.fromRGB(30, 30, 32))
	end
end

local function beaches(ctx: Ctx)
	local B = Cfg.Beach
	local random = ctx.random
	local half = ctx.half
	local x0 = ctx.seaEdge
	local folder = model(ctx.static, "Beaches")
	for _, side in { -1, 1 } do
		local from = ctx.port.z + side * (ctx.port.d / 2 + B.Gap)
		local len = half - math.abs(from)
		local zc = from + side * len / 2
		part(
			folder,
			Vector3.new(B.Width, 1, len),
			CFrame.new(x0 + B.Width / 2, -0.43, zc),
			SAND,
			Enum.Material.Sand
		)
		-- umbrellas with a towel under each
		for _ = 1, B.Umbrellas do
			local at = Vector3.new(
				x0 + random:NextNumber(25, B.Width - 30),
				0,
				zc + random:NextNumber(-len / 2 + 40, len / 2 - 120)
			)
			local colour = pick(random, B.UmbrellaColours)
			local m = prop(ctx.props, "Umbrella")
			post(m, 10, 0.5, at, WHITE)
			disc(m, 1, 14, at + Vector3.new(0, 9.5, 0), colour)
			paint(
				folder,
				Vector3.new(4, 0.2, 8),
				CFrame.new(at + Vector3.new(3, 0.12, 2))
					* CFrame.Angles(0, random:NextNumber(-0.5, 0.5), 0),
				colour
			)
		end
		-- a lifeguard tower
		local tower = model(ctx.buildings, "Lifeguard")
		local t = Vector3.new(x0 + B.Width * 0.6, 0, zc)
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			part(
				tower,
				Vector3.new(0.8, 9, 0.8),
				CFrame.new(t + Vector3.new(c[1] * 4, 4.5, c[2] * 4)),
				WHITE
			)
		end
		part(
			tower,
			Vector3.new(10, 1, 10),
			CFrame.new(t + Vector3.new(0, 9.5, 0)),
			WOOD,
			Enum.Material.WoodPlanks
		)
		part(
			tower,
			Vector3.new(8, 6, 8),
			CFrame.new(t + Vector3.new(0, 13, 0)),
			Color3.fromRGB(230, 70, 60)
		)
		part(tower, Vector3.new(11, 0.6, 11), CFrame.new(t + Vector3.new(0, 16.3, 0)), WHITE)
	end
	-- a pier out into the sea from the south beach
	local pz = ctx.port.z + ctx.port.d / 2 + B.Gap + (half - ctx.port.d / 2) * 0.4
	local pier = model(ctx.buildings, "Pier")
	part(
		pier,
		Vector3.new(B.PierLength, 1, B.PierWidth),
		CFrame.new(x0 - B.PierLength / 2 + 20, 1.5, pz),
		WOOD,
		Enum.Material.WoodPlanks
	)
	for k = 0, 3 do
		for _, e in { -1, 1 } do
			post(
				pier,
				16,
				1.4,
				Vector3.new(x0 - k * B.PierLength / 4, -14, pz + e * (B.PierWidth / 2 - 1)),
				WOOD
			)
		end
	end
	-- the lighthouse at the south end of the coast, red and white bands
	local L = B.Lighthouse
	local lh = model(ctx.buildings, "Lighthouse")
	local at = Vector3.new(x0 + 30, 0, half - 260)
	local band = L.h / 5
	for k = 0, 4 do
		post(
			lh,
			band,
			L.dia * (1 - k * 0.06),
			at + Vector3.new(0, k * band, 0),
			if k % 2 == 0 then WHITE else rgb(B.LighthouseRed)
		)
	end
	disc(lh, 1, L.dia + 4, at + Vector3.new(0, L.h, 0), STEEL)
	local lamp =
		post(lh, 7, L.dia * 0.6, at + Vector3.new(0, L.h + 1, 0), Color3.fromRGB(255, 240, 180))
	lamp.Material = Enum.Material.Neon
	local cap = part(
		lh,
		Vector3.one * L.dia * 0.7,
		CFrame.new(at + Vector3.new(0, L.h + 8, 0)),
		rgb(B.LighthouseRed)
	)
	cap.Shape = Enum.PartType.Ball
end

local function forest(ctx: Ctx)
	local F = Cfg.Forest
	local r = F.Rect
	local random = ctx.random
	local folder = model(ctx.static, "Forest")
	local lake = Vector3.new(r.x + r.w * F.LakeAt[1], 0, r.z + r.d * F.LakeAt[2])
	disc(folder, 0.2, F.Lake * 2 + 16, lake, SAND).Material = Enum.Material.Sand
	local water = disc(folder, 0.3, F.Lake * 2, lake, WATER)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.15
	water.Reflectance = 0.15
	-- a jetty on the south bank, a log cabin beside it
	local jetty = lake + Vector3.new(0, 0, F.Lake - 20)
	part(
		folder,
		Vector3.new(8, 0.8, 50),
		CFrame.new(jetty + Vector3.new(0, 1, 0)),
		WOOD,
		Enum.Material.WoodPlanks
	)
	local cabinAt = lake + Vector3.new(60, 0, F.Lake + 45)
	barn(ctx.buildings, cabinAt, Vector3.new(0, 0, 1), 30, 22, 10, 7, rgb(F.Log), "Cabin")
	local taken = { { at = lake, r = F.Lake + 8 + F.Clear }, { at = cabinAt, r = 22 + F.Clear } }
	local placed, tries = 0, 0
	while placed < F.Pines and tries < F.Pines * 20 do
		tries += 1
		local at = Vector3.new(
			r.x + random:NextNumber(-r.w / 2, r.w / 2),
			0,
			r.z + random:NextNumber(-r.d / 2, r.d / 2)
		)
		local free = true
		for _, t in taken do
			if (at - t.at).Magnitude < t.r then
				free = false
				break
			end
		end
		if free then
			pine(folder, at, between(random, F.PineHeight), random)
			placed += 1
		end
	end
end

-- a gas station facing `out` (toward the road), centred at `at`: forecourt, canopy on posts, two pumps, a
-- shop with a glass front, a price sign. Canopy and shop smash; pumps get knocked over.
function CountryKit.gasStation(ctx: Ctx, at: Vector3, out: Vector3)
	local G = Cfg.Cells.Gas
	local red = rgb(Cfg.Cells.GasRed)
	local cf = CFrame.lookAt(at, at + out)
	part(
		ctx.static,
		Vector3.new(G.pad[1], 1, G.pad[2]),
		cf + Vector3.new(0, -0.41, 0),
		ROAD,
		Enum.Material.Asphalt
	)
	local station = model(ctx.buildings, "GasStation")
	local c = G.canopy
	part(station, Vector3.new(c[1], 1.4, c[2]), cf * CFrame.new(0, c[3], -G.pad[2] * 0.12), WHITE)
	part(
		station,
		Vector3.new(c[1] + 0.4, 1, c[2] + 0.4),
		cf * CFrame.new(0, c[3] - 1, -G.pad[2] * 0.12),
		red
	)
	for _, e in { -1, 1 } do
		part(
			station,
			Vector3.new(1.4, c[3] - 1.5, 1.4),
			cf * CFrame.new(e * c[1] * 0.3, (c[3] - 1.5) / 2, -G.pad[2] * 0.12),
			WHITE
		)
		local pump = prop(ctx.props, "Pump")
		part(
			pump,
			Vector3.new(2.4, 5, 1.6),
			cf * CFrame.new(e * c[1] * 0.3, 2.5, -G.pad[2] * 0.12 + 3),
			red
		)
	end
	local s = G.shop
	local back = cf * CFrame.new(0, 0, G.pad[2] / 2 - s[2] / 2 - 1)
	part(
		station,
		Vector3.new(s[1], s[3], s[2]),
		back * CFrame.new(0, s[3] / 2, 0),
		Color3.fromRGB(236, 232, 222),
		Enum.Material.Plaster
	)
	local glass = part(
		station,
		Vector3.new(s[1] - 6, s[3] * 0.55, 0.4),
		back * CFrame.new(0, s[3] * 0.4, -s[2] / 2 - 0.2),
		Color3.fromRGB(96, 140, 170),
		Enum.Material.Glass
	)
	glass.Transparency = 0.25
	glass:SetAttribute("Glass", true)
	part(station, Vector3.new(s[1] + 1, 1.6, s[2] + 1), back * CFrame.new(0, s[3] + 0.8, 0), red)
	local signAt = (cf * CFrame.new(c[1] * 0.75, 0, -G.pad[2] / 2 + 3)).Position
	post(station, 18, 1.2, signAt, STEEL)
	Places.sign(
		station,
		Vector3.new(12, 7, 1),
		CFrame.lookAt(signAt + Vector3.new(0, 20, 0), signAt + Vector3.new(0, 20, 0) + out),
		"GAS",
		red,
		WHITE,
		true
	)
end

-- a wind turbine standing on `at`, its rotor facing `out`
local function turbine(parent: Instance, at: Vector3, out: Vector3, spin: number)
	local T = Cfg.Cells.Turbine
	local m = model(parent, "Turbine")
	post(m, T.h, T.dia, at, WHITE)
	local hubAt = at + Vector3.new(0, T.h + 2, 0)
	local cf = CFrame.lookAt(hubAt, hubAt + out)
	part(m, Vector3.new(4, 4, 10), cf * CFrame.new(0, 0, 2), WHITE)
	local hub = part(m, Vector3.one * 4, cf * CFrame.new(0, 0, -3.5), WHITE)
	hub.Shape = Enum.PartType.Ball
	for k = 0, 2 do
		local a = spin + k * math.pi * 2 / 3
		part(
			m,
			Vector3.new(1.6, T.blade, 0.5),
			cf * CFrame.new(0, 0, -4) * CFrame.Angles(0, 0, a) * CFrame.new(0, T.blade / 2 + 1, 0),
			WHITE
		)
	end
end

-- one cell between the city and the ring, x/z its centre, w x d its size, `out` toward the ring
function CountryKit.cell(
	ctx: Ctx,
	use: string,
	x: number,
	z: number,
	w: number,
	d: number,
	out: Vector3
)
	local random = ctx.random
	local centre = Vector3.new(x, 0, z)
	local along = Vector3.new(-out.Z, 0, out.X)
	local long = math.abs(along.X) * w + math.abs(along.Z) * d -- along the ring
	local deep = math.abs(out.X) * w + math.abs(out.Z) * d -- toward the ring
	if use == "field" then
		local folder = model(ctx.static, "Field")
		local fw, fd = long - 40, deep - 50
		field(
			folder,
			centre,
			math.abs(along.X) * fw + math.abs(along.Z) * fd,
			math.abs(along.X) * fd + math.abs(along.Z) * fw,
			pick(random, Cfg.Farm.Crops)
		)
	elseif use == "turbines" then
		for _, e in { -1, 1 } do
			turbine(
				ctx.static,
				centre + along * e * long * 0.25,
				out,
				random:NextNumber(0, math.pi)
			)
		end
		for _ = 1, 2 do
			Greenery.tree(
				ctx.props,
				centre + along * random:NextNumber(-0.4, 0.4) * long - out * deep * 0.3,
				random
			)
		end
	elseif use == "gas" then
		CountryKit.gasStation(ctx, centre + out * (deep / 2 - Cfg.Cells.Gas.pad[2] / 2 - 4), out)
		Greenery.tree(ctx.props, centre - out * deep * 0.3 + along * long * 0.3, random)
	else
		for _ = 1, 4 do
			Greenery.tree(
				ctx.props,
				centre
					+ along * random:NextNumber(-0.4, 0.4) * long
					+ out * random:NextNumber(-0.35, 0.2) * deep,
				random
			)
		end
	end
end

-- the corner cells between the city and the ring: a small grove
function CountryKit.corner(ctx: Ctx, x: number, z: number, size: number)
	for _ = 1, Cfg.Cells.CornerTrees do
		Greenery.tree(
			ctx.props,
			Vector3.new(
				x + ctx.random:NextNumber(-0.35, 0.35) * size,
				0,
				z + ctx.random:NextNumber(-0.35, 0.35) * size
			),
			ctx.random
		)
	end
end

-- the desert's straight edges, blurred by low sand mounds, and a few more cacti at its rim
local function desertEdge(ctx: Ctx)
	local D = Cfg.DesertEdge
	local ds = ctx.desert
	local random = ctx.random
	for k = 1, D.Mounds do
		local t = random:NextNumber(-0.5, 0.5)
		local side = k % 4
		local x, z
		if side == 0 then
			x, z = ds.x + t * ds.w, ds.z - ds.d / 2
		elseif side == 1 then
			x, z = ds.x + t * ds.w, ds.z + ds.d / 2
		elseif side == 2 then
			x, z = ds.x - ds.w / 2, ds.z + t * ds.d
		else
			x, z = ds.x + ds.w / 2, ds.z + t * ds.d
		end
		-- leave the road in clear
		local onRoad = false
		for _, c in ctx.connectors do
			if inside(c, x, z, 20) then
				onRoad = true
			end
		end
		if not onRoad then
			mound(
				nil,
				x,
				z,
				between(random, D.Radius),
				between(random, D.Height),
				Enum.Material.Sand
			)
		end
	end
	local green = Color3.fromRGB(70, 130, 70)
	for _ = 1, D.Cacti do
		local side = if random:NextNumber() < 0.5 then -1 else 1
		local at = Vector3.new(
			ds.x + side * (ds.w / 2 + random:NextNumber(-40, 60)),
			0,
			ds.z + random:NextNumber(-ds.d / 2, ds.d / 2)
		)
		local m = prop(ctx.props, "Cactus")
		post(m, 14, 2.4, at, green)
		post(m, 5, 1.6, at + Vector3.new(2.6, 6, 0), green)
		post(m, 4, 1.6, at + Vector3.new(-2.6, 4, 0), green)
	end
end

-- everything past the ring that isn't a zone; returns the rects groves and ponds must keep clear of
function CountryKit.build(ctx: Ctx): { Rect }
	edges(ctx)
	farm(ctx)
	moto(ctx)
	beaches(ctx)
	forest(ctx)
	desertEdge(ctx)
	local half = ctx.half
	local band = 260 -- the hills' foot reaches this far in from the edge
	return {
		Cfg.Farm.Rect,
		Cfg.Moto.Rect,
		Cfg.Forest.Rect,
		{ x = 0, z = -half + band / 2, w = half * 2, d = band },
		{ x = 0, z = half - band / 2, w = half * 2, d = band },
		{ x = half - band / 2, z = 0, w = band, d = half * 2 },
		{ x = ctx.seaEdge + Cfg.Beach.Width / 2, z = 0, w = Cfg.Beach.Width + 40, d = half * 2 },
	}
end

-- a low grass hill on the open ground inside the walls
function CountryKit.hill(x: number, z: number, radius: number, height: number)
	mound(nil, x, z, radius, height, Enum.Material.Grass)
end

-- a strip of woods (the Belt mesh, `scale` of its full size) standing on flat ground at (x, z)
function CountryKit.wood(ctx: Ctx, x: number, z: number, scale: number)
	Greenery.mesh(
		ctx.static,
		"Belt",
		scale,
		CFrame.new(x, BELT_HEIGHT * scale / 2 - Cfg.Edge.BeltSink * scale, z)
			* CFrame.Angles(0, ctx.random:NextNumber(0, math.pi), 0),
		pick(ctx.random, Cfg.Edge.BeltColours)
	)
end

-- town fills -------------------------------------------------------------------------------------------------

-- parking bays painted in a lot (two rows back to back across the middle) and lamps at its corners
function CountryKit.lot(static: Instance, props: Instance, lotCentre: Vector3, inner: number)
	local L = Cfg.Lot
	local centre = lotCentre + Vector3.new(L.Shift, 0, 0) -- east, clear of the lot's west ramp
	local bw, bd = L.Bay[1], L.Bay[2]
	local rowLen = L.Bays * bw
	for _, side in { -1, 1 } do
		for k = 0, L.Bays do
			local x = -rowLen / 2 + k * bw
			paint(
				static,
				Vector3.new(L.Line, 0.05, bd),
				CFrame.new(centre + Vector3.new(x, 0.11, side * bd / 2 + side * 6)),
				WHITE
			)
		end
	end
	paint(
		static,
		Vector3.new(rowLen, 0.05, L.Line),
		CFrame.new(centre + Vector3.new(0, 0.11, 0)),
		WHITE
	)
	for k = 0, L.Lamps - 1 do
		local a = (k + 0.5) / L.Lamps * math.pi * 2
		local at = lotCentre + Vector3.new(math.cos(a), 0, math.sin(a)) * inner * 0.42
		local m = prop(props, "Lamp")
		post(m, 18, 0.8, at, STEEL)
		local head = part(
			m,
			Vector3.new(3, 0.8, 1.6),
			CFrame.new(at + Vector3.new(0, 18.2, 0)),
			Color3.fromRGB(255, 244, 214)
		)
		head.Material = Enum.Material.Neon
	end
end

-- market stalls round a plaza's edge, facing in; knockable
function CountryKit.plaza(props: Instance, centre: Vector3, inner: number, random: Random)
	local P = Cfg.Plaza
	local w, d, h = P.Stall[1], P.Stall[2], P.Stall[3]
	local a0 = random:NextNumber(0, math.pi * 2)
	for k = 0, P.Stalls - 1 do
		local a = a0 + k / P.Stalls * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local at = centre + dir * inner * 0.4
		local cf = CFrame.lookAt(at, centre)
		local m = prop(props, "Stall")
		local colour = pick(random, P.Awnings)
		part(
			m,
			Vector3.new(w, 3.5, d * 0.5),
			cf * CFrame.new(0, 1.75, 0),
			WOOD,
			Enum.Material.WoodPlanks
		)
		for _, e in { -1, 1 } do
			part(
				m,
				Vector3.new(0.5, h, 0.5),
				cf * CFrame.new(e * (w / 2 - 0.3), h / 2, d * 0.25),
				WOOD
			)
		end
		part(
			m,
			Vector3.new(w + 1, 0.5, d + 1),
			cf * CFrame.new(0, h, 0) * CFrame.Angles(0.18, 0, 0),
			colour,
			Enum.Material.Fabric
		)
	end
end

return CountryKit
