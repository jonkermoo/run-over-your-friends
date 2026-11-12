--!strict
-- Server goals (Config/ServerGoals, Rules/ServerGoals): one shared goal at a time for everyone on the
-- server, taking turns between kinds. Finishing it in time starts the next server event now and pays
-- each helper. Other services add progress with ServerGoalService.add(player, kind, amount).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.ServerGoals)
local Net = require(ReplicatedStorage.Shared.Net)
local Rules = require(ReplicatedStorage.Shared.Rules.ServerGoals)
local Analytics = require(script.Parent.Analytics)
local BuildingService = require(script.Parent.BuildingService)
local Data = require(script.Parent.Data)
local EventService = require(script.Parent.EventService)
local NpcService = require(script.Parent.NpcService)
local StuntService = require(script.Parent.StuntService)

local ServerGoalService = {}

local goal: Rules.Goal? = nil
local index = Random.new():NextInteger(0, #Config.Kinds - 1)
local nextAt = 0 -- os.time() when the next goal starts, once this one is over
local dirty = false

-- the same shape as an Hourly/Daily set, so the goals sheet draws it like one. Between goals (after one
-- ran out of time) it's a set with no goals that counts down to the next, so a pinned card can wait for it.
local function view()
	if not goal then
		return if nextAt > os.time() then { goals = {}, endsAt = nextAt } else nil
	end
	return {
		goals = {
			{
				text = goal.text,
				target = goal.target,
				progress = goal.progress,
				reward = Config.Reward,
				done = goal.done,
			},
		},
		endsAt = if goal.done then nextAt else goal.endsAt, -- a done goal counts down to the next one
	}
end

local function send(player: Player?)
	if player then
		Net.remote("ServerGoal"):FireClient(player, view(), os.time())
	else
		Net.remote("ServerGoal"):FireAllClients(view(), os.time())
	end
end

local function payHelper(player: Player, amount: number, text: string)
	local profile = Data.get(player)
	if not profile then
		return
	end
	profile.money += amount -- not Data.addMoney: rewards don't count toward "Earn" goals
	Data.changed(player)
	Analytics.source(player, amount, Enum.AnalyticsEconomyTransactionType.TimedReward, "ServerGoal")
	Net.remote("Popup"):FireClient(player, text, "goal")
end

local function finish(g: Rules.Goal)
	nextAt = os.time() + Config.Pause
	local early = EventService.hurry()
	for _, player in Players:GetPlayers() do
		if g.helpers[player.UserId] then
			payHelper(player, Config.Reward, `SERVER GOAL!  +${Config.Reward}`)
		end
		Net.remote("Celebrate"):FireClient(
			player,
			"SERVER GOAL DONE!",
			if early then "The next event starts now!" else "Everyone who helped gets a bonus!"
		)
	end
end

-- out of time: past PartialShare each helper gets that share of the reward and everyone sees how close it
-- came; under it, just how far it got (nothing at all when nobody helped)
local function timeUp(g: Rules.Goal)
	if g.progress <= 0 then
		return
	end
	local pay = Rules.partialPay(g, Config.Reward, Config.PartialShare)
	local score = `{g.progress} / {g.target}`
	for _, player in Players:GetPlayers() do
		local helped = g.helpers[player.UserId] == true
		if pay > 0 and helped then
			payHelper(player, pay, `SO CLOSE!  +${pay}`)
		end
		Net.remote("Celebrate"):FireClient(
			player,
			if pay > 0 then "SO CLOSE!" else "TIME'S UP!",
			if pay > 0 and helped
				then `Server goal {score}. You still get +${pay} for helping!`
				elseif pay > 0 then `Server goal {score}. Helpers get +${pay}. Join the next one!`
				else `Server goal {score}. The next one starts soon!`
		)
	end
end

-- progress from anywhere in the game (activities can add their own kinds)
function ServerGoalService.add(player: Player, kind: string, amount: number)
	local g = goal
	if not g then
		return
	end
	if Rules.add(g, kind, amount, player.UserId, os.time()) then
		finish(g)
	end
	dirty = true
end

function ServerGoalService.start()
	NpcService.onKnock(function(player)
		ServerGoalService.add(player, "Hits", 1)
	end)
	BuildingService.onBreak(function(player, count)
		ServerGoalService.add(player, "Breaks", count)
	end)
	StuntService.onStunt(function(player, kind, amount)
		if kind == "Jumps" then
			ServerGoalService.add(player, "Jumps", amount)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		send(player)
	end)

	task.spawn(function()
		while true do
			local now = os.time()
			local players = #Players:GetPlayers()
			if goal and not goal.done and now >= goal.endsAt then
				-- ran out of time: it leaves the sheet and the next comes after the pause
				local g = goal
				goal = nil
				nextAt = now + Config.Pause
				dirty = true
				timeUp(g)
			end
			if (not goal or goal.done) and now >= nextAt and players > 0 then
				index = Rules.nextIndex(index, #Config.Kinds)
				goal =
					Rules.make(Config.Kinds[index], players, Config.MinPlayers, now, Config.Seconds)
				dirty = true
			end
			if dirty then
				dirty = false
				send()
			end
			task.wait(0.5)
		end
	end)
end

return ServerGoalService
