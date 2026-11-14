--!strict
-- The countryside from Config/Country: hills, woods and islands past the map's edge, the farm, the motocross
-- track, the west-coast beaches and lighthouse, the pine forest and lake, the desert's blurred edge, and the
-- small fills used by OutskirtsKit (ring cells) and MapBuilder (outer sidewalk, parking bays, plaza stalls).
-- Hills and dirt are terrain (no parts); woods and pines are one-piece meshes; smashable things go in the
-- buildings folder, knockable things are props.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Country)
local Outskirts = require(ReplicatedStorage.Shared.Config.Outskirts)
local LandCfg = require(ReplicatedStorage.Shared.Config.Land)
local Land = require(ReplicatedStorage.Shared.Rules.Land)
local Greenery = require(script.Parent.Greenery)
local PaintKit = require(script.Parent.PaintKit)
local Places = require(script.Parent.Places)

local CountryKit = {}

export type Rect = { x: number, z: number, w: number, d: number }
export type Ctx = {
	static: Folder,
	buildings: Folder,
	props: Folder,
	random: Random,
	half: number, -- half the old square ground (the beaches and the straight coast reach this far)
	reach: number, -- the island's furthest edge from the middle
	allowed: (x: number, z: number, r: number) -> boolean, -- open ground: a circle this big fits inside the edge's fill band
	seaEdge: number, -- x of the west coast (the port's quay)
	port: Rect,
	desert: Rect,
	connectors: { Rect },
}

local SEA_DEPTH = Outskirts.Port.SeaDepth -- the sea past the edge is as deep as the port's
local MOUND_STEP = Cfg.Edge.MoundStep
local BELT_SIZE = (ReplicatedStorage:WaitForChild("SceneryModels"):WaitForChild("Belt") :: MeshPart).Size
local BELT_HEIGHT = BELT_SIZE.Y
CountryKit.beltLength = BELT_SIZE.X -- the woods mesh's long side, at full size

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local WHITE = Color3.fromRGB(240, 240, 236)
local STEEL = Color3.fromRGB(70, 74, 80)
local ROAD = Color3.fromRGB(58, 60, 66)
local SAND = Color3.fromRGB(222, 196, 140)
local WATER = Color3.fromRGB(40, 110, 140)
local WOOD = Color3.fromRGB(150, 112, 76)

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

local function paint(parent: Instance, size: Vector3, cf: CFrame, color: Color3): Part
	local p = part(parent, size, cf, color)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- an upright cylinder standing on `at`
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

-- a flat disc lying on the ground at `at`
local function disc(parent: Instance, thick: number, dia: number, at: Vector3, color: Color3): Part
	return post(parent, thick, dia, at, color)
end

local function prop(folder: Instance, kind: string): Model
	local m = Instance.new("Model")
	m.Name = kind
	m:SetAttribute("Prop", kind)
	m.Parent = folder
	return m
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function between(random: Random, range: { number }): number
	return random:NextNumber(range[1], range[2])
end

local function pick(random: Random, list: { { number } }): Color3
	return rgb(list[random:NextInteger(1, #list)])
end

local function inside(r: Rect, x: number, z: number, pad: number): boolean
	return math.abs(x - r.x) < r.w / 2 + pad and math.abs(z - r.z) < r.d / 2 + pad
end

-- terrain mounds (buried balls); `hills` keeps them so things can be stood on the slopes
-- a ball's cap (cy, r) or, with `h`, a bell `h` tall reaching out to r
type Ball = { x: number, z: number, cy: number, r: number, h: number?, peak: number? }

-- a smooth hill written voxel by voxel: a bell (cosine) profile `height` tall that flattens into the ground at
-- `radius`, so it has no rim or terraces; merged with what is already there (never digs). It is filled from
-- `floor` up (the ground's underside if not given); given a floor (islands from the sea bed), water counts as
-- empty.
local BELL_TILE = 128
local function bell(
	x: number,
	z: number,
	radius: number,
	height: number,
	material: Enum.Material,
	floor: number?
)
	local terrain = workspace.Terrain
	local function down(v: number): number
		return math.floor(v / 4) * 4
	end
	local function up(v: number): number
		return math.ceil(v / 4) * 4
	end
	local x0, x1, z0, z1 = down(x - radius), up(x + radius), down(z - radius), up(z + radius)
	local y0, y1 = down(floor or -4), up(height + 4)
	for tx = x0, x1 - 1, BELL_TILE do
		for tz = z0, z1 - 1, BELL_TILE do
			local region = Region3.new(
				Vector3.new(tx, y0, tz),
				Vector3.new(math.min(tx + BELL_TILE, x1), y1, math.min(tz + BELL_TILE, z1))
			)
			local mats, occs = terrain:ReadVoxels(region, 4)
			local size = mats.Size
			local changed = false
			for i = 1, size.X do
				local dx = tx + (i - 0.5) * 4 - x
				for k = 1, size.Z do
					local dz = tz + (k - 0.5) * 4 - z
					local d = math.sqrt(dx * dx + dz * dz)
					if d < radius then
						local h = height * (1 + math.cos(math.pi * d / radius)) / 2
						for j = 1, size.Y do
							local bottom = y0 + (j - 1) * 4
							local occ = math.clamp((h - bottom) / 4, 0, 1)
							-- islands (built from the sea bed) take the water's place; hills on land leave lakes be
							local wet = floor ~= nil and mats[i][j][k] == Enum.Material.Water
							if occ > 0 and (wet or occ > occs[i][j][k]) then
								occs[i][j][k] = occ
								if wet or mats[i][j][k] == Enum.Material.Air then
									mats[i][j][k] = material
								end
								changed = true
							end
						end
					end
				end
			end
			if changed then
				terrain:WriteVoxels(region, 4, mats, occs)
			end
		end
	end
end
CountryKit.bell = bell

local mounds = 0
local function mound(
	hills: { Ball }?,
	x: number,
	z: number,
	radius: number,
	height: number,
	material: Enum.Material
)
	mounds += 1
	if mounds % 6 == 0 then
		task.wait() -- terrain is slow to fill: yield so the map's build doesn't time out
	end
	local PK = Cfg.Edge.Peak
	if height >= PK.From then
		-- a mountain: concave slopes up to a point (each layer's radius shrinks as (1 - t)^Shape), grass on the
		-- lower slopes, rock above, snow on the tallest peaks' tops; stacked in flat discs from the sea floor up
		local y = -SEA_DEPTH
		local terrain = workspace.Terrain
		local layers = 0
		while y < height do
			layers += 1
			if layers % 40 == 0 then
				task.wait() -- a tall peak is many fills: yield so the build doesn't time out
			end
			local top = math.min(y + MOUND_STEP, height)
			local t = math.max((y + top) / 2, 0) / height
			local d = radius * (1 - t) ^ PK.Shape
			if d > 1 then
				local layer = if t < PK.GrassTo
					then Enum.Material.Grass
					elseif height >= PK.SnowMin and t >= PK.SnowFrom then Enum.Material.Snow
					else Enum.Material.Rock
				terrain:FillCylinder(CFrame.new(x, (y + top) / 2, z), top - y, d, layer)
			end
			y = top
		end
		if hills then
			table.insert(hills, { x = x, z = z, cy = 0, r = radius, h = height, peak = PK.Shape })
		end
		return
	end
	local r = (radius * radius / height + height) / 2
	local cy = height - r
	if height <= Cfg.Edge.BellMax then
		bell(x, z, radius, height, material)
		if hills then
			table.insert(hills, { x = x, z = z, cy = 0, r = radius, h = height })
		end
		return
	end
	-- the cap of a ball this big is too large for one FillBall, so stack it in flat discs from the sea floor up
	local step = MOUND_STEP
	local y = -SEA_DEPTH
	while y < height do
		local top = math.min(y + step, height)
		local mid = (y + top) / 2
		local d = math.sqrt(math.max(r * r - (mid - cy) ^ 2, 0))
		if d > 1 then
			workspace.Terrain:FillCylinder(
				CFrame.new(x, mid, z),
				top - y,
				math.min(d, radius * 1.1),
				material
			)
		end
		y = top
	end
	if hills then
		table.insert(hills, { x = x, z = z, cy = cy, r = r })
	end
end

-- the ground's height at (x, z) under the mounds in `hills` (0 where there are none)
local function heightAt(hills: { Ball }, x: number, z: number): number
	local y = 0
	for _, b in hills do
		local dx, dz = x - b.x, z - b.z
		local d2 = dx * dx + dz * dz
		if d2 < b.r * b.r then
			local h = b.h
			y = math.max(
				y,
				if h and b.peak
					then h * (1 - (math.sqrt(d2) / b.r) ^ (1 / b.peak))
					elseif h then h * (1 + math.cos(math.pi * math.sqrt(d2) / b.r)) / 2
					else b.cy + math.sqrt(b.r * b.r - d2)
			)
		end
	end
	return y
end

local function pine(folder: Instance, at: Vector3, height: number, random: Random)
	local p = Greenery.mesh(
		folder,
		"Pine",
		height,
		CFrame.new(at + Vector3.new(0, height / 2 - 1, 0))
			* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0),
		pick(random, Cfg.Edge.PineColours)
	)
	p.CanCollide = true
	return p
end
CountryKit.pine = pine

-- round the island's edge (Config/Land): two rows of hills, a belt of woods at their foot and pines on the
-- slopes, wherever the edge is land; the sea runs on past the west coast with islands on the horizon
local function edges(ctx: Ctx)
	local E = Cfg.Edge
	local random = ctx.random
	local hills: { Ball } = {}
	local function landAt(x: number, z: number, clear: number): boolean
		return x > Land.coast(LandCfg, ctx.seaEdge, z) + clear
	end
	-- calls `fn(theta)` every `step` studs round the edge
	local function around(step: number, fn: (theta: number) -> ())
		local theta = 0
		local count = 0
		while theta < math.pi * 2 do
			fn(theta)
			count += 1
			if count % 8 == 0 then
				task.wait() -- terrain is slow to fill: yield so the build doesn't time out
			end
			theta += step / Land.edge(LandCfg, theta)
		end
	end
	local function ray(theta: number, out: number): (Vector3, Vector3)
		local dir = Vector3.new(math.cos(theta), 0, math.sin(theta))
		return dir * (Land.edge(LandCfg, theta) + out), dir
	end
	for _, row in { E.Near, E.Far } do
		around(E.Spacing, function(theta)
			local t = theta + random:NextNumber(-0.3, 0.3) * E.Spacing / LandCfg.Radius
			local at = ray(t, between(random, row.out))
			if landAt(at.X, at.Z, 0) then
				-- skewed toward the low end, so a few big peaks stand out of the range
				local height = row.height[1]
					+ (row.height[2] - row.height[1]) * random:NextNumber() ^ row.skew
				local radius = between(random, row.radius)
					* (
						E.RadiusScale[1]
						+ (E.RadiusScale[2] - E.RadiusScale[1]) * height / row.height[2]
					)
				mound(hills, at.X, at.Z, radius, height, Enum.Material.Grass)
			end
		end)
	end
	-- a belt of woods along the hills' foot, just outside the walls, facing in
	around(E.BeltSpacing, function(theta)
		local at, out = ray(theta, E.BeltOut)
		if not landAt(at.X, at.Z, E.CoastClear) then
			return
		end
		local along = Vector3.new(-out.Z, 0, out.X)
		local y = math.min(
			heightAt(hills, at.X - along.X * E.BeltLook, at.Z - along.Z * E.BeltLook),
			heightAt(hills, at.X, at.Z),
			heightAt(hills, at.X + along.X * E.BeltLook, at.Z + along.Z * E.BeltLook)
		)
		local belt = Greenery.mesh(
			ctx.static,
			"Belt",
			1,
			CFrame.lookAt(at, at + out) + Vector3.new(0, y - E.BeltSink + BELT_HEIGHT / 2, 0),
			pick(random, E.BeltColours)
		)
		belt.CanCollide = false
		belt.CanQuery = false
	end)
	-- pines up the slopes
	local placed = 0
	local tries = 0
	while placed < E.Pines and tries < E.Pines * E.PineTries do
		tries += 1
		local at = ray(random:NextNumber(0, math.pi * 2), between(random, E.PineOut))
		if landAt(at.X, at.Z, E.CoastClear) then
			local y = heightAt(hills, at.X, at.Z)
			if y > E.PineMinHeight then
				local p = pine(
					ctx.static,
					Vector3.new(at.X, y, at.Z),
					between(random, E.PineHeight),
					random
				)
				p.CanCollide = false
				p.CanQuery = false
				placed += 1
			end
		end
	end
	-- islands on the horizon, off the west coast
	local spread = LandCfg.CoastStraight + E.IslandJitter
	for k = 1, E.Islands do
		local z = -spread
			+ (k - 0.5) / E.Islands * spread * 2
			+ random:NextNumber(-E.IslandJitter, E.IslandJitter)
		local x = Land.coast(LandCfg, ctx.seaEdge, z)
			- LandCfg.SeaReach
			- between(random, E.IslandOut)
		local radius = between(random, E.IslandRadius)
		local height = between(random, E.IslandHeight)
		local floor = -LandCfg.DeepDepth - 4
		-- smooth bells from the sea bed: a sand skirt, then the grassy hill and one or two lower shoulders off
		-- it, so an island has a ridge and a saddle, not one round pancake
		local humps = { { x = x, z = z, r = radius, h = height } }
		for _ = 1, random:NextInteger(E.Shoulders[1], E.Shoulders[2]) do
			local a = random:NextNumber(0, math.pi * 2)
			local off = radius * random:NextNumber(0.45, 0.75)
			table.insert(humps, {
				x = x + math.cos(a) * off,
				z = z + math.sin(a) * off,
				r = radius * random:NextNumber(0.5, 0.75),
				h = height * random:NextNumber(0.45, 0.75),
			})
		end
		for _, b in humps do
			bell(b.x, b.z, b.r * E.BeachSpread, b.h * E.BeachRise, Enum.Material.Sand, floor)
		end
		for _, b in humps do
			bell(b.x, b.z, b.r, b.h, Enum.Material.Grass, floor)
		end
		-- rocks at the waterline
		for _ = 1, random:NextInteger(E.IslandRocks[1], E.IslandRocks[2]) do
			local a = random:NextNumber(0, math.pi * 2)
			local off = radius * E.BeachSpread * random:NextNumber(0.85, 1.0)
			local size = between(random, E.RockSize)
			bell(
				x + math.cos(a) * off,
				z + math.sin(a) * off,
				size,
				size * 0.7,
				Enum.Material.Rock,
				floor
			)
		end
		-- pines on the slopes (the main hump's height there, a little sunk)
		for _ = 1, random:NextInteger(E.IslandPines[1], E.IslandPines[2]) do
			local a = random:NextNumber(0, math.pi * 2)
			local d = radius * random:NextNumber(0.05, 0.55)
			local y = height * (1 + math.cos(math.pi * d / radius)) / 2 - 2
			local p = pine(
				ctx.static,
				Vector3.new(x + math.cos(a) * d, y, z + math.sin(a) * d),
				between(random, E.PineHeight) * 0.7,
				random
			)
			p.CanCollide = false
			p.CanQuery = false
		end
	end
	-- rock outcrops on the shore where the coast curves (past the beaches), half in the water
	for k = 1, E.CoastRocks do
		local side = if k % 2 == 0 then 1 else -1
		local z = side
			* random:NextNumber(LandCfg.CoastStraight + 100, LandCfg.CoastStraight + 1600)
		local x = Land.coast(LandCfg, ctx.seaEdge, z) - random:NextNumber(-10, 40)
		if Land.inset(LandCfg, x, z) > 200 then
			for _ = 1, random:NextInteger(2, 4) do
				local size = between(random, E.RockSize)
				bell(
					x + random:NextNumber(-20, 20),
					z + random:NextNumber(-30, 30),
					size,
					size * random:NextNumber(0.5, 0.9),
					Enum.Material.Rock,
					-LandCfg.DeepDepth - 4
				)
			end
		end
	end
end

-- crop rows on a field of soil, w along x
local function field(parent: Instance, centre: Vector3, w: number, d: number, crop: Color3)
	local F = Cfg.Farm
	part(
		parent,
		Vector3.new(w, 1, d),
		CFrame.new(centre + Vector3.new(0, -0.44, 0)),
		rgb(F.Soil),
		Enum.Material.Ground
	)
	local pitch = d / F.Rows
	for k = 0, F.Rows - 1 do
		paint(
			parent,
			Vector3.new(w - 6, F.RowHeight, pitch * 0.55),
			CFrame.new(centre + Vector3.new(0, 0.06 + F.RowHeight / 2, -d / 2 + (k + 0.5) * pitch)),
			crop
		).Material =
			Enum.Material.LeafyGrass
	end
end

-- a gable-roofed shed w x d (w along `along`), walls h, roof rising `roof` more; smashable
local function barn(
	parent: Instance,
	at: Vector3,
	out: Vector3,
	w: number,
	d: number,
	h: number,
	roof: number,
	wall: Color3,
	name: string
)
	local m = model(parent, name)
	local cf = CFrame.lookAt(at, at + out)
	local T = Cfg.Farm.BarnWall
	part(
		m,
		Vector3.new(w, h, T),
		cf * CFrame.new(0, h / 2, -d / 2 + T / 2),
		wall,
		Enum.Material.WoodPlanks
	)
	part(
		m,
		Vector3.new(w, h, T),
		cf * CFrame.new(0, h / 2, d / 2 - T / 2),
		wall,
		Enum.Material.WoodPlanks
	)
	for _, e in { -1, 1 } do
		part(
			m,
			Vector3.new(T, h, d - 2 * T),
			cf * CFrame.new(e * (w / 2 - T / 2), h / 2, 0),
			wall,
			Enum.Material.WoodPlanks
		)
	end
	-- gable ends: two wedges each, roof slopes over them
	for _, zf in { -1, 1 } do
		for _, e in { -1, 1 } do
			local wg = Instance.new("WedgePart")
			wg.Anchored = true
			wg.Size = Vector3.new(T, roof, w / 2)
			wg.CFrame = cf
				* CFrame.new(e * w / 4, h + roof / 2, zf * (d / 2 - T / 2))
				* CFrame.Angles(0, -e * math.pi / 2, 0) -- the wedge's tall end (its +Z) toward the ridge
			wg.Color = wall
			wg.Material = Enum.Material.WoodPlanks
			wg.Parent = m
		end
	end
	local slope = math.sqrt((w / 2) ^ 2 + roof ^ 2) + 2
	local tilt = math.atan2(roof, w / 2)
	for _, e in { -1, 1 } do
		part(
			m,
			Vector3.new(slope, 0.8, d + 3),
			cf * CFrame.new(e * w / 4, h + roof / 2 + 0.4, 0) * CFrame.Angles(0, 0, -e * tilt),
			Color3.fromRGB(70, 66, 64),
			Enum.Material.CorrodedMetal
		)
	end
	-- the big white-framed door on the front gable
	part(m, Vector3.new(w * 0.4, h * 0.75, 0.4), cf * CFrame.new(0, h * 0.375, -d / 2 - 0.2), WHITE)
	return m
end

-- the farm's big barn facing `out`: red plank walls with white corner boards, a gambrel roof (steep lower
-- slopes, a shallow top) with white trim along its edges, big X-braced doors, a hay loft door with a hoist beam,
-- side windows and a weather vane. Returns the model and its frame.
local function bigBarn(parent: Instance, at: Vector3, out: Vector3, wall: Color3): (Model, CFrame)
	local B = Cfg.Farm.Barn
	local w, d, h, roof = B.w, B.d, B.h, B.roof
	local T = Cfg.Farm.BarnWall
	local m = model(parent, "Barn")
	local cf = CFrame.lookAt(at, at + out) -- -Z is the front
	local trim = WHITE
	local dark = Color3.fromRGB(122, 32, 30)
	local roofColour = rgb(B.RoofColour)
	local function box(
		size: Vector3,
		x: number,
		y: number,
		z: number,
		colour: Color3,
		mat: Enum.Material?
	)
		return part(m, size, cf * CFrame.new(x, y, z), colour, mat)
	end
	-- a thin part from p1 to p2 (x, y in the front view) at depth z, `thick` across, `deep` along z
	local function strut(
		x1: number,
		y1: number,
		x2: number,
		y2: number,
		z: number,
		thick: number,
		deep: number,
		colour: Color3,
		mat: Enum.Material?
	)
		local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
		return part(
			m,
			Vector3.new(len, thick, deep),
			cf
				* CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, z)
				* CFrame.Angles(0, 0, math.atan2(y2 - y1, x2 - x1)),
			colour,
			mat
		)
	end
	-- walls
	for _, e in { -1, 1 } do
		box(Vector3.new(w, h, T), 0, h / 2, e * (d / 2 - T / 2), wall, Enum.Material.WoodPlanks)
		box(
			Vector3.new(T, h, d - 2 * T),
			e * (w / 2 - T / 2),
			h / 2,
			0,
			wall,
			Enum.Material.WoodPlanks
		)
	end
	-- the gambrel's outline in the front view: eave (half, h) -> knee -> ridge (0, h + roof)
	local half = w / 2
	local kx = half * (1 - B.Knee[1])
	local ky = h + roof * B.Knee[2]
	local top = h + roof
	for _, zf in { -1, 1 } do
		local z = zf * (d / 2 - T / 2)
		box(Vector3.new(kx * 2, ky - h, T), 0, (h + ky) / 2, z, wall, Enum.Material.WoodPlanks)
		for _, e in { -1, 1 } do
			for _, tri in { { half, h, kx, ky }, { kx, ky, 0, top } } do
				local run, rise = tri[1] - tri[3], tri[4] - tri[2]
				local wg = Instance.new("WedgePart")
				wg.Anchored = true
				wg.Size = Vector3.new(T, rise, run)
				wg.CFrame = cf
					* CFrame.new(e * (tri[1] + tri[3]) / 2, tri[2] + rise / 2, z)
					* CFrame.Angles(0, -e * math.pi / 2, 0) -- the wedge's tall end (its +Z) toward the ridge
				wg.Color = wall
				wg.Material = Enum.Material.WoodPlanks
				wg.TopSurface = Enum.SurfaceType.Smooth
				wg.Parent = m
			end
			-- white trim up the gable's edge, just proud of the wall
			strut(e * (half + 0.3), h, e * kx, ky, zf * (d / 2 + 0.2), 0.8, 0.5, trim)
			strut(e * kx, ky, 0, top, zf * (d / 2 + 0.2), 0.8, 0.5, trim)
		end
	end
	-- the roof: four panels lying just above the outline, overhanging the walls, and a ridge cap
	for _, e in { -1, 1 } do
		for _, seg in { { half + 1.5, h - 1, kx, ky }, { kx, ky, 0, top } } do
			local x1, y1, x2, y2 = e * seg[1], seg[2], e * seg[3], seg[4]
			local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
			local nx, ny = -(y2 - y1) / len, (x2 - x1) / len
			if ny < 0 then
				nx, ny = -nx, -ny
			end
			part(
				m,
				Vector3.new(len + 0.6, 0.8, d + 3),
				cf
					* CFrame.new((x1 + x2) / 2 + nx * 0.5, (y1 + y2) / 2 + ny * 0.5, 0)
					* CFrame.Angles(0, 0, math.atan2(y2 - y1, x2 - x1)),
				roofColour,
				Enum.Material.Metal
			)
		end
		-- white corner boards
		for _, zf in { -1, 1 } do
			box(Vector3.new(1.2, h, 1.2), e * (half - 0.3), h / 2, zf * (d / 2 - 0.3), trim)
		end
		-- three windows down each side
		for k = -1, 1 do
			box(Vector3.new(0.4, 5, 5), e * (half + 0.1), h * 0.6, k * d * 0.28, trim)
			box(
				Vector3.new(0.5, 3.8, 3.8),
				e * (half + 0.15),
				h * 0.6,
				k * d * 0.28,
				Color3.fromRGB(40, 44, 52)
			)
		end
	end
	box(Vector3.new(1.6, 1.2, d + 3.4), 0, top + 0.7, 0, trim)
	-- the big doors: two dark-red leaves in a white frame, each with a white X
	local dw, dh = w * B.Door[1], h * B.Door[2]
	local fz = -d / 2 - 0.35
	for _, e in { -1, 1 } do
		local cx = e * dw / 4
		box(Vector3.new(dw / 2 - 0.2, dh, 0.4), cx, dh / 2, fz, dark, Enum.Material.WoodPlanks)
		strut(cx - dw / 4 + 0.6, 0.6, cx + dw / 4 - 0.6, dh - 0.6, fz - 0.3, 0.7, 0.3, trim)
		strut(cx - dw / 4 + 0.6, dh - 0.6, cx + dw / 4 - 0.6, 0.6, fz - 0.3, 0.7, 0.3, trim)
		box(Vector3.new(1, dh + 1, 0.6), e * (dw / 2 + 0.5), (dh + 1) / 2, fz - 0.1, trim)
	end
	box(Vector3.new(dw + 2, 1, 0.6), 0, dh + 0.5, fz - 0.1, trim)
	box(Vector3.new(0.5, dh, 0.6), 0, dh / 2, fz - 0.25, trim)
	-- the hay loft door high in the front gable, and the hoist beam over it
	local ly = (h + ky) / 2 + 1
	box(Vector3.new(9, 8, 0.4), 0, ly, fz, trim)
	box(Vector3.new(7.4, 6.4, 0.5), 0, ly, fz - 0.1, dark, Enum.Material.WoodPlanks)
	strut(-3.4, ly - 2.9, 3.4, ly + 2.9, fz - 0.4, 0.5, 0.3, trim)
	strut(-3.4, ly + 2.9, 3.4, ly - 2.9, fz - 0.4, 0.5, 0.3, trim)
	box(Vector3.new(1, 1, 6), 0, top - 1.5, -d / 2 - 2.5, WOOD, Enum.Material.WoodPlanks)
	-- a weather vane on the ridge
	local vane = top + 1.3
	box(Vector3.new(0.3, 5, 0.3), 0, vane + 2.5, 0, STEEL, Enum.Material.Metal)
	box(Vector3.new(0.3, 0.3, 4), 0, vane + 4, 0, STEEL, Enum.Material.Metal)
	box(Vector3.new(4, 0.3, 0.3), 0, vane + 3.4, 0, STEEL, Enum.Material.Metal)
	return m, cf
end

-- a wooden corral of `w` x `d` round `centre` (frame `cf`), posts and two rails a side, a trough inside
local function corral(parent: Instance, props: Instance, cf: CFrame)
	local C = Cfg.Farm.Corral
	local w, d = C.w, C.d
	local rail = Color3.fromRGB(196, 164, 120)
	for _, side in
		{ { w, 0, -d / 2 }, { w, 0, d / 2 }, { d, math.pi / 2, -w / 2 }, { d, math.pi / 2, w / 2 } }
	do
		local len, turn, off = side[1], side[2], side[3]
		local frame = cf * CFrame.Angles(0, turn, 0) * CFrame.new(0, 0, off)
		for _, y in { 2.2, 4.4 } do
			part(
				parent,
				Vector3.new(len, 0.6, 0.4),
				frame * CFrame.new(0, y, 0),
				rail,
				Enum.Material.WoodPlanks
			)
		end
		local posts = math.max(2, math.floor(len / C.PostGap) + 1)
		for k = 0, posts - 1 do
			part(
				parent,
				Vector3.new(0.8, 5.4, 0.8),
				frame * CFrame.new(-len / 2 + k * len / (posts - 1), 2.7, 0),
				WOOD,
				Enum.Material.WoodPlanks
			)
		end
	end
	local trough = prop(props, "Trough")
	part(
		trough,
		Vector3.new(10, 2.6, 3.4),
		cf * CFrame.new(w * 0.2, 1.3, -d * 0.3),
		STEEL,
		Enum.Material.Metal
	)
	paint(
		trough,
		Vector3.new(9.2, 0.2, 2.6),
		cf * CFrame.new(w * 0.2, 2.5, -d * 0.3),
		Color3.fromRGB(60, 140, 200)
	)
end

local function farm(ctx: Ctx)
	local F = Cfg.Farm
	local r = F.Rect
	local random = ctx.random
	local folder = model(ctx.static, "Farm")
	local cols, rows = F.Fields[1], F.Fields[2]
	-- fields fill the western three quarters, the yard the east
	local fw = (r.w * 0.72 - F.FieldGap * (cols + 1)) / cols
	local fd = (r.d - F.FieldGap * (rows + 1)) / rows
	local left = r.x - r.w / 2
	local top = r.z - r.d / 2
	local crop = 0
	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			crop += 1
			local c = Vector3.new(
				left + F.FieldGap + fw / 2 + i * (fw + F.FieldGap),
				0,
				top + F.FieldGap + fd / 2 + j * (fd + F.FieldGap)
			)
			field(folder, c, fw, fd, rgb(F.Crops[(crop - 1) % #F.Crops + 1]))
			-- a wind break of trees along the field's north side
			local belt = Greenery.mesh(
				folder,
				"Belt",
				fw / 230,
				CFrame.new(c + Vector3.new(0, 0, -fd / 2 - F.FieldGap / 2))
					+ Vector3.new(0, 19 * fw / 230 - 2, 0),
				pick(random, Cfg.Edge.BeltColours)
			)
			belt.Size = Vector3.new(belt.Size.X, belt.Size.Y, 12)
		end
	end
	-- the yard: barn and silo facing west toward the fields, hay bales round them
	local yard = Vector3.new(r.x + r.w * 0.36, 0, r.z)
	local _, barnCf =
		bigBarn(ctx.buildings, yard + Vector3.new(0, 0, -40), Vector3.new(-1, 0, 0), rgb(F.BarnRed))
	-- a dirt yard in front of the doors (terrain), and a corral beside it
	local B = F.Barn
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, c in { { -1, 0 }, { 1, 0 }, { -1, 1 }, { 1, 1 } } do
		local p = (barnCf * CFrame.new(c[1] * (B.w / 2 + 16), 0, -B.d / 2 - c[2] * F.Yard)).Position
		lo, hi = lo:Min(p), hi:Max(p)
	end
	workspace.Terrain:ReplaceMaterial(
		Region3.new(Vector3.new(lo.X, -10, lo.Z), Vector3.new(hi.X, 4, hi.Z)):ExpandToGrid(4),
		4,
		Enum.Material.Grass,
		Enum.Material.Ground
	)
	local corralCf = barnCf * CFrame.new(B.w / 2 + F.Corral.w / 2 + 6, 0, -B.d / 2 + F.Corral.d / 2)
	corral(ctx.static, ctx.props, corralCf)
	local silo = model(ctx.buildings, "Silo")
	local S = F.Silo
	local at = yard + Vector3.new(10, 0, 30)
	post(silo, S.h, S.dia, at, Color3.fromRGB(200, 200, 204)).Material = Enum.Material.Metal
	local dome = part(
		silo,
		Vector3.one * S.dia,
		CFrame.new(at + Vector3.new(0, S.h, 0)),
		Color3.fromRGB(150, 156, 164)
	)
	dome.Shape = Enum.PartType.Ball
	for k = 1, F.Bales do
		local a = k / F.Bales * math.pi * 2
		local p = yard + Vector3.new(math.cos(a) * 75, 0, math.sin(a) * 90)
		local inCorral = corralCf:PointToObjectSpace(p)
		if
			math.abs(inCorral.X) < F.Corral.w / 2 + 6
			and math.abs(inCorral.Z) < F.Corral.d / 2 + 6
		then
			continue
		end
		local bale = prop(ctx.props, "Bale")
		local b = part(
			bale,
			Vector3.new(F.BaleSize[2], F.BaleSize[1], F.BaleSize[1]),
			CFrame.new(p + Vector3.new(0, F.BaleSize[1] / 2, 0)) * CFrame.Angles(0, a, 0),
			rgb(F.Hay),
			Enum.Material.Fabric
		)
		b.Shape = Enum.PartType.Cylinder
	end
end

local function moto(ctx: Ctx)
	local M = Cfg.Moto
	local r = M.Rect
	local random = ctx.random
	local folder = model(ctx.static, "Motocross")
	local lx, lz = M.Loop[1] / 2, M.Loop[2] / 2
	local W = M.Width
	local dirt = rgb(M.Dirt)
	-- straights (north and south, east and west) and corner pads: a rounded box loop of packed dirt
	part(
		folder,
		Vector3.new(M.Loop[1] + W, 1, W),
		CFrame.new(r.x, -0.42, r.z - lz),
		dirt,
		Enum.Material.Ground
	)
	part(
		folder,
		Vector3.new(M.Loop[1] + W, 1, W),
		CFrame.new(r.x, -0.42, r.z + lz),
		dirt,
		Enum.Material.Ground
	)
	part(
		folder,
		Vector3.new(W, 1, M.Loop[2] - W),
		CFrame.new(r.x - lx, -0.42, r.z),
		dirt,
		Enum.Material.Ground
	)
	part(
		folder,
		Vector3.new(W, 1, M.Loop[2] - W),
		CFrame.new(r.x + lx, -0.42, r.z),
		dirt,
		Enum.Material.Ground
	)
	-- a cross-track through the middle with a big table-top
	part(
		folder,
		Vector3.new(W, 1, M.Loop[2] - W),
		CFrame.new(r.x, -0.42, r.z),
		dirt,
		Enum.Material.Ground
	)
	mound(nil, r.x, r.z, M.JumpRadius * 2.2, M.JumpHeight * 1.6, Enum.Material.Ground)
	-- jumps along the straights, berms on the outside of the corners
	for k = 1, M.Jumps do
		local t = (k - 0.5) / M.Jumps
		local x, z
		if k % 2 == 0 then
			x, z = r.x + (t * 2 - 1) * lx * 0.8, r.z + (if k % 4 == 0 then lz else -lz)
		else
			x, z = r.x + (if k % 4 == 1 then lx else -lx), r.z + (t * 2 - 1) * lz * 0.8
		end
		mound(nil, x, z, M.JumpRadius, M.JumpHeight, Enum.Material.Ground)
	end
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		mound(
			nil,
			r.x + c[1] * (lx + W * 0.9),
			r.z + c[2] * (lz + W * 0.9),
			W * 1.4,
			10,
			Enum.Material.Ground
		)
	end
	-- the start gate on the south straight: two posts and a banner
	local gate = Vector3.new(r.x - lx * 0.4, 0, r.z + lz)
	for _, e in { -1, 1 } do
		post(folder, 16, 1.6, gate + Vector3.new(0, 0, e * (W / 2 + 2)), STEEL)
	end
	Places.sign(
		folder,
		Vector3.new(1, 6, W + 4),
		CFrame.new(gate + Vector3.new(0, 15, 0)) * CFrame.Angles(0, math.pi / 2, 0),
		"MOTOCROSS",
		Color3.fromRGB(30, 30, 32),
		Color3.fromRGB(250, 210, 70),
		true
	)
	for _ = 1, M.Tyres do
		local a = random:NextNumber(0, math.pi * 2)
		local p = Vector3.new(r.x, 0, r.z)
			+ Vector3.new(math.cos(a) * (lx - W), 0, math.sin(a) * (lz - W))
		local m = prop(ctx.props, "Tyres")
		post(m, 4, 5, p, Color3.fromRGB(30, 30, 32))
	end
end

local function beaches(ctx: Ctx)
	local B = Cfg.Beach
	local random = ctx.random
	local half = ctx.half
	local x0 = ctx.seaEdge
	local folder = model(ctx.static, "Beaches")
	for _, side in { -1, 1 } do
		local from = ctx.port.z + side * (ctx.port.d / 2 + B.Gap)
		local len = half - math.abs(from)
		local zc = from + side * len / 2
		-- (the sand itself is terrain, laid with the ground: OutskirtsKit)
		-- umbrellas with a towel under each
		for _ = 1, B.Umbrellas do
			local at = Vector3.new(
				x0 + random:NextNumber(25, B.Width - 30),
				0,
				zc + random:NextNumber(-len / 2 + 40, len / 2 - 120)
			)
			local colour = pick(random, B.UmbrellaColours)
			local m = prop(ctx.props, "Umbrella")
			post(m, 10, 0.5, at, WHITE)
			disc(m, 1, 14, at + Vector3.new(0, 9.5, 0), colour)
			paint(
				folder,
				Vector3.new(4, 0.2, 8),
				CFrame.new(at + Vector3.new(3, 0.12, 2))
					* CFrame.Angles(0, random:NextNumber(-0.5, 0.5), 0),
				colour
			)
		end
		-- a lifeguard tower
		local tower = model(ctx.buildings, "Lifeguard")
		local t = Vector3.new(x0 + B.Width * 0.6, 0, zc)
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			part(
				tower,
				Vector3.new(0.8, 9, 0.8),
				CFrame.new(t + Vector3.new(c[1] * 4, 4.5, c[2] * 4)),
				WHITE
			)
		end
		part(
			tower,
			Vector3.new(10, 1, 10),
			CFrame.new(t + Vector3.new(0, 9.5, 0)),
			WOOD,
			Enum.Material.WoodPlanks
		)
		part(
			tower,
			Vector3.new(8, 6, 8),
			CFrame.new(t + Vector3.new(0, 13, 0)),
			Color3.fromRGB(230, 70, 60)
		)
		part(tower, Vector3.new(11, 0.6, 11), CFrame.new(t + Vector3.new(0, 16.3, 0)), WHITE)
	end
	-- a pier out into the sea from the south beach
	local pz = ctx.port.z + ctx.port.d / 2 + B.Gap + (half - ctx.port.d / 2) * 0.4
	local pier = model(ctx.buildings, "Pier")
	part(
		pier,
		Vector3.new(B.PierLength, 1, B.PierWidth),
		CFrame.new(x0 - B.PierLength / 2 + 20, 1.5, pz),
		WOOD,
		Enum.Material.WoodPlanks
	)
	for k = 0, 3 do
		for _, e in { -1, 1 } do
			post(
				pier,
				16,
				1.4,
				Vector3.new(x0 - k * B.PierLength / 4, -14, pz + e * (B.PierWidth / 2 - 1)),
				WOOD
			)
		end
	end
	-- the lighthouse at the south end of the coast: a rocky knoll, a plinth, red and white bands with a door and
	-- little windows facing the land, a railed gallery, a glass lantern room with its lamp, a red cap; and the
	-- keeper's cottage beside it
	local L = B.Lighthouse
	local lh = model(ctx.buildings, "Lighthouse")
	local at = Vector3.new(x0 + 30, 0, half - 260)
	local red = rgb(B.LighthouseRed)
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.4
		bell(
			at.X + math.cos(a) * L.dia * 0.9,
			at.Z + math.sin(a) * L.dia * 0.9,
			L.dia * 0.7,
			5 + k % 2 * 3,
			Enum.Material.Rock
		)
	end
	post(lh, 3, L.dia + 8, at, Color3.fromRGB(200, 200, 196)).Material = Enum.Material.Concrete
	local base = at + Vector3.new(0, 3, 0)
	local band = L.h / 5
	for k = 0, 4 do
		post(
			lh,
			band,
			L.dia * (1 - k * 0.06),
			base + Vector3.new(0, k * band, 0),
			if k % 2 == 0 then WHITE else red
		)
	end
	local landward = Vector3.xAxis -- the land is east of the coast
	local r0 = L.dia / 2
	part(
		lh,
		Vector3.new(0.6, 8, 5.6),
		CFrame.new(base + landward * (r0 - 0.1) + Vector3.new(0, 4, 0)),
		WHITE
	)
	part(
		lh,
		Vector3.new(0.6, 7, 4.2),
		CFrame.new(base + landward * (r0 + 0.1) + Vector3.new(0, 3.5, 0)),
		red
	)
	for k = 1, 3 do
		local y = k * band + band / 2
		local rk = r0 * (1 - k * 0.06)
		part(
			lh,
			Vector3.new(0.6, 3, 2.2),
			CFrame.new(base + landward * (rk - 0.1) + Vector3.new(0, y, 0)),
			Color3.fromRGB(36, 44, 56)
		)
	end
	-- the gallery: a platform, a ring of posts and a rail of short segments
	local gy = base.Y + L.h
	local gr = L.dia / 2 + 2
	disc(lh, 1, gr * 2, Vector3.new(at.X, gy, at.Z), STEEL)
	local n = L.RailPosts
	for k = 0, n - 1 do
		local a0, a1 = k / n * math.pi * 2, (k + 1) / n * math.pi * 2
		local p0 =
			Vector3.new(at.X + math.cos(a0) * (gr - 0.4), gy + 1, at.Z + math.sin(a0) * (gr - 0.4))
		local p1 =
			Vector3.new(at.X + math.cos(a1) * (gr - 0.4), gy + 1, at.Z + math.sin(a1) * (gr - 0.4))
		post(lh, 3, 0.35, p0, WHITE)
		local mid = (p0 + p1) / 2 + Vector3.new(0, 3, 0)
		part(
			lh,
			Vector3.new(0.3, 0.3, (p1 - p0).Magnitude + 0.2),
			CFrame.lookAt(mid, mid + (p1 - p0)),
			WHITE
		)
	end
	-- the lantern room: a glass drum round the lamp, a red cap and a finial
	local glass =
		post(lh, 8, L.dia * 0.62, Vector3.new(at.X, gy + 0.5, at.Z), Color3.fromRGB(180, 220, 240))
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.45
	glass:SetAttribute("Glass", true)
	local lamp =
		post(lh, 4, L.dia * 0.3, Vector3.new(at.X, gy + 2.5, at.Z), Color3.fromRGB(255, 240, 180))
	lamp.Material = Enum.Material.Neon
	lamp.CastShadow = false
	disc(lh, 1, L.dia * 0.72, Vector3.new(at.X, gy + 8.5, at.Z), red)
	local cap =
		part(lh, Vector3.one * L.dia * 0.6, CFrame.new(at + Vector3.new(0, gy - at.Y + 10, 0)), red)
	cap.Shape = Enum.PartType.Ball
	post(lh, 4, 0.4, Vector3.new(at.X, gy + 14, at.Z), STEEL)
	-- the keeper's cottage, inland of the tower
	local K = L.Cottage
	local cottage = model(ctx.buildings, "Cottage")
	local cc =
		CFrame.lookAt(at + Vector3.new(K.Off, 0, 0), at + Vector3.new(K.Off, 0, 0) - landward) -- door faces the sea
	local function box(
		size: Vector3,
		x: number,
		y: number,
		z: number,
		colour: Color3,
		mat: Enum.Material?
	)
		return part(cottage, size, cc * CFrame.new(x, y, z), colour, mat)
	end
	box(Vector3.new(K.w, K.h, K.d), 0, K.h / 2, 0, WHITE, Enum.Material.Plaster)
	local slope = math.sqrt((K.d / 2) ^ 2 + K.roof ^ 2) + 1.2
	local tilt = math.atan2(K.roof, K.d / 2)
	for _, e in { -1, 1 } do
		part(
			cottage,
			Vector3.new(K.w + 2, 0.8, slope),
			cc * CFrame.new(0, K.h + K.roof / 2 + 0.3, e * K.d / 4) * CFrame.Angles(e * tilt, 0, 0),
			red
		)
		for _, zf in { -1, 1 } do
			local g = Instance.new("WedgePart")
			g.Anchored = true
			g.Size = Vector3.new(0.4, K.roof, K.d / 2)
			g.CFrame = cc
				* CFrame.new(e * (K.w / 2 - 0.2), K.h + K.roof / 2, zf * K.d / 4)
				* CFrame.Angles(0, if zf > 0 then math.pi else 0, 0)
			g.Color = WHITE
			g.Material = Enum.Material.Plaster
			g.Parent = cottage
		end
	end
	box(Vector3.new(3.6, 6.4, 0.4), -K.w * 0.2, 3.2, -K.d / 2 - 0.2, Color3.fromRGB(60, 90, 140))
	for _, x in { K.w * 0.15, K.w * 0.35 } do
		box(Vector3.new(3, 3, 0.4), x, K.h * 0.55, -K.d / 2 - 0.2, Color3.fromRGB(36, 44, 56))
	end
	box(
		Vector3.new(2.4, 5, 2.4),
		K.w * 0.3,
		K.h + K.roof * 0.6,
		K.d * 0.15,
		Color3.fromRGB(150, 80, 60),
		Enum.Material.Brick
	)
end

local function forest(ctx: Ctx)
	local F = Cfg.Forest
	local r = F.Rect
	local random = ctx.random
	local folder = model(ctx.static, "Forest")
	local lake = Vector3.new(r.x + r.w * F.LakeAt[1], 0, r.z + r.d * F.LakeAt[2])
	disc(folder, 0.2, F.Lake * 2 + 16, lake, SAND).Material = Enum.Material.Sand
	local water = disc(folder, 0.3, F.Lake * 2, lake, WATER)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.15
	water.Reflectance = 0.15
	-- a jetty on the south bank, a log cabin beside it
	local jetty = lake + Vector3.new(0, 0, F.Lake - 20)
	part(
		folder,
		Vector3.new(8, 0.8, 50),
		CFrame.new(jetty + Vector3.new(0, 1, 0)),
		WOOD,
		Enum.Material.WoodPlanks
	)
	local cabinAt = lake + Vector3.new(60, 0, F.Lake + 45)
	barn(ctx.buildings, cabinAt, Vector3.new(0, 0, 1), 30, 22, 10, 7, rgb(F.Log), "Cabin")
	local taken = { { at = lake, r = F.Lake + 8 + F.Clear }, { at = cabinAt, r = 22 + F.Clear } }
	local placed, tries = 0, 0
	while placed < F.Pines and tries < F.Pines * 20 do
		tries += 1
		local at = Vector3.new(
			r.x + random:NextNumber(-r.w / 2, r.w / 2),
			0,
			r.z + random:NextNumber(-r.d / 2, r.d / 2)
		)
		local free = true
		for _, t in taken do
			if (at - t.at).Magnitude < t.r then
				free = false
				break
			end
		end
		if free then
			pine(folder, at, between(random, F.PineHeight), random)
			placed += 1
		end
	end
end

-- a gas station facing `out` (toward the road), centred at `at`: forecourt, canopy on posts, two pumps, a
-- shop with a glass front, a price sign. Canopy and shop smash; pumps get knocked over.
-- a roadside gas station facing `out` (the road): a forecourt with a canopy (lit soffit, red fascia with a
-- yellow stripe) over two pump islands, a little shop with a glass front and sign at the back, a price pylon by
-- the road, and the clutter round it (air stand, ice chest, bins, oil stains, parking bays)
function CountryKit.gasStation(ctx: Ctx, at: Vector3, out: Vector3)
	local G = Cfg.Cells.Gas
	local red = rgb(Cfg.Cells.GasRed)
	local yellow = rgb(G.Accent)
	local cream = Color3.fromRGB(236, 232, 222)
	local cf = CFrame.lookAt(at, at + out) -- -Z faces the road
	local pd = G.pad
	local function box(
		m: Instance,
		size: Vector3,
		x: number,
		y: number,
		z: number,
		colour: Color3,
		mat: Enum.Material?
	)
		return part(m, size, cf * CFrame.new(x, y, z), colour, mat)
	end
	-- ground: asphalt pad, a concrete forecourt under the canopy, kerbs, bays and stains (all static)
	part(
		ctx.static,
		Vector3.new(pd[1], 1, pd[2]),
		cf + Vector3.new(0, -0.41, 0),
		ROAD,
		Enum.Material.Asphalt
	)
	local c = G.canopy
	local cz = -pd[2] / 2 + 6 + c[2] / 2
	local apron = paint(
		ctx.static,
		Vector3.new(c[1] + 8, 0.2, c[2] + 8),
		cf * CFrame.new(0, 0.1, cz),
		Color3.fromRGB(176, 176, 172)
	)
	apron.Material = Enum.Material.Concrete
	for _, e in { -1, 1 } do
		box(
			ctx.static,
			Vector3.new(0.8, 0.5, pd[2]),
			e * (pd[1] / 2 - 0.4),
			0.25,
			0,
			WHITE,
			Enum.Material.Concrete
		)
	end
	box(
		ctx.static,
		Vector3.new(pd[1], 0.5, 0.8),
		0,
		0.25,
		pd[2] / 2 - 0.4,
		WHITE,
		Enum.Material.Concrete
	)
	local s = G.shop
	local sz = pd[2] / 2 - s[2] / 2 - 2
	for k = 0, G.Bays do
		paint(
			ctx.static,
			Vector3.new(0.4, 0.15, 12),
			cf * CFrame.new(s[1] / 2 + 4 + k * 7, 0.1, sz),
			WHITE
		)
	end
	for k = 1, 3 do
		local d = paint(
			ctx.static,
			Vector3.new(0.12, 3 + k, 3 + k),
			cf
				* CFrame.new((k - 2) * 9, 0.09, cz + (k % 2) * 5 - 2)
				* CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(40, 40, 44)
		)
		d.Shape = Enum.PartType.Cylinder
		d.Transparency = 0.45
	end

	local station = model(ctx.buildings, "GasStation")
	-- the canopy: deck, lit soffit panels, a red fascia all round with a yellow stripe under it
	box(station, Vector3.new(c[1], 1.2, c[2]), 0, c[3] + 0.6, cz, WHITE)
	for _, e in { -1, 1 } do
		box(station, Vector3.new(c[1] + 1, 2.6, 0.6), 0, c[3] + 1.3, cz + e * (c[2] / 2 + 0.3), red)
		box(station, Vector3.new(0.6, 2.6, c[2] + 1.6), e * (c[1] / 2 + 0.3), c[3] + 1.3, cz, red)
		box(
			station,
			Vector3.new(c[1] + 1.2, 0.5, 0.7),
			0,
			c[3] - 0.25,
			cz + e * (c[2] / 2 + 0.35),
			yellow
		)
		box(
			station,
			Vector3.new(0.7, 0.5, c[2] + 1.8),
			e * (c[1] / 2 + 0.35),
			c[3] - 0.25,
			cz,
			yellow
		)
	end
	for _, ex in { -1, 1 } do
		for _, ez in { -1, 1 } do
			local panel = box(
				station,
				Vector3.new(c[1] * 0.38, 0.2, c[2] * 0.3),
				ex * c[1] * 0.24,
				c[3] - 0.05,
				cz + ez * c[2] * 0.22,
				Color3.fromRGB(255, 250, 230),
				Enum.Material.Neon
			)
			panel.CastShadow = false
		end
	end
	-- two pump islands, each a kerb with a post holding up the canopy, two pumps and yellow bollards at the ends
	for _, ex in { -1, 1 } do
		local x = ex * c[1] * 0.24
		box(station, Vector3.new(4, 0.8, c[2] * 0.62), x, 0.4, cz, cream, Enum.Material.Concrete)
		box(station, Vector3.new(1.2, c[3] - 0.8, 1.2), x, (c[3] - 0.8) / 2 + 0.8, cz, WHITE)
		for _, ez in { -1, 1 } do
			local pump = prop(ctx.props, "Pump")
			local pz = cz + ez * c[2] * 0.17
			part(pump, Vector3.new(2.6, 5.6, 1.8), cf * CFrame.new(x, 3.6, pz), WHITE)
			part(pump, Vector3.new(2.8, 1.4, 2), cf * CFrame.new(x, 7.1, pz), red)
			for _, side in { -1, 1 } do
				paint(
					pump,
					Vector3.new(1.6, 1.1, 0.1),
					cf * CFrame.new(x, 5.2, pz + side * 0.92),
					Color3.fromRGB(28, 32, 40)
				)
				paint(
					pump,
					Vector3.new(0.3, 3.4, 0.3),
					cf * CFrame.new(x + 1.45, 3.4, pz + side * 0.5),
					Color3.fromRGB(30, 30, 32)
				)
			end
			local b = post(
				station,
				3.2,
				0.9,
				(cf * CFrame.new(x, 0.8, cz + ez * (c[2] * 0.31 + 0.2))).Position,
				yellow
			)
			b.Name = "Bollard"
		end
	end

	-- the shop at the back: plaster box, a glass front with white mullions and a door, a red fascia with a
	-- yellow stripe and the MART sign, a parapet and two roof units
	local back = cf * CFrame.new(0, 0, sz)
	local function shop(
		size: Vector3,
		x: number,
		y: number,
		z: number,
		colour: Color3,
		mat: Enum.Material?
	)
		return part(station, size, back * CFrame.new(x, y, z), colour, mat)
	end
	shop(Vector3.new(s[1], s[3], s[2]), 0, s[3] / 2, 0, cream, Enum.Material.Plaster)
	local front = -s[2] / 2 - 0.2
	local glass = shop(
		Vector3.new(s[1] - 4, s[3] * 0.58, 0.4),
		0,
		s[3] * 0.36,
		front,
		Color3.fromRGB(96, 140, 170),
		Enum.Material.Glass
	)
	glass.Transparency = 0.25
	glass:SetAttribute("Glass", true)
	for k = -2, 2 do
		shop(Vector3.new(0.5, s[3] * 0.6, 0.6), k * (s[1] - 4) / 4, s[3] * 0.36, front - 0.1, WHITE)
	end
	shop(Vector3.new(s[1] - 3, 0.5, 0.7), 0, s[3] * 0.07 + 0.3, front - 0.1, WHITE)
	local door = shop(
		Vector3.new(4.6, 7.6, 0.5),
		-s[1] * 0.18,
		3.8,
		front - 0.35,
		Color3.fromRGB(60, 88, 110),
		Enum.Material.Glass
	)
	door.Transparency = 0.15
	shop(Vector3.new(s[1] + 1, 2.4, s[2] + 1), 0, s[3] - 0.6, 0, red)
	shop(Vector3.new(s[1] + 1.2, 0.5, s[2] + 1.2), 0, s[3] - 2, 0, yellow)
	for _, e in { -1, 1 } do
		shop(Vector3.new(s[1], 1.2, 0.6), 0, s[3] + 1.2, e * (s[2] / 2 - 0.3), cream)
		shop(Vector3.new(0.6, 1.2, s[2]), e * (s[1] / 2 - 0.3), s[3] + 1.2, 0, cream)
		shop(
			Vector3.new(4, 2.4, 3.2),
			e * s[1] * 0.22,
			s[3] + 1.2,
			s[2] * 0.15,
			Color3.fromRGB(176, 180, 186),
			Enum.Material.Metal
		)
	end
	Places.sign(
		station,
		Vector3.new(12, 2.2, 0.4),
		back * CFrame.new(s[1] * 0.12, s[3] - 0.6, front - 0.6),
		"MART",
		red,
		WHITE
	)
	-- by the shop: an ice chest, an air stand and two bins (knockable)
	local ice = prop(ctx.props, "IceChest")
	part(ice, Vector3.new(5, 3.6, 2.4), back * CFrame.new(s[1] * 0.36, 1.8, front - 1.6), WHITE)
	paint(
		ice,
		Vector3.new(4, 1.4, 0.1),
		back * CFrame.new(s[1] * 0.36, 2.2, front - 2.85),
		Color3.fromRGB(60, 140, 220)
	)
	local air = prop(ctx.props, "AirStand")
	part(
		air,
		Vector3.new(1.8, 4.6, 1.4),
		cf * CFrame.new(-pd[1] / 2 + 5, 2.3, sz - s[2] / 2 - 4),
		red
	)
	paint(
		air,
		Vector3.new(1.2, 0.8, 0.1),
		cf * CFrame.new(-pd[1] / 2 + 5, 3.6, sz - s[2] / 2 - 4.75),
		yellow
	)
	for _, e in { -1, 1 } do
		local bin = prop(ctx.props, "Bin")
		post(
			bin,
			3.4,
			2.2,
			(back * CFrame.new(e * (s[1] / 2 + 2.5), 0, front - 1)).Position,
			Color3.fromRGB(56, 110, 70)
		)
	end

	-- the price pylon by the road: a red column, a white GAS board and a dark price board, read from the road
	local signAt = (cf * CFrame.new(pd[1] / 2 - 6, 0, -pd[2] / 2 + 3)).Position
	local face = CFrame.lookAt(signAt, signAt + out:Cross(Vector3.yAxis))
	part(station, Vector3.new(2.6, 20, 2.6), face * CFrame.new(0, 10, 0), red)
	part(station, Vector3.new(11, 0.6, 3), face * CFrame.new(0, 26.6, 0), yellow)
	Places.sign(
		station,
		Vector3.new(11, 6, 2.4),
		face * CFrame.new(0, 23.3, 0),
		"GAS",
		WHITE,
		red,
		true
	)
	Places.sign(
		station,
		Vector3.new(9, 3.4, 2.2),
		face * CFrame.new(0, 18.4, 0),
		G.Price,
		Color3.fromRGB(26, 26, 30),
		yellow,
		true
	)
end

-- a wind turbine standing on `at`, its rotor facing `out`
local function turbine(parent: Instance, at: Vector3, out: Vector3, spin: number)
	local T = Cfg.Cells.Turbine
	local m = model(parent, "Turbine")
	post(m, T.h, T.dia, at, WHITE)
	local hubAt = at + Vector3.new(0, T.h + 2, 0)
	local cf = CFrame.lookAt(hubAt, hubAt + out)
	part(m, Vector3.new(4, 4, 10), cf * CFrame.new(0, 0, 2), WHITE)
	local hub = part(m, Vector3.one * 4, cf * CFrame.new(0, 0, -3.5), WHITE)
	hub.Shape = Enum.PartType.Ball
	for k = 0, 2 do
		local a = spin + k * math.pi * 2 / 3
		part(
			m,
			Vector3.new(1.6, T.blade, 0.5),
			cf * CFrame.new(0, 0, -4) * CFrame.Angles(0, 0, a) * CFrame.new(0, T.blade / 2 + 1, 0),
			WHITE
		)
	end
end

-- one cell between the city and the ring, x/z its centre, w x d its size, `out` toward the ring
function CountryKit.cell(
	ctx: Ctx,
	use: string,
	x: number,
	z: number,
	w: number,
	d: number,
	out: Vector3
)
	local random = ctx.random
	local centre = Vector3.new(x, 0, z)
	local along = Vector3.new(-out.Z, 0, out.X)
	local long = math.abs(along.X) * w + math.abs(along.Z) * d -- along the ring
	local deep = math.abs(out.X) * w + math.abs(out.Z) * d -- toward the ring
	if use == "field" then
		local folder = model(ctx.static, "Field")
		local fw, fd = long - 40, deep - 50
		field(
			folder,
			centre,
			math.abs(along.X) * fw + math.abs(along.Z) * fd,
			math.abs(along.X) * fd + math.abs(along.Z) * fw,
			pick(random, Cfg.Farm.Crops)
		)
	elseif use == "turbines" then
		for _, e in { -1, 1 } do
			turbine(
				ctx.static,
				centre + along * e * long * 0.25,
				out,
				random:NextNumber(0, math.pi)
			)
		end
		for _ = 1, 2 do
			Greenery.tree(
				ctx.props,
				centre + along * random:NextNumber(-0.4, 0.4) * long - out * deep * 0.3,
				random
			)
		end
	elseif use == "gas" then
		CountryKit.gasStation(ctx, centre + out * (deep / 2 - Cfg.Cells.Gas.pad[2] / 2 - 4), out)
		Greenery.tree(ctx.props, centre - out * deep * 0.3 + along * long * 0.3, random)
	else
		for _ = 1, 4 do
			Greenery.tree(
				ctx.props,
				centre
					+ along * random:NextNumber(-0.4, 0.4) * long
					+ out * random:NextNumber(-0.35, 0.2) * deep,
				random
			)
		end
	end
end

-- the corner cells between the city and the ring: a small grove
function CountryKit.corner(ctx: Ctx, x: number, z: number, size: number)
	for _ = 1, Cfg.Cells.CornerTrees do
		Greenery.tree(
			ctx.props,
			Vector3.new(
				x + ctx.random:NextNumber(-0.35, 0.35) * size,
				0,
				z + ctx.random:NextNumber(-0.35, 0.35) * size
			),
			ctx.random
		)
	end
end

-- the desert's straight edges, blurred by low sand mounds, and a few more cacti at its rim
local function desertEdge(ctx: Ctx)
	local D = Cfg.DesertEdge
	local ds = ctx.desert
	local random = ctx.random
	for k = 1, D.Mounds do
		local t = random:NextNumber(-0.5, 0.5)
		local side = k % 4
		local x, z
		if side == 0 then
			x, z = ds.x + t * ds.w, ds.z - ds.d / 2
		elseif side == 1 then
			x, z = ds.x + t * ds.w, ds.z + ds.d / 2
		elseif side == 2 then
			x, z = ds.x - ds.w / 2, ds.z + t * ds.d
		else
			x, z = ds.x + ds.w / 2, ds.z + t * ds.d
		end
		-- leave the road in clear
		local onRoad = false
		for _, c in ctx.connectors do
			if inside(c, x, z, 20) then
				onRoad = true
			end
		end
		if not onRoad then
			mound(
				nil,
				x,
				z,
				between(random, D.Radius),
				between(random, D.Height),
				Enum.Material.Sand
			)
		end
	end
	local green = Color3.fromRGB(70, 130, 70)
	for _ = 1, D.Cacti do
		local side = if random:NextNumber() < 0.5 then -1 else 1
		local at = Vector3.new(
			ds.x + side * (ds.w / 2 + random:NextNumber(-40, 60)),
			0,
			ds.z + random:NextNumber(-ds.d / 2, ds.d / 2)
		)
		local m = prop(ctx.props, "Cactus")
		post(m, 14, 2.4, at, green)
		post(m, 5, 1.6, at + Vector3.new(2.6, 6, 0), green)
		post(m, 4, 1.6, at + Vector3.new(-2.6, 4, 0), green)
	end
end

-- everything past the ring that isn't a zone; returns the rects groves and ponds must keep clear of
function CountryKit.build(ctx: Ctx): { Rect }
	edges(ctx)
	farm(ctx)
	moto(ctx)
	beaches(ctx)
	forest(ctx)
	desertEdge(ctx)
	local half = ctx.half
	-- (the hills round the edge are kept clear by ctx.allowed)
	return {
		Cfg.Farm.Rect,
		Cfg.Moto.Rect,
		Cfg.Forest.Rect,
		{ x = ctx.seaEdge + Cfg.Beach.Width / 2, z = 0, w = Cfg.Beach.Width + 40, d = half * 2 },
	}
end

-- a low grass hill on the open ground inside the walls
function CountryKit.hill(x: number, z: number, radius: number, height: number)
	mound(nil, x, z, radius, height, Enum.Material.Grass)
end

-- a strip of woods (the Belt mesh, `scale` of its full size) standing on flat ground at (x, z)
function CountryKit.wood(ctx: Ctx, x: number, z: number, scale: number)
	Greenery.mesh(
		ctx.static,
		"Belt",
		scale,
		CFrame.new(x, BELT_HEIGHT * scale / 2 - Cfg.Edge.BeltSink * scale, z)
			* CFrame.Angles(0, ctx.random:NextNumber(0, math.pi), 0),
		pick(ctx.random, Cfg.Edge.BeltColours)
	)
end

-- town fills -------------------------------------------------------------------------------------------------

-- parking bays painted in a lot (two rows back to back across the middle) and lamps at its corners
function CountryKit.lot(static: Instance, props: Instance, lotCentre: Vector3, inner: number)
	local L = Cfg.Lot
	local centre = lotCentre + Vector3.new(L.Shift, 0, 0) -- east, clear of the lot's west ramp
	local bw, bd = L.Bay[1], L.Bay[2]
	local rowLen = L.Bays * bw
	local draw = PaintKit.patch(static, centre + Vector3.new(0, 0.13, 0), rowLen + 2, bd * 2 + 14)
	for _, side in { -1, 1 } do
		for k = 0, L.Bays do
			draw(-rowLen / 2 + k * bw, side * (bd / 2 + 6), L.Line, bd, WHITE)
		end
	end
	draw(0, 0, rowLen, L.Line, WHITE)
	for k = 0, L.Lamps - 1 do
		local a = (k + 0.5) / L.Lamps * math.pi * 2
		local at = lotCentre + Vector3.new(math.cos(a), 0, math.sin(a)) * inner * 0.42
		local m = prop(props, "Lamp")
		post(m, 18, 0.8, at, STEEL)
		local head = part(
			m,
			Vector3.new(3, 0.8, 1.6),
			CFrame.new(at + Vector3.new(0, 18.2, 0)),
			Color3.fromRGB(255, 244, 214)
		)
		head.Material = Enum.Material.Neon
	end
end

-- market stalls round a plaza's edge, facing in; knockable
function CountryKit.plaza(props: Instance, centre: Vector3, inner: number, random: Random)
	local P = Cfg.Plaza
	local w, d, h = P.Stall[1], P.Stall[2], P.Stall[3]
	local a0 = random:NextNumber(0, math.pi * 2)
	for k = 0, P.Stalls - 1 do
		local a = a0 + k / P.Stalls * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local at = centre + dir * inner * 0.4
		local cf = CFrame.lookAt(at, centre)
		local m = prop(props, "Stall")
		local colour = pick(random, P.Awnings)
		part(
			m,
			Vector3.new(w, 3.5, d * 0.5),
			cf * CFrame.new(0, 1.75, 0),
			WOOD,
			Enum.Material.WoodPlanks
		)
		for _, e in { -1, 1 } do
			part(
				m,
				Vector3.new(0.5, h, 0.5),
				cf * CFrame.new(e * (w / 2 - 0.3), h / 2, d * 0.25),
				WOOD
			)
		end
		part(
			m,
			Vector3.new(w + 1, 0.5, d + 1),
			cf * CFrame.new(0, h, 0) * CFrame.Angles(0.18, 0, 0),
			colour,
			Enum.Material.Fabric
		)
	end
end

return CountryKit
