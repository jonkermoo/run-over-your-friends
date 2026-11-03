--!strict
-- The world outside the city grid, from Config/Outskirts: the ground and the sea, the highway ring and its
-- connectors, the cells between the city and the ring, the stunt park (east), the container port (west), the
-- desert (south), the construction site (north), and terrain hills over the ground the zones leave empty.
-- Terrain costs no parts, so hills, dunes, dirt jumps and the sea are terrain; what you smash is parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Outskirts)
local Rules = require(ReplicatedStorage.Shared.Rules.Outskirts)
local Streets = require(ReplicatedStorage.Shared.Config.Streets)
local Tiles = require(ReplicatedStorage.Shared.Rules.Tiles)
local Places = require(script.Parent.Places)

local OutskirtsKit = {}

export type Ctx = {
	static: Folder,
	buildings: Folder,
	props: Folder,
	random: Random,
	half: number, -- half the ground's size
	spanX: number, -- the city grid, outer roads included
	spanZ: number,
	x0: number,
	z0: number,
	road: number,
	pitch: number,
	blocksX: number,
	blocksZ: number,
}
export type Result = { walkPoints: { Vector3 }, places: { Places.Place } }

local C = Cfg.Colours
local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local COLORS = {
	road = Color3.fromRGB(58, 60, 66),
	grass = Color3.fromRGB(104, 160, 82),
	sand = Color3.fromRGB(222, 196, 140),
	concrete = Color3.fromRGB(190, 190, 195),
	ramp = Color3.fromRGB(240, 170, 50),
	stripe = Color3.fromRGB(40, 40, 44),
	trunk = Color3.fromRGB(110, 78, 52),
	leaves = Color3.fromRGB(70, 140, 70),
	white = Color3.fromRGB(240, 240, 236),
	yellow = Color3.fromRGB(242, 206, 70),
	metal = Color3.fromRGB(70, 74, 80),
}
local CONTAINERS = {
	Color3.fromRGB(190, 60, 50),
	Color3.fromRGB(40, 100, 170),
	Color3.fromRGB(230, 160, 40),
	Color3.fromRGB(60, 140, 90),
	Color3.fromRGB(150, 150, 155),
}
local MAX_PART = 2048

-- an anchored part; one longer than MAX_PART is laid as tiles (the first tile is returned)
local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?
): Part
	local first: Part? = nil
	for _, t in Tiles.split(size.X, size.Z, MAX_PART) do
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = Vector3.new(t.sx, size.Y, t.sz)
		p.CFrame = cf * CFrame.new(t.x, 0, t.z)
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Transparency = transparency or 0
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		first = first or p
	end
	return first :: Part
end

-- flat paint that never collides
local function paint(parent: Instance, size: Vector3, cf: CFrame, color: Color3): Part
	local p = part(parent, size, cf, color)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function cylinder(
	parent: Instance,
	length: number,
	dia: number,
	cf: CFrame,
	color: Color3
): Part
	local p = part(parent, Vector3.new(length, dia, dia), cf, color)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- an upright cylinder standing on `at`
local function post(parent: Instance, height: number, dia: number, at: Vector3, color: Color3): Part
	return cylinder(
		parent,
		height,
		dia,
		CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color
	)
end

-- a ramp you drive up while heading along `dir` (flat); its foot sits at `foot`
local function ramp(
	parent: Instance,
	foot: Vector3,
	dir: Vector3,
	width: number,
	height: number,
	length: number,
	color: Color3?,
	material: Enum.Material?
): WedgePart
	local look = dir.Unit
	local centre = foot + look * (length / 2) + Vector3.new(0, height / 2, 0)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = Vector3.new(width, height, length)
	w.CFrame = CFrame.lookAt(centre, centre - look) -- the high end ends up ahead of the driver
	w.Color = color or COLORS.ramp
	w.Material = material or Enum.Material.SmoothPlastic
	w.Parent = parent
	return w
end

-- dark bands across a ramp's slope (paint: they never bump a wheel)
local function stripes(w: WedgePart, n: number)
	local s = w.Size
	local tilt = -math.atan2(s.Y, s.Z)
	for k = 1, n do
		local z = -s.Z / 2 + k / (n + 1) * s.Z
		local cf = w.CFrame
			* CFrame.new(0, z * s.Y / s.Z, z)
			* CFrame.Angles(tilt, 0, 0)
			* CFrame.new(0, 0.12, 0)
		paint(w.Parent :: Instance, Vector3.new(s.X * 0.9, 0.1, 3), cf, COLORS.stripe)
	end
end

local function tree(parent: Instance, at: Vector3, random: Random)
	local h = random:NextNumber(10, 16)
	part(
		parent,
		Vector3.new(1.6, h, 1.6),
		CFrame.new(at + Vector3.new(0, h / 2, 0)),
		COLORS.trunk,
		Enum.Material.Wood
	)
	local r = random:NextNumber(10, 15)
	local ball = part(
		parent,
		Vector3.new(r, r, r),
		CFrame.new(at + Vector3.new(0, h + r * 0.3, 0)),
		COLORS.leaves
	)
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Grass
end

local function prop(folder: Instance, kind: string): Model
	local m = Instance.new("Model")
	m.Name = kind
	m:SetAttribute("Prop", kind)
	m.Parent = folder
	return m
end

local function billboard(parent: Instance, at: Vector3, out: Vector3, text: string, accent: Color3)
	for _, side in { -1, 1 } do
		local along = Vector3.new(-out.Z, 0, out.X)
		part(
			parent,
			Vector3.new(1.2, 13, 1.2),
			CFrame.new(at + along * side * 15 + Vector3.new(0, 6.5, 0)),
			COLORS.metal,
			Enum.Material.Metal
		)
	end
	local boardAt = at + Vector3.new(0, 19, 0)
	Places.sign(
		parent,
		Vector3.new(40, 13, 1),
		CFrame.lookAt(boardAt, boardAt + out),
		text,
		Color3.fromRGB(250, 250, 245),
		accent,
		true
	)
end

-- a buried terrain ball: a mound `height` tall covering a circle `radius` wide on the ground
local function mound(x: number, z: number, radius: number, height: number, material: Enum.Material)
	local r = (radius * radius / height + height) / 2
	workspace.Terrain:FillBall(Vector3.new(x, height - r, z), r, material)
end

local function spots(
	random: Random,
	centre: Vector3,
	halfX: number,
	halfZ: number,
	n: number,
	list: { Vector3 }
): { Vector3 }
	local out = {}
	for _ = 1, n do
		local p = centre
			+ Vector3.new(random:NextNumber(-halfX, halfX), 0.5, random:NextNumber(-halfZ, halfZ))
		table.insert(out, p)
		table.insert(list, p)
	end
	return out
end

function OutskirtsKit.build(ctx: Ctx): Result
	local static, buildings, props, random = ctx.static, ctx.buildings, ctx.props, ctx.random
	local walkPoints: { Vector3 } = {}
	local places: { Places.Place } = {}
	local terrain = workspace.Terrain
	terrain:Clear()
	terrain:SetMaterialColor(Enum.Material.Grass, COLORS.grass)
	terrain:SetMaterialColor(Enum.Material.Sand, COLORS.sand)
	terrain:SetMaterialColor(Enum.Material.Ground, rgb(C.dirt))
	terrain.WaterColor = rgb(C.water)
	terrain.WaterWaveSize = 0.08
	terrain.WaterTransparency = 0.5

	local R = ctx.road
	local half = ctx.half
	local RG = Cfg.Ring
	local ring = math.max(ctx.spanX, ctx.spanZ) / 2 + RG.Gap
	local RW = RG.Width
	local ringOuter = ring + RW / 2
	local zones = Rules.zones(ringOuter, Cfg.Stunt, Cfg.Port, Cfg.Desert, Cfg.Site)
	local seaEdge = zones.port.x - zones.port.w / 2

	-- the ground (the sea takes the west strip beyond the port's quay) and the invisible edge walls
	local landW = half - seaEdge
	part(
		static,
		Vector3.new(landW, 20, half * 2),
		CFrame.new(seaEdge + landW / 2, -10, 0),
		COLORS.grass,
		Enum.Material.Grass
	)
	for _, s in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		part(
			static,
			Vector3.new(if s[1] ~= 0 then 10 else half * 2, 80, if s[2] ~= 0 then 10 else half * 2),
			CFrame.new(s[1] * half, 30, s[2] * half),
			COLORS.concrete,
			nil,
			1
		)
	end
	local seaW = seaEdge + half
	local P = Cfg.Port
	terrain:FillBlock(
		CFrame.new(seaEdge - seaW / 2, -P.SeaDepth - 2, 0),
		Vector3.new(seaW, 4, half * 2),
		Enum.Material.Sand
	)
	terrain:FillBlock(
		CFrame.new(seaEdge - seaW / 2, -P.SeaDepth / 2 - 0.5, 0),
		Vector3.new(seaW, P.SeaDepth - 1, half * 2),
		Enum.Material.Water
	)

	-- highway ring, joined to every grid road, a double yellow down the middle
	for _, s in { 1, -1 } do
		part(
			static,
			Vector3.new(RW, 1, ring * 2 + RW),
			CFrame.new(s * ring, -0.4, 0),
			COLORS.road,
			Enum.Material.Asphalt
		)
		part(
			static,
			Vector3.new(ring * 2 + RW, 1, RW),
			CFrame.new(0, -0.38, s * ring),
			COLORS.road,
			Enum.Material.Asphalt
		)
		for _, o in { -0.55, 0.55 } do
			paint(
				static,
				Vector3.new(RG.CentreLine, Streets.PaintThick, ring * 2),
				CFrame.new(s * ring + o, Streets.PaintHeight, 0),
				COLORS.yellow
			)
			paint(
				static,
				Vector3.new(ring * 2, Streets.PaintThick, RG.CentreLine),
				CFrame.new(0, Streets.PaintHeight, s * ring + o),
				COLORS.yellow
			)
		end
	end
	local roadX, roadZ = {}, {}
	for i = 0, ctx.blocksX do
		local x = ctx.x0 + R / 2 + i * ctx.pitch
		table.insert(roadX, x)
		local len = ring - ctx.spanZ / 2
		for _, s in { 1, -1 } do
			part(
				static,
				Vector3.new(R, 1, len),
				CFrame.new(x, -0.4, s * (ctx.spanZ / 2 + len / 2)),
				COLORS.road,
				Enum.Material.Asphalt
			)
		end
	end
	for j = 0, ctx.blocksZ do
		local z = ctx.z0 + R / 2 + j * ctx.pitch
		table.insert(roadZ, z)
		local len = ring - ctx.spanX / 2
		for _, s in { 1, -1 } do
			part(
				static,
				Vector3.new(len, 1, R),
				CFrame.new(s * (ctx.spanX / 2 + len / 2), -0.38, z),
				COLORS.road,
				Enum.Material.Asphalt
			)
		end
	end
	-- connectors from the ring out to each zone, on the middle grid roads
	local connectors: { Rules.Rect } = {}
	for _, z in { zones.stunt, zones.port, zones.desert, zones.site } do
		local alongX = z.z == 0
		local near = if alongX then math.abs(z.x) - z.w / 2 else math.abs(z.z) - z.d / 2
		local len = near - ring + 20
		local mid = ring + len / 2
		local rect: Rules.Rect = if alongX
			then { x = math.sign(z.x) * mid, z = 0, w = len, d = RG.Connector }
			else { x = 0, z = math.sign(z.z) * mid, w = RG.Connector, d = len }
		table.insert(connectors, rect)
		part(
			static,
			Vector3.new(rect.w, 1, rect.d),
			CFrame.new(rect.x, -0.41, rect.z),
			COLORS.road,
			Enum.Material.Asphalt
		)
	end

	-- the cells between the city and the ring: a grass mound, a tree, a billboard facing the ring every other cell
	local RC = Cfg.RingCells
	local inner = ring - RW / 2
	local cellCount = 0
	local function cell(x: number, z: number, w: number, d: number, out: Vector3)
		cellCount += 1
		local f = math.min(w, d) * 0.2
		mound(x - out.X * d * 0.1, z - out.Z * d * 0.1, f, RC.MoundHeight, Enum.Material.Grass)
		for _ = 1, RC.Trees do
			tree(
				static,
				Vector3.new(
					x + random:NextNumber(-w, w) * 0.35,
					0,
					z + random:NextNumber(-d, d) * 0.35
				),
				random
			)
		end
		if cellCount % RC.BillboardEvery == 0 then
			local depth = math.abs(out.X) * w + math.abs(out.Z) * d
			local at = Vector3.new(x, 0, z) + out * (depth / 2 - 12)
			local accent = Streets.Districts.neon.accent
			local pick = Streets.Billboards[random:NextInteger(1, #Streets.Billboards)]
			billboard(
				static,
				at,
				out,
				pick,
				if cellCount % 4 == 0 then rgb(accent) else rgb(Streets.Districts.old.accent)
			)
		end
	end
	local bandX, bandZ = inner - ctx.spanX / 2, inner - ctx.spanZ / 2
	for i = 1, #roadX - 1 do
		local cx = (roadX[i] + roadX[i + 1]) / 2
		local w = roadX[i + 1] - roadX[i] - R
		for _, s in { 1, -1 } do
			cell(cx, s * (ctx.spanZ / 2 + bandZ / 2), w, bandZ, Vector3.new(0, 0, s))
		end
	end
	for j = 1, #roadZ - 1 do
		local cz = (roadZ[j] + roadZ[j + 1]) / 2
		local d = roadZ[j + 1] - roadZ[j] - R
		for _, s in { 1, -1 } do
			cell(s * (ctx.spanX / 2 + bandX / 2), cz, bandX, d, Vector3.new(s, 0, 0))
		end
	end

	-- stunt park (east): four lanes west to east, the bowl to the south, stands to the north
	do
		local S = Cfg.Stunt
		local st = zones.stunt
		local function at(x: number, z: number): Vector3
			return Vector3.new(st.x + x, 0, st.z + z)
		end
		local folder = Instance.new("Folder")
		folder.Name = "StuntPark"
		-- the park's ground, for StuntService (jumps over it pay double)
		folder:SetAttribute("Centre", Vector3.new(st.x, 0, st.z))
		folder:SetAttribute("Size", Vector3.new(st.w, 0, st.d))
		folder.Parent = static
		part(
			folder,
			Vector3.new(st.w, 1, st.d),
			CFrame.new(st.x, -0.42, st.z),
			COLORS.concrete,
			Enum.Material.Concrete
		)
		local function deck(x0: number, x1: number, z: number, width: number, color: Color3)
			paint(
				folder,
				Vector3.new(x1 - x0, 0.1, width),
				CFrame.new(at((x0 + x1) / 2, z) + Vector3.new(0, 0.12, 0)),
				color
			)
		end
		local E = Vector3.new(1, 0, 0)
		local hw = st.w / 2
		-- the gate and a chequered start line where the road comes in
		local gx = -hw + 20
		local cw = RG.Connector
		for _, side in { -1, 1 } do
			part(
				folder,
				Vector3.new(8, 40, 8),
				CFrame.new(at(gx, side * (cw / 2 + 8)) + Vector3.new(0, 20, 0)),
				rgb(C.deckRed)
			)
		end
		part(
			folder,
			Vector3.new(8, 8, cw + 24),
			CFrame.new(at(gx, 0) + Vector3.new(0, 44, 0)),
			rgb(C.deckRed)
		)
		local signAt = at(gx - 4.5, 0) + Vector3.new(0, 34, 0)
		Places.sign(
			folder,
			Vector3.new(cw - 4, 11, 1),
			CFrame.lookAt(signAt, signAt - E),
			"STUNT PARK",
			Color3.fromRGB(250, 250, 245),
			rgb(C.deckRed),
			true
		)
		local lineX = gx + 30
		paint(
			folder,
			Vector3.new(8, 0.1, cw),
			CFrame.new(at(lineX, 0) + Vector3.new(0, 0.13, 0)),
			COLORS.white
		)
		for row = 0, 1 do
			for k = 0, 4 do
				local z = -cw / 2 + (k * 2 + row + 0.5) * cw / 10
				paint(
					folder,
					Vector3.new(4, 0.1, cw / 10),
					CFrame.new(at(lineX - 2 + row * 4, z) + Vector3.new(0, 0.15, 0)),
					COLORS.stripe
				)
			end
		end

		-- lane 1: mega ramp, gap, landing, wall ride
		local mz = S.MegaZ
		deck(-hw + 30, hw - 10, mz, S.Mega.width + 20, rgb(C.deckRed))
		local mega =
			ramp(folder, at(S.Mega.foot, mz), E, S.Mega.width, S.Mega.height, S.Mega.length)
		stripes(mega, 4)
		local landing = ramp(
			folder,
			at(S.Landing.foot, mz),
			-E,
			S.Mega.width,
			S.Landing.height,
			S.Landing.length,
			COLORS.concrete
		)
		local landTop = S.Landing.foot - S.Landing.length
		ramp(
			folder,
			at(landTop - S.Landing.back, mz),
			E,
			S.Mega.width,
			S.Landing.height,
			S.Landing.back,
			COLORS.concrete
		)
		stripes(landing, 3)
		local wall = ramp(
			folder,
			at(S.WallRide.foot, mz),
			E,
			S.WallRide.width,
			S.WallRide.height,
			S.WallRide.length
		)
		stripes(wall, 2)

		-- lane 2: tabletops that grow
		local tz = S.TableZ
		deck(-hw + 30, hw - 60, tz, S.TableWidth + 20, rgb(C.deckBlue))
		for k = 0, S.Tables - 1 do
			local h, up = 6 + 3 * k, 20 + 5 * k
			local down = up * 1.4
			local x = -hw + 70 + k * S.TableSpacing
			stripes(ramp(folder, at(x, tz), E, S.TableWidth, h, up), 1)
			part(
				folder,
				Vector3.new(S.TableDeck, h, S.TableWidth),
				CFrame.new(at(x + up + S.TableDeck / 2, tz) + Vector3.new(0, h / 2, 0)),
				COLORS.ramp
			)
			ramp(
				folder,
				at(x + up + S.TableDeck + down, tz),
				-E,
				S.TableWidth,
				h,
				down,
				COLORS.concrete
			)
		end

		-- lane 3: kicker over smashable containers onto a landing, then dirt rollers and a dirt tabletop
		local jz, J = S.JumpZ, S.Jump
		deck(-hw + 30, J.landingFoot + 10, jz, 70, rgb(C.deckOrange))
		stripes(ramp(folder, at(J.foot, jz), E, 40, J.height, J.length), 2)
		local stack = Instance.new("Model")
		stack.Name = "Containers"
		for k = 0, J.containers - 1 do
			local cx = J.foot + J.length + 30 + k * 25
			part(
				stack,
				Vector3.new(16, 16, 56),
				CFrame.new(at(cx, jz) + Vector3.new(0, 8, 0)),
				CONTAINERS[k % #CONTAINERS + 1],
				Enum.Material.CorrodedMetal
			)
		end
		stack.Parent = buildings
		ramp(folder, at(J.landingFoot, jz), -E, 40, J.height + 2, 60, COLORS.concrete)
		for k = 0, S.Rollers - 1 do
			local p = at(S.RollerStart + k * S.RollerSpacing, jz)
			mound(p.X, p.Z, S.RollerRadius, S.RollerHeight, Enum.Material.Ground)
		end
		local top = at(S.RollerStart + S.Rollers * S.RollerSpacing + 60, jz)
		mound(top.X, top.Z, 45, 14, Enum.Material.Ground)

		-- the bowl: four quarter pipes, open corners to drive in
		local bc = at(0, S.BowlZ)
		paint(
			folder,
			Vector3.new(S.BowlHalf * 2, 0.1, S.BowlHalf * 2),
			CFrame.new(bc + Vector3.new(0, 0.12, 0)),
			rgb(C.bowl)
		)
		for _, d in { E, -E, Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
			local q =
				ramp(folder, bc + d * S.BowlHalf, d, S.BowlHalf * 1.45, S.BowlHeight, S.BowlLength)
			stripes(q, 1)
		end
		-- a zig-zag of dirt doubles in the corner between the gate and the bowl (terrain)
		for k = 0, S.DirtField - 1 do
			local p = at(-hw + 95 + (k % 2) * 50, S.JumpZ + 120 + k * 55)
			mound(p.X, p.Z, 18, 7, Enum.Material.Ground)
		end

		-- the north stands, light towers in the corners, flags down the sides
		local hd = st.d / 2
		local seat = { rgb(C.deckRed), rgb(C.deckBlue) }
		local watch: { Vector3 } = {}
		for k = 0, S.Stands - 1 do
			local sx = -150 + k * 260
			for step = 0, 2 do
				local h = 3 + step * 3
				part(
					folder,
					Vector3.new(120, h, 8),
					CFrame.new(at(sx, -hd + 30 - step * 8) + Vector3.new(0, h / 2, 0)),
					seat[k + 1]
				)
			end
			part(
				folder,
				Vector3.new(124, 1, 30),
				CFrame.new(at(sx, -hd + 22) + Vector3.new(0, 22, 0)),
				COLORS.white
			)
			for _, side in { -1, 1 } do
				part(
					folder,
					Vector3.new(1.5, 22, 1.5),
					CFrame.new(at(sx + side * 60, -hd + 10) + Vector3.new(0, 11, 0)),
					COLORS.metal,
					Enum.Material.Metal
				)
			end
			for _, p in
				spots(random, at(sx, -hd + 50), 55, 12, S.Spectators // S.Stands, walkPoints)
			do
				table.insert(watch, p)
			end
		end
		table.insert(places, Places.open("stunt", watch[1], watch))
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			local foot = at(c[1] * (hw - 15), c[2] * (hd - 15))
			part(
				folder,
				Vector3.new(2, 50, 2),
				CFrame.new(foot + Vector3.new(0, 25, 0)),
				COLORS.metal,
				Enum.Material.Metal
			)
			local head = part(
				folder,
				Vector3.new(10, 4, 2),
				CFrame.lookAt(foot + Vector3.new(0, 51, 0), at(0, 0) + Vector3.new(0, 51, 0)),
				COLORS.white,
				Enum.Material.Neon
			)
			head.CastShadow = false
		end
		local flagColours = { rgb(C.deckRed), rgb(C.deckBlue), rgb(C.deckOrange), COLORS.yellow }
		for k = 0, S.Flags - 1 do
			local side = if k % 2 == 0 then -1 else 1
			local z = -hd + 100 + (k // 2) * (st.d - 200) / math.max(1, S.Flags // 2 - 1)
			local foot = at(side * (hw - 6), z)
			if math.abs(z) > cw then
				post(folder, 18, 0.6, foot, COLORS.metal)
				part(
					folder,
					Vector3.new(0.2, 4, 7),
					CFrame.new(foot + Vector3.new(0, 16, 3.5)),
					flagColours[k % #flagColours + 1]
				)
			end
		end
		-- tyre stacks between the lanes: knock them flying
		local perRow = S.TyreStacks // 2
		for _, z in { (S.MegaZ + S.TableZ) / 2, (S.TableZ + S.JumpZ) / 2 } do
			for k = 0, perRow - 1 do
				local m = prop(props, "Tyres")
				post(m, 3.6, 4, at(-hw + 60 + k * (st.w - 100) / perRow, z), rgb(C.tyre))
			end
		end
	end

	-- container port (west): smashable stacks, gantry cranes on the quay, a moored ship, the sea beyond
	do
		local pt = zones.port
		part(
			static,
			Vector3.new(pt.w, 1, pt.d),
			CFrame.new(pt.x, -0.42, pt.z),
			COLORS.concrete,
			Enum.Material.Concrete
		)
		for row = 0, P.Rows - 1 do
			for col = 0, P.Cols - 1 do
				local stack = Instance.new("Model")
				stack.Name = "Containers"
				local base = Vector3.new(
					pt.x - pt.w / 2 + 150 + col * 150,
					0,
					pt.z - pt.d / 2 + 100 + row * (pt.d - 200) / (P.Rows - 1)
				)
				for h = 0, random:NextInteger(1, 3) do
					for k = 0, 1 do
						part(
							stack,
							Vector3.new(16, 16, 56),
							CFrame.new(base + Vector3.new(k * 18, 8 + h * 16.2, 0)),
							CONTAINERS[random:NextInteger(1, #CONTAINERS)],
							Enum.Material.CorrodedMetal
						)
					end
				end
				stack.Parent = buildings
			end
		end
		for _ = 1, 20 do
			table.insert(
				walkPoints,
				Vector3.new(
					pt.x + random:NextNumber(-pt.w / 2 + 60, pt.w / 2 - 20),
					0.5,
					pt.z + random:NextNumber(-pt.d / 2 + 20, pt.d / 2 - 20)
				)
			)
		end
		-- the quay: a low kerb, bollards, two gantry cranes reaching over the water
		local qx = seaEdge
		part(
			static,
			Vector3.new(2, 3, pt.d),
			CFrame.new(qx + 1, 1.5, pt.z),
			Color3.fromRGB(230, 200, 40),
			Enum.Material.Concrete
		)
		for k = 0, P.Bollards - 1 do
			post(
				static,
				2.4,
				1.6,
				Vector3.new(qx + 5, 0, pt.z - pt.d / 2 + (k + 0.5) * pt.d / P.Bollards),
				COLORS.stripe
			)
		end
		local craneCol = rgb(C.crane)
		for k = 0, P.Cranes - 1 do
			local cz = pt.z + (k - (P.Cranes - 1) / 2) * 320
			local crane = Instance.new("Model")
			crane.Name = "Crane"
			for _, lx in { 12, 52 } do
				for _, lz in { -14, 14 } do
					part(
						crane,
						Vector3.new(3, 56, 3),
						CFrame.new(qx + lx, 28, cz + lz),
						craneCol,
						Enum.Material.Metal
					)
				end
			end
			part(
				crane,
				Vector3.new(130, 5, 5),
				CFrame.new(qx + 10, 58, cz),
				craneCol,
				Enum.Material.Metal
			)
			part(crane, Vector3.new(8, 6, 10), CFrame.new(qx - 20, 53, cz), COLORS.white)
			part(crane, Vector3.new(0.5, 30, 0.5), CFrame.new(qx - 20, 35, cz), COLORS.stripe)
			crane.Parent = buildings
		end
		-- a cargo ship moored off the quay (you can jump onto its deck)
		local ship = Instance.new("Model")
		ship.Name = "Ship"
		local sx = qx - 34
		part(
			ship,
			Vector3.new(44, 16, 240),
			CFrame.new(sx, -3, pt.z),
			rgb(C.ship),
			Enum.Material.Metal
		)
		part(
			ship,
			Vector3.new(44, 1, 240),
			CFrame.new(sx, 5.5, pt.z),
			Color3.fromRGB(90, 96, 100),
			Enum.Material.Metal
		)
		part(ship, Vector3.new(36, 18, 26), CFrame.new(sx, 15, pt.z + 100), COLORS.white)
		part(ship, Vector3.new(8, 12, 8), CFrame.new(sx, 30, pt.z + 104), COLORS.stripe)
		for k = 0, 3 do
			part(
				ship,
				Vector3.new(16, 16, 56),
				CFrame.new(sx + (k % 2 - 0.5) * 18, 14, pt.z - 90 + (k // 2) * 60),
				CONTAINERS[k + 1],
				Enum.Material.CorrodedMetal
			)
		end
		ship.Parent = buildings
	end

	-- desert (south): sand, terrain dunes, sandstone mesas, cacti
	do
		local D = Cfg.Desert
		local ds = zones.desert
		part(
			static,
			Vector3.new(ds.w, 1, ds.d),
			CFrame.new(ds.x, -0.43, ds.z),
			COLORS.sand,
			Enum.Material.Sand
		)
		for _ = 1, D.Dunes do
			local f = random:NextNumber(D.DuneRadius[1], D.DuneRadius[2])
			local h = f * random:NextNumber(D.DuneSlope[1], D.DuneSlope[2]) / 100
			local x = ds.x + random:NextNumber(-ds.w / 2 + f, ds.w / 2 - f)
			local z = ds.z + random:NextNumber(-ds.d / 2 + f, ds.d / 2 - f)
			mound(x, z, f, h, Enum.Material.Sand)
		end
		for k = 0, D.Mesas - 1 do
			local side = if k % 2 == 0 then -1 else 1
			local x = ds.x + side * (ds.w / 2 - 70 - (k // 2) * 160)
			local z = ds.z + random:NextNumber(-ds.d / 4, ds.d / 4)
			local size = Vector3.new(
				random:NextNumber(60, 100),
				random:NextNumber(30, 50),
				random:NextNumber(60, 100)
			)
			terrain:FillBlock(
				CFrame.new(x, size.Y / 2 - 2, z)
					* CFrame.Angles(0, random:NextNumber(0, math.pi), 0),
				size,
				Enum.Material.Sandstone
			)
		end
		local green = rgb(C.cactus)
		for _ = 1, D.Cacti do
			local at = Vector3.new(
				ds.x + random:NextNumber(-ds.w / 2 + 30, ds.w / 2 - 30),
				0,
				ds.z + random:NextNumber(-ds.d / 2 + 30, ds.d / 2 - 30)
			)
			local m = prop(props, "Cactus")
			post(m, 14, 2.4, at, green)
			post(m, 5, 1.6, at + Vector3.new(2.6, 6, 0), green)
			post(m, 4, 1.6, at + Vector3.new(-2.6, 4, 0), green)
		end
	end

	-- construction site (north): hoarding with a gate toward town, steel frames, tower cranes, dirt piles
	do
		local SI = Cfg.Site
		local s = zones.site
		local function at(x: number, z: number): Vector3
			return Vector3.new(s.x + x, 0, s.z + z)
		end
		local hw, hd = s.w / 2, s.d / 2
		local folder = Instance.new("Folder")
		folder.Name = "Site"
		folder.Parent = static
		part(
			folder,
			Vector3.new(s.w, 1, s.d),
			CFrame.new(s.x, -0.42, s.z),
			rgb(C.sitePad),
			Enum.Material.Ground
		)
		local hoard = rgb(C.hoarding)
		local H = SI.HoardingHeight
		part(
			folder,
			Vector3.new(s.w, H, 1),
			CFrame.new(at(0, -hd) + Vector3.new(0, H / 2, 0)),
			hoard
		)
		for _, side in { -1, 1 } do
			part(
				folder,
				Vector3.new(1, H, s.d),
				CFrame.new(at(side * hw, 0) + Vector3.new(0, H / 2, 0)),
				hoard
			)
			local len = hw - SI.GateWidth / 2
			part(
				folder,
				Vector3.new(len, H, 1),
				CFrame.new(at(side * (SI.GateWidth / 2 + len / 2), hd) + Vector3.new(0, H / 2, 0)),
				hoard
			)
			local signAt = at(side * (SI.GateWidth / 2 + len / 2), hd + 0.6)
				+ Vector3.new(0, H / 2, 0)
			Places.sign(
				folder,
				Vector3.new(len * 0.6, H - 2, 0.2),
				CFrame.lookAt(signAt, signAt + Vector3.new(0, 0, 1)),
				if side < 0 then "MEGACORP TOWER" else "COMING SOON",
				hoard,
				COLORS.white
			)
		end
		local taken: { { number } } = {} -- x, z, radius of what stands on the site
		-- steel frames: corner columns, edge beams each floor, concrete slabs on the lower floors (all smashable)
		local FH = 14
		for k = 0, SI.Frames - 1 do
			local fx, fz = -240 + k * 220, -110 + (k % 2) * 90
			table.insert(taken, { fx, fz, SI.FrameSize })
			local frame = Instance.new("Model")
			frame.Name = "SteelFrame"
			local fh = SI.FrameSize / 2
			local steel = rgb(C.steel)
			local tall = SI.FrameFloors * FH
			for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
				part(
					frame,
					Vector3.new(2, tall, 2),
					CFrame.new(at(fx + c[1] * fh, fz + c[2] * fh) + Vector3.new(0, tall / 2, 0)),
					steel,
					Enum.Material.Metal
				)
			end
			for f = 1, SI.FrameFloors do
				local y = f * FH
				for _, side in { -1, 1 } do
					part(
						frame,
						Vector3.new(SI.FrameSize, 1.6, 1.6),
						CFrame.new(at(fx, fz + side * fh) + Vector3.new(0, y, 0)),
						steel,
						Enum.Material.Metal
					)
					part(
						frame,
						Vector3.new(1.6, 1.6, SI.FrameSize),
						CFrame.new(at(fx + side * fh, fz) + Vector3.new(0, y, 0)),
						steel,
						Enum.Material.Metal
					)
				end
				if f <= SI.FrameFloors // 2 then
					part(
						frame,
						Vector3.new(SI.FrameSize, 1, SI.FrameSize),
						CFrame.new(at(fx, fz) + Vector3.new(0, y - 1.3, 0)),
						COLORS.concrete,
						Enum.Material.Concrete
					)
				end
			end
			frame.Parent = buildings
		end
		-- tower cranes
		for k = 0, SI.Cranes - 1 do
			local cx, cz = -120 + k * 330, -220 + k * 260
			table.insert(taken, { cx, cz, 20 })
			local crane = Instance.new("Model")
			crane.Name = "TowerCrane"
			local col = rgb(C.crane)
			local foot = at(cx, cz)
			part(
				crane,
				Vector3.new(6, 120, 6),
				CFrame.new(foot + Vector3.new(0, 60, 0)),
				col,
				Enum.Material.DiamondPlate
			)
			local dir = if k == 0 then Vector3.new(1, 0, 0) else Vector3.new(-1, 0, 0)
			part(
				crane,
				Vector3.new(4, 4, 130),
				CFrame.lookAt(
					foot + dir * 50 + Vector3.new(0, 122, 0),
					foot + dir * 100 + Vector3.new(0, 122, 0)
				),
				col,
				Enum.Material.DiamondPlate
			)
			part(
				crane,
				Vector3.new(10, 10, 12),
				CFrame.new(foot - dir * 30 + Vector3.new(0, 116, 0)),
				COLORS.concrete,
				Enum.Material.Concrete
			)
			part(
				crane,
				Vector3.new(7, 7, 7),
				CFrame.new(foot + dir * 6 + Vector3.new(0, 116, 0)),
				COLORS.white
			)
			part(
				crane,
				Vector3.new(0.5, 50, 0.5),
				CFrame.new(foot + dir * 90 + Vector3.new(0, 95, 0)),
				COLORS.stripe
			)
			part(
				crane,
				Vector3.new(10, 4, 10),
				CFrame.new(foot + dir * 90 + Vector3.new(0, 68, 0)),
				Color3.fromRGB(150, 70, 50),
				Enum.Material.Brick
			)
			crane.Parent = buildings
		end
		-- site cabins by the gate, an excavator, pipe stacks
		for k = 0, SI.Cabins - 1 do
			local m = Instance.new("Model")
			m.Name = "Cabin"
			local c = at(hw - 60, hd - 60 - k * 32)
			table.insert(taken, { c.X - s.x, c.Z - s.z, 18 })
			part(m, Vector3.new(24, 9, 12), CFrame.new(c + Vector3.new(0, 4.5, 0)), COLORS.white)
			part(
				m,
				Vector3.new(14, 2.5, 0.2),
				CFrame.new(c + Vector3.new(0, 5.5, -6.1)),
				Color3.fromRGB(120, 170, 200),
				Enum.Material.Glass
			)
			part(m, Vector3.new(0.2, 7, 3.5), CFrame.new(c + Vector3.new(-12.1, 3.5, 0)), hoard)
			m.Parent = buildings
		end
		do
			local m = Instance.new("Model")
			m.Name = "Excavator"
			local c = at(120, 150)
			table.insert(taken, { 120, 150, 25 })
			local yellow = rgb(C.crane)
			for _, side in { -1, 1 } do
				part(
					m,
					Vector3.new(18, 3.5, 3.5),
					CFrame.new(c + Vector3.new(0, 1.75, side * 5)),
					COLORS.stripe
				)
			end
			part(m, Vector3.new(14, 4, 10), CFrame.new(c + Vector3.new(0, 5.5, 0)), yellow)
			part(m, Vector3.new(5, 6, 5), CFrame.new(c + Vector3.new(-2, 10.5, -2)), yellow)
			part(
				m,
				Vector3.new(16, 2, 2),
				CFrame.new(c + Vector3.new(11, 11, 0)) * CFrame.Angles(0, 0, math.rad(30)),
				yellow
			)
			part(
				m,
				Vector3.new(12, 1.6, 1.6),
				CFrame.new(c + Vector3.new(21, 9, 0)) * CFrame.Angles(0, 0, math.rad(-55)),
				yellow
			)
			part(m, Vector3.new(4, 3, 5), CFrame.new(c + Vector3.new(25, 3, 0)), COLORS.stripe)
			m.Parent = buildings
		end
		for k = 0, SI.PipeStacks - 1 do
			local m = Instance.new("Model")
			m.Name = "Pipes"
			local c = at(-300 + k * 60, hd - 50)
			table.insert(taken, { c.X - s.x, c.Z - s.z, 20 })
			for n = 0, 4 do
				local layer = if n < 3 then 0 else 1
				local x = if n < 3 then (n - 1) * 4.2 else (n - 3.5) * 4.2
				cylinder(
					m,
					30,
					4,
					CFrame.new(c + Vector3.new(x, 2 + layer * 3.6, 0))
						* CFrame.Angles(0, math.pi / 2, 0),
					Color3.fromRGB(110, 120, 130)
				)
			end
			m.Parent = buildings
		end
		local function free(x: number, z: number, r: number): boolean
			for _, t in taken do
				if (x - t[1]) ^ 2 + (z - t[2]) ^ 2 < (r + t[3]) ^ 2 then
					return false
				end
			end
			return math.abs(x) < hw - r and math.abs(z) < hd - r
		end
		-- dirt piles to jump (terrain), cones and pallets of bricks to knock over
		local piles = 0
		for _ = 1, SI.DirtPiles * 8 do
			if piles >= SI.DirtPiles then
				break
			end
			local f = random:NextNumber(22, 42)
			local x, z = random:NextNumber(-hw, hw), random:NextNumber(-hd, hd)
			if free(x, z, f) and math.abs(x) > SI.GateWidth then
				piles += 1
				table.insert(taken, { x, z, f })
				mound(s.x + x, s.z + z, f, f * random:NextNumber(0.3, 0.45), Enum.Material.Ground)
			end
		end
		local orange = rgb(C.cone)
		local placed = 0
		for _ = 1, SI.Cones * 8 do
			if placed >= SI.Cones then
				break
			end
			local x, z = random:NextNumber(-hw, hw), random:NextNumber(-hd, hd)
			if free(x, z, 3) then
				placed += 1
				local m = prop(props, "Cone")
				local p = at(x, z)
				part(m, Vector3.new(2.2, 0.3, 2.2), CFrame.new(p + Vector3.new(0, 0.15, 0)), orange)
				post(m, 2.4, 1.3, p + Vector3.new(0, 0.3, 0), orange)
			end
		end
		placed = 0
		for _ = 1, SI.Pallets * 8 do
			if placed >= SI.Pallets then
				break
			end
			local x, z = random:NextNumber(-hw, hw), random:NextNumber(-hd, hd)
			if free(x, z, 4) then
				placed += 1
				local m = prop(props, "Pallet")
				part(
					m,
					Vector3.new(4, 3, 4),
					CFrame.new(at(x, z) + Vector3.new(0, 1.5, 0)),
					Color3.fromRGB(170, 82, 60),
					Enum.Material.Brick
				)
			end
		end
		local crew = spots(random, at(0, 0), hw - 40, hd - 40, SI.Workers, walkPoints)
		table.insert(places, Places.open("park", at(0, hd - 10), crew))
	end

	-- terrain hills over everything the roads and zones leave empty
	local exclude: { Rules.Rect } = {
		{ x = 0, z = 0, w = ringOuter * 2, d = ringOuter * 2 },
		zones.stunt,
		zones.port,
		zones.desert,
		zones.site,
		{ x = seaEdge - seaW / 2, z = 0, w = seaW, d = half * 2 },
	}
	for _, c in connectors do
		table.insert(exclude, c)
	end
	local HC = Cfg.Hills
	local function rng(): number
		return random:NextNumber()
	end
	local hills = Rules.hills(half, exclude, HC, rng)
	for _, h in hills do
		terrain:FillBall(Vector3.new(h.x, -HC.Bury * h.r, h.z), h.r, Enum.Material.Grass)
		if random:NextNumber() < HC.RockChance then
			terrain:FillBall(
				Vector3.new(h.x, (1 - HC.Bury) * h.r - h.r * 0.15, h.z),
				h.r * 0.3,
				Enum.Material.Rock
			)
		end
	end

	-- the flat grass between the hills: groves, ponds with a sandy bank, boulders
	local W = Cfg.Wilds
	for _, g in
		Rules.clearSpots(half, exclude, hills, HC.Bury, W.Groves, W.GroveRadius, W.Margin, rng)
	do
		for _ = 1, random:NextInteger(W.GroveTrees[1], W.GroveTrees[2]) do
			local a, d = random:NextNumber(0, math.pi * 2), random:NextNumber(0, W.GroveRadius)
			tree(static, Vector3.new(g.x + math.cos(a) * d, 0, g.z + math.sin(a) * d), random)
		end
		table.insert(exclude, { x = g.x, z = g.z, w = W.GroveRadius * 2, d = W.GroveRadius * 2 })
	end
	for _, p in
		Rules.clearSpots(half, exclude, hills, HC.Bury, W.Ponds, W.PondRadius, W.Margin, rng)
	do
		-- two flat discs (the ground is a part, so terrain water can't sit below it): a sandy bank, the water
		local bank = post(static, 0.2, W.PondRadius * 2, Vector3.new(p.x, 0, p.z), COLORS.sand)
		bank.Material = Enum.Material.Sand
		local water =
			post(static, 0.3, W.PondRadius * 2 - 14, Vector3.new(p.x, 0, p.z), rgb(C.water))
		water.Material = Enum.Material.Glass
		water.Transparency = 0.15
		water.Reflectance = 0.15
		table.insert(exclude, { x = p.x, z = p.z, w = W.PondRadius * 2, d = W.PondRadius * 2 })
	end
	for _, b in
		Rules.clearSpots(half, exclude, hills, HC.Bury, W.Boulders, W.BoulderRadius, W.Margin, rng)
	do
		local r = random:NextNumber(0.5, 1) * W.BoulderRadius
		terrain:FillBall(Vector3.new(b.x, -r * 0.3, b.z), r, Enum.Material.Rock)
	end

	return { walkPoints = walkPoints, places = places }
end

return OutskirtsKit
