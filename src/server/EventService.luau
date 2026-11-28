--!strict
-- Server events on a schedule (Config/Events, Rules/Events): after each one a wait of 1-5 minutes, and the
-- longer the wait the bigger the next event (its tier). Low gravity, golden rush, a giant, a stampede, the
-- Cash Drop, Money Truck and Boss Truck (server/EventProps), and contests (Rules/Contest) that score smashing,
-- flinging, hits or jumps and pay the top 3 and everyone who took part (the Boss Truck splits a pot by damage).
-- Clients read the workspace attributes EventPhase ("quiet" | "warn" | "live"), EventKey and EventEndsAt
-- (server time) to draw the banner; Event holds the key only while one is live (NpcService reads it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Events)
local Rules = require(ReplicatedStorage.Shared.Rules.Events)
local Contest = require(ReplicatedStorage.Shared.Rules.Contest)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Analytics = require(script.Parent.Analytics)
local BuildingService = require(script.Parent.BuildingService)
local Data = require(script.Parent.Data)
local EventProps = require(script.Parent.EventProps)
local NpcService = require(script.Parent.NpcService)
local Passes = require(script.Parent.Passes)
local StuntService = require(script.Parent.StuntService)

local EventService = {}

local baseGravity = workspace.Gravity
local giantSpots: { Vector3 } = {}
local giant: Model? = nil
local random = Random.new()
-- the schedule (os.clock times): the next event and when it starts, or the live one and when it ends
local nextIndex = 1
local startAt = 0
local liveIndex: number? = nil
local liveEnds = 0
local lastIndex: number? = nil
local won = false -- the live event was won early (claimed, cracked, beaten)
local forced: number? = nil -- Studio: start this event now

-- the contest running now, if any
type Running = { event: Config.Event, scores: Contest.Scores, names: { [number]: string } }
local running: Running? = nil

function EventService.setGiantSpots(points: { Vector3 })
	giantSpots = points
end

-- the live contest's leader (user id), if one is running and someone has scored (the city map's crown)
function EventService.leader(): number?
	local c = running
	if not c then
		return nil
	end
	local st = Contest.standings(c.scores)
	return if st[1] then st[1].id else nil
end

-- where the live event is happening, if it has one spot (the giant while it stands, a truck, the crate)
function EventService.spot(): Vector3?
	local g = giant
	if g and g.Parent and not g:GetAttribute("Down") then
		return g:GetPivot().Position
	end
	return EventProps.spot()
end

local function nearPlayers(npc: Model): number
	local best = math.huge
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			best = math.min(best, (root.Position - npc:GetPivot().Position).Magnitude)
		end
	end
	return best
end

local function eventOf(key: string): Config.Event?
	for _, e in Config.List do
		if e.key == key then
			return e
		end
	end
	return nil
end

-- a score for the running contest, if it counts this stat
local function score(player: Player, stat: string, amount: number)
	local c = running
	if not c or not c.event.contest or c.event.contest.stat ~= stat then
		return
	end
	if Contest.record(c.scores, player.UserId, c.event.contest.mode, amount, os.clock()) then
		c.names[player.UserId] = player.DisplayName
	end
end

-- each player's view: the top few, and their own place and score
local function sendStandings(c: Running)
	local st = Contest.standings(c.scores)
	local top = {}
	for i = 1, math.min(Config.ContestShown, #st) do
		table.insert(top, { name = c.names[st[i].id] or "?", score = st[i].score })
	end
	local placeOf = {}
	for _, p in st do
		placeOf[p.id] = p
	end
	for _, player in Players:GetPlayers() do
		local mine = placeOf[player.UserId]
		Net.remote("Contest"):FireClient(player, {
			key = c.event.key,
			top = top,
			place = if mine then mine.place else 0,
			score = if mine then mine.score else 0,
			count = #st,
		})
	end
end

local function beginContest(event: Config.Event)
	local c: Running = { event = event, scores = {}, names = {} }
	running = c
	task.spawn(function()
		while running == c do
			sendStandings(c)
			task.wait(Config.ContestSendSeconds)
		end
	end)
end

local function finishContest()
	local c = running
	running = nil
	if not c or not c.event.contest then
		return
	end
	local st = Contest.standings(c.scores)
	local share = c.event.contest.pay == "share"
	local prizes: { [number]: number }
	if share then
		-- the Boss Truck: its pot split by damage, in full if it was beaten; money passes count
		local B = Config.BossTruck
		local pot = B.Pot * Config.PayScale * (if EventProps.beaten() then 1 else B.FailShare)
		prizes = Contest.shares(st, pot, B.MinShare * Config.PayScale)
	else
		prizes = Contest.prizes(
			st,
			Config.ContestPrizes,
			Config.ContestTakePart,
			Config.ContestFullField
		)
	end
	local unit = c.event.contest.unit
	for _, p in st do
		local player = Players:GetPlayerByUserId(p.id)
		local pay = prizes[p.id]
		if not (player and pay) then
			continue
		end
		if share then
			pay = math.floor(pay * Passes.moneyMultiplier(player) + 0.5)
			prizes[p.id] = pay
		end
		Data.addMoney(player, pay)
		Analytics.eventPaid(player, c.event.key, if share then "Share" else "Prize", pay)
		if share then
			Net.remote("Popup"):FireClient(player, Loc.msg("BossPay", { pay = pay }), "big")
			continue
		end
		local label = if p.place <= #Config.ContestPrizes
			then Loc.msg(
				"ContestPlace",
				{ place = Loc.ordinal(p.place), event = Loc.src(c.event.title) }
			)
			else Loc.src("FOR TAKING PART")
		Net.remote("Popup")
			:FireClient(player, Loc.msg("ContestPay", { pay = pay, label = label }), "big")
	end
	if #st == 0 then
		return
	end
	-- the podium (client/Podium): the top 3 for everyone, plus each player's own place and prize
	local top = {}
	for i = 1, math.min(#Config.ContestPrizes, #st) do
		local p = st[i]
		table.insert(
			top,
			{ id = p.id, name = c.names[p.id] or "?", score = p.score, prize = prizes[p.id] or 0 }
		)
	end
	local placeOf = {}
	for _, p in st do
		placeOf[p.id] = p
	end
	for _, everyone in Players:GetPlayers() do
		local mine = placeOf[everyone.UserId]
		Net.remote("Podium"):FireClient(everyone, {
			title = c.event.title,
			unit = unit,
			top = top,
			place = if mine then mine.place else 0,
			score = if mine then mine.score else 0,
			prize = if mine then prizes[mine.id] or 0 else 0,
		})
	end
end

-- the live event was beaten: it ends EndLinger seconds from now (the schedule plans the next from then)
local function beaten()
	if not won then
		won = true
		liveEnds = math.min(liveEnds, os.clock() + Config.EndLinger)
	end
end

local function begin(key: string)
	local event = eventOf(key)
	if event and event.contest then
		beginContest(event)
	end
	if key == "LowGravity" then
		workspace.Gravity = baseGravity * Config.LowGravityScale
	elseif key == "GoldenRush" then
		-- the golden ones are near players, so there's something to chase straight away
		local list = NpcService.all()
		table.sort(list, function(a, b)
			return nearPlayers(a) < nearPlayers(b)
		end)
		for i = 1, math.min(Config.GoldenCount, #list) do
			NpcService.makeGolden(list[i])
		end
	elseif key == "Giant" then
		local at = if #giantSpots > 0
			then giantSpots[random:NextInteger(1, #giantSpots)]
			else Vector3.new(0, 0, 0)
		giant = NpcService.spawnGiant(at)
	elseif key == "CashDrop" or key == "MoneyTruck" or key == "BossTruck" then
		EventProps.begin(key, {
			score = function(player, amount)
				score(player, "Damage", amount)
			end,
			won = function()
				beaten()
			end,
			paid = function(player, what, amount)
				Analytics.eventPaid(player, key, what, amount)
			end,
		})
	end
end

local function finish(key: string)
	if running and running.event.key == key then
		finishContest()
	end
	if key == "LowGravity" then
		workspace.Gravity = baseGravity
	elseif key == "GoldenRush" then
		NpcService.clearGolden()
	elseif key == "Giant" then
		-- an untoppled giant wanders off
		if giant and giant.Parent and not giant:GetAttribute("Down") then
			giant:Destroy()
		end
		giant = nil
	elseif key == "CashDrop" or key == "MoneyTruck" or key == "BossTruck" then
		EventProps.finish()
	end
end

-- start the next event's countdown now (a server goal reward); false when one is already on its way or live
function EventService.hurry(): boolean
	local t = os.clock()
	if liveIndex or startAt - t <= Config.WarnSeconds then
		return false
	end
	startAt = t + Config.WarnSeconds
	return true
end

-- the next event and its wait, after `last` (nil: a new server's first, FirstAfter from now)
local function plan(last: number?)
	local gap
	nextIndex, gap = Rules.pick(
		Config.List,
		Config.Tiers,
		last,
		random:NextNumber(),
		random:NextNumber(),
		random:NextNumber(),
		if last then nil else Config.FirstAfter
	)
	startAt = os.clock() + gap
end

local function goLive(i: number)
	local event = Config.List[i]
	liveIndex = i
	won = false
	liveEnds = os.clock() + Rules.duration(event, Config.Tiers)
	workspace:SetAttribute("Event", event.key)
	begin(event.key)
end

local function endLive()
	local i = liveIndex
	if not i then
		return
	end
	local key = Config.List[i].key
	local g = giant
	local toppled = key == "Giant" and g ~= nil and g:GetAttribute("Down") == true
	finish(key)
	Analytics.eventEnded(key, if won or toppled then "Won" else "Time")
	liveIndex = nil
	lastIndex = i
	workspace:SetAttribute("Event", nil)
end

local function tick()
	local t = os.clock()
	local f = forced
	if f then
		forced = nil
		endLive()
		nextIndex, startAt = f, t
	end
	-- a toppled giant ends its event (the topple bonus is paid as it falls, NpcService)
	local g = giant
	if liveIndex and Config.List[liveIndex].key == "Giant" and g and g:GetAttribute("Down") then
		beaten()
	end
	if liveIndex and t >= liveEnds then
		endLive()
		plan(lastIndex)
	elseif not liveIndex and t >= startAt then
		goLive(nextIndex)
	end
	local live = liveIndex
	local phase, endsIn = "live", liveEnds - t
	if not live then
		local untilStart = startAt - t
		phase = if untilStart <= Config.WarnSeconds then "warn" else "quiet"
		endsIn = if phase == "warn" then untilStart else untilStart - Config.WarnSeconds
	end
	workspace:SetAttribute("EventPhase", phase)
	workspace:SetAttribute("EventKey", Config.List[live or nextIndex].key)
	workspace:SetAttribute("EventEndsAt", workspace:GetServerTimeNow() + math.max(endsIn, 0))
end

function EventService.start()
	Net.remote("Podium") -- made now, so screens can listen before the first contest ends
	EventProps.start()
	BuildingService.onBreak(function(player, count)
		score(player, "Breaks", count)
	end)
	NpcService.onKnock(function(player)
		score(player, "Hits", 1)
	end)
	NpcService.onLaunch(function(player, studs)
		if studs >= Config.ContestMinLaunch then
			score(player, "Launch", math.floor(studs + 0.5))
		end
	end)
	StuntService.onStunt(function(player, kind, amount)
		if kind == "Stunt" then
			score(player, "Stunt", amount)
		end
	end)
	plan(nil)
	if RunService:IsStudio() then
		-- testing: start the named event now (ending the live one)
		local attr = Config.StudioStartAttribute
		workspace:GetAttributeChangedSignal(attr):Connect(function()
			local key = workspace:GetAttribute(attr)
			for i, e in Config.List do
				if e.key == key then
					forced = i
					workspace:SetAttribute(attr, nil) -- so the same key can start it again
				end
			end
		end)
	end
	task.spawn(function()
		while true do
			local ok, err = pcall(tick)
			if not ok then
				warn("[EventService]", err)
			end
			task.wait(0.25)
		end
	end)
end

return EventService
