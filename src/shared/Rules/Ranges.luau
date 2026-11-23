--!strict
-- The mountain ranges past the island's edge (Config/Country Edge.Ranges), pure so Lune tests them: the
-- ground's height at a spot, from how far past the edge it is (`v`) and how far along the edge (`u`), and which
-- band of the slope (grass, forest, rock, snow) a height falls in. Two ranges overlap: low forested foothills
-- near the edge, then tall rocky ridges with saddles behind them. The noise is passed in (math.noise in Roblox),
-- returning roughly -0.5..0.5.

local Ranges = {}

export type Noise = (x: number, y: number, z: number) -> number
export type Front = {
	from: number,
	rise: number,
	fade: { number },
	base: number,
	amp: number,
	scale: number,
}
export type Back = {
	rise: { number },
	fade: { number },
	base: number,
	amp: number,
	scale: number,
	bigScale: number,
	bigMin: number,
}
export type Bands = {
	grass: number,
	forest: number,
	rock: number,
	jitter: number,
	jitterScale: number,
	strata: number,
	strataY: number,
	grassJitter: number,
}
export type Config = {
	Seed: number,
	Front: Front,
	Back: Back,
	CoastClear: number,
	CoastFade: number,
	Bands: Bands,
}

-- 0 below a, 1 above b, a smooth S between
function Ranges.smooth(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- soft rolling noise, 0..1
local function rolling(noise: Noise, x: number, z: number, seed: number): number
	local a, f, sum, w = 1, 1, 0, 0
	for o = 1, 3 do
		sum += a * math.clamp(noise(x * f, z * f, seed + o * 3.1) + 0.5, 0, 1)
		w += a
		a *= 0.5
		f *= 2
	end
	return sum / w
end

-- ridged noise, 0..1: sharp crests where the noise crosses zero
local function ridged(noise: Noise, x: number, z: number, seed: number): number
	local a, f, sum, w = 1, 1, 0, 0
	for o = 1, 4 do
		local n = noise(x * f, z * f, seed + o * 7.3)
		sum += a * (1 - math.clamp(math.abs(n) * 2, 0, 1)) ^ 2
		w += a
		a *= 0.5
		f *= 2.1
	end
	return sum / w
end

-- the ranges' height `v` studs past the edge and `u` studs along it; `coast` is how far east of the west coast
-- the spot is (the ranges fade out before the sea)
function Ranges.height(cfg: Config, noise: Noise, v: number, u: number, coast: number): number
	local F, B = cfg.Front, cfg.Back
	if v < F.from then
		return 0
	end
	local keep = Ranges.smooth(cfg.CoastClear, cfg.CoastClear + cfg.CoastFade, coast)
	if keep <= 0 then
		return 0
	end
	local front = Ranges.smooth(F.from, F.rise, v) * (1 - Ranges.smooth(F.fade[1], F.fade[2], v))
	local hf = front * (F.base + F.amp * rolling(noise, u / F.scale, v / F.scale, cfg.Seed))
	local back = Ranges.smooth(B.rise[1], B.rise[2], v)
		* (1 - Ranges.smooth(B.fade[1], B.fade[2], v))
	local hb = 0
	if back > 0 then
		local big = B.bigMin + (1 - B.bigMin) * rolling(noise, u / B.bigScale, 0, cfg.Seed + 20)
		hb = back * (B.base + B.amp * ridged(noise, u / B.scale, v / B.scale, cfg.Seed + 40) * big)
	end
	return math.max(hf, hb) * keep
end

-- the tallest the ranges can be
function Ranges.peak(cfg: Config): number
	return math.max(cfg.Front.base + cfg.Front.amp, cfg.Back.base + cfg.Back.amp)
end

-- the band a voxel `y` studs up falls in at (x, z): "grass", "forest", "rock", "rock2" (a second rock, in
-- strata) or "snow"; the band edges wander by the noise so they don't run level
function Ranges.band(cfg: Config, noise: Noise, x: number, y: number, z: number): string
	local Bd = cfg.Bands
	local j = noise(x / Bd.jitterScale, z / Bd.jitterScale, cfg.Seed + 5) * Bd.jitter
	if y < Bd.grass + j * Bd.grassJitter then
		return "grass"
	elseif y < Bd.forest + j then
		return "forest"
	elseif y < Bd.rock + j then
		return if noise(x / Bd.strata, y / Bd.strataY, z / Bd.strata) > 0 then "rock2" else "rock"
	end
	return "snow"
end

return Ranges
