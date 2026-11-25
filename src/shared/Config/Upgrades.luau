--!strict
-- Car mastery, upgrades and decals (docs/UPGRADES.md). Driving a car fills that car's mastery; each level opens
-- its upgrades (bought once with game money, then switched on and off) and decals (free). Every upgrade rebuilds
-- one zone of the car's model: the parts named Z<n> (stock zone) and U<n> (rebuilt zone, U<n>W_ wheel sets) in
-- ReplicatedStorage.VehicleModels, made by tools/blender/vehicle_upgrades.py. Rules/Upgrades turns these numbers
-- into stats.

-- what an upgrade does; every field is optional
export type Effect = {
	-- shares added to the garage's four stats: 0.25 = +25%
	speed: number?, -- top speed
	accel: number?, -- launch and pull
	handling: number?, -- tyre grip
	weight: number?, -- hit weight (how hard it hits and what a hit pays)
	rearGrip: number?, -- rear axle grip set to at least this (a loose tail made tamer)
	maxBreak: number?, -- building holes up to this many studs across (instead of the car's own cap)
	reach: number?, -- studs added to the hit box in front of the car
	rearReach: number?, -- studs of hit box added behind the car (people behind it count as hits)
	wide: number?, -- studs added to each side of the hit box
	trailerWide: number?, -- studs added to each side of the trailer's hit box
	throw: number?, -- the plow's sideways throw times this
	pivot: number?, -- crawler tracks' on-the-spot spin rate times this
	taxiRange: number?, -- the taxi call reaches this many times further
	taxiCount: number?, -- people one taxi call brings
	jingleRange: number?, -- the jingle reaches this many times further
	jingleEvery: number?, -- seconds between jingle pulls times this (under 1 = faster)
	cannonRange: number?, -- water cannon range times this
	cannonCone: number?, -- the cannon's aim cone (a dot product) times this: under 1 = a wider spray
	cannonForce: number?, -- how hard the cannon knocks people, times this
	stuntPay: number?, -- jump pay times this
	bounce: number?, -- suspension bounce times this (monster truck)
	thrusterTime: number?, -- the thruster meter lasts this many times longer
	thrusterPush: number?, -- the thruster pushes this many times harder
	jetPush: number?, -- the Roadster's rear jet pushes this many times harder
	jetTime: number?, -- and lasts this many times longer
	flySpeed: number?, -- flight top speed times this
	flyClimb: number?, -- flight climb rate times this
}

export type Upgrade = {
	n: number, -- 1-3, the Z<n>/U<n> parts of the model
	name: string,
	zone: string, -- shown on the card
	effect: Effect,
	text: string, -- the effect in words, shown on the card ("+25% WEIGHT, +1 REACH")
}

local Upgrades = {}

-- mastery points per action, given to the car being driven
Upgrades.Points = table.freeze({
	Npc = 10, -- a person knocked down for money (run over, giant hit, water cannon)
	Player = 25, -- a player run over
	Traffic = 8, -- a traffic car hit
	Smash = 5, -- a hole knocked in a building
	Collapse = 50, -- a whole building brought down
	Stunt = 10, -- a jump landed
	StudsPerPoint = 500, -- driving: one point per this many studs
	DriveEvery = 1, -- seconds between the server's driving checks
	MaxDriveStep = 400, -- studs a car can honestly cover between two checks (teleports and respawns don't count)
})

-- total points for each level (index = level)
Upgrades.Levels = table.freeze({ 100, 300, 650, 1200, 2000 })
Upgrades.MaxLevel = 5

-- the mastery level that opens upgrade n
Upgrades.UpgradeLevel = table.freeze({ 1, 3, 5 })

-- price of upgrade n: this share of the car's price, at least the floor
Upgrades.PriceShare = table.freeze({ 0.1, 0.2, 0.3 })
Upgrades.PriceFloor = table.freeze({ 150, 375, 750 })
-- cars priced as if they cost this for upgrades (the Roadster is also a pass, so its upgrades stay put if its
-- cash price moves)
Upgrades.PriceBasis = table.freeze({ Roadster = 200000 } :: { [string]: number })

Upgrades.SetEvery = 0.4 -- seconds between upgrade or decal changes a player may make
Upgrades.PopupSeconds = 3 -- the driving mastery bar shows this long after points come in

-- decals: one per car at a time, each opened by a mastery level; the images are drawn per car
-- (tools/art/decals.py) and printed on the car's painted parts over the paint colour
export type Decal = { id: string, level: number, name: string }
Upgrades.Decals = table.freeze({
	table.freeze({ id = "Stripes", level = 1, name = "Stripes" }),
	table.freeze({ id = "Number", level = 2, name = "Number" }),
	table.freeze({ id = "Flames", level = 3, name = "Flames" }),
	table.freeze({ id = "Checker", level = 4, name = "Checker" }),
	table.freeze({ id = "Signature", level = 5, name = "Signature" }),
} :: { Decal })

-- each car's signature decal name
Upgrades.Signature = table.freeze({
	Hatchback = "Lightning",
	Scooter = "Pizza Zoom",
	Cart = "Mega Mart",
	Sedan = "Pinstripe",
	Taxi = "Dice",
	Muscle = "Thunder",
	IceCream = "Sprinkles",
	FireTruck = "Station 13",
	Semi = "Wings",
	Bulldozer = "Hazard",
	Monster = "Shark Mouth",
	Supercar = "Tricolore",
	Roadster = "Galaxy",
} :: { [string]: string })

-- decal images (Open Cloud image ids, owned by the group), vehicle -> decal id -> image id; 0 = not uploaded
Upgrades.Images = table.freeze({
	Bulldozer = table.freeze({
		Stripes = 95226058313320,
		Number = 121776674208036,
		Flames = 108784998656051,
		Checker = 110809330563262,
		Signature = 92949172613711,
	}),
	Cart = table.freeze({
		Stripes = 102415157265054,
		Number = 130911788051121,
		Flames = 131071467464341,
		Checker = 70510223563840,
		Signature = 75753410070549,
	}),
	FireTruck = table.freeze({
		Stripes = 89949978600657,
		Number = 106258526181519,
		Flames = 108044029057748,
		Checker = 114418296055244,
		Signature = 113396599739294,
	}),
	Hatchback = table.freeze({
		Stripes = 126548385087856,
		Number = 93734615556365,
		Flames = 90184357142653,
		Checker = 117646948214083,
		Signature = 94544110622803,
	}),
	IceCream = table.freeze({
		Stripes = 140224232077162,
		Number = 104316051513773,
		Flames = 85838101329634,
		Checker = 71453758898292,
		Signature = 83512649396230,
	}),
	Monster = table.freeze({
		Stripes = 140102787333231,
		Number = 71473508854870,
		Flames = 119802936906819,
		Checker = 118686323797753,
		Signature = 71482206091822,
	}),
	Muscle = table.freeze({
		Stripes = 108440731246237,
		Number = 74633671431107,
		Flames = 93641020052684,
		Checker = 118800597247308,
		Signature = 97706939995228,
	}),
	Roadster = table.freeze({
		Stripes = 105810464167185,
		Number = 95728774914559,
		Flames = 101570981526000,
		Checker = 103875812007096,
		Signature = 132698617258585,
	}),
	Scooter = table.freeze({
		Stripes = 108674070609984,
		Number = 121734482637394,
		Flames = 123130566898385,
		Checker = 73533252007893,
		Signature = 96567708533546,
	}),
	Sedan = table.freeze({
		Stripes = 105077326348655,
		Number = 72983621976496,
		Flames = 98906372735497,
		Checker = 88791061791595,
		Signature = 113233811011600,
	}),
	Semi = table.freeze({
		Stripes = 101561259493802,
		Number = 129084807021557,
		Flames = 135545970956936,
		Checker = 123652911542411,
		Signature = 97012421769181,
	}),
	Supercar = table.freeze({
		Stripes = 123650818111318,
		Number = 82968905972240,
		Flames = 109213676381205,
		Checker = 125737303576558,
		Signature = 92610900952325,
	}),
	Taxi = table.freeze({
		Stripes = 116338049894996,
		Number = 119412685440344,
		Flames = 92475448633557,
		Checker = 136564452871403,
		Signature = 77888218220775,
	}),
} :: { [string]: { [string]: number } })

local function u(n: number, name: string, zone: string, text: string, effect: Effect): Upgrade
	return table.freeze({
		n = n,
		name = name,
		zone = zone,
		text = text,
		effect = table.freeze(effect),
	})
end

Upgrades.ByVehicle = table.freeze({
	Hatchback = table.freeze({
		u(1, "Rally Bumper", "FRONT", "+25% WEIGHT, +1 REACH", { weight = 0.25, reach = 1 }),
		u(
			2,
			"Hot Hatch Kit",
			"SIDES + WHEELS",
			"+15% HANDLING, +15% ACCEL",
			{ handling = 0.15, accel = 0.15 }
		),
		u(3, "Rally Roof", "ROOF", "+15% SPEED, BIGGER HOLES", { speed = 0.15, maxBreak = 12 }),
	}),
	Scooter = table.freeze({
		u(1, "Racing Fairing", "FRONT", "+15% SPEED", { speed = 0.15 }),
		u(2, "Big Bore", "REAR", "+25% ACCEL", { accel = 0.25 }),
		u(
			3,
			"Balloon Tyres",
			"WHEELS",
			"+15% HANDLING, +65% WEIGHT",
			{ handling = 0.15, weight = 0.65 }
		),
	}),
	Cart = table.freeze({
		u(1, "Battering Basket", "FRONT", "+150% WEIGHT", { weight = 1.5 }),
		u(2, "Rocket Handle", "REAR", "+30% SPEED, +30% ACCEL", { speed = 0.3, accel = 0.3 }),
		u(3, "Monster Casters", "WHEELS", "+30% HANDLING", { handling = 0.3 }),
	}),
	Sedan = table.freeze({
		u(1, "Push Bar", "FRONT", "+25% WEIGHT, +1 REACH", { weight = 0.25, reach = 1 }),
		u(2, "Sport Rear", "REAR", "+15% ACCEL, +10% SPEED", { accel = 0.15, speed = 0.1 }),
		u(3, "Lowered Kit", "SIDES + WHEELS", "+15% HANDLING", { handling = 0.15 }),
	}),
	Taxi = table.freeze({
		u(1, "Mega Sign", "ROOF", "TAXI CALL REACHES 50% FURTHER", { taxiRange = 1.5 }),
		u(2, "Cow Catcher", "FRONT", "+30% WEIGHT, +1.5 REACH", { weight = 0.3, reach = 1.5 }),
		u(3, "Double Fare", "REAR", "A TAXI CALL BRINGS TWO PEOPLE", { taxiCount = 2 }),
	}),
	Muscle = table.freeze({
		u(1, "Blower", "HOOD", "+20% ACCEL", { accel = 0.2 }),
		u(
			2,
			"Wide Body",
			"SIDES + WHEELS",
			"+15% HANDLING, TAIL LESS LOOSE",
			{ handling = 0.15, rearGrip = 1.05 }
		),
		u(3, "Ram Nose", "FRONT", "+30% WEIGHT, +1 REACH", { weight = 0.3, reach = 1 }),
	}),
	IceCream = table.freeze({
		u(1, "Giant Cone", "ROOF", "JINGLE REACHES 40% FURTHER", { jingleRange = 1.4 }),
		u(2, "Freezer Bumper", "FRONT", "+30% WEIGHT, +1 REACH", { weight = 0.3, reach = 1 }),
		u(
			3,
			"Sound System",
			"SIDES",
			"JINGLE PULLS FASTER, +15% SPEED",
			{ jingleEvery = 0.6, speed = 0.15 }
		),
	}),
	FireTruck = table.freeze({
		u(
			1,
			"Big Cannon",
			"ROOF",
			"CANNON REACHES 40% FURTHER",
			{ cannonRange = 1.4, cannonCone = 0.9 }
		),
		u(2, "Ram Bumper", "FRONT", "+20% WEIGHT, +1.5 REACH", { weight = 0.2, reach = 1.5 }),
		u(
			3,
			"High-Pressure Pump",
			"SIDES",
			"CANNON 60% HARDER, +10% SPEED",
			{ cannonForce = 1.6, speed = 0.1 }
		),
	}),
	Semi = table.freeze({
		u(1, "Bull Bar", "FRONT", "+20% WEIGHT, +1.5 REACH", { weight = 0.2, reach = 1.5 }),
		u(2, "Big Stacks", "ROOF", "+20% ACCEL, +10% SPEED", { accel = 0.2, speed = 0.1 }),
		u(3, "Sweeper Trailer", "TRAILER", "TRAILER SWEEPS WIDER", { trailerWide = 3 }),
	}),
	Bulldozer = table.freeze({
		u(
			1,
			"Big Blade",
			"FRONT",
			"+2.5 REACH, WIDER, THROWS 50% FURTHER",
			{ reach = 2.5, wide = 2, throw = 1.5 }
		),
		u(2, "Turbo Diesel", "HOOD", "+30% SPEED, +25% ACCEL", { speed = 0.3, accel = 0.25 }),
		u(3, "Ripper", "REAR", "SPINS 45% FASTER, HITS BEHIND IT", { pivot = 1.45, rearReach = 3 }),
	}),
	Monster = table.freeze({
		u(1, "Light Bar & Cage", "ROOF", "JUMPS PAY 25% MORE", { stuntPay = 1.25 }),
		u(2, "Crusher Bumper", "FRONT", "+30% WEIGHT, +1 REACH", { weight = 0.3, reach = 1 }),
		u(3, "Mega Tyres", "WHEELS", "+10% SPEED, BIGGER BOUNCES", { speed = 0.1, bounce = 1.3 }),
	}),
	Supercar = table.freeze({
		u(1, "Aero Nose", "FRONT", "+12% HANDLING", { handling = 0.12 }),
		u(
			2,
			"Swan Wing",
			"REAR",
			"+8% HANDLING, THRUSTER LASTS 25% LONGER",
			{ handling = 0.08, thrusterTime = 1.25 }
		),
		u(
			3,
			"Twin Turbo",
			"ENGINE",
			"+8% SPEED, THRUSTER 20% HARDER",
			{ speed = 0.08, thrusterPush = 1.2 }
		),
	}),
	Roadster = table.freeze({
		u(1, "Aero Nose", "FRONT", "+10% HANDLING", { handling = 0.1 }),
		u(2, "Afterburner", "REAR", "JET 20% HARDER AND LONGER", { jetPush = 1.2, jetTime = 1.2 }),
		u(
			3,
			"Flight Fins",
			"SIDES",
			"FLIES 20% FASTER, CLIMBS 30% FASTER",
			{ flySpeed = 1.2, flyClimb = 1.3 }
		),
	}),
} :: { [string]: { Upgrade } })

-- the trailer model that carries a vehicle's trailer upgrades (its U<n> parts follow the tractor's switches)
Upgrades.TrailerOf = table.freeze({ Semi = "SemiTrailer" } :: { [string]: string })

return table.freeze(Upgrades)
