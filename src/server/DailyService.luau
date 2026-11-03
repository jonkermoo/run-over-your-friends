--!strict
-- Daily login streak (Config/Daily, Rules/Daily): once per UTC day a player collects a reward that grows
-- with the days in a row they've collected; a missed day starts over at 1. Saved in the profile, so the
-- session lock keeps two servers from paying the same day. Also each player's car of the day and its price for the shop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Daily)
local Daily = require(ReplicatedStorage.Shared.Rules.Daily)
local Net = require(ReplicatedStorage.Shared.Net)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Analytics = require(script.Parent.Analytics)
local Data = require(script.Parent.Data)
local RateLimit = require(script.Parent.RateLimit)

local DailyService = {}

local saleIds = Daily.saleIds(Vehicles.List, Config.DiscountSkip)
local sent: { [Player]: string } = {}

local function today(): number
	return Daily.day(os.time(), Config.DaySeconds)
end

-- this player's car of the day: picked once a day from the cars they didn't own then and kept all day,
-- so buying a car doesn't reshuffle it. Published as the CarOfDay attribute ("" for none) for the garage.
local function pick(player: Player): string?
	local profile = Data.get(player)
	if not profile then
		return nil
	end
	local day = today()
	local sale = profile.sale
	if not sale or sale.day ~= day or (sale.id and not table.find(saleIds, sale.id)) then
		sale = { day = day, id = Daily.pickFor(saleIds, profile.owned, day, Config.DiscountSalt) }
		profile.sale = sale
	end
	local id = (sale :: { day: number, id: string? }).id
	player:SetAttribute("CarOfDay", id or "")
	return id
end

-- what a vehicle costs this player right now (their car of the day is cheaper)
function DailyService.price(player: Player, stats: Vehicles.Vehicle): number
	return Daily.price(
		stats.id,
		stats.price,
		pick(player),
		Config.DiscountShare,
		Config.DiscountRound
	)
end

local function send(player: Player, force: boolean?)
	local profile = Data.get(player)
	if not profile then
		return
	end
	local nextStreak = Daily.next(profile.daily, today())
	local state = {
		streak = nextStreak or (if profile.daily then profile.daily.streak else 0),
		ready = nextStreak ~= nil,
	}
	local key = `{state.streak}/{state.ready}`
	if force or sent[player] ~= key then
		sent[player] = key
		Net.remote("Daily"):FireClient(player, state)
	end
end

local function claim(player: Player)
	if not RateLimit.allow(player, "daily", 1) then
		return
	end
	local profile = Data.get(player)
	local day = today()
	local streak = profile and Daily.next(profile.daily, day)
	if not (profile and streak) then
		return
	end
	local reward = Daily.reward(streak, Config.StreakRewards)
	profile.daily = { day = day, streak = streak }
	profile.money += reward -- not Data.addMoney: rewards don't count toward "Earn" goals
	Data.changed(player)
	Analytics.source(
		player,
		reward,
		Enum.AnalyticsEconomyTransactionType.TimedReward,
		"DailyStreak"
	)
	Net.remote("Popup"):FireClient(player, `DAY {streak} STREAK  +${reward}`, "big")
	send(player, true)
	task.spawn(Data.saveNow, player)
end

function DailyService.start()
	local function onReady(player: Player)
		while player.Parent and not player:GetAttribute("DataReady") do
			task.wait(0.2)
		end
		pick(player)
		send(player, true)
	end
	Players.PlayerAdded:Connect(onReady)
	for _, p in Players:GetPlayers() do
		task.spawn(onReady, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		sent[p] = nil
	end)
	Net.remote("ClaimDaily").OnServerEvent:Connect(claim)

	-- a player still on when the UTC day turns gets the new day's reward offered
	task.spawn(function()
		while true do
			task.wait(20)
			for _, player in Players:GetPlayers() do
				if sent[player] then
					pick(player)
					send(player)
				end
			end
		end
	end)
end

return DailyService
