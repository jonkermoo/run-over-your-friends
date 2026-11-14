--!strict
-- Map layout, NPCs and destruction budgets. Studs and seconds.

return table.freeze({
	-- the world's look, "golden afternoon": a lower, warm late-afternoon sun for long readable shadows, cool
	-- blue shade so lit sides pop, a painted cartoon sky with real clouds, a light blue haze that keeps the
	-- distance clear, a punchier grade and a touch of sun rays. Colours are { r, g, b }.
	-- (Was: no sky, no clouds, shadows off and a milky haze (Haze 1), Exposure +0.15 blew white concrete out.)
	Look = table.freeze({
		ClockTime = 16.4,
		Brightness = 3,
		Exposure = 0,
		Shadows = true, -- Lighting.GlobalShadows; phones on low quality skip shadows themselves
		Ambient = table.freeze({ 125, 125, 140 }), -- indoor / no-sky fill
		OutdoorAmbient = table.freeze({ 120, 130, 160 }), -- shade colour outdoors: cool, so sunlit sides stand out
		SunTint = table.freeze({ 255, 226, 190 }), -- the sun's colour on lit faces (Lighting.ColorShift_Top)
		ShadowSoftness = 0.25,
		DiffuseScale = 1, -- sky light on surfaces
		SpecularScale = 1, -- sky reflections on smooth parts (glass, paint)
		AirDensity = 0.18, -- a light haze gives the bigger map depth and softens where far ground stops loading
		AirOffset = 0.1,
		AirHaze = 0.4,
		AirGlare = 0.2,
		AirColor = table.freeze({ 225, 232, 240 }), -- the horizon: close to the sky's pale band
		AirDecay = table.freeze({ 110, 165, 225 }), -- blue distance away from the sun
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
		CloudColor = table.freeze({ 255, 255, 255 }),
		Saturation = 0.25,
		Contrast = 0.12,
		GradeBrightness = 0.01,
		Tint = table.freeze({ 255, 249, 240 }),
		BloomIntensity = 0.35,
		BloomSize = 24,
		BloomThreshold = 1.6,
		SunRays = 0.06, -- intensity of the rays round the sun
		SunRaysSpread = 0.6,
		PaintLift = 0.03, -- plaza paint sits this far above the paving
	}),
	-- subtle built-in materials on the buildings' plain plastic (the "quiet" look): light walls get soft
	-- plaster, mid tones and flat roofs concrete, dark upright trim brushed metal. Small parts, dark floors and
	-- see-through parts stay plastic.
	-- Only materials change, so the map's part count doesn't. Lightness is the mean of r, g, b (0..1).
	Surfaces = table.freeze({
		MinSize = 4, -- studs: the part's longest side must reach this
		Light = "Plaster",
		LightFrom = 0.7,
		Mid = "Concrete",
		MidFrom = 0.3,
		Dark = "Metal", -- upright dark parts only (flat dark ones, like floor tiles, stay plastic)
		Roof = "Concrete", -- flat, wide, thin parts
		RoofThickness = 1.6,
		RoofWidth = 8,
	}),
	-- far stand-ins (SkylineKit): one box per building of these kinds, round its walls (parts at least MinPart
	-- long), shrunk by Inset so it never shows through the real thing
	Skyline = table.freeze({
		Kinds = table.freeze({
			"Home",
			"SuburbHome",
			"Shop",
			"Office",
			"Restaurant",
			"Warehouse",
			"Cabin",
			"Barn",
			"Silo",
		}),
		MinPart = 3,
		Inset = 0.6,
	}),
	-- the spawn plaza's dressing (MapBuilder dressSpawnPlaza): paving bands, the trophy, planters, stalls, flags
	SpawnPlaza = table.freeze({
		SeedOffset = 77, -- its own random stream (trees), so the town's layout doesn't shift
		Band = { 186, 92, 66 }, -- terracotta paving: the ring round the fountain and the border
		Ring = 64, -- inside the spawn pads' inner corners (about 35 out)
		Border = 6,
		Gold = { 255, 196, 48 },
		Stone = { 224, 214, 196 },
		Planters = table.freeze({ { 82, 82 }, { 56, 88 }, { 88, 56 } }), -- x, z out from the middle, each corner
		StallReach = 72, -- the food stalls stand on the diagonals this far out
		Stalls = table.freeze({
			table.freeze({ text = "HOT DOGS", colour = { 232, 60, 60 } }),
			table.freeze({ text = "ICE CREAM", colour = { 236, 90, 160 } }),
			table.freeze({ text = "TACOS", colour = { 255, 180, 0 } }),
			table.freeze({ text = "DONUTS", colour = { 60, 140, 230 } }),
		}),
		PoleHeight = 26,
		Banners = table.freeze({
			{ 255, 208, 0 },
			{ 236, 72, 150 },
			{ 50, 130, 240 },
			{ 120, 210, 60 },
		}), -- UI colours
	}),
	-- no decoration grass in the city grid (and CityMargin past its outer sidewalk) or under flat ground parts
	-- elsewhere (MapBuilder): parts whose bottom is at most MaxBottom and top at most MaxTop, at least MinSize
	-- across, get Asphalt terrain (grass-tinted, no blades) under them
	GrassUnder = table.freeze({
		MaxBottom = 0.2,
		MaxTop = 1.5,
		MinSize = 4,
		Batch = 300,
		CityMargin = 8,
	}),
	Map = table.freeze({
		GroundSize = 6000,
		BlockSize = 220, -- city block, kerb to kerb
		RoadWidth = 64, -- wide enough for the semi and the fire truck
		BlocksX = 8,
		BlocksZ = 8,
		FloorHeight = 14,
		PanelWidth = 12,
		WallThickness = 1.5,
		SidewalkWidth = 8, -- narrow, so the buildings stand close to the road
		SidewalkHeight = 0.6,
		Seed = 20261030,
	}),
	Npc = table.freeze({
		Count = 45,
		CountPhone = 30, -- not used yet: NPCs are server-side, so every client sees the same crowd
		WalkSpeed = 9,
		RespawnSeconds = 7,
		FriendNameRange = 45, -- nameplates show within this many studs
		TaxiRange = 90,
		JingleRange = 120,
		JingleEvery = 0.8, -- while the jingle is on, people in JingleRange head for the truck this often...
		JingleGap = 2.5, -- ...and stand this far outside its outline
		CannonRange = 70,
		CannonCone = 0.8, -- dot product with the aim
		CannonSend = 0.2, -- seconds between aim updates sent while spraying
		CannonUp = 0.6, -- the aim's height (unit vector y) is held between these
		CannonDown = -0.75, -- steep enough to hit people right beside the truck
	}),
	Debris = table.freeze({
		RebuildSeconds = 75,
		ChunkFallReach = 0.7, -- share of the break radius that also drops the floors above
	}),
})
