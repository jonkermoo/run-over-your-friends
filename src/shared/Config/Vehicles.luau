--!strict
-- Every vehicle is one row: shop price, hit weight, driving numbers, features. The model is
-- ReplicatedStorage.VehicleModels[id] (Body + Wheel_<Corner><n> meshes, front facing -Z).
-- Driving numbers are metres and seconds; topSpeed in mph.
-- Engine sounds: Roblox audio library loops (Pro Sound Effects) except Electric (own synth); horns and the jingle
-- are library sounds too; see ASSETS_LICENSES.md.

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

export type HornKind = "Car" | "V8" | "Euro" | "Bike" | "AirHorn" | "Siren" | "Buzzer"

-- a one-shot horn recording; volumes even out the recordings (measured RMS) to about the same loudness
export type Horn = {
	sound: string,
	volume: number,
	start: number?, -- seconds of silence at the head of the file to skip
}

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
	maxBreak: number?, -- studs: caps how far its building hits reach (early cars: a hole they can drive through); nil = no cap, and it can bring a whole building down
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
	horn: HornKind, -- H / pad D-pad up / the phone's HONK button
	hornPitch: number?, -- PlaybackSpeed on the horn, default 1
	steerTilt: number?, -- degrees the cabin steering wheel leans back towards the driver, default 22 (trucks lie flatter)
	steerRatio: number?, -- steering wheel turns per road-wheel turn, default 4 (handlebars 1)
	nozzle: { number }?, -- water cannon turret, studs from the chassis centre (x, y, z)
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
		maxBreak = 8,
		topSpeed = 95,
		launch = 5.5,
		power = 70,
		grip = 16,
		rearGrip = 1.12,
		maxSteer = 34,
		features = {},
		showDriver = true,
		seat = { -1.4, 1.5, 1 },
		engine = "Petrol",
		horn = "Car",
		engineTone = 1.15,
		blurb = "Nippy little starter. Light hits.",
	}),
	v({
		id = "Scooter",
		name = "Scooter",
		order = 2,
		price = 200,
		weight = 150,
		maxBreak = 8,
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
		horn = "Bike",
		steerTilt = 80, -- 90 - SCOOT_RAKE in tools/blender/export_vehicles.py (the column runs through the front hub)
		steerRatio = 1,
		blurb = "Tiny and silly. Barely tips people over.",
	}),
	v({
		id = "Sedan",
		name = "Sedan",
		order = 4,
		price = 3000,
		weight = 1500,
		maxBreak = 8,
		topSpeed = 110,
		launch = 6,
		power = 85,
		grip = 15,
		rearGrip = 1.12,
		maxSteer = 33,
		features = {},
		showDriver = true,
		seat = { -1.5, 2.1, 0.4 },
		engine = "Petrol",
		horn = "Car",
		hornPitch = 0.95,
		blurb = "The all-rounder.",
	}),
	v({
		id = "Cart",
		name = "Shopping Cart",
		order = 3,
		price = 400,
		weight = 80,
		maxBreak = 8,
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
		horn = "Bike",
		hornPitch = 1.25,
		steerTilt = 35,
		blurb = "One wobbly wheel. The speedometer swears it does 400.",
	}),
	v({
		id = "Taxi",
		name = "Taxi",
		order = 5,
		price = 6000,
		weight = 1600,
		maxBreak = 8,
		topSpeed = 105,
		launch = 6,
		power = 85,
		grip = 15,
		rearGrip = 1.12,
		maxSteer = 33,
		features = { "Taxi" },
		showDriver = true,
		seat = { -1.5, 2.1, 0.4 },
		engine = "Petrol",
		horn = "Car",
		hornPitch = 0.92,
		blurb = "Yell TAXI! and someone comes running.",
	}),
	v({
		id = "Muscle",
		name = "Muscle Car",
		order = 6,
		price = 25000,
		weight = 1700,
		topSpeed = 150,
		launch = 8.5,
		power = 170,
		grip = 15,
		rearGrip = 0.98,
		maxSteer = 32,
		features = {},
		showDriver = true,
		seat = { -1.5, 1.7, 1.5 },
		engine = "V8",
		horn = "V8",
		blurb = "Huge launch, loose tail.",
	}),
	v({
		id = "IceCream",
		name = "Ice-Cream Truck",
		order = 7,
		price = 50000,
		weight = 3500,
		topSpeed = 75,
		launch = 4,
		power = 45,
		grip = 11,
		rearGrip = 1.12,
		maxSteer = 30,
		features = { "Jingle" },
		showDriver = true,
		seat = { -1.8, 5.5, -4.3 },
		engine = "Jalopy",
		horn = "Car",
		hornPitch = 1.12,
		blurb = "Turn the jingle on and they all come to you.",
	}),
	v({
		id = "FireTruck",
		name = "Fire Truck",
		order = 8,
		price = 70000,
		weight = 9000,
		topSpeed = 85,
		launch = 3.8,
		power = 55,
		grip = 10,
		rearGrip = 1.12,
		maxSteer = 28,
		features = { "Cannon" },
		showDriver = true,
		seat = { -2.4, 8.2, -14.1 },
		engine = "Diesel",
		nozzle = { 0, 12, -6 }, -- on the roof behind the cab
		horn = "Siren",
		steerTilt = 50,
		blurb = "Water cannon knocks people flat. Breaks buildings.",
	}),
	v({
		id = "Semi",
		name = "Semi Truck",
		order = 9,
		price = 80000,
		weight = 15000,
		topSpeed = 80,
		launch = 3.2,
		power = 50,
		grip = 9.5,
		rearGrip = 1.12,
		maxSteer = 26,
		features = {},
		showDriver = true,
		seat = { -2.1, 10.0, -5.9 },
		engine = "BigRig",
		horn = "AirHorn",
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
		topSpeed = 35,
		launch = 3,
		power = 30,
		grip = 12,
		rearGrip = 1.12,
		maxSteer = 40,
		features = { "Plow" },
		showDriver = true,
		seat = { 0, 12.4, 6.5 },
		engine = "Diesel",
		horn = "Buzzer",
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
		topSpeed = 90,
		launch = 6,
		power = 110,
		grip = 12,
		rearGrip = 1.12,
		maxSteer = 32,
		features = { "Monster" },
		showDriver = true,
		seat = { -1.8, 7.8, -0.9 },
		engine = "V8",
		horn = "AirHorn",
		hornPitch = 1.15,
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
		topSpeed = 200,
		launch = 11,
		power = 230,
		grip = 20,
		rearGrip = 1.1,
		maxSteer = 32,
		features = { "Thruster" },
		showDriver = true,
		seat = { -1.7, 1.3, 1 }, -- 0.5 over roof - 4.7, so the driver sees out over the dash
		engine = "Race",
		horn = "Euro",
		blurb = "Near-Roadster speed, plus a forward thruster.",
	}),
	v({
		id = "Roadster",
		name = "Roadster",
		order = 13,
		price = 1000000,
		weight = 2000,
		topSpeed = 250,
		launch = 15,
		power = 290,
		grip = 22,
		rearGrip = 1.12,
		maxSteer = 32,
		features = { "Jet", "Thruster" },
		showDriver = true,
		seat = { -1.6, 0.8, 1 },
		engine = "Electric",
		horn = "Euro",
		hornPitch = 1.1,
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

-- Pro Sound Effects library one-shots (see ASSETS_LICENSES.md)
local horns: { [HornKind]: Horn } = {
	Car = { sound = "rbxassetid://9120385543", volume = 0.65 }, -- Vehicle Horn Short Long Honks 1
	V8 = { sound = "rbxassetid://9120382911", volume = 0.67 }, -- Vehicle Horn 4
	Euro = { sound = "rbxassetid://9120383812", volume = 0.66 }, -- Vehicle Horn Honk European Buzzing Whine 5
	Bike = { sound = "rbxassetid://9113438365", volume = 0.9 }, -- Bike Horn Squeeze 2
	AirHorn = { sound = "rbxassetid://9114075665", volume = 0.35, start = 0.45 }, -- Diesel Truck Air Horn 1
	Siren = { sound = "rbxassetid://9119162409", volume = 1.6 }, -- Siren Blat 2
	Buzzer = { sound = "rbxassetid://9126157673", volume = 0.7 }, -- Vehicle Horn Short Honking Blasts Very Buzzy
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
	Horns = table.freeze(horns),
	HornCooldown = 0.35, -- seconds between honks (the server relays no faster)
	-- the ice-cream truck's G turns its tune on and off: APM Music "Ice Cream Truck OL" (30 s), looped while
	-- on; it fades out over `fade` seconds when turned off
	Jingle = table.freeze({ sound = "rbxassetid://1838797774", volume = 0.7, fade = 1.2 }),
	Starter = "Hatchback",
	StudsPerMetre = 4.32, -- every model is built to this scale
	-- on the ground the body tilts to the road under it (ramps, hills); in the air it levels to world up
	Ground = table.freeze({
		follow = 10, -- how fast the wanted tilt eases toward the measured ground, per second
		maxTilt = 40, -- degrees from flat it will ever tilt to (steepest ramp on the map is ~31)
		reach = 0.8, -- metres below the chassis bottom the corner probes look for ground
		inset = 0.8, -- probes sit this share of the way out to the chassis corners
		parkedEvery = 0.2, -- seconds between ground checks for a parked car (server)
	}),
	-- weight and balance: when the centre of mass (from the parts' real physics mass) is past the wheels that
	-- are on the ground, like the rear wheels on a ledge with the nose in the air, the levelling lets go and
	-- gravity tips it over the edge (Rules/Balance)
	Balance = table.freeze({
		margin = 0.12, -- share of the chassis half-length the centre of mass may sit past the support and stay up
		settle = 0.08, -- seconds it must be past the support before it lets go, so bumps and seams don't tip it
		hold = 0.05, -- share of gravity's tipping pull (mass x g x half-length) the levelling still fights
		airFree = 0.7, -- seconds after tipping off an edge before the air levelling rights it again
		maxSpeed = 12, -- m/s; faster than this, off a crest or ramp lip, it flies level as before instead of tipping
	}),
	has = has,
})
