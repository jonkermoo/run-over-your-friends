--!strict
-- Map layout, NPCs and destruction budgets. Studs and seconds.

return table.freeze({
	-- the world's look (light, sky, haze, grade, glass) lives in Config/Look, outside the map build, so a look
	-- change never needs a terrain bake. Only what the map's build reads stays here.
	Look = table.freeze({
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
		-- a gabled house's stand-in is a wall box with a roof in the house's roof colour: one part turned 45
		-- degrees about the ridge, its top half the gable, as wide as the house and as tall as the house's ridge;
		-- the walls stay at least RoofMinWall tall (the ridge rises above the real one if it must)
		RoofMinWall = 7,
	}),
	-- the spawn plaza (MapBuilder spawnPlaza, dressSpawnPlaza): a roundabout hub. A grass island in the middle
	-- holds the champions' podium (Config/Champions: a slowly turning stage); the spawn
	-- pads stand in a ring round it, each facing out onto a painted one-way ring road with four exits to the
	-- streets; the crowd waits at the four corners by the food stalls. All distances in studs from the middle.
	SpawnPlaza = table.freeze({
		SeedOffset = 77, -- its own random stream (trees), so the town's layout doesn't shift
		Band = { 186, 92, 66 }, -- terracotta paving: the island's kerb and the plaza's border
		Border = 6,
		Gold = { 255, 196, 48 },
		Stone = { 224, 214, 196 },
		Island = 24, -- grass island radius
		Kerb = 3, -- terracotta kerb round it
		IslandTop = 0.3, -- near flush: a flat car collider stops dead on a 0.5 kerb
		Pads = 12,
		PadRadius = 44, -- pad centres, between the island and the ring road
		PadSize = 10,
		PadAngle = 15, -- degrees: the first pad's angle, so no pad sits on an exit's line
		RingInner = 58, -- the ring road's asphalt
		RingOuter = 78,
		RingDashes = 24, -- yellow dashes along its middle
		RingArrows = 8, -- white one-way arrows (anticlockwise seen from above)
		ExitWidth = 28, -- asphalt from the ring out to each side street
		-- the champions' podium on the island: a round turntable with three steps in a row on it (left, middle,
		-- right as Config/Champions.Steps) (nothing else on it). Colours are { r, g, b }.
		Podium = table.freeze({
			Keys = table.freeze({ "Earned", "HitsAll", "Hits" }), -- the steps' boards, as Config/Champions.Steps
			Radius = 19, -- the turntable
			Rise = 0.8, -- its top above the island
			StepWidth = 11,
			StepDepth = 9,
			Heights = table.freeze({ 6, 9, 6 }),
			LipOut = 0.15, -- the white cap on each step sticks out this far past its sides
			LipRaise = 0.04, -- and sits this far above its top (the avatars stand on the cap)
			Colours = table.freeze({
				table.freeze({ 43, 220, 90 }), -- money green
				table.freeze({ 255, 196, 48 }), -- gold
				table.freeze({ 232, 52, 52 }), -- red
			}),
			WallHeight = 34, -- the invisible wall round the turning steps, up past the avatars' heads
			WallRadius = 18.5, -- covers the circle the steps sweep (tests/champions)
		}),
		Corner = table.freeze({ reach = 92, spread = 11, people = 6 }), -- the crowd at each corner
		Planters = table.freeze({ { 56, 88 }, { 88, 56 } }), -- x, z out from the middle, each corner
		StallReach = 106, -- the food stalls stand on the diagonals this far out
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
	-- elsewhere (MapBuilder): parts whose bottom is at most MaxBottom and top at most MaxTop get Asphalt terrain
	-- (grass-tinted, no blades) under their own footprint
	GrassUnder = table.freeze({
		MaxBottom = 0.2,
		MaxTop = 1.5,
		Grow = 1, -- a voxel column is cleared when its middle is this close to a part's footprint
		CityMargin = 8,
	}),
	-- the map build at a server's start (server/Pace): it yields a frame once this many seconds of work have gone by
	Build = table.freeze({
		YieldEvery = 0.1,
	}),
	Map = table.freeze({
		GroundSize = 6000,
		BlockSize = 220, -- city block, kerb to kerb
		RoadWidth = 64, -- wide enough for the semi and the fire truck
		BlocksX = 7, -- odd, so the spawn block sits right in the middle (was 8 x 8: compacted)
		BlocksZ = 7,
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
