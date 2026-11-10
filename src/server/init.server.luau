--!strict
-- Server entry: collision groups, the world, then every service.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)

-- every remote exists before any client asks for it
for name in Net.Messages do
	Net.remote(name :: any)
end

-- Vehicles pass through players, NPCs, debris and each other: NPC and player hits are found by overlap.
-- The one exception: player cars' collider boxes (CarBodies) bump into each other and the world.
for _, g in { "Vehicles", "Characters", "Npcs", "Debris", "Furniture", "CarBodies" } do
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

local Data = require(script.Data)
local Passes = require(script.Passes)
local VehicleService = require(script.VehicleService)
local CrowdService = require(script.CrowdService)
local NpcService = require(script.NpcService)
local BuildingService = require(script.BuildingService)
local PlayerHitService = require(script.PlayerHitService)
local MapBuilder = require(script.MapBuilder)
local OnboardingService = require(script.Onboarding)
local QuestService = require(script.QuestService)
local DailyService = require(script.DailyService)
local SocialService = require(script.SocialService)
local LeaderboardService = require(script.LeaderboardService)
local ProductService = require(script.ProductService)
local EventService = require(script.EventService)
local ServerGoalService = require(script.ServerGoalService)
local Analytics = require(script.Analytics)
local Bodies = require(script.Bodies)
local PaintService = require(script.PaintService)
local RateLimit = require(script.RateLimit)
local TrafficService = require(script.TrafficService)
local StuntService = require(script.StuntService)

local world = MapBuilder.build()
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
NpcService.start()
TrafficService.start()
BuildingService.start()
PlayerHitService.start()
OnboardingService.start()
QuestService.start()
DailyService.start()
SocialService.start()
LeaderboardService.start()
ProductService.start()
EventService.setGiantSpots(downtown)
EventService.start()
PaintService.start()
ServerGoalService.start()
StuntService.start()

-- analytics hooks
Data.onEarn(Analytics.earned)
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
	profile.money -= price
	profile.owned[stats.id] = true
	Data.changed(player)
	Analytics.spent(player, price, stats.id)
	Analytics.step(player, Analytics.Steps.FirstPurchase)
	OnboardingService.purchased(player, stats)
end)

-- like reward: honour system, once per account (Roblox can't tell a game whether you liked it)
Net.remote("ClaimLike").OnServerEvent:Connect(function(player)
	if not RateLimit.allow(player, "like", 2) then
		return
	end
	local profile = Data.get(player)
	if not profile or profile.likeClaimed then
		return
	end
	profile.likeClaimed = true
	profile.money += Economy.LikeReward
	Data.changed(player)
	Analytics.source(
		player,
		Economy.LikeReward,
		Enum.AnalyticsEconomyTransactionType.TimedReward,
		"LikeReward"
	)
	Net.remote("Popup")
		:FireClient(player, "+$" .. Economy.LikeReward .. "  Thanks for the like!", "big")
end)
