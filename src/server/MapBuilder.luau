--!strict
-- Builds the world from World.Map at server start (same seed, same city every time):
-- an 8x8 city grid with wide roads; blocks from the city plan (offices, homes, the burger place, the parcel
-- warehouse, shops, parks, plazas) with destructible chunked buildings and places for the crowd,
-- parking lots with kickers; the ground, the highway ring and the zones beyond it come from OutskirtsKit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingConfig = require(ReplicatedStorage.Shared.Config.Buildings)
local CityPlan = require(ReplicatedStorage.Shared.Rules.CityPlan)
local Crowd = require(ReplicatedStorage.Shared.Config.Crowd)
local HouseRules = require(ReplicatedStorage.Shared.Rules.Houses)
local Houses = require(ReplicatedStorage.Shared.Config.Houses)
local Districts = require(ReplicatedStorage.Shared.Rules.Districts)
local Parks = require(ReplicatedStorage.Shared.Config.Parks)
local Leaderboards = require(ReplicatedStorage.Shared.Config.Leaderboards)
local Routes = require(ReplicatedStorage.Shared.Rules.Routes)
local Streets = require(ReplicatedStorage.Shared.Config.Streets)
local Tiles = require(ReplicatedStorage.Shared.Rules.Tiles)
local World = require(ReplicatedStorage.Shared.Config.World)
local Greenery = require(script.Parent.Greenery)
local HouseKit = require(script.Parent.HouseKit)
local OutskirtsKit = require(script.Parent.OutskirtsKit)
local Places = require(script.Parent.Places)
local RampKit = require(script.Parent.RampKit)
local StreetKit = require(script.Parent.StreetKit)
local TownKit = require(script.Parent.TownKit)

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

-- the spawn plaza's road paint: dashed yellow lanes out from the fountain, numbered white parking bays
-- round the four spawn pads, and big white chevrons near each edge pointing out to the streets
local function paintPlaza(parent: Instance, cx: number, cz: number, inner: number)
	local folder = Instance.new("Folder")
	folder.Name = "Paint"
	folder.Parent = parent
	local y = 0.12 + World.Look.PaintLift
	local half = inner / 2
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local along = if math.abs(dir.X) > 0 then Vector2.new(4, 0.8) else Vector2.new(0.8, 4)
		for d = 24, half - 20, 7 do
			paint(folder, along, CFrame.new(cx + dir.X * d, y, cz + dir.Z * d), PAINT_YELLOW)
		end
		-- a chevron of two bars pointing outwards
		local tip = Vector3.new(cx, y, cz) + dir * (half - 12)
		local yaw = math.atan2(dir.X, dir.Z) + math.pi -- turned so the point faces the street
		for _, side in { -1, 1 } do
			local cf = CFrame.new(tip)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.new(side * 3.2, 0, -3.2)
				* CFrame.Angles(0, side * math.rad(45), 0)
			paint(folder, Vector2.new(2, 11), cf, PAINT_WHITE)
		end
	end
	for s = 0, 3 do
		local px = cx + (s % 2 - 0.5) * 60
		local pz = cz + (math.floor(s / 2) - 0.5) * 60
		for _, edge in
			{
				{ 0, -7.5, 15.6, 0.7 },
				{ 0, 7.5, 15.6, 0.7 },
				{ -7.5, 0, 0.7, 15.6 },
				{ 7.5, 0, 0.7, 15.6 },
			}
		do
			paint(
				folder,
				Vector2.new(edge[3], edge[4]),
				CFrame.new(px + edge[1], y, pz + edge[2]),
				PAINT_WHITE
			)
		end
		-- the bay number painted just outside the pad, on the side away from the fountain
		local out = Vector3.new(px - cx, 0, pz - cz).Unit
		local tag = paint(
			folder,
			Vector2.new(9, 6),
			CFrame.new(px + out.X * 13, y, pz + out.Z * 13),
			PAINT_WHITE
		)
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
		label.Text = string.format("%02d", s + 1)
		label.TextScaled = true
		label.TextColor3 = PAINT_WHITE
		label.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
		label.Rotation = math.deg(math.atan2(out.X, out.Z)) + 180 -- reads from the pad
		label.Parent = gui
	end
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
	w:SetAttribute("Launch", true) -- throws cars up off its lip (client Stunts)
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

function MapBuilder.build(): Result
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

	-- city grid
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
			Enum.Material.Asphalt
		)
	end
	for j = 0, M.BlocksZ do
		local z = z0 + R / 2 + j * pitch
		part(
			static,
			Vector3.new(spanX, 1, R),
			CFrame.new(0, -0.38, z),
			COLORS.road,
			Enum.Material.Asphalt
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
	for i = 0, M.BlocksX - 1 do
		for j = 0, M.BlocksZ - 1 do
			local cx = x0 + R + i * pitch + B / 2
			local cz = z0 + R + j * pitch + B / 2
			local centre = Vector3.new(cx, 0, cz)
			local district = Districts.of(i, j, M.BlocksX, M.BlocksZ)
			local style = (Streets.Districts :: any)[district] :: Streets.District
			local function wallColour(): Color3
				local c = style.walls[random:NextInteger(1, #style.walls)]
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
				-- spawn plaza
				part(
					static,
					Vector3.new(inner, 1, inner),
					CFrame.new(cx, -0.38, cz),
					COLORS.plaza,
					Enum.Material.Pavement
				)
				for s = 0, 3 do
					local sp = Instance.new("SpawnLocation")
					sp.Anchored = true
					sp.Size = Vector3.new(10, 1, 10)
					sp.CFrame = CFrame.new(
						cx + (s % 2 - 0.5) * 60,
						-0.36,
						cz + (math.floor(s / 2) - 0.5) * 60
					)
					sp.Color = COLORS.ramp
					sp.Material = Enum.Material.SmoothPlastic
					sp.Duration = 0
					sp.Parent = static
				end
				local f = Instance.new("Part")
				f.Shape = Enum.PartType.Cylinder
				f.Anchored = true
				f.Size = Vector3.new(0.6, 40, 40) -- flat, so new drivers don't beach on it
				f.CFrame = CFrame.new(cx, 0.05, cz) * CFrame.Angles(0, 0, math.pi / 2)
				f.Color = COLORS.concrete
				f.Parent = static
				paintPlaza(static, cx, cz, inner)
				-- leaderboard stands on the north sidewalk, facing the plaza (the client draws the boards)
				local boards = Instance.new("Folder")
				boards.Name = "Boards"
				boards.Parent = static
				-- a sign gantry over them: a road-yellow beam on two black posts
				local gz = cz - B / 2 + 5
				part(boards, Vector3.new(196, 3, 2.4), CFrame.new(cx, 55, gz), PAINT_YELLOW)
				for _, side in { -1, 1 } do
					part(
						boards,
						Vector3.new(3, 56, 3),
						CFrame.new(cx + side * 96, 27, gz),
						PAINT_BLACK
					)
				end
				for k, board in Leaderboards.Boards do
					local bx = cx + (k - 2) * 62
					local bz = cz - B / 2 + 6
					local face = part(
						boards,
						Vector3.new(52, 46, 1.2),
						CFrame.lookAt(Vector3.new(bx, 30, bz), Vector3.new(bx, 30, bz + 10)),
						Color3.fromRGB(24, 24, 38)
					)
					face.Name = "Board_" .. board.key
					for _, side in { -1, 1 } do
						part(
							boards,
							Vector3.new(2, 8, 2),
							CFrame.new(bx + side * 20, 3, bz - 0.5),
							COLORS.concrete
						)
					end
				end
				-- the first crowd: right in front of where new players appear
				for k = 1, 24 do
					local a = k / 24 * math.pi * 2
					local r = if k % 2 == 0 then 50 else 80
					local p = centre + Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r)
					table.insert(walkPoints, p)
					table.insert(crowdPoints, p)
				end
				addPlace(Places.open("spawn", centre, crowdPoints), i, j)
			elseif kind == "office" then
				-- office towers in the town style: a stone lobby with a door, window bands, the name on the roof
				local floors = if distFromCentre < 2.5
					then random:NextInteger(5, 9)
					else random:NextInteger(3, 5)
				local fp = BuildingConfig.Office.Footprint
				local w = random:NextNumber(fp[1], fp[2]) * inner
				local d = random:NextNumber(fp[1], fp[2]) * inner
				count += 1
				offices += 1
				local out = SIDES[random:NextInteger(1, 4)]
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
				end
				local wall = wallColour()
				local look = (BuildingConfig.Office.Looks :: any)[district] :: BuildingConfig.OfficeLook
				local colours = {
					wall = wall,
					trim = rgb(look.trim),
					accent = rgb(style.accent),
					roof = rgb(look.roof),
					stone = rgb(look.stone),
				}
				local model, door =
					TownKit.office(buildings, tower, w, d, floors, colours, "Office" .. count, out)
				-- the company name and a parody billboard stand on the roof, behind the parapet
				local top = floors * M.FloorHeight + BuildingConfig.Office.Parapet + 1
				local name = Crowd.OfficeNames[(offices - 1) % #Crowd.OfficeNames + 1]
				local width = math.abs(Vector3.new(-out.Z, 0, out.X):Dot(Vector3.new(w, 0, d)))
				addPlace(Places.office(model, door, out, width, top, name), i, j)
				local boardAt = tower - out * 10 + Vector3.new(0, top + 14, 0)
				local ad = Streets.Billboards[random:NextInteger(1, #Streets.Billboards)]
				Places.sign(
					model,
					Vector3.new(34, 11, 1),
					CFrame.lookAt(boardAt, boardAt + out),
					ad,
					Color3.fromRGB(250, 250, 245),
					colours.accent:Lerp(Color3.new(0, 0, 0), 0.4),
					true
				)
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
				end
				local yard = inner - SH.Setback - SH.Depth - 4
				part(
					static,
					Vector3.new(inner, 1, yard),
					CFrame.new(cx, -0.39, cz - inner / 2 + yard / 2),
					COLORS.road,
					Enum.Material.Asphalt
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
						end
					end
				end
				for _ = 1, Parks.HomeTrees do
					local at = Vector3.new(
						random:NextNumber(-inner / 2.4, inner / 2.4),
						0,
						random:NextNumber(-20, 20)
					)
					Greenery.tree(props, centre + at, random)
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
			end
			-- the district's wall material on the walls of what was just built here
			local wallMaterial = (Enum.Material :: any)[style.wallMaterial]
			local children = buildings:GetChildren()
			for n = firstBuilding, #children do
				for _, p in children[n]:GetDescendants() do
					if p:IsA("BasePart") and p.Material == Enum.Material.SmoothPlastic then
						for _, c in style.walls do
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

	-- the street kit: paint, furniture, bus stops
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

	-- lighting and look
	local Lighting = game:GetService("Lighting")
	local look = World.Look
	Lighting.ClockTime = look.ClockTime
	Lighting.Brightness = look.Brightness
	Lighting.ExposureCompensation = look.Exposure
	Lighting.Ambient = rgb(look.Ambient)
	Lighting.OutdoorAmbient = rgb(look.OutdoorAmbient)
	Lighting.ShadowSoftness = look.ShadowSoftness
	Lighting.EnvironmentDiffuseScale = look.DiffuseScale
	Lighting.EnvironmentSpecularScale = look.SpecularScale
	local air = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	air.Density = look.AirDensity
	air.Offset = look.AirOffset
	air.Haze = look.AirHaze
	air.Glare = look.AirGlare
	air.Color = rgb(look.AirColor)
	air.Decay = rgb(look.AirDecay)
	air.Parent = Lighting
	local grade = (Lighting:FindFirstChild("Grade") :: ColorCorrectionEffect?)
		or Instance.new("ColorCorrectionEffect")
	grade.Name = "Grade"
	grade.Saturation = look.Saturation
	grade.Contrast = look.Contrast
	grade.Brightness = look.GradeBrightness
	grade.TintColor = rgb(look.Tint)
	grade.Parent = Lighting
	local bloom = (Lighting:FindFirstChild("Bloom") :: BloomEffect?) or Instance.new("BloomEffect")
	bloom.Name = "Bloom"
	bloom.Intensity = look.BloomIntensity
	bloom.Size = look.BloomSize
	bloom.Threshold = look.BloomThreshold
	bloom.Parent = Lighting

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

return MapBuilder
