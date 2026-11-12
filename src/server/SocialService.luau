--!strict
-- Playing together (Config/Social, Rules/Social). Roblox friends in the same server boost each other's hit
-- money; the count is published as the player attribute Friends for the HUD chip. When one player launches
-- another (player hits), the flight is watched and both get a toast with how far it went.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Social)
local Net = require(ReplicatedStorage.Shared.Net)
local Social = require(ReplicatedStorage.Shared.Rules.Social)
local Analytics = require(script.Parent.Analytics)
local Data = require(script.Parent.Data)

local SocialService = {}

-- friends[a][b] is true when a and b are Roblox friends; checked once per pair, both ways filled
local friends: { [Player]: { [Player]: boolean } } = {}
local toasts = Social.newToasts()

local function count(player: Player): number
	local n = 0
	for other, yes in friends[player] or {} do
		if yes and other.Parent then
			n += 1
		end
	end
	return n
end

local function publish(player: Player)
	if player.Parent then
		player:SetAttribute("Friends", count(player))
	end
end

-- hit money multiplier from friends in the server
function SocialService.multiplier(player: Player): number
	return Social.friendMultiplier(count(player), Config.FriendBonusPer, Config.FriendBonusMax)
end

local function checkPair(newcomer: Player, other: Player)
	local ok, yes = pcall(function()
		return newcomer:IsFriendsWith(other.UserId)
	end)
	if
		not (
			ok
			and yes
			and newcomer.Parent
			and other.Parent
			and friends[newcomer]
			and friends[other]
		)
	then
		return
	end
	friends[newcomer][other] = true
	friends[other][newcomer] = true
	publish(newcomer)
	publish(other)
	local pct = math.floor(Config.FriendBonusPer * 100 + 0.5)
	Net.remote("Popup")
		:FireClient(other, `Your friend {newcomer.DisplayName} joined!  +{pct}% money`, "social")
	Net.remote("Popup")
		:FireClient(newcomer, `Your friend {other.DisplayName} is here!  +{pct}% money`, "social")
end

-- watch how far `part` flies after `by` launched `victim`, then toast both if it went far enough
function SocialService.launched(by: Player?, victim: Player?, part: BasePart?)
	if not (by and victim and part) or by == victim then
		return
	end
	task.spawn(function()
		local start = part.Position * Vector3.new(1, 0, 1)
		local far = 0
		for _ = 1, Config.FlightSamples do
			task.wait(Config.FlightSampleEvery)
			if not part.Parent then
				break
			end
			far = math.max(far, (part.Position * Vector3.new(1, 0, 1) - start).Magnitude)
		end
		if not (by.Parent and victim.Parent) then
			return
		end
		if Social.allowToast(toasts, by.UserId, victim.UserId, far, os.clock(), Config) then
			local mine, theirs = Social.toastText(by.DisplayName, victim.DisplayName, far)
			Net.remote("Popup"):FireClient(by, mine, "social")
			Net.remote("Popup"):FireClient(victim, theirs, "social")
		end
	end)
end

local function waitReady(player: Player): boolean
	local t = os.clock()
	while player.Parent and not player:GetAttribute("DataReady") and os.clock() - t < 60 do
		task.wait(0.5)
	end
	return player.Parent ~= nil and player:GetAttribute("DataReady") == true
end

local function grant(player: Player, amount: number, text: string)
	local profile = Data.get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.money += amount -- not Data.addMoney: rewards don't count toward "Earn" goals
	Data.changed(player)
	Analytics.source(player, amount, Enum.AnalyticsEconomyTransactionType.TimedReward, "Invite")
	Net.remote("Popup"):FireClient(player, text, "social")
end

-- a player who joined from an invite: once both profiles are loaded, pay the inviter (if they're here) and
-- welcome the newcomer (Rules/Social.inviteReward)
local function checkInvite(newcomer: Player)
	local ok, join = pcall(function()
		return newcomer:GetJoinData()
	end)
	if not ok or typeof(join) ~= "table" then
		return
	end
	local id = Social.inviter(join.ReferredByPlayerId, join.LaunchData, newcomer.UserId)
	local inviter = id and Players:GetPlayerByUserId(id)
	if not inviter or not waitReady(newcomer) or not waitReady(inviter) then
		return
	end
	local mine, theirs = Data.get(inviter), Data.get(newcomer)
	if not (mine and theirs) then
		return
	end
	local forInviter, forNewcomer = Social.inviteReward(
		mine.invited,
		newcomer.UserId,
		theirs.welcomed,
		Config.InviteReward,
		Config.InviteWelcome,
		Config.InviteMaxPaid
	)
	if forInviter > 0 then
		mine.invited[tostring(newcomer.UserId)] = true
		grant(inviter, forInviter, `{newcomer.DisplayName} CAME!  +${forInviter}`)
	end
	if forNewcomer > 0 then
		theirs.welcomed = true
		grant(newcomer, forNewcomer, `WELCOME BONUS  +${forNewcomer}`)
	end
end

function SocialService.start()
	local function onAdded(player: Player)
		friends[player] = {}
		publish(player)
		task.spawn(checkInvite, player)
		for _, other in Players:GetPlayers() do
			if other ~= player and friends[other] then
				task.spawn(checkPair, player, other)
			end
		end
	end
	Players.PlayerAdded:Connect(onAdded)
	for _, p in Players:GetPlayers() do
		if not friends[p] then
			onAdded(p)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		local mine = friends[player]
		friends[player] = nil
		Social.forget(toasts, player.UserId)
		for other in mine or {} do
			if friends[other] then
				friends[other][player] = nil
				publish(other)
			end
		end
	end)
end

return SocialService
