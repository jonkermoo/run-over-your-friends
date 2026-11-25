--!strict
-- Teleporting from the city map (server/TeleportService, Rules/Teleport, client/CityMap): one ring per area on the
-- map; tapping it and TELEPORT moves you (and your car, with anyone riding in it) to a free landing spot there.
-- Each area has several landing spots so a group that teleports together lands apart. Where an area sits comes
-- from the map's own config (the city grid, Config/Suburbs, Config/Country), so it follows the map when it moves.
-- Studs, seconds, layout px.

-- from: "Plaza" = the spawn plaza (Config/World Map), "Suburb" = the Config/Suburbs hood called `hood`,
-- "Moto" = the motocross track (Config/Country Moto), "Spot" = the fixed x, z given here.
-- roads = true lands on the built road points (MapBuilder spawnPoints) within `radius` of the middle; false
-- lands on `count` points in a circle `radius` round it.
export type Place = {
	key: string,
	name: string,
	from: string,
	hood: string?,
	x: number?,
	z: number?,
	roads: boolean,
	radius: number,
	count: number?,
}

return table.freeze({
	Cooldown = 60, -- seconds between teleports (free)
	MinGap = 60, -- landing spots in one area stay at least this far apart
	MaxSpots = 12, -- at most this many landing spots per area
	Clear = 30, -- a spot with a player or car this close is taken
	EventKeepAway = 500, -- no landing this close to the live event's spot (the crate, a truck, the giant)
	StreamTimeout = 6, -- the longest the server waits for the spot to stream in around the player
	Lift = 3, -- on foot: the character's root this high over the ground

	Places = table.freeze({
		table.freeze({ key = "City", name = "CITY", from = "Plaza", roads = true, radius = 450 }),
		table.freeze({
			key = "SunnyVale",
			name = "SUNNY VALE",
			from = "Suburb",
			hood = "SUNNY VALE",
			roads = true,
			radius = 450,
		}),
		table.freeze({
			key = "OakHollow",
			name = "OAK HOLLOW",
			from = "Suburb",
			hood = "OAK HOLLOW",
			roads = true,
			radius = 450,
		}),
		table.freeze({
			key = "Seaside",
			name = "SEASIDE",
			from = "Suburb",
			hood = "SEASIDE",
			roads = true,
			radius = 450,
		}),
		-- the stunt park (the city map's STUNT PARK label, Config/CityMap Places)
		table.freeze({
			key = "StuntPark",
			name = "STUNT PARK",
			from = "Spot",
			x = 1953,
			z = -2,
			roads = false,
			radius = 90,
			count = 8,
		}),
		table.freeze({
			key = "Motocross",
			name = "MOTOCROSS",
			from = "Moto",
			roads = false,
			radius = 90,
			count = 8,
		}),
	}) :: { Place },

	-- the map's rings and the picked place's card (client/CityMap)
	Ring = 30, -- layout px across
	RingPicked = 40,
	TapRadius = 30, -- a tap this close to a ring picks it (rings win over player dots)
})
