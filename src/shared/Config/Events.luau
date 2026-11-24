--!strict
-- Server events: one every 1-5 minutes, announced ahead, running for a short while. The longer the wait, the
-- bigger the event (Tiers; Rules/Events picks the next one and its wait).
-- A contest event keeps a score per player while it runs (Rules/Contest) and pays the top 3 and everyone
-- who took part when it ends. stat: "Breaks" (building pieces), "Launch" (studs, best one), "Hits" or "Stunt" (one jump's
-- pay, best one), "Damage" (the Boss Truck). pay: "places" (the default: ContestPrizes) or "share" (a pot split
-- by score, Rules/Contest.shares).

export type Contest = {
	stat: "Breaks" | "Launch" | "Hits" | "Stunt" | "Damage",
	mode: "add" | "max",
	unit: string,
	pay: ("places" | "share")?,
}
export type Event = {
	key: string,
	title: string,
	text: string,
	color: string,
	tier: number, -- index into Tiers
	duration: number?, -- seconds; else its tier's
	contest: Contest?,
}
export type Tier = {
	key: string,
	name: string, -- on the NEXT EVENT sign
	color: string, -- Style.colors
	weight: number, -- how often this tier comes next
	gap: { number }, -- seconds from one event's end to the next one's start (warning included), min and max
	duration: number,
}

return table.freeze({
	-- quick small events after short gaps, contests in the middle, the big ones after the longest waits
	Tiers = table.freeze({
		table.freeze({
			key = "Quick",
			name = "QUICK",
			color = "green",
			weight = 40,
			gap = table.freeze({ 60, 120 }),
			duration = 60,
		}),
		table.freeze({
			key = "Contest",
			name = "CONTEST",
			color = "blue",
			weight = 35,
			gap = table.freeze({ 120, 210 }),
			duration = 90,
		}),
		table.freeze({
			key = "Big",
			name = "BIG EVENT",
			color = "gold",
			weight = 25,
			gap = table.freeze({ 210, 300 }),
			duration = 150,
		}),
	}) :: { Tier },
	TitleSeconds = 3.6, -- the big title is up this long (fade included); queued cards like the daily streak wait for it
	FirstAfter = 180, -- a new server's first event: 3 minutes in, after a first player's tutorial (its tier follows)
	WarnSeconds = 20, -- the banner counts down before it starts (part of the gap)
	-- an event won early (the crate claimed, the truck cracked, the boss beaten) ends this many seconds later
	EndLinger = 6,
	-- every new event payout (Money Truck, Cash Drop, Boss Truck) is its number below times this, then the
	-- player's money passes (Passes.moneyMultiplier). One number to retune them against hit pay.
	PayScale = 1,
	List = table.freeze({
		table.freeze({
			key = "LowGravity",
			title = "LOW GRAVITY",
			text = "Everything floats. Launches go to the moon.",
			color = "purple",
			tier = 1,
		}),
		table.freeze({
			key = "WreckingSpree",
			title = "WRECKING SPREE",
			text = "Smash the most building pieces. Top 3 win big!",
			color = "orange",
			tier = 2,
			contest = table.freeze({ stat = "Breaks", mode = "add", unit = "pieces" }),
		}),
		table.freeze({
			key = "GoldenRush",
			title = "GOLDEN RUSH",
			text = "Golden people are worth 10x. Find them!",
			color = "gold",
			tier = 1,
		}),
		table.freeze({
			key = "FlingFest",
			title = "FLING FEST",
			text = "Launch someone the farthest. Top 3 win big!",
			color = "blue",
			tier = 2,
			contest = table.freeze({ stat = "Launch", mode = "max", unit = "studs" }),
		}),
		table.freeze({
			key = "Giant",
			title = "GIANT IN TOWN",
			text = "A giant walks downtown. Hit it 5 times to topple it!",
			color = "red",
			tier = 3,
		}),
		table.freeze({
			key = "Rampage",
			title = "RAMPAGE",
			text = "Run over the most people. Top 3 win big!",
			color = "pink",
			tier = 2,
			contest = table.freeze({ stat = "Hits", mode = "add", unit = "hits" }),
		}),
		table.freeze({
			key = "Stampede",
			title = "STAMPEDE",
			text = "Crowds flood the streets and every hit pays double.",
			color = "green",
			tier = 1,
		}),
		table.freeze({
			key = "AirShow",
			title = "AIR SHOW",
			text = "Land the best jump. Top 3 win big!",
			color = "red",
			tier = 2,
			contest = table.freeze({ stat = "Stunt", mode = "max", unit = "points" }),
		}),
		table.freeze({
			key = "CashDrop",
			title = "CASH DROP",
			text = "A crate of cash is falling. First car to touch it wins!",
			color = "green",
			tier = 1,
		}),
		table.freeze({
			key = "MoneyTruck",
			title = "MONEY TRUCK",
			text = "Ram the armoured truck for cash. Crack it open for the jackpot!",
			color = "gold",
			tier = 3,
		}),
		table.freeze({
			key = "BossTruck",
			title = "BOSS TRUCK",
			text = "A monster truck runs wild. Wreck it together and split the pot!",
			color = "red",
			tier = 3,
			contest = table.freeze({
				stat = "Damage",
				mode = "add",
				unit = "points",
				pay = "share",
			}),
		}),
	}),
	LowGravityScale = 0.35,
	GoldenCount = 8,
	GoldenMultiplier = 10,
	GoldenRespawnChance = 0.25,
	GiantScale = 5,
	GiantHits = 5,
	GiantHitPay = 1500,
	GiantToppleBonus = 5000,
	-- the giant is stood on the real (colliding) ground under its spawn spot: a ray from Up studs over the
	-- spot (clear of kerbs, under lamps and trees) to Down studs below it; the feet start GiantSpawnLift over it
	GiantGroundProbe = table.freeze({ Up = 6, Down = 60 }),
	GiantSpawnLift = 0.5,
	GiantWalkSpeed = 24, -- studs/s; its walk animation slows to match its size (Rules/Crowd.walkAnimSpeed)
	-- finding the giant from anywhere (client/GiantFinder): a light column over it and a pointer on the
	-- screen edge with the distance. Colour: Config/Crowd Tags.Giant.
	GiantFinder = table.freeze({
		BeamHeight = 900, -- studs above the giant's head
		BeamGap = 12, -- studs of clear air between the top of its head and the column's foot
		BeamWidth = 10, -- studs
		BeamMinPixels = 6, -- added on screen, so it stays a few pixels wide from across the map
		BeamTransparency = 0.15,
		BeamCore = 0.35, -- the white middle stripe, as a share of the width
		HideWithin = 90, -- studs: closer than this the pointer hides and the name tag takes over
		EdgeMargin = 70, -- layout px kept clear at the screen edge
		AboveHead = 40, -- layout px: the on-screen marker sits this far above the giant's head
		PlateWidth = 104, -- layout px
		PlateHeight = 50,
		Pointer = 22, -- layout px: the room the pointer takes past the plate's edge
		PointerImage = 36, -- layout px: the pointer image's box (the wedge fills about two thirds of it)
		ClearGap = 10, -- layout px kept between the plate and the controls card or speedometer (Rules/Clear)
		ScanSeconds = 0.5, -- how often to look for the giant in the crowd
		Unit = "m", -- distance label: one stud is one of these
	}),
	-- Studio only: set this workspace attribute to an event key (e.g. "Giant") to start that event now
	StudioStartAttribute = "StartEvent",
	StampedeExtraNpcs = 25,
	StampedeMultiplier = 2,
	-- contests: places 1, 2, 3, then everyone else who scored at least once
	ContestPrizes = table.freeze({ 5000, 3000, 2000 }),
	ContestTakePart = 500,
	ContestFullField = 4, -- with fewer taking part, the top-3 prizes shrink in step (Rules/Contest.prizes)
	ContestShown = 3, -- standings sent to each player (the banner shows the leader and you)
	-- the event sign (top centre, src/client/EventBanner): one line (LIVE pill, title, timer) sitting in the
	-- empty middle of Roblox's top bar, plus one slim line under it during a contest. Layout px.
	Card = table.freeze({
		InTopBar = true, -- centred in the top bar; false puts it just under the bar
		Gap = 8, -- the gap under the bar when InTopBar is false
		Height = 42, -- the one-line sign (also NEXT EVENT and the shrunk chip)
		Width = 360, -- warn / live sign
		WidthNarrow = 320, -- on screens under NarrowPx real px wide (Studio, phones)
		NarrowPx = 1000,
		QuietWidth = 340, -- the next event's sign: tier pill, name, countdown
		ContestRow = 20, -- the contest line under the sign
		TitleText = 20,
		TimerText = 18,
		ContestText = 14,
	}),
	ContestSendSeconds = 1, -- standings to each player this often while one runs
	ContestMinLaunch = 10, -- studs: shorter flings don't count for Fling Fest

	-- the event vehicles (server/EventProps, client/EventProps) drive the road network (Rules/Route): in the lane
	-- right of the centre line, corners rounded this much. Speeds in studs/s, sizes in studs.
	RouteLane = 11,
	RouteCorner = 32,
	RouteStraight = 3, -- straight on at a crossing is this many times likelier than each turn
	RouteAhead = 4, -- crossings kept planned ahead of the vehicle
	-- it starts on a crossing this far from a player picked at random, so everyone has a way to go
	StartFrom = table.freeze({ 350, 900 }),
	CrashSpeed = 9, -- m/s: a hit counts at this closing speed, with the hitter driving into it at least this fast
	CrashReach = 10, -- studs of slack on the server's check, past both vehicles' sizes
	HitGap = 1, -- seconds between counted hits from one player
	Bounce = 0.45, -- the hitter's car bounces back with this share of its speed
	BounceUp = 18, -- studs/s up
	-- the health bar over an event vehicle (layout px; studs over its roof)
	HpBar = table.freeze({ Width = 220, Height = 22, Above = 6, Text = 16 }),

	-- Money Truck (tier 3): an armoured van drives a route; every hit spills cash, the last hit cracks it
	MoneyTruck = table.freeze({
		Vehicle = "IceCream", -- the model (ReplicatedStorage.VehicleModels), repainted
		Scale = 1.35, -- times Game.VehicleScale
		Paint = table.freeze({ 52, 78, 60 }), -- armour green
		Trim = table.freeze({ 255, 196, 40 }), -- gold
		Speed = 40,
		Hits = 6, -- to crack it with one player in the server...
		HitsPerPlayer = 2, -- ...plus this many for each other player...
		HitsMax = 16, -- ...up to this
		SpillCount = 3, -- cash bundles each hit throws out
		SpillValue = 300,
		Jackpot = 8000, -- to whoever cracks it
		JackpotSpill = 8, -- and this many bundles burst out for anyone
		Mark = "TRUCK", -- the screen-edge pointer's word
	}),
	-- the cash bundles a hit spills (pooled parts): grabbed by driving or walking through them
	Cash = table.freeze({
		Max = 40,
		Life = 25, -- seconds before an untouched bundle goes
		Radius = 10, -- studs from a player to grab it
		Spread = table.freeze({ 12, 28 }), -- studs from the hit, min and max
		Size = table.freeze({ 3.2, 1.4, 1.8 }),
		Color = table.freeze({ 60, 200, 90 }),
	}),
	-- Cash Drop (tier 1): a crate parachutes onto a street; the first car to touch it after it lands wins
	CashDrop = table.freeze({
		Value = 2500,
		FallSeconds = 12,
		FallHeight = 320, -- studs above the street it starts at
		Radius = 16, -- studs from the crate's middle to a player to claim it
		From = table.freeze({ 350, 1100 }), -- studs from a player picked at random
		CrateSize = 10,
		ChuteSize = table.freeze({ 36, 12 }), -- canopy width and height
		RingSize = 46, -- the landing ring on the street
		Mark = "CASH",
	}),
	-- Boss Truck (tier 3): a huge monster truck chases players; hit it to wear it down, the pot is split by damage
	BossTruck = table.freeze({
		Vehicle = "Monster",
		Scale = 2.4, -- times Game.VehicleScale
		Paint = table.freeze({ 200, 30, 30 }),
		Speed = 44,
		ChaseRange = 1600, -- studs: it heads for the nearest player this close, else roams
		Hp = 240, -- with one player in the server...
		HpPerPlayer = 140, -- ...plus this for each other player
		-- one hit's damage: Damage at DamageSpeed m/s closing speed in a WeightRef kg car, in step with speed
		-- and the square root of weight, between DamageMin and DamageMax
		Damage = 20,
		DamageSpeed = 25,
		WeightRef = 1500,
		DamageMin = 6,
		DamageMax = 60,
		Pot = 20000, -- split by damage done when it's beaten...
		FailShare = 0.4, -- ...or this share of it when time runs out first
		MinShare = 500, -- anyone who hit it gets at least this
		-- every SlamEvery seconds it slams the ground (a ring warns SlamWarn seconds ahead): every player within
		-- SlamRadius is thrown away from it
		SlamEvery = 5,
		SlamWarn = 1.2,
		SlamRadius = 85, -- the truck is about 80 studs long: this reaches ~45 past its nose
		SlamPush = 85, -- studs/s out
		SlamUp = 70, -- studs/s up
		SlamDown = 1.6, -- seconds without control
		Mark = "BOSS",
	}),
})
