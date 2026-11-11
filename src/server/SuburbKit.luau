--!strict
-- The suburbs (Config/Suburbs): a road out from the highway ring, then a curving avenue with side streets that
-- end in cul-de-sacs, detached houses on lawns along every street. Streets are straight pieces with round
-- joints (so they curve smoothly); houses come from the house kit, turned to face their street. Lot dressing
-- (mailboxes, trees, fences, cars) is made of props, so it can be knocked flying.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Suburbs)
local Houses = require(ReplicatedStorage.Shared.Config.Houses)
local Lots = require(ReplicatedStorage.Shared.Config.Lots)
local Streets = require(ReplicatedStorage.Shared.Config.Streets)
local HouseRules = require(ReplicatedStorage.Shared.Rules.Houses)
local Greenery = require(script.Parent.Greenery)
local HouseKit = require(script.Parent.HouseKit)
local LotKit = require(script.Parent.LotKit)
local Places = require(script.Parent.Places)

local SuburbKit = {}

export type Rect = { x: number, z: number, w: number, d: number }
export type Result = {
	rects: { Rect },
	places: { Places.Place },
	walkPoints: { Vector3 },
	spawnPoints: { Vector3 },
}

type Street = { pts: { Vector3 }, bulb: boolean }
type Lot = { c: Vector3, out: Vector3, w: number, depth: number }

local ASPHALT = Color3.fromRGB(64, 66, 70)

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

local function prop(folder: Instance, kind: string): Model
	local m = Instance.new("Model")
	m.Name = kind
	m:SetAttribute("Prop", kind)
	m.Parent = folder
	return m
end

local function disc(
	parent: Instance,
	at: Vector3,
	dia: number,
	thick: number,
	color: Color3,
	material: Enum.Material
)
	local d = part(
		parent,
		Vector3.new(thick, dia, dia),
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material
	)
	d.Shape = Enum.PartType.Cylinder
	return d
end

-- a strip along a polyline at height `y`: straight pieces, round joints between them
local function lay(
	parent: Instance,
	pts: { Vector3 },
	width: number,
	y: number,
	thick: number,
	color: Color3,
	material: Enum.Material
)
	local lift = Vector3.new(0, y, 0)
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		part(
			parent,
			Vector3.new(width, thick, (b - a).Magnitude),
			CFrame.lookAt((a + b) / 2 + lift, b + lift),
			color,
			material
		)
	end
	for i = 2, #pts - 1 do
		disc(parent, pts[i] + lift, width, thick, color, material)
	end
end

-- the unit way along a polyline at point i, and the unit way to its right
local function frame(pts: { Vector3 }, i: number): (Vector3, Vector3)
	local a, b = pts[math.max(i - 1, 1)], pts[math.min(i + 1, #pts)]
	local along = (b - a).Unit
	return along, Vector3.new(-along.Z, 0, along.X)
end

-- terrain off the ground (hill feet, mounds) over a rect, so roads and lawns lie flat
local function flatten(r: Rect)
	workspace.Terrain:FillBlock(
		CFrame.new(r.x, 150.5, r.z),
		Vector3.new(r.w, 300, r.d),
		Enum.Material.Air
	)
end

local function rectAlong(
	origin: Vector3,
	dir: Vector3,
	from: number,
	to: number,
	across: number
): Rect
	local mid = origin + dir * ((from + to) / 2)
	local len = to - from
	return {
		x = mid.X,
		z = mid.Z,
		w = if dir.X ~= 0 then len else across,
		d = if dir.Z ~= 0 then len else across,
	}
end

local function sign(parent: Instance, at: Vector3, face: Vector3, text: string)
	local W, H = Cfg.Sign[1], Cfg.Sign[2]
	local cf = CFrame.lookAt(at, at + face)
	local wood = rgb(Cfg.Fence)
	for _, x in { -W / 2 + 2, W / 2 - 2 } do
		part(
			parent,
			Vector3.new(1.2, H + 5, 1.2),
			cf * CFrame.new(x, (H + 5) / 2, 0),
			wood,
			Enum.Material.Wood
		)
	end
	local board = part(
		parent,
		Vector3.new(W, H, 1),
		cf * CFrame.new(0, 5 + H / 2, 0),
		rgb(Cfg.SignColour),
		Enum.Material.Wood
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 1
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(250, 246, 226)
	label.Text = text
	label.Parent = gui
end

-- a house's back garden (the house at `c`, facing `face`, `width` by `depth`): maybe a tree, maybe a fence
-- round it, and inside some fences a pool. The caller checks there is room behind the house.
function SuburbKit.garden(
	folder: Instance,
	props: Instance,
	c: Vector3,
	face: Vector3,
	width: number,
	depth: number,
	random: Random
)
	local C = Cfg.Chances
	local right = Vector3.new(-face.Z, 0, face.X)
	local g = c - face * (depth / 2 + Cfg.Garden / 2)
	if random:NextNumber() < C.backTree then
		local sx = if random:NextNumber() < 0.5 then 1 else -1
		Greenery.tree(props, g - face * (Cfg.Garden / 2 - 4) + right * sx * (width / 2 - 3), random)
	end
	if random:NextNumber() < C.fence then
		local colour = if random:NextNumber() < C.picket then rgb(Cfg.Picket) else rgb(Cfg.Fence)
		local fence = prop(props, "Fence")
		local H = Cfg.FenceHeight
		local backAt = c - face * (depth / 2 + Cfg.Garden)
		part(
			fence,
			Vector3.new(width + 6, H, 0.4),
			CFrame.lookAt(backAt, backAt + face) + Vector3.new(0, H / 2, 0),
			colour,
			Enum.Material.WoodPlanks
		)
		for _, sx in { -1, 1 } do
			local sideAt = g + right * sx * (width / 2 + 3)
			part(
				fence,
				Vector3.new(0.4, H, Cfg.Garden),
				CFrame.lookAt(sideAt, sideAt + face) + Vector3.new(0, H / 2, 0),
				colour,
				Enum.Material.WoodPlanks
			)
		end
		if random:NextNumber() < C.pool / C.fence then
			local P = Cfg.Pool
			part(
				folder,
				Vector3.new(P[1] + 2, 0.4, P[2] + 2),
				CFrame.lookAt(g, g + right),
				Color3.fromRGB(240, 240, 236),
				Enum.Material.Concrete
			)
			local water = part(
				folder,
				Vector3.new(P[1], 0.5, P[2]),
				CFrame.lookAt(g, g + right) + Vector3.new(0, 0.05, 0),
				rgb(Cfg.PoolWater),
				Enum.Material.Glass
			)
			water.Transparency = 0.15
			water.Reflectance = 0.2
			water.CanCollide = false
		end
	end
end

-- one neighbourhood; `ringOuter` is the ring road's outer edge from the middle
local function hood(
	h: Cfg.Hood,
	ringOuter: number,
	static: Instance,
	buildings: Instance,
	props: Instance,
	random: Random,
	out: Result
)
	local dir = Vector3.new(h.dir[1], 0, h.dir[2])
	local perp = Vector3.new(-dir.Z, 0, dir.X)
	local origin = Vector3.new(math.abs(dir.Z) * h.offset, 0, math.abs(dir.X) * h.offset)
	local folder = Instance.new("Model")
	folder.Name = "Suburb_" .. h.name
	folder.Parent = static
	local roadHalf = Cfg.Road / 2
	local setback = roadHalf + Cfg.Verge + Cfg.Sidewalk + Cfg.Lawn

	-- the ground: flat over the feeder and the whole neighbourhood
	local F = Cfg.Feeder
	local feeder = rectAlong(origin, dir, ringOuter - 5, h.start, F.width + 30)
	local area =
		rectAlong(origin, dir, h.start - 40, h.start + h.length + Cfg.Bulb + 120, h.half * 2 + 80)
	flatten(feeder)
	flatten(area)
	table.insert(out.rects, feeder)
	table.insert(out.rects, area)

	-- the feeder road with a double yellow
	local a, b = origin + dir * (ringOuter - 5), origin + dir * (h.start + 2)
	local len = (b - a).Magnitude
	part(
		folder,
		Vector3.new(F.width, 1, len),
		CFrame.lookAt((a + b) / 2, b) - Vector3.new(0, 0.4, 0),
		ASPHALT,
		Enum.Material.Asphalt
	)
	for _, o in { -0.55, 0.55 } do
		part(
			folder,
			Vector3.new(F.line, Streets.PaintThick, len),
			CFrame.lookAt((a + b) / 2, b) + perp * o + Vector3.new(0, Streets.PaintHeight, 0),
			Color3.fromRGB(240, 196, 60)
		)
	end
	sign(folder, b - dir * 30 + perp * (F.width / 2 + 10), -dir, h.name)

	-- the streets: the spine, then side streets off both sides
	local streets: { Street } = {}
	local wave = random:NextNumber(Cfg.SpineWave[1], Cfg.SpineWave[2])
	local spine: { Vector3 } = {}
	local u = 0
	while u <= h.length do
		local v = wave * math.sin(u / h.length * math.pi * 1.6)
		table.insert(spine, origin + dir * (h.start + u) + perp * v)
		u += Cfg.Step
	end
	table.insert(streets, { pts = spine, bulb = true })
	for _, s in { -1, 1 } do
		local at = Cfg.BranchFirst
			+ (
				if s > 0
					then 0
					else random:NextNumber(Cfg.BranchStagger[1], Cfg.BranchStagger[2])
						* Cfg.BranchGap[1]
			)
		while at < h.length - 140 do
			local i = math.floor(at / Cfg.Step) + 1
			local base = spine[i]
			local v0 = (base - origin):Dot(perp)
			local reach = h.half - Cfg.BranchEnd - s * v0
			local bend = random:NextNumber(-1, 1) * Cfg.BranchBend
			local pts: { Vector3 } = {}
			local t = 0
			while t <= reach do
				local k = t / reach
				table.insert(pts, base + perp * (s * t) + dir * (bend * k * k))
				t += Cfg.Step
			end
			if #pts >= 4 then
				table.insert(streets, { pts = pts, bulb = true })
			end
			at += random:NextNumber(Cfg.BranchGap[1], Cfg.BranchGap[2])
		end
	end

	-- dense points along every street, for keeping lots and sidewalks off them
	local dense: { { p: Vector3, street: number } } = {}
	for n, st in streets do
		for i = 1, #st.pts - 1 do
			local p0, p1 = st.pts[i], st.pts[i + 1]
			for f = 0, 0.99, 0.25 do
				table.insert(dense, { p = p0:Lerp(p1, f), street = n })
			end
		end
		table.insert(dense, { p = st.pts[#st.pts], street = n })
	end
	local function nearest(p: Vector3, skip: number?): number
		local best = math.huge
		for _, d in dense do
			if d.street ~= skip then
				local dx, dz = d.p.X - p.X, d.p.Z - p.Z
				local dd = dx * dx + dz * dz
				if dd < best then
					best = dd
				end
			end
		end
		return math.sqrt(best)
	end

	-- lay the streets: asphalt, a cul-de-sac bulb at the end, sidewalks that stop at other streets' mouths
	local concrete = rgb(Cfg.Concrete)
	local sideOff = roadHalf + Cfg.Verge + Cfg.Sidewalk / 2
	local clearMouth = roadHalf + Cfg.Verge + Cfg.Sidewalk + 3
	local lampSide = 1
	for n, st in streets do
		lay(folder, st.pts, Cfg.Road, -0.4, 1, ASPHALT, Enum.Material.Asphalt)
		local last = st.pts[#st.pts]
		if st.bulb then
			disc(
				folder,
				last - Vector3.new(0, 0.4, 0),
				Cfg.Bulb * 2,
				1,
				ASPHALT,
				Enum.Material.Asphalt
			)
		end
		for _, side in { -1, 1 } do
			local run: { Vector3 } = {}
			local function flush()
				if #run >= 2 then
					lay(folder, run, Cfg.Sidewalk, 0, 0.6, concrete, Enum.Material.Concrete)
				end
				run = {}
			end
			for i = 1, #st.pts do
				local _, right = frame(st.pts, i)
				local p = st.pts[i] + right * side * sideOff
				local clear = nearest(p, n) > clearMouth
					and (not st.bulb or (p - last).Magnitude > Cfg.Bulb + Cfg.Sidewalk)
				if clear then
					table.insert(run, p)
					table.insert(out.walkPoints, p)
				else
					flush()
				end
			end
			flush()
		end
		-- lamps along the sidewalk, sides taking turns
		local walked = Cfg.LampEvery / 2
		for i = 2, #st.pts do
			walked += (st.pts[i] - st.pts[i - 1]).Magnitude
			if walked >= Cfg.LampEvery then
				local _, right = frame(st.pts, i)
				local p = st.pts[i] + right * lampSide * (roadHalf + Cfg.Verge + Cfg.Sidewalk + 1)
				if nearest(p, n) > clearMouth + 4 then
					LotKit.lamp(props, p)
					walked = 0
					lampSide = -lampSide
				end
			end
		end
		for i = 1, #st.pts, 6 do
			table.insert(out.spawnPoints, st.pts[i] + Vector3.new(0, 0.2, 0))
		end
	end

	-- the lots: houses along both sides of every street and round each cul-de-sac
	local lots: { Lot } = {}
	local lastPalette: number? = nil
	local function inArea(p: Vector3): boolean
		local lu, lv = (p - origin):Dot(dir), (p - origin):Dot(perp)
		return lu > h.start - 20
			and lu < h.start + h.length + Cfg.Bulb + 100
			and math.abs(lv) < h.half + 30
	end
	local function try(c: Vector3, face: Vector3)
		local kind = HouseRules.pickType(h.types, random:NextNumber())
		local T = (Houses.Types :: any)[kind] :: Houses.HouseType
		if not inArea(c) then
			return
		end
		local right = Vector3.new(-face.Z, 0, face.X)
		local front = setback - 5
		for _, corner in
			{
				c + face * (T.depth / 2) + right * (T.width / 2),
				c + face * (T.depth / 2) - right * (T.width / 2),
				c - face * (T.depth / 2),
			}
		do
			if nearest(corner) < front then
				return
			end
		end
		if nearest(c) < setback + T.depth / 2 - 6 then
			return
		end
		for _, l in lots do
			if (l.c - c).Magnitude < math.max(Cfg.HouseClear, (l.w + T.width) / 2 + 8) then
				return
			end
		end
		local pal = HouseRules.pickPalette(#Houses.Palettes, lastPalette, random:NextNumber())
		lastPalette = pal
		local place = HouseKit.build(
			buildings,
			kind,
			c,
			face,
			Houses.Palettes[pal],
			random:NextNumber() < 0.5,
			"SuburbHome" .. (#out.places + 1)
		)
		table.insert(out.places, place)
		table.insert(lots, { c = c, out = face, w = T.width, depth = T.depth })

		-- the front: a driveway to the road, a path to the door, a mailbox, maybe a tree and a car
		local C = Cfg.Chances
		local side = if random:NextNumber() < 0.5 then 1 else -1
		local driveLen = setback - roadHalf
		local dl = side * (T.width / 2 - Cfg.Driveway / 2 - 1)
		local drive = c + face * (T.depth / 2 + driveLen / 2) + right * dl
		part(
			folder,
			Vector3.new(Cfg.Driveway, 0.6, driveLen + 0.5),
			CFrame.lookAt(drive, drive + face),
			concrete,
			Enum.Material.Concrete
		)
		local doorLat = math.clamp((place.door - c):Dot(right), -T.width / 2 + 3, T.width / 2 - 3)
		if math.abs(doorLat - dl) > Cfg.Driveway / 2 + Cfg.Path then
			local path = c + face * (T.depth / 2 + Cfg.Lawn / 2) + right * doorLat
			part(
				folder,
				Vector3.new(Cfg.Path, 0.5, Cfg.Lawn + 0.5),
				CFrame.lookAt(path, path + face),
				concrete:Lerp(Color3.new(1, 1, 1), 0.2),
				Enum.Material.Pavement
			)
		end
		local box = c
			+ face * (T.depth / 2 + Cfg.Lawn - 1.5)
			+ right * (dl + side * (Cfg.Driveway / 2 + 2))
		local mail = prop(props, "Mailbox")
		part(
			mail,
			Vector3.new(0.5, 3.6, 0.5),
			CFrame.new(box + Vector3.new(0, 1.8, 0)),
			rgb(Cfg.Fence),
			Enum.Material.Wood
		)
		part(
			mail,
			Vector3.new(1.4, 1.2, 2.2),
			CFrame.lookAt(box, box + face) + Vector3.new(0, 4, 0),
			rgb(Cfg.Mailbox),
			Enum.Material.Metal
		)
		if random:NextNumber() < C.tree then
			Greenery.tree(
				props,
				c + face * (T.depth / 2 + Cfg.Lawn * 0.55) - right * side * (T.width / 2 - 5),
				random
			)
		end
		if random:NextNumber() < C.car then
			local at = c + face * (T.depth / 2 + 14) + right * dl + Vector3.new(0, 0.3, 0)
			LotKit.car(props, Lots.Cars, CFrame.lookAt(at, at - face), random)
		end

		-- the back garden: a fence round it (if it doesn't run into a neighbour or a street), maybe a pool
		local g = c - face * (T.depth / 2 + Cfg.Garden / 2)
		local roomy = nearest(g) > roadHalf + Cfg.Garden / 2 + 4
		for _, l in lots do
			if l.c ~= c and (l.c - g).Magnitude < l.depth / 2 + Cfg.Garden / 2 + 6 then
				roomy = false
			end
		end
		if roomy then
			SuburbKit.garden(folder, props, c, face, T.width, T.depth, random)
		end
	end

	for _, st in streets do
		-- along both sides, a lot every LotGap
		local walked = 0
		local nextAt = Cfg.LotGap * 0.8
		for i = 2, #st.pts do
			walked += (st.pts[i] - st.pts[i - 1]).Magnitude
			if walked >= nextAt and (not st.bulb or i < #st.pts - 1) then
				nextAt += Cfg.LotGap
				local _, right = frame(st.pts, i)
				for _, side in { -1, 1 } do
					local probe = HouseRules.pickType(h.types, 0.5)
					local depth = ((Houses.Types :: any)[probe] :: Houses.HouseType).depth
					try(st.pts[i] + right * side * (setback + depth / 2), -right * side)
				end
			end
		end
		-- round the cul-de-sac
		if st.bulb then
			local along = frame(st.pts, #st.pts)
			for _, angle in { -1.15, 0, 1.15 } do
				local way = (CFrame.Angles(0, angle, 0) * along).Unit
				try(
					st.pts[#st.pts] + way * (Cfg.Bulb + Cfg.Lawn + Cfg.Verge + Cfg.Sidewalk + 13),
					-way
				)
			end
		end
		task.wait() -- many houses: yield between streets so the build doesn't time out
	end

	-- small clumps of trees on the open grass left between the gardens
	local S = Cfg.Spinney
	local placed = 0
	for _ = 1, S.n * S.tries do
		if placed >= S.n then
			break
		end
		local p = origin
			+ dir * (h.start + random:NextNumber(0, h.length))
			+ perp * random:NextNumber(-h.half, h.half)
		local clear = nearest(p) > roadHalf + Cfg.Verge + Cfg.Sidewalk + S.clear
		for _, l in lots do
			if (l.c - p).Magnitude < l.depth / 2 + Cfg.Garden + S.clear then
				clear = false
				break
			end
		end
		if clear then
			placed += 1
			for _ = 1, random:NextInteger(S.trees[1], S.trees[2]) do
				local ang, dist =
					random:NextNumber(0, math.pi * 2), random:NextNumber(0, S.clear - 8)
				Greenery.tree(
					props,
					p + Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist),
					random
				)
			end
		end
	end
end

function SuburbKit.build(
	ringOuter: number,
	static: Instance,
	buildings: Instance,
	props: Instance,
	random: Random
): Result
	local out: Result = { rects = {}, places = {}, walkPoints = {}, spawnPoints = {} }
	for _, h in Cfg.Hoods do
		hood(h, ringOuter, static, buildings, props, random, out)
	end
	return out
end

return SuburbKit
