--!strict
-- Where the city's people are allowed to be (server/CrowdService, Rules/Spread): outings stay a short walk
-- from home on the sidewalks, homes out of town (no sidewalk) keep their people at home, and no stretch of
-- the map gets more than its share of residents. Studs.

return table.freeze({
	-- a resident or office worker heads out only to a restaurant, shop, park or plaza this close to where
	-- they are (about two city blocks); with none that close they stay in
	OutingRange = 600,
	-- homes off the sidewalk network (the suburbs and farms out of town) keep their people home: walking
	-- from there to town means a straight line over open grass and empty roads
	OffNetworkOutings = false,
	-- residents are counted on a grid of square cells this big (by their home's door)...
	AreaCell = 500,
	-- ...and a cell keeps at most this many; the rest are left out, taken first from the fullest homes
	AreaMaxResidents = 14,
})
