--!strict
-- Play-time gifts (Config/Gifts, Rules/Gifts): a gift opens at each minute mark of play this session and the
-- player claims it with one tap (ClaimGift), in order. The session starts when the data is ready. Published as
-- GiftStart (server time the session started) and GiftsClaimed (how many so far) for the HUD chip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Gifts)
local Paints = require(ReplicatedStorage.Shared.Config.Paints)
local Gifts = require(ReplicatedStorage.Shared.Rules.Gifts)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Analytics = require(script.Parent.Analytics)
local Data = require(script.Parent.Data)
local RateLimit = require(script.Parent.RateLimit)

local GiftService = {}

type Session = { startedAt: number, claimed: number }
local sessions: { [Player]: Session } = {}

local function claim(player: Player)
	if not RateLimit.allow(player, "claimGift", 0.5) then
		return
	end
	local s, profile = sessions[player], Data.get(player)
	if not (s and profile) then
		return
	end
	local index = Gifts.nextIndex(s.claimed, Config.Minutes)
	if
		not index or not Gifts.open(index, os.clock() - s.startedAt, Config.Minutes, Config.Slack)
	then
		return
	end
	local cash, paint = Gifts.payout(index, Config.Prizes, profile.paints)
	s.claimed = index
	player:SetAttribute("GiftsClaimed", index)
	local minute = Config.Minutes[index]
	if paint then
		profile.paints[paint] = true
		local p = Paints.ById[paint]
		Net.remote("Popup"):FireClient(
			player,
			Loc.msg("PaintUnlocked", { paint = Loc.src(p and p.name or paint) }),
			"big"
		)
	else
		profile.money += cash -- not Data.addMoney: rewards don't count toward "Earn" goals
		Analytics.source(
			player,
			cash,
			Enum.AnalyticsEconomyTransactionType.TimedReward,
			`Gift{minute}`
		)
		Net.remote("Popup")
			:FireClient(player, Loc.msg("GiftPay", { m = minute, pay = cash }), "big")
	end
	Data.changed(player)
	Analytics.giftClaimed(player, minute, if paint then "Paint" else "Cash")
end

function GiftService.start()
	local function onReady(player: Player)
		while player.Parent and not player:GetAttribute("DataReady") do
			task.wait(0.2)
		end
		if not player.Parent then
			return
		end
		sessions[player] = { startedAt = os.clock(), claimed = 0 }
		player:SetAttribute("GiftStart", workspace:GetServerTimeNow())
		player:SetAttribute("GiftsClaimed", 0)
	end
	Players.PlayerAdded:Connect(onReady)
	for _, p in Players:GetPlayers() do
		task.spawn(onReady, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		sessions[p] = nil
	end)
	Net.remote("ClaimGift").OnServerEvent:Connect(claim)
end

return GiftService
