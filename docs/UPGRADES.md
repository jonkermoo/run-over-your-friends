# Car mastery, upgrades and decals (design draft)

Every vehicle gets its own mastery bar. Driving a car fills its bar; each mastery level unlocks that car's own
upgrades and decals. Upgrades cost game money (a money sink, kept cheap); decals are free once unlocked. Each
upgrade changes how the car drives or hits **and** reshapes the model itself (rebuilt in Blender, not stuck on).

All numbers below are first guesses for `src/shared/Config/Upgrades.luau` and will be tuned after a play test.

## 1. Mastery

Points go only to the car you are driving at the time.

| Action | Mastery points |
|---|---|
| Knock a person down for money (run over, giant hit, water cannon) | 10 |
| Run over a player | 25 |
| Hit a traffic car | 8 |
| Knock a hole in a building | 5 |
| Bring a whole building down | 50 |
| Land a jump | 10 |
| Driving | 1 per 500 studs (about 25 a minute flat out) |

Levels (points in that car, in total):

| Level | 1 | 2 | 3 | 4 | 5 (mastered) |
|---|---|---|---|---|---|
| Points | 100 | 300 | 650 | 1,200 | 2,000 |
| About (17 hits a minute) | 30 s | 1.5 min | 3.5 min | 6 min | 10 min |

What each level opens, the same plan on every car:

| Level | Unlocks |
|---|---|
| 1 | Upgrade I, decal **Racing Stripes** |
| 2 | decal **Race Number** (the car's bay number in a roundel) |
| 3 | Upgrade II, decal **Flames** |
| 4 | decal **Checker** |
| 5 | Upgrade III, the car's own **signature decal**, gold MASTERED tag in the garage |

A level-up shows a pop-up ("SEDAN MASTERY 3: Sport Rear unlocked") with confetti. No money is paid for levels
(money already piles up); the reward is the unlock. Old profiles start every car at 0.

## 2. Upgrade prices

Upgrade price = a share of the car's price, with a floor so starter cars aren't free:

| | Upgrade I | Upgrade II | Upgrade III |
|---|---|---|---|
| Share of car price | 10% | 20% | 30% |
| Floor | $300 | $750 | $1,500 |

| Car (price) | I | II | III | All three |
|---|---|---|---|---|
| Hatchback (free) | $300 | $750 | $1,500 | $2,550 |
| Scooter ($200) | $300 | $750 | $1,500 | $2,550 |
| Shopping Cart ($400) | $300 | $750 | $1,500 | $2,550 |
| Sedan ($3,000) | $300 | $750 | $1,500 | $2,550 |
| Taxi ($6,000) | $600 | $1,200 | $1,800 | $3,600 |
| Muscle Car ($25,000) | $2,500 | $5,000 | $7,500 | $15,000 |
| Ice-Cream Truck ($50,000) | $5,000 | $10,000 | $15,000 | $30,000 |
| Fire Truck ($70,000) | $7,000 | $14,000 | $21,000 | $42,000 |
| Semi Truck ($80,000) | $8,000 | $16,000 | $24,000 | $48,000 |
| Bulldozer ($100,000) | $10,000 | $20,000 | $30,000 | $60,000 |
| Monster Truck ($120,000) | $12,000 | $24,000 | $36,000 | $72,000 |
| Supercar ($150,000) | $15,000 | $30,000 | $45,000 | $90,000 |
| Roadster ($1,000,000; priced as $200,000) | $20,000 | $40,000 | $60,000 | $120,000 |

Everything on every car: about $400,000. Bought upgrades can be switched on and off in the garage (look and
stats go together); buying is once, per car.

## 3. Upgrades per vehicle

Each upgrade owns one **zone** of its car (Front, Rear, Roof, Sides, Wheels). The model is cut into those zones in
Blender; an upgrade's zone is rebuilt with new geometry and swapped in whole, so any mix of a car's three
upgrades fits together.

Effects are named after the garage's four stat bars (SPEED = top speed, ACCEL = launch and pull, HANDLING = grip
and steering, WEIGHT = how hard it hits and what a hit pays), as a share added to the car's own number. A few
upgrades do something only that car can do; those say so in words. REACH stretches the hit box in front of the
car by that many studs.

| Car | Upgrade | Zone | What changes on the model | Effect |
|---|---|---|---|---|
| **Hatchback** | I Rally Bumper | Front | front bumper rebuilt as a steel bash bar wrapped round the nose, tow hook, skid plate | +25% WEIGHT, +1 REACH |
| | II Hot Hatch Kit | Sides + Wheels | flared wheel arches, wider sills, wider wheels with 5-spoke rims | +15% HANDLING, +15% ACCEL |
| | III Rally Roof | Roof | roof rebuilt with a scoop, light pod and a roof spoiler | +15% SPEED, bigger holes in buildings |
| **Scooter** | I Racing Fairing | Front | nose fairing round the steering column with a bubble screen | +15% SPEED |
| | II Big Bore | Rear | engine cowl swollen into a bigger body, twin exhaust | +25% ACCEL |
| | III Balloon Tyres | Wheels | fat balloon tyres, wider mudguards | +15% HANDLING, +65% WEIGHT |
| **Shopping Cart** | I Battering Basket | Front | wire nose of the basket rebuilt as a plated steel ram | +150% WEIGHT |
| | II Rocket Handle | Rear | push handle with a bundle of firework rockets | +30% SPEED, +30% ACCEL |
| | III Monster Casters | Wheels | big chunky casters, basket lifted | +30% HANDLING |
| **Sedan** | I Push Bar | Front | police-style push bar built into the front bumper | +25% WEIGHT, +1 REACH |
| | II Sport Rear | Rear | rear bumper with diffuser and quad pipes, lip spoiler on the trunk | +15% ACCEL, +10% SPEED |
| | III Lowered Kit | Sides + Wheels | side skirts, body sits lower, wider tyres | +15% HANDLING |
| **Taxi** | I Mega Sign | Roof | roof sign rebuilt twice the size | taxi call reaches 50% further |
| | II Cow Catcher | Front | slatted cow catcher wedge on the nose | +30% WEIGHT, +1.5 REACH |
| | III Double Fare | Rear | luggage rack on the trunk and a second meter light | a taxi call brings **two** people |
| **Muscle Car** | I Blower | Roof (hood) | supercharger through the hood with a big scoop | +20% ACCEL |
| | II Wide Body | Sides + Wheels | riveted wide arches, fat rear tyres | +15% HANDLING, tail less loose |
| | III Ram Nose | Front | front end rebuilt as a sloped steel ram | +30% WEIGHT, +1 REACH |
| **Ice-Cream Truck** | I Giant Cone | Roof | roof cone rebuilt as a giant swirl cone | jingle reaches 40% further |
| | II Freezer Bumper | Front | huge chrome bumper shaped like an ice block | +30% WEIGHT, +1 REACH |
| | III Sound System | Sides | serving hatch rebuilt as a speaker stack, horns on the back | jingle pulls people faster, +15% SPEED |
| **Fire Truck** | I Big Cannon | Roof | turret rebuilt with a longer, wider barrel | cannon reaches 40% further, wider spray |
| | II Ram Bumper | Front | front bumper rebuilt as a heavy ram | +20% WEIGHT, +1.5 REACH |
| | III High-Pressure Pump | Sides | side lockers rebuilt as a pump panel with hose reels | cannon knocks 60% harder, +10% SPEED |
| **Semi Truck** | I Bull Bar | Front | big chrome bull bar round the grille | +20% WEIGHT, +1.5 REACH |
| | II Big Stacks | Roof | tall chrome stacks, sun visor, roof air horns | +20% ACCEL, +10% SPEED |
| | III Sweeper Trailer | Rear (trailer) | trailer side skirts with ram fins | trailer sweeps 3 studs wider each side |
| **Bulldozer** | I Big Blade | Front | a wider, taller curved U-blade: wings swung forward, teeth on the cutting edge, a spill guard on top | +2.5 REACH, 4 studs wider, throws people 50% further |
| | II Turbo Diesel | Roof | twin stacks with heat shields and flap caps, a big precleaner bowl on the hood | +30% SPEED, +25% ACCEL |
| | III Ripper | Rear | a three-shank ripper on a wide beam, curved shanks with steel tips | +45% HANDLING (spins faster), hits count behind it too |
| **Monster Truck** | I Light Bar & Cage | Roof | roll cage over the bed, light bar on the roof | jumps pay 25% more |
| | II Crusher Bumper | Front | toothed crusher bumper | +30% WEIGHT, +1 REACH |
| | III Mega Tyres | Wheels | tyres 12% bigger, deeper treads, lift kit raised | +10% SPEED, bigger bounces |
| **Supercar** | I Aero Nose | Front | deeper splitter with canards | +12% HANDLING |
| | II Swan Wing | Rear | ducktail replaced by a tall swan-neck wing | +8% HANDLING, thruster lasts 25% longer |
| | III Twin Turbo | Roof (engine deck) | louvred engine cover with twin intakes | +8% SPEED, thruster pushes 20% harder |
| **Roadster** | I Aero Nose | Front | a carbon splitter following the curve of the nose, end plates and canards | +10% HANDLING |
| | II Afterburner | Rear | a nozzle set into the rear in a body-coloured shroud, petals round a glowing core | rear jet pushes 20% harder and lasts 20% longer |
| | III Flight Fins | Sides | swept wings off the sills with upturned tips, two small tail fins | flies 20% faster and climbs 30% faster |

## 4. Decals

Decals print on a car's painted panels, over the paint colour (paint shows through everywhere the decal is
clear), so every decal works with every colour. One decal per car at a time, or none. Decals are free once the
level opens them. Each design is drawn once per car (by script, no outside art, no brand names or logos of real
companies), fitted to that car's own sides and top so nothing stretches.

| Decal | Level | Look |
|---|---|---|
| Racing Stripes | 1 | two white stripes over hood, roof and trunk |
| Race Number | 2 | white roundel on each door with the car's bay number (Hatchback 01 ... Roadster 13) |
| Flames | 3 | yellow-orange-red flames licking back from the front wheels |
| Checker | 4 | black-and-white checker band along the sides |
| Signature | 5 | one per car, below |

Signature decals: Hatchback **Lightning** (a bolt down each side), Scooter **Pizza Zoom** (a pizza slice with
speed lines), Shopping Cart **Mega Mart** (a made-up shop logo), Sedan **Pinstripe** (thin swoosh lines),
Taxi **Dice** (two dice and a checker band), Muscle Car **Thunder** (scallop flashes), Ice-Cream Truck
**Sprinkles**, Fire Truck **Station 13** (a crest), Semi Truck **Wings** (wings along the trailer), Bulldozer
**Hazard** (yellow-black chevrons), Monster Truck **Shark Mouth**, Supercar **Tricolore** (three-colour stripe),
Roadster **Galaxy** (stars and a nebula).

## 5. How it is built (short)

- **Models:** `tools/blender/export_vehicles.py` cuts each body (and its `_Paint` part) at the zone borders into
  `<Id>_Body` + zone pieces, and builds each upgrade's replacement zone as new geometry (`<Id>_Up<n>` plus its
  `_Paint` part; wheel upgrades as their own `Wheel_` sets). The importer still centres on the stock Body and
  wheels, so seats and cabins don't move. The game keeps only the pieces for the switched-on upgrades when it
  builds the car. Max 20k tris per mesh; most new pieces stay under 1k.
- **Decal printing:** the `_Paint` parts get one fixed UV layout (left side, right side, top), and a decal is a
  transparent image set as the part's texture; clear pixels show the paint colour. One image per decal per car,
  drawn by a Python script and uploaded under the 4725 Studio group.
- **Stats:** `Config/Upgrades` holds every number; a pure rule (`Rules/Upgrades`) turns a car's row plus its
  switched-on upgrades into the stats the server and the driving code use (the car model carries an
  `Upgrades` attribute).
- **Saves:** new profile fields `mastery` (car → points), `upgrades` (car → upgrade → on/off) and `decal`
  (car → decal id), all empty for old profiles.
- **Screens:** in the garage, the chosen car's panel gets its mastery bar and an UPGRADES / DECALS area next to
  paint (designed as a mock-up first). Points pop up next to hit cash while driving ("+10 MASTERY").
