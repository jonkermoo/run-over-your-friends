--!strict
-- Every vehicle is one row: shop price, hit weight, driving numbers, features. The model is
-- ReplicatedStorage.VehicleModels[id] (Body + Wheel_<Corner><n> meshes, front facing -Z).
-- Driving numbers are metres and seconds; topSpeed in mph.

export type Feature =
	"Taxi"
	| "Jingle"
	| "Cannon"
	| "Jet"
	| "Thruster"
	| "Plow"
	| "Scooter"
	| "Cart"
	| "Monster"

export type Vehicle = {
	id: string,
	name: string,
	order: number,
	price: number, -- in-game money; 0 = free starter
	weight: number, -- kg, sets how hard it hits (not its physics mass)
	breaksBuildings: boolean,
	topSpeed: number, -- mph
	launch: number, -- m/s^2 off the line
	power: number, -- acceleration = power / speed once traction stops limiting it
	grip: number, -- lateral m/s^2 before the tyres give up
	rearGrip: number, -- rear axle grip vs front; under 1.1 makes the tail loose
	maxSteer: number, -- degrees of road-wheel lock
	features: { Feature },
	showDriver: boolean, -- open vehicles show the rider; closed ones hide them inside
	seat: { number }, -- seat position from the model's centre-bottom, studs (x, y, z)
	blurb: string,
}

local function v(row: Vehicle): Vehicle
	return table.freeze(row)
end

local list: { Vehicle } = {
	v({
		id = "Hatchback",
		name = "Hatchback",
		order = 1,
		price = 0,
		weight = 1100,
		breaksBuildings = false,
		topSpeed = 95,
		launch = 5.5,
		power = 70,
		grip = 16,
		rearGrip = 1.12,
		maxSteer = 34,
		features = {},
		showDriver = false,
		seat = { 0, 1.6, 1 },
		blurb = "Nippy little starter. Light hits.",
	}),
	v({
		id = "Scooter",
		name = "Scooter",
		order = 2,
		price = 1000,
		weight = 150,
		breaksBuildings = false,
		topSpeed = 55,
		launch = 4.5,
		power = 40,
		grip = 14,
		rearGrip = 1.12,
		maxSteer = 30,
		features = { "Scooter" },
		showDriver = true,
		seat = { 0, 3.9, 1.9 },
		blurb = "Tiny and silly. Barely tips people over.",
	}),
	v({
		id = "Sedan",
		name = "Sedan",
		order = 3,
		price = 3000,
		weight = 1500,
		breaksBuildings = false,
		topSpeed = 110,
		launch = 6,
		power = 85,
		grip = 15,
		rearGrip = 1.12,
		maxSteer = 33,
		features = {},
		showDriver = false,
		seat = { 0, 1.8, 1 },
		blurb = "The all-rounder.",
	}),
	v({
		id = "Cart",
		name = "Shopping Cart",
		order = 4,
		price = 5000,
		weight = 80,
		breaksBuildings = false,
		topSpeed = 40,
		launch = 4,
		power = 30,
		grip = 10,
		rearGrip = 1.0,
		maxSteer = 40,
		features = { "Cart" },
		showDriver = true,
		seat = { 0, 2.2, 0.3 },
		blurb = "One wobbly wheel. The speedometer swears it does 400.",
	}),
	v({
		id = "Taxi",
		name = "Taxi",
		order = 5,
		price = 6000,
		weight = 1600,
		breaksBuildings = false,
		topSpeed = 105,
		launch = 6,
		power = 85,
		grip = 15,
		rearGrip = 1.12,
		maxSteer = 33,
		features = { "Taxi" },
		showDriver = false,
		seat = { 0, 1.8, 1 },
		blurb = "Yell TAXI! and someone comes running.",
	}),
	v({
		id = "Muscle",
		name = "Muscle Car",
		order = 6,
		price = 25000,
		weight = 1700,
		breaksBuildings = false,
		topSpeed = 150,
		launch = 8.5,
		power = 170,
		grip = 15,
		rearGrip = 0.98,
		maxSteer = 32,
		features = {},
		showDriver = false,
		seat = { 0, 1.8, 1.5 },
		blurb = "Huge launch, loose tail.",
	}),
	v({
		id = "IceCream",
		name = "Ice-Cream Truck",
		order = 7,
		price = 50000,
		weight = 3500,
		breaksBuildings = false,
		topSpeed = 75,
		launch = 4,
		power = 45,
		grip = 11,
		rearGrip = 1.12,
		maxSteer = 30,
		features = { "Jingle" },
		showDriver = false,
		seat = { 0, 3, -3 },
		blurb = "Play the jingle and they all come to you.",
	}),
	v({
		id = "FireTruck",
		name = "Fire Truck",
		order = 8,
		price = 70000,
		weight = 9000,
		breaksBuildings = true,
		topSpeed = 85,
		launch = 3.8,
		power = 55,
		grip = 10,
		rearGrip = 1.12,
		maxSteer = 28,
		features = { "Cannon" },
		showDriver = false,
		seat = { 0, 4, -12 },
		blurb = "Water cannon knocks people flat. Breaks buildings.",
	}),
	v({
		id = "Semi",
		name = "Semi Truck",
		order = 9,
		price = 80000,
		weight = 15000,
		breaksBuildings = true,
		topSpeed = 80,
		launch = 3.2,
		power = 50,
		grip = 9.5,
		rearGrip = 1.12,
		maxSteer = 26,
		features = {},
		showDriver = false,
		seat = { 0, 4, -12 },
		blurb = "Enormous hits. Turns like a ship.",
	}),
	v({
		id = "Bulldozer",
		name = "Bulldozer",
		order = 10,
		price = 100000,
		weight = 20000,
		breaksBuildings = true,
		topSpeed = 35,
		launch = 3,
		power = 30,
		grip = 12,
		rearGrip = 1.12,
		maxSteer = 40,
		features = { "Plow" },
		showDriver = false,
		seat = { 0, 5, 3 },
		blurb = "Slow. The blade throws everything aside.",
	}),
	v({
		id = "Monster",
		name = "Monster Truck",
		order = 11,
		price = 120000,
		weight = 5000,
		breaksBuildings = true,
		topSpeed = 90,
		launch = 6,
		power = 110,
		grip = 12,
		rearGrip = 1.12,
		maxSteer = 32,
		features = { "Monster" },
		showDriver = false,
		seat = { 0, 7, 0 },
		blurb = "Giant wheels, giant bounces. Breaks buildings.",
	}),
	v({
		id = "Supercar",
		name = "Supercar",
		order = 12,
		price = 150000,
		weight = 1500,
		breaksBuildings = true,
		topSpeed = 200,
		launch = 11,
		power = 230,
		grip = 20,
		rearGrip = 1.1,
		maxSteer = 32,
		features = { "Thruster" },
		showDriver = false,
		seat = { 0, 1.5, 1 },
		blurb = "Near-Roadster speed, plus a forward thruster.",
	}),
	v({
		id = "Roadster",
		name = "Roadster",
		order = 13,
		price = 1000000,
		weight = 2000,
		breaksBuildings = true,
		topSpeed = 250,
		launch = 15,
		power = 290,
		grip = 22,
		rearGrip = 1.12,
		maxSteer = 32,
		features = { "Jet", "Thruster" },
		showDriver = false,
		seat = { 0, 1.5, 1 },
		blurb = "The dream car: rear jet, air control, thruster.",
	}),
}

local byId: { [string]: Vehicle } = {}
for _, row in list do
	byId[row.id] = row
end

local function has(vehicle: Vehicle, feature: Feature): boolean
	return table.find(vehicle.features, feature) ~= nil
end

return table.freeze({
	List = table.freeze(list),
	ById = table.freeze(byId),
	Starter = "Hatchback",
	StudsPerMetre = 4.32, -- every model is built to this scale
	has = has,
})
