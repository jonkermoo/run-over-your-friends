--!strict
-- Map layout, NPCs and destruction budgets. Studs and seconds.

return table.freeze({
	Map = table.freeze({
		GroundSize = 6000,
		BlockSize = 220, -- city block, kerb to kerb
		RoadWidth = 64, -- wide enough for the semi and the fire truck
		BlocksX = 8,
		BlocksZ = 8,
		FloorHeight = 14,
		PanelWidth = 12,
		WallThickness = 1.5,
		SidewalkWidth = 14,
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
		JingleSeconds = 8,
		CannonRange = 70,
		CannonCone = 0.8, -- dot product with the nose
	}),
	Debris = table.freeze({
		MaxLoose = 1500,
		RebuildSeconds = 75,
		ChunkFallReach = 0.7, -- share of the break radius that also drops the floors above
	}),
})
