--!strict
-- Builds the world from World.Map at server start (same seed, same city every time):
-- an 8x8 city grid with wide roads, destructible chunked buildings, plazas and parks full of NPC walk points,
-- parking lots with kickers, a highway ring, a stunt park (east), a container port (west) and desert dunes (south).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Config.World)

local MapBuilder = {}
local M = World.Map

export type Result = {
	buildings: Folder,
	walkPoints: { Vector3 },
	spawnPoints: { Vector3 },
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
local WALLS = {
	Color3.fromRGB(232, 214, 184),
	Color3.fromRGB(200, 110, 90),
	Color3.fromRGB(150, 170, 190),
	Color3.fromRGB(240, 236, 226),
	Color3.fromRGB(170, 200, 170),
	Color3.fromRGB(214, 160, 110),
	Color3.fromRGB(120, 130, 150),
}
local CONTAINERS = {
	Color3.fromRGB(190, 60, 50),
	Color3.fromRGB(40, 100, 170),
	Color3.fromRGB(230, 160, 40),
	Color3.fromRGB(60, 140, 90),
	Color3.fromRGB(150, 150, 155),
}

local random = Random.new(M.Seed)

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

-- a building made of chunks: wall panels with windows per floor, floor slabs in tiles, a roof
local function building(
	parent: Folder,
	centre: Vector3,
	w: number,
	d: number,
	floors: number,
	color: Color3,
	name: string
)
	local model = Instance.new("Model")
	model.Name = name
	local FH, PW, T = M.FloorHeight, M.PanelWidth, M.WallThickness
	local function side(origin: Vector3, along: Vector3, outward: Vector3, length: number)
		local n = math.max(1, math.floor(length / PW + 0.5))
		local pw = length / n
		for f = 0, floors - 1 do
			local y0 = centre.Y + f * FH
			for i = 0, n - 1 do
				local mid = origin + along * ((i + 0.5) * pw)
				local cf = CFrame.lookAt(mid, mid + outward)
				if f == 0 then
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
	local walkPoints: { Vector3 } = {}
	local spawnPoints: { Vector3 } = {}

	local old = workspace:FindFirstChild("Baseplate")
	if old then
		old:Destroy()
	end

	local G = M.GroundSize
	part(static, Vector3.new(G, 20, G), CFrame.new(0, -10, 0), COLORS.grass, Enum.Material.Grass)
	for _, s in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local wall = part(
			static,
			Vector3.new(if s[1] ~= 0 then 10 else G, 60, if s[2] ~= 0 then 10 else G),
			CFrame.new(s[1] * G / 2, 30, s[2] * G / 2),
			COLORS.concrete
		)
		wall.Transparency = 0.6
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
		part(static, Vector3.new(0.8, 1, spanZ), CFrame.new(x, -0.35, 0), COLORS.line)
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
		part(static, Vector3.new(spanX, 1, 0.8), CFrame.new(0, -0.33, z), COLORS.line)
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

	-- blocks
	local centreI, centreJ = math.floor(M.BlocksX / 2), math.floor(M.BlocksZ / 2)
	local count = 0
	for i = 0, M.BlocksX - 1 do
		for j = 0, M.BlocksZ - 1 do
			local cx = x0 + R + i * pitch + B / 2
			local cz = z0 + R + j * pitch + B / 2
			local centre = Vector3.new(cx, 0, cz)
			-- sidewalk ring (flush, so vehicles roll straight over it) with walk points
			local SW = M.SidewalkWidth
			part(
				static,
				Vector3.new(B, 1, B),
				CFrame.new(cx, -0.42, cz),
				COLORS.sidewalk,
				Enum.Material.Concrete
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
			local roll = random:NextNumber()
			if i == centreI and j == centreJ then
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
					sp.CFrame =
						CFrame.new(cx + (s % 2 - 0.5) * 60, 0, cz + (math.floor(s / 2) - 0.5) * 60)
					sp.Color = COLORS.ramp
					sp.Material = Enum.Material.SmoothPlastic
					sp.Duration = 0
					sp.Parent = static
				end
				local f = Instance.new("Part")
				f.Shape = Enum.PartType.Cylinder
				f.Anchored = true
				f.Size = Vector3.new(4, 40, 40)
				f.CFrame = CFrame.new(cx, 1.5, cz) * CFrame.Angles(0, 0, math.pi / 2)
				f.Color = COLORS.concrete
				f.Parent = static
				for k = 1, 16 do
					local a = k / 16 * math.pi * 2
					table.insert(
						walkPoints,
						centre + Vector3.new(math.cos(a) * 60, 0.5, math.sin(a) * 60)
					)
				end
			elseif distFromCentre < 2.5 and roll < 0.8 or roll < 0.35 then
				-- downtown towers
				local floors = if distFromCentre < 2.5
					then random:NextInteger(5, 9)
					else random:NextInteger(3, 5)
				local w = random:NextNumber(0.55, 0.8) * inner
				local d = random:NextNumber(0.55, 0.8) * inner
				count += 1
				building(
					buildings,
					centre,
					w,
					d,
					floors,
					WALLS[random:NextInteger(1, #WALLS)],
					"Tower" .. count
				)
			elseif roll < 0.55 then
				-- a row of low shops
				local n = random:NextInteger(2, 3)
				local w = inner / n - 8
				for k = 0, n - 1 do
					count += 1
					local c = centre
						+ Vector3.new(-inner / 2 + (k + 0.5) * inner / n, 0, -inner * 0.15)
					building(
						buildings,
						c,
						w,
						inner * 0.55,
						random:NextInteger(1, 3),
						WALLS[random:NextInteger(1, #WALLS)],
						"Shop" .. count
					)
				end
				for k = 0, 5 do
					table.insert(
						walkPoints,
						centre + Vector3.new(-inner / 2 + (k + 0.5) * inner / 6, 0.5, inner * 0.32)
					)
				end
			elseif roll < 0.72 then
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
				for _ = 1, 10 do
					table.insert(
						walkPoints,
						centre
							+ Vector3.new(
								random:NextNumber(-inner / 2.5, inner / 2.5),
								0.5,
								random:NextNumber(-inner / 2.5, inner / 2.5)
							)
					)
				end
				ramp(static, centre + Vector3.new(-30, 0, 20), Vector3.new(1, 0, 0), 24, 7, 30)
			elseif roll < 0.86 then
				-- plaza: busy with people
				part(
					static,
					Vector3.new(inner, 1, inner),
					CFrame.new(cx, -0.38, cz),
					COLORS.plaza,
					Enum.Material.Pavement
				)
				for _ = 1, 22 do
					table.insert(
						walkPoints,
						centre
							+ Vector3.new(
								random:NextNumber(-inner / 2.2, inner / 2.2),
								0.5,
								random:NextNumber(-inner / 2.2, inner / 2.2)
							)
					)
				end
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
		end
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
	for _ = 1, 40 do
		table.insert(
			walkPoints,
			park + Vector3.new(random:NextNumber(-400, 400), 0.5, random:NextNumber(120, 220))
		)
	end

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
	return { buildings = buildings, walkPoints = walkPoints, spawnPoints = spawnPoints }
end

return MapBuilder
