--!strict
-- Lived-in lots (Config/Yards): a shed, a trampoline or a swing set in a back garden, and an office tower's
-- street front (awnings, planters with bushes, a bench). Every piece is a prop (any vehicle knocks it flying,
-- BuildingService stands it back up). Pieces draw from their own random streams, never the layout's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Yards)
local Foliage = require(ReplicatedStorage.Shared.Config.Foliage)
local World = require(ReplicatedStorage.Shared.Config.World)
local Greenery = require(script.Parent.Greenery)
local StreetKit = require(script.Parent.StreetKit)

local YardKit = {}

export type Taken = { c: Vector3, half: Vector3 }

-- whether `p` is in (or within `pad` of) any of the boxes
function YardKit.inside(taken: { Taken }, p: Vector3, pad: number): boolean
	for _, t in taken do
		if math.abs(p.X - t.c.X) < t.half.X + pad and math.abs(p.Z - t.c.Z) < t.half.Z + pad then
			return true
		end
	end
	return false
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function pick(random: Random, list: { { number } }): Color3
	return rgb(list[random:NextInteger(1, #list)])
end

local function prop(folder: Instance, kind: string): Model
	local m = Instance.new("Model")
	m.Name = kind
	m:SetAttribute("Prop", kind)
	m.Parent = folder
	return m
end

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material?,
	class: string?
): BasePart
	local p = Instance.new(class or "Part") :: BasePart
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- a garden shed on `at` (the ground), its door facing `face`
local function shed(folder: Instance, at: Vector3, face: Vector3, random: Random)
	local S = Cfg.Shed
	local w, h, d = S.Size[1], S.Size[2], S.Size[3]
	local m = prop(folder, "Shed")
	local cf = CFrame.lookAt(at, at + face)
	part(
		m,
		Vector3.new(w, h, d),
		cf * CFrame.new(0, h / 2, 0),
		pick(random, S.Walls),
		Enum.Material.WoodPlanks
	)
	-- the gable: two wedges meeting along the ridge (front to back), a little proud of the walls
	local roof = rgb(S.RoofColour)
	for _, sx in { -1, 1 } do
		part(
			m,
			Vector3.new(d + 1, S.Roof, w / 2 + 0.6),
			cf
				* CFrame.new(sx * (w / 4 + 0.3), h + S.Roof / 2, 0)
				* CFrame.Angles(0, -sx * math.pi / 2, 0), -- the slope faces out, the tall side meets at the ridge
			roof,
			Enum.Material.Slate,
			"WedgePart"
		)
	end
	part(
		m,
		Vector3.new(w * 0.4, h * 0.8, 0.3),
		cf * CFrame.new(0, h * 0.4, -d / 2 - 0.15),
		rgb(S.Door),
		Enum.Material.Wood
	)
end

-- a round trampoline on `at`: a coloured rim, a black mat and three legs
local function trampoline(folder: Instance, at: Vector3, random: Random)
	local T = Cfg.Trampoline
	local m = prop(folder, "Trampoline")
	local up = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
	local rim = part(
		m,
		Vector3.new(0.5, T.Dia, T.Dia),
		up + Vector3.new(0, T.Height, 0),
		pick(random, T.Rim)
	)
	rim.Shape = Enum.PartType.Cylinder
	local mat = part(
		m,
		Vector3.new(0.3, T.Dia - 1.4, T.Dia - 1.4),
		up + Vector3.new(0, T.Height + 0.2, 0),
		rgb(T.Mat),
		Enum.Material.Fabric
	)
	mat.Shape = Enum.PartType.Cylinder
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3
		local leg = at + Vector3.new(math.cos(a), 0, math.sin(a)) * (T.Dia / 2 - 0.8)
		part(
			m,
			Vector3.new(0.35, T.Height, 0.35),
			CFrame.new(leg + Vector3.new(0, T.Height / 2, 0)),
			rgb(T.Legs),
			Enum.Material.Metal
		)
	end
end

-- a swing set on `at`, its bar running along `along`: two posts, the bar, two seats on ropes
local function swings(folder: Instance, at: Vector3, along: Vector3)
	local S = Cfg.Swings
	local m = prop(folder, "Swings")
	local cf = CFrame.lookAt(at, at + Vector3.new(-along.Z, 0, along.X))
	local frame = rgb(S.Frame)
	for _, sx in { -1, 1 } do
		part(
			m,
			Vector3.new(0.5, S.Height, 0.5),
			cf * CFrame.new(sx * S.Width / 2, S.Height / 2, 0),
			frame,
			Enum.Material.Metal
		)
	end
	part(
		m,
		Vector3.new(S.Width + 0.6, 0.5, 0.5),
		cf * CFrame.new(0, S.Height, 0),
		frame,
		Enum.Material.Metal
	)
	for _, sx in { -0.25, 0.25 } do
		local x = sx * S.Width
		part(m, Vector3.new(1.8, 0.3, 1), cf * CFrame.new(x, S.SeatHeight, 0), rgb(S.Seat))
		for _, rx in { -0.7, 0.7 } do
			part(
				m,
				Vector3.new(0.12, S.Height - S.SeatHeight - 0.1, 0.12),
				cf * CFrame.new(x + rx, S.SeatHeight + 0.1 + (S.Height - S.SeatHeight - 0.1) / 2, 0),
				rgb(S.Rope)
			)
		end
	end
end

-- maybe one thing in a back garden: `corner` is its spot on the ground, `face` toward the house
function YardKit.garden(folder: Instance, corner: Vector3, face: Vector3)
	local G = Cfg.Garden
	local own = Random.new(G.Seed + math.floor(corner.X) * 31 + math.floor(corner.Z) * 7)
	if own:NextNumber() >= G.Chance then
		return
	end
	local total = G.Kinds.shed + G.Kinds.trampoline + G.Kinds.swings
	local roll = own:NextNumber(0, total)
	if roll < G.Kinds.shed then
		shed(folder, corner, face, own)
	elseif roll < G.Kinds.shed + G.Kinds.trampoline then
		trampoline(folder, corner, own)
	else
		swings(folder, corner, face)
	end
end

-- an office tower's street front: `door` on the ground at the front's middle, `out` toward the street,
-- `width` the front's length
function YardKit.officeFront(folder: Instance, door: Vector3, out: Vector3, width: number)
	local O = Cfg.Office
	local own = Random.new(O.Seed + math.floor(door.X) * 13 + math.floor(door.Z))
	local across = Vector3.new(-out.Z, 0, out.X)
	local colour = pick(own, O.Awnings)
	for _, sx in { -1, 1 } do
		local m = prop(folder, "Awning")
		local at = door + across * sx * width / 2 * O.AwningAt + out * (O.Awning[2] / 2)
		local cf = CFrame.lookAt(at, at + out) * CFrame.Angles(-O.AwningTilt, 0, 0)
		part(
			m,
			Vector3.new(O.Awning[1], O.Awning[3], O.Awning[2]),
			cf + Vector3.new(0, O.AwningHeight, 0),
			colour,
			Enum.Material.Fabric
		)
	end
	for _, sx in { -1, 1 } do
		local m = prop(folder, "Planter")
		local at = door + across * sx * (width / 2 - O.PlanterInset) + out * O.Out
		local P = O.Planter
		part(
			m,
			Vector3.new(P[1], P[2], P[3]),
			CFrame.lookAt(at, at + out) + Vector3.new(0, P[2] / 2, 0),
			rgb(O.PlanterColour),
			Enum.Material.Concrete
		)
		local bush = Greenery.place(
			m,
			Foliage.Bushes[own:NextInteger(1, #Foliage.Bushes)],
			at + Vector3.new(0, P[2] - 0.4, 0),
			O.BushSize,
			nil,
			own:NextNumber(0, math.pi * 2),
			rgb(Foliage.TuftGreens[own:NextInteger(1, #Foliage.TuftGreens)])
		)
		bush.Material = Enum.Material.Grass
	end
	StreetKit.bench(folder, door + across * O.BenchAt + out * O.Out, out)
end

-- a slide: a ladder post, a platform and the chute sloping down along `along`
local function slide(folder: Instance, at: Vector3, along: Vector3)
	local M = Cfg.Middle
	local w, h, l = M.Slide[1], M.Slide[2], M.Slide[3]
	local m = prop(folder, "Slide")
	local cf = CFrame.lookAt(at, at + along)
	local colour = rgb(M.SlideColour)
	part(m, Vector3.new(w, 0.5, w), cf * CFrame.new(0, h, 0), colour)
	for _, sx in { -1, 1 } do
		part(
			m,
			Vector3.new(0.4, h, 0.4),
			cf * CFrame.new(sx * (w / 2 - 0.2), h / 2, w / 2 - 0.2),
			rgb(M.SlidePosts),
			Enum.Material.Metal
		)
	end
	local run = math.sqrt(l * l + h * h)
	part(
		m,
		Vector3.new(w - 0.4, 0.4, run),
		cf * CFrame.new(0, h / 2, -w / 2 - l / 2) * CFrame.Angles(-math.atan2(h, l), 0, 0),
		rgb(M.ChuteColour)
	)
end

-- the middle of a block of town homes: `centre` on the ground, `inner` the block's inner size, the hedge line
-- running along x through the middle. Returns the boxes it filled (middle and half size on the ground), so
-- trees can keep out of them
function YardKit.blockMiddle(folder: Instance, centre: Vector3, inner: number): { Taken }
	local M = Cfg.Middle
	local own = Random.new(M.Seed + math.floor(centre.X) * 17 + math.floor(centre.Z) * 3)
	local reach = inner / 2 * M.Reach
	local taken: { Taken } = {}
	local total = reach * 2 - M.HedgeGap * (M.Hedges - 1)
	local len = total / M.Hedges
	for k = 0, M.Hedges - 1 do
		local x = -reach + len / 2 + k * (len + M.HedgeGap)
		local m = prop(folder, "Hedge")
		local h = Greenery.place(
			m,
			Foliage.Bushes[own:NextInteger(1, #Foliage.Bushes)],
			centre + Vector3.new(x, -0.3, 0),
			nil,
			M.HedgeHeight,
			0,
			rgb(Foliage.TuftGreens[own:NextInteger(1, #Foliage.TuftGreens)]):Lerp(
				Color3.new(0, 0, 0),
				0.2
			)
		)
		h.Size = Vector3.new(len, M.HedgeHeight, M.HedgeDepth)
		h.CFrame = CFrame.new(centre + Vector3.new(x, M.HedgeHeight / 2 - 0.3, 0))
		h.Material = Enum.Material.Grass
		h.CanCollide = true
		h.CanQuery = true
		h.CanTouch = true
	end
	table.insert(taken, { c = centre, half = Vector3.new(reach, 0, M.HedgeDepth / 2) })
	-- a playground on every PlayEvery-th block, on one side of the hedge; the beds go on the other side
	local pitch = World.Map.BlockSize + World.Map.RoadWidth -- one block and its road
	local blockIndex = math.floor(centre.X / pitch + 0.5) + math.floor(centre.Z / pitch + 0.5)
	local play = blockIndex % M.PlayEvery == 0
	local playSide = if own:NextNumber() < 0.5 then 1 else -1
	for b = 1, M.Beds do
		local side = if play then -playSide else (if b % 2 == 0 then 1 else -1)
		local at = centre
			+ Vector3.new(own:NextNumber(-reach * 0.7, reach * 0.7), 0, side * M.BedOff)
		Greenery.flowerBed(folder, at, Vector3.new(1, 0, 0), own)
		table.insert(taken, { c = at, half = Vector3.new(6, 0, 3) })
	end
	if play then
		local gap = M.PlaySpacing
		local spot = centre
			+ Vector3.new(
				own:NextNumber(-reach * 0.5, reach * 0.5),
				0,
				playSide * (M.BedOff + M.PlayOff)
			)
		swings(folder, spot, Vector3.new(1, 0, 0))
		slide(folder, spot + Vector3.new(gap, 0, 0), Vector3.new(0, 0, playSide))
		local sand = prop(folder, "Sandpit")
		local S = M.Sand
		part(
			sand,
			Vector3.new(S[1] + 1, S[2] + 0.2, S[1] + 1),
			CFrame.new(spot + Vector3.new(-gap, (S[2] + 0.2) / 2, 0)),
			rgb(M.SandEdge),
			Enum.Material.WoodPlanks
		)
		part(
			sand,
			Vector3.new(S[1], S[2] + 0.3, S[1]),
			CFrame.new(spot + Vector3.new(-gap, (S[2] + 0.3) / 2, 0)),
			rgb(M.SandColour),
			Enum.Material.Sand
		)
		table.insert(taken, { c = spot, half = Vector3.new(gap + S[1] / 2 + 1, 0, M.Slide[3] + 2) })
	end
	return taken
end

return YardKit
