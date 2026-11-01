--!strict
-- Builds the world from World.Map at server start (same seed, same city every time):
-- an 8x8 city grid with wide roads; blocks from the city plan (offices, homes, the burger place, the parcel
-- warehouse, shops, parks, plazas) with destructible chunked buildings and places for the crowd,
-- parking lots with kickers, a highway ring, a stunt park (east), a container port (west) and desert dunes (south).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CityPlan = require(ReplicatedStorage.Shared.Rules.CityPlan)
local Crowd = require(ReplicatedStorage.Shared.Config.Crowd)
local HouseRules = require(ReplicatedStorage.Shared.Rules.Houses)
local Houses = require(ReplicatedStorage.Shared.Config.Houses)
local Districts = require(ReplicatedStorage.Shared.Rules.Districts)
local Leaderboards = require(ReplicatedStorage.Shared.Config.Leaderboards)
local Routes = require(ReplicatedStorage.Shared.Rules.Routes)
local Streets = require(ReplicatedStorage.Shared.Config.Streets)
local Tiles = require(ReplicatedStorage.Shared.Rules.Tiles)
local World = require(ReplicatedStorage.Shared.Config.World)
local HouseKit = require(script.Parent.HouseKit)
local Places = require(script.Parent.Places)
local StreetKit = require(script.Parent.StreetKit)

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
	glass = Color3.fromRGB(96, 140, 170),
	trunk = Color3.fromRGB(110, 78, 52),
	leaves = Color3.fromRGB(70, 140, 70),
}
local CONTAINERS = {
	Color3.fromRGB(190, 60, 50),
	Color3.fromRGB(40, 100, 170),
	Color3.fromRGB(230, 160, 40),
	Color3.fromRGB(60, 140, 90),
	Color3.fromRGB(150, 150, 155),
}

local random = Random.new(M.Seed)

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
	return w
end

local function tree(parent: Instance, at: Vector3)
	local h = random:NextNumber(10, 16)
	part(parent, Vector3.new(1.6, h, 1.6), CFrame.new(at + Vector3.new(0, h / 2, 0)), COLORS.trunk)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	local r = random:NextNumber(10, 15)
	ball.Size = Vector3.new(r, r, r)
	ball.CFrame = CFrame.new(at + Vector3.new(0, h + r * 0.3, 0))
	ball.Color = COLORS.leaves
	ball.Material = Enum.Material.SmoothPlastic
	ball.Parent = parent
end

-- a building made of chunks: wall panels with windows per floor, floor slabs in tiles, a roof.
-- With `front` (a flat unit vector), that face gets a glass ground floor and a doorway in the middle panel;
-- returns the model and the middle of the doorway at ground level.
local function building(
	parent: Folder,
	centre: Vector3,
	w: number,
	d: number,
	floors: number,
	color: Color3,
	name: string,
	front: Vector3?
): (Model, Vector3?)
	local model = Instance.new("Model")
	model.Name = name
	local FH, PW, T = M.FloorHeight, M.PanelWidth, M.WallThickness
	local door: Vector3? = nil
	local function side(origin: Vector3, along: Vector3, outward: Vector3, length: number)
		local n = math.max(1, math.floor(length / PW + 0.5))
		local pw = length / n
		local isFront = front ~= nil and outward:Dot(front) > 0.9
		local doorAt = n // 2
		for f = 0, floors - 1 do
			local y0 = centre.Y + f * FH
			for i = 0, n - 1 do
				local mid = origin + along * ((i + 0.5) * pw)
				local cf = CFrame.lookAt(mid, mid + outward)
				if f == 0 and isFront and i == doorAt then
					-- doorway: only the lintel
					part(
						model,
						Vector3.new(pw, FH - 8.5, T),
						cf + Vector3.new(0, y0 + 8.5 + (FH - 8.5) / 2, 0),
						color
					)
					door = Vector3.new(mid.X, 0, mid.Z)
				elseif f == 0 and isFront then
					-- lobby or shop window
					part(model, Vector3.new(pw, 1.5, T), cf + Vector3.new(0, y0 + 0.75, 0), color)
					local lobby = part(
						model,
						Vector3.new(pw, FH - 4.5, T * 0.6),
						cf + Vector3.new(0, y0 + 1.5 + (FH - 4.5) / 2, 0),
						COLORS.glass,
						Enum.Material.Glass
					)
					lobby.Transparency = 0.25
					lobby:SetAttribute("Glass", true)
					part(model, Vector3.new(pw, 3, T), cf + Vector3.new(0, y0 + FH - 1.5, 0), color)
				elseif f == 0 then
					part(model, Vector3.new(pw, FH, T), cf + Vector3.new(0, y0 + FH / 2, 0), color)
				else
					-- sill below, window above
					local sill = FH * 0.4
					part(
						model,
						Vector3.new(pw, sill, T),
						cf + Vector3.new(0, y0 + sill / 2, 0),
						color
					)
					local glass = part(
						model,
						Vector3.new(pw, FH - sill, T * 0.6),
						cf + Vector3.new(0, y0 + sill + (FH - sill) / 2, 0),
						COLORS.glass,
						Enum.Material.Glass
					)
					glass.Transparency = 0.25
					glass:SetAttribute("Glass", true)
				end
			end
		end
	end
	local hw, hd = w / 2, d / 2
	local base = Vector3.new(centre.X, 0, centre.Z)
	side(base + Vector3.new(-hw, 0, -hd), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), w)
	side(base + Vector3.new(-hw, 0, hd), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), w)
	side(
		base + Vector3.new(-hw, 0, -hd + T),
		Vector3.new(0, 0, 1),
		Vector3.new(-1, 0, 0),
		d - 2 * T
	)
	side(base + Vector3.new(hw, 0, -hd + T), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), d - 2 * T)
	-- floors and roof in tiles about 45 studs across
	local tx, tz = math.max(1, math.floor(w / 45 + 0.5)), math.max(1, math.floor(d / 45 + 0.5))
	for f = 1, floors do
		local y = centre.Y + f * FH - 0.6
		for i = 0, tx - 1 do
			for j = 0, tz - 1 do
				local cx = centre.X - hw + (i + 0.5) * w / tx
				local cz = centre.Z - hd + (j + 0.5) * d / tz
				part(
					model,
					Vector3.new(w / tx, 1.2, d / tz),
					CFrame.new(cx, y, cz),
					if f == floors then color:Lerp(Color3.new(0, 0, 0), 0.25) else COLORS.concrete
				)
			end
		end
	end
	model.Parent = parent
	return model, door
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

	local G = M.GroundSize
	part(static, Vector3.new(G, 20, G), CFrame.new(0, -10, 0), COLORS.grass, Enum.Material.Grass)
	for _, s in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		part(
			static,
			Vector3.new(if s[1] ~= 0 then 10 else G, 60, if s[2] ~= 0 then 10 else G),
			CFrame.new(s[1] * G / 2, 30, s[2] * G / 2),
			COLORS.concrete,
			nil,
			0.6
		)
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

	-- highway ring around the city, joined to every grid road
	local ring = math.max(spanX, spanZ) / 2 + 220
	local RW = 90
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
	end
	for i = 0, M.BlocksX do
		local x = x0 + R / 2 + i * pitch
		local len = ring - spanZ / 2
		part(
			static,
			Vector3.new(R, 1, len),
			CFrame.new(x, -0.4, spanZ / 2 + len / 2),
			COLORS.road,
			Enum.Material.Asphalt
		)
		part(
			static,
			Vector3.new(R, 1, len),
			CFrame.new(x, -0.4, -spanZ / 2 - len / 2),
			COLORS.road,
			Enum.Material.Asphalt
		)
	end
	for j = 0, M.BlocksZ do
		local z = z0 + R / 2 + j * pitch
		local len = ring - spanX / 2
		part(
			static,
			Vector3.new(len, 1, R),
			CFrame.new(spanX / 2 + len / 2, -0.38, z),
			COLORS.road,
			Enum.Material.Asphalt
		)
		part(
			static,
			Vector3.new(len, 1, R),
			CFrame.new(-spanX / 2 - len / 2, -0.38, z),
			COLORS.road,
			Enum.Material.Asphalt
		)
	end

	-- blocks: what stands where comes from the city plan
	local centreI, centreJ = math.floor(M.BlocksX / 2), math.floor(M.BlocksZ / 2)
	local plan = CityPlan.plan(M.BlocksX, M.BlocksZ, M.Seed)
	local places: { Places.Place } = {}
	local count, offices = 0, 0
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
			local style = (Streets.Districts :: any)[Districts.of(
					i,
					j,
					M.BlocksX,
					M.BlocksZ
				)] :: Streets.District
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
				-- leaderboard stands on the north sidewalk, facing the plaza (the client draws the boards)
				local boards = Instance.new("Folder")
				boards.Name = "Boards"
				boards.Parent = static
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
				-- office towers: a glass lobby with a door, the company name on the roof
				local floors = if distFromCentre < 2.5
					then random:NextInteger(5, 9)
					else random:NextInteger(3, 5)
				local w = random:NextNumber(0.55, 0.8) * inner
				local d = random:NextNumber(0.55, 0.8) * inner
				count += 1
				offices += 1
				local out = SIDES[random:NextInteger(1, 4)]
				local wall = wallColour()
				local model, door =
					building(buildings, centre, w, d, floors, wall, "Office" .. count, out)
				if door then
					local name = Crowd.OfficeNames[(offices - 1) % #Crowd.OfficeNames + 1]
					local width = math.abs(Vector3.new(-out.Z, 0, out.X):Dot(Vector3.new(w, 0, d)))
					local trim = wall:Lerp(Color3.new(0, 0, 0), 0.35)
					addPlace(
						Places.office(model, door, out, width, floors * M.FloorHeight, name, trim),
						i,
						j
					)
				end
				-- a parody billboard on the roof, facing the street with the door
				local top = floors * M.FloorHeight
				local boardAt = centre - out * 10 + Vector3.new(0, top + 14, 0)
				local ad = Streets.Billboards[random:NextInteger(1, #Streets.Billboards)]
				local accent = Color3.fromRGB(style.accent[1], style.accent[2], style.accent[3])
				Places.sign(
					model,
					Vector3.new(34, 11, 1),
					CFrame.lookAt(boardAt, boardAt + out),
					ad,
					Color3.fromRGB(250, 250, 245),
					accent:Lerp(Color3.new(0, 0, 0), 0.4),
					true
				)
				local along = Vector3.new(-out.Z, 0, out.X)
				for _, e in { -12, 12 } do
					part(
						model,
						Vector3.new(1, 9, 1),
						CFrame.new(centre - out * 10 + along * e + Vector3.new(0, top + 4.5, 0)),
						COLORS.concrete
					)
				end
			elseif kind == "shops" then
				-- a row of low shops
				local n = random:NextInteger(2, 3)
				local w = inner / n - 8
				for k = 0, n - 1 do
					count += 1
					local c = centre
						+ Vector3.new(-inner / 2 + (k + 0.5) * inner / n, 0, -inner * 0.15)
					local shop, door = building(
						buildings,
						c,
						w,
						inner * 0.55,
						random:NextInteger(1, 3),
						wallColour(),
						"Shop" .. count,
						Vector3.new(0, 0, 1)
					)
					if door then
						addPlace(Places.shop(door, Vector3.new(0, 0, 1), "Shop" .. count), i, j)
						-- a striped awning over the shop front
						local accent =
							Color3.fromRGB(style.accent[1], style.accent[2], style.accent[3])
						local front = Vector3.new(c.X, 0, door.Z)
						part(
							shop,
							Vector3.new(w * 0.94, 0.5, 5),
							CFrame.new(front + Vector3.new(0, M.FloorHeight - 2.5, 2.5)),
							accent
						)
						part(
							shop,
							Vector3.new(w * 0.94, 1.2, 0.3),
							CFrame.new(front + Vector3.new(0, M.FloorHeight - 3.1, 5)),
							Color3.new(1, 1, 1)
						)
					end
				end
				for k = 0, 5 do
					table.insert(
						walkPoints,
						centre + Vector3.new(-inner / 2 + (k + 0.5) * inner / 6, 0.5, inner * 0.32)
					)
				end
			elseif kind == "park" then
				-- park with trees and a kicker
				part(
					static,
					Vector3.new(inner, 1, inner),
					CFrame.new(cx, -0.39, cz),
					COLORS.grass,
					Enum.Material.Grass
				)
				for _ = 1, 9 do
					tree(
						static,
						centre
							+ Vector3.new(
								random:NextNumber(-inner / 2.3, inner / 2.3),
								0,
								random:NextNumber(-inner / 2.3, inner / 2.3)
							)
					)
				end
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
				ramp(static, centre + Vector3.new(-30, 0, 20), Vector3.new(1, 0, 0), 24, 7, 30)
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
				for _ = 1, 4 do
					tree(
						static,
						centre
							+ Vector3.new(
								random:NextNumber(-inner / 3, inner / 3),
								0,
								random:NextNumber(-inner / 3, inner / 3)
							)
					)
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
				local district = Districts.of(i, j, M.BlocksX, M.BlocksZ)
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
				for _ = 1, 3 do
					local at = Vector3.new(
						random:NextNumber(-inner / 2.4, inner / 2.4),
						0,
						random:NextNumber(-20, 20)
					)
					tree(static, centre + at)
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
				-- the parcel warehouse: loading bays toward town, trucks backed up to them
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

	-- stunt park (east)
	local sx = ring + RW / 2 + 520
	local park = Vector3.new(sx, 0, 0)
	part(
		static,
		Vector3.new(900, 1, 1100),
		CFrame.new(sx, -0.42, 0),
		COLORS.concrete,
		Enum.Material.Concrete
	)
	part(
		static,
		Vector3.new(sx - ring, 1, 80),
		CFrame.new((ring + sx) / 2 - 200, -0.4, 0),
		COLORS.road,
		Enum.Material.Asphalt
	)
	-- mega ramp: a long climb, a gap, a landing slope
	ramp(static, park + Vector3.new(-380, 0, -300), Vector3.new(1, 0, 0), 60, 70, 260)
	local landing =
		ramp(static, park + Vector3.new(220, 0, -300), Vector3.new(-1, 0, 0), 60, 40, 200)
	landing.Color = COLORS.concrete
	-- kickers in a row
	for k = 0, 5 do
		ramp(
			static,
			park + Vector3.new(-350 + k * 120, 0, 0),
			Vector3.new(1, 0, 0),
			28,
			6 + k * 2,
			26 + k * 4
		)
	end
	-- a bowl of quarter ramps
	for _, d in
		{ Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
	do
		ramp(static, park + Vector3.new(0, 0, 330) - d * 180, -d, 160, 30, 50)
	end
	local stuntSpots = {}
	for _ = 1, 40 do
		local p = park + Vector3.new(random:NextNumber(-400, 400), 0.5, random:NextNumber(120, 220))
		table.insert(walkPoints, p)
		table.insert(stuntSpots, p)
	end
	table.insert(places, Places.open("stunt", stuntSpots[1], stuntSpots))

	-- container port (west): stacks are destructible
	local px = -(ring + RW / 2 + 420)
	part(
		static,
		Vector3.new(700, 1, 1000),
		CFrame.new(px, -0.42, 0),
		COLORS.concrete,
		Enum.Material.Concrete
	)
	part(
		static,
		Vector3.new(px + ring, 1, 80),
		CFrame.new((px - ring) / 2 + 150, -0.4, 0),
		COLORS.road,
		Enum.Material.Asphalt
	)
	for row = 0, 5 do
		for col = 0, 3 do
			local stack = Instance.new("Model")
			stack.Name = "Containers"
			local base = Vector3.new(px - 250 + col * 150, 0, -400 + row * 150)
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
			Vector3.new(px + random:NextNumber(-300, 300), 0.5, random:NextNumber(-450, 450))
		)
	end

	-- desert dunes (south)
	local dz = ring + RW / 2 + 500
	part(
		static,
		Vector3.new(1800, 1, 800),
		CFrame.new(0, -0.43, dz),
		COLORS.sand,
		Enum.Material.Sand
	)
	for _ = 1, 26 do
		local at = Vector3.new(random:NextNumber(-800, 800), 0, dz + random:NextNumber(-330, 330))
		local dir = if random:NextNumber() < 0.5 then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
		local up = ramp(
			static,
			at,
			dir,
			random:NextNumber(40, 90),
			random:NextNumber(8, 22),
			random:NextNumber(50, 90)
		)
		up.Color = COLORS.sand
		up.Material = Enum.Material.Sand
	end

	-- lighting and look
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.6
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local a = Instance.new("Atmosphere")
		a.Density = 0.28
		a.Haze = 1.2
		a.Color = Color3.fromRGB(200, 215, 230)
		a.Parent = Lighting
	end

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
