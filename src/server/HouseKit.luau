--!strict
-- The house kit: four house types built from anchored chunks in the town style (plinth band, cornice,
-- corner trims, framed windows with sills, overhanging roofs, an accent front door with a step).
-- A bungalow, B family house, C corner house with a garage wing, D townhouse. Ground-floor front windows
-- are real openings (you can see who's home); the rest are framed glass on the wall. Each house returns a
-- Place for the crowd (door, entry and spots inside). Positions are in the house's own frame:
-- x to the right, y up, z toward the street; `mirror` flips x.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local H = require(ReplicatedStorage.Shared.Config.Houses)
local Interiors = require(ReplicatedStorage.Shared.Config.Interiors)
local Kit = require(script.Parent.Kit)
local Places = require(script.Parent.Places)

local HouseKit = {}

local Y0 = Kit.Y0
local GLASS = Kit.GLASS
local STEP = Kit.STEP

type Ctx = Kit.Ctx

local put, row, seg, sides, trims, gable, chimney =
	Kit.put, Kit.row, Kit.seg, Kit.sides, Kit.trims, Kit.gable, Kit.chimney

-- the wooden floor; furniture is drawn by each client near the camera (Config/Interiors)
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
	local ctx = Kit.context(model, c, out, mirror, {
		wall = Kit.rgb(palette.wall),
		trim = Kit.rgb(palette.trim),
		accent = Kit.rgb(palette.accent),
		roof = Kit.rgb(palette.roof),
	}, (Enum.Material :: any)[palette.material] or Enum.Material.SmoothPlastic, H.Wall)
	local base = ctx.base
	local info = BUILD[kind](ctx)
	-- the client furnishes the house from its frame, type and mirror flag
	model.WorldPivot = base
	model:SetAttribute("Mirror", mirror)
	model.Parent = parent
	local function at(x: number, z: number): Vector3
		return (base * CFrame.new(x * ctx.m, Y0, -z)).Position
	end
	local function facing(fx: number, fz: number): Vector3
		return base:VectorToWorldSpace(Vector3.new(fx * ctx.m, 0, -fz))
	end
	local doorX = info.door
	local spots: { Places.Spot } = {}
	local layout = (Interiors.Layouts :: any)[kind] :: Interiors.Layout?
	if layout then
		for _, sp in layout.spots do
			-- step in past the door first, then across the room
			table.insert(spots, {
				path = { at(doorX, info.front - 5), at(sp.x, sp.z) },
				face = facing(sp.fx, sp.fz),
				sit = sp.sit,
			})
		end
	end
	return {
		kind = "home",
		name = name,
		door = at(doorX, info.front + 3),
		entry = at(doorX, info.front - 3),
		spots = spots,
		staffSpots = {},
		indoors = true,
	}
end

return HouseKit
