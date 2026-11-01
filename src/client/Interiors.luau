--!strict
-- Interiors, drawn on this screen only: furniture and lamps in the houses nearest the camera (layouts in
-- Config/Interiors) and in the nearest town buildings (offices, shops, the burger place, the warehouse;
-- layouts in Rules/Interiors, worked out from each building's size). Both match where the server puts
-- people. Nothing here collides or is hit-tested, and a building being smashed loses its furniture until
-- it's rebuilt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buildings = require(ReplicatedStorage.Shared.Config.Buildings)
local Config = require(ReplicatedStorage.Shared.Config.Interiors)
local Layouts = require(ReplicatedStorage.Shared.Rules.Interiors)
local World = require(ReplicatedStorage.Shared.Config.World)

local Interiors = {}

local Y0 = 0.08
local TOWN = Config.Town
local LAYOUT_CONFIG: Layouts.Config = {
	FloorHeight = World.Map.FloorHeight,
	Floors = TOWN.OfficeFloors,
	DeskEvery = TOWN.DeskEvery,
	Tables = Buildings.Restaurant.Tables,
	TableZ = Buildings.Restaurant.TableZ,
}
local WOOD = Color3.fromRGB(140, 98, 62)
local DARK_WOOD = Color3.fromRGB(96, 66, 44)
local WHITE = Color3.fromRGB(236, 234, 228)
local STEEL = Color3.fromRGB(190, 194, 200)
local DARK = Color3.fromRGB(40, 42, 48)
local STONE = Color3.fromRGB(222, 218, 210)
local SCREEN = Color3.fromRGB(70, 130, 190)
local WARM = Color3.fromRGB(255, 214, 150)
local COOL = Color3.fromRGB(240, 244, 255)
local FABRICS = {
	Color3.fromRGB(70, 96, 140),
	Color3.fromRGB(150, 70, 60),
	Color3.fromRGB(90, 120, 80),
	Color3.fromRGB(120, 110, 100),
	Color3.fromRGB(180, 140, 70),
	Color3.fromRGB(110, 80, 130),
}
local RUGS = {
	Color3.fromRGB(190, 160, 120),
	Color3.fromRGB(150, 60, 60),
	Color3.fromRGB(70, 90, 120),
	Color3.fromRGB(200, 190, 170),
}
local BOOKS =
	{ Color3.fromRGB(180, 50, 50), Color3.fromRGB(50, 90, 160), Color3.fromRGB(220, 180, 60) }

-- how one building is dressed: its fabric and rug, its goods (shops), its accent, and the piece's width
type Look = {
	fabric: Color3,
	rug: Color3,
	goods: { Color3 },
	accent: Color3,
	w: number,
	d: number,
	m: number, -- -1 when the building is mirrored
}
type Build = (folder: Folder, at: CFrame, look: Look) -> ()

local function block(
	folder: Folder,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = folder
	return p
end

-- a cylinder `len` long along the frame's x axis (wheels)
local function cyl(folder: Folder, len: number, dia: number, cf: CFrame, color: Color3): Part
	local p = block(folder, Vector3.new(len, dia, dia), cf, color)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- a flat round disc `h` thick (table tops, lamp shades, hat brims)
local function round(folder: Folder, dia: number, h: number, cf: CFrame, color: Color3): Part
	return cyl(folder, h, dia, cf * CFrame.Angles(0, 0, math.pi / 2), color)
end

local function light(part: BasePart, range: number?, brightness: number?, color: Color3?)
	local l = Instance.new("PointLight")
	l.Range = range or Config.LampRange
	l.Brightness = brightness or Config.LampBrightness
	l.Color = color or WARM
	l.Shadows = false
	l.Parent = part
end

local function glassBox(f: Folder, size: Vector3, cf: CFrame, color: Color3?): Part
	local g = block(f, size, cf, color or Color3.fromRGB(190, 220, 235), Enum.Material.Glass)
	g.Transparency = 0.6
	return g
end

local function goods(look: Look, k: number): Color3
	return look.goods[(k - 1) % #look.goods + 1]
end

-- each piece is built in its own frame: origin on the floor, front facing -Z (the piece's LookVector)
local PIECES: { [string]: Build } = {
	-- houses (and lobbies)
	Sofa = function(f, at, look)
		block(
			f,
			Vector3.new(7, 1.4, 3),
			at * CFrame.new(0, 1.1, 0),
			look.fabric,
			Enum.Material.Fabric
		)
		block(
			f,
			Vector3.new(7, 2.2, 0.9),
			at * CFrame.new(0, 2.2, 1.1),
			look.fabric,
			Enum.Material.Fabric
		)
		for _, e in { -1, 1 } do
			block(
				f,
				Vector3.new(0.8, 2, 3),
				at * CFrame.new(e * 3.5, 1.5, 0),
				look.fabric:Lerp(Color3.new(0, 0, 0), 0.15),
				Enum.Material.Fabric
			)
		end
	end,
	CoffeeTable = function(f, at)
		block(f, Vector3.new(3.6, 0.3, 2.2), at * CFrame.new(0, 1.5, 0), WOOD, Enum.Material.Wood)
		block(
			f,
			Vector3.new(3, 1.3, 1.6),
			at * CFrame.new(0, 0.7, 0),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end,
	TV = function(f, at)
		block(
			f,
			Vector3.new(5, 1.8, 1.4),
			at * CFrame.new(0, 0.9, 0),
			DARK_WOOD,
			Enum.Material.Wood
		)
		block(f, Vector3.new(5.4, 3, 0.3), at * CFrame.new(0, 3.5, 0.2), Color3.fromRGB(20, 22, 26))
		local screen = block(
			f,
			Vector3.new(5, 2.6, 0.1),
			at * CFrame.new(0, 3.5, 0.02),
			SCREEN,
			Enum.Material.Neon
		)
		screen.Transparency = 0.2
	end,
	Rug = function(f, at, look)
		block(
			f,
			Vector3.new(8, 0.08, 6),
			at * CFrame.new(0, 0.34, 0),
			look.rug,
			Enum.Material.Fabric
		)
	end,
	FloorLamp = function(f, at)
		block(f, Vector3.new(1.2, 0.3, 1.2), at * CFrame.new(0, 0.45, 0), DARK_WOOD)
		block(f, Vector3.new(0.3, 5.4, 0.3), at * CFrame.new(0, 3.2, 0), DARK_WOOD)
		local shade = block(
			f,
			Vector3.new(1.6, 1.3, 1.6),
			at * CFrame.new(0, 6.3, 0),
			WARM,
			Enum.Material.Neon
		)
		light(shade)
	end,
	CeilingLamp = function(f, at)
		block(f, Vector3.new(0.15, 1.6, 0.15), at * CFrame.new(0, 10.9, 0), DARK_WOOD)
		local shade = block(
			f,
			Vector3.new(1.8, 0.8, 1.8),
			at * CFrame.new(0, 9.8, 0),
			WARM,
			Enum.Material.Neon
		)
		light(shade)
	end,
	Bookshelf = function(f, at)
		block(f, Vector3.new(4.4, 6.4, 1.2), at * CFrame.new(0, 3.5, 0), WOOD, Enum.Material.Wood)
		for k, c in BOOKS do
			block(f, Vector3.new(3.8, 1.2, 0.9), at * CFrame.new(0, 0.9 + k * 1.7, -0.2), c)
		end
	end,
	Plant = function(f, at)
		block(
			f,
			Vector3.new(1.4, 1.4, 1.4),
			at * CFrame.new(0, 1, 0),
			Color3.fromRGB(170, 96, 64),
			Enum.Material.Slate
		)
		local leaves = block(
			f,
			Vector3.new(2.6, 2.6, 2.6),
			at * CFrame.new(0, 2.9, 0),
			Color3.fromRGB(70, 140, 70),
			Enum.Material.Grass
		)
		leaves.Shape = Enum.PartType.Ball
	end,
	Counter = function(f, at)
		block(f, Vector3.new(8, 3.4, 2.2), at * CFrame.new(0, 1.95, 0), WHITE)
		block(
			f,
			Vector3.new(8.2, 0.3, 2.4),
			at * CFrame.new(0, 3.8, 0),
			Color3.fromRGB(90, 90, 96),
			Enum.Material.Marble
		)
		block(
			f,
			Vector3.new(1.8, 0.1, 1.2),
			at * CFrame.new(1.5, 3.96, 0),
			STEEL,
			Enum.Material.Metal
		)
	end,
	Fridge = function(f, at)
		block(f, Vector3.new(3, 6.6, 2.4), at * CFrame.new(0, 3.6, 0), STEEL, Enum.Material.Metal)
		block(
			f,
			Vector3.new(0.2, 1.6, 0.2),
			at * CFrame.new(1, 4.6, -1.3),
			Color3.fromRGB(60, 60, 64)
		)
	end,
	DiningTable = function(f, at)
		block(f, Vector3.new(5, 0.4, 3.4), at * CFrame.new(0, 3.1, 0), WOOD, Enum.Material.Wood)
		block(f, Vector3.new(1, 2.8, 1), at * CFrame.new(0, 1.6, 0), DARK_WOOD, Enum.Material.Wood)
	end,
	Chair = function(f, at)
		block(f, Vector3.new(1.9, 0.3, 1.9), at * CFrame.new(0, 1.85, 0), WOOD, Enum.Material.Wood)
		block(f, Vector3.new(1.9, 2.2, 0.3), at * CFrame.new(0, 3.1, 0.8), WOOD, Enum.Material.Wood)
		block(
			f,
			Vector3.new(1.2, 1.6, 1.2),
			at * CFrame.new(0, 0.95, 0),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end,

	-- offices
	Reception = function(f, at, look)
		block(f, Vector3.new(12, 3.6, 2.6), at * CFrame.new(0, 1.8, 0), WHITE)
		block(f, Vector3.new(12.2, 0.8, 0.4), at * CFrame.new(0, 2.6, -1.4), look.accent)
		block(
			f,
			Vector3.new(12.6, 0.3, 3.2),
			at * CFrame.new(0, 3.75, 0),
			STONE,
			Enum.Material.Marble
		)
		block(f, Vector3.new(2.2, 1.5, 0.2), at * CFrame.new(-2.5, 4.7, 0.2), DARK)
		block(
			f,
			Vector3.new(2, 1.3, 0.05),
			at * CFrame.new(-2.5, 4.7, 0.33),
			SCREEN,
			Enum.Material.Neon
		)
	end,
	WaterCooler = function(f, at)
		block(f, Vector3.new(1.4, 3.4, 1.4), at * CFrame.new(0, 1.7, 0), WHITE)
		local bottle = block(
			f,
			Vector3.new(1.3, 1.3, 1.3),
			at * CFrame.new(0, 4.1, 0),
			Color3.fromRGB(120, 180, 240),
			Enum.Material.Glass
		)
		bottle.Shape = Enum.PartType.Ball
		bottle.Transparency = 0.3
	end,
	LiftCore = function(f, at)
		local h = World.Map.FloorHeight - 0.4
		block(
			f,
			Vector3.new(24, h, 10),
			at * CFrame.new(0, h / 2, 0),
			STONE,
			Enum.Material.Limestone
		)
		for _, e in { -1, 1 } do
			block(
				f,
				Vector3.new(5.4, 9, 0.3),
				at * CFrame.new(e * 5, 4.5, -5.05),
				DARK,
				Enum.Material.Metal
			)
			block(
				f,
				Vector3.new(4.6, 8.4, 0.2),
				at * CFrame.new(e * 5, 4.2, -5.15),
				STEEL,
				Enum.Material.Metal
			)
			block(
				f,
				Vector3.new(1.2, 0.4, 0.1),
				at * CFrame.new(e * 5, 9.5, -5.22),
				WARM,
				Enum.Material.Neon
			)
		end
	end,
	CoffeeBar = function(f, at, look)
		block(
			f,
			Vector3.new(10, 3.6, 2.4),
			at * CFrame.new(0, 1.8, 0),
			DARK_WOOD,
			Enum.Material.Wood
		)
		block(
			f,
			Vector3.new(10.2, 0.3, 2.6),
			at * CFrame.new(0, 3.75, 0),
			STONE,
			Enum.Material.Marble
		)
		block(f, Vector3.new(2, 2, 1.6), at * CFrame.new(2, 4.9, 0.2), STEEL, Enum.Material.Metal)
		block(
			f,
			Vector3.new(0.6, 0.3, 0.1),
			at * CFrame.new(2, 5.4, -0.62),
			look.accent,
			Enum.Material.Neon
		)
		for k = 0, 2 do
			block(f, Vector3.new(0.5, 0.6, 0.5), at * CFrame.new(-3 + k * 0.9, 4.2, -0.4), WHITE)
		end
	end,
	CafeTable = function(f, at)
		round(f, 3, 0.25, at * CFrame.new(0, 3, 0), WHITE)
		block(f, Vector3.new(0.4, 2.9, 0.4), at * CFrame.new(0, 1.5, 0), DARK)
	end,
	PanelLight = function(f, at)
		local panel =
			block(f, Vector3.new(4, 0.2, 4), at * CFrame.new(0, -0.1, 0), COOL, Enum.Material.Neon)
		light(panel, TOWN.LightRange, TOWN.LightBrightness, COOL)
	end,
	PanelGlow = function(f, at)
		block(f, Vector3.new(5, 0.2, 2), at * CFrame.new(0, -0.1, 0), COOL, Enum.Material.Neon)
	end,
	Desk = function(f, at)
		block(f, Vector3.new(6, 0.3, 2.6), at * CFrame.new(0, 2.95, 0), WHITE)
		for _, e in { -1, 1 } do
			block(f, Vector3.new(0.3, 2.8, 2.4), at * CFrame.new(e * 2.8, 1.4, 0), DARK)
		end
		block(f, Vector3.new(2.6, 1.7, 0.2), at * CFrame.new(0, 4.1, -0.6), DARK)
		block(
			f,
			Vector3.new(2.4, 1.5, 0.05),
			at * CFrame.new(0, 4.1, -0.48),
			SCREEN,
			Enum.Material.Neon
		)
		block(f, Vector3.new(2, 0.1, 0.7), at * CFrame.new(0, 3.15, 0.5), DARK)
	end,

	-- shops
	Floor = function(f, at, look)
		block(
			f,
			Vector3.new(look.w, 0.1, look.d),
			at * CFrame.new(0, 0.05, 0),
			Color3.fromRGB(176, 132, 90),
			Enum.Material.WoodPlanks
		)
	end,
	Partition = function(f, at, look)
		block(f, Vector3.new(look.w, 13.4, 0.6), at * CFrame.new(0, 6.7, 0), STONE)
		block(
			f,
			Vector3.new(4.4, 8.4, 0.2),
			at * CFrame.new(-look.w / 2 + 5, 4.2, -0.35),
			look.accent
		)
	end,
	Shelf = function(f, at, look)
		block(f, Vector3.new(8, 7, 0.4), at * CFrame.new(0, 3.5, 0.6), WHITE)
		for k = 0, 2 do
			local y = 0.9 + k * 2.2
			block(f, Vector3.new(8, 0.25, 1.6), at * CFrame.new(0, y, 0), WOOD, Enum.Material.Wood)
			for s = 0, 1 do
				block(
					f,
					Vector3.new(3.6, 1.4, 1.2),
					at * CFrame.new(-1.9 + s * 3.8, y + 0.82, 0),
					goods(look, k + s + 1)
				)
			end
		end
	end,
	ShopCounter = function(f, at, look)
		block(f, Vector3.new(look.w, 3.6, 2.4), at * CFrame.new(0, 1.8, 0), look.accent)
		block(
			f,
			Vector3.new(look.w + 0.2, 0.3, 2.6),
			at * CFrame.new(0, 3.75, 0),
			WOOD,
			Enum.Material.Wood
		)
		-- the till at the door end
		local till = at * CFrame.new(look.m * (look.w / 2 - 2), 3.9, 0)
		block(f, Vector3.new(1.6, 0.6, 1.4), till * CFrame.new(0, 0.3, 0), DARK)
		block(
			f,
			Vector3.new(1.2, 0.9, 0.1),
			till * CFrame.new(0, 1.1, 0.3) * CFrame.Angles(math.rad(-20), math.pi, 0),
			SCREEN,
			Enum.Material.Neon
		)
	end,
	Table = function(f, at, look)
		block(f, Vector3.new(6, 0.4, 3), at * CFrame.new(0, 3, 0), WOOD, Enum.Material.Wood)
		block(f, Vector3.new(5, 2.8, 2), at * CFrame.new(0, 1.4, 0), DARK_WOOD, Enum.Material.Wood)
		for k = 0, 2 do
			block(
				f,
				Vector3.new(1.4, 1 + k * 0.3, 1.4),
				at * CFrame.new(-1.9 + k * 1.9, 3.7 + k * 0.15, 0),
				goods(look, k + 1)
			)
		end
	end,
	Case = function(f, at, look)
		block(f, Vector3.new(6, 2.6, 3), at * CFrame.new(0, 1.3, 0), WHITE)
		glassBox(f, Vector3.new(6, 1.8, 3), at * CFrame.new(0, 3.5, 0))
		for k = 0, 2 do
			block(
				f,
				Vector3.new(1.3, 0.7, 1.3),
				at * CFrame.new(-1.9 + k * 1.9, 2.95, 0),
				goods(look, k + 1)
			)
		end
		block(f, Vector3.new(5.6, 0.1, 0.3), at * CFrame.new(0, 4.35, 0), WARM, Enum.Material.Neon)
	end,
	Rack = function(f, at, look)
		block(f, Vector3.new(6, 0.3, 2), at * CFrame.new(0, 0.15, 0), DARK)
		for _, e in { -1, 1 } do
			block(f, Vector3.new(0.3, 5.6, 0.3), at * CFrame.new(e * 2.9, 2.95, 0), STEEL)
		end
		block(f, Vector3.new(6, 0.2, 0.2), at * CFrame.new(0, 5.6, 0), STEEL, Enum.Material.Metal)
		for k = 0, 4 do
			block(
				f,
				Vector3.new(0.4, 2.6, 1.8),
				at * CFrame.new(-2.2 + k * 1.1, 4.2, 0),
				goods(look, k + 1),
				Enum.Material.Fabric
			)
		end
	end,
	Bikes = function(f, at, look)
		block(f, Vector3.new(6.4, 0.3, 3), at * CFrame.new(0, 0.15, 0), DARK)
		for k, z in { -0.7, 0.7 } do
			local c = goods(look, k + 1)
			for _, e in { -1, 1 } do
				cyl(
					f,
					0.2,
					2.2,
					at * CFrame.new(e * 1.6, 1.4, z) * CFrame.Angles(0, math.pi / 2, 0),
					DARK
				)
			end
			block(f, Vector3.new(3.4, 0.25, 0.25), at * CFrame.new(0, 2.1, z), c)
			block(f, Vector3.new(0.25, 1.2, 0.25), at * CFrame.new(-0.6, 2.4, z), c)
			block(f, Vector3.new(0.9, 0.25, 0.5), at * CFrame.new(-0.6, 3.05, z), DARK)
			block(f, Vector3.new(0.25, 0.25, 1.2), at * CFrame.new(1.5, 3, z), STEEL)
		end
	end,
	Crates = function(f, at, look)
		block(f, Vector3.new(6.4, 2, 3), at * CFrame.new(0, 1, 0), WOOD, Enum.Material.Wood)
		for k = 0, 2 do
			local cf = at * CFrame.new(-2.1 + k * 2.1, 2.6, 0) * CFrame.Angles(math.rad(-15), 0, 0)
			block(
				f,
				Vector3.new(2, 1, 2.6),
				cf,
				Color3.fromRGB(176, 130, 80),
				Enum.Material.WoodPlanks
			)
			block(
				f,
				Vector3.new(1.8, 0.3, 2.4),
				cf * CFrame.new(0, 0.6, 0),
				goods(look, k + 1),
				Enum.Material.Grass
			)
		end
	end,
	Lamps = function(f, at, look)
		block(f, Vector3.new(6, 0.4, 3), at * CFrame.new(0, 3, 0), WOOD, Enum.Material.Wood)
		block(f, Vector3.new(5, 2.8, 2), at * CFrame.new(0, 1.4, 0), DARK_WOOD, Enum.Material.Wood)
		for k = 0, 2 do
			block(f, Vector3.new(0.2, 1.8, 0.2), at * CFrame.new(-2 + k * 2, 4.1, 0), DARK)
			block(
				f,
				Vector3.new(1.3, 0.9, 1.3),
				at * CFrame.new(-2 + k * 2, 5.2, 0),
				goods(look, k + 1),
				Enum.Material.Neon
			)
		end
	end,
	Tanks = function(f, at, look)
		block(f, Vector3.new(6, 2.6, 3), at * CFrame.new(0, 1.3, 0), DARK)
		for _, e in { -1, 1 } do
			local water = block(
				f,
				Vector3.new(2.6, 2, 2.6),
				at * CFrame.new(e * 1.5, 3.6, 0),
				Color3.fromRGB(70, 150, 220),
				Enum.Material.Glass
			)
			water.Transparency = 0.35
			block(
				f,
				Vector3.new(2.5, 0.3, 2.5),
				at * CFrame.new(e * 1.5, 2.75, 0),
				Color3.fromRGB(200, 180, 140)
			)
			block(
				f,
				Vector3.new(0.6, 0.3, 0.2),
				at * CFrame.new(e * 1.5, 3.7, -0.3),
				goods(look, 3),
				Enum.Material.Neon
			)
		end
	end,
	Stands = function(f, at, look)
		block(f, Vector3.new(6, 0.3, 2.4), at * CFrame.new(0, 0.15, 0), DARK)
		for k = 0, 2 do
			local x = -2 + k * 2
			block(
				f,
				Vector3.new(0.25, 3.8 + (k % 2) * 0.8, 0.25),
				at * CFrame.new(x, 2.2 + (k % 2) * 0.4, 0),
				STEEL
			)
			local y = 4.2 + (k % 2) * 0.8
			round(f, 1.8, 0.15, at * CFrame.new(x, y, 0), goods(look, k + 1))
			block(f, Vector3.new(1, 0.7, 1), at * CFrame.new(x, y + 0.4, 0), goods(look, k + 1))
		end
	end,

	-- the burger place
	Register = function(f, at)
		block(f, Vector3.new(1.8, 0.7, 1.4), at * CFrame.new(0, 0.35, 0), DARK)
		block(
			f,
			Vector3.new(1.4, 1, 0.1),
			at * CFrame.new(0, 1.2, -0.3) * CFrame.Angles(math.rad(20), 0, 0),
			SCREEN,
			Enum.Material.Neon
		)
	end,
	Fryer = function(f, at)
		block(
			f,
			Vector3.new(5, 3.6, 3),
			at * CFrame.new(0, 1.8, 0),
			STEEL,
			Enum.Material.DiamondPlate
		)
		for _, e in { -1, 1 } do
			block(
				f,
				Vector3.new(1.8, 0.1, 2),
				at * CFrame.new(e * 1.2, 3.62, 0),
				Color3.fromRGB(230, 170, 60),
				Enum.Material.Neon
			)
			block(
				f,
				Vector3.new(1.4, 0.8, 1.4),
				at * CFrame.new(e * 1.2, 4.1, 0.2),
				DARK,
				Enum.Material.Metal
			)
		end
	end,
	DrinkMachine = function(f, at, look)
		block(f, Vector3.new(4, 6, 2.4), at * CFrame.new(0, 3, 0), Color3.fromRGB(196, 44, 40))
		block(
			f,
			Vector3.new(3.2, 2.2, 0.1),
			at * CFrame.new(0, 4.4, -1.22),
			look.accent,
			Enum.Material.Neon
		)
		block(
			f,
			Vector3.new(3.4, 0.3, 1),
			at * CFrame.new(0, 2.2, -1.5),
			STEEL,
			Enum.Material.Metal
		)
	end,
	Bin = function(f, at)
		block(f, Vector3.new(1.8, 3.2, 1.8), at * CFrame.new(0, 1.6, 0), Color3.fromRGB(60, 90, 70))
		block(f, Vector3.new(2, 0.4, 2), at * CFrame.new(0, 3.4, 0), Color3.fromRGB(40, 60, 46))
	end,

	-- the warehouse
	HighBayLight = function(f, at)
		round(f, 3.2, 1, at * CFrame.new(0, 0, 0), DARK)
		local lamp = round(f, 2.6, 0.1, at * CFrame.new(0, -0.55, 0), COOL)
		lamp.Material = Enum.Material.Neon
		light(lamp, 34, 1.1, COOL)
	end,
	Forklift = function(f, at, look)
		block(f, Vector3.new(4, 2.6, 5), at * CFrame.new(0, 2, 0.5), look.accent)
		block(f, Vector3.new(4, 1.4, 1.6), at * CFrame.new(0, 2.6, 2.6), DARK)
		block(f, Vector3.new(1.6, 0.8, 1.4), at * CFrame.new(0, 3.7, 0.9), DARK)
		for _, e in { -1, 1 } do
			block(
				f,
				Vector3.new(0.4, 7, 0.4),
				at * CFrame.new(e * 1.4, 3.5, -2.2),
				DARK,
				Enum.Material.Metal
			)
			block(
				f,
				Vector3.new(0.5, 0.2, 3.6),
				at * CFrame.new(e * 0.9, 0.4, -4),
				STEEL,
				Enum.Material.Metal
			)
			block(f, Vector3.new(0.3, 4.6, 0.3), at * CFrame.new(e * 1.8, 5.6, 2.4), DARK)
			for _, z in { -1.2, 2.2 } do
				cyl(f, 0.6, 1.6, at * CFrame.new(e * 2.1, 0.8, z), DARK)
			end
		end
		block(f, Vector3.new(4, 0.3, 4.4), at * CFrame.new(0, 7.9, 0.6), DARK, Enum.Material.Metal)
	end,
	PackingTable = function(f, at)
		block(f, Vector3.new(7, 0.4, 3), at * CFrame.new(0, 3.2, 0), WOOD, Enum.Material.Wood)
		for _, e in { -1, 1 } do
			block(
				f,
				Vector3.new(0.4, 3, 2.6),
				at * CFrame.new(e * 3.1, 1.5, 0),
				STEEL,
				Enum.Material.Metal
			)
		end
		block(
			f,
			Vector3.new(2, 1.6, 1.6),
			at * CFrame.new(-1.6, 4.2, 0.2),
			Color3.fromRGB(196, 150, 96),
			Enum.Material.Cardboard
		)
		block(
			f,
			Vector3.new(1.4, 1, 1.2),
			at * CFrame.new(1.4, 3.9, 0.3),
			Color3.fromRGB(180, 136, 86),
			Enum.Material.Cardboard
		)
		round(f, 0.7, 0.4, at * CFrame.new(0.2, 3.6, -0.6), Color3.fromRGB(200, 190, 160))
	end,
}

local function hash(s: string): number
	local h = 7
	for k = 1, #s do
		h = (h * 31 + string.byte(s, k)) % 1000003
	end
	return h
end

local function broken(model: Model): boolean
	for _, p in model:GetChildren() do
		if p:GetAttribute("Broken") then
			return true
		end
	end
	return false
end

local function rgbList(list: { { number } }): { Color3 }
	local out = {}
	for _, c in list do
		table.insert(out, Color3.fromRGB(c[1], c[2], c[3]))
	end
	return out
end

type AnyPiece = {
	kind: string,
	x: number,
	z: number,
	fx: number,
	fz: number,
	y: number?,
	w: number?,
	d: number?,
}

-- the pieces of a house (by type) or a town building (by its Interior attribute), cached per model
local layouts: { [Model]: { AnyPiece } | false } = {}
local function piecesOf(model: Model): { AnyPiece }?
	local cached = layouts[model]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local kind = model:GetAttribute("HouseType")
	local list: { AnyPiece }? = nil
	if typeof(kind) == "string" then
		local layout = (Config.Layouts :: any)[kind] :: Config.Layout?
		list = if layout then layout.pieces :: any else nil
	else
		local layout = Layouts.of(model:GetAttributes(), LAYOUT_CONFIG)
		list = if layout then layout.pieces :: any else nil
	end
	layouts[model] = list or false
	return list
end

local function furnish(model: Model, into: Folder): Folder?
	local pieces = piecesOf(model)
	if not pieces then
		return nil
	end
	local m = if model:GetAttribute("Mirror") then -1 else 1
	local base = model.WorldPivot
	local h = hash(model.Name)
	local theme = (Buildings.Shops.Themes :: any)[model:GetAttribute("Theme") or ""]
	local accent = model:GetAttribute("Accent")
	local look: Look = {
		fabric = FABRICS[h % #FABRICS + 1],
		rug = RUGS[(h // 7) % #RUGS + 1],
		goods = if theme then rgbList(theme.goods) else BOOKS,
		accent = if typeof(accent) == "Color3" then accent else WOOD,
		w = 8,
		d = 8,
		m = m,
	}
	local folder = Instance.new("Folder")
	folder.Name = model.Name
	for _, piece in pieces do
		local build = PIECES[piece.kind]
		if build then
			local pos = (base * CFrame.new(piece.x * m, Y0 + (piece.y or 0), -piece.z)).Position
			local face = base:VectorToWorldSpace(Vector3.new(piece.fx * m, 0, -piece.fz))
			look.w = piece.w or 8
			look.d = piece.d or 8
			build(folder, CFrame.lookAt(pos, pos + face), look)
		end
	end
	folder.Parent = into
	return folder
end

-- keep the nearest `max` of `models` within `radius` of the camera furnished
local function keep(
	models: { Model },
	built: { [Model]: Folder },
	into: Folder,
	eye: Vector3,
	radius: number,
	max: number
)
	local near: { { model: Model, d: number } } = {}
	for _, model in models do
		local d = (model.WorldPivot.Position - eye).Magnitude
		if d < radius then
			table.insert(near, { model = model, d = d })
		end
	end
	table.sort(near, function(a, b)
		return a.d < b.d
	end)
	local want: { [Model]: boolean } = {}
	for k = 1, math.min(#near, max) do
		local model = near[k].model
		if not broken(model) then
			want[model] = true
		end
	end
	for model, folder in built do
		if not want[model] then
			folder:Destroy()
			built[model] = nil
		end
	end
	for model in want do
		if not built[model] then
			local folder = furnish(model, into)
			if folder then
				built[model] = folder
			end
		end
	end
end

function Interiors.start()
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local buildings = map:WaitForChild("Buildings")
		local into = Instance.new("Folder")
		into.Name = "Interiors"
		into.Parent = workspace
		local houses: { Model } = {}
		local town: { Model } = {}
		local builtHouses: { [Model]: Folder } = {}
		local builtTown: { [Model]: Folder } = {}
		task.wait(1)
		for _, m in buildings:GetChildren() do
			if m:IsA("Model") then
				if m:GetAttribute("HouseType") then
					table.insert(houses, m)
				elseif m:GetAttribute("Interior") then
					table.insert(town, m)
				end
			end
		end
		while true do
			task.wait(1)
			local camera = workspace.CurrentCamera
			if not camera then
				continue
			end
			local eye = camera.CFrame.Position
			keep(houses, builtHouses, into, eye, Config.Radius, Config.MaxFurnished)
			keep(town, builtTown, into, eye, TOWN.Radius, TOWN.MaxFurnished)
		end
	end)
end

return Interiors
