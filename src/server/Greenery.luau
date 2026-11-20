--!strict
-- Trees, bushes and flower beds from Config/Parks. Each is a Model with a "Prop" attribute, so put it in the
-- Props folder and any vehicle knocks it flying (BuildingService stands it back up later).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local P = require(ReplicatedStorage.Shared.Config.Parks)
local Foliage = require(ReplicatedStorage.Shared.Config.Foliage)

-- one-piece meshes (assets/Scenery.rbxm, tools/blender/export_scenery.py): a tree's crown and a bed's flowers
-- are one part each instead of four and fourteen
local MESHES = ReplicatedStorage:WaitForChild("SceneryModels")

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

local function green(random: Random): Color3
	return rgb(P.Greens[random:NextInteger(1, #P.Greens)])
end

-- a template mesh from assets/Scenery.rbxm, scaled by `scale`, centred at `cf`
function Greenery.mesh(
	parent: Instance,
	name: string,
	scale: number,
	cf: CFrame,
	color: Color3
): MeshPart
	local template = MESHES:FindFirstChild(name)
	assert(template and template:IsA("MeshPart"), `no scenery mesh "{name}" in assets/Scenery.rbxm`)
	local m = template:Clone()
	m.Size = m.Size * scale
	m.CFrame = cf
	m.Color = color
	m.Material = Enum.Material.Grass
	m.Parent = parent
	return m
end

-- a low-poly template from assets/Scenery.rbxm standing on `base`: scaled evenly so it is `width` across (or
-- `height` tall when width is nil), turned `turn` about the vertical; it never collides or blocks a ray
function Greenery.place(
	parent: Instance,
	name: string,
	base: Vector3,
	width: number?,
	height: number?,
	turn: number,
	color: Color3
): MeshPart
	local template = MESHES:FindFirstChild(name)
	assert(template and template:IsA("MeshPart"), `no scenery mesh "{name}" in assets/Scenery.rbxm`)
	local m = template:Clone()
	local k = if width
		then width / math.max(template.Size.X, template.Size.Z)
		else (height or 1) / template.Size.Y
	m.Size = template.Size * k
	m.CFrame = CFrame.new(base + Vector3.new(0, m.Size.Y / 2, 0)) * CFrame.Angles(0, turn, 0)
	m.Color = color
	m.Material = Enum.Material.SmoothPlastic
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.Parent = parent
	return m
end

-- a whole number from a spot, to pick a shape without drawing from the layout's random stream
local function spotPick(at: Vector3, n: number): number
	return (math.floor(at.X) * 7 + math.floor(at.Z) * 13) % n + 1
end

-- a leafy tree: a trunk and a chunky low-poly crown (one of three shapes, picked by its spot), turned a random way
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
	local turn = random:NextNumber(0, math.pi * 2)
	local name = Foliage.Crowns[spotPick(at, #Foliage.Crowns)]
	local template = MESHES:FindFirstChild(name)
	assert(template and template:IsA("MeshPart"), `no scenery mesh "{name}" in assets/Scenery.rbxm`)
	local height = template.Size.Y
		* r
		* Foliage.CrownWidth
		/ math.max(template.Size.X, template.Size.Z)
	local crown = Greenery.place(
		m,
		name,
		at + Vector3.new(0, h - height * Foliage.CrownSink, 0),
		r * Foliage.CrownWidth,
		nil,
		turn,
		green(random)
	)
	crown.Material = Enum.Material.Grass
	crown.CanCollide = true
	crown.CanQuery = true
	crown.CanTouch = true
end

-- take the random draws a tree takes, without planting it (so a skipped tree moves nothing after it)
function Greenery.skipTree(random: Random)
	local T = P.Tree
	random:NextNumber(T.Trunk[1], T.Trunk[2])
	random:NextNumber(T.Crown[1], T.Crown[2])
	random:NextNumber(0, math.pi * 2)
	random:NextInteger(1, #P.Greens)
end

-- a low chunky bush (one of two shapes, picked by its spot); the same random draws as the old two-ball bush,
-- so nothing after it moves
function Greenery.bush(folder: Instance, at: Vector3, random: Random)
	local m = prop(folder, "Bush")
	local r = random:NextNumber(P.Bush[1], P.Bush[2])
	local c = green(random)
	local turn = 0
	if random:NextNumber() < 0.6 then
		turn = random:NextNumber(0, math.pi * 2)
	end
	local b = Greenery.place(
		m,
		Foliage.Bushes[spotPick(at, #Foliage.Bushes)],
		at,
		r * Foliage.BushWidth,
		nil,
		turn,
		c
	)
	b.Material = Enum.Material.Grass
	b.CanCollide = true
	b.CanQuery = true
	b.CanTouch = true
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
	Greenery.mesh(
		m,
		"Blooms",
		1,
		cf + Vector3.new(0, 1.25 + F.bloomHeight / 2, 0), -- 1.25: the soil's top (1.1 up, 0.3 thick)
		rgb(P.Flowers[random:NextInteger(1, #P.Flowers)])
	).Material =
		Enum.Material.SmoothPlastic
end

return Greenery
