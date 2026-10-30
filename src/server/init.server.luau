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

-- Vehicles pass through players, NPCs, debris and each other: NPC and Wrecker hits are found by overlap
for _, g in { "Vehicles", "Characters", "Npcs", "Debris" } do
	PhysicsService:RegisterCollisionGroup(g)
end
PhysicsService:CollisionGroupSetCollidable("Vehicles", "Vehicles", false)
PhysicsService:CollisionGroupSetCollidable("Vehicles", "Characters", false)
PhysicsService:CollisionGroupSetCollidable("Vehicles", "Npcs", false)
PhysicsService:CollisionGroupSetCollidable("Vehicles", "Debris", false)
PhysicsService:CollisionGroupSetCollidable("Npcs", "Characters", false)

local Data = require(script.Data)
local Passes = require(script.Passes)
local VehicleService = require(script.VehicleService)
local NpcService = require(script.NpcService)
local BuildingService = require(script.BuildingService)
local WreckerService = require(script.WreckerService)
local MapBuilder = require(script.MapBuilder)
local OnboardingService = require(script.Onboarding)
local QuestService = require(script.QuestService)
local LeaderboardService = require(script.LeaderboardService)
local ProductService = require(script.ProductService)

local world = MapBuilder.build()
BuildingService.register(world.buildings)
NpcService.setWalkPoints(world.walkPoints, world.crowdPoints)
VehicleService.setSpawnPoints(world.spawnPoints)

Data.start()
Passes.start()
VehicleService.start()
NpcService.start()
BuildingService.start()
WreckerService.start()
OnboardingService.start()
QuestService.start()
LeaderboardService.start()
ProductService.start()

-- shop: buy a vehicle with in-game money (the Roadster can also come from its pass)
Net.remote("BuyVehicle").OnServerEvent:Connect(function(player, id)
	local stats = if typeof(id) == "string" then Vehicles.ById[id] else nil
	local profile = Data.get(player)
	if not (stats and profile) or profile.owned[stats.id] then
		return
	end
	if profile.money < stats.price then
		Net.remote("Popup"):FireClient(player, "Not enough money yet", "info")
		return
	end
	profile.money -= stats.price
	profile.owned[stats.id] = true
	Data.changed(player)
	OnboardingService.purchased(player, stats)
end)

-- like reward: honour system, once per account (Roblox can't tell a game whether you liked it)
Net.remote("ClaimLike").OnServerEvent:Connect(function(player)
	local profile = Data.get(player)
	if not profile or profile.likeClaimed then
		return
	end
	profile.likeClaimed = true
	profile.money += Economy.LikeReward
	Data.changed(player)
	Net.remote("Popup")
		:FireClient(player, "+$" .. Economy.LikeReward .. "  Thanks for the like!", "big")
end)
