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

function WildsKit.fill(ctx: CountryKit.Ctx, exclude: { Rules.Rect })
	local F = Country.Fill
	local random = ctx.random
	local half = ctx.half
	local function rng(): number
		return random:NextNumber()
	end
	local function spots(n: number, r: number): { { x: number, z: number } }
		local list = Rules.clearSpots(half, exclude, n, r, F.Margin, rng)
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
		workspace.Terrain:FillBall(
			Vector3.new(s.x, -K.radius * 0.35, s.z),
			K.radius * 0.7,
			Enum.Material.Grass
		)
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

	-- rolling hills in the gaps (terrain)
	local HL = F.Hills
	for _, s in spots(HL.n, HL.radius[2] * 0.6) do
		CountryKit.hill(s.x, s.z, between(random, HL.radius), between(random, HL.height))
	end
end

return WildsKit
