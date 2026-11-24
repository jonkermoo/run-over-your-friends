--!strict
-- The city map's sums (Config/CityMap): world spots to places on the picture and back, which way a dot's
-- arrow points, the server's compact update packing, sliding dots between updates, which dot a tap picks, and
-- zooming and moving the picture.
-- Pure Luau, no Roblox objects, so Lune tests it (tests/citymap).

local CityMap = {}

local WIDTH = 5 -- numbers a spot packs into

export type Cfg = { Centre: { number }, Span: number }
-- one player on the map: user id, world x and z, heading (degrees clockwise from north), and whether they're in
-- their car
export type Spot = { id: number, x: number, z: number, h: number, car: boolean }

-- a world spot (x, z) to the picture's 0..1 square (u right, v down), held on the picture's edge, and
-- whether it was inside
function CityMap.toMap(x: number, z: number, cfg: Cfg): (number, number, boolean)
	local u = (x - cfg.Centre[1]) / cfg.Span + 0.5
	local v = (z - cfg.Centre[2]) / cfg.Span + 0.5
	local inside = u >= 0 and u <= 1 and v >= 0 and v <= 1
	return math.clamp(u, 0, 1), math.clamp(v, 0, 1), inside
end

-- the other way: a place on the picture to the world spot under it
function CityMap.toWorld(u: number, v: number, cfg: Cfg): (number, number)
	return cfg.Centre[1] + (u - 0.5) * cfg.Span, cfg.Centre[2] + (v - 0.5) * cfg.Span
end

-- a facing (the look vector's x and z) as degrees clockwise from north (up on the map): what an up-pointing
-- arrow's Rotation must be
function CityMap.heading(lookX: number, lookZ: number): number
	if lookX == 0 and lookZ == 0 then
		return 0
	end
	return math.deg(math.atan2(lookX, -lookZ)) % 360
end

-- the shortest turn from one heading to another, in degrees (-180..180)
function CityMap.turn(from: number, to: number): number
	return (to - from + 180) % 360 - 180
end

-- part way (t: 0..1) from one heading to another, the short way round
function CityMap.blendHeading(from: number, to: number, t: number): number
	return (from + CityMap.turn(from, to) * math.clamp(t, 0, 1)) % 360
end

-- every spot in one flat list of whole numbers (id, x, z, h, car 1/0, id, x, z...), for the remote
function CityMap.pack(spots: { Spot }): { number }
	local out = table.create(#spots * WIDTH)
	for _, s in spots do
		table.insert(out, s.id)
		table.insert(out, math.round(s.x))
		table.insert(out, math.round(s.z))
		table.insert(out, math.round(s.h) % 360)
		table.insert(out, if s.car then 1 else 0)
	end
	return out
end

-- and back; a list that isn't whole spots of numbers gives nothing
function CityMap.unpack(flat: { any }): { Spot }
	local out = {}
	if typeof(flat) ~= "table" or #flat % WIDTH ~= 0 then
		return out
	end
	for i = 1, #flat, WIDTH do
		local id, x, z, h, car = flat[i], flat[i + 1], flat[i + 2], flat[i + 3], flat[i + 4]
		if
			typeof(id) ~= "number"
			or typeof(x) ~= "number"
			or typeof(z) ~= "number"
			or typeof(h) ~= "number"
			or typeof(car) ~= "number"
		then
			return {}
		end
		table.insert(out, { id = id, x = x, z = z, h = h, car = car == 1 })
	end
	return out
end

-- how far a sliding dot has got: `since` seconds after an update, taking `over` seconds in all (0..1)
function CityMap.slide(since: number, over: number): number
	if over <= 0 then
		return 1
	end
	return math.clamp(since / over, 0, 1)
end

-- the dot a tap at (px, py) picks: the closest one within `radius`, or nil. Dots are { x, y } in the same
-- pixels as the tap.
function CityMap.pick(
	dots: { { x: number, y: number } },
	px: number,
	py: number,
	radius: number
): number?
	local best, bestD = nil, radius * radius
	for i, d in dots do
		local dx, dy = d.x - px, d.y - py
		local dd = dx * dx + dy * dy
		if dd <= bestD then
			best, bestD = i, dd
		end
	end
	return best
end

-- zooming from z to z2 while the point `at` (window px from the window's edge) stays put: the canvas's new
-- offset along that axis (the canvas is z times the window's size, moved by `pan`)
function CityMap.zoomAbout(pan: number, at: number, z: number, z2: number): number
	return at - (at - pan) * z2 / z
end

-- the canvas's offset kept so it always covers the window (size px) at zoom z: between size - size * z and 0
function CityMap.clampPan(pan: number, z: number, size: number): number
	return math.clamp(pan, size - size * z, 0)
end

return CityMap
