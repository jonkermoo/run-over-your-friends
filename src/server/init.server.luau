--!strict
-- Server entry: collision groups, the world, then every service.

local GroupService = game:GetService("GroupService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)

-- every remote exists before any client asks for it
for name in Net.Messages do
	Net.remote(name :: any)
end

-- Vehicles pass through players, NPCs, debris and each other: NPC and player hits are found by overlap.
-- The one exception: player cars' collider boxes (CarBodies) bump into each other and the world.
for _, g in
	{ "Vehicles", "Characters", "Npcs", "Debris", "Furniture", "CarBodies", "Props", "Giant" }
do
	PhysicsService:RegisterCollisionGroup(g)
end
for _, g in { "Vehicles", "Characters", "Npcs", "Debris", "Furniture" } do
	PhysicsService:CollisionGroupSetCollidable("CarBodies", g, false)
end
-- furniture inside buildings (each client's own) stops people on foot, nothing else
for _, g in { "Vehicles", "Npcs", "Debris", "Furniture" } do
	PhysicsService:CollisionGroupSetCollidable("Furniture", g, false)
end
PhysicsService:CollisionGroupSetCollidable("Vehicles", "Vehicles", false)
PhysicsService:CollisionGroupSetCollidable("Vehicles", "Characters", false)
PhysicsService:CollisionGroupSetCollidable("Vehicles", "Npcs", false)
PhysicsService:CollisionGroupSetCollidable("Vehicles", "Debris", false)
PhysicsService:CollisionGroupSetCollidable("Npcs", "Characters", false)
-- people walk through each other instead of shoving into clumps
PhysicsService:CollisionGroupSetCollidable("Npcs", "Npcs", false)
-- the giant (Giant in Town) collides like a person, but strides through street props (Props: lamps, signals,
-- trees, benches...), which stopped it dead at every corner; everything else meets props as it always did
for _, g in PhysicsService:GetRegisteredCollisionGroups() do
	PhysicsService:CollisionGroupSetCollidable(
		"Giant",
		g.name,
		PhysicsService:CollisionGroupsAreCollidable("Npcs", g.name)
	)
end
PhysicsService:CollisionGroupSetCollidable("Giant", "Props", false)

local Data = require(script.Data)
local Passes = require(script.Passes)
local HitGuard = require(script.HitGuard)
local VehicleService = require(script.VehicleService)
local CrowdService = require(script.CrowdService)
local NpcService = require(script.NpcService)
local BuildingService = require(script.BuildingService)
local PlayerHitService = require(script.PlayerHitService)
local MapBuilder = require(script.MapBuilder)
local OnboardingService = require(script.Onboarding)
local QuestService = require(script.QuestService)
local ChallengeService = require(script.ChallengeService)
local DailyService = require(script.DailyService)
local SocialService = require(script.SocialService)
local LeaderboardService = require(script.LeaderboardService)
local ProductService = require(script.ProductService)
local EventService = require(script.EventService)
local ServerGoalService = require(script.ServerGoalService)
local Analytics = require(script.Analytics)
local Bodies = require(script.Bodies)
local PaintService = require(script.PaintService)
local MasteryService = require(script.MasteryService)
local UpgradeService = require(script.UpgradeService)
local RateLimit = require(script.RateLimit)
local TrafficService = require(script.TrafficService)
local StuntService = require(script.StuntService)
local DayNightService = require(script.DayNightService)
local LookService = require(script.LookService)
local TrialService = require(script.TrialService)
local CityMapService = require(script.CityMapService)
local TrialConfig = require(ReplicatedStorage.Shared.Config.Trial)
local StreetLife = require(script.StreetLife)

-- the map's terrain takes a few seconds to fill (it yields), so nobody spawns until it stands
local Players = game:GetService("Players")
Players.CharacterAutoLoads = false
-- the cars' finish, before the map's parked cars copy the templates (a failure only costs the sheen)
local shone, shineError = pcall(LookService.cars, ReplicatedStorage:WaitForChild("VehicleModels"))
if not shone then
	warn("car finish not applied: " .. tostring(shineError))
end
local built, world = pcall(MapBuilder.build)
Players.CharacterAutoLoads = true -- even if the build failed, so players still spawn and the error shows
if not built then
	error(world)
end
LookService.apply(world.buildings)
-- parked cars, plaza life, a building site, roadworks (props, registered below); a failure here only loses them
local streetOk, streetErr = pcall(StreetLife.build, world)
if not streetOk then
	warn("street life failed: " .. tostring(streetErr))
end
for _, p in Players:GetPlayers() do
	if not p.Character then
		task.spawn(p.LoadCharacter, p)
	end
end
BuildingService.register(world.buildings)
BuildingService.registerProps(world.props)
CrowdService.setup(world.places, world.grid)
TrafficService.setup(world.grid)
VehicleService.setSpawnPoints(world.spawnPoints)
-- the giant appears at a downtown crossing
local downtown = {}
for _, p in world.spawnPoints do
	if p.Magnitude < 700 then
		table.insert(downtown, p)
	end
end

Analytics.start()
Bodies.start()
Data.start()
Passes.start()
VehicleService.start()
HitGuard.start()
NpcService.start()
TrafficService.start()
BuildingService.start()
PlayerHitService.start()
OnboardingService.start()
QuestService.start()
ChallengeService.start()
DailyService.start()
SocialService.start()
LeaderboardService.start()
ProductService.start()
EventService.setGiantSpots(downtown)
EventService.start()
PaintService.start()
MasteryService.start()
UpgradeService.start()
ServerGoalService.start()
StuntService.start()
DayNightService.start()
TrialService.start()
CityMapService.start()

-- analytics hooks
Data.onEarn(Analytics.earned)
Data.onPublish(function(player, profile)
	Analytics.progress(
		player,
		profile.owned,
		profile.money,
		profile.progress,
		Data.playSeconds(player)
	)
end)
VehicleService.onSpawn(function(player, id)
	Analytics.step(player, Analytics.Steps.SpawnedCar)
	Analytics.custom(
		player,
		"VehicleSpawned",
		1,
		{ [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = id }
	)
end)
NpcService.onKnock(function(player)
	Analytics.step(player, Analytics.Steps.FirstHit)
	Analytics.tookPart(player)
end)
BuildingService.onBreak(function(player)
	Analytics.tookPart(player)
end)
StuntService.onStunt(function(player)
	Analytics.tookPart(player)
end)

-- shop: buy a vehicle with in-game money (the Roadster can also come from its pass)
Net.remote("BuyVehicle").OnServerEvent:Connect(function(player, id)
	if not RateLimit.allow(player, "buy", 0.5) then
		return
	end
	local stats = if typeof(id) == "string" then Vehicles.ById[id] else nil
	local profile = Data.get(player)
	if not (stats and profile) or profile.owned[stats.id] then
		return
	end
	local price = DailyService.price(player, stats)
	if profile.money < price then
		Net.remote("Popup"):FireClient(player, "Not enough money yet", "info")
		return
	end
	-- for analytics only, so it can never stop the purchase
	local checked, first =
		pcall(Analytics.isFirstCar, profile.owned, profile.roadsterPassPaid, profile.bought)
	profile.money -= price
	profile.owned[stats.id] = true
	Data.changed(player)
	Analytics.spent(player, price, stats.id)
	Analytics.step(player, Analytics.Steps.FirstPurchase)
	Analytics.boughtWithMoney(player, stats.id, price)
	if checked and first then
		Analytics.firstVehicle(player, stats.id, Data.playSeconds(player))
	end
	OnboardingService.purchased(player, stats)
	Analytics.carOwned(player, stats.id, profile.owned, Data.playSeconds(player))
	if stats.id == TrialConfig.Car then
		TrialService.bought(player)
	end
end)

-- group reward: once per account, for members of the game's group (checked fresh, so joining mid-session counts)
local function inGroup(player: Player): boolean
	if Economy.GroupId == 0 then
		return RunService:IsStudio() -- no group yet: a test grant in Studio only
	end
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if not ok or typeof(groups) ~= "table" then
		return false
	end
	for _, g in groups do
		if g.Id == Economy.GroupId then
			return true
		end
	end
	return false
end

-- the background music on or off (client/Music), saved with the profile
Net.remote("SetMusic").OnServerEvent:Connect(function(player, off)
	if typeof(off) ~= "boolean" or not RateLimit.allow(player, "music", 0.3) then
		return
	end
	local profile = Data.get(player)
	if profile and profile.musicOff ~= off then
		profile.musicOff = off
		Data.changed(player)
	end
end)

Net.remote("ClaimGroup").OnServerEvent:Connect(function(player)
	if not RateLimit.allow(player, "group", 2) then
		return
	end
	local profile = Data.get(player)
	if not profile or profile.groupClaimed then
		return
	end
	if not inGroup(player) then
		Net.remote("Popup"):FireClient(player, "Join the group first, then press CLAIM", "info")
		return
	end
	if profile.groupClaimed or not player.Parent then
		return -- claimed again while the group check was waiting
	end
	profile.groupClaimed = true
	profile.money += Economy.GroupReward
	Data.changed(player)
	Analytics.source(
		player,
		Economy.GroupReward,
		Enum.AnalyticsEconomyTransactionType.TimedReward,
		"GroupReward"
	)
	Net.remote("Popup")
		:FireClient(player, Loc.msg("GroupPay", { pay = Economy.GroupReward }), "big")
end)
