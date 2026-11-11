--!strict
-- Server events on a schedule (Config/Events, Rules/Events): low gravity, golden rush, a giant, a stampede,
-- and contests (Rules/Contest) that score smashing, flinging, hits or jumps and pay the top 3 and everyone who took part.
-- Clients read the workspace attributes EventPhase ("quiet" | "warn" | "live"), EventKey and EventEndsAt
-- (server time) to draw the banner; Event holds the key only while one is live (NpcService reads it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Events)
local Rules = require(ReplicatedStorage.Shared.Rules.Events)
local Contest = require(ReplicatedStorage.Shared.Rules.Contest)
local Net = require(ReplicatedStorage.Shared.Net)
local BuildingService = require(script.Parent.BuildingService)
local Data = require(script.Parent.Data)
local NpcService = require(script.Parent.NpcService)
local StuntService = require(script.Parent.StuntService)

local EventService = {}

local baseGravity = workspace.Gravity
local giantSpots: { Vector3 } = {}
local giant: Model? = nil
local random = Random.new()
local t0 = os.clock() -- the schedule's start; hurry() moves it to bring the next event forward
local phase = "quiet"
local untilWarn = 0
local offset = 0 -- which event in the list comes first
local restart = false -- Studio: start the live event over (a fresh giant)

-- the contest running now, if any
type Running = { event: Config.Event, scores: Contest.Scores, names: { [number]: string } }
local running: Running? = nil

function EventService.setGiantSpots(points: { Vector3 })
	giantSpots = points
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
	local won = Contest.prizes(st, Config.ContestPrizes, Config.ContestTakePart)
	local unit = c.event.contest.unit
	for _, p in st do
		local player = Players:GetPlayerByUserId(p.id)
		local pay = won[p.id]
		if player and pay then
			Data.addMoney(player, pay)
			local label = if p.place <= #Config.ContestPrizes
				then `{Contest.ordinal(p.place)} IN {c.event.title}!`
				else "FOR TAKING PART"
			Net.remote("Popup"):FireClient(player, `+${pay}  {label}`, "big")
		end
	end
	if #st == 0 then
		return
	end
	local lines = {}
	for i = 1, math.min(#Config.ContestPrizes, #st) do
		local p = st[i]
		table.insert(
			lines,
			`{Contest.ordinal(i)} {c.names[p.id] or "?"} ({Contest.amount(p.score, unit)})`
		)
	end
	for _, everyone in Players:GetPlayers() do
		Net.remote("Celebrate")
			:FireClient(everyone, c.event.title .. " WINNERS", table.concat(lines, "   "))
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
	end
end

-- start the next event's countdown now (a server goal reward); false when one is already on its way or live
function EventService.hurry(): boolean
	if phase ~= "quiet" then
		return false
	end
	t0 -= untilWarn
	untilWarn = 0
	return true
end

function EventService.start()
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
	t0 = os.clock()
	offset = random:NextInteger(0, #Config.List - 1)
	if RunService:IsStudio() then
		-- testing: put the schedule at the start of the named event
		local attr = Config.StudioStartAttribute
		workspace:GetAttributeChangedSignal(attr):Connect(function()
			local key = workspace:GetAttribute(attr)
			for i, e in Config.List do
				if e.key == key then
					offset = i - 1
					t0 = os.clock() - Config.FirstAfter
					restart = true
					workspace:SetAttribute(attr, nil) -- so the same key can start it again
				end
			end
		end)
	end
	local live: string? = nil
	task.spawn(function()
		while true do
			local ph = Rules.phase(
				os.clock() - t0,
				#Config.List,
				Config.FirstAfter,
				Config.GapSeconds,
				Config.DurationSeconds,
				Config.WarnSeconds,
				offset
			)
			local event = Config.List[ph.index]
			local key = if event then event.key else ""
			local nowLive = if ph.phase == "live" then key else nil
			if nowLive ~= live or restart then
				restart = false
				if live then
					finish(live)
				end
				live = nowLive
				workspace:SetAttribute("Event", live)
				if live then
					begin(live)
				end
			end
			phase = ph.phase
			untilWarn = if ph.phase == "quiet" then ph.endsIn else 0
			workspace:SetAttribute("EventPhase", ph.phase)
			workspace:SetAttribute("EventKey", key)
			workspace:SetAttribute("EventEndsAt", workspace:GetServerTimeNow() + ph.endsIn)
			task.wait(0.5)
		end
	end)
end

return EventService
