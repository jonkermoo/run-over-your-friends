--!strict
-- Daily and weekly challenges (Config/Challenges, Rules/Challenges): the same for everyone on a UTC day or week,
-- picked from the date, so friends can do them together. Progress comes from game events and is saved in the
-- profile; a finished challenge adds a chest of its set, which the player opens from the GOALS sheet (Net
-- "OpenChest"); the server rolls what's inside and pays it. The client gets the whole state when it changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cfg = require(ReplicatedStorage.Shared.Config.Challenges)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local PaintConfig = require(ReplicatedStorage.Shared.Config.Paints)
local Rules = require(ReplicatedStorage.Shared.Rules.Challenges)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Analytics = require(script.Parent.Analytics)
local BuildingService = require(script.Parent.BuildingService)
local Data = require(script.Parent.Data)
local NpcService = require(script.Parent.NpcService)
local RateLimit = require(script.Parent.RateLimit)
local StuntService = require(script.Parent.StuntService)
local VehicleService = require(script.Parent.VehicleService)

local ChallengeService = {}

-- the day's and week's challenges, rolled once per period for the whole server
local lists = {
	day = -1,
	week = -1,
	daily = {} :: { Rules.Challenge },
	weekly = {} :: { Rules.Challenge },
}
local dirty: { [Player]: boolean } = {}
local eventRun = { n = 0, seen = {} :: { [Player]: number } } -- live event runs, and the last one each player joined

local function carName(id: string): string
	local v = Vehicles.ById[id]
	return if v then v.name else id
end

local function current(now: number)
	local day, week = Rules.day(now, Cfg), Rules.week(now, Cfg)
	if day ~= lists.day then
		lists.day = day
		lists.daily = Rules.daily(day, Cfg, carName)
	end
	if week ~= lists.week then
		lists.week = week
		lists.weekly = Rules.weekly(week, Cfg)
	end
end

-- the player's saved challenges, cleaned for this day and week (stored back in the profile)
local function saved(player: Player): Rules.Saved?
	local profile = Data.get(player)
	if not profile then
		return nil
	end
	current(os.time())
	local s = profile.challenges :: any
	if
		typeof(s) ~= "table"
		or typeof(s.daily) ~= "table"
		or typeof(s.weekly) ~= "table"
		or s.daily.period ~= lists.day
		or s.weekly.period ~= lists.week
		or typeof(s.chests) ~= "table"
	then
		s = Rules.clean(s, lists.day, lists.week)
		profile.challenges = s
		dirty[player] = true
	end
	return s :: Rules.Saved
end

local function send(player: Player)
	local s = saved(player)
	if not s then
		return
	end
	Net.remote("Challenges"):FireClient(player, {
		daily = Rules.view(lists.daily, s.daily),
		dailyEnds = Rules.dayEnds(lists.day, Cfg),
		weekly = Rules.view(lists.weekly, s.weekly),
		weeklyEnds = Rules.weekEnds(lists.week, Cfg),
		chests = { Daily = s.chests.Daily, Weekly = s.chests.Weekly },
		day = lists.day,
	}, os.time())
end

-- a game event for this player: `amount` of `kind`, counted in the car they drive now
function ChallengeService.event(player: Player, kind: string, amount: number)
	local s = saved(player)
	if not s then
		return
	end
	local vehicle = VehicleService.of(player)
	local id = vehicle and vehicle:GetAttribute("VehicleId")
	local car = if typeof(id) == "string" then id else nil
	local any = false
	for _, set in { "Daily", "Weekly" } do
		local list = if set == "Daily" then lists.daily else lists.weekly
		local prog = if set == "Daily" then s.daily else s.weekly
		for _, c in list do
			if c.kind == kind and not prog.done[c.id] then
				any = true
			end
		end
		for _, c in Rules.advance(list, prog, kind, amount, car) do
			Rules.addChest(s, set)
			Analytics.challenge(player, set, c.id)
			Net.remote("Popup"):FireClient(
				player,
				Loc.msg(if set == "Daily" then "ChallengeDoneDaily" else "ChallengeDoneWeekly"),
				"goal"
			)
			Data.changed(player)
		end
	end
	if any then
		dirty[player] = true
	end
end

local function openChest(player: Player, set: any)
	if set ~= "Daily" and set ~= "Weekly" then
		return
	end
	if not RateLimit.allow(player, "openChest", Cfg.OpenEvery) then
		return
	end
	local profile = Data.get(player)
	local s = saved(player)
	if not profile or not s or s.chests[set] <= 0 then
		return
	end
	s.chests[set] -= 1
	local rng = Random.new()
	local prize = Rules.prize(
		set,
		rng:NextNumber(),
		rng:NextNumber(),
		PaintConfig.ChestIds,
		profile.paints,
		Cfg
	)
	if prize.paint then
		profile.paints[prize.paint] = true
	end
	if prize.cash > 0 then
		profile.money += prize.cash -- not Data.addMoney: rewards don't count toward "Earn" goals
		Analytics.source(
			player,
			prize.cash,
			Enum.AnalyticsEconomyTransactionType.TimedReward,
			set .. "Chest"
		)
	end
	Analytics.chest(player, set, prize.cash, prize.paint)
	Data.changed(player)
	Net.remote("ChestPrize"):FireClient(player, set, prize.cash, prize.paint or "")
	dirty[player] = true
end

-- a hit, smash or stunt while a live event runs: the player joined that event (once per run)
local function tookPart(player: Player)
	if typeof(workspace:GetAttribute("Event")) ~= "string" then
		return
	end
	if eventRun.seen[player] ~= eventRun.n then
		eventRun.seen[player] = eventRun.n
		ChallengeService.event(player, "Events", 1)
	end
end

function ChallengeService.start()
	current(os.time())
	Net.remote("OpenChest").OnServerEvent:Connect(openChest)
	local function onReady(player: Player)
		while player.Parent and not player:GetAttribute("DataReady") do
			task.wait(0.2)
		end
		if player.Parent then
			send(player)
		end
	end
	Players.PlayerAdded:Connect(onReady)
	for _, p in Players:GetPlayers() do
		task.spawn(onReady, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		dirty[p] = nil
		eventRun.seen[p] = nil
	end)
	workspace:GetAttributeChangedSignal("Event"):Connect(function()
		if typeof(workspace:GetAttribute("Event")) == "string" then
			eventRun.n += 1
		end
	end)

	NpcService.onKnock(function(player, combo)
		ChallengeService.event(player, "Hits", 1)
		ChallengeService.event(player, "Combo", combo)
		tookPart(player)
	end)
	NpcService.onLaunch(function(player, studs)
		ChallengeService.event(player, "Launch", math.floor(studs))
	end)
	BuildingService.onBreak(function(player, count)
		ChallengeService.event(player, "Breaks", count)
		tookPart(player)
	end)
	BuildingService.onCollapse(function(player)
		ChallengeService.event(player, "Collapses", 1)
	end)
	StuntService.onStunt(function(player, kind, amount)
		if kind == "Jumps" or kind == "Spins" or kind == "ParkJumps" or kind == "BestAir" then
			ChallengeService.event(player, kind, amount)
		end
		tookPart(player)
	end)

	if RunService:IsStudio() then
		-- testing: progress or a chest for every player from a workspace attribute
		local attr = Cfg.StudioAttribute
		workspace:GetAttributeChangedSignal(attr):Connect(function()
			local value = workspace:GetAttribute(attr)
			if typeof(value) ~= "string" then
				return
			end
			workspace:SetAttribute(attr, nil) -- so the same value works again
			local kind, amount = string.match(value, "^(%a+):(%w+)$")
			for _, player in Players:GetPlayers() do
				local s = saved(player)
				if s and kind == "Chest" and amount then
					Rules.addChest(s, amount)
					dirty[player] = true
				elseif kind and tonumber(amount) then
					ChallengeService.event(player, kind, tonumber(amount) :: number)
				end
			end
		end)
	end

	-- send changes a few times a second; at midnight UTC everyone gets the new day
	task.spawn(function()
		while true do
			task.wait(Cfg.SendEvery)
			for _, player in Players:GetPlayers() do
				saved(player) -- rolls over to a new day or week (marks dirty)
				if dirty[player] then
					dirty[player] = nil
					send(player)
				end
			end
		end
	end)
end

return ChallengeService
