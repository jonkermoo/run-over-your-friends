--!strict
-- The land's shape after everything else is placed (Rules/Ground, Config/Country Roll and Paths): the open
-- grass rolls in long smooth swells, worn dirt paths wander across it, and what stands on the grass is lifted
-- by as much as the ground under it rose. Also draws the farm's crop fields into the terrain, row by row, so
-- they follow the land. Terrain changes go through Terra (baked into the place).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Country = require(ReplicatedStorage.Shared.Config.Country)
local LandCfg = require(ReplicatedStorage.Shared.Config.Land)
local Ground = require(ReplicatedStorage.Shared.Rules.Ground)
local Pace = require(script.Parent.Pace)
local Terra = require(script.Parent.Terra)

local GroundKit = {}

type Rect = Ground.Rect

local TILE = 128
local GRASSY: { [Enum.Material]: boolean } = {
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
}

local function down(v: number): number
	return math.floor(v / 4) * 4
end
local function up(v: number): number
	return math.ceil(v / 4) * 4
end

-- the ground the roll may raise: grass, dirt and the farm's crops (so sand past the beaches rolls too; never rock
-- or the road's asphalt)
local function rollable(): { [Enum.Material]: boolean }
	local set: { [Enum.Material]: boolean } = {
		[Enum.Material.Grass] = true,
		[Enum.Material.LeafyGrass] = true,
		[Enum.Material.Ground] = true,
		[Enum.Material.Sand] = true,
	}
	for _, name in Country.Farm.CropMaterials do
		set[(Enum.Material :: any)[name]] = true
	end
	return set
end

local function rollNow(level: { Rect }, paths: { { { number } } }, seaEdge: number, reach: number)
	local R = Country.Roll
	local P = Country.Paths
	local terrain = workspace.Terrain
	local index = Ground.index(level, R.Margin + R.Fade, R.Cell)
	local pathIndex = Ground.segIndex(paths, P.width, R.Cell)
	local base = -LandCfg.GroundSink -- the flat ground's filled top
	local raisable = rollable()
	local DIRT = Enum.Material.Ground
	local AIR, WATER = Enum.Material.Air, Enum.Material.Water
	local y0, y1 = down(base - 8), up(base + Ground.maxRise(R) + 4)
	local halfDiag = TILE * 0.71
	local lo, hi = down(-reach), up(reach)
	for tx = lo, hi - 1, TILE do
		for tz = lo, hi - 1, TILE do
			Pace.step()
			local cx, cz = tx + TILE / 2, tz + TILE / 2
			-- whole tiles that are kept level, or out at sea / past the edge, are skipped
			if Ground.clearance(index, cx, cz) + halfDiag <= R.Margin then
				continue
			end
			if Ground.inland(LandCfg, seaEdge, cx, cz) < -halfDiag then
				continue
			end
			local region =
				Region3.new(Vector3.new(tx, y0, tz), Vector3.new(tx + TILE, y1, tz + TILE))
			local mats, occs = terrain:ReadVoxels(region, 4)
			local size = mats.Size
			local changed = false
			for i = 1, size.X do
				local x = tx + (i - 0.5) * 4
				local mi, oi = mats[i], occs[i]
				for k = 1, size.Z do
					local z = tz + (k - 0.5) * 4
					local lift = Ground.lift(R, index, LandCfg, seaEdge, x, z)
					local onPath = false
					if lift > 0 then
						local pd = Ground.pathDistance(pathIndex, x, z)
						onPath = pd < P.width / 2 and Ground.weight(R, index, x, z) >= P.minWeight
					end
					if lift < R.MinLift and not onPath then
						continue
					end
					-- the column's top: only grass-like ground rolls, and nothing with water in it
					local top = 0
					local wet = false
					for j = size.Y, 1, -1 do
						local m = mi[j][k]
						if m == WATER then
							wet = true
							break
						end
						if top == 0 and oi[j][k] > 0 then
							top = j
						end
					end
					if wet or top == 0 then
						continue
					end
					local surface = mi[top][k]
					if not raisable[surface] then
						continue
					end
					local fillWith = if onPath and GRASSY[surface] then DIRT else surface
					if lift >= R.MinLift then
						local want = base + lift
						for j = 1, size.Y do
							local bottom = y0 + (j - 1) * 4
							local occ = math.clamp((want - bottom) / 4, 0, 1)
							if occ > oi[j][k] then
								oi[j][k] = occ
								if mi[j][k] == AIR then
									mi[j][k] = fillWith
								end
								changed = true
							end
						end
					end
					if fillWith ~= surface then
						-- the path's dirt on the top two solid voxels
						local n = 0
						for j = size.Y, 1, -1 do
							if oi[j][k] > 0 then
								if GRASSY[mi[j][k]] then
									mi[j][k] = fillWith
									changed = true
								end
								n += 1
								if n >= 2 then
									break
								end
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

-- worn dirt paths: wandering lines over the open grass, kept where the roll reaches (Config/Country Paths)
function GroundKit.paths(
	level: { Rect },
	seaEdge: number,
	reach: number,
	random: Random
): { { { number } } }
	local R = Country.Roll
	local P = Country.Paths
	local index = Ground.index(level, R.Margin + R.Fade, R.Cell)
	local function ok(x: number, z: number): boolean
		return Ground.weight(R, index, x, z) >= P.minWeight
			and Ground.inland(LandCfg, seaEdge, x, z) > R.EdgeFade
	end
	local function rng(): number
		return random:NextNumber()
	end
	local out = {}
	local tries = 0
	while #out < P.n and tries < P.n * 30 do
		tries += 1
		local x, z = random:NextNumber(-reach, reach), random:NextNumber(-reach, reach)
		if not ok(x, z) then
			continue
		end
		local steps = random:NextInteger(P.steps[1], P.steps[2])
		local pts =
			Ground.wander(x, z, random:NextNumber(0, math.pi * 2), steps, P.step, P.turn, rng, ok)
		if #pts >= 4 then
			-- round the numbers so the terrain's fingerprint is the same on every machine
			for _, p in pts do
				p[1] = math.floor(p[1] * 4 + 0.5) / 4
				p[2] = math.floor(p[2] * 4 + 0.5) / 4
			end
			table.insert(out, pts)
		end
	end
	return out
end

-- roll the open grass and lay the paths (one terrain pass, after everything else)
function GroundKit.roll(level: { Rect }, paths: { { { number } } }, seaEdge: number, reach: number)
	local copy = {}
	for _, r in level do
		table.insert(copy, { x = r.x, z = r.z, w = r.w, d = r.d })
	end
	Terra.run("roll", rollNow, copy, paths, seaEdge, reach)
end

-- lift what stands on the rolled grass by as much as the ground under it rose (the least of its middle and
-- four corners, so long things sink in a little rather than float)
function GroundKit.lift(folders: { Instance }, level: { Rect }, seaEdge: number)
	local R = Country.Roll
	local index = Ground.index(level, R.Margin + R.Fade, R.Cell)
	local function liftAt(x: number, z: number): number
		return Ground.lift(R, index, LandCfg, seaEdge, x, z)
	end
	local moved = 0
	for _, folder in folders do
		for _, child in folder:GetChildren() do
			local cf: CFrame, size: Vector3
			if child:IsA("Model") then
				cf, size = child:GetBoundingBox()
			elseif child:IsA("BasePart") then
				cf, size = child.CFrame, child.Size
			else
				continue
			end
			local p = cf.Position
			-- big containers (a whole suburb, the road network) are never moved as one
			if size.X > R.Container or size.Z > R.Container then
				continue
			end
			if Ground.clearance(index, p.X, p.Z) <= R.Margin then
				continue
			end
			local least = liftAt(p.X, p.Z)
			if least < R.MinLift then
				continue
			end
			local ax, az = cf.RightVector * (size.X / 2), cf.LookVector * (size.Z / 2)
			for _, e in { ax + az, ax - az, -ax + az, -ax - az } do
				least = math.min(least, liftAt(p.X + e.X, p.Z + e.Z))
			end
			local bottom = p.Y - size.Y / 2
			local by = least - math.max(bottom, 0)
			if by < R.MinLift then
				continue
			end
			local shift = Vector3.new(0, by, 0)
			if child:IsA("Model") then
				child:PivotTo(child:GetPivot() + shift)
			else
				(child :: BasePart).CFrame += shift
			end
			moved += 1
		end
		Pace.step()
	end
	return moved
end

-- a crop field drawn into the terrain: one crop material over a patch turned `angle`, its outline wobbling; it
-- turns the grass already there (any height, so it follows the land) and nothing else
local function fieldNow(
	cx: number,
	cz: number,
	w: number,
	d: number,
	angle: number,
	wobble: number,
	waves: Ground.Waves,
	crop: string
)
	local terrain = workspace.Terrain
	local m = (Enum.Material :: any)[crop] :: Enum.Material
	local reachOut = (math.sqrt(w * w + d * d) / 2 + wobble * 1.5)
	local x0, x1 = down(cx - reachOut), up(cx + reachOut)
	local z0, z1 = down(cz - reachOut), up(cz + reachOut)
	local ylo, yhi = -12, up(Ground.maxRise(Country.Roll) + 8)
	for tx = x0, x1 - 1, TILE do
		for tz = z0, z1 - 1, TILE do
			Pace.step()
			local region = Region3.new(
				Vector3.new(tx, ylo, tz),
				Vector3.new(math.min(tx + TILE, x1), yhi, math.min(tz + TILE, z1))
			)
			local mats, occs = terrain:ReadVoxels(region, 4)
			local size = mats.Size
			local changed = false
			for i = 1, size.X do
				local x = tx + (i - 0.5) * 4
				for k = 1, size.Z do
					local z = tz + (k - 0.5) * 4
					if not Ground.inField(cx, cz, w, d, angle, wobble, waves, x, z) then
						continue
					end
					for j = 1, size.Y do
						if occs[i][j][k] > 0 and GRASSY[mats[i][j][k]] then
							mats[i][j][k] = m
							changed = true
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

function GroundKit.field(
	cx: number,
	cz: number,
	w: number,
	d: number,
	angle: number,
	wobble: number,
	crop: string
)
	local F = Country.Farm
	local waves = {
		u = { F.WobbleWaves.u[1], F.WobbleWaves.u[2] },
		v = { F.WobbleWaves.v[1], F.WobbleWaves.v[2] },
		second = F.WobbleSecond,
	}
	Terra.run("field", fieldNow, cx, cz, w, d, angle, wobble, waves, crop)
end

-- the terrain tints of the farm's crops (the soil is the island's dirt, already tinted)
function GroundKit.tint()
	local F = Country.Farm
	for name, c in F.TerrainCrops do
		workspace.Terrain:SetMaterialColor(
			(Enum.Material :: any)[name],
			Color3.fromRGB(c[1], c[2], c[3])
		)
	end
end

return GroundKit
