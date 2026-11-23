--!strict
-- The world's look: light, sky, haze, grade, bloom and the buildings' window glass. Set by the server once
-- the map stands (server/LookService); in play each client's DayNight then eases the light through the day
-- (Config/DayNight, whose day look is this one). Kept out of the map build, so a look change never needs a
-- terrain bake. Colours are { r, g, b }.

return table.freeze({
	-- "golden afternoon" (user's pick, 2026-11-22): a low warm sun kept off noon (high latitude) for long
	-- readable shadows, lavender shade so lit sides pop, a peach horizon haze that softens the far city into
	-- depth, the painted cartoon sky with warm-lit clouds, more bloom on highlights and a touch of sun rays.
	-- Every value tunes effects the game already had: no new effects, no assets.
	-- (Was "bright noon": a near-white sun overhead most of the day, thin cool haze, flat shade.)
	Look = table.freeze({
		ClockTime = 15.2, -- start-up only; in play Config/DayNight drives the clock
		Latitude = 58, -- Lighting.GeographicLatitude: the sun never climbs past ~55 degrees
		Brightness = 3.2,
		Exposure = 0.12,
		Shadows = true, -- Lighting.GlobalShadows; phones on low quality skip shadows themselves
		Ambient = table.freeze({ 135, 120, 130 }), -- indoor / no-sky fill
		OutdoorAmbient = table.freeze({ 135, 130, 175 }), -- shade colour outdoors: lavender, so sunlit sides stand out
		SunTint = table.freeze({ 255, 200, 145 }), -- the sun's colour on lit faces (Lighting.ColorShift_Top)
		ShadowSoftness = 0.2,
		DiffuseScale = 1, -- sky light on surfaces
		SpecularScale = 0.8, -- sky reflections on smooth parts (glass, paint)
		AirDensity = 0.24, -- the haze gives the map depth and softens where far ground stops loading
		AirOffset = 0.15,
		AirHaze = 0.55,
		AirGlare = 0.5,
		AirColor = table.freeze({ 255, 210, 175 }), -- the horizon: warm peach
		AirDecay = table.freeze({ 190, 130, 150 }), -- rose distance away from the sun
		-- the painted sky (tools/sky/make_sky.py): image ids per face, and a big cartoon sun
		Sky = table.freeze({
			Ft = 124408530416332,
			Bk = 121619511943463,
			Lf = 105868860160466,
			Rt = 79382770347599,
			Up = 137876384618520,
			Dn = 84132017227560,
		}),
		SunSize = 16, -- Sky.SunAngularSize, degrees
		-- volumetric clouds (workspace.Terrain.Clouds); off on low quality
		CloudCover = 0.4,
		CloudDensity = 0.45,
		CloudColor = table.freeze({ 255, 228, 205 }),
		Saturation = 0.35,
		Contrast = 0.18,
		GradeBrightness = 0.02,
		Tint = table.freeze({ 255, 240, 225 }),
		BloomIntensity = 0.6,
		BloomSize = 28,
		BloomThreshold = 1.3,
		SunRays = 0.12, -- intensity of the rays round the sun
		SunRaysSpread = 0.5,
	}),
	-- the buildings' window glass (user's pick, 2026-11-22): soft sea-glass tints instead of saturated cobalt,
	-- one tint per building (by its name, Rules/Glass) so neighbours differ. Each pane keeps its own lightness,
	-- clamped; its hue and colour strength come from the tint. Colour only: no new parts.
	Glass = table.freeze({
		Tints = table.freeze({ -- { hue 0..1, most saturation }
			table.freeze({ 0.52, 0.28 }), -- sea glass
			table.freeze({ 0.47, 0.26 }), -- teal
			table.freeze({ 0.58, 0.24 }), -- steel blue
			table.freeze({ 0.08, 0.1 }), -- warm grey
			table.freeze({ 0.41, 0.18 }), -- mint
		}),
		ValueMin = 0.45, -- pane lightness (HSV value) kept inside this range
		ValueMax = 0.9,
		ValueGain = 1.02,
		MinTransparency = 0.15, -- solid panes become a little see-through, so rooms behind show
	}),
})
