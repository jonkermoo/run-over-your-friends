--!strict
-- The last pass over the open grass inside the walls (Config/Country Fill): rocky knolls, pine stands, strips
-- of woods, hedgerows, wildflower patches with bushes, then rolling hills in what's left. Rocks and hills are
-- terrain (no parts); pines and woods are one mesh each. Every piece keeps clear of the city, the ring, the
-- zones and everything placed before it (Rules/Outskirts clearSpots).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Country = require(ReplicatedStorage.Shared.Config.Country)
local Parks = require(ReplicatedStorage.Shared.Config.Parks)
local Rules = require(ReplicatedStorage.Shared.Rules.Outskirts)
local CountryKit = require(script.Parent.CountryKit)
local Greenery = require(script.Parent.Greenery)

local WildsKit = {}

local function between(random: Random, range: { number }): number
	return random:NextNumber(range[1], range[2])
end

local function count(random: Random, range: { number }): number
	return random:NextInteger(range[1], range[2])
end

-- the lakes (Config/Country Lakes): a wobbly bowl of terrain water with a sandy shore, trees round it; each
-- joins `exclude`
function WildsKit.lakes(ctx: CountryKit.Ctx, exclude: { Rules.Rect })
	local terrain = workspace.Terrain
	local random = ctx.random
	for _, L in Country.Lakes do
		local p1, p2 = random:NextNumber(0, math.pi * 2), random:NextNumber(0, math.pi * 2)
		local function edgeAt(a: number): number
			return L.r * (1 + 0.18 * math.sin(2 * a + p1) + 0.1 * math.sin(5 * a + p2))
		end
		local reach = L.r * (1.28 + Country.LakeBeach)
		local x0, z0 = math.floor((L.x - reach) / 4) * 4, math.floor((L.z - reach) / 4) * 4
		local span = math.ceil(reach * 2 / 4) * 4
		local y0 = -4 * math.ceil((Country.LakeDepth + 8) / 4)
		local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + span, 4, z0 + span))
		local mats, occs = terrain:ReadVoxels(region, 4)
		local size = mats.Size
		for i = 1, size.X do
			local dx = x0 + (i - 0.5) * 4 - L.x
			for k = 1, size.Z do
				local dz = z0 + (k - 0.5) * 4 - L.z
				local d = math.sqrt(dx * dx + dz * dz)
				local e = edgeAt(math.atan2(dz, dx))
				local f = d / e
				if f < 1 + Country.LakeBeach then
					local bed = if f < 1
						then -Country.LakeDepth * (1 + math.cos(math.pi * f)) / 2 - 0.5
						else 0
					for j = 1, size.Y do
						local bottom = y0 + (j - 1) * 4
						if bottom >= 0 then
							continue
						end
						if f >= 1 then
							-- the dry shore: sand where the ground is
							if occs[i][j][k] > 0 then
								mats[i][j][k] = Enum.Material.Sand
							end
						elseif bottom >= -4 or bottom >= bed then
							-- the top layer is always water inside the edge, and so is everything above the bed
							mats[i][j][k], occs[i][j][k] = Enum.Material.Water, 1
						else
							-- the bed: solid up to `bed`; a voxel it barely reaches stays water (they can't share)
							local occ = math.clamp((bed - bottom) / 4, 0, 1)
							if occ < 0.5 then
								mats[i][j][k], occs[i][j][k] = Enum.Material.Water, 1
							else
								mats[i][j][k], occs[i][j][k] = Enum.Material.Sand, occ
							end
						end
					end
				end
			end
		end
		-- a voxel keeps its solid part when water is written into it (shorelines), so the water's voxels are
		-- cleared to air first, then filled (measured in Studio)
		local wet: { Vector3 } = {}
		for i = 1, size.X do
			for j = 1, size.Y do
				for k = 1, size.Z do
					if mats[i][j][k] == Enum.Material.Water then
						table.insert(wet, Vector3.new(i, j, k))
						mats[i][j][k], occs[i][j][k] = Enum.Material.Air, 0
					end
				end
			end
		end
		terrain:WriteVoxels(region, 4, mats, occs)
		for _, v in wet do
			mats[v.X][v.Y][v.Z], occs[v.X][v.Y][v.Z] = Enum.Material.Water, 1
		end
		terrain:WriteVoxels(region, 4, mats, occs)
		for _ = 1, Country.LakeTrees do
			local a = random:NextNumber(0, math.pi * 2)
			local d = edgeAt(a) * (1 + Country.LakeBeach) + random:NextNumber(8, 40)
			Greenery.tree(
				ctx.props,
				Vector3.new(L.x + math.cos(a) * d, 0, L.z + math.sin(a) * d),
				random
			)
		end
		table.insert(exclude, { x = L.x, z = L.z, w = reach * 2 + 40, d = reach * 2 + 40 })
	end
end

function WildsKit.fill(ctx: CountryKit.Ctx, exclude: { Rules.Rect })
	local F = Country.Fill
	local random = ctx.random
	local half = ctx.reach
	local function rng(): number
		return random:NextNumber()
	end
	local function spots(n: number, r: number): { { x: number, z: number } }
		local list = Rules.clearSpots(half, exclude, n, r, F.Margin, rng, ctx.allowed)
		for _, s in list do
			table.insert(exclude, { x = s.x, z = s.z, w = r * 2, d = r * 2 })
		end
		return list
	end
	local function around(s: { x: number, z: number }, r: number): Vector3
		local a, d = random:NextNumber(0, math.pi * 2), math.sqrt(random:NextNumber()) * r
		return Vector3.new(s.x + math.cos(a) * d, 0, s.z + math.sin(a) * d)
	end

	-- rocky knolls: a few rock balls half sunk in the grass, a grassy skirt round them
	local K = F.Knolls
	for _, s in spots(K.n, K.radius) do
		CountryKit.bell(s.x, s.z, K.radius * 1.2, K.radius * 0.3, Enum.Material.Grass)
		for _ = 1, count(random, K.rocks) do
			local size = between(random, K.size)
			local at = around(s, K.radius * 0.5)
			local material = if random:NextNumber() < 0.7
				then Enum.Material.Rock
				else Enum.Material.Slate
			workspace.Terrain:FillBall(at - Vector3.new(0, size * 0.25, 0), size / 2, material)
		end
	end

	-- pine stands
	local P = F.Pines
	for _, s in spots(P.n, P.radius) do
		for _ = 1, count(random, P.trees) do
			CountryKit.pine(
				ctx.static,
				around(s, P.radius),
				between(random, Country.Forest.PineHeight),
				random
			)
		end
	end

	-- strips of woods
	local W = F.Woods
	local woodRadius = CountryKit.beltLength * W.scale[2] / 2
	for _, s in spots(W.n, woodRadius) do
		CountryKit.wood(ctx, s.x, s.z, between(random, W.scale))
	end

	-- hedgerows: a straight row of leafy trees along x or z
	local H = F.Hedges
	local longest = (H.trees[2] - 1) * H.gap
	for _, s in spots(H.n, longest / 2 + 6) do
		local n = count(random, H.trees)
		local dir = if random:NextNumber() < 0.5 then Vector3.xAxis else Vector3.zAxis
		for k = 0, n - 1 do
			local t = (k - (n - 1) / 2) * H.gap + random:NextNumber(-2, 2)
			Greenery.tree(ctx.props, Vector3.new(s.x, 0, s.z) + dir * t, random)
		end
	end

	-- wildflower patches: low drifts of blooms (one mesh each) and a couple of bushes
	local FL = F.Flowers
	for _, s in spots(FL.n, FL.radius) do
		local colour = Parks.Flowers[random:NextInteger(1, #Parks.Flowers)]
		for _ = 1, count(random, FL.beds) do
			local scale = between(random, FL.scale)
			local at = around(s, FL.radius - 6)
			-- mostly one colour per patch, a few strays
			local c = if random:NextNumber() < 0.75
				then colour
				else Parks.Flowers[random:NextInteger(1, #Parks.Flowers)]
			local bloom = Greenery.mesh(
				ctx.static,
				"Blooms",
				scale,
				CFrame.new(at + Vector3.new(0, Parks.FlowerBed.bloomHeight * scale / 2 - 0.3, 0))
					* CFrame.Angles(0, random:NextNumber(0, math.pi), 0),
				Color3.fromRGB(c[1], c[2], c[3])
			)
			bloom.Material = Enum.Material.SmoothPlastic
			bloom.CanCollide = false
			bloom.CanQuery = false
		end
		for _ = 1, FL.bushes do
			Greenery.bush(ctx.props, around(s, FL.radius), random)
		end
	end

	-- patches of darker grass: a wobbly blob each, its grass voxels turned leafy (not kept clear of anything:
	-- it is only colour)
	local PA = F.Patches
	local terrain = workspace.Terrain
	for _, s in Rules.clearSpots(half, {}, PA.n, PA.radius, 0, rng, ctx.allowed) do
		local r = between(random, PA.size)
		local p1, p2 = random:NextNumber(0, math.pi * 2), random:NextNumber(0, math.pi * 2)
		local x0, z0 = math.floor((s.x - r * 1.4) / 4) * 4, math.floor((s.z - r * 1.4) / 4) * 4
		local span = math.ceil(r * 2.8 / 4) * 4
		local region = Region3.new(Vector3.new(x0, -8, z0), Vector3.new(x0 + span, 4, z0 + span))
		local mats, occs = terrain:ReadVoxels(region, 4)
		local size = mats.Size
		for i = 1, size.X do
			local dx = x0 + (i - 0.5) * 4 - s.x
			for k = 1, size.Z do
				local dz = z0 + (k - 0.5) * 4 - s.z
				local a = math.atan2(dz, dx)
				local edge = r * (1 + 0.25 * math.sin(3 * a + p1) + 0.15 * math.sin(5 * a + p2))
				if dx * dx + dz * dz < edge * edge then
					for j = 1, size.Y do
						if mats[i][j][k] == Enum.Material.Grass then
							mats[i][j][k] = Enum.Material.LeafyGrass
						end
					end
				end
			end
		end
		terrain:WriteVoxels(region, 4, mats, occs)
	end

	-- rolling hills in the gaps (terrain)
	local HL = F.Hills
	for _, s in spots(HL.n, HL.radius[2] * 0.6) do
		CountryKit.hill(s.x, s.z, between(random, HL.radius), between(random, HL.height))
	end
end

return WildsKit
