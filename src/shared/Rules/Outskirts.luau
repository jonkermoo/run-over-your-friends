--!strict
-- Where the outskirts go: the four zones round the highway ring, and clear spots on the flat grass around
-- them that touch no road or zone. Pure, so Lune tests it. `rng` returns a number in [0, 1).

local Outskirts = {}

export type Rect = { x: number, z: number, w: number, d: number } -- centre and size (w east-west, d north-south)
export type Zone = { Gap: number, Width: number, Depth: number }

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

-- up to `n` spots of radius `r` on the flat ground (within `half` of the middle, and where `allowed` says so):
-- clear of every rect by `margin`, and of each other; tries a fixed number of times, so a crowded map gets fewer
function Outskirts.clearSpots(
	half: number,
	exclude: { Rect },
	n: number,
	r: number,
	margin: number,
	rng: () -> number,
	allowed: ((x: number, z: number, r: number) -> boolean)?
): { { x: number, z: number } }
	local out: { { x: number, z: number } } = {}
	for _ = 1, n * 30 do
		if #out >= n then
			break
		end
		local x = (rng() * 2 - 1) * (half - r - margin)
		local z = (rng() * 2 - 1) * (half - r - margin)
		local ok = allowed == nil or allowed(x, z, r + margin)
		for _, e in if ok then exclude else {} do
			if Outskirts.distance(e, x, z) < r + margin then
				ok = false
				break
			end
		end
		if ok then
			for _, p in out do
				if (x - p.x) ^ 2 + (z - p.z) ^ 2 < (2 * r + margin) ^ 2 then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(out, { x = x, z = z })
		end
	end
	return out
end

return Outskirts
