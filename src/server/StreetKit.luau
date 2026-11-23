--!strict
-- The street kit: road paint (double yellows, lane dashes, zebra crossings, stop lines, manholes) and street
-- furniture (lamps, traffic lights, benches, bins, hydrants, planter trees, bus shelters, news
-- boxes, mailboxes, planters, A-boards),
-- styled by district. Paint is flat and never collides. Furniture goes in the Props folder: each piece is a
-- Model that any vehicle knocks flying (BuildingService puts it back later).

local CollectionService = game:GetService("CollectionService")
local GeometryService = game:GetService("GeometryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ambient = require(ReplicatedStorage.Shared.Config.Ambient)
local CityPlan = require(ReplicatedStorage.Shared.Rules.CityPlan)
local Districts = require(ReplicatedStorage.Shared.Rules.Districts)
local Routes = require(ReplicatedStorage.Shared.Rules.Routes)
local S = require(ReplicatedStorage.Shared.Config.Streets)
local Places = require(script.Parent.Places)
local G = require(ReplicatedStorage.Shared.Config.StreetGreen)
local Green = require(ReplicatedStorage.Shared.Rules.StreetGreen)
local Greenery = require(script.Parent.Greenery)

local StreetKit = {}

local DARK = Color3.fromRGB(34, 36, 40)
local METAL = Color3.fromRGB(70, 74, 80)
local Y0 = 0.08
local SIG = S.Signal

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

-- the traffic light's head facing one road: a yellow housing with a dark visor over each lamp slot, its middle at
-- `cf` (LookVector toward the road)
local function signalHead(parent: Instance, cf: CFrame)
	local hs, v = SIG.Housing, SIG.Visor
	block(parent, Vector3.new(hs[1], hs[2], hs[3]), cf, rgb(SIG.HousingColour))
	for i = -1, 1 do
		local y = i * SIG.LampSpacing + SIG.LampDiameter / 2 + v[2] / 2
		block(
			parent,
			Vector3.new(v[1], v[2], v[3]),
			cf * CFrame.new(0, y, -(hs[3] / 2 + v[3] / 2)),
			rgb(SIG.VisorColour)
		)
	end
end

-- the head joined into one part, made once and copied to every corner; false when the
-- engine can't join it, and each head is then built from its four parts
local headUnion: BasePart | false | nil = nil
local function headCopy(): BasePart?
	if headUnion == nil then
		local holder = Instance.new("Model")
		signalHead(holder, CFrame.identity)
		local parts = holder:GetChildren() :: { any }
		local ok, joined = pcall(function()
			return GeometryService:UnionAsync(parts[1], { parts[2], parts[3], parts[4] }, {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Automatic,
				SplitApart = false,
			})
		end)
		local union = ok and joined and joined[1]
		if union and union:IsA("BasePart") then
			union.UsePartColor = false -- keep the housing yellow and the visors dark
			union.Anchored = true
			union.Name = "SignalHead"
			headUnion = union
		else
			warn("StreetKit: couldn't join the traffic light head, building it from parts", joined)
			headUnion = false
		end
		holder:Destroy()
	end
	return if headUnion then headUnion:Clone() else nil
end

-- a traffic light on a corner: a grey pole and a head facing each road (toX and toZ point at the crossing), set side
-- by side round the pole; each lamp is tagged Signal = "EW" / "NS" and Lamp = its colour, and the client lights
-- the one for the current colour
local function signal(folder: Instance, foot: Vector3, toX: Vector3, toZ: Vector3)
	local m = prop(folder, "Signal")
	local pw, hs = SIG.PoleWidth, SIG.Housing
	block(
		m,
		Vector3.new(pw, SIG.PoleHeight, pw),
		CFrame.new(foot + Vector3.new(0, SIG.PoleHeight / 2, 0)),
		rgb(SIG.PoleColour),
		Enum.Material.Metal
	)
	for _, f in { { toX, toZ, "EW" }, { toZ, toX, "NS" } } do
		local dir, other = f[1] :: Vector3, f[2] :: Vector3
		-- its back against the pole, shifted away from the other head so the two don't meet
		local at = foot
			+ dir * (pw / 2 + hs[3] / 2)
			- other * (hs[1] / 2 - pw / 2)
			+ Vector3.new(0, SIG.HousingHeight, 0)
		local cf = CFrame.lookAt(at, at + dir)
		local head = headCopy()
		if head then
			head.CFrame = cf * head.CFrame
			head.Parent = m
		else
			signalHead(m, cf)
		end
		for i, colour in { "green", "amber", "red" } do
			local disc = cylinder(
				m,
				SIG.LampDepth,
				SIG.LampDiameter,
				Vector3.zero,
				rgb((SIG.Dim :: any)[colour])
			)
			-- the disc's axis (X) points at the road, half of it standing out of the housing's face
			disc.CFrame = cf
				* CFrame.new(0, (i - 2) * SIG.LampSpacing, -hs[3] / 2)
				* CFrame.Angles(0, math.pi / 2, 0)
			disc:SetAttribute("Signal", f[3])
			disc:SetAttribute("Lamp", colour)
		end
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
	-- soil and a row of blooms (Config/StreetGreen PlanterBlooms), the colour picked by its spot
	local B = G.PlanterBlooms
	block(
		m,
		Vector3.new(B.Size[1], B.SoilThick, 1.8),
		cf + Vector3.new(0, B.SoilTop - B.SoilThick / 2, 0),
		rgb(B.Soil),
		Enum.Material.Ground
	)
	local blooms = Greenery.mesh(
		m,
		"Blooms",
		1,
		cf + Vector3.new(0, B.SoilTop + B.Size[2] / 2 - B.Sink, 0),
		rgb(G.Flowers[Green.spot(at.X, at.Z) % #G.Flowers + 1])
	)
	blooms.Size = Vector3.new(B.Size[1], B.Size[2], B.Size[3])
	blooms.Material = Enum.Material.SmoothPlastic
	blooms.CanCollide = false
	blooms.CanQuery = false
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

-- a street tree (Config/StreetGreen Trees): a trunk and a big low-poly crown, its shape and turn picked by
-- its spot and its tint by its block side (`accent`, else a green by spot), so no random draws and nothing else
-- moves; the crown reaches over the road, so it never collides (the trunk does)
local function tree(folder: Instance, at: Vector3, accent: number?)
	local T = G.Trees
	local m = prop(folder, "Tree")
	local shape = T.Shapes[Green.shape(at.X, at.Z, #T.Shapes)]
	block(
		m,
		Vector3.new(T.TrunkWidth, shape.trunk, T.TrunkWidth),
		CFrame.new(at + Vector3.new(0, shape.trunk / 2, 0)),
		rgb(T.Trunk),
		Enum.Material.Wood
	)
	local colour = if accent
		then rgb(T.Accents[accent])
		else rgb(T.Greens[Green.green(at.X, at.Z, #T.Greens)])
	local crown = Greenery.place(
		m,
		shape.mesh,
		at,
		shape.width,
		nil,
		(Green.spot(at.X, at.Z) % 360) * math.pi / 180,
		colour
	)
	crown.Size = Vector3.new(crown.Size.X, crown.Size.Y * shape.stretch, crown.Size.Z)
	local foot = shape.foot or (shape.trunk - crown.Size.Y * shape.sink)
	crown.Position = at + Vector3.new(0, foot + crown.Size.Y / 2, 0)
	crown.Material = Enum.Material.Grass
end

-- a flat grass strip along a block side's kerb, under its trees (Config/StreetGreen Verge); never collides
local function verge(static: Instance, edge: Vector3, out: Vector3, blockSize: number)
	local V = G.Verge
	local along = Vector3.new(-out.Z, 0, out.X)
	local mid = edge - out * V.Inset + Vector3.new(0, V.Top / 2, 0)
	local p = block(
		static,
		Vector3.new(V.Length * blockSize, V.Top, V.Width),
		CFrame.fromMatrix(mid, along, Vector3.yAxis),
		rgb(V.Colour),
		Enum.Material.Grass
	)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
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
				-- street trees (Config/StreetGreen Trees) in a grass verge; the spawn plaza keeps its own paving and
				-- only the outer pair, clear of its exits
				if random:NextNumber() < d.trees then
					local accent = Green.accent(i, j, sideIndex, G.Trees.AccentEvery)
					local downtown = CityPlan.distance(i, j, N, M) < G.Trees.DowntownReach
					local spots = if kind == "spawn"
						then G.Trees.SpawnAt
						elseif downtown then G.Trees.At
						else G.Trees.OuterAt
					for _, t in spots do
						tree(props, edge - out * G.Trees.Inset + along * (t * B), accent)
					end
					if kind ~= "spawn" then
						verge(static, edge, out, B)
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
				-- a jet of spray from the column's top, made on each screen (client/Ambient)
				water:SetAttribute("SprayLift", Ambient.FountainLift)
				CollectionService:AddTag(water, Ambient.Tags.Spray)
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
