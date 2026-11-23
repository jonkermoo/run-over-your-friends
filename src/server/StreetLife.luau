--!strict
-- Street life from Config/StreetLife, added once the map stands (outside MapBuilder, so the terrain bake never
-- changes for it): cars parked at the kerb downtown and on the shop streets, rows of cars round the car parks'
-- edges, lawns, food trucks and tables on the plazas, a building site in one car park, and roadworks in the
-- kerb lane on quieter streets. Cars, tables, boards, barriers and cones are props any vehicle knocks flying.
-- It draws from its own random stream, and skips any spot where an existing prop or building already stands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.StreetLife)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local World = require(ReplicatedStorage.Shared.Config.World)
local CityPlan = require(ReplicatedStorage.Shared.Rules.CityPlan)
local Routes = require(ReplicatedStorage.Shared.Rules.Routes)
local Rules = require(ReplicatedStorage.Shared.Rules.StreetLife)
local Greenery = require(script.Parent.Greenery)
local PaintKit = require(script.Parent.PaintKit)

local StreetLife = {}

local WHITE = Color3.fromRGB(240, 240, 236)
local Y = Cfg.Ground

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

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

-- an upright cylinder `height` tall and `dia` across standing on `at`
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

local function prop(folder: Instance, kind: string): Model
	local m = Instance.new("Model")
	m.Name = kind
	m:SetAttribute("Prop", kind)
	m.Parent = folder
	return m
end

-- a traffic cone standing on `at` (Config/StreetLife Works.ConeSize)
local function cone(props: Instance, at: Vector3)
	local W = Cfg.Works
	local base, h, dia = W.ConeSize[1], W.ConeSize[2], W.ConeSize[3]
	local m = prop(props, "Cone")
	part(m, Vector3.new(base, 0.3, base), CFrame.new(at + Vector3.new(0, 0.15, 0)), rgb(W.Cone))
	post(m, h, dia, at + Vector3.new(0, 0.3, 0), rgb(W.Cone))
end

-- (the same cut-down as LotKit.car, kept here so the terrain bake's source never changes for street life)
-- parked cars: each vehicle cut down once to its body, paint, glass and wheels, welded to its body so a knock
-- sends it flying in one piece; the pivot is its bottom centre
local MODELS = ReplicatedStorage:WaitForChild("VehicleModels")
local KEEP = { Body = true, Paint = true, Glass = true }
local templates: { [string]: { model: Model, size: Vector3 } } = {}

local function template(id: string): { model: Model, size: Vector3 }?
	local cached = templates[id]
	if cached then
		return cached
	end
	local source = MODELS:FindFirstChild(id)
	if not (source and source:IsA("Model")) then
		return nil
	end
	local model = source:Clone()
	model.WorldPivot = CFrame.identity
	model:ScaleTo(Game.VehicleScale)
	for _, d in model:GetDescendants() do
		local keep = if d:IsA("BasePart")
			then KEEP[d.Name]
				or string.sub(d.Name, 1, 6) == "Wheel_"
				-- the stock body's zones cut out for mastery upgrades (Z<n>): without them the bumpers are gone
				or string.match(d.Name, "^Z%d") ~= nil
			else d:IsA("Model")
		if not keep then
			d:Destroy()
		end
	end
	local body = model:FindFirstChild("Body") :: BasePart?
	if not body then
		model:Destroy()
		return nil
	end
	local box, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0))
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanTouch = false
			-- the body is what vehicles hit (meshes come in with CanQuery off)
			p.CanCollide = p == body
			p.CanQuery = p == body
			if p ~= body then
				local w = Instance.new("WeldConstraint")
				w.Part0 = body
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	model.Name = "ParkedCar"
	model:SetAttribute("Prop", "ParkedCar")
	local t = { model = model, size = size }
	templates[id] = t
	return t
end

type Ctx = {
	static: Instance,
	props: Instance,
	random: Random,
	params: OverlapParams,
	parts: number,
}

-- nothing of the map's props or buildings stands in this box (`cf` its middle)
local function clear(ctx: Ctx, cf: CFrame, size: Vector3): boolean
	local pad = Vector3.one * (Cfg.Clearance * 2)
	return #workspace:GetPartBoundsInBox(cf, size + pad, ctx.params) == 0
end

local function count(ctx: Ctx, m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			ctx.parts += 1
		end
	end
	if m:IsA("BasePart") then
		ctx.parts += 1
	end
end

-- a parked car standing at `at` facing `face`, if its spot is clear
local function car(ctx: Ctx, ids: { string }, at: Vector3, face: Vector3): Model?
	local id = ids[ctx.random:NextInteger(1, #ids)]
	local colour = rgb(Cfg.Paints[ctx.random:NextInteger(1, #Cfg.Paints)])
	local t = template(id)
	if not t then
		return nil
	end
	local cf = CFrame.lookAt(at, at + face) * CFrame.new(0, Y - Cfg.CarSink, 0)
	if not clear(ctx, cf * CFrame.new(0, t.size.Y / 2, 0), t.size) then
		return nil
	end
	local m = t.model:Clone()
	m:PivotTo(cf)
	if not Cfg.KeepFactory[id] then
		for _, painted in m:GetChildren() do
			if painted:IsA("BasePart") and string.match(painted.Name, "Paint$") then
				painted.Color = colour
			end
		end
	end
	m.Parent = ctx.props
	count(ctx, m)
	return m
end

local function sideWays(side: number): (Vector3, Vector3)
	local d = Rules.SIDES[side]
	local out = Vector3.new(d[1], 0, d[2])
	return out, Vector3.new(-out.Z, 0, out.X)
end

-- cars parked at the kerb, on the right-hand side of the traffic beside the block
local function kerb(ctx: Ctx, grid: Routes.Grid, plan: { [number]: { [number]: string } })
	local K = Cfg.Kerb
	for _, s in Rules.sides(plan, grid.blocksX, grid.blocksZ, K.Kinds) do
		local cx, cz = Routes.blockCentre(grid, s.i, s.j)
		local out, along = sideWays(s.side)
		local slots = table.clone(K.Slots)
		for _ = 1, K.PerSide[ctx.random:NextInteger(1, #K.PerSide)] do
			local t = table.remove(slots, ctx.random:NextInteger(1, #slots)) :: number
			t += ctx.random:NextNumber(-K.Jitter, K.Jitter)
			car(ctx, Cfg.Cars, Vector3.new(cx, 0, cz) + out * K.Out + along * t, along)
		end
	end
end

-- painted bays round a car park's edge with cars in some of them, nose to the edge
local function lot(ctx: Ctx, centre: Vector3, inner: number, keepOut: { Rules.Rect })
	local L = Cfg.Lot
	local bw, bd = L.Bay[1], L.Bay[2]
	local bays = Rules.lotBays(inner, L.Bay, L.Edge, L.Corner, keepOut)
	local rowAt = inner / 2 - L.Edge - bd / 2
	local rowLen = inner - L.Corner * 2
	local draws: { [number]: (number, number, number, number, Color3) -> () } = {}
	for _, b in bays do
		local key = b.dx * 2 + b.dz
		local draw = draws[key]
		if not draw then
			local sx = if b.dx ~= 0 then bd else rowLen
			local sz = if b.dx ~= 0 then rowLen else bd
			draw = PaintKit.patch(
				ctx.static,
				centre + Vector3.new(b.dx * rowAt, Y + 0.02, b.dz * rowAt),
				sx,
				sz
			)
			draws[key] = draw
			ctx.parts += 1
		end
		local px, pz = b.x - b.dx * rowAt, b.z - b.dz * rowAt -- the bay's middle on its patch
		for _, e in { -1, 1 } do
			if b.dx ~= 0 then
				draw(px, pz + e * bw / 2, bd, L.Line, WHITE)
			else
				draw(px + e * bw / 2, pz, L.Line, bd, WHITE)
			end
		end
		if ctx.random:NextNumber() < L.Fill then
			local face = Vector3.new(b.dx, 0, b.dz)
			car(ctx, Cfg.Cars, centre + Vector3.new(b.x, 0, b.z) + face * 1.5, face)
		end
	end
end

-- a building site inside `area` (from the car park's middle): boarded round with its gate open east, a slab
-- and a concrete frame, a tower crane, a site office, mounds of earth, pallets and cones
local function site(ctx: Ctx, centre: Vector3, area: Rules.Rect)
	local S = Cfg.Site
	local x0, z0, x1, z1 = area[1], area[2], area[3], area[4]
	local w, d = x1 - x0, z1 - z0
	local mid = centre + Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2)
	local static = Instance.new("Model")
	static.Name = "Site"
	static.Parent = ctx.static
	local ground = part(
		static,
		Vector3.new(w, 0.2, d),
		CFrame.new(mid + Vector3.new(0, Y + 0.08, 0)),
		rgb(S.Ground),
		Enum.Material.Ground
	)
	ground.CanCollide = false
	local board = rgb(S.HoardingColour)
	for _, b in Rules.hoarding(area, S.Hoarding, S.Gate) do
		local at = centre + Vector3.new(b.x, Y + S.HoardingHeight / 2, b.z)
		local size = if b.alongX
			then Vector3.new(b.len - 0.3, S.HoardingHeight + 0.04, 0.6)
			else Vector3.new(0.6, S.HoardingHeight, b.len - 0.3)
		local m = prop(ctx.props, "Hoarding")
		part(m, size, CFrame.new(at), board, Enum.Material.WoodPlanks)
		ctx.parts += 1
	end
	-- the slab and frame at the west end, the crane and office at the east end
	local taken: { Rules.Rect } = {}
	local concrete = rgb(S.Concrete)
	local sw, sh, sd = S.Slab[1], S.Slab[2], S.Slab[3]
	local slabX, slabZ = x0 + 4 + sw / 2, (z0 + z1) / 2
	table.insert(
		taken,
		{ slabX - sw / 2 - 3, slabZ - sd / 2 - 3, slabX + sw / 2 + 3, slabZ + sd / 2 + 3 }
	)
	local slabAt = centre + Vector3.new(slabX, Y, slabZ)
	part(
		static,
		Vector3.new(sw, sh, sd),
		CFrame.new(slabAt + Vector3.new(0, sh / 2, 0)),
		concrete,
		Enum.Material.Concrete
	)
	for k = 0, S.Columns - 1 do
		for _, e in { -1, 1 } do
			local cx = -sw / 2 + 2 + k * (sw - 4) / (S.Columns - 1)
			part(
				static,
				Vector3.new(2, S.Storey, 2),
				CFrame.new(slabAt + Vector3.new(cx, sh + S.Storey / 2, e * (sd / 2 - 2))),
				concrete,
				Enum.Material.Concrete
			)
		end
	end
	part(
		static,
		Vector3.new(sw, 1.5, sd),
		CFrame.new(slabAt + Vector3.new(0, sh + S.Storey + 0.75, 0)),
		concrete,
		Enum.Material.Concrete
	)
	-- the crane: its mast in the site's north-east corner, the jib out west over the frame
	local C = S.Crane
	local yellow = rgb(C.colour)
	local mastX, mastZ = x1 - 10, z0 + 8
	table.insert(taken, { mastX - 6, mastZ - 6, mastX + 6, mastZ + 6 })
	local foot = centre + Vector3.new(mastX, Y, mastZ)
	part(
		static,
		Vector3.new(5, C.mast, 5),
		CFrame.new(foot + Vector3.new(0, C.mast / 2, 0)),
		yellow,
		Enum.Material.DiamondPlate
	)
	local top = foot + Vector3.new(0, C.mast + 1.5, 0)
	local dir = (Vector3.new(slabAt.X, 0, slabAt.Z) - Vector3.new(foot.X, 0, foot.Z)).Unit
	local jibTurn = CFrame.lookAt(Vector3.zero, dir)
	part(
		static,
		Vector3.new(2.5, 3, C.jib),
		CFrame.new(top + dir * (C.jib / 2)) * jibTurn,
		yellow,
		Enum.Material.DiamondPlate
	)
	part(
		static,
		Vector3.new(2.5, 3, C.back),
		CFrame.new(top - dir * (C.back / 2)) * jibTurn,
		yellow,
		Enum.Material.DiamondPlate
	)
	part(
		static,
		Vector3.new(5, 4, 4),
		CFrame.new(top - dir * (C.back - 2) + Vector3.new(0, -3, 0)) * jibTurn,
		rgb(S.Concrete),
		Enum.Material.Concrete
	)
	part(
		static,
		Vector3.new(4.5, 4.5, 4.5),
		CFrame.new(top + Vector3.new(0, -3.5, 0) + dir * 4) * jibTurn,
		rgb(S.CabGlass),
		Enum.Material.Glass
	)
	local hookAt = top + dir * (C.jib - 8)
	local drop = C.mast - S.Storey - 10
	part(
		static,
		Vector3.new(0.3, drop, 0.3),
		CFrame.new(hookAt + Vector3.new(0, -drop / 2, 0)),
		rgb(S.HookLine),
		Enum.Material.Metal
	)
	local cw, ch, cd = S.Cabin[1], S.Cabin[2], S.Cabin[3]
	local cabX, cabZ = x1 - 6 - cw / 2, z1 - 4 - cd / 2
	table.insert(
		taken,
		{ cabX - cw / 2 - 2, cabZ - cd / 2 - 2, cabX + cw / 2 + 2, cabZ + cd / 2 + 2 }
	)
	local cabin = prop(ctx.props, "SiteCabin")
	part(
		cabin,
		Vector3.new(cw, ch, cd),
		CFrame.new(centre + Vector3.new(cabX, Y + ch / 2, cabZ)),
		rgb(S.CabinColour)
	)
	ctx.parts += 9 + S.Columns * 2 + 1
	-- loose things on what's left of the ground: mounds, pallets, cones
	local function spot(r: number): Vector3?
		for _ = 1, 20 do
			local x = ctx.random:NextNumber(x0 + r + 2, x1 - r - 2)
			local z = ctx.random:NextNumber(z0 + r + 2, z1 - r - 2)
			if not Rules.hits(taken, x - r, z - r, x + r, z + r) then
				local at = centre + Vector3.new(x, Y, z)
				if
					clear(ctx, CFrame.new(at + Vector3.new(0, 3, 0)), Vector3.new(r * 2, 6, r * 2))
				then
					table.insert(taken, { x - r, z - r, x + r, z + r })
					return at
				end
			end
		end
		return nil
	end
	local earth = rgb(S.Earth)
	for _ = 1, S.Mounds do
		local at = spot(S.MoundSize[1] / 2)
		if at then
			local m = part(
				static,
				Vector3.one * S.MoundSize[1],
				CFrame.new(at + Vector3.new(0, S.MoundSize[2] - S.MoundSize[1] / 2, 0)),
				earth,
				Enum.Material.Ground
			)
			m.Shape = Enum.PartType.Ball
			ctx.parts += 1
		end
	end
	for _ = 1, S.Pallets do
		local at = spot(S.Pallet[1] / 2 + 0.5)
		if at then
			local m = prop(ctx.props, "Pallet")
			part(
				m,
				Vector3.new(S.Pallet[1], S.Pallet[2], S.Pallet[3]),
				CFrame.new(at + Vector3.new(0, S.Pallet[2] / 2, 0)),
				rgb(Cfg.Plaza.Wood),
				Enum.Material.WoodPlanks
			)
			part(
				m,
				Vector3.new(S.Load[1], S.Load[2], S.Load[3]),
				CFrame.new(at + Vector3.new(0, S.Pallet[2] + S.Load[2] / 2, 0)),
				rgb(S.Crate),
				Enum.Material.Cardboard
			)
			ctx.parts += 2
		end
	end
	for _ = 1, S.Cones do
		local at = spot(2)
		if at then
			cone(ctx.props, at)
			ctx.parts += 2
		end
	end
end

-- a picnic table under an umbrella, its long side along `along`
local function picnic(ctx: Ctx, at: Vector3, along: Vector3)
	at = Vector3.new(at.X, Y, at.Z)
	local P = Cfg.Plaza
	local L, H, W = P.Table[1], P.Table[2], P.Table[3]
	local cf = CFrame.lookAt(at, at + along)
	local wood = rgb(P.Wood)
	if not clear(ctx, cf * CFrame.new(0, H / 2, 0), Vector3.new(W + 4, H, L)) then
		return
	end
	local m = prop(ctx.props, "Picnic")
	part(m, Vector3.new(W, 0.5, L), cf * CFrame.new(0, H, 0), wood, Enum.Material.WoodPlanks)
	for _, s in { -1, 1 } do
		part(
			m,
			Vector3.new(1.4, H * 0.55, L),
			cf * CFrame.new(s * (W / 2 + 1.2), H * 0.275, 0),
			wood,
			Enum.Material.WoodPlanks
		)
	end
	local U = P.Umbrella
	post(m, U[1], 0.4, at, WHITE)
	local canopy = part(
		m,
		Vector3.new(0.6, U[2], U[2]),
		CFrame.new(at + Vector3.new(0, U[1], 0)) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(P.Canopies[ctx.random:NextInteger(1, #P.Canopies)]),
		Enum.Material.Fabric
	)
	canopy.Shape = Enum.PartType.Cylinder
	ctx.parts += 5
end

-- a plaza: lawns on its diagonals, food trucks parked round its edge with tables in front
local function plaza(ctx: Ctx, centre: Vector3)
	local P = Cfg.Plaza
	local taken: { Rules.Rect } = {}
	for _, q in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local x, z = q[1] * P.LawnAt, q[2] * P.LawnAt
		local at = centre + Vector3.new(x, Y, z)
		if clear(ctx, CFrame.new(at + Vector3.new(0, 2, 0)), Vector3.new(P.Lawn, 4, P.Lawn)) then
			local lawn = part(
				ctx.static,
				Vector3.new(P.Lawn, 0.3, P.Lawn),
				CFrame.new(at + Vector3.new(0, 0.12, 0)),
				rgb(P.LawnColour),
				Enum.Material.Grass
			)
			lawn.CanCollide = false
			lawn.Name = "Lawn"
			table.insert(taken, { x - P.Lawn / 2, z - P.Lawn / 2, x + P.Lawn / 2, z + P.Lawn / 2 })
			Greenery.tree(ctx.props, at + Vector3.new(-q[1] * 4, 0.25, -q[2] * 4), ctx.random)
			Greenery.bush(ctx.props, at + Vector3.new(q[1] * 6, 0.25, q[2] * 6), ctx.random)
			ctx.parts += 4
		end
	end
	local placed = 0
	for _, a in P.TruckTurns do
		if placed >= P.Trucks then
			break
		end
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local tangent = Vector3.new(-dir.Z, 0, dir.X)
		local at = centre + dir * P.TruckAt
		local t = template(P.TruckIds[1])
		if t then
			-- its rough box, to keep it off the lawns
			local r = t.size.Z / 2
			local rx, rz = at.X - centre.X, at.Z - centre.Z
			if not Rules.hits(taken, rx - r, rz - r, rx + r, rz + r) then
				if car(ctx, P.TruckIds, at, tangent) then
					placed += 1
					for k = 1, P.Tables do
						local off = ((k - 0.5) / P.Tables - 0.5) * P.TableGap * P.Tables
						picnic(ctx, at - dir * P.TableIn + tangent * off, dir)
					end
				end
			end
		end
	end
end

-- roadworks in the kerb lane: a dug patch, barriers on its traffic side and ends, a taper of cones before it
local function works(ctx: Ctx, grid: Routes.Grid, plan: { [number]: { [number]: string } })
	local W = Cfg.Works
	local sides = Rules.sides(plan, grid.blocksX, grid.blocksZ, W.Kinds)
	local colours = { rgb(W.BarrierColours[1]), rgb(W.BarrierColours[2]) }
	local pw, pl = W.Patch[1], W.Patch[2]
	for _ = 1, math.min(W.Count, #sides) do
		local s = table.remove(sides, ctx.random:NextInteger(1, #sides)) :: Rules.Side
		local cx, cz = Routes.blockCentre(grid, s.i, s.j)
		local out, along = sideWays(s.side)
		local at = Vector3.new(cx, Y, cz)
			+ out * Cfg.Kerb.Out
			+ along * ctx.random:NextNumber(-W.Spread, W.Spread)
		local turn = CFrame.lookAt(at, at + along)
		if
			clear(
				ctx,
				turn * CFrame.new(0, 2, 0),
				Vector3.new(pw + 4, 4, pl + W.Cones * W.ConeGap * 2)
			)
		then
			local patch = part(
				ctx.static,
				Vector3.new(pw, 0.2, pl),
				turn * CFrame.new(0, 0.05, 0),
				rgb(W.PatchColour),
				Enum.Material.Ground
			)
			patch.CanCollide = false
			patch.Name = "Roadworks"
			local n = 0
			local function barrier(pos: Vector3, runs: Vector3)
				n += 1
				local m = prop(ctx.props, "Barrier")
				local bar =
					Greenery.place(m, "Barrier", pos, nil, W.BarrierHeight, 0, colours[n % 2 + 1])
				bar.Size = Vector3.new(W.Barrier, bar.Size.Y, bar.Size.Z)
				bar.CFrame =
					CFrame.fromMatrix(pos + Vector3.new(0, bar.Size.Y / 2, 0), runs, Vector3.yAxis)
				bar.Material = Enum.Material.Concrete
				bar.CanCollide = true
				bar.CanQuery = true
				bar.CanTouch = true
			end
			-- the traffic side faces away from the block (`out`)
			for _, e in { -1, 1 } do
				barrier(at + out * (pw / 2 + 0.6) + along * (e * pl / 4), along)
				barrier(at + along * (e * (pl / 2 + 0.6)), out)
			end
			-- cones before it (traffic comes along `along`)
			for k = 1, W.Cones do
				local c = at
					- along * (pl / 2 + k * W.ConeGap)
					+ out * (pw / 2 * (1 - k / (W.Cones + 1)))
				cone(ctx.props, c)
			end
			ctx.parts += 5 + W.Cones * 2
		end
	end
end

-- after the map is built and before its props are registered (so all of it is knockable). Returns the parts
-- it added.
function StreetLife.build(map: { props: Folder, buildings: Folder, grid: Routes.Grid }): number
	local M = World.Map
	local grid = map.grid
	local plan = CityPlan.plan(M.BlocksX, M.BlocksZ, M.Seed)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map.props, map.buildings }
	local static = Instance.new("Folder")
	static.Name = "StreetLife"
	static.Parent = map.props.Parent
	local ctx: Ctx = {
		static = static,
		props = map.props,
		random = Random.new(M.Seed + Cfg.SeedOffset),
		params = params,
		parts = 0,
	}
	local inner = grid.block - grid.sidewalk * 2
	local siteAt = Vector3.new(Cfg.Site.Block[1], 0, Cfg.Site.Block[2])
	for i = 0, grid.blocksX - 1 do
		for j = 0, grid.blocksZ - 1 do
			local cx, cz = Routes.blockCentre(grid, i, j)
			local centre = Vector3.new(cx, 0, cz)
			local kind = plan[i][j]
			if kind == "parking" then
				local keepOut = table.clone(Cfg.Lot.KeepOut)
				if (centre - siteAt).Magnitude < 1 then
					local a = Cfg.Site.Area
					table.insert(keepOut, { a[1] - 4, a[2] - 4, a[3] + 4, a[4] + 4 })
					site(ctx, centre, a)
				end
				lot(ctx, centre, inner, keepOut)
			elseif kind == "plaza" then
				plaza(ctx, centre)
			end
		end
	end
	if Cfg.Kerb.On then
		kerb(ctx, grid, plan)
	end
	works(ctx, grid, plan)
	return ctx.parts
end

return StreetLife
