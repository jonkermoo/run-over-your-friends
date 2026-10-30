--!strict
-- First session: spawn a car, run over three people (bonus and confetti), then save for the next car.
-- The step is saved in the profile and shown as the player attribute "Tutorial";
-- "TutorialHits" counts the hits for step 2. The client draws the goal card, arrows and hints.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Analytics = require(script.Parent.Analytics)
local Data = require(script.Parent.Data)
local NpcService = require(script.Parent.NpcService)
local VehicleService = require(script.Parent.VehicleService)

local Steps = Onboarding.Steps
local OnboardingService = {}
local hits: { [Player]: number } = {}

local function setStep(player: Player, step: number)
	local profile = Data.get(player)
	if profile and profile.tutorial ~= step then
		profile.tutorial = step
		Data.changed(player)
	end
end

local function step(player: Player): number
	local profile = Data.get(player)
	return if profile then profile.tutorial else Steps.Done
end

-- every vehicle bought gets its own moment; the first one also ends the tutorial
function OnboardingService.purchased(player: Player, vehicle: Vehicles.Vehicle)
	Net.remote("Celebrate")
		:FireClient(player, "NEW RIDE!", vehicle.name .. " is yours. Open the GARAGE to spawn it.")
	if step(player) < Steps.Done then
		setStep(player, Steps.Done)
	end
end

function OnboardingService.start()
	VehicleService.onSpawn(function(player)
		if step(player) == Steps.Spawn then
			hits[player] = 0
			player:SetAttribute("TutorialHits", 0)
			setStep(player, Steps.Hits)
		end
	end)
	NpcService.onKnock(function(player)
		if step(player) ~= Steps.Hits then
			return
		end
		local n = (hits[player] or 0) + 1
		hits[player] = n
		player:SetAttribute("TutorialHits", n)
		if n >= Onboarding.HitsGoal then
			Data.addMoney(player, Onboarding.HitsReward)
			setStep(player, Steps.Save)
			Analytics.step(player, Analytics.Steps.TutorialDone)
			Net.remote("Celebrate"):FireClient(
				player,
				"FIRST RAMPAGE!",
				`+${Onboarding.HitsReward} bonus. Keep going and save up for a new ride!`
			)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		hits[player] = nil
	end)
end

return OnboardingService
