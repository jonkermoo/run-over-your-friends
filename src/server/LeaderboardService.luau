--!strict
-- Leaderboards (Config/Leaderboards): weekly most run over, biggest launch and biggest combo; all-time most
-- run over and richest (money earned by playing). Each player's numbers live in their profile; changed scores
-- go to one OrderedDataStore per board (per week for the weekly ones). The boards read the top entries once a
-- minute and mix in the live numbers of everyone in this server, so your own progress shows at once. Each
-- player also gets their own row: their rank in the top ReadTop and the gap to the next place. The #1 of each
-- podium board goes to ChampionService; while nobody has scored this week, the weekly step shows last week's #1.
-- Without DataStore access (an unpublished place) the boards show this server only.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config.Leaderboards)
local Lb = require(ReplicatedStorage.Shared.Rules.Leaderboards)
local Net = require(ReplicatedStorage.Shared.Net)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local ChampionService = require(script.Parent.ChampionService)
local Data = require(script.Parent.Data)
local NpcService = require(script.Parent.NpcService)

local LeaderboardService = {}

local stored: { [string]: { Lb.Entry } } = {} -- last read of each board's store (top ReadTop)
local lastWeekTop: Lb.Entry? = nil -- last week's #1 of the weekly run-over board
local names: { [number]: string } = {}
local dirty: { [Player]: boolean } = {}
local lastSent: { [Player]: string } = {}

local function now(): number
	return os.time()
end

local function week(): number
	return Lb.week(now(), Config.WeekSeconds, Config.WeekStartOffset)
end

-- a weekly board's store for week `w` (this week by default); one store for good for an all-time board
local function store(board: Config.Board, w: number?): OrderedDataStore?
	local name = if board.allTime then `Lb_{board.key}` else `Lb_{board.key}_w{w or week()}`
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	return if ok then result else nil
end

-- the player's stats table, created and rolled to this week as needed. The all-time money count starts from
-- what they hold plus what their cars cost: a one-time estimate of what they earned before it existed (it can
-- include Robux packs and cars bought before then); from then on only money earned by playing adds to it
local function statsOf(player: Player): Lb.Stats?
	-- not before the profile has loaded: the money count would start from a default balance
	local profile = if player:GetAttribute("DataReady") then Data.get(player) else nil
	if not profile then
		return nil
	end
	local s = profile.stats
	if typeof(s.week) ~= "number" then
		local fresh = Lb.fresh(week())
		for k, v in fresh do
			s[k] = if typeof(s[k]) == "number" then s[k] else v
		end
	end
	if typeof(s.allEarned) ~= "number" then
		local prices = {}
		for id, owned in profile.owned do
			local v = Vehicles.ById[id]
			if owned and v then
				table.insert(prices, v.price)
			end
		end
		s.allEarned = Lb.earnedSeed(profile.money, prices)
		dirty[player] = true
	end
	Lb.roll(s :: any, week())
	return s :: any
end

local function setLeaderstat(player: Player, s: Lb.Stats)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		return
	end
	local v = folder:FindFirstChild("Run Over") :: IntValue?
	if not v then
		local created = Instance.new("IntValue")
		created.Name = "Run Over"
		created.Parent = folder
		v = created
	end
	(v :: IntValue).Value = s.allHits
end

local function record(player: Player, key: string, value: number)
	local s = statsOf(player)
	if s and Lb.record(s, key, value) then
		dirty[player] = true
		setLeaderstat(player, s)
	end
end

local function nameOf(userId: number): string
	local n = names[userId]
	if n then
		return n
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	n = if ok and result then result else "Player"
	names[userId] = n
	return n
end

local function save(player: Player)
	local s = statsOf(player)
	if not s or not dirty[player] then
		return
	end
	dirty[player] = nil
	for _, board in Config.Boards do
		local value = math.floor(Lb.value(s, board.key))
		local ds = store(board)
		if ds and value > 0 then
			pcall(function()
				(ds :: OrderedDataStore):SetAsync(tostring(player.UserId), value)
			end)
		end
	end
end

-- the top `count` of a store, names looked up, hidden players left out
local function readTop(ds: OrderedDataStore?, count: number): { Lb.Entry }
	local entries: { Lb.Entry } = {}
	if not ds then
		return entries
	end
	local ok, pages = pcall(function()
		return (ds :: OrderedDataStore):GetSortedAsync(false, count)
	end)
	if ok and pages then
		for _, item in (pages :: DataStorePages):GetCurrentPage() do
			local id = tonumber(item.key)
			if id then
				table.insert(entries, { userId = id, name = names[id] or "", value = item.value })
			end
		end
	end
	entries = Lb.visible(entries, Config.Hidden)
	-- names only for the rows a board shows (the rest only count for ranks): a web call each, cached
	for i = 1, math.min(#entries, Config.Top) do
		if entries[i].name == "" then
			entries[i].name = nameOf(entries[i].userId)
		end
	end
	return entries
end

local function readStores()
	if RunService:IsStudio() and game.PlaceId == 0 then
		return -- an unpublished place has no DataStores (keeps StudioBoards entries)
	end
	for _, board in Config.Boards do
		stored[board.key] = readTop(store(board), Config.ReadTop)
	end
end

local function readLastWeek()
	for _, board in Config.Boards do
		if board.key == "Hits" then
			lastWeekTop = readTop(store(board, week() - 1), 1)[1]
		end
	end
end

-- stored tops mixed with everyone here right now, ranked to ReadTop
local function merged(): { [string]: { Lb.Entry } }
	local out = {}
	for _, board in Config.Boards do
		local byId: { [number]: Lb.Entry } = {}
		for _, e in stored[board.key] or {} do
			byId[e.userId] = { userId = e.userId, name = e.name, value = e.value }
		end
		for _, p in Players:GetPlayers() do
			local s = statsOf(p)
			if s and not Config.Hidden[p.UserId] then
				local v = math.floor(Lb.value(s, board.key))
				local e = byId[p.UserId]
				if not e or v > e.value then
					byId[p.UserId] = { userId = p.UserId, name = p.DisplayName, value = v }
				end
			end
		end
		local list = {}
		for _, e in byId do
			table.insert(list, e)
		end
		out[board.key] = Lb.rank(list, Config.ReadTop)
	end
	return out
end

local function broadcast(force: boolean)
	local full = merged()
	local boards = {}
	for key, list in full do
		boards[key] = table.move(list, 1, math.min(#list, Config.Top), 1, {})
	end
	-- the podium: each step's #1 (the weekly one falls back to last week's while this week is empty)
	ChampionService.update("Earned", full.Earned[1], false)
	ChampionService.update("HitsAll", full.HitsAll[1], false)
	if full.Hits[1] then
		ChampionService.update("Hits", full.Hits[1], false)
	else
		ChampionService.update("Hits", lastWeekTop, true)
	end
	local endsAt = now() + Lb.secondsLeft(now(), Config.WeekSeconds, Config.WeekStartOffset)
	local shared = HttpService:JSONEncode(boards)
	for _, p in Players:GetPlayers() do
		local s = statsOf(p)
		if not s then
			continue
		end
		local you = {}
		for _, board in Config.Boards do
			you[board.key] = Lb.you(
				full[board.key],
				p.UserId,
				math.floor(Lb.value(s, board.key)),
				Config.ReadTop
			)
		end
		-- only send when something this player sees changed (or to catch a new player up)
		local signature = shared .. HttpService:JSONEncode(you)
		if force or signature ~= lastSent[p] then
			lastSent[p] = signature
			Net.remote("Boards")
				:FireClient(p, { endsAt = endsAt, now = now(), boards = boards, you = you })
		end
	end
end

function LeaderboardService.start()
	ChampionService.start()
	local function onReady(player: Player)
		while player.Parent and not player:GetAttribute("DataReady") do
			task.wait(0.2)
		end
		local s = statsOf(player)
		if s then
			setLeaderstat(player, s)
		end
		lastSent[player] = nil
		broadcast(false)
	end
	Players.PlayerAdded:Connect(onReady)
	for _, p in Players:GetPlayers() do
		task.spawn(onReady, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		save(p)
		dirty[p] = nil
		lastSent[p] = nil
	end)

	NpcService.onKnock(function(player, combo)
		record(player, "Hits", 1)
		record(player, "Combo", combo)
	end)
	NpcService.onLaunch(function(player, studs)
		record(player, "Launch", math.floor(studs))
	end)
	Data.onEarn(function(player, amount)
		record(player, "Earned", amount)
	end)

	-- Studio only (no DataStores there): ServerStorage.StudioBoards:Fire(key, userId, value) puts a stored
	-- entry on a board, so the boards and the podium can be tried with other players' avatars
	if RunService:IsStudio() then
		local hook = Instance.new("BindableEvent")
		hook.Name = "StudioBoards"
		hook.Parent = ServerStorage
		hook.Event:Connect(function(key: string, userId: number, value: number)
			local name = nameOf(userId) -- yields: read the board after it
			local list = stored[key] or {}
			for i = #list, 1, -1 do
				if list[i].userId == userId then
					table.remove(list, i)
				end
			end
			table.insert(list, { userId = userId, name = name, value = value })
			stored[key] = Lb.rank(list, Config.ReadTop)
		end)
	end

	task.spawn(function()
		readStores()
		readLastWeek()
		local lastRead, lastSave, lastWeekRead = os.clock(), os.clock(), os.clock()
		while true do
			task.wait(3)
			if os.clock() - lastSave >= Config.SaveSeconds then
				lastSave = os.clock()
				for p in dirty do
					task.spawn(save, p)
				end
			end
			if os.clock() - lastRead >= Config.RefreshSeconds then
				lastRead = os.clock()
				readStores()
				-- last week's #1 is only needed while this week's board is empty
				if
					#(stored.Hits or {}) == 0
					and os.clock() - lastWeekRead >= Config.LastWeekSeconds
				then
					lastWeekRead = os.clock()
					readLastWeek()
				end
			end
			broadcast(false)
		end
	end)
end

return LeaderboardService
