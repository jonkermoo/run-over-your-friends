--!strict
-- First session: a new player is first asked whether they want the tutorial (a big offer card with the finish
-- bonus on it, client/TutorialOffer); "No thanks" ends it, asks once more on a later join, and leaves a TUTORIAL
-- tab in the menu strip that starts it again. The tutorial: start in the starter car (the server spawns it; the
-- garage if that fails), run over three people (bonus and confetti), smash a building, a garage tour (car page,
-- upgrades, paint, decals, the next car; client/Guide), finish a short first goal (a few more hits, then a big
-- CLAIM pop-up that claims itself if left alone), join an event, then the finish bonus (Config/Onboarding
-- FinishBonus) and a last step to spend it on a car. The
-- step is saved in the profile and shown as the player attribute "Tutorial"; "TutorialCount" counts toward the
-- step (hits, building pieces) and "TutorialClaim" is set while the first goal waits to be claimed. The client
-- draws the job card, markers, hints and the CLAIM pop-up. Things done before their step comes up
-- (Rules/Onboarding) pass that step when it does, and every new step can be skipped (no event on, no money yet).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Rules = require(ReplicatedStorage.Shared.Rules.Onboarding)
local AnalyticsRules = require(ReplicatedStorage.Shared.Rules.Analytics)
local AnalyticsCfg = require(ReplicatedStorage.Shared.Config.Analytics)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Analytics = require(script.Parent.Analytics)
local BuildingService = require(script.Parent.BuildingService)
local Data = require(script.Parent.Data)
local NpcService = require(script.Parent.NpcService)
local RateLimit = require(script.Parent.RateLimit)
local StuntService = require(script.Parent.StuntService)
local VehicleService = require(script.Parent.VehicleService)

local Steps = Onboarding.Steps
local Offer = Onboarding.Offer
-- the bonus as the card shows it: 2500 -> "2,500" (the lines put the $ in front)
local BONUS_TEXT = tostring(Onboarding.FinishBonus)
do
	local grouped = string.gsub(string.reverse(BONUS_TEXT), "(%d%d%d)", "%1,")
	BONUS_TEXT = string.reverse(grouped)
	if string.sub(BONUS_TEXT, 1, 1) == "," then
		BONUS_TEXT = string.sub(BONUS_TEXT, 2)
	end
end
local SKIP_NAMES: { [number]: string } = {}
for _, n in Onboarding.Order do
	SKIP_NAMES[n] = AnalyticsRules.stepName(n, Steps)
end
local FUNNEL = {
	[Steps.Smash] = Analytics.Steps.SmashedBuilding,
	[Steps.Goal] = Analytics.Steps.ClaimedGoal,
	[Steps.Event] = Analytics.Steps.JoinedEvent,
}

local OnboardingService = {}

type Session = {
	count: number,
	pieces: number,
	enteredAt: number,
	claimable: boolean,
	answered: boolean, -- the offer was answered this session: it doesn't come back until a later join
	offerLogged: boolean,
	where: string, -- how this run of the tutorial started (analytics TutorialOffer field 02)
	tour: { [string]: boolean }, -- garage tour pages logged
}
local sessions: { [Player]: Session } = {}

local function sessionOf(player: Player): Session
	local s = sessions[player]
	if not s then
		s = {
			count = 0,
			pieces = 0,
			enteredAt = os.clock(),
			claimable = false,
			answered = false,
			offerLogged = false,
			where = "First",
			tour = {},
		}
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
		Net.remote("Popup"):FireClient(
			player,
			Loc.msg("CheerPay", { cheer = Loc.src(Onboarding.Cheers[done]), amount = amount }),
			"big"
		)
	end
	if FUNNEL[done] then
		Analytics.step(player, FUNNEL[done])
	end
end

-- the offer card ("TutorialOffer": where it shows, nil when it doesn't) and the menu strip's TUTORIAL tab
local function refreshOffer(player: Player)
	local profile = Data.get(player)
	if not profile then
		return
	end
	local where = Rules.offerWhere(profile.offer, profile.tutorial, profile.bonusPaid, Onboarding)
	player:SetAttribute("TutorialOffer", if sessionOf(player).answered then nil else where)
	player:SetAttribute(
		"TutorialTab",
		Rules.tabShows(profile.offer, profile.tutorial, profile.bonusPaid, Onboarding)
	)
end

-- the finish bonus, once: the big moment and the money for the first real car
local function payBonus(player: Player): boolean
	local profile = Data.get(player)
	if not profile then
		return false
	end
	profile.money += Onboarding.FinishBonus -- like the step rewards, not toward "Earn" goals
	profile.bonusPaid = true
	Data.changed(player)
	Analytics.source(
		player,
		Onboarding.FinishBonus,
		Enum.AnalyticsEconomyTransactionType.Onboarding,
		"TutorialBonus"
	)
	Analytics.tutorialOffer(player, "RewardPaid", sessionOf(player).where, Onboarding.FinishBonus)
	Net.remote("Celebrate")
		:FireClient(player, "TUTORIAL COMPLETE!", Loc.msg("FinishBonusSub", { n = BONUS_TEXT }))
	refreshOffer(player)
	return true
end

-- on to the step after `from`, passing any already done
local function moveOn(player: Player, from: number)
	local s = sessionOf(player)
	local facts = { pieces = s.pieces, ownsExtra = ownsExtra(player) }
	local landing, passed = Rules.landing(Rules.after(from, Onboarding), facts, Onboarding)
	for _, done in passed do
		cheer(player, done)
	end
	s.count = 0
	s.enteredAt = os.clock()
	s.claimable = false
	player:SetAttribute("TutorialClaim", nil)
	-- pieces smashed earlier still show on the smash step's bar
	player:SetAttribute("TutorialCount", if landing == Steps.Smash then s.pieces else 0)
	setStep(player, landing)
	local profile = Data.get(player)
	local paid = profile ~= nil
		and Rules.bonusDue(profile.offer, landing, profile.bonusPaid, Onboarding)
		and payBonus(player)
	if landing == Steps.Done then
		Analytics.step(player, Analytics.Steps.TutorialDone)
	end
	-- the bonus has its own big moment; one is enough
	if landing == Steps.Done and not paid then
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

-- the first goal is done: the CLAIM pop-up shows, and claims by itself if the player leaves it
local function goalDone(player: Player)
	local s = sessionOf(player)
	s.claimable = true
	local entered = s.enteredAt
	task.delay(Onboarding.ClaimDelay, function()
		if player.Parent and s.claimable and s.enteredAt == entered then
			player:SetAttribute("TutorialClaim", true)
		end
	end)
	task.delay(Onboarding.ClaimDelay + Onboarding.ClaimAutoAfter, function()
		if player.Parent and s.claimable and s.enteredAt == entered then
			complete(player, Steps.Goal)
		end
	end)
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

-- a new player (still on the spawn step) starts in the starter car instead of having to find the garage
local function autoSpawn(player: Player)
	while player.Parent and not player:GetAttribute("DataReady") do
		task.wait(0.2)
	end
	for _ = 1, Onboarding.AutoSpawnTries do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then
			task.wait(Onboarding.AutoSpawnDelay)
		else
			task.wait(Onboarding.AutoSpawnRetry)
		end
		if not player.Parent or step(player) ~= Steps.Spawn or VehicleService.of(player) then
			return
		end
		if humanoid and VehicleService.spawn(player, Vehicles.Starter) then
			return
		end
	end
end

-- back into the tutorial from its first played step (the offer's second showing, or the TUTORIAL tab)
local function restart(player: Player)
	local s = sessionOf(player)
	s.count = 0
	s.enteredAt = os.clock()
	s.claimable = false
	s.tour = {}
	player:SetAttribute("TutorialClaim", nil)
	player:SetAttribute("TutorialCount", 0)
	setStep(player, Steps.Hits)
end

-- once the data is in, the offer card shows (for a new player) and the TUTORIAL tab where it belongs
local function offerWhenReady(player: Player)
	while player.Parent and not player:GetAttribute("DataReady") do
		task.wait(0.2)
	end
	task.wait(Onboarding.OfferDelay)
	if player.Parent then
		refreshOffer(player)
	end
end

local function onOffer(player: Player, action: unknown)
	local profile = Data.get(player)
	if not (profile and RateLimit.allow(player, "tutorialOffer", 0.5)) then
		return
	end
	local s = sessionOf(player)
	local where = player:GetAttribute("TutorialOffer")
	if typeof(where) == "string" then
		if action == "Shown" and not s.offerLogged then
			s.offerLogged = true
			Analytics.tutorialOffer(player, "Shown", where)
		elseif action == "Start" then
			s.answered, s.where = true, where
			profile.offer = Offer.Accepted
			Analytics.tutorialOffer(player, "Accepted", where)
			if profile.tutorial == Steps.Done then
				restart(player)
			end
			Data.changed(player)
			refreshOffer(player)
		elseif action == "Decline" then
			s.answered = true
			profile.offer = Rules.declined(profile.offer, Onboarding)
			Analytics.tutorialOffer(player, "Declined", where)
			s.claimable = false
			player:SetAttribute("TutorialClaim", nil)
			player:SetAttribute("TutorialCount", 0)
			setStep(player, Steps.Done) -- not "Tutorial done" on the funnel: it wasn't
			Data.changed(player)
			refreshOffer(player)
			Net.remote("Popup")
				:FireClient(player, Loc.msg("OfferLater", { n = BONUS_TEXT }), "info")
		end
	elseif
		action == "Restart"
		and Rules.tabShows(profile.offer, profile.tutorial, profile.bonusPaid, Onboarding)
	then
		s.answered, s.where = true, "Button"
		profile.offer = Offer.Accepted
		Analytics.tutorialOffer(player, "Restarted", "Button")
		restart(player)
		Data.changed(player)
		refreshOffer(player)
	end
end

local function onTour(player: Player, page: unknown)
	if
		not RateLimit.allow(player, "tutorialTour", 0.01)
		or step(player) ~= Steps.Garage
		or typeof(page) ~= "string"
		or not table.find(Onboarding.TourPages, page)
	then
		return
	end
	local s = sessionOf(player)
	-- pages come in order: DONE only counts once every page before it was reached
	for i = 1, (table.find(Onboarding.TourPages, page) :: number) - 1 do
		if not s.tour[Onboarding.TourPages[i]] then
			return
		end
	end
	if not s.tour[page] then
		s.tour[page] = true
		Analytics.tutorialTour(player, page)
	end
	if page == "Done" then
		complete(player, Steps.Garage)
	end
end

function OnboardingService.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(offerWhenReady, player)
		autoSpawn(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(offerWhenReady, player)
		task.spawn(autoSpawn, player)
	end
	Net.remote("TutorialOffer").OnServerEvent:Connect(onOffer)
	Net.remote("TutorialTour").OnServerEvent:Connect(onTour)
	VehicleService.onSpawn(function(player)
		if step(player) == Steps.Spawn then
			sessionOf(player).count = 0
			player:SetAttribute("TutorialCount", 0)
			setStep(player, Steps.Hits)
		end
	end)
	NpcService.onKnock(function(player)
		tookPart(player)
		local s = sessionOf(player)
		if step(player) == Steps.Goal and not s.claimable then
			s.count += 1
			player:SetAttribute("TutorialCount", s.count)
			if s.count >= Onboarding.GoalHits then
				goalDone(player)
			end
			return
		end
		if step(player) ~= Steps.Hits then
			return
		end
		s.count += 1
		player:SetAttribute("TutorialCount", s.count)
		if s.count >= Onboarding.HitsGoal then
			Data.addMoney(player, Onboarding.HitsReward)
			Analytics.step(player, Analytics.Steps.FirstRampage)
			Net.remote("Celebrate"):FireClient(
				player,
				"FIRST RAMPAGE!",
				Loc.msg("FirstRampageSub", { n = Onboarding.HitsReward })
			)
			moveOn(player, Steps.Hits)
		end
	end)
	-- a jump off a jump ramp joins a live event
	StuntService.onStunt(function(player, kind)
		if kind == "RampJumps" then
			tookPart(player)
		end
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
		if RateLimit.allow(player, "tutorialClaim", 0.5) and sessionOf(player).claimable then
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
			-- SKIP shows after SkipAfter on the card; held here too, so skips can't race to the finish bonus
			and os.clock() - sessionOf(player).enteredAt >= Onboarding.SkipAfter
		then
			Analytics.tutorialSkipped(
				player,
				SKIP_NAMES[from] or "Unknown",
				os.clock() - sessionOf(player).enteredAt
			)
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
					Analytics.tutorialSkipped(
						player,
						AnalyticsCfg.EventTimeout,
						os.clock() - sessionOf(player).enteredAt
					)
					moveOn(player, Steps.Event)
				end
			end
		end
	end)
end

return OnboardingService
