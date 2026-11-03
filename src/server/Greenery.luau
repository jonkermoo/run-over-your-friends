--!strict
-- Trees, bushes and flower beds from Config/Parks. Each is a Model with a "Prop" attribute, so put it in the
-- Props folder and any vehicle knocks it flying (BuildingService stands it back up later).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local P = require(ReplicatedStorage.Shared.Config.Parks)

local Greenery = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function prop(folder: Instance, kind: string): Model
	local m = Instance.new("Model")
	m.Name = kind
	m:SetAttribute("Prop", kind)
	m.Parent = folder
	return m
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

local function ball(parent: Instance, size: number, at: Vector3, color: Color3): Part
	local b = block(parent, Vector3.one * size, CFrame.new(at), color, Enum.Material.Grass)
	b.Shape = Enum.PartType.Ball
	return b
end

local function green(random: Random): Color3
	return rgb(P.Greens[random:NextInteger(1, #P.Greens)])
end

-- a leafy tree: a trunk and a crown of three lumps in two greens, turned a random way
function Greenery.tree(folder: Instance, at: Vector3, random: Random)
	local T = P.Tree
	local m = prop(folder, "Tree")
	local h = random:NextNumber(T.Trunk[1], T.Trunk[2])
	block(
		m,
		Vector3.new(T.TrunkWidth, h, T.TrunkWidth),
		CFrame.new(at + Vector3.new(0, h / 2, 0)),
		rgb(P.Trunk),
		Enum.Material.Wood
	)
	local r = random:NextNumber(T.Crown[1], T.Crown[2])
	local top = at + Vector3.new(0, h + r * 0.25, 0)
	local main, side = green(random), green(random)
	ball(m, r, top, main)
	local a = random:NextNumber(0, math.pi * 2)
	for k = 0, 1 do
		local dir = Vector3.new(math.cos(a + k * math.pi), 0, math.sin(a + k * math.pi))
		ball(m, r * T.Lumps, top + dir * r * 0.4 + Vector3.new(0, -r * (0.1 + k * 0.1), 0), side)
	end
	ball(
		m,
		r * T.Lumps * 0.8,
		top + Vector3.new(0, r * 0.38, 0),
		main:Lerp(Color3.new(1, 1, 1), 0.08)
	)
end

-- a low round bush of one or two balls
function Greenery.bush(folder: Instance, at: Vector3, random: Random)
	local m = prop(folder, "Bush")
	local r = random:NextNumber(P.Bush[1], P.Bush[2])
	local c = green(random)
	ball(m, r, at + Vector3.new(0, r * 0.4, 0), c)
	if random:NextNumber() < 0.6 then
		local a = random:NextNumber(0, math.pi * 2)
		ball(
			m,
			r * 0.7,
			at + Vector3.new(math.cos(a), 0, math.sin(a)) * r * 0.5 + Vector3.new(0, r * 0.3, 0),
			c:Lerp(Color3.new(0, 0, 0), 0.1)
		)
	end
end

-- a raised bed of soil edged in wood, with a row of flowers, long side along `along`
function Greenery.flowerBed(folder: Instance, at: Vector3, along: Vector3, random: Random)
	local F = P.FlowerBed
	local m = prop(folder, "FlowerBed")
	local cf = CFrame.lookAt(at, at + Vector3.new(-along.Z, 0, along.X))
	block(
		m,
		Vector3.new(F.width, 1, F.depth),
		cf + Vector3.new(0, 0.5, 0),
		rgb(P.Edging),
		Enum.Material.WoodPlanks
	)
	block(
		m,
		Vector3.new(F.width - 0.8, 0.3, F.depth - 0.8),
		cf + Vector3.new(0, 1.1, 0),
		rgb(P.Soil),
		Enum.Material.Ground
	)
	for k = 1, F.flowers do
		local x = -F.width / 2 + (k - 0.5) * F.width / F.flowers
		local z = random:NextNumber(-0.25, 0.25) * F.depth
		local stem = cf * CFrame.new(x, 1.8, z)
		block(m, Vector3.new(0.3, 1.2, 0.3), stem, rgb(P.Greens[1]))
		local head = block(
			m,
			Vector3.one * 1.1,
			stem * CFrame.new(0, 0.8, 0),
			rgb(P.Flowers[random:NextInteger(1, #P.Flowers)])
		)
		head.Shape = Enum.PartType.Ball
		head.CanCollide = false
	end
end

return Greenery
