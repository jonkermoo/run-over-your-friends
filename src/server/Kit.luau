--!strict
-- The town style's building blocks, shared by the house kit, the shop rows and the landmarks: wall rows with
-- real and framed windows, doorways and garage doors, plain side walls, plinth / cornice / corner trims,
-- gable and barn roofs, chimneys. Everything is anchored chunks, so BuildingService smashes and rebuilds it.
-- Positions are in the building's own frame: x to the right, y up, z toward the street; `m` = -1 mirrors x.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local B = require(ReplicatedStorage.Shared.Config.Buildings)
local H = require(ReplicatedStorage.Shared.Config.Houses)
local Rules = require(ReplicatedStorage.Shared.Rules.Buildings)

local Kit = {}

Kit.Y0 = 0.08 -- top of the block's sidewalk slab: floor level for everything on a block
Kit.GLASS = Color3.fromRGB(143, 195, 223)
Kit.STEP = Color3.fromRGB(190, 184, 172)

export type Ctx = {
	model: Model,
	base: CFrame, -- building frame: look = toward the street
	m: number, -- 1 or -1 (mirror)
	t: number, -- wall thickness
	wall: Color3,
	trim: Color3,
	accent: Color3,
	roof: Color3,
	material: Enum.Material,
}

local Y0, GLASS, STEP = Kit.Y0, Kit.GLASS, Kit.STEP

function Kit.rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- a building frame on the ground at `c`, facing the street along `out`
function Kit.context(
	model: Model,
	c: Vector3,
	out: Vector3,
	mirror: boolean,
	colours: { wall: Color3, trim: Color3, accent: Color3, roof: Color3 },
	material: Enum.Material,
	t: number
): Ctx
	return {
		model = model,
		base = CFrame.lookAt(Vector3.new(c.X, 0, c.Z), Vector3.new(c.X, 0, c.Z) + out),
		m = if mirror then -1 else 1,
		t = t,
		wall = colours.wall,
		trim = colours.trim,
		accent = colours.accent,
		roof = colours.roof,
		material = material,
	}
end

-- world position of building-frame point (x, y, z)
function Kit.at(ctx: Ctx, x: number, y: number, z: number): Vector3
	return (ctx.base * CFrame.new(x * ctx.m, y, -z)).Position
end

-- a part at building-frame position (x, y, z) with building-frame size; `rot` turns it about its own centre
function Kit.put(
	ctx: Ctx,
	size: Vector3,
	x: number,
	y: number,
	z: number,
	color: Color3,
	material: Enum.Material?,
	rot: CFrame?,
	noMirror: boolean?,
	wedge: boolean?
): BasePart
	local p: BasePart = if wedge then Instance.new("WedgePart") else Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = ctx.base
		* CFrame.new(if noMirror then x else x * ctx.m, y, -z)
		* (rot or CFrame.identity)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = ctx.model
	return p
end
local put = Kit.put

function Kit.wallPart(ctx: Ctx, size: Vector3, x: number, y: number, z: number): BasePart
	return put(ctx, size, x, y, z, ctx.wall, ctx.material)
end
local wallPart = Kit.wallPart

local function glassPane(
	ctx: Ctx,
	size: Vector3,
	x: number,
	y: number,
	z: number,
	transparency: number
)
	local g = put(ctx, size, x, y, z, GLASS, Enum.Material.Glass)
	g.Transparency = transparency
	g:SetAttribute("Glass", true)
	return g
end

-- sh shutters, fl flower box, can canopy over a door, bare a doorway with no door leaf (wide public doors,
-- so nothing stands in the way of people walking in)
export type Seg = {
	a: number,
	b: number,
	k: string,
	sh: boolean?,
	fl: boolean?,
	can: boolean?,
	bare: boolean?,
}
type SegOpts = { sh: boolean?, fl: boolean?, can: boolean?, bare: boolean? }

function Kit.seg(a: number, b: number, k: string, opts: SegOpts?): Seg
	local o = opts or {}
	return { a = a, b = b, k = k, sh = o.sh, fl = o.fl, can = o.can, bare = o.bare }
end

local function shutters(ctx: Ctx, mid: number, half: number, y: number, h: number, zOut: number)
	for _, e in { -1, 1 } do
		put(ctx, Vector3.new(1.6, h, 0.3), mid + e * (half + 1), y, zOut, ctx.accent)
	end
end

-- one storey of a front or back wall (`s` = 1 front, -1 back) made of segments along x:
-- "s" solid, "w" real window, "sw" big shop window, "p" framed glass on the wall, "d" doorway,
-- "g" garage door, "x" left open (a loading bay). Returns where the door and window ended up.
function Kit.row(
	ctx: Ctx,
	zFace: number,
	s: number,
	y0: number,
	h: number,
	segs: { Seg }
): { [string]: number }
	local T = ctx.t
	local zc = zFace - s * T / 2
	local found: { [string]: number } = {}
	for _, g in segs do
		local mid, len = (g.a + g.b) / 2, g.b - g.a
		if g.k == "s" then
			wallPart(ctx, Vector3.new(len, h, T), mid, y0 + h / 2, zc)
		elseif g.k == "w" then
			local gh = h - 6.5
			wallPart(ctx, Vector3.new(len, 3.5, T), mid, y0 + 1.75, zc)
			glassPane(ctx, Vector3.new(len, gh, T * 0.5), mid, y0 + 3.5 + gh / 2, zc, 0.3)
			wallPart(ctx, Vector3.new(len, 3, T), mid, y0 + h - 1.5, zc)
			put(ctx, Vector3.new(len + 1, 0.4, T + 1), mid, y0 + 3.3, zFace + s * 0.2, ctx.trim)
			put(
				ctx,
				Vector3.new(len + 0.6, 0.5, T + 0.5),
				mid,
				y0 + h - 2.75,
				zFace + s * 0.1,
				ctx.trim
			)
			if g.sh then
				shutters(ctx, mid, len / 2, y0 + 3.5 + gh / 2, gh, zFace + s * 0.15)
			end
			if g.fl then
				put(
					ctx,
					Vector3.new(len, 0.9, 1),
					mid,
					y0 + 2.6,
					zFace + s * 0.7,
					ctx.accent:Lerp(Color3.new(0, 0, 0), 0.25)
				)
				put(
					ctx,
					Vector3.new(len - 0.4, 0.5, 0.6),
					mid,
					y0 + 3.3,
					zFace + s * 0.7,
					Color3.fromRGB(255, 111, 145),
					Enum.Material.Grass
				)
			end
			found.window = mid
		elseif g.k == "sw" then
			-- a shop window: low base, tall glass, a header above, framed in trim
			local gh = h - 5.5
			wallPart(ctx, Vector3.new(len, 1.5, T), mid, y0 + 0.75, zc)
			glassPane(ctx, Vector3.new(len, gh, T * 0.5), mid, y0 + 1.5 + gh / 2, zc, 0.3)
			wallPart(ctx, Vector3.new(len, h - 1.5 - gh, T), mid, y0 + h - (h - 1.5 - gh) / 2, zc)
			put(
				ctx,
				Vector3.new(len + 0.6, 0.6, T + 0.6),
				mid,
				y0 + 1.5 + gh + 0.3,
				zFace + s * 0.15,
				ctx.trim
			)
			put(ctx, Vector3.new(len + 1.2, 0.4, T + 1), mid, y0 + 1.6, zFace + s * 0.2, ctx.trim)
			found.window = mid
		elseif g.k == "p" then
			wallPart(ctx, Vector3.new(len, h, T), mid, y0 + h / 2, zc)
			local ww, wh = math.min(len - 1.6, 5), h * 0.5
			local wy = y0 + h * 0.55
			put(ctx, Vector3.new(ww + 0.8, wh + 0.8, 0.16), mid, wy, zFace + s * 0.08, ctx.trim)
			local glass = put(
				ctx,
				Vector3.new(ww, wh, 0.22),
				mid,
				wy,
				zFace + s * 0.12,
				GLASS,
				Enum.Material.Glass
			)
			glass.Reflectance = 0.15
			put(
				ctx,
				Vector3.new(ww + 1.2, 0.35, 0.7),
				mid,
				wy - wh / 2 - 0.55,
				zFace + s * 0.35,
				ctx.trim
			)
			if g.sh then
				shutters(ctx, mid, ww / 2 + 0.4, wy, wh + 0.8, zFace + s * 0.15)
			end
			if g.fl then
				put(
					ctx,
					Vector3.new(ww, 0.8, 0.9),
					mid,
					wy - wh / 2 - 1.1,
					zFace + s * 0.6,
					ctx.accent:Lerp(Color3.new(0, 0, 0), 0.25)
				)
			end
		elseif g.k == "d" then
			wallPart(ctx, Vector3.new(len, h - 8.5, T), mid, y0 + 8.5 + (h - 8.5) / 2, zc)
			put(ctx, Vector3.new(len + 1, 0.6, T + 0.4), mid, y0 + 8.75, zFace + s * 0.2, ctx.trim)
			if not g.bare then
				-- the door stands open inside, hinged on its left
				put(
					ctx,
					Vector3.new(0.3, 8.2, len - 0.6),
					g.a + 0.25,
					y0 + 4.1,
					zFace - s * (T + (len - 0.6) / 2),
					ctx.accent
				)
			end
			put(
				ctx,
				Vector3.new(len + 2, 0.5, 2),
				mid,
				y0 + 0.25,
				zFace + s * 1,
				STEP,
				Enum.Material.Concrete
			)
			if g.can then
				put(ctx, Vector3.new(len + 3, 0.4, 3), mid, y0 + 9.5, zFace + s * 1.5, ctx.roof)
			end
			found.door = mid
		elseif g.k == "g" then
			wallPart(ctx, Vector3.new(len, h - 9, T), mid, y0 + 9 + (h - 9) / 2, zc)
			put(
				ctx,
				Vector3.new(len - 0.4, 9, 0.4),
				mid,
				y0 + 4.5,
				zFace - s * 0.4,
				Color3.fromRGB(233, 230, 223)
			)
			put(ctx, Vector3.new(len + 1, 0.6, T + 0.4), mid, y0 + 9.25, zFace + s * 0.2, ctx.trim)
			put(
				ctx,
				Vector3.new(len + 2, 0.3, 8),
				mid,
				y0 + 0.15,
				zFace + s * 4,
				STEP,
				Enum.Material.Concrete
			)
		end
	end
	return found
end

-- plain side walls (x = ±xHalf), in panels about 12 studs long; optional framed window on the middle panel
function Kit.sides(
	ctx: Ctx,
	xHalf: number,
	zFront: number,
	zBack: number,
	y0: number,
	h: number,
	window: boolean?
)
	local T = ctx.t
	local len = zFront - zBack - 2 * T
	local n = math.max(1, math.floor(len / 12 + 0.5))
	local pl = len / n
	for _, e in { -1, 1 } do
		local xc = e * (xHalf - T / 2)
		for k = 0, n - 1 do
			local zc = zBack + T + (k + 0.5) * pl
			wallPart(ctx, Vector3.new(T, h, pl), xc, y0 + h / 2, zc)
		end
		if window then
			local zc = (zFront + zBack) / 2
			local wy = y0 + h * 0.55
			put(ctx, Vector3.new(0.16, h * 0.5 + 0.8, 4.8), e * (xHalf + 0.08), wy, zc, ctx.trim)
			local glass = put(
				ctx,
				Vector3.new(0.22, h * 0.5, 4),
				e * (xHalf + 0.12),
				wy,
				zc,
				GLASS,
				Enum.Material.Glass
			)
			glass.Reflectance = 0.15
		end
	end
end

-- a horizontal band along x (centred at cx) or z (centred at cz), in pieces of at most B.BandPiece
function Kit.bandX(
	ctx: Ctx,
	cx: number,
	length: number,
	y: number,
	h: number,
	depth: number,
	z: number,
	color: Color3,
	material: Enum.Material?
)
	for _, sp in Rules.pieces(length, B.BandPiece) do
		put(
			ctx,
			Vector3.new(sp.to - sp.from, h, depth),
			cx + (sp.from + sp.to) / 2,
			y,
			z,
			color,
			material
		)
	end
end

function Kit.bandZ(
	ctx: Ctx,
	x: number,
	length: number,
	y: number,
	h: number,
	depth: number,
	cz: number,
	color: Color3,
	material: Enum.Material?
)
	for _, sp in Rules.pieces(length, B.BandPiece) do
		put(
			ctx,
			Vector3.new(depth, h, sp.to - sp.from),
			x,
			y,
			cz + (sp.from + sp.to) / 2,
			color,
			material
		)
	end
end

-- plinth band, cornice and corner trims round a box of half-width xHalf from zBack to zFront, height top
function Kit.trims(
	ctx: Ctx,
	cx: number,
	xHalf: number,
	zFront: number,
	zBack: number,
	top: number,
	pilasters: boolean
)
	local T = ctx.t
	local d = zFront - zBack
	local zm = (zFront + zBack) / 2
	local band = ctx.wall:Lerp(Color3.new(0, 0, 0), 0.35)
	-- the bands run from the middle of the wall outward, never into the room; the cornice stands a hair
	-- above the wall tops and the roof so their top faces don't flicker
	local plinth, cornice = T / 2 + 0.15, T / 2 + 0.25
	for _, z in { zFront, zBack } do
		local s = if z == zFront then 1 else -1
		Kit.bandX(
			ctx,
			cx,
			xHalf * 2 + 0.4,
			Y0 + H.Plinth / 2,
			H.Plinth,
			plinth,
			z - s * (T - plinth) / 2,
			band,
			ctx.material
		)
		Kit.bandX(
			ctx,
			cx,
			xHalf * 2 + 0.6,
			top - 0.35,
			0.8,
			cornice,
			z - s * (T - cornice) / 2,
			ctx.trim
		)
	end
	for _, e in { -1, 1 } do
		Kit.bandZ(
			ctx,
			cx + e * (xHalf - (T - plinth) / 2),
			d,
			Y0 + H.Plinth / 2,
			H.Plinth,
			plinth,
			zm,
			band,
			ctx.material
		)
		Kit.bandZ(
			ctx,
			cx + e * (xHalf - (T - cornice) / 2),
			d + 0.6,
			top - 0.35,
			0.8,
			cornice,
			zm,
			ctx.trim
		)
		if pilasters then
			-- corner posts, kept inside the wall's thickness on the room side
			for _, z in { zFront - 0.2, zBack + 0.2 } do
				local hgt = top - Y0 - H.Plinth - 0.8
				put(
					ctx,
					Vector3.new(0.8, hgt, 0.8),
					cx + e * (xHalf - 0.2),
					Y0 + H.Plinth + hgt / 2,
					z,
					ctx.trim
				)
			end
		end
	end
end

-- a gable roof over a box centred at cx (building frame), ridge along x ("side") or z ("front")
function Kit.gable(
	ctx: Ctx,
	cx: number,
	w: number,
	zFront: number,
	zBack: number,
	top: number,
	rise: number,
	ridge: string
)
	local o = H.Overhang
	local d = zFront - zBack
	local zm = (zFront + zBack) / 2
	local x0 = cx * ctx.m
	local function raw(size: Vector3, x: number, y: number, z: number, color: Color3, rot: CFrame?)
		put(
			ctx,
			size,
			x0 + x,
			y,
			zm + z,
			color,
			if color == ctx.wall then ctx.material else nil,
			rot,
			true,
			color == ctx.wall -- the wall-coloured pieces under a roof are the gable wedges
		)
	end
	if ridge == "side" then
		local half = d / 2
		local theta = math.atan(rise / half)
		local yE = top - o * math.tan(theta)
		local L = math.sqrt((half + o) ^ 2 + (top + rise - yE) ^ 2) + 0.4
		local yc = (yE + top + rise) / 2 + 0.4
		raw(
			Vector3.new(w + 2 * o, 0.8, L),
			0,
			yc,
			(half + o) / 2,
			ctx.roof,
			CFrame.Angles(-theta, 0, 0)
		)
		raw(
			Vector3.new(w + 2 * o, 0.8, L),
			0,
			yc,
			-(half + o) / 2,
			ctx.roof,
			CFrame.Angles(theta, 0, 0)
		)
		raw(Vector3.new(w, rise, half), 0, top + rise / 2, half / 2, ctx.wall, nil)
		raw(
			Vector3.new(w, rise, half),
			0,
			top + rise / 2,
			-half / 2,
			ctx.wall,
			CFrame.Angles(0, math.pi, 0)
		)
		raw(
			Vector3.new(w + 2 * o, 0.6, 1.4),
			0,
			top + rise + 0.75,
			0,
			ctx.roof:Lerp(Color3.new(0, 0, 0), 0.3)
		)
	else
		local half = w / 2
		local theta = math.atan(rise / half)
		local yE = top - o * math.tan(theta)
		local L = math.sqrt((half + o) ^ 2 + (top + rise - yE) ^ 2) + 0.4
		local yc = (yE + top + rise) / 2 + 0.4
		raw(
			Vector3.new(L, 0.8, d + 2 * o),
			(half + o) / 2,
			yc,
			0,
			ctx.roof,
			CFrame.Angles(0, 0, -theta)
		)
		raw(
			Vector3.new(L, 0.8, d + 2 * o),
			-(half + o) / 2,
			yc,
			0,
			ctx.roof,
			CFrame.Angles(0, 0, theta)
		)
		raw(
			Vector3.new(d, rise, half),
			half / 2,
			top + rise / 2,
			0,
			ctx.wall,
			CFrame.Angles(0, -math.pi / 2, 0)
		)
		raw(
			Vector3.new(d, rise, half),
			-half / 2,
			top + rise / 2,
			0,
			ctx.wall,
			CFrame.Angles(0, math.pi / 2, 0)
		)
		raw(
			Vector3.new(1.4, 0.6, d + 2 * o),
			0,
			top + rise + 0.75,
			0,
			ctx.roof:Lerp(Color3.new(0, 0, 0), 0.3)
		)
	end
end

-- a barn roof (two slopes each side) with its ridge running back from the street, over a box w wide:
-- the knee sits kx from the middle, `kneeRise` above the eaves; the ridge `peakRise` above them
function Kit.gambrel(
	ctx: Ctx,
	w: number,
	zFront: number,
	zBack: number,
	top: number,
	kneeShare: number,
	kneeRise: number,
	peakRise: number
)
	local o = H.Overhang
	local d = zFront - zBack
	local zm = (zFront + zBack) / 2
	local half = w / 2
	local kx = half * kneeShare
	local function raw(
		size: Vector3,
		x: number,
		y: number,
		color: Color3,
		rot: CFrame?,
		wedge: boolean?
	)
		put(ctx, size, x, y, zm, color, if wedge then ctx.material else nil, rot, true, wedge)
	end
	for _, e in { 1, -1 } do
		-- lower, steep slope from the eave to the knee
		local t1 = math.atan(kneeRise / (half - kx))
		local yE = top - o * math.tan(t1)
		local L1 = math.sqrt((half + o - kx) ^ 2 + (top + kneeRise - yE) ^ 2) + 0.4
		raw(
			Vector3.new(L1, 0.8, d + 2 * o),
			e * (half + o + kx) / 2,
			(yE + top + kneeRise) / 2 + 0.4,
			ctx.roof,
			CFrame.Angles(0, 0, -e * t1)
		)
		-- upper, shallow slope from the knee to the ridge
		local t2 = math.atan((peakRise - kneeRise) / kx)
		local L2 = math.sqrt(kx ^ 2 + (peakRise - kneeRise) ^ 2) + 0.6
		raw(
			Vector3.new(L2, 0.8, d + 2 * o),
			e * kx / 2,
			top + (kneeRise + peakRise) / 2 + 0.4,
			ctx.roof,
			CFrame.Angles(0, 0, -e * t2)
		)
		-- the gable infill under each slope (wedges through the whole depth)
		local turn = CFrame.Angles(0, -e * math.pi / 2, 0)
		raw(
			Vector3.new(d, kneeRise, half - kx),
			e * (kx + (half - kx) / 2),
			top + kneeRise / 2,
			ctx.wall,
			turn,
			true
		)
		raw(
			Vector3.new(d, peakRise - kneeRise, kx),
			e * kx / 2,
			top + kneeRise + (peakRise - kneeRise) / 2,
			ctx.wall,
			turn,
			true
		)
	end
	put(
		ctx,
		Vector3.new(kx * 2, kneeRise, d),
		0,
		top + kneeRise / 2,
		zm,
		ctx.wall,
		ctx.material,
		nil,
		true
	)
	raw(
		Vector3.new(1.4, 0.6, d + 2 * o),
		0,
		top + peakRise + 0.75,
		ctx.roof:Lerp(Color3.new(0, 0, 0), 0.3)
	)
end

function Kit.chimney(ctx: Ctx, x: number, z: number, top: number, height: number)
	put(
		ctx,
		Vector3.new(3, height, 3),
		x,
		top + height / 2,
		z,
		ctx.wall:Lerp(Color3.new(0, 0, 0), 0.45),
		ctx.material
	)
	put(ctx, Vector3.new(3.6, 0.6, 3.6), x, top + height + 0.3, z, ctx.trim)
end

return Kit
