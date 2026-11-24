--!strict
-- City map checks (Config/CityMap, Rules/CityMap), called from tests/run.

local Cfg = require("../src/shared/Config/CityMap")
local Net = require("../src/shared/Net")
local SettingsCfg = require("../src/shared/Config/Settings")
local Rules = require("../src/shared/Rules/CityMap")

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

return function(check: (string, boolean) -> ())
	check(
		"city map: square picture in whole tiles",
		Cfg.Span > 0
			and #Cfg.Tiles == Cfg.TileGrid * Cfg.TileGrid
			and Cfg.Pixels / Cfg.TileGrid <= 1024
	)
	check("city map: zoom range", Cfg.MinZoom == 1 and Cfg.MaxZoom > 1 and Cfg.ZoomStep > 1)
	check("city map: sends about once a second", Cfg.SendEvery >= 0.5 and Cfg.SendEvery <= 2)
	check(
		"city map: dots slide in under one update",
		Cfg.Smooth > 0 and Cfg.Smooth <= Cfg.SendEvery
	)
	check(
		"city map: remotes named in Net",
		Net.Messages.MapOpen ~= nil and Net.Messages.MapDots ~= nil
	)

	check(
		"city map: its gamepad key isn't the Settings panel's",
		Cfg.PadKey == "" or Cfg.PadKey ~= SettingsCfg.PadKey
	)

	-- the picture's middle is the Centre, its corners Span / 2 away
	local cx, cz = Cfg.Centre[1], Cfg.Centre[2]
	local u, v, inside = Rules.toMap(cx, cz, Cfg)
	check("city map: centre in the middle", near(u, 0.5) and near(v, 0.5) and inside)
	u, v = Rules.toMap(cx - Cfg.Span / 2, cz - Cfg.Span / 2, Cfg)
	check("city map: north-west corner top left", near(u, 0) and near(v, 0))
	u, v = Rules.toMap(cx + Cfg.Span / 4, cz, Cfg)
	check("city map: east is right", near(u, 0.75) and near(v, 0.5))
	u, v = Rules.toMap(cx, cz + Cfg.Span / 4, Cfg)
	check("city map: south (+z) is down", near(u, 0.5) and near(v, 0.75))
	u, v, inside = Rules.toMap(cx + Cfg.Span * 3, cz - Cfg.Span * 3, Cfg)
	check("city map: far spots held on the edge", near(u, 1) and near(v, 0) and not inside)
	local mu, mv = Rules.toMap(cx + 123, cz - 456, Cfg)
	local x, z = Rules.toWorld(mu, mv, Cfg)
	check("city map: there and back", near(x, cx + 123) and near(z, cz - 456))

	-- a test frame of our own, so the sums don't hang on the real numbers
	local test = { Centre = { 100, -200 }, Span = 1000 }
	u, v = Rules.toMap(350, 50, test)
	check("city map: offset centre", near(u, 0.75) and near(v, 0.75))

	check("heading: north is 0", near(Rules.heading(0, -1), 0))
	check("heading: east is 90", near(Rules.heading(1, 0), 90))
	check("heading: south is 180", near(Rules.heading(0, 1), 180))
	check("heading: west is 270", near(Rules.heading(-1, 0), 270))
	check("heading: straight up or down is 0", Rules.heading(0, 0) == 0)
	check(
		"turn: the short way round",
		near(Rules.turn(350, 10), 20) and near(Rules.turn(10, 350), -20)
	)
	check("blend: across north", near(Rules.blendHeading(350, 10, 0.5), 0))
	check("blend: done at 1", near(Rules.blendHeading(30, 120, 1), 120))

	local spots = {
		{ id = 7, x = 10.4, z = -20.6, h = 359.7, car = true },
		{ id = -1, x = 0, z = 5, h = 90, car = false },
	}
	local flat = Rules.pack(spots)
	check("pack: five numbers a spot", #flat == 10)
	local back = Rules.unpack(flat)
	check(
		"pack: round trip in whole studs and degrees",
		#back == 2
			and back[1].id == 7
			and back[1].x == 10
			and back[1].z == -21
			and back[1].h == 0
			and back[2].id == -1
			and back[2].h == 90
			and back[1].car == true
			and back[2].car == false
	)
	check(
		"unpack: bad lists give nothing",
		#Rules.unpack({ 1, 2, 3 }) == 0 and #Rules.unpack({ 1, 2, "x", 4, 0 }) == 0
	)

	check("slide: halfway", near(Rules.slide(0.4, 0.8), 0.5))
	check("slide: done and held", Rules.slide(5, 0.8) == 1 and Rules.slide(0, 0) == 1)

	local dots = { { x = 0, y = 0 }, { x = 20, y = 0 }, { x = 100, y = 100 } }
	check("pick: closest dot", Rules.pick(dots, 14, 0, 30) == 2)
	check("pick: nothing out of reach", Rules.pick(dots, 60, 50, 30) == nil)

	-- zooming keeps the point under the cursor still, and the canvas always covers the window
	local S = 400
	local pan = Rules.zoomAbout(0, 100, 1, 2) -- zoom in about x = 100
	check(
		"zoom: point under the cursor stays",
		near(pan, -100) and near((100 - pan) / (S * 2), 100 / S)
	)
	check("zoom: back out to where it was", near(Rules.zoomAbout(pan, 100, 2, 1), 0))
	check("pan: can't leave a gap on the left", Rules.clampPan(30, 2, S) == 0)
	check("pan: can't leave a gap on the right", Rules.clampPan(-900, 2, S) == -400)
	check("pan: none at zoom 1", Rules.clampPan(-50, 1, S) == 0)

	-- key places sit on the picture
	local placesOk = #Cfg.Places >= 2
	for _, p in Cfg.Places do
		local _, _, inPicture = Rules.toMap(p.x, p.z, Cfg)
		placesOk = placesOk and inPicture and p.name ~= ""
	end
	check("city map: key places on the picture", placesOk)
end
