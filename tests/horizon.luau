--!strict
-- The horizon's checks: mountain ranges (Rules/Ranges, Config/Country Edge.Ranges) and the sea's boats and
-- lighthouse beam (Rules/Sea, Config/Sea), called from tests/run.

local Country = require("../src/shared/Config/Country")
local LandConfig = require("../src/shared/Config/Land")
local SeaConfig = require("../src/shared/Config/Sea")

return function(check: (string, boolean) -> ())
	local Ranges = require("../src/shared/Rules/Ranges")
	local Sea = require("../src/shared/Rules/Sea")
	local R = Country.Edge.Ranges

	-- a stand-in for math.noise: smooth, -0.5..0.5, steady
	local function noise(x: number, y: number, z: number): number
		return 0.5 * math.sin(x * 1.3 + z * 0.7) * math.cos(y * 0.9 + x * 0.4)
	end
	local function zero(_x: number, _y: number, _z: number): number
		return 0
	end

	check(
		"ranges: flat inside the edge and before they start",
		Ranges.height(R, noise, -50, 0, 5000) == 0
	)
	check("ranges: flat before Front.from", Ranges.height(R, noise, R.Front.from - 1, 0, 5000) == 0)
	check(
		"ranges: flat past the back range's end",
		Ranges.height(R, noise, R.Back.fade[2] + 10, 0, 5000) == 0
	)
	check("ranges: flat at the west coast", Ranges.height(R, noise, 600, 0, R.CoastClear) == 0)
	local tallest, inBounds = 0, true
	for v = 0, R.Back.fade[2] + 100, 20 do
		for u = 0, 6000, 137 do
			local h = Ranges.height(R, noise, v, u, 5000)
			tallest = math.max(tallest, h)
			inBounds = inBounds and h >= 0 and h <= Ranges.peak(R)
		end
	end
	check("ranges: heights stay between 0 and the peak", inBounds)
	check(
		"ranges: the back range rises well above the foothills",
		tallest > R.Front.base + R.Front.amp
	)
	check(
		"ranges: the ranges end before the ground under them does (Land Overrun)",
		R.Back.fade[2] <= LandConfig.Overrun
	)
	check(
		"ranges: half way to the coast fade is lower than far from it",
		Ranges.height(R, zero, 900, 0, R.CoastClear + R.CoastFade / 2)
			< Ranges.height(R, zero, 900, 0, R.CoastClear + R.CoastFade + 10)
	)
	local Bd = R.Bands
	check(
		"ranges: bands climb grass, forest, rock, snow",
		Ranges.band(R, zero, 0, 0, 0) == "grass"
			and Ranges.band(R, zero, 0, (Bd.grass + Bd.forest) / 2, 0) == "forest"
			and Ranges.band(R, zero, 0, (Bd.forest + Bd.rock) / 2, 0) == "rock"
			and Ranges.band(R, zero, 0, Bd.rock + 10, 0) == "snow"
	)
	local mats = true
	for _, band in { "grass", "forest", "rock", "rock2", "snow" } do
		mats = mats and type((R.Materials :: any)[band]) == "string"
	end
	check("ranges: every band has a terrain material", mats)
	check(
		"ranges: pines stay in the forest band",
		Country.Edge.PineMaxHeight < Bd.forest - Bd.jitter / 2
	)

	-- boats
	local b = SeaConfig.Boats[1]
	local x0, z0 = Sea.boatAt(b, 0)
	local x1, z1 = Sea.boatAt(b, b.lap)
	check(
		"sea: a boat is back where it started after one lap",
		math.abs(x0 - x1) < 1e-6 and math.abs(z0 - z1) < 1e-6
	)
	local onLoop = true
	for t = 0, 300, 7 do
		local x, z, hx, hz = Sea.boatAt(b, t)
		local e = (x / b.across) ^ 2 + (z / b.along) ^ 2
		onLoop = onLoop and math.abs(e - 1) < 1e-6 and math.abs(hx * hx + hz * hz - 1) < 1e-6
	end
	check("sea: boats stay on their loop and head along it", onLoop)
	-- heading points the way it moves: a step later is ahead along the heading
	local ahead = true
	for _, boat in SeaConfig.Boats do
		local x, z, hx, hz = Sea.boatAt(boat, 10)
		local nx, nz = Sea.boatAt(boat, 10.5)
		ahead = ahead and (nx - x) * hx + (nz - z) * hz > 0
	end
	check("sea: every boat heads the way it moves, either way round", ahead)
	local inside = true
	for _, boat in SeaConfig.Boats do
		-- out to sea by up to off + across; inside the walls, and clear of the moored ship by the quay
		inside = inside
			and boat.off + boat.across < LandConfig.SeaReach
			and boat.off - boat.across > 100
	end
	check("sea: boat loops stay inside the walls and off the quay", inside)

	-- the beam
	local Bm = SeaConfig.Beam
	check("sea: the beam is off at noon", Sea.beam(12, Bm.on, Bm.off, Bm.fade) == 0)
	check("sea: the beam is on at midnight", Sea.beam(0, Bm.on, Bm.off, Bm.fade) == 1)
	check("sea: the beam is on just after `on`", Sea.beam(Bm.on + 0.1, Bm.on, Bm.off, Bm.fade) == 1)
	local half = Sea.beam(Bm.on - Bm.fade / 2, Bm.on, Bm.off, Bm.fade)
	check("sea: the beam fades in before `on`", half > 0.4 and half < 0.6)
	local out = Sea.beam(Bm.off + Bm.fade / 2, Bm.on, Bm.off, Bm.fade)
	check("sea: the beam fades out after `off`", out > 0.4 and out < 0.6)
end
