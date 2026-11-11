--!strict
-- A crown for an office tower's roof, so every tower has its own skyline (Config/Buildings Office.Crowns):
-- a setback penthouse, a spire, a roof garden, a stepped top, a helipad, a water tower, art-deco fins or a
-- copper dome. It stands on the back half of the roof, behind the billboard and clear of the name sign, and its
-- parts belong to the tower (they come down with it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local B = require(ReplicatedStorage.Shared.Config.Buildings)
local World = require(ReplicatedStorage.Shared.Config.World)

local TowerKit = {}

export type Colours = { wall: Color3, trim: Color3, accent: Color3, roof: Color3, glass: Color3 }

local FH = World.Map.FloorHeight
local CC = B.Office.CrownColours
local G = B.Office.RoofTrees

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- `centre` is the tower's footprint centre on the ground, `out` its front, `w`/`d` its size in x/z, `top`
-- the roof's height
function TowerKit.crown(
	model: Model,
	style: string,
	centre: Vector3,
	w: number,
	d: number,
	out: Vector3,
	top: number,
	c: Colours,
	random: Random
)
	local across = Vector3.new(-out.Z, 0, out.X)
	local W = math.abs(across:Dot(Vector3.new(w, 0, d)))
	local D = math.abs(out:Dot(Vector3.new(w, 0, d)))
	-- the back zone: from behind the billboard (16 back) to just inside the back parapet
	local depth = math.max(D / 2 - 19, 14)
	local width = W - 10
	local at = Vector3.new(centre.X, top, centre.Z) - out * (16 + depth / 2)
	local frame = CFrame.lookAt(at, at + out)
	local small = math.min(width, depth)

	local function part(
		size: Vector3,
		cf: CFrame,
		colour: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = colour
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end
	local function box(
		x: number,
		y: number,
		z: number,
		sx: number,
		sy: number,
		sz: number,
		colour: Color3,
		material: Enum.Material?
	): Part
		return part(Vector3.new(sx, sy, sz), frame * CFrame.new(x, y, z), colour, material)
	end
	-- an upright cylinder `h` tall, `dia` across, its foot at height y
	local function post(
		x: number,
		y: number,
		z: number,
		h: number,
		dia: number,
		colour: Color3,
		material: Enum.Material?
	): Part
		return part(
			Vector3.new(h, dia, dia),
			frame * CFrame.new(x, y + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
			colour,
			material,
			Enum.PartType.Cylinder
		)
	end
	local function ball(
		x: number,
		y: number,
		z: number,
		dia: number,
		colour: Color3,
		material: Enum.Material?
	): Part
		return part(
			Vector3.one * dia,
			frame * CFrame.new(x, y, z),
			colour,
			material,
			Enum.PartType.Ball
		)
	end
	local function glassBox(x: number, y: number, z: number, sx: number, sy: number, sz: number)
		local g = box(x, y, z, sx, sy, sz, c.glass, Enum.Material.Glass)
		g.Transparency = 0.2
		g.Reflectance = 0.1
	end

	if style == "penthouse" then
		-- a glass box set back from the edges, a flat roof with an overhang, a mast
		local pw, pd, ph = width * 0.7, depth * 0.85, FH * 1.4
		box(0, 0.75, 0, pw + 1, 1.5, pd + 1, c.wall)
		glassBox(0, 1.5 + (ph - 1.5) / 2, 0, pw, ph - 1.5, pd)
		box(0, ph + 0.5, 0, pw + 4, 1, pd + 4, c.trim)
		post(pw / 4, ph + 1, 0, 18, 0.8, c.trim, Enum.Material.Metal)
		ball(pw / 4, ph + 19.5, 0, 1.6, c.accent, Enum.Material.Neon)
	elseif style == "spire" then
		-- a stepped base, then a tapering needle with a glowing tip
		local tall = 40 + top * 0.35
		box(0, 4, 0, small * 0.6, 8, small * 0.6, c.trim)
		box(0, 11, 0, small * 0.4, 6, small * 0.4, c.wall)
		post(0, 14, 0, tall * 0.45, 6, c.trim, Enum.Material.Metal)
		post(0, 14 + tall * 0.45, 0, tall * 0.35, 3.4, c.trim, Enum.Material.Metal)
		post(0, 14 + tall * 0.8, 0, tall * 0.2, 1.4, c.trim, Enum.Material.Metal)
		ball(0, 14 + tall + 0.6, 0, 2.4, c.accent, Enum.Material.Neon)
	elseif style == "garden" then
		-- a lawn with planters and a few trees
		local grass = rgb(CC.grass)
		box(0, 0.4, 0, width, 0.8, depth, grass, Enum.Material.Grass)
		for _, e in { -1, 1 } do
			box(e * (width / 2 - 1.5), 1.5, 0, 3, 3, depth, c.trim, Enum.Material.Concrete)
		end
		local n = math.max(2, math.floor(width / 22))
		for k = 1, n do
			local x = -width / 2 + (k - 0.5) * width / n
			local z = random:NextNumber(-depth / 4, depth / 4)
			local h = random:NextNumber(G.trunk[1], G.trunk[2])
			box(x, 0.8 + h / 2, z, 1.2, h, 1.2, Color3.fromRGB(110, 78, 52), Enum.Material.Wood)
			ball(
				x,
				0.8 + h + 2,
				z,
				random:NextNumber(G.crown[1], G.crown[2]),
				grass:Lerp(Color3.new(0, 0, 0), random:NextNumber(0, G.shade)),
				Enum.Material.Grass
			)
		end
	elseif style == "pyramid" then
		-- an art-deco stepped top: shrinking tiers in wall and trim, a flagpole
		local s = small * 0.9
		local y = 0
		for k = 0, 3 do
			local size = s * (1 - k * 0.22)
			local h = 5 - k * 0.6
			box(0, y + h / 2, 0, size, h, size, if k % 2 == 0 then c.wall else c.trim)
			y += h
		end
		post(0, y, 0, 16, 0.6, c.trim, Enum.Material.Metal)
		box(1.8, y + 13.5, 0, 3.4, 2.2, 0.2, c.accent)
	elseif style == "helipad" then
		-- a dark pad on short legs, a white H, lights round the rim
		local dia = small * 0.95
		local pad = part(
			Vector3.new(1, dia, dia),
			frame * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.pi / 2),
			rgb(CC.pad),
			Enum.Material.Concrete,
			Enum.PartType.Cylinder
		)
		pad.Name = "Helipad"
		box(0, 1.25, 0, dia * 0.5, 2.5, dia * 0.5, c.wall)
		local white = Color3.fromRGB(245, 245, 240)
		local hs = dia * 0.4
		box(-hs / 3, 3.55, 0, hs * 0.12, 0.1, hs, white)
		box(hs / 3, 3.55, 0, hs * 0.12, 0.1, hs, white)
		box(0, 3.55, 0, hs * 0.6, 0.1, hs * 0.12, white)
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			ball(
				math.cos(a) * dia * 0.47,
				3.7,
				math.sin(a) * dia * 0.47,
				0.9,
				Color3.fromRGB(255, 200, 80),
				Enum.Material.Neon
			)
		end
	elseif style == "watertower" then
		-- a wooden water tank on a steel frame, with a cap
		local wood = rgb(CC.water)
		local legH, dia = 12, math.min(small * 0.5, 16)
		for _, xz in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			box(
				xz[1] * dia * 0.35,
				legH / 2,
				xz[2] * dia * 0.35,
				0.8,
				legH,
				0.8,
				Color3.fromRGB(60, 62, 66),
				Enum.Material.Metal
			)
		end
		box(
			0,
			legH,
			0,
			dia * 0.85,
			0.6,
			dia * 0.85,
			Color3.fromRGB(60, 62, 66),
			Enum.Material.Metal
		)
		post(0, legH + 0.3, 0, dia * 0.9, dia, wood, Enum.Material.WoodPlanks)
		for k = 1, 3 do
			post(
				0,
				legH + 0.3 + k * dia * 0.22,
				0,
				0.4,
				dia + 0.3,
				Color3.fromRGB(70, 70, 74),
				Enum.Material.Metal
			)
		end
		ball(0, legH + 0.3 + dia * 0.9, 0, dia * 1.02, c.roof) -- the lower half hides in the tank
	elseif style == "fins" then
		-- art-deco fins along the back edge, tallest in the middle, lit on top
		local n = 7
		for k = 0, n - 1 do
			local x = -width / 2 + (k + 0.5) * width / n
			local h = 12 + (1 - math.abs(k - (n - 1) / 2) / ((n - 1) / 2)) * 22
			box(x, h / 2, -depth / 2 + 2, 1.6, h, 4, c.trim)
			box(x, h + 0.3, -depth / 2 + 2, 1.7, 0.6, 4.1, c.accent, Enum.Material.Neon)
		end
	else
		-- a copper dome on a drum, a finial on top
		local dia = small * 0.75
		post(0, 0, 0, 6, dia, c.trim)
		post(0, 6, 0, 1, dia + 1.5, c.wall)
		ball(0, 7, 0, dia, rgb(CC.copper), Enum.Material.Metal)
		post(0, 7 + dia / 2 - 1, 0, 8, 0.8, c.trim, Enum.Material.Metal)
		ball(0, 7 + dia / 2 + 7.4, 0, 1.6, c.accent, Enum.Material.Neon)
	end
end

return TowerKit
