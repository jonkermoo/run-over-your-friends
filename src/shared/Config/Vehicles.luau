--!strict
-- Every vehicle is one row: shop price, hit weight, driving numbers, features. The model is
-- ReplicatedStorage.VehicleModels[id] (Body + Wheel_<Corner><n> meshes, front facing -Z).
-- Driving numbers are metres and seconds; topSpeed in mph.
-- Engine sounds: Roblox audio library loops (Pro Sound Effects) except Electric (own synth); see ASSETS_LICENSES.md.

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

export type EngineKind =
	"Electric"
	| "Petrol"
	| "V8"
	| "Race"
	| "Kart"
	| "Cart"
	| "Jalopy"
	| "Diesel"
	| "BigRig"

export type Engine = {
	sound: string,
	loop: { number }?, -- seconds {from, to}: the steadiest stretch of the recording; nil = the whole file
	idlePitch: number, -- PlaybackSpeed at a standstill
	topPitch: number, -- PlaybackSpeed at top speed
	volume: number, -- evens out the recordings' levels
	idle: number, -- share of full volume while sitting still with a driver in; 0 = silent (electric)
}

export type Trailer = {
	model: string, -- ReplicatedStorage.VehicleModels[model], built like a vehicle (Body + Wheel_R<n>)
	hitch: { number }, -- coupling point on the tractor, studs from its centre-bottom (x, y, z)
	kingpin: { number }, -- the matching point on the trailer, studs from its centre-bottom
	swing: number, -- degrees the trailer may turn either way on the hitch
	twist: number, -- degrees the trailer may roll either way against the tractor
	sideGrip: number, -- lateral m/s^2 the trailer's tyres hold before its tail slides out
}

export type Tracks = {
	pivotRate: number, -- degrees per second it spins on the spot, tracks running opposite ways
	pivotFade: number, -- m/s at which on-the-spot turning has faded into ordinary steering
	pivotAccel: number, -- how fast the spin builds and stops (per second)
}

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
	showDriver: boolean, -- false hides the driver
	seat: { number }, -- seat position from the model's centre-bottom, studs (x, y, z); cars with an interior
	-- seat the driver on the left (-x), matching tools/blender/export_vehicles.py
	engine: EngineKind,
	engineTone: number?, -- pitch multiplier on the engine (bigger vehicle = lower), default 1
	steerTilt: number?, -- degrees the cabin steering wheel leans back towards the driver, default 22 (trucks lie flatter)
	steerRatio: number?, -- steering wheel turns per road-wheel turn, default 4 (handlebars 1)
	tracks: Tracks?, -- crawler tracks instead of tyres: turns on the spot when slow
	trailer: Trailer?,
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
		showDriver = true,
		seat = { -1.4, 1.6, 1 },
		engine = "Petrol",
		engineTone = 1.15,
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
		seat = { 0, 4.3, 0.4 },
		engine = "Kart",
		steerTilt = 60,
		steerRatio = 1,
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
		showDriver = true,
		seat = { -1.5, 1.8, 0.4 },
		engine = "Petrol",
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
		seat = { 0, 2.9, 0.3 },
		engine = "Cart",
		steerTilt = 35,
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
		showDriver = true,
		seat = { -1.5, 1.8, 0.4 },
		engine = "Petrol",
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
		showDriver = true,
		seat = { -1.5, 1.8, 1.5 },
		engine = "V8",
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
		showDriver = true,
		seat = { -1.8, 4.2, -4.3 },
		engine = "Jalopy",
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
		showDriver = true,
		seat = { -2.4, 6.4, -14.1 },
		engine = "Diesel",
		steerTilt = 50,
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
		showDriver = true,
		seat = { -2.1, 9.3, -5.9 },
		engine = "BigRig",
		trailer = {
			model = "SemiTrailer",
			hitch = { 0, 5.7, 7.6 },
			kingpin = { 0, 5.7, -9.05 },
			swing = 75,
			twist = 15,
			sideGrip = 12,
		},
		steerTilt = 55,
		blurb = "Enormous hits. The trailer swings wide and flattens the lot.",
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
		showDriver = true,
		seat = { 0, 10.4, 6.5 },
		engine = "Diesel",
		engineTone = 0.85,
		tracks = { pivotRate = 45, pivotFade = 4, pivotAccel = 3 },
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
		showDriver = true,
		seat = { -1.8, 7, -0.9 },
		engine = "V8",
		engineTone = 0.8,
		steerTilt = 30,
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
		showDriver = true,
		seat = { -1.7, 1.5, 1 },
		engine = "Race",
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
		showDriver = true,
		seat = { -1.6, 1.2, 1 },
		engine = "Electric",
		blurb = "The dream car: rear jet, air control, thruster.",
	}),
}

local engines: { [EngineKind]: Engine } = {
	Electric = {
		sound = "rbxassetid://73461257901277",
		idlePitch = 0.3,
		topPitch = 2.5,
		volume = 1,
		idle = 0,
	},
	Petrol = { -- 1969 convertible, cruising
		sound = "rbxassetid://9112735119",
		loop = { 9.25, 15.25 },
		idlePitch = 0.85,
		topPitch = 1.7,
		volume = 2.5,
		idle = 0.3,
	},
	V8 = { -- 1969 convertible, deep rumble
		sound = "rbxassetid://9112734366",
		loop = { 39.75, 45.75 },
		idlePitch = 0.8,
		topPitch = 1.6,
		volume = 3,
		idle = 0.4,
	},
	Race = { -- race car, constant
		sound = "rbxassetid://9112782186",
		loop = { 4.75, 10.75 },
		idlePitch = 0.6,
		topPitch = 1.35,
		volume = 2,
		idle = 0.3,
	},
	Kart = { -- go-kart engine, constant
		sound = "rbxassetid://9112787518",
		loop = { 11.5, 17.5 },
		idlePitch = 0.8,
		topPitch = 1.6,
		volume = 3,
		idle = 0.3,
	},
	Cart = { -- shopping cart rolling: no engine, just rattle
		sound = "rbxassetid://9119092604",
		loop = { 2, 8 },
		idlePitch = 0.6,
		topPitch = 1.4,
		volume = 5,
		idle = 0,
	},
	Jalopy = { -- cartoon jalopy chugging
		sound = "rbxassetid://9125425383",
		loop = { 1.5, 7.5 },
		idlePitch = 0.8,
		topPitch = 1.4,
		volume = 2.5,
		idle = 0.4,
	},
	Diesel = { -- diesel dump truck
		sound = "rbxassetid://9112735582",
		loop = { 26.75, 32.75 },
		idlePitch = 0.75,
		topPitch = 1.3,
		volume = 1,
		idle = 0.4,
	},
	BigRig = { -- semi truck, driving
		sound = "rbxassetid://9112736261",
		loop = { 15, 21 },
		idlePitch = 0.75,
		topPitch = 1.3,
		volume = 1.5,
		idle = 0.4,
	},
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
	Engines = table.freeze(engines),
	Starter = "Hatchback",
	StudsPerMetre = 4.32, -- every model is built to this scale
	has = has,
})
