--!strict
-- The house kit: four house types built from anchored chunks in the town style (plinth band, cornice,
-- corner trims, framed windows with sills, overhanging roofs, an accent front door with a step).
-- A bungalow, B family house, C corner house with a garage wing, D townhouse. Ground-floor front windows
-- are real openings (you can see who's home); the rest are framed glass on the wall. Each house returns a
-- Place for the crowd (door, entry and spots inside). Positions are in the house's own frame:
-- x to the right, y up, z toward the street; `mirror` flips x.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local H = require(ReplicatedStorage.Shared.Config.Houses)
local Places = require(script.Parent.Places)

local HouseKit = {}

local Y0 = 0.08
local GLASS = Color3.fromRGB(143, 195, 223)
local STEP = Color3.fromRGB(190, 184, 172)

type Ctx = {
	model: Model,
	base: CFrame, -- house frame: look = toward the street
	m: number, -- 1 or -1 (mirror)
	wall: Color3,
	trim: Color3,
	accent: Color3,
	roof: Color3,
	material: Enum.Material,
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- a part at house-frame position (x, y, z) with house-frame size; `rot` turns it about its own centre
local function put(
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

local function wallPart(ctx: Ctx, size: Vector3, x: number, y: number, z: number): BasePart
	return put(ctx, size, x, y, z, ctx.wall, ctx.material)
end

export type Seg = { a: number, b: number, k: string, sh: boolean?, fl: boolean?, can: boolean? }

local function seg(
	a: number,
	b: number,
	k: string,
	opts: { sh: boolean?, fl: boolean?, can: boolean? }?
): Seg
	local o = opts or {}
	return { a = a, b = b, k = k, sh = o.sh, fl = o.fl, can = o.can }
end

local function shutters(ctx: Ctx, mid: number, half: number, y: number, h: number, zOut: number)
	for _, e in { -1, 1 } do
		put(ctx, Vector3.new(1.6, h, 0.3), mid + e * (half + 1), y, zOut, ctx.accent)
	end
end

-- one storey of a front or back wall (`s` = 1 front, -1 back) made of segments along x:
-- "s" solid, "w" real window, "p" framed glass on the wall, "d" doorway, "g" garage door
local function row(
	ctx: Ctx,
	zFace: number,
	s: number,
	y0: number,
	h: number,
	segs: { Seg }
): { [string]: number }
	local T = H.Wall
	local zc = zFace - s * T / 2
	local found: { [string]: number } = {}
	for _, g in segs do
		local mid, len = (g.a + g.b) / 2, g.b - g.a
		if g.k == "s" then
			wallPart(ctx, Vector3.new(len, h, T), mid, y0 + h / 2, zc)
		elseif g.k == "w" then
			local gh = h - 6.5
			wallPart(ctx, Vector3.new(len, 3.5, T), mid, y0 + 1.75, zc)
			local glass = put(
				ctx,
				Vector3.new(len, gh, T * 0.5),
				mid,
				y0 + 3.5 + gh / 2,
				zc,
				GLASS,
				Enum.Material.Glass
			)
			glass.Transparency = 0.3
			glass:SetAttribute("Glass", true)
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
			put(ctx, Vector3.new(len + 1, 0.6, T + 0.4), mid, y0 + 8.8, zFace + s * 0.2, ctx.trim)
			-- the door stands open inside, hinged on its left
			put(
				ctx,
				Vector3.new(0.3, 8.2, len - 0.6),
				g.a + 0.25,
				y0 + 4.1,
				zFace - s * (T + (len - 0.6) / 2),
				ctx.accent
			)
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
			put(ctx, Vector3.new(len + 1, 0.6, T + 0.4), mid, y0 + 9.3, zFace + s * 0.2, ctx.trim)
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

-- plain side walls (x = ±xFace), in panels about 12 studs long; optional framed window on the middle panel
local function sides(
	ctx: Ctx,
	xHalf: number,
	zFront: number,
	zBack: number,
	y0: number,
	h: number,
	window: boolean?
)
	local T = H.Wall
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

-- plinth band, cornice and corner trims round a box of half-width xHalf from zBack to zFront, height top
local function trims(
	ctx: Ctx,
	cx: number,
	xHalf: number,
	zFront: number,
	zBack: number,
	top: number,
	pilasters: boolean
)
	local d = zFront - zBack
	local zm = (zFront + zBack) / 2
	local band = ctx.wall:Lerp(Color3.new(0, 0, 0), 0.35)
	for _, z in { zFront, zBack } do
		local s = if z == zFront then 1 else -1
		put(
			ctx,
			Vector3.new(xHalf * 2 + 0.4, H.Plinth, H.Wall + 0.3),
			cx,
			Y0 + H.Plinth / 2,
			z - s * H.Wall / 2,
			band,
			ctx.material
		)
		put(
			ctx,
			Vector3.new(xHalf * 2 + 0.6, 0.8, H.Wall + 0.5),
			cx,
			top - 0.4,
			z - s * H.Wall / 2,
			ctx.trim
		)
	end
	for _, e in { -1, 1 } do
		put(
			ctx,
			Vector3.new(H.Wall + 0.3, H.Plinth, d),
			cx + e * (xHalf - H.Wall / 2),
			Y0 + H.Plinth / 2,
			zm,
			band,
			ctx.material
		)
		put(
			ctx,
			Vector3.new(H.Wall + 0.5, 0.8, d + 0.6),
			cx + e * (xHalf - H.Wall / 2),
			top - 0.4,
			zm,
			ctx.trim
		)
		if pilasters then
			for _, z in { zFront - 0.4, zBack + 0.4 } do
				local hgt = top - Y0 - H.Plinth - 0.8
				put(
					ctx,
					Vector3.new(1.2, hgt, 1.2),
					cx + e * (xHalf - 0.4),
					Y0 + H.Plinth + hgt / 2,
					z,
					ctx.trim
				)
			end
		end
	end
end

-- a gable roof over a box centred at cx (house frame), ridge along x ("side") or z ("front")
local function gable(
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

local function chimney(ctx: Ctx, x: number, z: number, top: number, height: number)
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

local function interior(ctx: Ctx, cx: number, w: number, zFront: number, zBack: number)
	local T = H.Wall
	put(
		ctx,
		Vector3.new(w - 2 * T, 0.3, zFront - zBack - 2 * T),
		cx,
		Y0 + 0.15,
		(zFront + zBack) / 2,
		Color3.fromRGB(150, 110, 74),
		Enum.Material.WoodPlanks
	)
	put(
		ctx,
		Vector3.new(8, 3, 3.5),
		cx + w / 5,
		Y0 + 1.5,
		zBack + T + 2.2,
		ctx.wall:Lerp(Color3.fromRGB(60, 60, 70), 0.6),
		Enum.Material.Fabric
	)
end

local BUILD: { [string]: (Ctx) -> { door: number, front: number, back: number, living: Vector3 } } =
	{}

-- A: bungalow, front gable, porch and chimney
BUILD.A = function(ctx)
	local w, d, fh = H.Types.A.width, H.Types.A.depth, H.FloorHeight
	local zf, zb = d / 2, -d / 2
	local top = Y0 + fh
	local found = row(ctx, zf, 1, Y0, fh, {
		seg(-15, -11, "s"),
		seg(-11, -5, "w", { sh = true, fl = true }),
		seg(-5, -2.5, "s"),
		seg(-2.5, 2.5, "d"),
		seg(2.5, 5, "s"),
		seg(5, 11, "w", { sh = true, fl = true }),
		seg(11, 15, "s"),
	})
	row(ctx, zb, -1, Y0, fh, { seg(-15, -6, "s"), seg(-6, 0, "p"), seg(0, 15, "s") })
	sides(ctx, w / 2, zf, zb, Y0, fh, false)
	trims(ctx, 0, w / 2, zf, zb, top, true)
	gable(ctx, 0, w, zf, zb, top, 9, "front")
	chimney(ctx, 9, -6, top + 3, 9)
	-- porch: floor, two posts, a roof
	put(ctx, Vector3.new(12, 0.6, 5), 0, Y0 + 0.3, zf + 2.5, STEP, Enum.Material.WoodPlanks)
	for _, e in { -5.3, 5.3 } do
		put(ctx, Vector3.new(0.8, 9.6, 0.8), e, Y0 + 4.8, zf + 4.4, ctx.trim)
	end
	put(ctx, Vector3.new(13.5, 0.5, 6), 0, Y0 + 9.85, zf + 2.6, ctx.roof)
	interior(ctx, 0, w, zf, zb)
	return { door = found.door, front = zf, back = zb, living = Vector3.new(-8, 0, zf - 5) }
end

-- B: family house, two storeys, side gable
BUILD.B = function(ctx)
	local w, d, fh = H.Types.B.width, H.Types.B.depth, H.FloorHeight
	local zf, zb = d / 2, -d / 2
	local top = Y0 + 2 * fh
	local found = row(ctx, zf, 1, Y0, fh, {
		seg(-17, -13, "s"),
		seg(-13, -7, "w", { fl = true }),
		seg(-7, -2.5, "s"),
		seg(-2.5, 2.5, "d", { can = true }),
		seg(2.5, 7, "s"),
		seg(7, 13, "w", { fl = true }),
		seg(13, 17, "s"),
	})
	row(ctx, zf, 1, Y0 + fh, fh, {
		seg(-17, -7.5, "p", { sh = true }),
		seg(-7.5, 7.5, "p"),
		seg(7.5, 17, "p", { sh = true }),
	})
	row(ctx, zb, -1, Y0, fh, { seg(-17, -5, "s"), seg(-5, 1, "p"), seg(1, 17, "s") })
	row(ctx, zb, -1, Y0 + fh, fh, { seg(-17, 0, "p"), seg(0, 17, "p") })
	sides(ctx, w / 2, zf, zb, Y0, fh, false)
	sides(ctx, w / 2, zf, zb, Y0 + fh, fh, true)
	put(
		ctx,
		Vector3.new(w - 2 * H.Wall, 0.8, d - 2 * H.Wall),
		0,
		Y0 + fh,
		0,
		Color3.fromRGB(200, 196, 188)
	)
	put(ctx, Vector3.new(w + 0.6, 0.5, H.Wall + 0.4), 0, Y0 + fh, zf - H.Wall / 2, ctx.trim)
	trims(ctx, 0, w / 2, zf, zb, top, true)
	gable(ctx, 0, w, zf, zb, top, 8, "side")
	chimney(ctx, 13, -3, top + 2, 9)
	interior(ctx, 0, w, zf, zb)
	return { door = found.door, front = zf, back = zb, living = Vector3.new(-10, 0, zf - 5) }
end

-- C: corner house, a two-storey front gable and a one-storey garage wing on the right
BUILD.C = function(ctx)
	local d, fh = H.Types.C.depth, H.FloorHeight
	local mw, gw = 22, 16
	local mx, gx = -H.Types.C.width / 2 + mw / 2, H.Types.C.width / 2 - gw / 2
	local zf, zb = d / 2, -d / 2
	local top = Y0 + 2 * fh
	-- the main block, in its own frame shifted to mx
	local main = table.clone(ctx)
	main.base = ctx.base * CFrame.new(mx * ctx.m, 0, 0)
	local found = row(main, zf, 1, Y0, fh, {
		seg(-11, -7.5, "s"),
		seg(-7.5, -2.5, "w", { fl = true }),
		seg(-2.5, 0.5, "s"),
		seg(0.5, 5.5, "d", { can = true }),
		seg(5.5, 11, "s"),
	})
	row(
		main,
		zf,
		1,
		Y0 + fh,
		fh,
		{ seg(-11, -3.5, "s"), seg(-3.5, 3.5, "p", { sh = true }), seg(3.5, 11, "s") }
	)
	row(main, zb, -1, Y0, fh, { seg(-11, 0, "p"), seg(0, 11, "s") })
	row(main, zb, -1, Y0 + fh, fh, { seg(-11, 11, "p") })
	sides(main, mw / 2, zf, zb, Y0, 2 * fh, false)
	put(
		main,
		Vector3.new(mw - 2 * H.Wall, 0.8, d - 2 * H.Wall),
		0,
		Y0 + fh,
		0,
		Color3.fromRGB(200, 196, 188)
	)
	trims(main, 0, mw / 2, zf, zb, top, true)
	gable(main, 0, mw, zf, zb, top, 8, "front")
	interior(main, 0, mw, zf, zb)
	-- the garage wing, set back a little
	local wing = table.clone(ctx)
	wing.base = ctx.base * CFrame.new(gx * ctx.m, 0, 0)
	local gzf, gzb, gh = zf - 3, zb + 1, 11
	row(wing, gzf, 1, Y0, gh, { seg(-8, -7, "s"), seg(-7, 7, "g"), seg(7, 8, "s") })
	row(wing, gzb, -1, Y0, gh, { seg(-8, 8, "s") })
	sides(wing, gw / 2, gzf, gzb, Y0, gh, false)
	trims(wing, 0, gw / 2, gzf, gzb, Y0 + gh, false)
	gable(wing, 0, gw, gzf, gzb, Y0 + gh, 4, "side")
	return { door = mx + found.door, front = zf, back = zb, living = Vector3.new(mx - 5, 0, zf - 5) }
end

-- D: townhouse, three storeys, flat roof with a deep cornice, a bay window and a stoop
BUILD.D = function(ctx)
	local w, d, fh = H.Types.D.width, H.Types.D.depth, H.FloorHeight
	local zf, zb = d / 2, -d / 2
	local top = Y0 + 3 * fh
	local found = row(ctx, zf, 1, Y0, fh, {
		seg(-8, -7.5, "s"),
		seg(-7.5, 0.5, "w"),
		seg(0.5, 2, "s"),
		seg(2, 7, "d"),
		seg(7, 8, "s"),
	})
	-- the bay in front of the ground-floor window
	put(
		ctx,
		Vector3.new(8.4, 3.4, 2.6),
		-3.5,
		Y0 + 1.7,
		zf + 1.3,
		ctx.wall:Lerp(Color3.new(0, 0, 0), 0.2),
		ctx.material
	)
	local bay =
		put(ctx, Vector3.new(8, 5.6, 2.4), -3.5, Y0 + 6.2, zf + 1.2, GLASS, Enum.Material.Glass)
	bay.Transparency = 0.35
	bay:SetAttribute("Glass", true)
	put(ctx, Vector3.new(9, 0.6, 3.2), -3.5, Y0 + 9.3, zf + 1.4, ctx.roof)
	for f = 1, 2 do
		row(ctx, zf, 1, Y0 + f * fh, fh, {
			seg(-8, -6.5, "s"),
			seg(-6.5, -1.5, "p", { fl = f == 1 }),
			seg(-1.5, 1.5, "s"),
			seg(1.5, 6.5, "p", { fl = f == 1 }),
			seg(6.5, 8, "s"),
		})
		put(ctx, Vector3.new(w + 0.6, 0.6, H.Wall + 0.5), 0, Y0 + f * fh, zf - H.Wall / 2, ctx.trim)
	end
	for f = 0, 2 do
		row(ctx, zb, -1, Y0 + f * fh, fh, { seg(-8, 0, "s"), seg(0, 8, "p") })
	end
	sides(ctx, w / 2, zf, zb, Y0, 3 * fh, false)
	trims(ctx, 0, w / 2, zf, zb, top, false)
	-- flat roof, deep cornice and parapet
	put(ctx, Vector3.new(w, 0.8, d), 0, top - 0.4, 0, ctx.roof)
	put(ctx, Vector3.new(w + 0.8, 1.2, 2.2), 0, top + 0.2, zf - 0.6, ctx.trim)
	put(
		ctx,
		Vector3.new(w + 0.4, 1.6, H.Wall),
		0,
		top + 1.6,
		zf - H.Wall / 2,
		ctx.wall:Lerp(Color3.new(0, 0, 0), 0.3),
		ctx.material
	)
	-- stoop
	put(ctx, Vector3.new(6, 0.8, 3), found.door, Y0 + 0.4, zf + 1.5, STEP, Enum.Material.Concrete)
	put(
		ctx,
		Vector3.new(6, 0.5, 1.6),
		found.door,
		Y0 + 1.05,
		zf + 0.8,
		STEP,
		Enum.Material.Concrete
	)
	interior(ctx, 0, w, zf, zb)
	return { door = found.door, front = zf, back = zb, living = Vector3.new(-3.5, 0, zf - 4) }
end

-- build a house of `kind` at c (ground), facing the street along `out`; returns its Place
function HouseKit.build(
	parent: Instance,
	kind: string,
	c: Vector3,
	out: Vector3,
	palette: H.Palette,
	mirror: boolean,
	name: string
): Places.Place
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("HouseType", kind)
	local base = CFrame.lookAt(Vector3.new(c.X, 0, c.Z), Vector3.new(c.X, 0, c.Z) + out)
	local ctx: Ctx = {
		model = model,
		base = base,
		m = if mirror then -1 else 1,
		wall = rgb(palette.wall),
		trim = rgb(palette.trim),
		accent = rgb(palette.accent),
		roof = rgb(palette.roof),
		material = (Enum.Material :: any)[palette.material] or Enum.Material.SmoothPlastic,
	}
	local info = BUILD[kind](ctx)
	model.Parent = parent
	local function at(x: number, z: number): Vector3
		return (base * CFrame.new(x * ctx.m, Y0, -z)).Position
	end
	local doorX = info.door
	return {
		kind = "home",
		name = name,
		door = at(doorX, info.front + 3),
		entry = at(doorX, info.front - 3),
		spots = {
			{ path = { at(info.living.X, info.living.Z) }, face = out },
			{ path = { at(doorX, info.front - 6), at(0, info.back + 6) }, face = -out },
		},
		staffSpots = {},
		indoors = true,
	}
end

return HouseKit
