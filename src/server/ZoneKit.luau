--!strict
-- Dressing for the zones outside the city (Config/Zones), laid once the ground is finished (after the roll,
-- before the greenery): the port's quay, the stunt park's barriers, the farmhouse and tractors, and the beaches'
-- huts, loungers and volleyball net. Things a car can knock flying are props; huts, the gatehouse and the
-- farmhouse are smashable buildings. Everything draws from its own random stream.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Zones)
local Country = require(ReplicatedStorage.Shared.Config.Country)
local Houses = require(ReplicatedStorage.Shared.Config.Houses)
local Greenery = require(script.Parent.Greenery)
local HouseKit = require(script.Parent.HouseKit)
local YardKit = require(script.Parent.YardKit)
local Places = require(script.Parent.Places)
local Terra = require(script.Parent.Terra)

local ZoneKit = {}

export type Rect = { x: number, z: number, w: number, d: number }
export type Beach = { x0: number, zc: number, len: number, taken: { Vector3 }, seed: number }
export type Ctx = {
	static: Instance,
	buildings: Instance,
	props: Instance,
	port: Rect,
	stunt: Rect,
	seaEdge: number,
	connector: number, -- the roads into the port and the stunt park, wide
	yard: Vector3, -- the farm yard's middle
	beaches: { Beach },
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
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

local function prop(folder: Instance, kind: string): Model
	local m = Instance.new("Model")
	m.Name = kind
	m:SetAttribute("Prop", kind)
	m.Parent = folder
	return m
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- a scenery mesh that collides and can be hit (Greenery.place makes them ghosts)
local function solid(m: MeshPart): MeshPart
	m.CanCollide = true
	m.CanQuery = true
	m.CanTouch = true
	return m
end

-- the terrain's top under (x, z), or 0 where there is none
local onlyTerrain = RaycastParams.new()
onlyTerrain.FilterType = Enum.RaycastFilterType.Include
onlyTerrain.FilterDescendantsInstances = { workspace.Terrain }
local function ground(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), onlyTerrain)
	return if hit then hit.Position.Y else 0
end

-- the top of the port's and the stunt park's slabs (OutskirtsKit)
local SLAB = 0.08

local function port(ctx: Ctx)
	local P = Cfg.Port
	local pt, qx = ctx.port, ctx.seaEdge
	local folder = model(ctx.static, "PortDressing")
	local z0 = pt.z - pt.d / 2
	for k = 0, P.Bollards - 1 do
		local b = Greenery.place(
			folder,
			"Bollard",
			Vector3.new(qx + P.BollardIn, SLAB, z0 + (k + 0.5) * pt.d / P.Bollards),
			nil,
			2.6,
			0,
			rgb(P.BollardColour)
		)
		b.Material = Enum.Material.Metal
		solid(b)
	end
	-- lifebuoys on boards, halfway between bollards, facing the yard
	for k = 0, P.Buoys - 1 do
		local z = z0 + (k + 0.5) * pt.d / P.Buoys + pt.d / P.Bollards / 2
		local m = prop(ctx.props, "Lifebuoy")
		local at = Vector3.new(qx + P.BuoyIn, SLAB, z)
		part(
			m,
			Vector3.new(0.4, 4.4, 3.2),
			CFrame.new(at + Vector3.new(0, 2.2, 0)),
			rgb(P.BoardColour)
		)
		local ring = Greenery.place(
			m,
			"Lifebuoy",
			at + Vector3.new(0.45, 1, 0),
			nil,
			2.4,
			math.pi / 2,
			rgb(P.BuoyColour)
		)
		solid(ring)
	end
	-- floodlight masts down the landward side, lamps facing the quay
	local mx = pt.x + pt.w / 2 - P.MastIn
	for k = 0, P.Masts - 1 do
		local z = z0 + (k + 0.5) * pt.d / P.Masts
		local foot = Vector3.new(mx, SLAB, z)
		local mast = part(
			folder,
			Vector3.new(P.MastHeight, 1.6, 1.6),
			CFrame.new(foot + Vector3.new(0, P.MastHeight / 2, 0))
				* CFrame.Angles(0, 0, math.pi / 2),
			rgb(P.MastColour),
			Enum.Material.Metal
		)
		mast.Shape = Enum.PartType.Cylinder
		part(
			folder,
			Vector3.new(P.MastHead[1], P.MastHead[2], P.MastHead[3]),
			CFrame.new(foot + Vector3.new(-P.HeadOut, P.MastHeight + P.HeadUp, 0)),
			rgb(P.MastColour),
			Enum.Material.Metal
		)
		local lamp = part(
			folder,
			Vector3.new(P.LampSize[1], P.LampSize[2], P.LampSize[3]),
			CFrame.new(foot + Vector3.new(-P.LampOut, P.MastHeight + P.HeadUp, 0)),
			rgb(P.Lamp),
			Enum.Material.Neon
		)
		lamp.CastShadow = false
	end
	-- the gatehouse on the road's south side, its boom raised over the road
	local G = P.Gate
	local w, h, d = G.Booth[1], G.Booth[2], G.Booth[3]
	local gate = model(ctx.buildings, "Gatehouse")
	local at = Vector3.new(pt.x + pt.w / 2 - G.In, SLAB, pt.z + ctx.connector / 2 + G.Off + d / 2)
	local cf = CFrame.lookAt(at, at - Vector3.zAxis) -- the window band faces the road
	part(
		gate,
		Vector3.new(w, h, d),
		cf * CFrame.new(0, h / 2, 0),
		rgb(G.Wall),
		Enum.Material.Concrete
	)
	local glass = part(
		gate,
		Vector3.new(w + 0.2, 2.6, d + 0.2),
		cf * CFrame.new(0, h * 0.62, 0),
		rgb(G.Glass),
		Enum.Material.Glass
	)
	glass.Transparency = 0.3
	glass:SetAttribute("Glass", true)
	part(gate, Vector3.new(w + 1.6, 0.8, d + 1.6), cf * CFrame.new(0, h + 0.4, 0), rgb(G.Band))
	local post = G.Post -- the boom's post: across, tall; beside the booth, out toward the road
	local px, pz = w / 2 + G.PostOff[1], -d / 2 - G.PostOff[2]
	part(
		gate,
		Vector3.new(post[1], post[2], post[1]),
		cf * CFrame.new(px, post[2] / 2, pz),
		rgb(G.Wall)
	)
	local pivot = cf * CFrame.new(px, post[2], pz)
	part(
		gate,
		Vector3.new(0.6, 0.6, G.Boom),
		pivot * CFrame.Angles(G.BoomUp, 0, 0) * CFrame.new(0, 0, -G.Boom / 2),
		rgb(G.BoomColour)
	)
end

local function stunt(ctx: Ctx)
	local S = Cfg.Stunt
	local st = ctx.stunt
	local hw, hd = st.w / 2, st.d / 2
	-- the terrain under the park is dirt, so the mounds' skirts read as dirt on the asphalt, not grass
	Terra.terrain:ReplaceMaterial(
		-- in from the edge by S.DirtIn, so the grid snap stays inside the park
		Region3.new(
			Vector3.new(st.x - hw + S.DirtIn, -20, st.z - hd + S.DirtIn),
			Vector3.new(st.x + hw - S.DirtIn, 40, st.z + hd - S.DirtIn)
		):ExpandToGrid(4),
		4,
		Enum.Material.Grass,
		Enum.Material.Ground
	)
	local colours = { rgb(S.BarrierColours[1]), rgb(S.BarrierColours[2]) }
	local n = 0
	-- one side of the edge: from a to b (corners in), skipping the gate's opening
	local function side(a: Vector3, b: Vector3, skip: (Vector3) -> boolean)
		local len = (b - a).Magnitude
		local along = (b - a).Unit
		for k = 0, math.floor(len / S.Barrier) - 1 do
			local at = a + along * ((k + 0.5) * S.Barrier)
			if not skip(at) then
				n += 1
				local m = prop(ctx.props, "Barrier")
				local bar =
					Greenery.place(m, "Barrier", at, nil, S.BarrierHeight, 0, colours[n % 2 + 1])
				bar.Size = Vector3.new(S.Barrier - S.BarrierGap, bar.Size.Y, bar.Size.Z)
				bar.CFrame =
					CFrame.fromMatrix(at + Vector3.new(0, bar.Size.Y / 2, 0), along, Vector3.yAxis)
				bar.Material = Enum.Material.Concrete
				solid(bar)
			end
		end
	end
	local i = S.BarrierIn
	local function p(x: number, z: number): Vector3
		return Vector3.new(st.x + x, SLAB, st.z + z)
	end
	local function never(_: Vector3): boolean
		return false
	end
	side(p(-hw + i, -hd + i), p(hw - i, -hd + i), never)
	side(p(-hw + i, hd - i), p(hw - i, hd - i), never)
	side(p(hw - i, -hd + i), p(hw - i, hd - i), never)
	side(p(-hw + i, -hd + i), p(-hw + i, hd - i), function(at: Vector3): boolean
		return math.abs(at.Z - st.z) < ctx.connector / 2 + S.GateGap
	end)
end

local function farm(ctx: Ctx): Places.Place
	local F = Cfg.Farm
	local yard = ctx.yard
	local c = yard + Vector3.new(F.House[1], 0, F.House[2])
	c = Vector3.new(c.X, ground(c.X, c.Z), c.Z)
	local face = -Vector3.xAxis
	local T = (Houses.Types :: any)[F.HouseType] :: Houses.HouseType
	local place = HouseKit.build(
		ctx.buildings,
		F.HouseType,
		c,
		face,
		Houses.Palettes[F.Palette],
		false,
		"Farmhouse"
	)
	local right = Vector3.new(-face.Z, 0, face.X)
	local door = (place.door - c):Dot(right)
	local drive = T.width / 2 - F.DriveIn
	YardKit.front(ctx.props, {
		c = c,
		face = face,
		width = T.width,
		depth = T.depth,
		lawn = F.Lawn,
		door = door,
		drive = drive,
		driveWidth = F.Drive,
		car = false,
		gaps = {
			{ door - F.Path / 2, door + F.Path / 2 },
			{ drive - F.Drive / 2, drive + F.Drive / 2 },
		},
		wallGaps = {},
		clear = function(_: Vector3): boolean
			return true
		end,
	})
	for _, t in F.Tractors do
		local at = yard + Vector3.new(t[1], 0, t[2])
		at = Vector3.new(at.X, ground(at.X, at.Z), at.Z)
		local m = prop(ctx.props, "Tractor")
		for _, piece in { { "Tractor", F.TractorBody }, { "TractorWheels", F.TractorWheels } } do
			local mesh = Greenery.place(
				m,
				piece[1] :: string,
				at,
				nil,
				8.6,
				t[3],
				rgb(piece[2] :: { number })
			)
			mesh.Material = Enum.Material.SmoothPlastic
			solid(mesh)
		end
	end
	return place
end

local function beach(ctx: Ctx, b: Beach)
	local B = Cfg.Beach
	local W = Country.Beach.Width
	local own = Random.new(B.Seed + b.seed)
	local function on(x: number, z: number): Vector3
		return Vector3.new(x, ground(x, z), z)
	end
	-- the huts, in a row facing the sea
	local w, h, d = B.Hut[1], B.Hut[2], B.Hut[3]
	local hx = b.x0 + W * B.HutAt
	local z0 = b.zc + b.len * B.HutFrom
	local function free(x: number, z: number, pad: number): boolean
		for _, t in b.taken do
			if Vector2.new(t.X - x, t.Z - z).Magnitude < pad then
				return false
			end
		end
		return true
	end
	local huts: { Vector3 } = {}
	for k = 0, B.Huts - 1 do
		local z = z0 + k * B.HutGap
		if not free(hx, z, B.HutClear) then
			continue
		end
		local at = on(hx, z)
		table.insert(huts, at)
		local hut = model(ctx.buildings, "BeachHut")
		local cf = CFrame.lookAt(at, at - Vector3.xAxis) -- door to the sea
		part(
			hut,
			Vector3.new(w, h, d),
			cf * CFrame.new(0, h / 2, 0),
			rgb(B.HutColours[k % #B.HutColours + 1]),
			Enum.Material.WoodPlanks
		)
		for _, sx in { -1, 1 } do
			part(
				hut,
				Vector3.new(d + 1, B.HutRoof, w / 2 + 0.6),
				cf
					* CFrame.new(sx * (w / 4 + 0.3), h + B.HutRoof / 2, 0)
					* CFrame.Angles(0, -sx * math.pi / 2, 0),
				rgb(B.HutRoofColour),
				Enum.Material.WoodPlanks,
				"WedgePart"
			)
		end
		part(
			hut,
			Vector3.new(w * 0.4, h * 0.75, 0.3),
			cf * CFrame.new(0, h * 0.375, -d / 2 - 0.15),
			rgb(B.HutDoor)
		)
	end
	for _, at in huts do
		table.insert(b.taken, at)
	end
	-- umbrellas with two loungers under each
	local placed = 0
	for _ = 1, B.Sets * B.SetTries do
		if placed >= B.Sets then
			break
		end
		local x = b.x0 + own:NextNumber(B.SetFrom, W * B.SetTo)
		local z = b.zc + own:NextNumber(-b.len / 2 + B.SetEnd, b.len / 2 - B.SetEnd)
		if free(x, z, B.SetClear) then
			placed += 1
			local at = on(x, z)
			table.insert(b.taken, at)
			local U = B.Umbrella
			local m = prop(ctx.props, "Umbrella")
			local pole = part(
				m,
				Vector3.new(U[1], 0.5, 0.5),
				CFrame.new(at + Vector3.new(0, U[1] / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.new(1, 1, 1)
			)
			pole.Shape = Enum.PartType.Cylinder
			local top = part(
				m,
				Vector3.new(1, U[2], U[2]),
				CFrame.new(at + Vector3.new(0, U[1] - 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				rgb(B.Loungers[own:NextInteger(1, #B.Loungers)])
			)
			top.Shape = Enum.PartType.Cylinder
			local colour = rgb(B.Loungers[own:NextInteger(1, #B.Loungers)])
			local turn = own:NextNumber(-B.LoungerTurn, B.LoungerTurn) -- heads inland, feet to the sea
			for _, s in { -B.LoungerApart, B.LoungerApart } do
				local l = prop(ctx.props, "Lounger")
				local spot = on(x + B.LoungerIn, z + s)
				solid(Greenery.place(l, "Lounger", spot, B.LoungerLength, nil, turn, colour))
			end
		end
	end
	-- a volleyball net: two posts and the net between them
	local N = B.Net
	local nx, nz = b.x0 + W * B.NetAt, b.zc + b.len * B.NetAlong
	if not free(nx, nz, N[1] / 2 + B.SetClear / 2) then
		return
	end
	local nc = on(nx, nz)
	local net = prop(ctx.props, "Net")
	for _, s in { -1, 1 } do
		local foot = on(nc.X + s * N[1] / 2, nc.Z)
		part(
			net,
			Vector3.new(0.5, N[2], 0.5),
			CFrame.new(foot + Vector3.new(0, N[2] / 2, 0)),
			rgb(B.NetColour)
		)
	end
	local mesh = part(
		net,
		Vector3.new(N[1], N[3], 0.15),
		CFrame.new(nc + Vector3.new(0, N[2] - N[3] / 2, 0)),
		rgb(B.NetColour),
		Enum.Material.Fabric
	)
	mesh.Transparency = 0.35
	table.insert(b.taken, nc)
end

-- everything; returns the farmhouse's place (for the crowd)
function ZoneKit.build(ctx: Ctx): { Places.Place }
	-- a terrain ray in the same frame as the roll's writes still sees the old ground: let it settle first
	task.wait()
	port(ctx)
	stunt(ctx)
	local places = { farm(ctx) }
	for _, b in ctx.beaches do
		beach(ctx, b)
	end
	return places
end

return ZoneKit
