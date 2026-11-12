--!strict
-- The street kit: road paint (double yellows, lane dashes, zebra crossings, stop lines, manholes) and street
-- furniture (lamps, traffic lights, benches, bins, hydrants, planter trees, bus shelters, news
-- boxes, mailboxes, planters, A-boards),
-- styled by district. Paint is flat and never collides. Furniture goes in the Props folder: each piece is a
-- Model that any vehicle knocks flying (BuildingService puts it back later).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Districts = require(ReplicatedStorage.Shared.Rules.Districts)
local Routes = require(ReplicatedStorage.Shared.Rules.Routes)
local S = require(ReplicatedStorage.Shared.Config.Streets)
local Places = require(script.Parent.Places)

local StreetKit = {}

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

local function newsBox(folder: Instance, at: Vector3, out: Vector3, color: Color3)
	local m = prop(folder, "NewsBox")
	block(m, Vector3.new(2, 3.4, 1.8), CFrame.lookAt(at, at + out) + Vector3.new(0, 1.7, 0), color)
end

local function mailbox(folder: Instance, at: Vector3, out: Vector3)
	local m = prop(folder, "Mailbox")
	local cf = CFrame.lookAt(at, at + out)
	block(m, Vector3.new(2.2, 3, 1.8), cf + Vector3.new(0, 2.6, 0), Color3.fromRGB(40, 70, 150))
	block(m, Vector3.new(1.2, 1.1, 1.2), cf + Vector3.new(0, 0.55, 0), DARK)
end

local function planter(folder: Instance, at: Vector3, out: Vector3)
	local m = prop(folder, "Planter")
	local cf = CFrame.lookAt(at, at + out)
	block(
		m,
		Vector3.new(5, 1.6, 2.2),
		cf + Vector3.new(0, 0.8, 0),
		Color3.fromRGB(150, 140, 128),
		Enum.Material.Concrete
	)
	block(
		m,
		Vector3.new(4.4, 1.4, 1.8),
		cf + Vector3.new(0, 2.1, 0),
		Color3.fromRGB(80, 150, 70),
		Enum.Material.Grass
	)
end

-- a sandwich board outside a shop or cafe
local function aBoard(folder: Instance, at: Vector3, out: Vector3, color: Color3)
	local m = prop(folder, "ABoard")
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = Vector3.new(2.4, 3.4, 1.6)
	w.CFrame = CFrame.lookAt(at, at - out) + Vector3.new(0, 1.7, 0)
	w.Color = color
	w.Material = Enum.Material.WoodPlanks
	w.Parent = m
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

-- the park uses the same benches and lamps
StreetKit.bench = bench
StreetKit.lamp = lamp

export type Result = { places: { Places.Place } }

-- build the kit for the whole grid; `kinds[i][j]` is the city plan, `random` the map's seeded random
function StreetKit.build(
	static: Instance,
	props: Instance,
	grid: Grid,
	kinds: { [number]: { [number]: string } },
	random: Random
): Result
	-- the road paint and manholes are part of the road meshes now (RoadKit)
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
				-- clutter in free slots along the side, between the kerb and the buildings
				local slots = table.clone(S.ClutterSlots)
				for _ = 1, S.ClutterPerSide do
					local slot = table.remove(slots, random:NextInteger(1, #slots)) :: number
					local inset = random:NextNumber(S.KerbInset + 1, grid.sidewalk - 1.5)
					local at = edge - out * inset + along * (slot * B)
					local pick = random:NextInteger(1, if busy then 5 else 3)
					if pick == 1 then
						bin(props, at)
					elseif pick == 2 then
						mailbox(props, at, out)
					elseif pick == 3 then
						planter(props, at, out)
					elseif pick == 4 then
						newsBox(props, at, out, rgb(d.accent))
					else
						aBoard(props, at, out, rgb(d.accent):Lerp(Color3.new(0, 0, 0), 0.3))
					end
				end
			end
			local inner = B - grid.sidewalk * 2
			if kind == "plaza" then
				-- a fountain in the middle, planters in a ring round it, benches between them facing in
				local F = S.PlazaFountain
				local stone = Color3.fromRGB(200, 196, 188)
				cylinder(static, F.rim, F.size, centre + Vector3.new(0, F.rim / 2, 0), stone).Material =
					Enum.Material.Concrete
				local water = cylinder(
					static,
					0.4,
					F.size - 3,
					centre + Vector3.new(0, F.rim - 0.1, 0),
					Color3.fromRGB(60, 170, 210)
				)
				water.Material = Enum.Material.Glass
				water.Transparency = 0.15
				cylinder(static, F.column, 4, centre + Vector3.new(0, F.column / 2, 0), stone)
				cylinder(static, 1, 12, centre + Vector3.new(0, F.column, 0), stone)
				for k = 0, S.PlazaPlanters - 1 do
					local a = k / S.PlazaPlanters * math.pi * 2
					local out = Vector3.new(math.cos(a), 0, math.sin(a))
					planter(props, centre + out * (inner * 0.3), out)
				end
				for k = 0, S.PlazaBenches - 1 do
					local a = (k + 0.5) / S.PlazaBenches * math.pi * 2
					local out = Vector3.new(math.cos(a), 0, math.sin(a))
					bench(props, centre + out * (inner * 0.22), -out)
				end
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
