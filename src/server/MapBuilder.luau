--!strict
-- Builds the world from World.Map at server start (same seed, same city every time):
-- an 8x8 city grid with wide roads; blocks from the city plan (offices, homes, the burger place, the parcel
-- warehouse, shops, parks, plazas) with destructible chunked buildings and places for the crowd,
-- parking lots with kickers; the ground, the highway ring and the zones beyond it come from OutskirtsKit.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ambient = require(ReplicatedStorage.Shared.Config.Ambient)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.Buildings)
local CityPlan = require(ReplicatedStorage.Shared.Rules.CityPlan)
local Crowd = require(ReplicatedStorage.Shared.Config.Crowd)
local HouseRules = require(ReplicatedStorage.Shared.Rules.Houses)
local Houses = require(ReplicatedStorage.Shared.Config.Houses)
local Districts = require(ReplicatedStorage.Shared.Rules.Districts)
local Parks = require(ReplicatedStorage.Shared.Config.Parks)
local Leaderboards = require(ReplicatedStorage.Shared.Config.Leaderboards)
local HitConfig = require(ReplicatedStorage.Shared.Config.PlayerHits)
local Routes = require(ReplicatedStorage.Shared.Rules.Routes)
local Streets = require(ReplicatedStorage.Shared.Config.Streets)
local Tiles = require(ReplicatedStorage.Shared.Rules.Tiles)
local Country = require(ReplicatedStorage.Shared.Config.Country)
local World = require(ReplicatedStorage.Shared.Config.World)
local CountryKit = require(script.Parent.CountryKit)
local Greenery = require(script.Parent.Greenery)
local HouseKit = require(script.Parent.HouseKit)
local LotKit = require(script.Parent.LotKit)
local TowerKit = require(script.Parent.TowerKit)
local SuburbKit = require(script.Parent.SuburbKit)
local Lots = require(ReplicatedStorage.Shared.Config.Lots)
local OutskirtsKit = require(script.Parent.OutskirtsKit)
local Places = require(script.Parent.Places)
local RampKit = require(script.Parent.RampKit)
local RoadKit = require(script.Parent.RoadKit)
local SeaKit = require(script.Parent.SeaKit)
local SkylineKit = require(script.Parent.SkylineKit)
local StreetKit = require(script.Parent.StreetKit)
local TownKit = require(script.Parent.TownKit)
local YardKit = require(script.Parent.YardKit)
local Pace = require(script.Parent.Pace)
local Terra = require(script.Parent.Terra)

local MapBuilder = {}
local M = World.Map

export type Result = {
	buildings: Folder,
	props: Folder, -- street furniture any vehicle can knock over
	walkPoints: { Vector3 },
	spawnPoints: { Vector3 },
	crowdPoints: { Vector3 },
	places: { Places.Place }, -- homes, workplaces, shops and open areas the crowd uses
	grid: Routes.Grid, -- the city grid, for the sidewalk network
}

local COLORS = {
	road = Color3.fromRGB(58, 60, 66),
	line = Color3.fromRGB(235, 225, 170),
	sidewalk = Color3.fromRGB(176, 172, 164),
	grass = Color3.fromRGB(104, 160, 82),
	plaza = Color3.fromRGB(206, 192, 168),
	sand = Color3.fromRGB(222, 196, 140),
	concrete = Color3.fromRGB(190, 190, 195),
	ramp = Color3.fromRGB(240, 170, 50),
	rampStripe = Color3.fromRGB(40, 40, 44),
}

local random = Random.new(M.Seed)
-- the car parks' life (LotKit) rolls its own numbers, so the rest of the map stays as it was
local lotRandom = Random.new(M.Seed + 1)

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local MAX_PART = 2048 -- Roblox cuts any bigger part down, which left holes at the city's edges

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

local PAINT_YELLOW = Color3.fromRGB(255, 208, 0)
local PAINT_WHITE = Color3.fromRGB(245, 245, 245)
local PAINT_BLACK = Color3.fromRGB(23, 23, 26)

-- a flat strip of road paint on the plaza: no collisions, no raycasts (cars drive over it as paving)
local function paint(parent: Instance, size: Vector2, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(size.X, 0.05, size.Y)
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- a flat disc of paint lying on the plaza, centred at `at` (no collisions, no raycasts)
local function paintDisc(parent: Instance, dia: number, at: Vector3, color: Color3): Part
	local p = paint(parent, Vector2.new(dia, dia), CFrame.new(at), color)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.05, dia, dia)
	p.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
	return p
end

-- a white chevron of two bars on the ground, its point at `tip` facing along `dir` (flat)
local function chevron(parent: Instance, tip: Vector3, dir: Vector3, bar: number, width: number)
	local yaw = math.atan2(dir.X, dir.Z) + math.pi -- turned so the point faces `dir`
	local reach = bar * 0.29
	for _, side in { -1, 1 } do
		local cf = CFrame.new(tip)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.new(side * reach, 0, -reach)
			* CFrame.Angles(0, side * math.rad(45), 0)
		paint(parent, Vector2.new(width, bar), cf, PAINT_WHITE)
	end
end

-- the spawn pads' spots (World.SpawnPlaza): a ring round the middle, each with the way out it faces
local function padSpots(cx: number, cz: number): { { at: Vector3, out: Vector3 } }
	local SP = World.SpawnPlaza
	local spots = {}
	for k = 0, SP.Pads - 1 do
		local a = math.rad(SP.PadAngle) + k / SP.Pads * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		table.insert(spots, { at = Vector3.new(cx, 0, cz) + out * SP.PadRadius, out = out })
	end
	return spots
end

-- the spawn plaza's road paint (World.SpawnPlaza): the ring road's asphalt and four exits out to the streets,
-- a dashed yellow line round its middle, white one-way arrows (anticlockwise seen from above), big white
-- chevrons at each exit pointing out, and each spawn pad's number painted just outside it
local function paintPlaza(parent: Instance, cx: number, cz: number, inner: number)
	local SP = World.SpawnPlaza
	local folder = Instance.new("Folder")
	folder.Name = "Paint"
	folder.Parent = parent
	local y = 0.11 + World.Look.PaintLift -- three layers 0.02 apart: asphalt, paving back over it, markings
	local half = inner / 2
	local centre = Vector3.new(cx, y, cz)
	local asphalt = Color3.fromRGB(64, 66, 74)
	paintDisc(folder, SP.RingOuter * 2, centre, asphalt)
	paintDisc(folder, SP.RingInner * 2, centre + Vector3.new(0, 0.02, 0), COLORS.plaza).Material =
		Enum.Material.Pavement
	local mark = centre + Vector3.new(0, 0.04, 0)
	local mid = (SP.RingInner + SP.RingOuter) / 2
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local from = SP.RingOuter - 6
		local length = half - from
		local size = if math.abs(dir.X) > 0
			then Vector2.new(length, SP.ExitWidth)
			else Vector2.new(SP.ExitWidth, length)
		paint(folder, size, CFrame.new(centre + dir * (from + length / 2)), asphalt)
		chevron(folder, mark + dir * (half - 12), dir, 11, 2)
	end
	for k = 0, SP.RingDashes - 1 do
		local a = (k + 0.5) / SP.RingDashes * math.pi * 2
		local at = mark + Vector3.new(math.cos(a), 0, math.sin(a)) * mid
		local along = Vector3.new(math.sin(a), 0, -math.cos(a))
		paint(folder, Vector2.new(0.8, 5), CFrame.lookAt(at, at + along), PAINT_YELLOW)
	end
	-- anticlockwise from above: from +X (east) round to -Z (north)
	local lane = (mid + SP.RingOuter) / 2
	for k = 0, SP.RingArrows - 1 do
		local a = (k + 0.25) / SP.RingArrows * math.pi * 2
		local at = mark + Vector3.new(math.cos(a), 0, math.sin(a)) * lane
		chevron(folder, at, Vector3.new(math.sin(a), 0, -math.cos(a)), 6, 1.2)
	end
	for n, spot in padSpots(cx, cz) do
		local at = spot.at + spot.out * (SP.PadSize / 2 + 3.5)
		local tag = paint(folder, Vector2.new(7, 5), CFrame.new(at.X, mark.Y, at.Z), PAINT_WHITE)
		tag.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.LightInfluence = 1
		gui.Parent = tag
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = string.format("%02d", n)
		label.TextScaled = true
		label.TextColor3 = PAINT_WHITE
		label.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
		label.Rotation = math.deg(math.atan2(spot.out.X, spot.out.Z)) + 180 -- reads from the pad
		label.Parent = gui
	end
end

-- the spawn plaza's dressing (World.SpawnPlaza), the first thing every player sees: coloured paving bands, a
-- giant gold trophy on a plinth in the middle, trees in planters and food stalls on the diagonals (clear of
-- the pads and the lanes out), and flag poles with banners in the UI's colours at the corners. Its own random
-- stream, so the rest of the town keeps its layout.
local function dressSpawnPlaza(
	static: Instance,
	props: Instance,
	cx: number,
	cz: number,
	inner: number
)
	local SP = World.SpawnPlaza
	local r = Random.new(M.Seed + SP.SeedOffset)
	local centre = Vector3.new(cx, 0, cz)
	local half = inner / 2
	local band = rgb(SP.Band)
	local yBand = 0.1 + World.Look.PaintLift / 2
	-- the grass island in the middle with a terracotta kerb (the champions' podium stands on it), and a
	-- border inside the plaza's edge
	local function slab(radius: number, top: number, colour: Color3, material: Enum.Material)
		local p = part(
			static,
			Vector3.new(top + 0.4, radius * 2, radius * 2),
			CFrame.new(cx, (top - 0.4) / 2, cz) * CFrame.Angles(0, 0, math.pi / 2),
			colour,
			material
		)
		p.Shape = Enum.PartType.Cylinder
	end
	slab(SP.Island + SP.Kerb, SP.IslandTop - 0.05, band, Enum.Material.Pavement)
	slab(SP.Island, SP.IslandTop, COLORS.grass, Enum.Material.Grass)
	for _, e in { -1, 1 } do
		paint(
			static,
			Vector2.new(inner, SP.Border),
			CFrame.new(cx, yBand, cz + e * (half - SP.Border / 2)),
			band
		)
		paint(
			static,
			Vector2.new(SP.Border, inner - SP.Border * 2),
			CFrame.new(cx + e * (half - SP.Border / 2), yBand, cz),
			band
		)
	end
	-- trees in planters on the diagonals near the corners
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			for _, off in SP.Planters do
				local at = centre + Vector3.new(sx * off[1], 0, sz * off[2])
				part(
					static,
					Vector3.new(10, 2.4, 10),
					CFrame.new(at + Vector3.new(0, 1.2, 0)),
					rgb(SP.Stone),
					Enum.Material.Limestone
				)
				paint(
					static,
					Vector2.new(8.4, 8.4),
					CFrame.new(at + Vector3.new(0, 2.43, 0)),
					Color3.fromRGB(92, 70, 52)
				).Material =
					Enum.Material.Ground
				Greenery.tree(props, at + Vector3.new(0, 2.4, 0), r)
			end
		end
	end
	-- food stalls on the diagonals, facing the trophy: a counter, posts, a striped awning and a sign
	for k, stall in SP.Stalls do
		local a = math.rad(45 + (k - 1) * 90)
		local at = centre + Vector3.new(math.cos(a), 0, math.sin(a)) * SP.StallReach
		local cf = CFrame.lookAt(at, centre)
		local m = Instance.new("Model")
		m.Name = "Stall"
		m:SetAttribute("Prop", "Stall")
		m.Parent = props
		local colour = rgb(stall.colour)
		part(m, Vector3.new(10, 3.6, 3), cf * CFrame.new(0, 1.8, -1), Color3.fromRGB(245, 240, 228))
		part(m, Vector3.new(10.4, 0.6, 3.4), cf * CFrame.new(0, 3.9, -1), colour)
		for _, e in { -1, 1 } do
			part(
				m,
				Vector3.new(0.5, 8, 0.5),
				cf * CFrame.new(e * 4.8, 4, 1.5),
				Color3.fromRGB(240, 240, 236)
			)
		end
		for s = 0, 4 do
			part(
				m,
				Vector3.new(2.2, 0.4, 7),
				cf * CFrame.new(-4.4 + s * 2.2, 8.2, 0) * CFrame.Angles(0.2, 0, 0),
				if s % 2 == 0 then colour else Color3.fromRGB(250, 250, 250)
			)
		end
		Places.sign(
			m,
			Vector3.new(9, 2.2, 0.4),
			cf * CFrame.new(0, 10, -3.2),
			stall.text,
			PAINT_BLACK,
			colour,
			nil,
			"Stall_" .. stall.text
		)
	end
	-- flag poles at the corners, two banners each in the UI's colours
	for k, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local at = centre + Vector3.new(c[1], 0, c[2]) * (half - SP.Border - 2)
		local pole = part(
			static,
			Vector3.new(SP.PoleHeight, 1, 1),
			CFrame.new(at + Vector3.new(0, SP.PoleHeight / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(230, 230, 226),
			Enum.Material.Metal
		)
		pole.Shape = Enum.PartType.Cylinder
		local cap = part(
			static,
			Vector3.one * 1.8,
			CFrame.new(at + Vector3.new(0, SP.PoleHeight + 0.6, 0)),
			PAINT_YELLOW
		)
		cap.Shape = Enum.PartType.Ball
		for side = 0, 1 do
			local colour = rgb(SP.Banners[(k + side - 1) % #SP.Banners + 1])
			local dir = if side == 0 then Vector3.new(c[1], 0, 0) else Vector3.new(0, 0, c[2])
			local b = part(
				static,
				Vector3.new(0.3, 12, 4),
				CFrame.lookAt(
					at + dir * 2.6 + Vector3.new(0, SP.PoleHeight - 7, 0),
					at + dir * 3.6 + Vector3.new(0, SP.PoleHeight - 7, 0)
				),
				colour,
				Enum.Material.Fabric
			)
			b.CanCollide = false
			local tail = part(
				static,
				Vector3.new(0.3, 2.4, 4),
				b.CFrame * CFrame.new(0, -7.2, 0),
				PAINT_BLACK,
				Enum.Material.Fabric
			)
			tail.CanCollide = false
			-- both sway about the pole on each screen (client/Ambient)
			for _, piece in { b, tail } do
				piece:SetAttribute("Hinge", at)
				CollectionService:AddTag(piece, Ambient.Tags.Flag)
			end
		end
	end
end

-- the champions' podium on the spawn plaza's island (World.SpawnPlaza.Podium): a round concrete turntable and,
-- on it, a stage the client turns (model ChampionStage, kept loaded): three steps in a row (parts named
-- Step_<key>; the client puts the plates and the avatars on them). Nothing else stands on the stage, so no
-- angle shows anything passing through an avatar. The steps turn on screen only: an invisible wall collides.
local function champions(static: Instance, cx: number, cz: number)
	local SP = World.SpawnPlaza
	local P = SP.Podium
	local base = SP.IslandTop
	local table_ = part(
		static,
		Vector3.new(P.Rise, P.Radius * 2, P.Radius * 2),
		CFrame.new(cx, base + P.Rise / 2, cz) * CFrame.Angles(0, 0, math.pi / 2),
		COLORS.concrete,
		Enum.Material.Concrete
	)
	table_.Shape = Enum.PartType.Cylinder
	local stage = Instance.new("Model")
	stage.Name = "ChampionStage"
	stage.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- the client turns it
	stage.Parent = static
	local floor = base + P.Rise
	for i, key in P.Keys do
		local h = P.Heights[i]
		local x = (2 - i) * P.StepWidth -- step 1 on the left seen from the front (-Z)
		local p = part(
			stage,
			Vector3.new(P.StepWidth, h, P.StepDepth),
			CFrame.new(cx + x, floor + h / 2, cz),
			rgb(P.Colours[i])
		)
		p.Name = "Step_" .. key
		p.CanCollide = false
		-- a white cap on top, a little bigger than the step every way (sides LipOut out, top LipRaise up) so no
		-- face of it lies in a face of the step: shared faces flicker
		local lipH = 0.4 + P.LipRaise
		part(
			stage,
			Vector3.new(P.StepWidth + P.LipOut * 2, lipH, P.StepDepth + P.LipOut * 2),
			CFrame.new(cx + x, floor + h + P.LipRaise - lipH / 2, cz),
			COLORS.concrete
		).CanCollide =
			false
	end
	-- the steps turn on screen only, so an invisible round wall over the circle they sweep (up past the avatars'
	-- heads) is what people and cars bump into
	local wall = part(
		static,
		Vector3.new(P.WallHeight, P.WallRadius * 2, P.WallRadius * 2),
		CFrame.new(cx, floor + P.WallHeight / 2, cz) * CFrame.Angles(0, 0, math.pi / 2),
		COLORS.concrete,
		nil,
		1
	)
	wall.Shape = Enum.PartType.Cylinder
	wall.Name = "PodiumWall"
	wall.CanQuery = false -- the camera sees through it
	wall.CastShadow = false
end

-- a ramp you drive up while heading along `dir` (a flat unit vector); its foot sits at `foot`
local function ramp(
	parent: Instance,
	foot: Vector3,
	dir: Vector3,
	width: number,
	height: number,
	length: number
)
	local look = dir.Unit
	local centre = foot + look * (length / 2) + Vector3.new(0, height / 2, 0)
	-- a WedgePart rises toward its -Z side... facing -look puts the high end ahead of the driver
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = Vector3.new(width, height, length)
	w.CFrame = CFrame.lookAt(centre, centre - look)
	w.Color = COLORS.ramp
	w.Material = Enum.Material.SmoothPlastic
	w.Parent = parent
	RampKit.dress(w)
	return w
end

-- a flat disc lying on the ground, `height` thick and `dia` across, its top `top` studs up
local function disc(
	parent: Instance,
	height: number,
	dia: number,
	at: Vector3,
	top: number,
	color: Color3,
	material: Enum.Material
): Part
	local p = part(
		parent,
		Vector3.new(height, dia, dia),
		CFrame.new(at + Vector3.new(0, top - height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- the park: two paths crossing at a round pond; trees and bushes in three lawns, the kicker on the fourth;
-- a bench, a lamp and flower beds along every path arm
local function park(
	static: Instance,
	props: Instance,
	centre: Vector3,
	inner: number,
	accent: Color3
)
	local PK = Parks.Park
	local pathColour = rgb(PK.PathColour)
	for _, alongX in { true, false } do
		local size = if alongX then Vector2.new(inner, PK.Path) else Vector2.new(PK.Path, inner)
		paint(static, size, CFrame.new(centre + Vector3.new(0, 0.14, 0)), pathColour).Material =
			Enum.Material.Pavement
	end
	local rimDia = PK.Pond + PK.Rim * 2
	disc(static, 0.05, rimDia + 8, centre, 0.15, pathColour, Enum.Material.Pavement).CanCollide =
		false
	disc(static, 0.8, rimDia, centre, 0.8, COLORS.concrete, Enum.Material.Concrete)
	local water =
		disc(static, 0.3, PK.Pond, centre, 0.9, Color3.fromRGB(60, 160, 200), Enum.Material.Glass)
	water.Transparency = 0.15
	water.Reflectance = 0.1
	-- a low jet of spray in its middle, made on each screen (client/Ambient)
	water:SetAttribute("SprayLift", Ambient.PondLift)
	water:SetAttribute("Pond", true)
	CollectionService:AddTag(water, Ambient.Tags.Spray)
	-- along each arm, from the pond out to the sidewalk
	local lampColour = accent:Lerp(Color3.new(1, 1, 1), 0.5)
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local from, to = rimDia / 2 + 8, inner / 2 - 6
		for k = 1, PK.Benches do
			local t = from + (to - from) * k / (PK.Benches + 1)
			StreetKit.bench(props, centre + dir * t + side * (PK.Path / 2 + 2.5), -side)
		end
		for k = 1, PK.Lamps do
			local t = from + (to - from) * k / (PK.Lamps + 1)
			StreetKit.lamp(props, centre + dir * t - side * (PK.Path / 2 + 1.5), side, lampColour)
		end
		for _, t in { from + 4, to - 4 } do
			Greenery.flowerBed(props, centre + dir * t - side * (PK.Path / 2 + 3), dir, random)
		end
	end
	-- the four lawns between the paths; the north-west one has the kicker, so its trees keep to its edges
	local q = (PK.Path / 2 + inner / 2) / 2
	local room = (inner / 2 - PK.Path / 2) / 2 - 8
	local rampLane = centre + Vector3.new(-q, 0, -q)
	ramp(static, rampLane + Vector3.new(-room, 0, 0), Vector3.new(1, 0, 0), 24, 7, 30)
	local taken: { Vector3 } = {}
	local function spot(lawn: Vector3, gap: number, keepOffLane: boolean): Vector3?
		for _ = 1, 20 do
			local p = lawn
				+ Vector3.new(random:NextNumber(-room, room), 0, random:NextNumber(-room, room))
			local ok = not keepOffLane or math.abs(p.Z - rampLane.Z) > 22
			for _, o in taken do
				if (o - p).Magnitude < gap then
					ok = false
					break
				end
			end
			if ok then
				table.insert(taken, p)
				return p
			end
		end
		return nil
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local lawn = centre + Vector3.new(sx * q, 0, sz * q)
			local rampLawn = sx < 0 and sz < 0
			for _ = 1, if rampLawn then 2 else PK.TreesPerLawn do
				local p = spot(lawn, 16, rampLawn)
				if p then
					Greenery.tree(props, p, random)
				end
			end
			for _ = 1, PK.BushesPerLawn do
				local p = spot(lawn, 8, rampLawn)
				if p then
					Greenery.bush(props, p, random)
				end
			end
		end
	end
end

-- turn the terrain grass under one flat ground part to Asphalt (run through Terra: it reads the voxels first)
local function clearGrassUnder(size: Vector3, cf: CFrame, lo: Vector3, hi: Vector3)
	local GU = World.GrassUnder
	local terrain = workspace.Terrain
	-- only the voxel columns whose middle is under the part (grown by GU.Grow), so a turned driveway or a
	-- narrow path clears its own shape, not its whole bounding box in 4-stud blocks; a part too small to
	-- cover any middle clears the one column under its centre
	local region = Region3.new(
		Vector3.new(lo.X - GU.Grow, -12, lo.Z - GU.Grow),
		Vector3.new(hi.X + GU.Grow, 4, hi.Z + GU.Grow)
	):ExpandToGrid(4)
	local vox, occ = terrain:ReadVoxels(region, 4)
	local n = vox.Size
	local base = region.CFrame.Position - region.Size / 2
	local lim = size / 2 + Vector3.one * GU.Grow
	local function clear(ix: number, iz: number): boolean
		local hit = false
		for iy = 1, n.Y do
			if vox[ix][iy][iz] == Enum.Material.Grass and occ[ix][iy][iz] > 0 then
				vox[ix][iy][iz] = Enum.Material.Asphalt
				hit = true
			end
		end
		return hit
	end
	local changed, any = false, false
	for ix = 1, n.X do
		for iz = 1, n.Z do
			local q = cf:PointToObjectSpace(
				Vector3.new(base.X + (ix - 0.5) * 4, cf.Position.Y, base.Z + (iz - 0.5) * 4)
			)
			if math.abs(q.X) <= lim.X and math.abs(q.Y) <= lim.Y and math.abs(q.Z) <= lim.Z then
				any = true
				changed = clear(ix, iz) or changed
			end
		end
	end
	if not any then
		local ix = math.clamp(math.floor((cf.Position.X - base.X) / 4) + 1, 1, n.X)
		local iz = math.clamp(math.floor((cf.Position.Z - base.Z) / 4) + 1, 1, n.Z)
		changed = clear(ix, iz)
	end
	if changed then
		terrain:WriteVoxels(region, 4, vox, occ)
	end
end

-- a city home's small front garden (YardKit.front, compact): a picket fence or hedge along the sidewalk with
-- a gap at the door and wherever the house reaches out low toward it (a porch, a stoop), small bushes
local function frontGarden(
	props: Instance,
	buildings: Instance,
	home: Places.Place,
	c: Vector3,
	face: Vector3,
	t: Houses.HouseType
)
	local G = Houses.Garden
	local right = Vector3.new(-face.Z, 0, face.X)
	local door = (home.door - c):Dot(right)
	local gaps = { { door - G.DoorGap, door + G.DoorGap } }
	local model = buildings:FindFirstChild(home.name)
	if model then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				local cf, size = p.CFrame, p.Size
				local function reach(dir: Vector3): number
					return math.abs(cf.RightVector:Dot(dir)) * size.X / 2
						+ math.abs(cf.UpVector:Dot(dir)) * size.Y / 2
						+ math.abs(cf.LookVector:Dot(dir)) * size.Z / 2
				end
				local rel = p.Position - c
				if
					rel:Dot(face) + reach(face) > t.depth / 2 + G.Proud
					and p.Position.Y - reach(Vector3.yAxis) < G.Low
				then
					local x, half = rel:Dot(right), reach(right)
					table.insert(gaps, { x - half, x + half })
				end
			end
		end
	end
	YardKit.front(props, {
		c = c,
		face = face,
		width = t.width,
		depth = t.depth,
		lawn = Houses.Yard,
		door = door,
		drive = 0,
		driveWidth = 0,
		car = false,
		gaps = gaps,
		wallGaps = {},
		clear = function(_: Vector3): boolean
			return true
		end,
		compact = true,
	})
end

-- `fresh` (the bake) draws all the terrain even when the place already holds it (Terra)
function MapBuilder.build(fresh: boolean?): Result
	Terra.begin(fresh)
	local map = Instance.new("Folder")
	map.Name = "Map"
	local static = Instance.new("Folder")
	static.Name = "Static"
	static.Parent = map
	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = map
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = map
	local walkPoints: { Vector3 } = {}
	local spawnPoints: { Vector3 } = {}
	local crowdPoints: { Vector3 } = {}

	-- a template place's Baseplate and SpawnLocation would fight the map (players must appear at the plaza)
	for _, old in workspace:GetChildren() do
		if old.Name == "Baseplate" or old:IsA("SpawnLocation") then
			old:Destroy()
		end
	end

	-- city grid: the roads you see are meshes (RoadKit); these plain parts under them are what cars drive on,
	-- all with their top at 0.10, invisible
	local B, R = M.BlockSize, M.RoadWidth
	local pitch = B + R
	local spanX, spanZ = M.BlocksX * pitch + R, M.BlocksZ * pitch + R
	local x0, z0 = -spanX / 2, -spanZ / 2
	for i = 0, M.BlocksX do
		local x = x0 + R / 2 + i * pitch
		part(
			static,
			Vector3.new(R, 1, spanZ),
			CFrame.new(x, -0.4, 0),
			COLORS.road,
			Enum.Material.Asphalt,
			1
		)
	end
	for j = 0, M.BlocksZ do
		local z = z0 + R / 2 + j * pitch
		part(
			static,
			Vector3.new(spanX, 1, R),
			CFrame.new(0, -0.4, z),
			COLORS.road,
			Enum.Material.Asphalt,
			1
		)
		for i = 0, M.BlocksX do
			table.insert(spawnPoints, Vector3.new(x0 + R / 2 + i * pitch, 0.2, z))
		end
	end

	-- blocks: what stands where comes from the city plan
	local centreI, centreJ = math.floor(M.BlocksX / 2), math.floor(M.BlocksZ / 2)
	local plan = CityPlan.plan(M.BlocksX, M.BlocksZ, M.Seed)
	local places: { Places.Place } = {}
	local count, offices, shops = 0, 0, 0
	local function addPlace(place: Places.Place, i: number, j: number)
		place.block = { i, j }
		table.insert(places, place)
	end
	-- the side of a block facing the spawn block (so landmarks face the middle of town)
	local function towardSpawn(i: number, j: number): Vector3
		local di, dj = centreI - i, centreJ - j
		if math.abs(di) >= math.abs(dj) and di ~= 0 then
			return Vector3.new(math.sign(di), 0, 0)
		end
		return Vector3.new(0, 0, if dj ~= 0 then math.sign(dj) else 1)
	end
	local SIDES =
		{ Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
	-- the hero tower (Config/Buildings Office.Hero) stands on the office block nearest the spawn plaza
	local heroI, heroJ, heroD = -1, -1, math.huge
	for i = 0, M.BlocksX - 1 do
		for j = 0, M.BlocksZ - 1 do
			if plan[i][j] == "spawn" then
				for oi = 0, M.BlocksX - 1 do
					for oj = 0, M.BlocksZ - 1 do
						local dd = (oi - i) ^ 2 + (oj - j) ^ 2
						if plan[oi][oj] == "office" and dd < heroD then
							heroI, heroJ, heroD = oi, oj, dd
						end
					end
				end
			end
		end
	end
	for i = 0, M.BlocksX - 1 do
		for j = 0, M.BlocksZ - 1 do
			local cx = x0 + R + i * pitch + B / 2
			local cz = z0 + R + j * pitch + B / 2
			local centre = Vector3.new(cx, 0, cz)
			local district = Districts.of(i, j, M.BlocksX, M.BlocksZ)
			local style = (Streets.Districts :: any)[district] :: Streets.District
			local walls = (BuildingConfig.Facades :: any)[district] or style.walls
			local function wallColour(): Color3
				local c = walls[random:NextInteger(1, #walls)]
				return Color3.fromRGB(c[1], c[2], c[3])
			end
			local firstBuilding = #buildings:GetChildren() + 1
			-- sidewalk ring (flush, so vehicles roll straight over it) with walk points
			local SW = M.SidewalkWidth
			part(
				static,
				Vector3.new(B, 1, B),
				CFrame.new(cx, -0.42, cz),
				Color3.fromRGB(style.sidewalk[1], style.sidewalk[2], style.sidewalk[3]),
				(Enum.Material :: any)[style.sidewalkMaterial]
			)
			for k = 0, 7 do
				local t = (k + 0.5) / 8 * B - B / 2
				table.insert(walkPoints, centre + Vector3.new(t, 0.5, -B / 2 + SW / 2))
				table.insert(walkPoints, centre + Vector3.new(t, 0.5, B / 2 - SW / 2))
				table.insert(walkPoints, centre + Vector3.new(-B / 2 + SW / 2, 0.5, t))
				table.insert(walkPoints, centre + Vector3.new(B / 2 - SW / 2, 0.5, t))
			end
			local inner = B - SW * 2
			local distFromCentre =
				math.max(math.abs(i - centreI + 0.5), math.abs(j - centreJ + 0.5))
			local kind = plan[i][j]
			if kind == "spawn" then
				-- spawn plaza: a roundabout hub (World.SpawnPlaza)
				part(
					static,
					Vector3.new(inner, 1, inner),
					CFrame.new(cx, -0.38, cz),
					COLORS.plaza,
					Enum.Material.Pavement
				)
				-- the pads in a ring round the island, each facing out onto the ring road; just above the
				-- road paint so they show
				for _, spot in padSpots(cx, cz) do
					local sp = Instance.new("SpawnLocation")
					sp.Anchored = true
					sp.Size = Vector3.new(World.SpawnPlaza.PadSize, 1, World.SpawnPlaza.PadSize)
					local at = spot.at + Vector3.new(0, -0.29, 0)
					sp.CFrame = CFrame.lookAt(at, at + spot.out)
					sp.Color = COLORS.ramp
					sp.Material = Enum.Material.SmoothPlastic
					sp.Duration = 0
					sp.Parent = static
				end
				-- the whole block is a safe zone: nobody in it can be hit by a player (PlayerHitService, Drive)
				workspace:SetAttribute("SafeZoneCentre", Vector3.new(cx, 0, cz))
				workspace:SetAttribute("SafeZoneHalf", B / 2 + HitConfig.SafeZoneMargin)
				paintPlaza(static, cx, cz, inner)
				dressSpawnPlaza(static, props, cx, cz, inner)
				-- leaderboard stands on the north sidewalk, facing the plaza (parts named Stand_<n>; the client
				-- draws the boards, Config/Leaderboards), and the champions' podium on the island
				local boards = Instance.new("Model")
				boards.Name = "Boards"
				boards.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- the client builds the boards on it
				boards.Parent = static
				-- the boards in a row, each in a frame (gold bars, cream sides, a lit strip under the top bar)
				-- with two lamps leaning over it, under a cream gantry on terracotta posts
				local L = Leaderboards
				local STW, SH = L.StandWidth, L.StandHeight
				local by = L.StandLift + SH / 2
				local span = (L.Stands - 1) * L.StandStep + STW + L.GantryReach * 2
				local gz = cz - B / 2 + 5
				local beamY = L.StandLift + SH + L.FrameTop + L.GantryOver
				part(boards, Vector3.new(span, 3, 2.4), CFrame.new(cx, beamY, gz), rgb(L.Gantry))
				for _, side in { -1, 1 } do
					part(
						boards,
						Vector3.new(L.GantryPost, beamY + 1, L.GantryPost),
						CFrame.new(cx + side * (span / 2 - L.PostInset), (beamY + 1) / 2, gz),
						rgb(L.GantryPosts)
					)
				end
				champions(static, cx, cz)
				for k = 1, L.Stands do
					local bx = cx + (k - (L.Stands + 1) / 2) * L.StandStep
					local bz = cz - B / 2 + 6
					local face = part(
						boards,
						Vector3.new(STW, SH, 1.2),
						CFrame.lookAt(Vector3.new(bx, by, bz), Vector3.new(bx, by, bz + 10)),
						rgb(L.Panel)
					)
					face.Name = "Stand_" .. k
					local frame =
						CFrame.lookAt(Vector3.new(bx, by, bz - 0.4), Vector3.new(bx, by, bz + 10))
					for _, e in { -1, 1 } do
						part(
							boards,
							Vector3.new(STW + 3, 1.6, 1.6),
							frame * CFrame.new(0, e * (SH / 2 + 0.8), 0),
							rgb(L.Frame)
						)
						part(
							boards,
							Vector3.new(1.6, SH, 1.6),
							frame * CFrame.new(e * (STW / 2 + 0.8), 0, 0),
							rgb(L.FrameSides)
						)
						local lamp = part(
							boards,
							Vector3.new(3, 1.4, 2.4),
							frame
								* CFrame.new(e * STW * 0.27, SH / 2 + 2.6, -2.6)
								* CFrame.Angles(math.rad(-35), 0, 0),
							PAINT_BLACK
						)
						local light = Instance.new("SpotLight")
						light.Face = Enum.NormalId.Bottom
						light.Angle = 70
						light.Range = 40
						light.Brightness = 2
						light.Color = Color3.fromRGB(255, 244, 220)
						light.Parent = lamp
					end
					part(
						boards,
						Vector3.new(STW + L.GlowStrip[1], L.GlowStrip[2], L.GlowStrip[3]),
						frame * CFrame.new(0, SH / 2 - L.GlowAt[1], -L.GlowAt[2]),
						rgb(L.Glow),
						Enum.Material.Neon
					)
					for _, side in { -1, 1 } do
						part(
							boards,
							-- ends inside the frame's bottom bar: equal tops flicker
							Vector3.new(2, L.StandLift + 0.4, 2),
							CFrame.new(
								bx + side * (STW / 2 - 2),
								(L.StandLift + 0.4) / 2 - 1,
								bz - 0.5
							),
							COLORS.concrete
						)
					end
				end
				-- the first crowd: at the four corners, a short drive out from the pads
				local corner = World.SpawnPlaza.Corner
				for _, c in { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } } do
					local at = centre + Vector3.new(c[1], 0, c[2]) * (corner.reach / math.sqrt(2))
					for n = 1, corner.people do
						local a = n / corner.people * math.pi * 2
						local r = if n % 2 == 0 then corner.spread else corner.spread * 0.45
						local p = at + Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r)
						table.insert(walkPoints, p)
						table.insert(crowdPoints, p)
					end
				end
				addPlace(Places.open("spawn", centre, crowdPoints), i, j)
			elseif kind == "office" then
				-- office towers in the town style: a stone lobby with a door, window bands, the name on the roof
				local OF = BuildingConfig.Office
				local floors = if distFromCentre < 2.5
					then random:NextInteger(5, 9)
					else random:NextInteger(3, 5)
				if distFromCentre < OF.DowntownReach then
					floors = lotRandom:NextInteger(OF.DowntownFloors[1], OF.DowntownFloors[2])
				end
				local fp = BuildingConfig.Office.Footprint
				local w = random:NextNumber(fp[1], fp[2]) * inner
				local d = random:NextNumber(fp[1], fp[2]) * inner
				count += 1
				offices += 1
				local out = SIDES[random:NextInteger(1, 4)]
				local hero = i == heroI and j == heroJ
				if hero then
					floors = OF.Hero.Floors
					out = towardSpawn(i, j)
				end
				-- the tower stands up to its front sidewalk, its car park behind it
				local deep = math.abs(out:Dot(Vector3.new(w, 0, d)))
				local tower = centre + out * (inner / 2 - BuildingConfig.Office.Setback - deep / 2)
				local lot = inner - BuildingConfig.Office.Setback - deep - 4
				if lot > 10 then
					local across = Vector3.new(math.abs(out.Z), 0, math.abs(out.X)) * inner
					part(
						static,
						across + Vector3.new(math.abs(out.X) * lot, 1, math.abs(out.Z) * lot),
						CFrame.new(centre - out * (inner / 2 - lot / 2) + Vector3.new(0, -0.39, 0)),
						COLORS.road,
						Enum.Material.Asphalt
					)
					LotKit.yard(
						static,
						props,
						centre - out * (inner / 2 - lot / 2),
						out,
						inner,
						lot,
						Lots.OfficeLot,
						lotRandom
					)
				end
				local wall = wallColour()
				local look = (BuildingConfig.Office.Looks :: any)[district] :: BuildingConfig.OfficeLook
				-- its own frame and spandrels, and two shopfront colours, each taken in turn
				local frame = OF.Frames[(offices * OF.FrameStride) % #OF.Frames + 1]
				local SFC = OF.Shopfront.Colours
				local colours = {
					wall = if hero or OF.FacadeSpandrels then wall else rgb(frame.spandrel),
					trim = rgb(frame.trim),
					accent = rgb(style.accent),
					roof = rgb(look.roof),
					stone = rgb(look.stone),
					glass = rgb(OF.Tints[(offices * 5) % #OF.Tints + 1]),
					shops = {
						rgb(SFC[(offices * 2) % #SFC + 1]),
						rgb(SFC[(offices * 2 + 1) % #SFC + 1]),
					},
				}
				if hero then
					colours.glass = rgb(OF.Hero.Glass)
					colours.accent = rgb(OF.Hero.Accent)
					colours.trim = rgb(OF.Hero.Trim)
				end
				local model, door =
					TownKit.office(buildings, tower, w, d, floors, colours, "Office" .. count, out)
				-- a street front: planters and a bench (YardKit)
				YardKit.officeFront(
					props,
					door,
					out,
					math.abs(Vector3.new(-out.Z, 0, out.X):Dot(Vector3.new(w, 0, d)))
				)
				-- lawn, hedge and flower beds on the bare paving either side of it (Config/StreetGreen Forecourt)
				YardKit.officeFlanks(
					props,
					static,
					centre,
					out,
					inner,
					math.abs(Vector3.new(-out.Z, 0, out.X):Dot(Vector3.new(w, 0, d))),
					deep,
					BuildingConfig.Office.Setback
				)
				-- its own crown, taken in turn so neighbours differ (TowerKit)
				TowerKit.crown(
					model,
					if hero then OF.Hero.Crown else OF.Crowns[(offices - 1) % #OF.Crowns + 1],
					tower,
					w,
					d,
					out,
					floors * M.FloorHeight,
					colours :: any,
					lotRandom
				)
				TowerKit.clutter(
					model,
					tower,
					w,
					d,
					out,
					floors * M.FloorHeight,
					colours :: any,
					offices
				)
				-- a vent box on some roofs' back corner, steaming on each screen (client/Ambient)
				if offices % Ambient.VentEvery == 0 then
					local VS = Ambient.VentSize
					local side = Vector3.new(-out.Z, 0, out.X)
					local acrossW = math.abs(side:Dot(Vector3.new(w, 0, d)))
					local vent = part(
						model,
						Vector3.new(VS[1], VS[2], VS[3]),
						CFrame.new(
							tower
								- out * (deep / 2 - Ambient.VentInset)
								+ side * (acrossW / 2 - Ambient.VentInset)
								+ Vector3.new(0, floors * M.FloorHeight + VS[2] / 2, 0)
						),
						rgb(Ambient.VentColour),
						Enum.Material.Metal
					)
					vent:SetAttribute("Fixed", true)
					CollectionService:AddTag(vent, Ambient.Tags.Steam)
				end
				-- the company name and a parody billboard stand on the roof, behind the parapet
				local top = floors * M.FloorHeight + BuildingConfig.Office.Parapet + 1
				local name = Crowd.OfficeNames[(offices - 1) % #Crowd.OfficeNames + 1]
				local width = math.abs(Vector3.new(-out.Z, 0, out.X):Dot(Vector3.new(w, 0, d)))
				addPlace(Places.office(model, door, out, width, top, name), i, j)
				local boardAt = tower - out * 10 + Vector3.new(0, top + 14, 0)
				local ad = Streets.Billboards[random:NextInteger(1, #Streets.Billboards)]
				if hero then
					-- the hero tower carries the game's name in the UI's road yellow on black, seen from spawn
					local size = OF.Hero.SignSize
					Places.sign(
						model,
						Vector3.new(math.min(size[1], width - 4), size[2], 1.2),
						CFrame.lookAt(
							boardAt + Vector3.new(0, size[2] / 2 - 5, 0),
							boardAt + Vector3.new(0, size[2] / 2 - 5, 0) + out
						),
						OF.Hero.Sign,
						PAINT_BLACK,
						PAINT_YELLOW,
						true,
						"Hero"
					)
				else
					Places.sign(
						model,
						Vector3.new(34, 11, 1),
						CFrame.lookAt(boardAt, boardAt + out),
						ad,
						Color3.fromRGB(250, 250, 245),
						colours.accent:Lerp(Color3.new(0, 0, 0), 0.4),
						true,
						"Ad_" .. ad
					)
				end
				local along = Vector3.new(-out.Z, 0, out.X)
				for _, e in { -12, 12 } do
					part(
						model,
						Vector3.new(1, 9, 1),
						CFrame.new(tower - out * 10 + along * e + Vector3.new(0, top + 4.5, 0)),
						COLORS.concrete
					)
				end
			elseif kind == "shops" then
				-- a row of shop fronts facing the south sidewalk, flats above, a car park behind
				local SH = BuildingConfig.Shops
				local fw = inner / SH.PerBlock
				local z = inner / 2 - SH.Setback - SH.Depth / 2
				local wallMaterial = (Enum.Material :: any)[style.wallMaterial] :: Enum.Material
				local lastPalette: number? = nil
				for k = 0, SH.PerBlock - 1 do
					count += 1
					shops += 1
					local pal =
						HouseRules.pickPalette(#Houses.Palettes, lastPalette, random:NextNumber())
					lastPalette = pal
					local place = TownKit.shop(
						buildings,
						centre + Vector3.new(-inner / 2 + (k + 0.5) * fw, 0, z),
						Vector3.new(0, 0, 1),
						fw,
						random:NextInteger(SH.Floors[1], SH.Floors[2]),
						wallColour(),
						wallMaterial,
						Houses.Palettes[pal],
						random:NextNumber() < 0.5,
						SH.Names[(shops - 1) % #SH.Names + 1],
						"Shop" .. count
					)
					addPlace(place, i, j)
					local shopModel = buildings:FindFirstChild("Shop" .. count)
					if shopModel and shopModel:IsA("Model") then
						LotKit.shopBack(
							shopModel,
							centre
								+ Vector3.new(
									-inner / 2 + (k + 0.5) * fw,
									0.12,
									z - SH.Depth / 2 - Lots.Back.WallOut
								),
							Vector3.new(0, 0, -1),
							fw,
							lotRandom
						)
					end
				end
				local yard = inner - SH.Setback - SH.Depth - 4
				part(
					static,
					Vector3.new(inner, 1, yard),
					CFrame.new(cx, -0.39, cz - inner / 2 + yard / 2),
					COLORS.road,
					Enum.Material.Asphalt
				)
				LotKit.yard(
					static,
					props,
					Vector3.new(cx, 0, cz - inner / 2 + yard / 2),
					Vector3.new(0, 0, 1),
					inner,
					yard,
					Lots.ShopYard,
					lotRandom
				)
				for k = 0, 5 do
					table.insert(
						walkPoints,
						centre
							+ Vector3.new(
								-inner / 2 + (k + 0.5) * inner / 6,
								0.5,
								inner / 2 - SH.Setback / 2
							)
					)
				end
			elseif kind == "park" then
				-- park: paths round a pond, lawns of trees, benches, lamps and flower beds, a kicker
				part(
					static,
					Vector3.new(inner, 1, inner),
					CFrame.new(cx, -0.39, cz),
					COLORS.grass,
					Enum.Material.Grass
				)
				park(static, props, centre, inner, rgb(style.accent))
				local spots = {}
				for _ = 1, 10 do
					local p = centre
						+ Vector3.new(
							random:NextNumber(-inner / 2.5, inner / 2.5),
							0.5,
							random:NextNumber(-inner / 2.5, inner / 2.5)
						)
					table.insert(walkPoints, p)
					table.insert(spots, p)
				end
				addPlace(
					Places.open(
						"park",
						centre + SIDES[random:NextInteger(1, 4)] * (inner / 2),
						spots
					),
					i,
					j
				)
			elseif kind == "plaza" then
				-- plaza: busy with people
				part(
					static,
					Vector3.new(inner, 1, inner),
					CFrame.new(cx, -0.38, cz),
					COLORS.plaza,
					Enum.Material.Pavement
				)
				local spots = {}
				for _ = 1, 22 do
					local p = centre
						+ Vector3.new(
							random:NextNumber(-inner / 2.2, inner / 2.2),
							0.5,
							random:NextNumber(-inner / 2.2, inner / 2.2)
						)
					table.insert(walkPoints, p)
					table.insert(spots, p)
				end
				addPlace(
					Places.open(
						"plaza",
						centre + SIDES[random:NextInteger(1, 4)] * (inner / 2),
						spots
					),
					i,
					j
				)
				-- a tree in each corner, clear of the planter ring and the fountain
				for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
					local at = centre + Vector3.new(c[1], 0, c[2]) * (inner / 2 - 16)
					Greenery.tree(props, at, random)
				end
				-- market stalls round the edge (Config/Country Plaza)
				CountryKit.plaza(props, centre, inner, random)
			elseif kind == "homes" then
				-- a street of family homes facing the north and south sidewalks, gardens behind
				part(
					static,
					Vector3.new(inner, 1, inner),
					CFrame.new(cx, -0.39, cz),
					COLORS.grass,
					Enum.Material.Grass
				)
				-- house kit: three lots along each sidewalk, types by district, neighbours never share a palette
				local weights = (Houses.ByDistrict :: any)[district] or Houses.ByDistrict.maple
				local lot = inner / Houses.PerSide
				local lastPalette: number? = nil
				for _, sz in { -1, 1 } do
					local out = Vector3.new(0, 0, sz)
					for k = 0, Houses.PerSide - 1 do
						local houseType = HouseRules.pickType(weights, random:NextNumber())
						local t = (Houses.Types :: any)[houseType] :: Houses.HouseType
						local z = sz * (inner / 2 - Houses.Yard - t.depth / 2)
						local lotX = -inner / 2 + (k + 0.5) * lot
						local mirror = random:NextNumber() < 0.5
						for u = 0, t.perLot - 1 do
							count += 1
							local x = lotX + (u - (t.perLot - 1) / 2) * t.width
							local pal = HouseRules.pickPalette(
								#Houses.Palettes,
								lastPalette,
								random:NextNumber()
							)
							lastPalette = pal
							local home = HouseKit.build(
								buildings,
								houseType,
								centre + Vector3.new(x, 0, z),
								out,
								Houses.Palettes[pal],
								mirror,
								"Home" .. count
							)
							addPlace(home, i, j)
							frontGarden(
								props,
								buildings,
								home,
								centre + Vector3.new(x, 0, z),
								out,
								t
							)
							-- detached homes get a back garden: a tree, a fence, maybe a pool (SuburbKit)
							if t.perLot == 1 then
								SuburbKit.garden(
									static,
									props,
									centre + Vector3.new(x, 0, z),
									out,
									t.width,
									t.depth,
									lotRandom
								)
							end
						end
					end
				end
				-- the lawn in the middle: hedges, flower beds, sometimes a playground (YardKit)
				local taken = YardKit.blockMiddle(props, centre, inner)
				for _ = 1, Parks.HomeTrees do
					local at = Vector3.new(
						random:NextNumber(-inner / 2.4, inner / 2.4),
						0,
						random:NextNumber(-20, 20)
					)
					-- a tree that would stand in a hedge, a bed or the playground isn't planted (its draws
					-- are still taken, so nothing after it moves)
					if YardKit.inside(taken, centre + at, Parks.TreeClear) then
						Greenery.skipTree(random)
					else
						Greenery.tree(props, centre + at, random)
					end
				end
			elseif kind == "restaurant" then
				-- the burger place, facing the middle of town, with a car park behind
				part(
					static,
					Vector3.new(inner, 1, inner),
					CFrame.new(cx, -0.38, cz),
					COLORS.plaza,
					Enum.Material.Pavement
				)
				local out = towardSpawn(i, j)
				local lotSize = Vector3.new(
					if out.X ~= 0 then inner * 0.36 else inner,
					1,
					if out.Z ~= 0 then inner * 0.36 else inner
				)
				local lotAt = centre - out * (inner * 0.32) + Vector3.new(0, -0.37, 0)
				part(static, lotSize, CFrame.new(lotAt), COLORS.road, Enum.Material.Asphalt)
				LotKit.yard(
					static,
					props,
					Vector3.new(lotAt.X, 0, lotAt.Z),
					out,
					inner,
					inner * 0.36,
					Lots.BurgerLot,
					lotRandom
				)
				LotKit.picnic(props, centre + out * (inner / 2 - 20), out, Crowd.RestaurantSize[1])
				local D = Crowd.RestaurantSize[2]
				addPlace(
					Places.restaurant(buildings, centre + out * (inner / 2 - D / 2 - 20), out),
					i,
					j
				)
			elseif kind == "warehouse" then
				-- the parcel warehouse: loading bays toward town and pallets of parcels
				part(
					static,
					Vector3.new(inner, 1, inner),
					CFrame.new(cx, -0.38, cz),
					COLORS.concrete,
					Enum.Material.Concrete
				)
				addPlace(Places.warehouse(buildings, centre, towardSpawn(i, j)), i, j)
				LotKit.warehouse(static, props, centre, towardSpawn(i, j), inner / 2, lotRandom)
			else
				-- parking lot with launch ramps
				part(
					static,
					Vector3.new(inner, 1, inner),
					CFrame.new(cx, -0.39, cz),
					COLORS.road,
					Enum.Material.Asphalt
				)
				ramp(
					static,
					centre + Vector3.new(-inner / 2 + 10, 0, -30),
					Vector3.new(1, 0, 0),
					30,
					12,
					50
				)
				ramp(
					static,
					centre + Vector3.new(30, 0, inner / 2 - 10),
					Vector3.new(0, 0, -1),
					30,
					8,
					36
				)
				-- painted bays and lamps (Config/Country Lot)
				CountryKit.lot(static, props, centre, inner)
				LotKit.rampLot(props, centre, Country.Lot, lotRandom)
			end
			-- the district's wall material on the walls of what was just built here
			local wallMaterial = (Enum.Material :: any)[style.wallMaterial]
			local children = buildings:GetChildren()
			for n = firstBuilding, #children do
				for _, p in children[n]:GetDescendants() do
					if p:IsA("BasePart") and p.Material == Enum.Material.SmoothPlastic then
						for _, c in walls do
							if p.Color == Color3.fromRGB(c[1], c[2], c[3]) then
								p.Material = wallMaterial
								break
							end
						end
					end
				end
			end
		end
	end

	-- a sidewalk along the outside of the outer road, between the roads that run out to the ring
	if Country.OuterSidewalk then
		local SW = M.SidewalkWidth
		local style = Streets.Districts.maple
		local colour = Color3.fromRGB(style.sidewalk[1], style.sidewalk[2], style.sidewalk[3])
		local mat = (Enum.Material :: any)[style.sidewalkMaterial]
		for k = 0, M.BlocksX - 1 do
			local x = x0 + R + k * pitch + B / 2
			for _, s in { -1, 1 } do
				part(
					static,
					Vector3.new(B, 1, SW),
					CFrame.new(x, -0.42, s * (spanZ / 2 + SW / 2)),
					colour,
					mat
				)
			end
		end
		for k = 0, M.BlocksZ - 1 do
			local z = z0 + R + k * pitch + B / 2
			for _, s in { -1, 1 } do
				part(
					static,
					Vector3.new(SW, 1, B),
					CFrame.new(s * (spanX / 2 + SW / 2), -0.42, z),
					colour,
					mat
				)
			end
		end
	end

	-- the road meshes over the whole map (the city, the ring, the suburbs)
	RoadKit.build(static)

	-- the street kit: furniture, bus stops
	local kit = StreetKit.build(static, props, {
		blocksX = M.BlocksX,
		blocksZ = M.BlocksZ,
		block = B,
		road = R,
		sidewalk = M.SidewalkWidth,
		x0 = x0,
		z0 = z0,
	}, plan, random)
	for _, stop in kit.places do
		table.insert(places, stop)
	end

	-- the ground, the ring and everything beyond it
	local outskirts = OutskirtsKit.build({
		static = static,
		buildings = buildings,
		props = props,
		random = random,
		half = M.GroundSize / 2,
		spanX = spanX,
		spanZ = spanZ,
		x0 = x0,
		z0 = z0,
		road = R,
		pitch = pitch,
		blocksX = M.BlocksX,
		blocksZ = M.BlocksZ,
	})
	for _, p in outskirts.walkPoints do
		table.insert(walkPoints, p)
	end
	for _, place in outskirts.places do
		table.insert(places, place)
	end
	for _, p in outskirts.spawnPoints do
		table.insert(spawnPoints, p)
	end

	-- subtle materials on the buildings' plain plastic (World.Surfaces); materials only, no new parts
	local S = World.Surfaces
	local mats = Enum.Material :: any
	for _, p in buildings:GetDescendants() do
		if
			not (
				p:IsA("BasePart")
				and p.Material == Enum.Material.SmoothPlastic
				and p.Transparency == 0
			)
		then
			continue
		end
		local size = p.Size
		if math.max(size.X, size.Y, size.Z) < S.MinSize then
			continue
		end
		local c = p.Color
		local light = (c.R + c.G + c.B) / 3
		local flat = size.Y < S.RoofThickness and size.X >= S.RoofWidth and size.Z >= S.RoofWidth
		if flat and light >= S.MidFrom then
			p.Material = mats[S.Roof]
		elseif light >= S.LightFrom then
			p.Material = mats[S.Light]
		elseif light >= S.MidFrom then
			p.Material = mats[S.Mid]
		elseif size.Y >= S.MinSize then
			p.Material = mats[S.Dark]
		end
	end

	-- streaming: a building or prop arrives whole (smashing, collapses and rooms read all its parts)
	for _, folder in { buildings, props } do
		for _, m in folder:GetChildren() do
			if m:IsA("Model") and m.ModelStreamingMode == Enum.ModelStreamingMode.Default then
				m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			end
		end
	end
	-- terrain decoration grass grows up through parts and meshes lying on the ground, so: the whole city grid's
	-- terrain (roads, sidewalks, slabs and lawn parts over it) turns to Asphalt, which is tinted grass colour and
	-- grows no blades; outside it, so does the terrain under every flat ground-level part (pads, car parks,
	-- plazas, the invisible parts the ring road is driven on). Lawns of grass parts and the open country keep
	-- their blades. (Road meshes are left out of the second pass: each covers a 512-stud square of fields.)
	local GU = World.GrassUnder
	local terrain = Terra.terrain
	local edge = World.Map.SidewalkWidth + GU.CityMargin
	terrain:ReplaceMaterial(
		Region3.new(
			Vector3.new(x0 - edge, -16, z0 - edge),
			Vector3.new(x0 + spanX + edge, 4, z0 + spanZ + edge)
		):ExpandToGrid(4),
		4,
		Enum.Material.Grass,
		Enum.Material.Asphalt
	)
	for _, p in map:GetDescendants() do
		if
			not p:IsA("BasePart")
			or p:IsA("MeshPart")
			or (p.Transparency >= 1 and not p.CanCollide)
			or p.Material == Enum.Material.Grass
			or p.Material == Enum.Material.LeafyGrass
		then
			continue
		end
		local size, cf = p.Size, p.CFrame
		local half = Vector3.new(
			math.abs(cf.XVector.X) * size.X
				+ math.abs(cf.YVector.X) * size.Y
				+ math.abs(cf.ZVector.X) * size.Z,
			math.abs(cf.XVector.Y) * size.X
				+ math.abs(cf.YVector.Y) * size.Y
				+ math.abs(cf.ZVector.Y) * size.Z,
			math.abs(cf.XVector.Z) * size.X
				+ math.abs(cf.YVector.Z) * size.Y
				+ math.abs(cf.ZVector.Z) * size.Z
		) / 2
		local lo, hi = cf.Position - half, cf.Position + half
		if lo.Y > GU.MaxBottom or hi.Y > GU.MaxTop then
			continue
		end
		if
			lo.X >= x0 - edge
			and hi.X <= x0 + spanX + edge
			and lo.Z >= z0 - edge
			and hi.Z <= z0 + spanZ + edge
		then
			continue -- the city grid is done above
		end
		Terra.run("grass", clearGrassUnder, size, cf, lo, hi)
		Pace.step()
	end

	Terra.finish()

	-- far stand-ins for the buildings (always loaded; the client hides each while its building is here)
	SkylineKit.build(map, buildings)
	-- boats, the lighthouse beam and the beaches' foam (Config/Sea)
	SeaKit.build(map, static, outskirts.seaEdge, outskirts.lamp)
	map.Parent = workspace
	return {
		buildings = buildings,
		props = props,
		walkPoints = walkPoints,
		spawnPoints = spawnPoints,
		crowdPoints = crowdPoints,
		places = places,
		grid = {
			blocksX = M.BlocksX,
			blocksZ = M.BlocksZ,
			block = B,
			road = R,
			sidewalk = M.SidewalkWidth,
			x0 = x0,
			z0 = z0,
		},
	}
end

-- The terrain bake, after a change to the map (the server warns "the baked terrain is out of date"): in Studio,
-- Edit mode, in the command bar: require(game.ServerScriptService.Server.MapBuilder).bake(). It builds the map
-- with all its terrain drawn, then keeps only the terrain, labelled with its fingerprint. Save the place, then
-- `lune run tools/lune/bake_terrain <saved .rbxl> assets/Terrain.rbxm`.
function MapBuilder.bake(): string
	MapBuilder.build(true)
	local map = workspace:FindFirstChild("Map")
	if map then
		map:Destroy()
	end
	return workspace.Terrain:GetAttribute(Terra.ATTRIBUTE) :: string
end

return MapBuilder
