--!strict
-- The countryside's small greenery, laid last (Config/Foliage): clusters of grass tufts (some flowering),
-- bushes and rocks scattered over the rolled grass, thickest along the edges of what stays level (roadsides,
-- field and lot edges); bushes along the strips of woods; crop rows over the farm's fields. Each piece stands
-- on the terrain where a ray finds it (the terrain is baked into the place, so it is already there), and only on
-- grass: never on a path, sand, rock or a field (crop rows go on fields). Pieces come from their own random
-- streams, so nothing else in the map moves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Country = require(ReplicatedStorage.Shared.Config.Country)
local Foliage = require(ReplicatedStorage.Shared.Config.Foliage)
local LandCfg = require(ReplicatedStorage.Shared.Config.Land)
local Parks = require(ReplicatedStorage.Shared.Config.Parks)
local Ground = require(ReplicatedStorage.Shared.Rules.Ground)
local Greenery = require(script.Parent.Greenery)
local Pace = require(script.Parent.Pace)

local FoliageKit = {}

export type Field = {
	cx: number,
	cz: number,
	w: number,
	d: number,
	angle: number,
	wobble: number,
	crop: string,
}
export type Beach = { x0: number, zc: number, len: number, taken: { Vector3 }, seed: number }

local GRASS: { [Enum.Material]: boolean } = {
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function pick(random: Random, list: { { number } }): Color3
	return rgb(list[random:NextInteger(1, #list)])
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { workspace.Terrain }

-- the terrain's top at (x, z): its height and material (nil off the land)
local function surface(x: number, z: number): (number?, Enum.Material?, Vector3?)
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), rayParams)
	if not hit then
		return nil, nil, nil
	end
	return hit.Position.Y, hit.Material, hit.Normal
end

local function tuft(parent: Instance, at: Vector3, random: Random, colour: Color3, flowers: boolean)
	local S = Foliage.Scatter
	local h = random:NextNumber(S.TuftHeight[1], S.TuftHeight[2])
	local turn = random:NextNumber(0, math.pi * 2)
	local base = at - Vector3.new(0, S.TuftSink, 0)
	local t = Greenery.place(parent, "Tuft", base, nil, h, turn, colour)
	t.CastShadow = false
	if flowers then
		local f = Greenery.place(parent, "Petals", base, nil, h, turn, pick(random, Parks.Flowers))
		f.CastShadow = false
	end
end

local function rock(parent: Instance, at: Vector3, random: Random)
	local S = Foliage.Scatter
	local size = random:NextNumber(S.RockSize[1], S.RockSize[2])
	local r = Greenery.place(
		parent,
		Foliage.Rocks[random:NextInteger(1, #Foliage.Rocks)],
		at - Vector3.new(0, size * S.RockSink, 0),
		size,
		nil,
		random:NextNumber(0, math.pi * 2),
		pick(random, Foliage.RockGreys)
	)
	r.Material = Enum.Material.Slate
	r.CastShadow = size > S.RockShadowFrom
end

local function bush(parent: Instance, at: Vector3, random: Random, size: number)
	local b = Greenery.place(
		parent,
		Foliage.Bushes[random:NextInteger(1, #Foliage.Bushes)],
		at - Vector3.new(0, Foliage.Scatter.BushSink, 0),
		size,
		nil,
		random:NextNumber(0, math.pi * 2),
		pick(random, Foliage.TuftGreens):Lerp(Color3.new(0, 0, 0), Foliage.Scatter.BushDarken)
	)
	b.Material = Enum.Material.Grass
end

-- clusters over the open grass; returns how many pieces were placed
local function scatter(
	parent: Instance,
	level: { Ground.Rect },
	seaEdge: number,
	reach: number
): number
	local S = Foliage.Scatter
	local R = Country.Roll
	local index = Ground.index(level, R.Margin + R.Fade, R.Cell)
	local random = Random.new(S.Seed)
	local total = S.Kinds.tufts + S.Kinds.bush + S.Kinds.rocks
	local placed = 0
	local function put(x: number, z: number): Vector3?
		local y, mat = surface(x, z)
		if not y or not GRASS[mat :: Enum.Material] then
			return nil
		end
		return Vector3.new(x, y, z)
	end
	for cx = -reach, reach, S.Cell do
		Pace.step()
		for cz = -reach, reach, S.Cell do
			-- every cell draws the same numbers whatever happens, so the layout is the same every build
			local roll = random:NextNumber()
			local ox, oz = random:NextNumber(0, S.Cell), random:NextNumber(0, S.Cell)
			local kind = random:NextNumber(0, total)
			local seed = random:NextInteger(1, 2 ^ 30)
			local x, z = cx + ox, cz + oz
			-- verges start right at the level ground's edge; the open grass needs the roll to have begun
			local clear = Ground.clearance(index, x, z)
			local verge = clear > S.VergeFrom and clear < R.Margin + S.VergeBand
			if not verge and Ground.smooth((clear - R.Margin) / R.Fade) < S.MinWeight then
				continue
			end
			if clear <= S.VergeFrom or Ground.inland(LandCfg, seaEdge, x, z) < R.EdgeFade * 0.5 then
				continue
			end
			local chance = if verge then S.Verge else S.Base
			if roll >= chance then
				continue
			end
			local own = Random.new(seed)
			local function near(): (number, number)
				local a, d = own:NextNumber(0, math.pi * 2), own:NextNumber(0, S.Spread)
				return x + math.cos(a) * d, z + math.sin(a) * d
			end
			if kind < S.Kinds.tufts then
				local colour = pick(own, Foliage.TuftGreens)
				for _ = 1, own:NextInteger(S.Tufts[1], S.Tufts[2]) do
					local px, pz = near()
					local at = put(px, pz)
					if at then
						tuft(parent, at, own, colour, own:NextNumber() < S.FlowerShare)
						placed += 1
					end
				end
			elseif kind < S.Kinds.tufts + S.Kinds.bush then
				local at = put(x, z)
				if at then
					bush(parent, at, own, own:NextNumber(S.BushSize[1], S.BushSize[2]))
					placed += 1
					local colour = pick(own, Foliage.TuftGreens)
					for _ = 1, 2 do
						local px, pz = near()
						local t = put(px, pz)
						if t then
							tuft(parent, t, own, colour, false)
							placed += 1
						end
					end
				end
			else
				for _ = 1, own:NextInteger(S.Rocks[1], S.Rocks[2]) do
					local px, pz = near()
					local at = put(px, pz)
					if at then
						rock(parent, at, own)
						placed += 1
					end
				end
			end
		end
	end
	return placed
end

-- bushes along the front and back of each strip of woods on the land
local function woodEdges(parent: Instance, static: Instance, seaEdge: number): number
	local E = Foliage.WoodEdge
	local random = Random.new(Foliage.Scatter.Seed + 1)
	local placed = 0
	for _, belt in static:GetChildren() do
		if belt.Name ~= "Belt" or not belt:IsA("BasePart") then
			continue
		end
		local cf, size = belt.CFrame, belt.Size
		if Ground.inland(LandCfg, seaEdge, cf.Position.X, cf.Position.Z) < 0 then
			continue
		end
		for k = 1, E.per do
			local side = if k % 2 == 0 then 1 else -1
			local along = random:NextNumber(-E.spread, E.spread) * size.X
			local p = (cf * CFrame.new(along, 0, side * size.Z * E.out)).Position
			local y, mat = surface(p.X, p.Z)
			if y and GRASS[mat :: Enum.Material] then
				bush(
					parent,
					Vector3.new(p.X, y, p.Z),
					random,
					random:NextNumber(E.size[1], E.size[2])
				)
				placed += 1
			end
		end
		Pace.step()
	end
	return placed
end

-- crop rows in tiles over each field, turned with it and tilted to the ground under each tile's middle
local function crops(parent: Instance, fields: { Field }): number
	local T = Foliage.CropTile
	local F = Country.Farm
	local waves = { u = F.WobbleWaves.u, v = F.WobbleWaves.v, second = F.WobbleSecond }
	local placed = 0
	for _, f in fields do
		local spec = Foliage.Crops[f.crop]
		if not spec then
			continue
		end
		local colour = rgb(spec.colour)
		local c, s = math.cos(f.angle), math.sin(f.angle)
		local nu, nv = math.floor(f.w / T / 2), math.floor(f.d / T / 2)
		for i = -nu, nu do
			for j = -nv, nv do
				local u, v = i * T, j * T
				local x, z = f.cx + u * c - v * s, f.cz + u * s + v * c
				if
					not Ground.inField(f.cx, f.cz, f.w - T, f.d - T, f.angle, f.wobble, waves, x, z)
				then
					continue
				end
				local y, _, normal = surface(x, z)
				if not y or not normal then
					continue
				end
				local row =
					Greenery.place(parent, "CropRows", Vector3.new(x, y, z), T, nil, 0, colour)
				-- the rows run along the field's u (the mesh's rows run along its x), tilted to the ground under
				-- the tile and sunk into it; tiles butt edge to edge, each a hair higher or lower than the next so
				-- their ends never share a plane
				local along = Vector3.new(c, 0, s)
				local right = (along - normal * along:Dot(normal)).Unit
				local stagger = ((i + j) % 2) * Foliage.CropStagger
				row.Size = Vector3.new(T, spec.height, T)
				row.CFrame = CFrame.fromMatrix(
					Vector3.new(x, y - Foliage.CropSink + stagger, z) + normal * (spec.height / 2),
					right,
					normal
				)
				row.Material = Enum.Material.Grass
				row.CastShadow = false
				placed += 1
			end
			Pace.step()
		end
	end
	return placed
end

-- palms along a beach (from CountryKit: its water's-edge x, middle z, length, and what to keep clear of); each
-- palm is a Prop in `props` that any vehicle knocks flying (its trunk is what the car meets, its leaves a ghost)
local function palms(parent: Instance, props: Instance, beach: Beach): number
	local P = Foliage.Palms
	local B = Country.Beach
	local random = Random.new(beach.seed)
	local placed = 0
	for _ = 1, P.n do
		local x = beach.x0 + B.Width * random:NextNumber(P.from, P.to)
		local z = beach.zc + random:NextNumber(-beach.len / 2 + P.endGap, beach.len / 2 - P.endGap)
		local h = random:NextNumber(P.height[1], P.height[2])
		local turn = random:NextNumber(0, math.pi * 2)
		local leaves = rgb(P.leaves[random:NextInteger(1, #P.leaves)])
		local clear = true
		for _, p in beach.taken do
			if (Vector3.new(p.X, 0, p.Z) - Vector3.new(x, 0, z)).Magnitude < P.clear then
				clear = false
				break
			end
		end
		local y = if clear then surface(x, z) else nil
		if not y then
			continue
		end
		local base = Vector3.new(x, y - P.sink, z)
		local palm = Instance.new("Model")
		palm.Name = "Palm"
		palm:SetAttribute("Prop", "Palm")
		palm.Parent = props
		local trunk = Greenery.place(palm, "PalmTrunk", base, nil, h, turn, rgb(P.trunk))
		trunk.Material = Enum.Material.Wood
		trunk.CanCollide = true
		trunk.CanQuery = true
		trunk.CanTouch = true
		Greenery.place(palm, "PalmLeaves", base, nil, h, turn, leaves).Material =
			Enum.Material.Grass
		palm.WorldPivot = CFrame.new(base) -- at its foot, where the car meets it (the server's reach check)
		placed += 2
		Pace.step()
		for _ = 1, random:NextInteger(P.grass[1], P.grass[2]) do
			local a = random:NextNumber(0, math.pi * 2)
			local gx, gz =
				x + math.cos(a) * random:NextNumber(P.grassRing[1], P.grassRing[2]),
				z + math.sin(a) * random:NextNumber(P.grassRing[1], P.grassRing[2])
			local gy = surface(gx, gz)
			if gy then
				tuft(parent, Vector3.new(gx, gy, gz), random, rgb(Foliage.BeachGrass), false)
				placed += 1
			end
		end
	end
	return placed
end

-- everything above, after the map and its terrain are in place; returns the number of pieces
function FoliageKit.build(
	static: Instance,
	props: Instance,
	level: { Ground.Rect },
	seaEdge: number,
	reach: number,
	fields: { Field },
	beaches: { Beach }
): number
	task.wait() -- terrain written this frame isn't seen by rays until the next
	local folder = Instance.new("Folder")
	folder.Name = "Foliage"
	local n = scatter(folder, level, seaEdge, reach)
	n += woodEdges(folder, static, seaEdge)
	n += crops(folder, fields)
	for _, b in beaches do
		n += palms(folder, props, b)
	end
	folder.Parent = static
	return n
end

return FoliageKit
