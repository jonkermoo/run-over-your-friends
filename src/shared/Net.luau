--!strict
-- The ONLY place client/server message names are defined.
-- Add a name here, then use Net.remote(name) on both sides.

local Net = {}

Net.Messages = table.freeze({
	-- client -> server
	SpawnVehicle = "SpawnVehicle", -- (vehicleId)
	DespawnVehicle = "DespawnVehicle", -- ()
	BuyVehicle = "BuyVehicle", -- (vehicleId)
	BuyPass = "BuyPass", -- (passName): real purchase prompt, or a test toggle in Studio
	BuyProduct = "BuyProduct", -- (productKey): Robux money pack or starter pack
	ClaimGroup = "ClaimGroup", -- (): pays the group reward once, if the player is in Economy.GroupId
	HitNpc = "HitNpc", -- (npc: Model, velocity: Vector3)
	BreakAt = "BreakAt", -- (position: Vector3, velocity: Vector3)
	KnockProp = "KnockProp", -- (prop: Model, velocity: Vector3): street furniture hit by a vehicle
	PlayerHit = "PlayerHit", -- (target: Model, velocity: Vector3): the driver's vehicle hit a player or their vehicle
	Feature = "Feature", -- (feature: string)
	HitTraffic = "HitTraffic", -- (carId: number, velocity: Vector3): the driver's vehicle ran into a traffic car
	Horn = "Horn", -- client -> server: () honk; server -> other clients: (vehicle: Model)
	BuyPaint = "BuyPaint", -- (paintId): pay once for a colour (Config/Paints)
	SetPaint = "SetPaint", -- (vehicleId, paintId): the colour that vehicle wears
	BuyUpgrade = "BuyUpgrade", -- (vehicleId, n): pay once for a car's mastery upgrade n (Config/Upgrades); it goes on
	SetUpgrade = "SetUpgrade", -- (vehicleId, n, on: boolean): switch a bought upgrade on or off
	SetDecal = "SetDecal", -- (vehicleId, decalId): the decal that vehicle wears ("None" takes it off)
	ClaimDaily = "ClaimDaily", -- (): collect today's login streak reward
	ClaimGift = "ClaimGift", -- (): claim the next play-time gift once it has opened (Config/Gifts)
	TutorialClaim = "TutorialClaim", -- (): the tutorial's first goal, claimed from its CLAIM pop-up (client/Guide)
	TutorialSkip = "TutorialSkip", -- (step: number): skip the tutorial step the job card shows
	-- (action: "Shown" | "Start" | "Decline" | "Restart"): the first-join tutorial offer showed, was answered, or
	-- the menu strip's TUTORIAL tab was pressed (server/Onboarding checks each against the saved answer)
	TutorialOffer = "TutorialOffer",
	TutorialTour = "TutorialTour", -- (page: string): the garage tour reached a page (Config/Onboarding TourPages)
	SetMusic = "SetMusic", -- (off: boolean): the background music on or off, saved
	SetRideMode = "SetRideMode", -- (mode: string): who may ride in my car (Config/Riders Modes), saved
	StarterDealSeen = "StarterDealSeen", -- (): the Starter Pack card showed; starts its discount window once
	OpenChest = "OpenChest", -- (set: "Daily" | "Weekly"): open one of your unopened challenge chests
	-- (kind: "Open" | "View" | "Offer" | "State" | "Ready", a, b): client-only facts for analytics, each value
	-- from a fixed set in Config/Analytics (server/Analytics checks and rate-limits them)
	Track = "Track",
	-- (action: "Offered" | "Start"): the garage showed the Roadster's FREE TRIAL button, or it was pressed
	-- (starts a trial, or brings the trial car back while one runs); server/TrialService checks everything
	RoadsterTrial = "RoadsterTrial",
	HitEventProp = "HitEventProp", -- (velocity: Vector3): the driver's vehicle ran into the live event's truck (server/EventProps checks)
	MapOpen = "MapOpen", -- (open: boolean): the city map opened or closed; the server sends MapDots only while it's open
	-- server -> client
	-- (spots: { number }, leader: number, eventX: number?, eventZ: number?): every player's spot packed by
	-- Rules/CityMap.pack, the live contest's leader (user id, 0 = none) and the live event's spot (the giant)
	MapDots = "MapDots",
	TrialOver = "TrialOver", -- (): the Roadster trial ended on time; the end card shows (client/Trial)
	FriendNames = "FriendNames", -- ({ [friendKey: string]: name }): names of this player's own friends in the crowd (FriendKey attribute)
	Traffic = "Traffic", -- (snapshot: buffer): every traffic car, packed by TrafficService (Rules/Roads CarBytes)
	TrafficCrash = "TrafficCrash", -- (carId, gen, fling: Vector3, hitterUserId): a traffic car is wrecked
	Fling = "Fling", -- (kind: "Character" | "Vehicle", velocity: Vector3, spin: Vector3, seconds: number): down/no control for seconds
	Popup = "Popup", -- (text: string, kind: string)
	Mastery = "Mastery", -- (vehicleId, points: number, total: number, level: number?): points just earned in that car; level when it went up
	Celebrate = "Celebrate", -- (title: string, subtitle: string): confetti moment
	Goals = "Goals", -- (state: { Hourly: Set, Daily: Set }): the player's current goal sets
	Fx = "Fx", -- (kind: "Hit" | "Land" | "Break" | "Dodge" | "Honk", position: Vector3, a: number, b: number, userId: number)
	-- (bursts: { Burst }, at: Vector3, push: Vector3): parts broken by one hit, each { cf, size, color, material,
	-- transparency, shape, part, na, nb, fly } (src/client/Crumble); every screen throws their bricks itself
	Crumble = "Crumble",
	Collapse = "Collapse", -- (building: Model, at: Vector3, push: Vector3, pay: number, userId: number): a whole building comes down
	Contest = "Contest", -- (state: { key: string, top: { { name: string, score: number } }, place: number, score: number, count: number })
	Boards = "Boards", -- ({ endsAt, now, boards: { [key]: { Entry } }, you: { [key]: You } }): the leaderboards, per player
	ServerGoal = "ServerGoal", -- (set: { goals: { Goal }, endsAt: number }?, now: number): the shared server goal, nil between goals
	Daily = "Daily", -- ({ streak: number, ready: boolean }): the streak (what collecting would make it when ready)
	-- ({ daily: { View }, dailyEnds: number, weekly: { View }, weeklyEnds: number, chests: { Daily: number,
	-- Weekly: number }, day: number }, now: number): this player's challenges (Rules/Challenges view)
	Challenges = "Challenges",
	ChestPrize = "ChestPrize", -- (set: string, cash: number, paint: string): what the chest just opened held ("" = no paint)
	-- ({ title: string, unit: string, top: { { id: number, name: string, score: number, prize: number } }, place: number,
	-- score: number, prize: number }): a contest just ended; place 0 when you didn't take part
	Podium = "Podium",
})

export type MessageName =
	"SpawnVehicle"
	| "DespawnVehicle"
	| "BuyVehicle"
	| "BuyPass"
	| "BuyProduct"
	| "ClaimGroup"
	| "FriendNames"
	| "HitNpc"
	| "BreakAt"
	| "KnockProp"
	| "PlayerHit"
	| "Feature"
	| "Horn"
	| "HitTraffic"
	| "Traffic"
	| "TrafficCrash"
	| "BuyPaint"
	| "SetPaint"
	| "ClaimDaily"
	| "ClaimGift"
	| "TutorialClaim"
	| "TutorialSkip"
	| "TutorialOffer"
	| "TutorialTour"
	| "Fling"
	| "Popup"
	| "Celebrate"
	| "Goals"
	| "Fx"
	| "Crumble"
	| "Collapse"
	| "Contest"
	| "Boards"
	| "Daily"
	| "SetMusic"
	| "SetRideMode"
	| "Podium"
	| "ServerGoal"
	| "Track"
	| "OpenChest"
	| "Challenges"
	| "ChestPrize"
	| "RoadsterTrial"
	| "TrialOver"
	| "HitEventProp"
	| "MapOpen"
	| "MapDots"

-- Roblox services are fetched lazily so the name table above stays testable in Lune.
function Net.remote(name: MessageName): RemoteEvent
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		assert(RunService:IsServer(), "Remotes folder missing; the server must create it first")
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		folder = created
	end
	local remote = folder:FindFirstChild(name)
	if not remote then
		assert(RunService:IsServer(), "Remote missing: " .. name)
		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Parent = folder
		remote = created
	end
	return remote :: RemoteEvent
end

-- client side: wait for the server to make it
function Net.waitFor(name: MessageName): RemoteEvent
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
