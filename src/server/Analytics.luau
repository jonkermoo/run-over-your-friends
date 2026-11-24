--!strict
-- Roblox analytics (Creator Hub > Analytics): the first-session funnel, money in and out, and custom events
-- for the purchase funnel, joins and leaves, load time, goals and live events (all listed in docs/ANALYTICS.md).
-- Every call is wrapped so analytics can never break the game. Money earned by playing is added up and sent
-- once a minute per player, so busy players don't flood the economy log. Client-only facts (store opened, item
-- viewed, the offer cards, menu / idle state, load time and device) come in on Net "Track", each value checked
-- against a fixed set in Config/Analytics and rate-limited. Custom fields: 01 and 02 per event, 03 the device.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cfg = require(ReplicatedStorage.Shared.Config.Analytics)
local EventConfig = require(ReplicatedStorage.Shared.Config.Events)
local Net = require(ReplicatedStorage.Shared.Net)
local Offer = require(ReplicatedStorage.Shared.Rules.Offer)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Rules = require(ReplicatedStorage.Shared.Rules.Analytics)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)

local Analytics = {}

-- in Studio every custom event is also printed, so a play test shows what would be sent
local echo = RunService:IsStudio()

local F1 = Enum.AnalyticsCustomFieldKeys.CustomField01.Name
local F2 = Enum.AnalyticsCustomFieldKeys.CustomField02.Name
local F3 = Enum.AnalyticsCustomFieldKeys.CustomField03.Name

-- the first-session funnel, in order. Step numbers never change once live: Roblox names each number by the
-- events it has seen, so renumbering mixes steps up on the dashboard. Step 5 ("Took a ramp") left the
-- tutorial on 2026-11-20; it is now logged together with step 4 so the funnel stays continuous (docs/ANALYTICS.md)
Analytics.Steps = table.freeze({
	Joined = 1,
	SpawnedCar = 2,
	FirstHit = 3,
	FirstRampage = 4,
	TookRamp = 5, -- retired: logged with FirstRampage
	SmashedBuilding = 6,
	ClaimedGoal = 7,
	FirstPurchase = 8,
	JoinedEvent = 9,
	TutorialDone = 10,
})
local STEP_NAMES = {
	"Joined",
	"Spawned a car",
	"First hit",
	"First rampage",
	"Took a ramp",
	"Smashed a building",
	"Claimed a goal",
	"First vehicle bought",
	"Joined an event",
	"Tutorial done",
}

local reached: { [Player]: { [number]: boolean } } = {}
local pendingEarn: { [Player]: number } = {}

-- per player, for this session
type Session = {
	joinedAt: number, -- os.clock
	playersAtJoin: number,
	joinLogged: boolean,
	ready: boolean, -- the client's Ready came in
	device: string,
	state: string, -- Config/Analytics States, from the client
	where: string, -- where the next purchase comes from: Store, Garage, Starter, Upsell, Other
	prompts: { [string]: string }, -- item -> where, for prompts not answered yet
	viewed: { [string]: boolean },
	eventRun: number, -- the live event run this player last took part in
	bucket: Rules.Bucket,
	inSeat: boolean, -- sitting in a car's driver seat (kept up while they play: at leave the car is already gone)
	seatLeftAt: number?, -- os.clock when they last got out of a driver seat
}
local sessions: { [Player]: Session } = {}
local eventRun = 0

local function safe(f: () -> ())
	local ok, err = pcall(f)
	if not ok then
		warn("analytics:", err)
	end
end

local function balance(player: Player): number
	return math.floor((player:GetAttribute("Money") or 0) :: number)
end

local function session(player: Player): Session
	local s = sessions[player]
	if not s then
		s = {
			joinedAt = os.clock(),
			playersAtJoin = #Players:GetPlayers(),
			joinLogged = false,
			ready = false,
			device = "Unknown",
			state = "Active",
			where = "Other",
			prompts = {},
			viewed = {},
			eventRun = 0,
			bucket = { tokens = Cfg.TrackBurst, at = os.clock() },
			inSeat = false,
		}
		sessions[player] = s
	end
	return s
end

-- a custom event with up to two fixed-set fields; field 03 is always the player's device
local function log(player: Player, name: string, value: number, f1: string?, f2: string?)
	local s = session(player)
	local fields = { [F3] = s.device }
	if f1 then
		fields[F1] = f1
	end
	if f2 then
		fields[F2] = f2
	end
	if echo then
		print(`[analytics] {name} value={value} f1={f1 or "-"} f2={f2 or "-"} device={s.device}`)
	end
	safe(function()
		AnalyticsService:LogCustomEvent(player, name, value, fields :: any)
	end)
end

-- each step once per session
function Analytics.step(player: Player, step: number)
	local seen = reached[player]
	if not seen then
		seen = {}
		reached[player] = seen
	end
	if seen[step] then
		return
	end
	seen[step] = true
	if echo then
		print(`[analytics] funnel step {step} {STEP_NAMES[step]}`)
	end
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, STEP_NAMES[step])
	end)
	if step == Analytics.Steps.FirstRampage then
		Analytics.step(player, Analytics.Steps.TookRamp) -- the retired ramp step, so step 6 follows on
	end
end

-- money earned by running people over (batched)
function Analytics.earned(player: Player, amount: number)
	pendingEarn[player] = (pendingEarn[player] or 0) + amount
end

local function flushEarn(player: Player)
	local amount = math.floor(pendingEarn[player] or 0)
	pendingEarn[player] = nil
	if amount > 0 then
		safe(function()
			AnalyticsService:LogEconomyEvent(
				player,
				Enum.AnalyticsEconomyFlowType.Source,
				"Money",
				amount,
				balance(player),
				Enum.AnalyticsEconomyTransactionType.Gameplay.Name
			)
		end)
	end
end

-- one-off money in: goal rewards, packs, the like reward, the Roadster pass
function Analytics.source(
	player: Player,
	amount: number,
	kind: Enum.AnalyticsEconomyTransactionType,
	sku: string
)
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Money",
			math.floor(amount),
			balance(player),
			kind.Name,
			sku
		)
	end)
end

-- money out: buying a vehicle
function Analytics.spent(player: Player, amount: number, sku: string)
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Sink,
			"Money",
			math.floor(amount),
			balance(player),
			Enum.AnalyticsEconomyTransactionType.Shop.Name,
			sku
		)
	end)
end

function Analytics.custom(
	player: Player,
	name: string,
	value: number?,
	fields: { [string]: string }?
)
	safe(function()
		if fields then
			AnalyticsService:LogCustomEvent(player, name, value or 1, fields :: any)
		else
			AnalyticsService:LogCustomEvent(player, name, value or 1)
		end
	end)
end

---------------- joins and leaves

local function logJoin(player: Player)
	local s = session(player)
	if s.joinLogged then
		return
	end
	s.joinLogged = true
	log(
		player,
		"PlayerJoined",
		s.playersAtJoin,
		Rules.countBucket(s.playersAtJoin, Cfg.PlayerBuckets)
	)
end

-- keep the session's driver-seat flag up while the player plays
local function watchSeat(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", Cfg.HumanoidWaitSeconds)
	if not (humanoid and humanoid:IsA("Humanoid")) then
		return
	end
	local function set(seat: Instance?)
		local s = sessions[player]
		-- an old character's late signals must not undo the new one's seat
		if not s or player.Character ~= character then
			return
		end
		local now = seat ~= nil and seat.Name == "DriverSeat"
		if s.inSeat and not now then
			s.seatLeftAt = os.clock()
		end
		s.inSeat = now
	end
	set(humanoid.SeatPart)
	humanoid.Seated:Connect(function(active, seat)
		set(if active then seat else nil)
	end)
	humanoid.Destroying:Connect(function()
		set(nil)
	end)
end

local function driving(player: Player): boolean
	local s = session(player)
	local ago = if s.seatLeftAt then os.clock() - s.seatLeftAt else nil
	return Rules.wasDriving(s.inSeat, ago, Cfg)
end

-- the server's player count (the leaver included), how long they played and what they were doing
local function logLeave(player: Player)
	local s = session(player)
	logJoin(player) -- left before the client was ready: the join still counts
	local minutes = (os.clock() - s.joinedAt) / 60
	local rounded = math.floor(minutes * 10 + 0.5) / 10
	local span = Rules.rangeBucket(minutes, Cfg.MinuteBuckets)
	local hitAt = player:GetAttribute("HitAt") -- PlayerHitService: when another player's car last flung them
	local activity = Rules.activity({
		driving = driving(player),
		menu = s.state == "Menu",
		idle = s.state == "Idle",
		wreckedAgo = if typeof(hitAt) == "number"
			then workspace:GetServerTimeNow() - hitAt
			else nil,
	}, Cfg)
	log(
		player,
		"PlayerLeft",
		rounded,
		Rules.countBucket(#Players:GetPlayers(), Cfg.PlayerBuckets),
		span
	)
	log(player, "LeftWhile", rounded, activity, span)
	-- how far along the cars they were, so retention can be read against progress
	local owned = 0
	for _, id in string.split((player:GetAttribute("Owned") or "") :: string, ",") do
		if Vehicles.ById[id] then
			owned += 1
		end
	end
	log(player, "LeftOwning", rounded, Rules.countBucket(owned, Cfg.CarBuckets), span)
end

---------------- the purchase funnel: store opened -> item viewed -> prompt shown -> bought / cancelled
-- items: "Product:<key>" (Config/Products), "Pass:<name>" (Config/Economy Passes), "Car:<vehicle id>"

-- a Robux purchase prompt is about to show
function Analytics.prompted(player: Player, item: string)
	safe(function()
		local s = session(player)
		s.prompts[item] = s.where
		log(player, "PurchasePrompted", 1, item, s.where)
	end)
end

-- the prompt closed (MarketplaceService's finished signals): bought, or closed without buying
function Analytics.promptDone(player: Player, item: string, bought: boolean)
	safe(function()
		local s = session(player)
		local where = s.prompts[item] or s.where
		s.prompts[item] = nil
		log(player, if bought then "PurchaseBought" else "PurchaseCancelled", 1, item, where)
	end)
end

-- a vehicle bought with game money (no prompt: bought straight from the garage)
function Analytics.boughtWithMoney(player: Player, vehicleId: string, price: number)
	safe(function()
		log(player, "PurchaseBought", math.floor(price), "Car:" .. vehicleId, session(player).where)
	end)
end

-- before a car bought with game money: is it the player's first? Cars from the Roadster pass or the Starter
-- Pack don't count as bought
function Analytics.isFirstCar(
	owned: { [string]: boolean },
	roadsterPass: boolean,
	bought: { [string]: boolean }
): boolean
	local gifted: { [string]: boolean } = {}
	if roadsterPass then
		gifted.Roadster = true
	end
	if bought[Offer.onceKey(Products.Starter)] then
		for _, id in Products.Starter.vehicles or {} do
			gifted[id] = true
		end
	end
	return Rules.firstBought(owned, Vehicles.Starter, gifted)
end

-- the first vehicle the player bought beyond the starter, and their total minutes played until then
function Analytics.firstVehicle(player: Player, vehicleId: string, playSeconds: number)
	safe(function()
		local minutes = playSeconds / 60
		log(
			player,
			"FirstVehicleBought",
			math.floor(minutes + 0.5),
			vehicleId,
			Rules.rangeBucket(minutes, Cfg.PlayMinuteBuckets)
		)
	end)
end

-- an hourly or daily goal reached and paid (set: "Hourly" | "Daily", kind: the goal template's kind)
function Analytics.goal(player: Player, set: string, kind: string)
	safe(function()
		log(player, "GoalClaimed", 1, kind, set)
	end)
end

-- a daily or weekly challenge finished (set: "Daily" | "Weekly", id: its Config/Challenges template id)
function Analytics.challenge(player: Player, set: string, id: string)
	safe(function()
		log(player, "ChallengeDone", 1, id, set)
	end)
end

-- a challenge chest opened: value is the cash it paid, field 2 the paint it gave ("Cash" for none)
function Analytics.chest(player: Player, set: string, cash: number, paint: string?)
	safe(function()
		log(player, "ChestOpened", cash, set, if paint then "Paint:" .. paint else "Cash")
	end)
end

-- a tutorial step left without finishing it: field 01 the step's name (Config/Onboarding Steps) or
-- "EventTimeout" when the event step ended itself, field 02 the seconds spent on it, bucketed
function Analytics.tutorialSkipped(player: Player, stepName: string, seconds: number)
	safe(function()
		log(player, "TutorialSkipped", 1, stepName, Rules.rangeBucket(seconds, Cfg.SkipBuckets))
	end)
end

-- the first-join tutorial offer: field 01 the stage (Shown / Accepted / Declined / Restarted / RewardPaid), field 02
-- where (First: the first join, Again: the join after a "No thanks", Button: the menu strip's TUTORIAL tab);
-- RewardPaid's value is the bonus paid
function Analytics.tutorialOffer(player: Player, stage: string, where: string, value: number?)
	safe(function()
		if
			Rules.oneOf(Cfg.TutorialOfferStages, stage)
			and Rules.oneOf(Cfg.TutorialOfferWhere, where)
		then
			log(player, "TutorialOffer", value or 1, stage, where)
		end
	end)
end

-- the garage tour reached a page (Config/Onboarding TourPages), field 01 the page
function Analytics.tutorialTour(player: Player, page: string)
	safe(function()
		log(player, "TutorialTour", 1, page)
	end)
end

---------------- car progression and the Roadster free trial

-- a car came to the player (bought with cash, from a pass or a pack): field 01 the car, field 02 how many cars
-- they own now (the starter included), value their total minutes played
function Analytics.carOwned(
	player: Player,
	vehicleId: string,
	owned: { [string]: boolean },
	playSeconds: number
)
	safe(function()
		local count = tostring(Rules.carCount(owned))
		log(player, "CarOwned", math.floor(playSeconds / 60 + 0.5), vehicleId, count)
	end)
end

-- after any money or garage change: cash reached 25/50/75/100% of the cheapest car not owned yet, each step
-- once per car (kept in progress: vehicle id -> highest step logged); value the total minutes played. Waits for the
-- client's Ready (its device), so a join logs nothing until cash next changes
function Analytics.progress(
	player: Player,
	owned: { [string]: boolean },
	cash: number,
	progress: { [string]: number },
	playSeconds: number
)
	safe(function()
		local s = sessions[player]
		if not (s and s.ready) then
			return -- the device isn't known yet; the next money change catches up
		end
		local car = Rules.nextCar(Vehicles.List, owned)
		if not car then
			return
		end
		local steps = Rules.newMilestones(cash, car.price, progress[car.id] or 0, Cfg.ProgressSteps)
		for _, step in steps do
			progress[car.id] = step
			log(
				player,
				"NextCarProgress",
				math.floor(playSeconds / 60 + 0.5),
				car.id,
				tostring(step)
			)
		end
	end)
end

-- the Roadster free trial: stage Offered | Started | Ended | Converted (Config/Analytics TrialStages); ended:
-- why (Time | Left | Bought)
function Analytics.trial(player: Player, stage: string, ended: string?)
	safe(function()
		log(player, "RoadsterTrial", 1, stage, ended)
	end)
end

-- a hit, smash or stunt while an event is live counts as joining it, once per event run
function Analytics.tookPart(player: Player)
	safe(function()
		local key = workspace:GetAttribute("Event")
		local s = sessions[player]
		if typeof(key) ~= "string" or not s or s.eventRun == eventRun then
			return
		end
		s.eventRun = eventRun
		log(player, "EventJoined", 1, key)
	end)
end

-- a live event ended: logged once per run, on one player in the server. value = players who took part;
-- outcome "Won" (claimed, cracked, beaten) or "Time" (ran out)
function Analytics.eventEnded(key: string, outcome: string)
	safe(function()
		local joined, anyone = 0, nil
		for p, s in sessions do
			anyone = anyone or p
			if s.eventRun == eventRun then
				joined += 1
			end
		end
		if anyone then
			log(anyone, "EventEnded", joined, key, outcome)
		end
	end)
end

-- event money paid to a player (a prize, a share, a jackpot, cash grabbed): value = the amount
function Analytics.eventPaid(player: Player, key: string, kind: string, amount: number)
	safe(function()
		log(player, "EventPaid", math.floor(amount + 0.5), key, kind)
	end)
end

---------------- client-only facts (Net "Track")

local function onTrack(player: Player, kind: any, a: any, b: any, c: any)
	local s = sessions[player] -- none once the player has left: a late message is dropped
	if not s or not Rules.take(s.bucket, os.clock(), Cfg) then
		return
	end
	if kind == "Open" and Rules.oneOf(Cfg.Sheets, a) then
		s.where = a
		log(player, "StoreOpened", 1, a)
	elseif kind == "View" and Rules.oneOf(Cfg.Sheets, a) then
		local item: string? = nil
		if a == "Garage" and typeof(b) == "string" and Vehicles.ById[b] then
			item = "Car:" .. b
		elseif a == "Store" and Rules.oneOf(Cfg.StoreSections, b) then
			item = "Section:" .. b
		end
		if item and not s.viewed[item] then
			s.viewed[item] = true
			log(player, "ItemViewed", 1, item, a)
		end
	elseif kind == "Offer" and Rules.oneOf(Cfg.Offers, a) and Rules.oneOf(Cfg.OfferStages, b) then
		if b == "Pressed" then
			s.where = a
		end
		log(player, "OfferPopup", 1, a, b)
	elseif kind == "State" and Rules.oneOf(Cfg.States, a) then
		s.state = a
	elseif kind == "Ready" and not s.ready and Rules.oneOf(Cfg.Devices, a) then
		s.ready = true
		s.device = a
		local seconds = Rules.seconds(b, Cfg.MaxLoadSeconds)
		if seconds then
			log(
				player,
				"LoadTime",
				math.floor(seconds * 10 + 0.5) / 10,
				Rules.rangeBucket(seconds, Cfg.LoadBuckets),
				if c == true then "Ready" else "Timeout"
			)
		end
		logJoin(player)
	end
end

function Analytics.start()
	local function onPlayer(player: Player)
		session(player)
		local function onCharacter(character: Model)
			task.spawn(function()
				safe(function()
					watchSeat(player, character)
				end)
			end)
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
		Analytics.step(player, Analytics.Steps.Joined)
		-- no Ready from the client in time: log the join anyway
		task.delay(Cfg.ReadyWaitSeconds, function()
			if player.Parent and sessions[player] then
				safe(function()
					logJoin(player)
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		flushEarn(p)
		safe(function()
			logLeave(p)
		end)
		-- a moment later, so other leave handlers (a trial ending) still log with the player's device
		task.defer(function()
			reached[p] = nil
			sessions[p] = nil
		end)
	end)
	Net.remote("Track").OnServerEvent:Connect(function(player, kind, a, b, c)
		safe(function()
			onTrack(player, kind, a, b, c)
		end)
	end)
	-- each live event: who was in the server when it started (EventSeen); EventJoined counts who took part
	workspace:GetAttributeChangedSignal("Event"):Connect(function()
		local key = workspace:GetAttribute("Event")
		if typeof(key) ~= "string" then
			return
		end
		eventRun += 1
		local tier = ""
		for _, e in EventConfig.List do
			if e.key == key then
				tier = EventConfig.Tiers[e.tier].key
			end
		end
		for _, p in Players:GetPlayers() do
			log(p, "EventSeen", 1, key, tier)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for player in pendingEarn do
				flushEarn(player)
			end
		end
	end)
end

return Analytics
