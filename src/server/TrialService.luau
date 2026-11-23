--!strict
-- The Roadster free trial (Config/Trial, Rules/Trial). The garage's FREE TRIAL button asks for it on Net
-- "RoadsterTrial"; the server checks the player may have one (tutorial done, doesn't own the car, none in the
-- last 24 h), saves the start time in the profile and spawns a stock trial car (VehicleService.setTrial). The
-- clock runs only while they sit in its driver seat and shows as the TrialLeft attribute. At zero it waits for
-- the car to be on the ground (or LandWaitSeconds), puts them back in the car they drove before and fires
-- TrialOver for the end card. Leaving ends the trial; buying the car or its pass ends it with the car kept.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Trial)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Rules = require(ReplicatedStorage.Shared.Rules.Trial)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Analytics = require(script.Parent.Analytics)
local Data = require(script.Parent.Data)
local RateLimit = require(script.Parent.RateLimit)
local VehicleService = require(script.Parent.VehicleService)

local TrialService = {}

type Run = {
	left: number, -- driving seconds left
	prev: string?, -- the owned car to go back into
	zeroAt: number?, -- os.clock the clock reached zero
}
local runs: { [Player]: Run } = {}
local offered: { [Player]: boolean } = {} -- Offered logged this session

local function facts(player: Player): Rules.Facts?
	local profile = Data.get(player)
	if not profile then
		return nil
	end
	return {
		tutorialDone = profile.tutorial == Onboarding.Steps.Done,
		ownsCar = profile.owned[Cfg.Car] == true or player:GetAttribute("Pass" .. Cfg.Car) == true,
		lastAt = profile.trialAt,
		now = os.time(),
		active = runs[player] ~= nil,
	}
end

-- the player's trial car, when they have it out
local function trialCar(player: Player): Model?
	local car = VehicleService.of(player)
	if car and car:GetAttribute("Trial") == true and car:GetAttribute("VehicleId") == Cfg.Car then
		return car
	end
	return nil
end

local function inSeat(player: Player, car: Model?): boolean
	local seat = car and car:FindFirstChild("DriverSeat") :: VehicleSeat?
	local occupant = seat and seat.Occupant
	return occupant ~= nil and player.Character ~= nil and occupant.Parent == player.Character
end

local function grounded(player: Player, car: Model): boolean
	local chassis = car.PrimaryPart
	if not chassis then
		return true
	end
	local _, size = car:GetBoundingBox()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { car }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(
		chassis.Position,
		Vector3.new(0, -(size.Y / 2 + Cfg.GroundGap), 0),
		params
	)
	return hit ~= nil
end

local function stop(player: Player)
	runs[player] = nil
	VehicleService.setTrial(player, nil)
	player:SetAttribute("TrialLeft", nil)
end

-- time's up: back into the car they drove before (the starter if none), then the end card
local function finish(player: Player, run: Run)
	if trialCar(player) then
		local profile = Data.get(player)
		local back = if run.prev
				and profile
				and profile.owned[run.prev]
			then run.prev
			else Vehicles.Starter
		if not VehicleService.spawn(player, back) then
			VehicleService.despawn(player)
		end
	end
	Analytics.trial(player, "Ended", "Time")
	Net.remote("TrialOver"):FireClient(player)
end

local function start(player: Player)
	local run = runs[player]
	if run then
		-- a trial is running: bring the trial car back (after driving another car meanwhile)
		if not trialCar(player) and run.left > 0 then
			VehicleService.spawn(player, Cfg.Car)
		end
		return
	end
	local f = facts(player)
	local profile = Data.get(player)
	if not (f and profile) or Rules.problem(f, Cfg) then
		return
	end
	local current = player:GetAttribute("VehicleId")
	run = {
		left = Cfg.Seconds,
		prev = if typeof(current) == "string" and profile.owned[current] then current else nil,
	}
	runs[player] = run
	VehicleService.setTrial(player, Cfg.Car)
	if not VehicleService.spawn(player, Cfg.Car) then
		stop(player) -- couldn't spawn (wrecked cooldown, no character): nothing used up
		return
	end
	profile.trialAt = os.time()
	profile.trialConverted = false
	Data.changed(player)
	player:SetAttribute("TrialLeft", Rules.shown(run.left))
	Analytics.trial(player, "Started")
end

local function tick(dt: number)
	for player, run in runs do
		local car = trialCar(player)
		local before = run.left
		run.left = Rules.tick(run.left, dt, inSeat(player, car))
		if Rules.warnNow(before, run.left, Cfg) then
			Net.remote("Popup")
				:FireClient(player, Loc.msg("TrialWarn", { n = Cfg.WarnSeconds }), "info")
		end
		player:SetAttribute("TrialLeft", Rules.shown(run.left))
		if run.left <= 0 then
			run.zeroAt = run.zeroAt or os.clock()
			local waited = os.clock() - (run.zeroAt :: number)
			local onGround = car ~= nil and grounded(player, car :: Model)
			if Rules.swapNow(run.left, car ~= nil, onGround, waited, Cfg) then
				stop(player) -- before the swap yields, so the next tick doesn't finish it again
				task.spawn(finish, player, run)
			end
		end
	end
end

-- the player now owns the trial car (bought with cash or its pass): converted if within a week of a trial,
-- and a running trial ends with the car kept
function TrialService.bought(player: Player)
	local profile = Data.get(player)
	if not profile then
		return
	end
	if runs[player] then
		stop(player)
		local car = VehicleService.of(player)
		if car and car:GetAttribute("VehicleId") == Cfg.Car then
			car:SetAttribute("Trial", nil)
		end
		Analytics.trial(player, "Ended", "Bought")
	end
	if not profile.trialConverted and Rules.converted(profile.trialAt, os.time(), Cfg) then
		profile.trialConverted = true
		Data.changed(player)
		Analytics.trial(player, "Converted")
	end
end

function TrialService.start()
	Net.remote("RoadsterTrial").OnServerEvent:Connect(function(player, action)
		if
			(action ~= "Start" and action ~= "Offered")
			or not RateLimit.allow(player, "trial" .. action, Cfg.RemoteCooldown)
		then
			return
		end
		if action == "Start" then
			start(player)
		elseif action == "Offered" and not offered[player] then
			local f = facts(player)
			if f and not Rules.problem(f, Cfg) then
				offered[player] = true
				Analytics.trial(player, "Offered")
			end
		end
	end)
	-- driving an owned car during the trial makes it the one to go back to
	VehicleService.onSpawn(function(player, id)
		local run = runs[player]
		local profile = Data.get(player)
		if run and profile and id ~= Cfg.Car and profile.owned[id] then
			run.prev = id
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if runs[player] then
			Analytics.trial(player, "Ended", "Left")
		end
		runs[player] = nil
		offered[player] = nil
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Cfg.TickSeconds)
			local now = os.clock()
			tick(now - last)
			last = now
		end
	end)
end

return TrialService
