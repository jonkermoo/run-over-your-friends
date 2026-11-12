--!strict
-- Server entry: collision groups, the world, then every service.

local GroupService = game:GetService("GroupService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local HitGuard = require(script.HitGuard)
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

-- the map's terrain takes a few seconds to fill (it yields), so nobody spawns until it stands
local Players = game:GetService("Players")
Players.CharacterAutoLoads = false
local built, world = pcall(MapBuilder.build)
Players.CharacterAutoLoads = true -- even if the build failed, so players still spawn and the error shows
if not built then
	error(world)
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
		:FireClient(player, "+$" .. Economy.GroupReward .. "  Thanks for joining!", "big")
end)
