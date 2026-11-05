--!strict
-- City traffic: cars the server moves along the road network (Rules/Roads) as plain numbers, which every
-- screen draws from pooled models. Crash into one and it goes flying. Studs and seconds unless noted.

export type Kind = { id: string, weight: number, factoryPaint: boolean? }

return table.freeze({
	Count = 24, -- cars in the city at once (all players together)
	Kinds = table.freeze({ -- ReplicatedStorage.VehicleModels[id]; weight = how often it turns up
		{ id = "Hatchback", weight = 3 },
		{ id = "Sedan", weight = 3 },
		{ id = "Taxi", weight = 2, factoryPaint = true },
		{ id = "Muscle", weight = 1 },
		{ id = "Supercar", weight = 0.4 },
		{ id = "IceCream", weight = 0.3, factoryPaint = true },
	}) :: { Kind },
	FactoryChance = 0.35, -- other cars keep their own colour this often, else a random Config/Paints colour

	-- driving
	Lane = 11, -- studs right of the road's centre line
	Cruise = 48, -- studs/s (about 25 mph)
	TurnSpeed = 26, -- through a turn
	Accel = 22, -- studs/s^2
	Brake = 60,
	Gap = 9, -- bumper gap kept to whatever is in front
	Look = 45, -- how far ahead they watch for people and players in their lane
	StraightWeight = 3, -- at a crossing, straight on is this many times likelier than each turn
	Patience = 5, -- seconds stuck behind a player (their vehicle, or them on foot) before honking and passing
	PassShift = 7, -- studs/s sideways while pulling out into the other lane and back
	PassSpeed = 22, -- studs/s while out of their lane
	StopLine = 47, -- studs before a crossing's centre where they wait at a red light
	CarLength = 23, -- for spacing (studs, the longest kinds, at Game.VehicleScale)
	HalfWidth = 6.7, -- half a car's width plus a little: how wide a path they keep clear ahead
	Tick = 0.1, -- server step

	-- keeping them near players
	SpawnMin = 260, -- new and recycled cars appear this far from a player...
	SpawnMax = 480,
	RecycleDistance = 700, -- ...and a car this far from every player is moved
	RecycleEvery = 1,

	-- snapshots and drawing
	SendEvery = 0.25, -- server -> clients
	Delay = 0.3, -- clients draw this far in the past, between two snapshots
	DrawRadius = 450, -- clients draw cars this close to the camera...
	ShownMax = 18, -- ...at most this many (nearest first)
	ShownPhone = 10,
	GroundEvery = 0.2, -- seconds between ground checks per drawn car

	-- crashing
	CrashSpeed = 5, -- m/s closing speed for a hit to count
	CrashReach = 38, -- server check: studs between the player's vehicle and the car (at Game.VehicleScale), plus their lag
	RespawnSeconds = 8,
	WreckSeconds = 5, -- the flung car stays this long on screen, then fades
	Pay = 40, -- money per wreck at CrashSpeed...
	PayMax = 3, -- ...up to this many times more at speed
	FlingAlong = 1.2, -- a wreck flies off at this share of the closing velocity...
	FlingUp = 60, -- ...plus this much straight up (studs/s; Roblox gravity is strong)...
	FlingUpPerMs = 2.5, -- ...and this much more per m/s of closing speed
	BumpShare = 0.5, -- the hitting vehicle loses up to this share of its speed (less the heavier it is)
})
