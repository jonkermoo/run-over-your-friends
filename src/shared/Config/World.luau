--!strict
-- Map layout, NPCs and destruction budgets. Studs and seconds.

return table.freeze({
	-- the world's look, "soft clean": early-afternoon neutral daylight, soft bright shadows, clear air,
	-- true colours (a light grade) and bloom only on the brightest spots. Colours are { r, g, b }.
	Look = table.freeze({
		ClockTime = 14,
		Brightness = 2.6,
		Exposure = 0.1,
		Ambient = table.freeze({ 125, 125, 135 }), -- indoor / no-sky fill
		OutdoorAmbient = table.freeze({ 165, 165, 175 }), -- shade colour outdoors
		ShadowSoftness = 0.6,
		DiffuseScale = 1, -- sky light on surfaces
		SpecularScale = 1, -- sky reflections on smooth parts (glass, paint)
		AirDensity = 0.28, -- a light haze gives the bigger map depth and softens where far ground stops loading
		AirOffset = 0.1,
		AirHaze = 0.8,
		AirGlare = 0.2,
		AirColor = table.freeze({ 215, 230, 245 }),
		AirDecay = table.freeze({ 190, 210, 235 }),
		Saturation = 0.08,
		Contrast = 0.04,
		GradeBrightness = 0.02,
		Tint = table.freeze({ 255, 255, 255 }),
		BloomIntensity = 0.3,
		BloomSize = 24,
		BloomThreshold = 1.8,
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
