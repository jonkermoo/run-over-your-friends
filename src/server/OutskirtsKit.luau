--!strict
-- The world outside the city grid, from Config/Outskirts: the ground and the sea, the highway ring and its
-- connectors, the cells between the city and the ring, the stunt park (east), the container port (west), the
-- desert (south), the construction site (north), and groves and ponds on the flat grass the zones leave empty.
-- Terrain costs no parts, so dunes, dirt jumps and the sea are terrain; what you smash is parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Outskirts)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local LandCfg = require(ReplicatedStorage.Shared.Config.Land)
local Land = require(ReplicatedStorage.Shared.Rules.Land)
local Rules = require(ReplicatedStorage.Shared.Rules.Outskirts)
local Streets = require(ReplicatedStorage.Shared.Config.Streets)
local Tiles = require(ReplicatedStorage.Shared.Rules.Tiles)
local CountryKit = require(script.Parent.CountryKit)
local Country = require(ReplicatedStorage.Shared.Config.Country)
local Roadside = require(ReplicatedStorage.Shared.Config.Roadside)
local Greenery = require(script.Parent.Greenery)
local WildsKit = require(script.Parent.WildsKit)
local GroundKit = require(script.Parent.GroundKit)
local RoadsideKit = require(script.Parent.RoadsideKit)
local FoliageKit = require(script.Parent.FoliageKit)
local ZoneKit = require(script.Parent.ZoneKit)
local SuburbKit = require(script.Parent.SuburbKit)
local Pace = require(script.Parent.Pace)
local Places = require(script.Parent.Places)
local RampKit = require(script.Parent.RampKit)
local Terra = require(script.Parent.Terra)

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
export type Result = {
	walkPoints: { Vector3 },
	places: { Places.Place },
	spawnPoints: { Vector3 },
	seaEdge: number, -- the straight west coast's x (the port's quay)
	lamp: Vector3?, -- the lighthouse lamp's middle
}

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
	white = Color3.fromRGB(240, 240, 236),
	yellow = Color3.fromRGB(242, 206, 70),
	metal = Color3.fromRGB(70, 74, 80),
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
-- a shipping container: one painted box (length along its frame's Z) dressed with overlays that let its colour
-- show through (tools/port/container_textures.py): corrugated walls and roof, a frame with corner posts and
-- castings on the long sides, and doors with lock bars on its back end
local function container(parent: Instance, size: Vector3, cf: CFrame, colour: Color3): Part
	local K = Cfg.Container
	local box = Instance.new("Part")
	box.Anchored = true
	box.Size = size
	box.CFrame = cf
	box.Color = colour
	box.Material = Enum.Material.SmoothPlastic
	box.TopSurface = Enum.SurfaceType.Smooth
	box.BottomSurface = Enum.SurfaceType.Smooth
	local function overlay(face: Enum.NormalId, id: number, u: number, v: number)
		if id == 0 then
			return
		end
		local t = Instance.new("Texture")
		t.Face = face
		t.Texture = `rbxassetid://{id}`
		t.StudsPerTileU = u
		t.StudsPerTileV = v
		t.Parent = box
	end
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		overlay(face, K.Ribs, K.RibStuds * 2, size.Y)
		overlay(face, K.Frame, size.Z, size.Y)
	end
	overlay(Enum.NormalId.Front, K.Ribs, K.RibStuds * 2, size.Y)
	overlay(Enum.NormalId.Back, K.Door, size.X, size.Y)
	overlay(Enum.NormalId.Top, K.Ribs, K.RibStuds * 2, size.Z)
	box.Parent = parent
	return box
end

local function containerColour(random: Random): Color3
	return rgb(Cfg.Container.Colours[random:NextInteger(1, #Cfg.Container.Colours)])
end

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
		true,
		"Ad_" .. text
	)
end

-- a buried terrain ball: a mound `height` tall covering a circle `radius` wide on the ground
local function mound(x: number, z: number, radius: number, height: number, material: Enum.Material)
	local r = (radius * radius / height + height) / 2
	Terra.terrain:FillBall(Vector3.new(x, height - r, z), r, material)
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
	local terrain = Terra.terrain
	terrain:Clear()
	-- terrain grass draws lighter than the ground part's Grass, so it gets a darker tint to blend in
	workspace.Terrain:SetMaterialColor(Enum.Material.Grass, rgb(Country.TerrainGrass))
	-- terrain Asphalt lies only under the suburb road meshes (what cars drive on there); grass-coloured, so far
	-- terrain detail, which spreads it past the road's edge, still reads as grass
	workspace.Terrain:SetMaterialColor(Enum.Material.Asphalt, rgb(Country.TerrainGrass))
	workspace.Terrain:SetMaterialColor(Enum.Material.LeafyGrass, rgb(Country.TerrainLeafy))
	workspace.Terrain:SetMaterialColor(Enum.Material.Rock, rgb(Country.TerrainRock))
	workspace.Terrain:SetMaterialColor(Enum.Material.Sand, rgb(Cfg.Desert.TerrainSand))
	workspace.Terrain:SetMaterialColor(Enum.Material.Ground, rgb(C.dirt))
	GroundKit.tint() -- the farm's soil and crops
	terrain.WaterColor = rgb(C.water)
	terrain.WaterWaveSize = LandCfg.WaterWave
	terrain.WaterWaveSpeed = LandCfg.WaterWaveSpeed
	terrain.WaterTransparency = LandCfg.WaterClear

	local R = ctx.road
	local half = ctx.half
	local RG = Cfg.Ring
	local ring = math.max(ctx.spanX, ctx.spanZ) / 2 + RG.Gap
	local RW = RG.Width
	local ringOuter = ring + RW / 2
	local zones = Rules.zones(ringOuter, Cfg.Stunt, Cfg.Port, Cfg.Desert, Cfg.Site)
	local seaEdge = zones.port.x - zones.port.w / 2

	-- the ground is terrain, so hills, sand and dirt blend into it: land (sand along the curved coast), the sea
	-- west of the coast, filled in rows of square cells; then the invisible walls round the island (Config/Land)
	local L = LandCfg
	local P = Cfg.Port
	local tile = L.Cell
	local spread = 0
	for _, w in L.Waves do
		spread += math.abs(w.amp)
	end
	local reach = L.Radius + spread
	local fill = math.ceil((reach + L.Overrun) / tile) * tile
	local seaFar = L.SeaReach + 2800 -- the sea runs on to the horizon past the walls
	local edgeAt: { number } = {}
	local EDGE_STEPS = 4096
	for i = 0, EDGE_STEPS do
		edgeAt[i] = Land.edge(L, i / EDGE_STEPS * math.pi * 2)
	end
	local function insetAt(x: number, z: number): number
		local a = math.atan2(z, x)
		if a < 0 then
			a += math.pi * 2
		end
		return edgeAt[math.floor(a / (math.pi * 2) * EDGE_STEPS + 0.5)] - math.sqrt(x * x + z * z)
	end
	local SAND, GRASS = Enum.Material.Sand, Enum.Material.Grass
	-- the beaches north and south of the port (CountryKit puts the umbrellas, tower and pier on them): terrain
	-- sand whose inland edge wanders and which narrows at its ends, so it melts into the grass
	local BEACH = Country.Beach
	local port = zones.port
	local function beachWidth(zc: number): number
		local off = math.abs(zc - port.z) - (port.d / 2 + BEACH.Gap)
		local toEnd = half - math.abs(zc)
		if off <= 0 or toEnd < 0 then
			return 0
		end
		local w = BEACH.Width
		for _, wave in L.BeachWaves do
			w += wave.amp * math.sin(zc / wave.k * math.pi * 2 + wave.phase)
		end
		local t = math.clamp(math.min(off, toEnd) / L.BeachTaper, 0, 1)
		return w * t * t * (3 - 2 * t)
	end
	-- the sea bed's top `d` studs off the coast: a gentle sand shelf, then a slope to the deep (Config/Land);
	-- the port's quay drops straight to the port's depth
	local function smooth(t: number): number
		t = math.clamp(t, 0, 1)
		return t * t * (3 - 2 * t)
	end
	local function bedAt(d: number, quay: boolean): number
		local shelf = if quay then 0 else L.Shelf
		if d < shelf then
			return L.ShelfTop + (-P.SeaDepth - L.ShelfTop) * smooth(d / shelf)
		end
		return -P.SeaDepth + (P.SeaDepth - L.DeepDepth) * smooth((d - shelf) / (L.DeepFrom - shelf))
	end
	for z = -fill, fill - tile, tile do
		local zc = z + tile / 2
		Pace.step() -- the fill is long: yield now and then so the build doesn't time out
		local coastX = Land.coast(L, seaEdge, zc)
		local quay = math.abs(zc - port.z) < port.d / 2
		local runFrom, runKind = 0, nil :: Enum.Material?
		local function flush(xTo: number)
			if not runKind then
				return
			end
			local len = xTo - runFrom
			terrain:FillBlock(
				CFrame.new(runFrom + len / 2, -L.GroundDepth / 2 - L.GroundSink, zc),
				Vector3.new(len, L.GroundDepth, tile),
				runKind
			)
		end
		local seaFrom, seaTo = math.huge, -math.huge
		for x = -fill, fill, tile do
			local kind: Enum.Material? = nil
			if x < fill then
				local xc = x + tile / 2
				if xc > coastX and insetAt(xc, zc) > -L.Overrun then
					kind = GRASS
				elseif xc <= coastX and xc > coastX - seaFar then
					seaFrom, seaTo = math.min(seaFrom, x), math.max(seaTo, x + tile)
				end
			end
			if kind ~= runKind then
				flush(x)
				runFrom, runKind = x, kind
			end
		end
		if seaTo > seaFrom then
			-- the deep sea over the whole row, on a sand floor; then the shelf and slope near the coast, column
			-- by column (terrain draws its surface about 2 studs above a filled block's top, as on land)
			local len = seaTo - seaFrom
			terrain:FillBlock(
				CFrame.new(seaFrom + len / 2, -L.DeepDepth / 2 - 0.5, zc),
				Vector3.new(len, L.DeepDepth - 1, tile),
				Enum.Material.Water
			)
			terrain:FillBlock(
				CFrame.new(seaFrom + len / 2, -L.DeepDepth - 2, zc),
				Vector3.new(len, 4, tile),
				SAND
			)
			local floor = -L.DeepDepth
			local x = seaTo - tile
			while x >= seaFrom and coastX - (x + tile / 2) < L.DeepFrom do
				local top = bedAt(coastX - (x + tile / 2), quay) - 2
				if top > floor then
					terrain:FillBlock(
						CFrame.new(x + tile / 2, (floor + top) / 2, zc),
						Vector3.new(tile, top - floor, tile),
						SAND
					)
				end
				x -= tile
			end
		end
	end
	-- the sand along the coast (the beaches, and a strip everywhere else but the port), painted over the grass in
	-- 4-stud rows, so its inland edge is smooth rather than stepped in whole cells
	for z = -fill, fill - 4, 4 do
		Pace.step()
		local zc = z + 2
		local width = math.max(beachWidth(zc), L.Shore)
		if math.abs(zc - port.z) > port.d / 2 + 10 then
			local coastX = Land.coast(L, seaEdge, zc)
			local region = Region3.new(
				Vector3.new(coastX - 8, -L.GroundDepth - 8, z),
				Vector3.new(coastX + width, 4, z + 4)
			):ExpandToGrid(4)
			terrain:ReplaceMaterial(region, 4, GRASS, SAND)
		end
	end
	local outline = Land.outline(L, seaEdge, L.WallSegments)
	for i, a in outline do
		local b = outline[i % #outline + 1]
		local pa, pb = Vector3.new(a.x, 30, a.z), Vector3.new(b.x, 30, b.z)
		part(
			static,
			Vector3.new(10, 80, (pb - pa).Magnitude + 10),
			CFrame.lookAt((pa + pb) / 2, pb),
			COLORS.concrete,
			nil,
			1
		)
	end

	-- highway ring, joined to every grid road: the road you see is the road meshes (RoadKit); these invisible
	-- parts are what cars drive on, every top at 0.10
	for _, s in { 1, -1 } do
		part(
			static,
			Vector3.new(RW, 1, ring * 2 + RW),
			CFrame.new(s * ring, -0.4, 0),
			COLORS.road,
			Enum.Material.Asphalt,
			1
		)
		part(
			static,
			Vector3.new(ring * 2 + RW, 1, RW),
			CFrame.new(0, -0.4, s * ring),
			COLORS.road,
			Enum.Material.Asphalt,
			1
		)
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
				Enum.Material.Asphalt,
				1
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
				CFrame.new(s * (ctx.spanX / 2 + len / 2), -0.4, z),
				COLORS.road,
				Enum.Material.Asphalt,
				1
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
			CFrame.new(rect.x, -0.4, rect.z),
			COLORS.road,
			Enum.Material.Asphalt,
			1
		)
		-- split-rail fences down both sides, a pole line with wires down one (RoadsideKit)
		local along = if alongX
			then Vector3.new(math.sign(z.x), 0, 0)
			else Vector3.new(0, 0, math.sign(z.z))
		local across = Vector3.new(-along.Z, 0, along.X)
		local halfRoad = RG.Connector / 2
		local from = along * ring
		local to = along * (ring + len)
		local RF = Roadside.Fence
		for _, s in { -1, 1 } do
			local off = across * s * (halfRoad + RF.Out)
			RoadsideKit.fence(
				static,
				from + along * RF.EndGap + off,
				to - along * RF.EndGap + off,
				function()
					return false
				end
			)
		end
		local poleOff = across * (halfRoad + Roadside.Poles.RoadOut)
		RoadsideKit.poles(
			static,
			{ from + along * RF.EndGap + poleOff, to - along * RF.EndGap + poleOff },
			function()
				return false
			end
		)
	end

	-- the cells between the city and the ring: trees, and a billboard facing the ring every other cell
	local RC = Cfg.RingCells
	local inner = ring - RW / 2
	local cellCount = 0
	local country: CountryKit.Ctx = {
		static = static,
		buildings = buildings,
		props = props,
		random = random,
		half = half,
		reach = reach,
		-- open ground: inside the edge's fill band and east of the coast (by r)
		allowed = function(x: number, z: number, r: number): boolean
			return insetAt(x, z) >= L.FillBand + r and x >= Land.coast(L, seaEdge, z) + r
		end,
		seaEdge = seaEdge,
		port = zones.port,
		desert = zones.desert,
		connectors = connectors,
	}
	local uses = Country.Cells.Uses
	local function cell(x: number, z: number, w: number, d: number, out: Vector3)
		cellCount += 1
		-- gas stations only where a billboard isn't (they'd stand in each other's way)
		local use = uses[(cellCount - 1) % #uses + 1]
		if use == "gas" and cellCount % RC.BillboardEvery == 0 then
			use = "trees"
		end
		CountryKit.cell(country, use, x, z, w, d, out)
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

	-- the four corner cells, where the band turns
	for _, sx in { 1, -1 } do
		for _, sz in { 1, -1 } do
			CountryKit.corner(
				country,
				sx * (ctx.spanX / 2 + bandX / 2),
				sz * (ctx.spanZ / 2 + bandZ / 2),
				math.min(bandX, bandZ)
			)
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
			rgb(Zones.Stunt.Ground),
			Enum.Material.Asphalt
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
			true,
			"StuntPark"
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
		RampKit.dress(mega)
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
			RampKit.dress(ramp(folder, at(x, tz), E, S.TableWidth, h, up))
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
		RampKit.dress(ramp(folder, at(J.foot, jz), E, 40, J.height, J.length))
		local stack = Instance.new("Model")
		stack.Name = "Containers"
		for k = 0, J.containers - 1 do
			local js = Cfg.Container.JumpSize
			local cx = J.foot + J.length + 30 + k * (js[1] + J.containerGap)
			container(
				stack,
				Vector3.new(js[1], js[2], js[3]),
				CFrame.new(at(cx, jz) + Vector3.new(0, js[2] / 2, 0)),
				rgb(Cfg.Container.Colours[k % #Cfg.Container.Colours + 1])
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
			rgb(P.Dock),
			Enum.Material.Concrete
		)
		-- painted lanes between the stack rows: a yellow line down each side of every aisle
		local lane = rgb(P.LaneColour)
		for row = 0, P.Rows - 2 do
			local z = pt.z - pt.d / 2 + 100 + (row + 0.5) * (pt.d - 200) / (P.Rows - 1)
			for _, e in { -1, 1 } do
				paint(
					static,
					Vector3.new(pt.w - 120, 0.1, 0.8),
					CFrame.new(pt.x + 40, 0.1, z + e * 30),
					lane
				)
			end
		end
		for row = 0, P.Rows - 1 do
			for col = 0, P.Cols - 1 do
				local stack = Instance.new("Model")
				stack.Name = "Containers"
				local base = Vector3.new(
					pt.x - pt.w / 2 + 150 + col * 150,
					0,
					pt.z - pt.d / 2 + 100 + row * (pt.d - 200) / (P.Rows - 1)
				)
				local K = Cfg.Container
				local size = Vector3.new(K.Size[1], K.Size[2], K.Size[3])
				for h = 0, random:NextInteger(1, 3) do
					for k = 0, 1 do
						-- doors face either end, at random
						local turn = if random:NextNumber() < 0.5 then 0 else math.pi
						container(
							stack,
							size,
							CFrame.new(
								base
									+ Vector3.new(
										k * (size.X + K.Gap),
										size.Y / 2 + h * (size.Y + 0.2),
										0
									)
							) * CFrame.Angles(0, turn, 0),
							containerColour(random)
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
		-- (the bollards, lifebuoys and floodlights are laid with the other zone dressing: ZoneKit)
		-- black tyre fenders hung on the quay's face
		for k = 0, P.Fenders - 1 do
			local f = part(
				static,
				Vector3.new(2, 5, 5),
				CFrame.new(qx - 0.6, -1.5, pt.z - pt.d / 2 + (k + 0.5) * pt.d / P.Fenders),
				rgb(C.tyre)
			)
			f.Shape = Enum.PartType.Cylinder
		end
		local craneCol = rgb(C.crane)
		local dark = Color3.fromRGB(34, 36, 40)
		-- a beam between two points, `t` thick
		local function beam(
			parent: Instance,
			p1: Vector3,
			p2: Vector3,
			t: number,
			colour: Color3
		): Part
			return part(
				parent,
				Vector3.new(t, t, (p2 - p1).Magnitude),
				CFrame.lookAt((p1 + p2) / 2, p2),
				colour,
				Enum.Material.Metal
			)
		end
		local K = Cfg.Container
		for k = 0, P.Cranes - 1 do
			local cz = pt.z + (k - (P.Cranes - 1) / 2) * 320
			local crane = Instance.new("Model")
			crane.Name = "Crane"
			local legX, legZ, topY = { 12, 52 }, { -14, 14 }, 56
			local function at3(x: number, y: number, z: number): Vector3
				return Vector3.new(qx + x, y, cz + z)
			end
			-- four legs on wheeled bogies, hazard bands at their feet
			for _, lx in legX do
				for _, lz in legZ do
					part(
						crane,
						Vector3.new(3, topY, 3),
						CFrame.new(at3(lx, topY / 2, lz)),
						craneCol,
						Enum.Material.Metal
					)
					part(
						crane,
						Vector3.new(4.4, 2.4, 7),
						CFrame.new(at3(lx, 1.2, lz)),
						dark,
						Enum.Material.Metal
					)
					part(crane, Vector3.new(3.2, 1.2, 3.2), CFrame.new(at3(lx, 4, lz)), dark)
				end
			end
			-- cross-bracing: an X and a sill beam in each side frame, portal beams across the top
			for _, lz in legZ do
				beam(crane, at3(legX[1], 8, lz), at3(legX[2], topY - 4, lz), 1.4, craneCol)
				beam(crane, at3(legX[1], topY - 4, lz), at3(legX[2], 8, lz), 1.4, craneCol)
				beam(crane, at3(legX[1], 28, lz), at3(legX[2], 28, lz), 2, craneCol)
			end
			for _, lx in legX do
				beam(
					crane,
					at3(lx, topY - 1, legZ[1] - 1.5),
					at3(lx, topY - 1, legZ[2] + 1.5),
					3,
					craneCol
				)
				beam(crane, at3(lx, 30, legZ[1]), at3(lx, 30, legZ[2]), 2, craneCol)
			end
			-- the boom: two girders out over the water, a lattice between them, a machine house at the back
			local boomFrom, boomTo, by = 70, -60, topY + 3
			for _, gz in { -3.5, 3.5 } do
				beam(crane, at3(boomFrom, by, gz), at3(boomTo, by, gz), 2.4, craneCol)
				beam(crane, at3(boomFrom - 6, by + 8, gz), at3(10, by + 8, gz), 1.2, craneCol)
			end
			for kk = 0, 5 do
				local x = boomFrom - 6 - kk * 11
				beam(crane, at3(x, by, -3.5), at3(x - 6, by + 8, -3.5), 0.8, craneCol)
				beam(crane, at3(x, by, 3.5), at3(x - 6, by + 8, 3.5), 0.8, craneCol)
			end
			part(
				crane,
				Vector3.new(16, 9, 12),
				CFrame.new(at3(boomFrom - 6, by + 5.5, 0)),
				COLORS.white
			)
			part(
				crane,
				Vector3.new(16.4, 1.2, 12.4),
				CFrame.new(at3(boomFrom - 6, by + 10.4, 0)),
				craneCol
			)
			-- the driver's cab under the boom, with a dark window band
			part(crane, Vector3.new(8, 6, 8), CFrame.new(at3(-4, by - 5, 6)), COLORS.white)
			part(
				crane,
				Vector3.new(8.2, 2.4, 8.2),
				CFrame.new(at3(-4, by - 4.4, 6)),
				dark,
				Enum.Material.Glass
			)
			-- the trolley over the water, its cables and a spreader holding a container
			local tx = -32 + k * 14
			part(
				crane,
				Vector3.new(10, 3, 10),
				CFrame.new(at3(tx, by - 2.6, 0)),
				dark,
				Enum.Material.Metal
			)
			local hang = 22 + k * 8
			for _, cz2 in { -3, 3 } do
				part(
					crane,
					Vector3.new(0.3, hang, 0.3),
					CFrame.new(at3(tx, by - 4 - hang / 2, cz2)),
					dark
				)
			end
			local sy = by - 4 - hang
			part(
				crane,
				Vector3.new(K.Size[1] + 1, 1.4, K.Size[3] * 0.9),
				CFrame.new(at3(tx, sy, 0)) * CFrame.Angles(0, math.pi / 2, 0),
				craneCol,
				Enum.Material.Metal
			)
			container(
				crane,
				Vector3.new(K.Size[1], K.Size[2], K.Size[3]),
				CFrame.new(at3(tx, sy - 0.7 - K.Size[2] / 2, 0)) * CFrame.Angles(0, math.pi / 2, 0),
				containerColour(random)
			)
			crane.Parent = buildings
		end
		-- tall ship-to-shore cranes along the quay (static scenery, the port's skyline from afar): four legs with
		-- portal beams, a boom reaching out over the water and back over the yard, an A-frame with two stays, a cab
		local ST = P.Sts
		-- always on every client (like the far stand-ins), so they stand on the skyline from the city too
		local cranes = Instance.new("Model")
		cranes.Name = "PortCranes"
		cranes.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		for k, oz in ST.At do
			local colour = rgb(ST.Colours[(k - 1) % #ST.Colours + 1])
			local lx, cz, H = qx + ST.Inland, pt.z + oz, ST.Height
			local hs, hd = ST.Span / 2, ST.Depth / 2
			for _, dx in { -hs, hs } do
				for _, dz in { -hd, hd } do
					part(
						cranes,
						Vector3.new(ST.Leg, H, ST.Leg),
						CFrame.new(lx + dx, H / 2, cz + dz),
						colour
					)
				end
				part(
					cranes,
					Vector3.new(ST.Leg + 1, 5, ST.Depth + ST.Leg),
					CFrame.new(lx + dx, H - ST.Tie, cz),
					colour
				).CanCollide =
					false
			end
			for _, dz in { -hd, hd } do
				part(
					cranes,
					Vector3.new(ST.Span + ST.Leg, 6, ST.Leg + 1),
					CFrame.new(lx, H, cz + dz),
					colour
				)
			end
			local back = ST.Boom - ST.Reach
			local boomY = H + 6
			part(
				cranes,
				Vector3.new(ST.Boom, 5, 8),
				CFrame.new(lx + (back - ST.Reach) / 2, boomY, cz),
				colour
			).CanCollide =
				false
			local apex = Vector3.new(lx + hs, boomY + ST.Frame, cz)
			part(
				cranes,
				Vector3.new(4, ST.Frame, 4),
				CFrame.new(apex - Vector3.new(0, ST.Frame / 2, 0)),
				colour
			).CanCollide =
				false
			beam(cranes, apex, Vector3.new(lx - ST.Reach * 0.6, boomY + 2, cz), 2, colour).CanCollide =
				false
			beam(cranes, apex, Vector3.new(lx + back, boomY + 2, cz), 2, colour).CanCollide = false
			part(cranes, Vector3.new(10, 8, 10), CFrame.new(lx - hs, boomY - 8, cz), COLORS.white).CanCollide =
				false
		end
		cranes.Parent = static
		-- stacks of mixed heights along the yard's north and south edges (static, so the smashable stacks and
		-- their pay stay as they were): the yard's skyline is uneven instead of one flat grid
		local ES = P.EdgeStacks
		local edgeRandom = Random.new(ES.Seed)
		local ek = Cfg.Container
		local size = Vector3.new(ek.Size[1], ek.Size[2], ek.Size[3])
		for _, side in { -1, 1 } do
			local z = pt.z + side * (pt.d / 2 - ES.Inset)
			local x = pt.x - pt.w / 2 + ES.From
			while x + size.Z <= pt.x + pt.w / 2 - ES.To do
				for h = 0, edgeRandom:NextInteger(ES.Heights[1], ES.Heights[2]) - 1 do
					-- turned to lie along x, doors at either end
					local turn = if edgeRandom:NextNumber() < 0.5 then math.pi / 2 else -math.pi / 2
					container(
						static,
						size,
						CFrame.new(x + size.Z / 2, size.Y / 2 + h * (size.Y + 0.2), z)
							* CFrame.Angles(0, turn, 0),
						containerColour(edgeRandom)
					)
				end
				x += size.Z + ES.Gap
			end
		end
		-- a cargo ship moored off the quay (you can jump onto its deck): a two-tone hull with a pointed bow, a
		-- deck stacked with containers, a bridge tower with windows and wings at the stern, a funnel, rails and
		-- lifeboats. The bow points along -z.
		local ship = Instance.new("Model")
		ship.Name = "Ship"
		local SH = P.Ship
		local sx = qx - 34
		local hw, len, bowLen = SH.Width / 2, SH.Length, SH.Bow
		local z0 = pt.z - len / 2 + bowLen -- where the bow starts to narrow
		local z1 = pt.z + len / 2 -- the stern
		local hullMid = (z0 + z1) / 2
		local lowCol, topCol = rgb(C.ship), rgb(SH.Topsides)
		local deckCol = Color3.fromRGB(96, 104, 100)
		local function hull(y0: number, y1: number, colour: Color3)
			part(
				ship,
				Vector3.new(SH.Width, y1 - y0, z1 - z0),
				CFrame.new(sx, (y0 + y1) / 2, hullMid),
				colour,
				Enum.Material.Metal
			)
			for _, e in { -1, 1 } do
				local wg = Instance.new("WedgePart")
				wg.Anchored = true
				wg.Size = Vector3.new(y1 - y0, hw, bowLen)
				-- the right angle sits at the bow's base on the centre line: local Y runs out to the side, local -Z
				-- runs to the tip, local X is up
				wg.CFrame = CFrame.fromMatrix(
					Vector3.new(sx + e * hw / 2, (y0 + y1) / 2, z0 - bowLen / 2),
					Vector3.new(0, -e, 0),
					Vector3.new(e, 0, 0),
					Vector3.new(0, 0, 1)
				)
				wg.Color = colour
				wg.Material = Enum.Material.Metal
				wg.Parent = ship
			end
		end
		hull(SH.Keel, -1, lowCol)
		hull(-1, SH.Deck, topCol)
		hull(SH.Deck, SH.Deck + 0.4, deckCol)
		-- a white band along the waterline
		for _, e in { -1, 1 } do
			part(
				ship,
				Vector3.new(0.3, 0.8, z1 - z0),
				CFrame.new(sx + e * (hw + 0.1), -0.6, hullMid),
				COLORS.white
			)
		end
		-- rails along the deck edges
		for _, e in { -1, 1 } do
			for _, y in { 2, 3.6 } do
				part(
					ship,
					Vector3.new(0.3, 0.3, z1 - z0 - 4),
					CFrame.new(sx + e * (hw - 0.4), SH.Deck + y, hullMid),
					COLORS.white
				)
			end
		end
		-- containers on deck, two abreast, two rows, stacked
		local cs = Vector3.new(K.Size[1], K.Size[2], K.Size[3])
		for row = 0, 1 do
			for col = -1, 1, 2 do
				local cz = z0 + 4 + cs.Z / 2 + row * (cs.Z + 4)
				for h = 0, random:NextInteger(1, 2) do
					container(
						ship,
						cs,
						CFrame.new(
							sx + col * (cs.X / 2 + 1),
							SH.Deck + 0.4 + cs.Y / 2 + h * (cs.Y + 0.2),
							cz
						),
						containerColour(random)
					)
				end
			end
		end
		-- the bridge tower at the stern: two white tiers, a dark window band, wings, a mast
		local bz = z1 - 18
		local by0 = SH.Deck + 0.4
		part(ship, Vector3.new(34, 16, 24), CFrame.new(sx, by0 + 8, bz), COLORS.white)
		part(ship, Vector3.new(30, 9, 20), CFrame.new(sx, by0 + 20.5, bz - 1), COLORS.white)
		part(
			ship,
			Vector3.new(30.4, 3, 20.4),
			CFrame.new(sx, by0 + 21.5, bz - 1),
			Color3.fromRGB(30, 46, 64),
			Enum.Material.Glass
		)
		part(
			ship,
			Vector3.new(SH.Width + 4, 0.8, 6),
			CFrame.new(sx, by0 + 25.4, bz - 8),
			COLORS.white
		)
		part(
			ship,
			Vector3.new(30.6, 0.8, 20.6),
			CFrame.new(sx, by0 + 25.4, bz - 1),
			Color3.fromRGB(200, 60, 50)
		)
		for _, y in { 5, 10 } do
			part(
				ship,
				Vector3.new(34.4, 1.6, 24.4),
				CFrame.new(sx, by0 + y, bz),
				Color3.fromRGB(30, 46, 64),
				Enum.Material.Glass
			)
		end
		part(ship, Vector3.new(0.8, 12, 0.8), CFrame.new(sx, by0 + 32, bz), COLORS.white)
		part(ship, Vector3.new(8, 0.6, 0.6), CFrame.new(sx, by0 + 35, bz), COLORS.white)
		-- the funnel behind it: red with a white band and a black top
		local fz = z1 - 5
		part(ship, Vector3.new(9, 14, 8), CFrame.new(sx, by0 + 22, fz), Color3.fromRGB(200, 60, 50))
		part(ship, Vector3.new(9.2, 2.4, 8.2), CFrame.new(sx, by0 + 22, fz), COLORS.white)
		part(ship, Vector3.new(9.2, 2, 8.2), CFrame.new(sx, by0 + 29.6, fz), COLORS.stripe)
		-- orange lifeboats hung on the bridge's sides
		for _, e in { -1, 1 } do
			local boat = part(
				ship,
				Vector3.new(10, 3, 3),
				CFrame.new(sx + e * 19, by0 + 13, bz) * CFrame.Angles(0, math.pi / 2, 0),
				Color3.fromRGB(240, 120, 30)
			)
			boat.Shape = Enum.PartType.Cylinder
		end
		-- the anchor and its hawse pipe on each bow
		for _, e in { -1, 1 } do
			part(
				ship,
				Vector3.new(0.6, 6, 3),
				CFrame.new(sx + e * (hw * 0.55), SH.Deck - 4, z0 - bowLen * 0.45)
					* CFrame.Angles(0, -e * 0.62, 0),
				COLORS.stripe,
				Enum.Material.Metal
			)
		end
		ship.Parent = buildings
	end

	-- desert (south): sand, terrain dunes, sandstone mesas, cacti
	do
		local D = Cfg.Desert
		local ds = zones.desert
		-- the floor is the ground turned to sand (terrain), so it blends into the grass; ragged squares of sand
		-- spill past its edges
		local function sand(x0: number, z0: number, x1: number, z1: number)
			terrain:ReplaceMaterial(
				Region3.new(
					Vector3.new(math.floor(x0 / 4) * 4, -8, math.floor(z0 / 4) * 4),
					Vector3.new(math.ceil(x1 / 4) * 4, 4, math.ceil(z1 / 4) * 4)
				),
				4,
				Enum.Material.Grass,
				Enum.Material.Sand
			)
		end
		sand(ds.x - ds.w / 2, ds.z - ds.d / 2, ds.x + ds.w / 2, ds.z + ds.d / 2)
		for k = 1, D.EdgeSpill do
			local size = random:NextNumber(D.SpillSize[1], D.SpillSize[2])
			local t = random:NextNumber(-0.5, 0.5)
			local spill = random:NextNumber(-size / 2, D.SpillOut)
			local x, z
			if k % 4 < 2 then
				x, z = ds.x + t * ds.w, ds.z + (if k % 4 == 0 then -1 else 1) * (ds.d / 2 + spill)
			else
				x, z = ds.x + (if k % 4 == 2 then -1 else 1) * (ds.w / 2 + spill), ds.z + t * ds.d
			end
			sand(x - size / 2, z - size / 2, x + size / 2, z + size / 2)
		end
		for _ = 1, D.Dunes do
			local f = random:NextNumber(D.DuneRadius[1], D.DuneRadius[2])
			local h = f * random:NextNumber(D.DuneSlope[1], D.DuneSlope[2]) / 100
			local x = ds.x + random:NextNumber(-ds.w / 2 + f, ds.w / 2 - f)
			local z = ds.z + random:NextNumber(-ds.d / 2 + f, ds.d / 2 - f)
			mound(x, z, f, h, Enum.Material.Sand)
		end
		local mesas: { Vector3 } = {} -- x, z and the sand skirt's radius (cacti keep out)
		for k = 0, D.Mesas - 1 do
			local side = if k % 2 == 0 then -1 else 1
			local x = ds.x + side * (ds.w / 2 - 70 - (k // 2) * 160)
			local z = ds.z + random:NextNumber(-ds.d / 4, ds.d / 4)
			local size = Vector3.new(
				random:NextNumber(60, 100),
				random:NextNumber(30, 50),
				random:NextNumber(60, 100)
			)
			local turn = random:NextNumber(0, math.pi)
			-- stepped: tiers of a few overlapping turned slabs, each tier smaller, on a sand skirt (its own
			-- stream, so the rest of the outskirts keeps its layout)
			local own = Random.new(D.MesaSeed + k)
			local tall = size.Y * D.MesaTall
			table.insert(mesas, Vector3.new(x, z, math.max(size.X, size.Z) / 2 * (1 + D.MesaTalus)))
			mound(
				x,
				z,
				math.max(size.X, size.Z) / 2 * (1 + D.MesaTalus),
				tall * D.MesaTalusRise,
				Enum.Material.Sand
			)
			local tierH = tall / D.MesaTiers
			local scale = 1
			for t = 0, D.MesaTiers - 1 do
				local bottom = t * tierH - 2
				for _ = 1, own:NextInteger(D.MesaSlabs[1], D.MesaSlabs[2]) do
					local sx = size.X * scale * own:NextNumber(D.MesaSlabSize[1], D.MesaSlabSize[2])
					local sz = size.Z * scale * own:NextNumber(D.MesaSlabSize[1], D.MesaSlabSize[2])
					local off = Vector3.new(
						own:NextNumber(-D.MesaOffset, D.MesaOffset) * size.X * scale,
						0,
						own:NextNumber(-D.MesaOffset, D.MesaOffset) * size.Z * scale
					)
					local h = tierH * own:NextNumber(D.MesaSlabHeight[1], D.MesaSlabHeight[2])
						+ (if t == 0 then 2 else 0)
					terrain:FillBlock(
						CFrame.new(x + off.X, bottom + h / 2, z + off.Z)
							* CFrame.Angles(0, turn + own:NextNumber(-D.MesaTwist, D.MesaTwist), 0),
						Vector3.new(sx, h, sz),
						Enum.Material.Sandstone
					)
				end
				scale *= own:NextNumber(D.MesaShrink[1], D.MesaShrink[2])
			end
		end
		-- sandstone outcrops: a few rock balls half sunk in the sand, round the dunes
		for _ = 1, D.Outcrops do
			local x = ds.x + random:NextNumber(-ds.w / 2 + 40, ds.w / 2 - 40)
			local z = ds.z + random:NextNumber(-ds.d / 2 + 40, ds.d / 2 - 40)
			for _ = 1, random:NextInteger(2, 4) do
				local r = random:NextNumber(D.OutcropSize[1], D.OutcropSize[2]) / 2
				terrain:FillBall(
					Vector3.new(
						x + random:NextNumber(-14, 14),
						-r * 0.3,
						z + random:NextNumber(-14, 14)
					),
					r,
					Enum.Material.Sandstone
				)
			end
		end
		local green = rgb(C.cactus)
		for _ = 1, D.Cacti do
			local at = Vector3.new(
				ds.x + random:NextNumber(-ds.w / 2 + 30, ds.w / 2 - 30),
				0,
				ds.z + random:NextNumber(-ds.d / 2 + 30, ds.d / 2 - 30)
			)
			local buried = false
			for _, me in mesas do
				if Vector2.new(at.X - me.X, at.Z - me.Y).Magnitude < me.Z then
					buried = true
					break
				end
			end
			if buried then
				continue
			end
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
				COLORS.white,
				nil,
				if side < 0 then "Hoard_MEGACORP TOWER" else "Hoard_COMING SOON"
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

	-- what the groves and ponds keep clear of: the city, the ring, its connectors, the zones and the sea
	local exclude: { Rules.Rect } = {
		{ x = 0, z = 0, w = ringOuter * 2, d = ringOuter * 2 },
		zones.stunt,
		zones.port,
		zones.desert,
		zones.site,
	}
	for _, c in connectors do
		table.insert(exclude, c)
	end
	-- the countryside: hills past the edge, farm, motocross, beaches, forest (Config/Country)
	for _, r in CountryKit.build(country) do
		table.insert(exclude, r)
	end
	-- the suburbs on the new land, each with its road out from the ring (Config/Suburbs; own seed)
	local suburbs =
		SuburbKit.build(ringOuter, static, buildings, props, Random.new(LandCfg.SuburbSeed))
	for _, r in suburbs.rects do
		table.insert(exclude, r)
	end
	for _, p in suburbs.walkPoints do
		table.insert(walkPoints, p)
	end
	for _, p in suburbs.places do
		table.insert(places, p)
	end
	WildsKit.lakes(country, exclude)
	local function rng(): number
		return random:NextNumber()
	end

	-- the flat grass: groves of trees, ponds with a sandy bank
	local W = Cfg.Wilds
	for _, g in
		Rules.clearSpots(reach, exclude, W.Groves, W.GroveRadius, W.Margin, rng, country.allowed)
	do
		for _ = 1, random:NextInteger(W.GroveTrees[1], W.GroveTrees[2]) do
			local a, d = random:NextNumber(0, math.pi * 2), random:NextNumber(0, W.GroveRadius)
			Greenery.tree(
				props,
				Vector3.new(g.x + math.cos(a) * d, 0, g.z + math.sin(a) * d),
				random
			)
		end
		table.insert(exclude, { x = g.x, z = g.z, w = W.GroveRadius * 2, d = W.GroveRadius * 2 })
	end
	for _, p in
		Rules.clearSpots(reach, exclude, W.Ponds, W.PondRadius, W.Margin, rng, country.allowed)
	do
		-- terrain: a sandy bank sunk a little, then water in it
		terrain:FillCylinder(CFrame.new(p.x, -1, p.z), 2, W.PondRadius, Enum.Material.Sand)
		terrain:FillCylinder(CFrame.new(p.x, -1, p.z), 2, W.PondRadius - 3, Enum.Material.Air)
		terrain:FillCylinder(CFrame.new(p.x, -4, p.z), 4, W.PondRadius - 7, Enum.Material.Sand)
		terrain:FillCylinder(CFrame.new(p.x, -2.5, p.z), 4, W.PondRadius - 7, Enum.Material.Water)
		table.insert(exclude, { x = p.x, z = p.z, w = W.PondRadius * 2, d = W.PondRadius * 2 })
	end
	-- what the roll keeps level (GroundKit): all of the above but the farm (only its yard stays flat) and the
	-- wind farm (its turbines rise with the land)
	local level: { Rules.Rect } = {}
	for _, r in exclude do
		if r ~= Country.Farm.Rect and r ~= Country.WindFarm.Rect then
			table.insert(level, r)
		end
	end
	table.insert(level, CountryKit.farmYard())
	-- what's still open: strips of woods, then low hills between them (Config/Country Meadow)
	local M = Country.Meadow
	local woodRadius = CountryKit.beltLength * M.WoodScale[2] / 2
	for _, w in
		Rules.clearSpots(reach, exclude, M.Woods, woodRadius, W.Margin, rng, country.allowed)
	do
		CountryKit.wood(country, w.x, w.z, random:NextNumber(M.WoodScale[1], M.WoodScale[2]))
		table.insert(exclude, { x = w.x, z = w.z, w = woodRadius * 2, d = woodRadius * 2 })
	end
	for _, h in
		Rules.clearSpots(reach, exclude, M.Hills, M.HillRadius[2], W.Margin, rng, country.allowed)
	do
		CountryKit.hill(
			h.x,
			h.z,
			random:NextNumber(M.HillRadius[1], M.HillRadius[2]),
			random:NextNumber(M.HillHeight[1], M.HillHeight[2])
		)
	end
	-- the last pass: knolls, pine stands, woods, hedgerows, wildflowers, more hills (Config/Country Fill)
	WildsKit.fill(country, exclude)
	-- the suburbs' lawns are all one grass: the darker patches (Wilds Fill.Patches) are taken back out of them,
	-- so neighbouring plots match
	for _, r in suburbs.rects do
		Terra.terrain:ReplaceMaterial(
			Region3.new(
				Vector3.new(r.x - r.w / 2, -16, r.z - r.d / 2),
				Vector3.new(r.x + r.w / 2, 4, r.z + r.d / 2)
			):ExpandToGrid(4),
			4,
			Enum.Material.LeafyGrass,
			Enum.Material.Grass
		)
	end
	-- the open grass rolls, worn paths cross it, and what stands on it rises with it (GroundKit)
	local paths = GroundKit.paths(level, seaEdge, reach, Random.new(Country.Roll.Seed))
	GroundKit.roll(level, paths, seaEdge, reach)
	GroundKit.lift({ static, props, buildings }, level, seaEdge)
	-- the zones' dressing on the finished ground (ZoneKit), before the greenery so palms keep off it
	local farmYard = CountryKit.farmYard()
	for _, place in
		ZoneKit.build({
			static = static,
			buildings = buildings,
			props = props,
			port = zones.port,
			stunt = zones.stunt,
			seaEdge = seaEdge,
			connector = RG.Connector,
			yard = Vector3.new(farmYard.x, 0, farmYard.z),
			beaches = CountryKit.beaches,
		})
	do
		table.insert(places, place)
	end
	-- tufts, bushes, rocks, crop rows and palms on the finished ground (FoliageKit)
	FoliageKit.build(static, props, level, seaEdge, reach, CountryKit.fields, CountryKit.beaches)
	return {
		walkPoints = walkPoints,
		places = places,
		spawnPoints = suburbs.spawnPoints,
		seaEdge = seaEdge,
		lamp = CountryKit.lamp,
	}
end

return OutskirtsKit
