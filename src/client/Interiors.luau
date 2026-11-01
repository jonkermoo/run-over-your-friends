--!strict
-- House interiors, drawn on this screen only: furniture and lamps on the ground floor of the houses nearest
-- the camera (layouts in Config/Interiors, so they match where the server seats residents). Nothing here
-- collides or is hit-tested, and a house being smashed loses its furniture until it's rebuilt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Interiors)

local Interiors = {}

local Y0 = 0.08
local WOOD = Color3.fromRGB(140, 98, 62)
local DARK_WOOD = Color3.fromRGB(96, 66, 44)
local WHITE = Color3.fromRGB(236, 234, 228)
local STEEL = Color3.fromRGB(190, 194, 200)
local WARM = Color3.fromRGB(255, 214, 150)
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

type Build = (folder: Folder, at: CFrame, fabric: Color3, rug: Color3) -> ()

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

local function light(part: BasePart)
	local l = Instance.new("PointLight")
	l.Range = Config.LampRange
	l.Brightness = Config.LampBrightness
	l.Color = WARM
	l.Shadows = false
	l.Parent = part
end

-- each piece is built in its own frame: origin on the floor, front facing -Z (the piece's LookVector)
local PIECES: { [string]: Build } = {
	Sofa = function(f, at, fabric)
		block(f, Vector3.new(7, 1.4, 3), at * CFrame.new(0, 1.1, 0), fabric, Enum.Material.Fabric)
		block(
			f,
			Vector3.new(7, 2.2, 0.9),
			at * CFrame.new(0, 2.2, 1.1),
			fabric,
			Enum.Material.Fabric
		)
		for _, e in { -1, 1 } do
			block(
				f,
				Vector3.new(0.8, 2, 3),
				at * CFrame.new(e * 3.5, 1.5, 0),
				fabric:Lerp(Color3.new(0, 0, 0), 0.15),
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
			Color3.fromRGB(70, 130, 190),
			Enum.Material.Neon
		)
		screen.Transparency = 0.2
	end,
	Rug = function(f, at, _, rug)
		block(f, Vector3.new(8, 0.08, 6), at * CFrame.new(0, 0.34, 0), rug, Enum.Material.Fabric)
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
}

local function hash(s: string): number
	local h = 7
	for k = 1, #s do
		h = (h * 31 + string.byte(s, k)) % 1000003
	end
	return h
end

local function broken(house: Model): boolean
	for _, p in house:GetChildren() do
		if p:GetAttribute("Broken") then
			return true
		end
	end
	return false
end

local function furnish(house: Model, into: Folder): Folder?
	local kind = house:GetAttribute("HouseType")
	local layout = if typeof(kind) == "string"
		then (Config.Layouts :: any)[kind] :: Config.Layout?
		else nil
	if not layout then
		return nil
	end
	local m = if house:GetAttribute("Mirror") then -1 else 1
	local base = house.WorldPivot
	local h = hash(house.Name)
	local fabric = FABRICS[h % #FABRICS + 1]
	local rug = RUGS[(h // 7) % #RUGS + 1]
	local folder = Instance.new("Folder")
	folder.Name = house.Name
	for _, piece in layout.pieces do
		local build = PIECES[piece.kind]
		if build then
			local pos = (base * CFrame.new(piece.x * m, Y0, -piece.z)).Position
			local face = base:VectorToWorldSpace(Vector3.new(piece.fx * m, 0, -piece.fz))
			build(folder, CFrame.lookAt(pos, pos + face), fabric, rug)
		end
	end
	folder.Parent = into
	return folder
end

function Interiors.start()
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local buildings = map:WaitForChild("Buildings")
		local into = Instance.new("Folder")
		into.Name = "Interiors"
		into.Parent = workspace
		local houses: { Model } = {}
		local built: { [Model]: Folder } = {}
		task.wait(1)
		for _, m in buildings:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("HouseType") then
				table.insert(houses, m)
			end
		end
		while true do
			task.wait(1)
			local camera = workspace.CurrentCamera
			if not camera then
				continue
			end
			local eye = camera.CFrame.Position
			local near: { { house: Model, d: number } } = {}
			for _, house in houses do
				local d = (house.WorldPivot.Position - eye).Magnitude
				if d < Config.Radius then
					table.insert(near, { house = house, d = d })
				end
			end
			table.sort(near, function(a, b)
				return a.d < b.d
			end)
			local want: { [Model]: boolean } = {}
			for k = 1, math.min(#near, Config.MaxFurnished) do
				local house = near[k].house
				if not broken(house) then
					want[house] = true
				end
			end
			for house, folder in built do
				if not want[house] then
					folder:Destroy()
					built[house] = nil
				end
			end
			for house in want do
				if not built[house] then
					local folder = furnish(house, into)
					if folder then
						built[house] = folder
					end
				end
			end
		end
	end)
end

return Interiors
