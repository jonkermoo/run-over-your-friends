--!strict
-- Map layout, NPCs and destruction budgets. Studs and seconds.

return table.freeze({
	-- the world's look, "golden afternoon": a lower, warm late-afternoon sun for long readable shadows, cool
	-- blue shade so lit sides pop, a warm light haze, a punchier grade and a touch of sun rays. Colours are
	-- { r, g, b }. (Was "soft clean": 2 pm neutral light, grey shade, grade +0.08; it read flat and washed out.)
	Look = table.freeze({
		ClockTime = 16.4,
		Brightness = 3,
		Exposure = 0.15,
		Ambient = table.freeze({ 125, 125, 140 }), -- indoor / no-sky fill
		OutdoorAmbient = table.freeze({ 120, 130, 160 }), -- shade colour outdoors: cool, so sunlit sides stand out
		SunTint = table.freeze({ 255, 226, 190 }), -- the sun's colour on lit faces (Lighting.ColorShift_Top)
		ShadowSoftness = 0.25,
		DiffuseScale = 1, -- sky light on surfaces
		SpecularScale = 1, -- sky reflections on smooth parts (glass, paint)
		AirDensity = 0.24, -- a light haze gives the bigger map depth and softens where far ground stops loading
		AirOffset = 0.1,
		AirHaze = 1,
		AirGlare = 0.5,
		AirColor = table.freeze({ 235, 222, 205 }), -- warm near the sun
		AirDecay = table.freeze({ 175, 195, 230 }), -- blue away from it
		Saturation = 0.2,
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
