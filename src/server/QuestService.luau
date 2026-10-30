--!strict
-- Hourly and daily goals. Each player gets their own sets (seeded by user id and period, so a rejoin
-- shows the same goals), saved in the profile. Progress comes from game events; a finished goal pays
-- at once. The client gets the whole state whenever it changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local QuestConfig = require(ReplicatedStorage.Shared.Config.Quests)
local Quests = require(ReplicatedStorage.Shared.Rules.Quests)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local BuildingService = require(script.Parent.BuildingService)
local Data = require(script.Parent.Data)
local NpcService = require(script.Parent.NpcService)
local VehicleService = require(script.Parent.VehicleService)

local QuestService = {}
local SETS = { Hourly = QuestConfig.Hourly, Daily = QuestConfig.Daily }
local SALT = { Hourly = 11, Daily = 23 }

local dirty: { [Player]: boolean } = {}
local lastPos: { [Player]: Vector3 } = {}

local function now(): number
	return os.time()
end

local function hasAbility(player: Player, needs: string): boolean
	local profile = Data.get(player)
	if not profile then
		return false
	end
	if needs == "Breaker" then
		for id in profile.owned do
			local v = Vehicles.ById[id]
			if v and v.breaksBuildings then
				return true
			end
		end
	end
	return false
end

-- make sure every set belongs to the current period; returns true if any were rolled
local function refresh(player: Player): boolean
	local profile = Data.get(player)
	if not profile then
		return false
	end
	local rolled = false
	for name, cfg in SETS do
		local period = Quests.period(now(), cfg.Seconds)
		local set = profile.quests[name]
		if typeof(set) ~= "table" or set.period ~= period or typeof(set.goals) ~= "table" then
			local rng = Random.new(Quests.seed(player.UserId, period, SALT[name]))
			profile.quests[name] = {
				period = period,
				goals = Quests.roll(cfg.Templates, cfg.Count, function()
					return rng:NextNumber()
				end, function(needs)
					return hasAbility(player, needs)
				end),
			}
			rolled = true
		end
	end
	return rolled
end

local function send(player: Player)
	local profile = Data.get(player)
	if not profile then
		return
	end
	local out = {}
	for name, cfg in SETS do
		local set = profile.quests[name]
		if set then
			out[name] = {
				goals = set.goals,
				endsAt = (set.period + 1) * cfg.Seconds, -- unix seconds
			}
		end
	end
	Net.remote("Goals"):FireClient(player, out, now())
end

function QuestService.event(player: Player, kind: string, amount: number)
	local profile = Data.get(player)
	if not profile then
		return
	end
	refresh(player)
	local paid = 0
	for name in SETS do
		local set = profile.quests[name]
		if set then
			for _, goal in Quests.advance(set.goals, kind, amount) do
				paid += goal.reward
				Net.remote("Popup"):FireClient(
					player,
					`{string.upper(name)} GOAL!  {goal.text}  +${goal.reward}`,
					"goal"
				)
			end
		end
	end
	if paid > 0 then
		profile.money += paid -- not Data.addMoney: rewards don't count toward "Earn" goals
		Data.changed(player)
	end
	dirty[player] = true
end

function QuestService.start()
	local function onReady(player: Player)
		while player.Parent and not player:GetAttribute("DataReady") do
			task.wait(0.2)
		end
		refresh(player)
		send(player)
	end
	Players.PlayerAdded:Connect(onReady)
	for _, p in Players:GetPlayers() do
		task.spawn(onReady, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		dirty[p] = nil
		lastPos[p] = nil
	end)

	NpcService.onKnock(function(player, combo)
		QuestService.event(player, "Hits", 1)
		QuestService.event(player, "Combo", combo)
	end)
	NpcService.onLaunch(function(player, studs)
		QuestService.event(player, "Launch", math.floor(studs))
	end)
	BuildingService.onBreak(function(player, count)
		QuestService.event(player, "Breaks", count)
	end)
	Data.onEarn(function(player, amount)
		QuestService.event(player, "Earn", amount)
	end)

	-- distance driven, sampled once a second (capped by what the vehicle could cover)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local vehicle = VehicleService.of(player)
				local stats = vehicle and VehicleService.stats(vehicle)
				local chassis = vehicle and vehicle.PrimaryPart
				local seat = vehicle and vehicle:FindFirstChild("DriverSeat") :: VehicleSeat?
				if stats and chassis and seat and seat.Occupant then
					local pos = chassis.Position * Vector3.new(1, 0, 1)
					local last = lastPos[player]
					lastPos[player] = pos
					if last then
						local step = (pos - last).Magnitude
						local cap = stats.topSpeed / 2.237 * Vehicles.StudsPerMetre * 1.5 + 20
						if step > 1 and step < cap then
							QuestService.event(player, "Drive", math.floor(step))
						end
					end
				else
					lastPos[player] = nil
				end
			end
		end
	end)

	-- push changes to clients a few times a second, and roll new sets when a period ends
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				if refresh(player) then
					dirty[player] = true
				end
				if dirty[player] then
					dirty[player] = nil
					send(player)
				end
			end
		end
	end)
end

return QuestService
