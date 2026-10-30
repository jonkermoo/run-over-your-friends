--!strict
-- Weekly leaderboards (most run over, biggest launch, biggest combo). Each player's numbers live in their
-- profile; changed scores go to one OrderedDataStore per board per week. The boards read the top entries
-- once a minute and mix in the live numbers of everyone in this server, so your own progress shows at once.
-- Without DataStore access (an unpublished place) the boards show this server only.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Leaderboards)
local Lb = require(ReplicatedStorage.Shared.Rules.Leaderboards)
local Net = require(ReplicatedStorage.Shared.Net)
local Data = require(script.Parent.Data)
local NpcService = require(script.Parent.NpcService)

local LeaderboardService = {}

local stored: { [string]: { Lb.Entry } } = {} -- last read of each board's store
local names: { [number]: string } = {}
local dirty: { [Player]: boolean } = {}
local lastSent = ""

local function now(): number
	return os.time()
end

local function week(): number
	return Lb.week(now(), Config.WeekSeconds, Config.WeekStartOffset)
end

local function store(key: string): OrderedDataStore?
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(`Lb_{key}_w{week()}`)
	end)
	return if ok then result else nil
end

-- the player's stats table, created and rolled to this week as needed
local function statsOf(player: Player): Lb.Stats?
	local profile = Data.get(player)
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
		local ds = store(board.key)
		if ds and value > 0 then
			pcall(function()
				(ds :: OrderedDataStore):SetAsync(tostring(player.UserId), value)
			end)
		end
	end
end

local function readStores()
	for _, board in Config.Boards do
		local ds = store(board.key)
		local entries: { Lb.Entry } = {}
		if ds then
			local ok, pages = pcall(function()
				return (ds :: OrderedDataStore):GetSortedAsync(false, Config.Top)
			end)
			if ok and pages then
				for _, item in (pages :: DataStorePages):GetCurrentPage() do
					local id = tonumber(item.key)
					if id then
						table.insert(
							entries,
							{ userId = id, name = nameOf(id), value = item.value }
						)
					end
				end
			end
		end
		stored[board.key] = entries
	end
end

-- stored tops mixed with everyone here right now
local function broadcast(force: boolean)
	local boards = {}
	for _, board in Config.Boards do
		local byId: { [number]: Lb.Entry } = {}
		for _, e in stored[board.key] or {} do
			byId[e.userId] = { userId = e.userId, name = e.name, value = e.value }
		end
		for _, p in Players:GetPlayers() do
			local s = statsOf(p)
			if s then
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
		boards[board.key] = Lb.rank(list, Config.Top)
	end
	local endsAt = now() + Lb.secondsLeft(now(), Config.WeekSeconds, Config.WeekStartOffset)
	local payload = { endsAt = endsAt, now = now(), boards = boards }
	-- only send when something changed (or to catch a new player up)
	local signature = game:GetService("HttpService"):JSONEncode(boards)
	if force or signature ~= lastSent then
		lastSent = signature
		Net.remote("Boards"):FireAllClients(payload)
	end
end

function LeaderboardService.start()
	local function onReady(player: Player)
		while player.Parent and not player:GetAttribute("DataReady") do
			task.wait(0.2)
		end
		local s = statsOf(player)
		if s then
			setLeaderstat(player, s)
		end
		broadcast(true)
	end
	Players.PlayerAdded:Connect(onReady)
	for _, p in Players:GetPlayers() do
		task.spawn(onReady, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		save(p)
		dirty[p] = nil
	end)

	NpcService.onKnock(function(player, combo)
		record(player, "Hits", 1)
		record(player, "Combo", combo)
	end)
	NpcService.onLaunch(function(player, studs)
		record(player, "Launch", math.floor(studs))
	end)

	task.spawn(function()
		readStores()
		local lastRead, lastSave = os.clock(), os.clock()
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
			end
			broadcast(false)
		end
	end)
end

return LeaderboardService
