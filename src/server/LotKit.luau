--!strict
-- Life in the town's car parks and yards from Config/Lots: painted bays with parked cars, dumpsters, lamps and
-- trees along a lot, parked cars in the ramp lots, picnic tables at the burger place, pallets at the
-- warehouse. Paint is static; everything else is a prop (Props folder) any vehicle knocks flying.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Lots)
local Crowd = require(ReplicatedStorage.Shared.Config.Crowd)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Greenery = require(script.Parent.Greenery)
local PaintKit = require(script.Parent.PaintKit)

local LotKit = {}

local WHITE = Color3.fromRGB(240, 240, 236)
local STEEL = Color3.fromRGB(70, 74, 80)

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

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

local function prop(folder: Instance, kind: string): Model
	local m = Instance.new("Model")
	m.Name = kind
	m:SetAttribute("Prop", kind)
	m.Parent = folder
	return m
end

-- a parked car: a vehicle model cut down to its body, paint, glass and wheels, welded to its body so a knock
-- sends it flying in one piece; `cf` is where its bottom centre stands, facing along its look vector
local KEEP = { Body = true, Paint = true, Glass = true }
local MODELS = ReplicatedStorage:WaitForChild("VehicleModels")

function LotKit.car(props: Instance, ids: { string }, cf: CFrame, random: Random): Model?
	local id = ids[random:NextInteger(1, #ids)]
	local source = MODELS:FindFirstChild(id)
	if not (source and source:IsA("Model")) then
		return nil
	end
	local model = source:Clone()
	model.WorldPivot = CFrame.identity
	model:ScaleTo(Game.VehicleScale)
	for _, d in model:GetDescendants() do
		-- keep the body, paint, glass and wheels; drop the rest (interior, needles, the drivable model's
		-- attachments, welds and sounds)
		local keep = if d:IsA("BasePart")
			then KEEP[d.Name] or string.sub(d.Name, 1, 6) == "Wheel_"
			else d:IsA("Model")
		if not keep then
			d:Destroy()
		end
	end
	local body = model:FindFirstChild("Body") :: BasePart?
	if not body then
		model:Destroy()
		return nil
	end
	local box, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0))
	model:PivotTo(cf * CFrame.new(0, Cfg.Ground - Cfg.CarSink, 0))
	local paintPart = model:FindFirstChild("Paint") :: BasePart?
	if paintPart and not Cfg.KeepFactory[id] then
		paintPart.Color = rgb(Cfg.Paints[random:NextInteger(1, #Cfg.Paints)])
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanTouch = false
			-- the body is what vehicles hit (meshes come in with CanQuery off)
			p.CanCollide = p == body
			p.CanQuery = p == body
			if p ~= body then
				local w = Instance.new("WeldConstraint")
				w.Part0 = body
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	model.Name = "ParkedCar"
	model:SetAttribute("Prop", "ParkedCar")
	model.Parent = props
	return model
end

-- a dumpster: a box and a lid, its long side along `along`
local function dumpster(props: Instance, at: Vector3, along: Vector3, random: Random)
	local D = Cfg.Dumpster
	local m = prop(props, "Dumpster")
	local cf = CFrame.lookAt(at, at + along:Cross(Vector3.yAxis)) -- long side (x) along `along`
	local colour = rgb(Cfg.DumpsterColours[random:NextInteger(1, #Cfg.DumpsterColours)])
	part(
		m,
		Vector3.new(D[1], D[2], D[3]),
		cf * CFrame.new(0, D[2] / 2, 0),
		colour,
		Enum.Material.Metal
	)
	part(
		m,
		Vector3.new(D[1] + 0.4, 0.4, D[3] + 0.6),
		cf * CFrame.new(0, D[2] + 0.3, 0.2) * CFrame.Angles(-0.12, 0, 0),
		colour:Lerp(Color3.new(0, 0, 0), 0.35)
	)
end

local function lamp(props: Instance, at: Vector3)
	local m = prop(props, "Lamp")
	local h = Cfg.LampHeight
	local pole = part(
		m,
		Vector3.new(h, 0.8, 0.8),
		CFrame.new(at + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		STEEL
	)
	pole.Shape = Enum.PartType.Cylinder
	local head = part(
		m,
		Vector3.new(3, 0.8, 1.6),
		CFrame.new(at + Vector3.new(0, h + 0.2, 0)),
		Color3.fromRGB(255, 244, 214)
	)
	head.Material = Enum.Material.Neon
end

-- a lot beside a building: `centre` is the lot's middle on the ground, `toward` the unit way to the building,
-- `width` the lot's length across that way and `depth` along it. A row of bays runs along the building's side
-- with cars parked nose-in; dumpsters at the row's ends, lamps and trees along the far side.
function LotKit.yard(
	static: Instance,
	props: Instance,
	centre: Vector3,
	toward: Vector3,
	width: number,
	depth: number,
	look: Cfg.Yard,
	random: Random
)
	local bw, bd = Cfg.Bay[1], Cfg.Bay[2]
	if depth < bd + Cfg.Edge + 8 then
		return
	end
	local along = Vector3.new(-toward.Z, 0, toward.X)
	local n = math.min(look.bays, math.floor((width - Cfg.EndClear * 2) / bw))
	if n < 1 then
		return
	end
	local rowLen = n * bw
	local rowAt = centre + toward * (depth / 2 - Cfg.Edge - bd / 2)
	-- the bay lines: one paint patch (lots are square to the world, so `toward` is along x or z)
	local function world(a: number, t: number): (number, number)
		local v = along * a + toward * t
		return math.abs(v.X), math.abs(v.Z)
	end
	local px, pz = world(rowLen + 2, bd + 1)
	local draw = PaintKit.patch(static, rowAt + Vector3.new(0, Cfg.Ground + 0.02, 0), px, pz)
	local ex, ez = world(Cfg.Line, bd)
	for k = 0, n do
		local o = along * (-rowLen / 2 + k * bw)
		draw(o.X, o.Z, ex, ez, WHITE)
	end
	-- cars in random bays, nose to the building
	local free = {}
	for k = 1, n do
		table.insert(free, k)
	end
	for _ = 1, math.min(look.cars, n) do
		local k = table.remove(free, random:NextInteger(1, #free)) :: number
		local at = rowAt + along * (-rowLen / 2 + (k - 0.5) * bw) + toward * 1.5
		LotKit.car(props, Cfg.Cars, CFrame.lookAt(at, at + toward), random)
	end
	for d = 1, look.dumpsters do
		local side = if d % 2 == 1 then 1 else -1
		local at = rowAt
			+ along * side * (rowLen / 2 + Cfg.Dumpster[1] / 2 + 2)
			+ toward * (bd / 2 - Cfg.Dumpster[3] / 2)
		dumpster(props, at, along, random)
	end
	local far = centre - toward * (depth / 2 - 3)
	for k = 1, look.lamps do
		lamp(props, far + along * ((k - 0.5) / look.lamps - 0.5) * width * 0.7)
	end
	if depth >= Cfg.TreesFrom then
		for k = 1, look.trees do
			local t = ((k - 0.5) / look.trees - 0.5) * (width - Cfg.EndClear * 2)
			Greenery.tree(props, far + along * t - toward * 1, random)
		end
	end
	-- a planted island down the middle of what's left, trees on it, cars parked along its building side
	local I = Cfg.Island
	if look.island and depth >= I.from then
		local rowBack = depth / 2 - Cfg.Edge - bd -- from the lot's middle to the bay row's back
		local mid = centre + toward * ((rowBack - depth / 2) / 2 - I.shift)
		local len = rowLen * I.length
		local island = part(
			static,
			Vector3.new(I.width, I.height, len),
			CFrame.new(mid + Vector3.new(0, Cfg.Ground + I.height / 2 - 0.2, 0))
				* CFrame.lookAt(Vector3.zero, along),
			Color3.fromRGB(96, 150, 70),
			Enum.Material.Grass
		)
		island.Name = "Island"
		island.CanCollide = false -- cars roll straight over it (a kerb this low still stops some vehicles)
		for k = 1, I.trees do
			local t = ((k - 0.5) / I.trees - 0.5) * (len - 8)
			Greenery.tree(props, mid + along * t, random)
		end
		for k = 1, I.cars do
			local t = ((k - 0.5) / I.cars - 0.5) * len + random:NextNumber(-4, 4)
			local at = mid + along * t + toward * (I.width / 2 + bd / 2 + 1)
			LotKit.car(props, Cfg.Cars, CFrame.lookAt(at, at - toward), random)
		end
	end
end

-- a shop's back: a service door and an air-con box on the wall facing its car park. They go into the shop's own
-- model, so they come down and stand back up with it. `at` is the wall's face at the ground, `face` its
-- outward way, `width` the shop's width along the wall.
function LotKit.shopBack(model: Model, at: Vector3, face: Vector3, width: number, random: Random)
	local B = Cfg.Back
	local along = Vector3.new(-face.Z, 0, face.X)
	local turn = CFrame.lookAt(Vector3.zero, face)
	local doorX = random:NextNumber(-0.3, 0.3) * width
	local door = part(
		model,
		Vector3.new(B.door[1], B.door[2], 0.4),
		CFrame.new(at + along * doorX + face * 0.2 + Vector3.new(0, B.door[2] / 2, 0)) * turn,
		rgb(B.doorColour),
		Enum.Material.Metal
	)
	door.Name = "BackDoor"
	local side = if doorX > 0 then -1 else 1
	local ac = part(
		model,
		Vector3.new(B.ac[1], B.ac[2], B.ac[3]),
		CFrame.new(
			at
				+ along * (doorX + side * (B.door[1] / 2 + B.ac[1] / 2 + 3))
				+ face * (B.ac[3] / 2)
				+ Vector3.new(0, B.ac[2] / 2, 0)
		) * turn,
		rgb(B.acColour),
		Enum.Material.DiamondPlate
	)
	ac.Name = "AirCon"
end

-- parked cars in a ramp lot's south bay row (Config/Country Lot draws the bays)
function LotKit.rampLot(props: Instance, lotCentre: Vector3, lot: any, random: Random)
	local bw, bd = lot.Bay[1], lot.Bay[2]
	local rowLen = lot.Bays * bw
	local z = bd / 2 + 6
	for _, k in Cfg.LotParked do
		local x = lot.Shift - rowLen / 2 + (k - 0.5) * bw
		local at = lotCentre + Vector3.new(x, 0, z)
		LotKit.car(props, Cfg.LotCars, CFrame.lookAt(at, at + Vector3.new(0, 0, 1)), random)
	end
end

-- picnic tables on the burger place's forecourt, `width` wide at `front`: rows of two on its left-hand side
-- (the sign pole and the drive-through are on its right, Places.restaurant)
function LotKit.picnic(props: Instance, front: Vector3, out: Vector3, width: number)
	local P = Cfg.Picnic
	local along = Vector3.new(-out.Z, 0, out.X)
	local wood = rgb(Cfg.Wood)
	local L, H, W = P.size[1], P.size[2], P.size[3]
	for row = 0, P.rows - 1 do
		for k = 1, 2 do
			local at = front - along * (width / 2 + 4 + k * P.gap) - out * (6 + row * P.rowGap)
			local cf = CFrame.lookAt(at, at + out)
			local m = prop(props, "Picnic")
			part(
				m,
				Vector3.new(W, 0.5, L),
				cf * CFrame.new(0, H, 0),
				wood,
				Enum.Material.WoodPlanks
			)
			for _, s in { -1, 1 } do
				part(
					m,
					Vector3.new(1.4, H * 0.55, L),
					cf * CFrame.new(s * (W / 2 + 1.2), H * 0.275, 0),
					wood,
					Enum.Material.WoodPlanks
				)
			end
		end
	end
end

local function pallet(props: Instance, at: Vector3, random: Random)
	local P, Ld = Cfg.Pallet, Cfg.Load
	local cf = CFrame.new(at) * CFrame.Angles(0, random:NextNumber(-0.2, 0.2), 0)
	local m = prop(props, "Pallet")
	part(
		m,
		Vector3.new(P[1], P[2], P[3]),
		cf * CFrame.new(0, P[2] / 2, 0),
		rgb(Cfg.Wood),
		Enum.Material.WoodPlanks
	)
	part(
		m,
		Vector3.new(Ld[1], Ld[2], Ld[3]),
		cf * CFrame.new(0, P[2] + Ld[2] / 2, 0),
		rgb(Cfg.Cardboard),
		Enum.Material.Cardboard
	)
end

-- the warehouse yard (`half` = half the block inside its sidewalks): painted truck lanes out from its loading
-- bays (Config/Lots Dock), pallet stacks between the bays and in the yard's corners front and back
function LotKit.warehouse(
	static: Instance,
	props: Instance,
	centre: Vector3,
	out: Vector3,
	half: number,
	random: Random
)
	local along = Vector3.new(-out.Z, 0, out.X)
	local D = Cfg.Dock
	local front = centre + out * (Crowd.WarehouseSize[2] / 2 + D.length / 2)
	local span = math.max(table.unpack(D.bays)) - math.min(table.unpack(D.bays)) + D.lane + 2
	local mid = (math.max(table.unpack(D.bays)) + math.min(table.unpack(D.bays))) / 2
	local sizeV = along * span + out * D.length
	local draw = PaintKit.patch(
		static,
		front + along * mid + Vector3.new(0, Cfg.Ground + 0.02, 0),
		math.abs(sizeV.X),
		math.abs(sizeV.Z)
	)
	local lineV = along * Cfg.Line + out * D.length
	for _, x in D.bays do
		for _, e in { -1, 1 } do
			local o = along * (x - mid + e * D.lane / 2)
			draw(o.X, o.Z, math.abs(lineV.X), math.abs(lineV.Z), WHITE)
		end
	end
	for _, x in D.pallets do
		pallet(props, centre + out * (Crowd.WarehouseSize[2] / 2 + 6) + along * x, random)
	end
	for k = 1, Cfg.PalletStacks do
		local side = if k % 2 == 1 then 1 else -1
		local back = if k > Cfg.PalletStacks / 2 then -1 else 1
		local row = math.floor((k - 1) / 2) % 2
		local at = centre
			+ along * side * (half - 8 - row * 10)
			+ out * back * (half - 8 - random:NextNumber(0, 10))
		pallet(props, at, random)
	end
end

return LotKit
