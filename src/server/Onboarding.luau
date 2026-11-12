--!strict
-- First session: spawn a car, run over three people (bonus and confetti), take a ramp, smash a building, claim a
-- first goal, buy a car, join an event. The step is saved in the profile and shown as the player attribute
-- "Tutorial"; "TutorialCount" counts toward the step (hits, building pieces). The client draws the job card,
-- markers and hints. Things done before their step comes up (Rules/Onboarding) pass that step when it does, and
-- every new step can be skipped (no event on, a car that can't jump, no money yet).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Rules = require(ReplicatedStorage.Shared.Rules.Onboarding)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Analytics = require(script.Parent.Analytics)
local BuildingService = require(script.Parent.BuildingService)
local Data = require(script.Parent.Data)
local NpcService = require(script.Parent.NpcService)
local RateLimit = require(script.Parent.RateLimit)
local StuntService = require(script.Parent.StuntService)
local VehicleService = require(script.Parent.VehicleService)

local Steps = Onboarding.Steps
local FUNNEL = {
	[Steps.Ramp] = Analytics.Steps.TookRamp,
	[Steps.Smash] = Analytics.Steps.SmashedBuilding,
	[Steps.Goal] = Analytics.Steps.ClaimedGoal,
	[Steps.Event] = Analytics.Steps.JoinedEvent,
}

local OnboardingService = {}

type Session = { count: number, jumped: boolean, pieces: number, enteredAt: number }
local sessions: { [Player]: Session } = {}

local function sessionOf(player: Player): Session
	local s = sessions[player]
	if not s then
		s = { count = 0, jumped = false, pieces = 0, enteredAt = os.clock() }
		sessions[player] = s
	end
	return s
end

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

local function ownsExtra(player: Player): boolean
	local profile = Data.get(player)
	if profile then
		for id in profile.owned do
			if id ~= Vehicles.Starter then
				return true
			end
		end
	end
	return false
end

-- the step's popup, reward and funnel mark
local function cheer(player: Player, done: number)
	local amount = Onboarding.Rewards[done]
	local profile = Data.get(player)
	if amount and profile then
		profile.money += amount -- not Data.addMoney: rewards don't count toward "Earn" goals
		Data.changed(player)
		Analytics.source(
			player,
			amount,
			Enum.AnalyticsEconomyTransactionType.Onboarding,
			"Tutorial" .. done
		)
		Net.remote("Popup"):FireClient(player, `{Onboarding.Cheers[done]}  +${amount}`, "big")
	end
	if FUNNEL[done] then
		Analytics.step(player, FUNNEL[done])
	end
end

-- on to the step after `from`, passing any already done
local function moveOn(player: Player, from: number)
	local s = sessionOf(player)
	local facts = { jumped = s.jumped, pieces = s.pieces, ownsExtra = ownsExtra(player) }
	local landing, passed = Rules.landing(Rules.after(from, Onboarding), facts, Onboarding)
	for _, done in passed do
		cheer(player, done)
	end
	s.count = 0
	s.enteredAt = os.clock()
	-- pieces smashed earlier still show on the smash step's bar
	player:SetAttribute("TutorialCount", if landing == Steps.Smash then s.pieces else 0)
	setStep(player, landing)
	if landing == Steps.Done then
		Analytics.step(player, Analytics.Steps.TutorialDone)
		Net.remote("Celebrate"):FireClient(
			player,
			"YOU'RE ALL SET!",
			"The whole city is yours now. Check GOALS for more cash!"
		)
	end
end

local function complete(player: Player, done: number)
	if step(player) == done then
		cheer(player, done)
		moveOn(player, done)
	end
end

-- a hit, a smash or a landed jump while an event is live counts as joining it
local function tookPart(player: Player)
	if step(player) == Steps.Event and workspace:GetAttribute("Event") ~= nil then
		complete(player, Steps.Event)
	end
end

-- every vehicle bought gets its own moment on the buyer's screen (client/NewRide, from the Owned
-- attribute); on the buy step it's also the way on
function OnboardingService.purchased(player: Player, _vehicle: Vehicles.Vehicle)
	if step(player) == Steps.Buy then
		moveOn(player, Steps.Buy)
	end
end

function OnboardingService.start()
	VehicleService.onSpawn(function(player)
		if step(player) == Steps.Spawn then
			sessionOf(player).count = 0
			player:SetAttribute("TutorialCount", 0)
			setStep(player, Steps.Hits)
		end
	end)
	NpcService.onKnock(function(player)
		tookPart(player)
		if step(player) ~= Steps.Hits then
			return
		end
		local s = sessionOf(player)
		s.count += 1
		player:SetAttribute("TutorialCount", s.count)
		if s.count >= Onboarding.HitsGoal then
			Data.addMoney(player, Onboarding.HitsReward)
			Analytics.step(player, Analytics.Steps.FirstRampage)
			Net.remote("Celebrate"):FireClient(
				player,
				"FIRST RAMPAGE!",
				`+${Onboarding.HitsReward} bonus. Now find a ramp and send it!`
			)
			moveOn(player, Steps.Hits)
		end
	end)
	-- the ramp step wants a jump off a jump ramp, not any kerb or crest
	StuntService.onStunt(function(player, kind)
		if kind ~= "RampJumps" then
			return
		end
		sessionOf(player).jumped = true
		tookPart(player)
		complete(player, Steps.Ramp)
	end)
	BuildingService.onBreak(function(player, count, building)
		local s = sessionOf(player)
		tookPart(player)
		if not building then
			return -- fences, trees and sheds don't teach smashing
		end
		s.pieces += count
		if step(player) == Steps.Smash then
			player:SetAttribute("TutorialCount", s.pieces)
			if s.pieces >= Onboarding.SmashGoal then
				complete(player, Steps.Smash)
			end
		end
	end)
	Net.remote("TutorialClaim").OnServerEvent:Connect(function(player)
		if RateLimit.allow(player, "tutorialClaim", 0.5) then
			complete(player, Steps.Goal)
		end
	end)
	-- the step the button was showing comes along, so a double tap can't skip two steps
	Net.remote("TutorialSkip").OnServerEvent:Connect(function(player, from)
		if
			RateLimit.allow(player, "tutorialSkip", 0.5)
			and typeof(from) == "number"
			and from == step(player)
			and Rules.canSkip(from, Onboarding)
		then
			moveOn(player, from)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	-- no event coming soon: the event step lets you go after a while
	task.spawn(function()
		while true do
			task.wait(1)
			local phase = workspace:GetAttribute("EventPhase")
			for _, player in Players:GetPlayers() do
				if
					step(player) == Steps.Event
					and Rules.eventExpired(
						if typeof(phase) == "string" then phase else nil,
						os.clock() - sessionOf(player).enteredAt,
						Onboarding
					)
				then
					moveOn(player, Steps.Event)
				end
			end
		end
	end)
end

return OnboardingService
