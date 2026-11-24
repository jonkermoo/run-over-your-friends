--!strict
-- Passengers (server/VehicleService, client/Riding, Rules/Riders): other players ride in a car's rider seats.
-- Seat spots are studs from the model's centre-bottom, in Config/Vehicles' seat frame (before VehicleScale):
-- x left (-) / right (+), y up, z back (+). The front passenger mirrors the driver (export_vehicles.py builds
-- both buckets at +-x); a rear bench (Hatchback, Sedan, Taxi) is 3.3 behind the front seats.

local Riders = {}

-- who may ride in a player's car (the Settings panel); saved per player, unknown or missing = Default
Riders.Modes = table.freeze({ "Everyone", "Friends", "Nobody" })
Riders.Default = "Everyone"

Riders.Seats = table.freeze({
	Hatchback = table.freeze({ { 1.4, 1.5, 1 }, { -0.85, 1.4, 4.3 }, { 0.85, 1.4, 4.3 } }),
	Scooter = table.freeze({ { 0, 4.6, 2.0 } }), -- pillion, on the saddle behind the rider
	Sedan = table.freeze({ { 1.5, 2.1, 0.4 }, { -0.9, 2.0, 3.7 }, { 0.9, 2.0, 3.7 } }),
	Cart = table.freeze({ { 0, 2.9, 1.8 } }), -- behind the driver (the toy steering stalk fills the front)
	Taxi = table.freeze({ { 1.5, 2.1, 0.4 }, { -0.9, 2.0, 3.7 }, { 0.9, 2.0, 3.7 } }),
	Muscle = table.freeze({ { 1.5, 1.7, 1.5 } }),
	IceCream = table.freeze({ { 1.8, 5.5, -4.3 } }),
	FireTruck = table.freeze({ { 2.4, 8.2, -14.1 } }),
	Semi = table.freeze({ { 2.1, 10.0, -5.9 } }),
	Bulldozer = table.freeze({ { 6.3, 8.6, 6.5 } }), -- outside the one-seat cab, on the deck over the right track
	Monster = table.freeze({ { 1.8, 7.8, -0.9 } }),
	Supercar = table.freeze({ { 1.7, 1.3, 1 } }),
	Roadster = table.freeze({ { 1.6, 0.8, 1 } }),
} :: { [string]: { { number } } })

Riders.ExitGap = 3 -- studs beside the car a rider steps out to
Riders.PromptRange = 12 -- the RIDE prompt's minimum reach (long vehicles reach further, like DRIVE)
Riders.FriendCache = 120 -- seconds a server friend check is trusted

return table.freeze(Riders)
