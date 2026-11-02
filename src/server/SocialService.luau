--!strict
-- Playing together (Config/Social, Rules/Social). Roblox friends in the same server boost each other's hit
-- money; the count is published as the player attribute Friends for the HUD chip. When one player launches
-- another (Wrecker hits and blasts), the flight is watched and both get a toast with how far it went.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Social)
local Net = require(ReplicatedStorage.Shared.Net)
local Social = require(ReplicatedStorage.Shared.Rules.Social)

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

function SocialService.start()
	local function onAdded(player: Player)
		friends[player] = {}
		publish(player)
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
