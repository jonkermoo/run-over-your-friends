--!strict
-- Where the outskirts go: the four zones round the highway ring, and the terrain hills that fill the ground
-- around them without touching a road or a zone. Pure, so Lune tests it. `rng` returns a number in [0, 1).

local Outskirts = {}

export type Rect = { x: number, z: number, w: number, d: number } -- centre and size (w east-west, d north-south)
export type Hill = { x: number, z: number, r: number } -- a ball's centre on the ground plan and its radius
export type Zone = { Gap: number, Width: number, Depth: number }
export type HillConfig = {
	Spacing: number,
	Jitter: number,
	RadiusMin: number,
	RadiusMax: number,
	Bury: number,
	Margin: number,
}

-- the four zones, `ringOuter` studs from the middle to the ring's outer edge
function Outskirts.zones(
	ringOuter: number,
	stunt: Zone,
	port: Zone,
	desert: Zone,
	site: Zone
): { stunt: Rect, port: Rect, desert: Rect, site: Rect }
	return {
		stunt = {
			x = ringOuter + stunt.Gap + stunt.Width / 2,
			z = 0,
			w = stunt.Width,
			d = stunt.Depth,
		},
		port = {
			x = -(ringOuter + port.Gap + port.Width / 2),
			z = 0,
			w = port.Width,
			d = port.Depth,
		},
		desert = {
			x = 0,
			z = ringOuter + desert.Gap + desert.Depth / 2,
			w = desert.Width,
			d = desert.Depth,
		},
		site = {
			x = 0,
			z = -(ringOuter + site.Gap + site.Depth / 2),
			w = site.Width,
			d = site.Depth,
		},
	}
end

-- how far a point is from a rectangle (0 inside it)
function Outskirts.distance(r: Rect, x: number, z: number): number
	local dx = math.max(math.abs(x - r.x) - r.w / 2, 0)
	local dz = math.max(math.abs(z - r.z) - r.d / 2, 0)
	return math.sqrt(dx * dx + dz * dz)
end

function Outskirts.overlaps(a: Rect, b: Rect): boolean
	return math.abs(a.x - b.x) < (a.w + b.w) / 2 and math.abs(a.z - b.z) < (a.d + b.d) / 2
end

-- the radius of the circle a hill covers on the ground (its ball is buried `bury` of its radius)
function Outskirts.footprint(r: number, bury: number): number
	return r * math.sqrt(1 - bury * bury)
end

-- hills on a jittered grid over the ground (half-size `half`), clear of every rect by `Margin`; they grow
-- toward the map edge, and a hill near a road or zone shrinks to fit (or is left out when under RadiusMin)
function Outskirts.hills(
	half: number,
	exclude: { Rect },
	cfg: HillConfig,
	rng: () -> number
): { Hill }
	local out: { Hill } = {}
	local spread = math.sqrt(1 - cfg.Bury * cfg.Bury)
	local n = math.floor(half * 2 / cfg.Spacing)
	for i = 0, n do
		for j = 0, n do
			local x = -half + (i + 0.5) * cfg.Spacing + (rng() * 2 - 1) * cfg.Jitter
			local z = -half + (j + 0.5) * cfg.Spacing + (rng() * 2 - 1) * cfg.Jitter
			local roll = rng()
			if math.abs(x) < half and math.abs(z) < half then
				local room = math.huge
				for _, r in exclude do
					room = math.min(room, Outskirts.distance(r, x, z) - cfg.Margin)
				end
				local edge = math.max(math.abs(x), math.abs(z)) / half -- 0 middle, 1 edge
				local want = cfg.RadiusMin
					+ (cfg.RadiusMax - cfg.RadiusMin)
						* (0.35 + 0.65 * edge)
						* (0.7 + 0.3 * roll)
				local r = math.min(want, room / spread)
				if r >= cfg.RadiusMin then
					table.insert(out, { x = x, z = z, r = r })
				end
			end
		end
	end
	return out
end

return Outskirts
