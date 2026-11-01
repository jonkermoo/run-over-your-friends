--!strict
-- The street kit: road paint (double yellows, lane dashes, zebra crossings, stop lines, manholes) and street
-- furniture (lamps, traffic lights, benches, bins, hydrants, parked cars, planter trees, bus shelters),
-- styled by district. Paint is flat and never collides. Furniture goes in the Props folder: each piece is a
-- Model that any vehicle knocks flying (BuildingService puts it back later).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Districts = require(ReplicatedStorage.Shared.Rules.Districts)
local Routes = require(ReplicatedStorage.Shared.Rules.Routes)
local S = require(ReplicatedStorage.Shared.Config.Streets)
local Places = require(script.Parent.Places)

local StreetKit = {}

local WHITE = Color3.fromRGB(240, 240, 236)
local YELLOW = Color3.fromRGB(242, 206, 70)
local DARK = Color3.fromRGB(34, 36, 40)
local METAL = Color3.fromRGB(70, 74, 80)
local Y0 = 0.08

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function block(
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

local function paint(parent: Instance, sx: number, sz: number, x: number, z: number, color: Color3)
	local p =
		block(parent, Vector3.new(sx, S.PaintThick, sz), CFrame.new(x, S.PaintHeight, z), color)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local function prop(folder: Instance, kind: string): Model
	local m = Instance.new("Model")
	m.Name = kind
	m:SetAttribute("Prop", kind)
	m.Parent = folder
	return m
end

local function cylinder(
	parent: Instance,
	height: number,
	dia: number,
	at: Vector3,
	color: Color3
): Part
	local p = block(
		parent,
		Vector3.new(height, dia, dia),
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		color
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

export type Grid = Routes.Grid

-- paint one road segment between two crossings; `alongX` for east-west roads
local function segment(parent: Instance, grid: Grid, centre: Vector3, alongX: boolean)
	local B, R = grid.block, grid.road
	local function put(
		along: number,
		across: number,
		lenAlong: number,
		lenAcross: number,
		color: Color3
	)
		if alongX then
			paint(parent, lenAlong, lenAcross, centre.X + along, centre.Z + across, color)
		else
			paint(parent, lenAcross, lenAlong, centre.X + across, centre.Z + along, color)
		end
	end
	local len = B - 2 * S.EndClear
	put(0, -0.55, len, S.LineWidth, YELLOW)
	put(0, 0.55, len, S.LineWidth, YELLOW)
	local t = -len / 2
	while t + S.DashLength <= len / 2 do
		put(t + S.DashLength / 2, -R / 4, S.DashLength, S.LineWidth, WHITE)
		put(t + S.DashLength / 2, R / 4, S.DashLength, S.LineWidth, WHITE)
		t += S.DashLength + S.DashGap
	end
	-- zebras where the sidewalk crossings run, one at each end
	for _, e in { -1, 1 } do
		local at = e * (B / 2 - S.ZebraInset)
		for s = 0, S.ZebraStripes - 1 do
			put(
				at,
				-R / 2 + (s + 0.5) * R / S.ZebraStripes,
				S.ZebraLength,
				R / S.ZebraStripes * 0.55,
				WHITE
			)
		end
	end
	-- stop lines on the half where traffic arrives (keep right): heading +along stops on one side, -along the other
	local right = if alongX then 1 else -1
	put(B / 2 - S.StopLineInset, right * R / 4, 1.2, R / 2 - 2, WHITE)
	put(-(B / 2 - S.StopLineInset), -right * R / 4, 1.2, R / 2 - 2, WHITE)
end

local function lamp(folder: Instance, foot: Vector3, out: Vector3, color: Color3)
	local m = prop(folder, "Lamp")
	block(
		m,
		Vector3.new(0.6, S.LampHeight, 0.6),
		CFrame.new(foot + Vector3.new(0, S.LampHeight / 2, 0)),
		METAL,
		Enum.Material.Metal
	)
	local headAt = foot + out * 1.6 + Vector3.new(0, S.LampHeight - 0.2, 0)
	block(
		m,
		Vector3.new(1.2, 0.5, 3.6),
		CFrame.lookAt(headAt, headAt + out),
		color,
		Enum.Material.Neon
	)
end

-- a traffic light on a corner: one lamp facing each road; the client cycles them
local function signal(folder: Instance, foot: Vector3, toX: Vector3, toZ: Vector3)
	local m = prop(folder, "Signal")
	block(
		m,
		Vector3.new(0.6, 12, 0.6),
		CFrame.new(foot + Vector3.new(0, 6, 0)),
		METAL,
		Enum.Material.Metal
	)
	block(m, Vector3.new(1.6, 3.6, 1.6), CFrame.new(foot + Vector3.new(0, 13.2, 0)), DARK)
	for _, f in { { toX, "EW" }, { toZ, "NS" } } do
		local dir = f[1] :: Vector3
		local at = foot + dir * 0.85 + Vector3.new(0, 13.2, 0)
		local l = block(
			m,
			Vector3.new(1, 1, 0.2),
			CFrame.lookAt(at, at + dir),
			Color3.fromRGB(60, 200, 90),
			Enum.Material.Neon
		)
		l:SetAttribute("Signal", f[2])
	end
end

local function bench(folder: Instance, at: Vector3, out: Vector3)
	local m = prop(folder, "Bench")
	local cf = CFrame.lookAt(at, at + out)
	block(
		m,
		Vector3.new(6, 0.5, 2),
		cf + Vector3.new(0, 1.6, 0),
		Color3.fromRGB(130, 90, 56),
		Enum.Material.WoodPlanks
	)
	block(
		m,
		Vector3.new(6, 1.6, 0.4),
		cf * CFrame.new(0, 2.6, 1) + Vector3.new(0, 0, 0),
		Color3.fromRGB(130, 90, 56),
		Enum.Material.WoodPlanks
	)
	block(m, Vector3.new(5, 1.4, 1.4), cf + Vector3.new(0, 0.7, 0), METAL, Enum.Material.Metal)
end

local function bin(folder: Instance, at: Vector3)
	local m = prop(folder, "Bin")
	cylinder(m, 3, 2, at + Vector3.new(0, 1.5, 0), Color3.fromRGB(50, 90, 60))
end

local function hydrant(folder: Instance, at: Vector3)
	local m = prop(folder, "Hydrant")
	cylinder(m, 2.4, 1.2, at + Vector3.new(0, 1.2, 0), Color3.fromRGB(210, 40, 36))
	block(
		m,
		Vector3.new(1.6, 0.5, 0.5),
		CFrame.new(at + Vector3.new(0, 1.6, 0)),
		Color3.fromRGB(210, 40, 36)
	)
end

local function parkedCar(folder: Instance, at: Vector3, along: Vector3, color: Color3)
	local m = prop(folder, "ParkedCar")
	local cf = CFrame.lookAt(at, at + along)
	block(m, Vector3.new(6.2, 1.2, 11), cf + Vector3.new(0, 0.7, 0), DARK)
	block(m, Vector3.new(6, 2, 13), cf + Vector3.new(0, 2.1, 0), color)
	block(
		m,
		Vector3.new(5.4, 2.2, 6.5),
		cf * CFrame.new(0, 4.2, 0.8),
		color:Lerp(Color3.new(0, 0, 0), 0.15)
	)
end

local function tree(folder: Instance, at: Vector3)
	local m = prop(folder, "Tree")
	block(
		m,
		Vector3.new(3.2, 1.2, 3.2),
		CFrame.new(at + Vector3.new(0, 0.6, 0)),
		Color3.fromRGB(120, 112, 104),
		Enum.Material.Concrete
	)
	block(
		m,
		Vector3.new(0.9, 9, 0.9),
		CFrame.new(at + Vector3.new(0, 5, 0)),
		Color3.fromRGB(110, 78, 52),
		Enum.Material.Wood
	)
	local crown = block(
		m,
		Vector3.new(8, 8, 8),
		CFrame.new(at + Vector3.new(0, 11, 0)),
		Color3.fromRGB(76, 146, 70),
		Enum.Material.Grass
	)
	crown.Shape = Enum.PartType.Ball
end

local function shelter(folder: Instance, at: Vector3, out: Vector3, accent: Color3)
	local m = prop(folder, "Shelter")
	local cf = CFrame.lookAt(at, at + out)
	block(m, Vector3.new(11, 0.4, 4), cf + Vector3.new(0, 8.2, 0), accent)
	local back = block(
		m,
		Vector3.new(11, 6.5, 0.3),
		cf * CFrame.new(0, 4.6, 1.8),
		Color3.fromRGB(150, 190, 210),
		Enum.Material.Glass
	)
	back.Transparency = 0.4
	block(m, Vector3.new(0.4, 8, 0.4), cf * CFrame.new(-5.2, 4, 1.8), METAL, Enum.Material.Metal)
	block(m, Vector3.new(0.4, 8, 0.4), cf * CFrame.new(5.2, 4, 1.8), METAL, Enum.Material.Metal)
	block(
		m,
		Vector3.new(8, 0.5, 1.4),
		cf * CFrame.new(0, 1.6, 1.1),
		Color3.fromRGB(130, 90, 56),
		Enum.Material.WoodPlanks
	)
end

export type Result = { places: { Places.Place } }

-- build the kit for the whole grid; `kinds[i][j]` is the city plan, `random` the map's seeded random
function StreetKit.build(
	static: Instance,
	props: Instance,
	grid: Grid,
	kinds: { [number]: { [number]: string } },
	random: Random
): Result
	local paintFolder = Instance.new("Folder")
	paintFolder.Name = "RoadPaint"
	paintFolder.Parent = static
	local B, R = grid.block, grid.road
	local pitch = B + R
	local N, M = grid.blocksX, grid.blocksZ
	local function rx(k: number): number
		return grid.x0 + R / 2 + k * pitch
	end
	local function rz(k: number): number
		return grid.z0 + R / 2 + k * pitch
	end
	local function district(i: number, j: number): Districts.Key
		return Districts.of(math.clamp(i, 0, N - 1), math.clamp(j, 0, M - 1), N, M)
	end
	-- paint every segment, a manhole at every crossing
	for k = 0, N do
		for m = 0, M - 1 do
			segment(paintFolder, grid, Vector3.new(rx(k), 0, rz(m) + R / 2 + B / 2), false)
		end
	end
	for m = 0, M do
		for k = 0, N - 1 do
			segment(paintFolder, grid, Vector3.new(rx(k) + R / 2 + B / 2, 0, rz(m)), true)
		end
	end
	for k = 0, N do
		for m = 0, M do
			local hole = cylinder(
				paintFolder,
				0.06,
				4,
				Vector3.new(rx(k) + 9, S.PaintHeight, rz(m) + 9),
				DARK
			)
			hole.CanCollide = false
			hole.CanQuery = false
		end
	end
	-- traffic lights at crossings that touch a district with signals (not on the city's outer edge)
	for k = 1, N - 1 do
		for m = 1, M - 1 do
			local lit = false
			for _, d in
				{ district(k - 1, m - 1), district(k, m - 1), district(k - 1, m), district(k, m) }
			do
				if (S.Districts :: any)[d].signals then
					lit = true
				end
			end
			if lit then
				for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
					local foot = Vector3.new(
						rx(k) + c[1] * (R / 2 + S.KerbInset + 1),
						Y0,
						rz(m) + c[2] * (R / 2 + S.KerbInset + 1)
					)
					signal(props, foot, Vector3.new(-c[1], 0, 0), Vector3.new(0, 0, -c[2]))
				end
			end
		end
	end
	-- furniture per block side
	local places: { Places.Place } = {}
	local SIDES =
		{ Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0) }
	for i = 0, N - 1 do
		for j = 0, M - 1 do
			local d = (S.Districts :: any)[district(i, j)] :: S.District
			local cx, cz = Routes.blockCentre(grid, i, j)
			local centre = Vector3.new(cx, Y0, cz)
			local kind = kinds[i][j]
			local busy = kind == "office"
				or kind == "shops"
				or kind == "plaza"
				or kind == "restaurant"
			local hydrantSide = random:NextInteger(1, 4)
			local benchSide = random:NextInteger(1, 4)
			for sideIndex, out in SIDES do
				local along = Vector3.new(-out.Z, 0, out.X)
				local edge = centre + out * (B / 2)
				lamp(
					props,
					edge - out * S.KerbInset,
					out,
					rgb(d.accent):Lerp(Color3.new(1, 1, 1), 0.5)
				)
				if random:NextNumber() < d.trees then
					for _, t in { -0.32, 0.32 } do
						tree(props, edge - out * (S.KerbInset + 1) + along * (t * B))
					end
				end
				if sideIndex == hydrantSide then
					hydrant(props, edge - out * S.KerbInset + along * (B * 0.2))
				end
				if sideIndex == benchSide then
					local at = edge - out * S.BenchInset + along * (-B * 0.18)
					bench(props, at, out)
					bin(props, at + along * 5)
				end
			end
			-- parked cars along the kerb, away from the crossings
			for _ = 1, S.ParkedPerBlock do
				local out = SIDES[random:NextInteger(1, 4)]
				local along = Vector3.new(-out.Z, 0, out.X)
				local at = centre
					+ out * (B / 2 + S.ParkedOffset)
					+ along * random:NextNumber(-B / 4, B / 4)
				parkedCar(props, at, along, rgb(S.CarColours[random:NextInteger(1, #S.CarColours)]))
			end
			-- a bus shelter and its waiting crowd on busy blocks
			if busy and random:NextNumber() < S.ShelterChance then
				local out = SIDES[random:NextInteger(1, 4)]
				local along = Vector3.new(-out.Z, 0, out.X)
				local at = centre + out * (B / 2 - S.BenchInset) + along * (B * 0.12)
				shelter(props, at, out, rgb(d.accent))
				local spots = {}
				for s = -1.5, 1.5 do
					table.insert(spots, at + out * 4.2 + along * (s * 2.6))
				end
				local stop = Places.open("plaza", spots[1], spots)
				stop.block = { i, j }
				table.insert(places, stop)
			end
		end
	end
	return { places = places }
end

return StreetKit
