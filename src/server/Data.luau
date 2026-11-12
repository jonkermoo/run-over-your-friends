--!strict
-- Player profiles: money, owned vehicles, one-time rewards. Saved with DataStores; if a load fails,
-- that player plays on session-only data and nothing is written for them.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Impact = require(ReplicatedStorage.Shared.Rules.Impact)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local OnboardingRules = require(ReplicatedStorage.Shared.Rules.Onboarding)
local PaintRules = require(ReplicatedStorage.Shared.Rules.Paints)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)

export type Profile = {
	money: number, -- fractional; rounded only for display
	owned: { [string]: boolean },
	groupClaimed: boolean,
	roadsterPassPaid: boolean,
	tutorial: number, -- Config/Onboarding Steps
	quests: { [string]: any }, -- Hourly/Daily goal sets, checked by QuestService
	stats: { [string]: any }, -- leaderboard numbers, checked by LeaderboardService
	receipts: { [string]: boolean }, -- Robux purchase ids already granted
	bought: { [string]: boolean }, -- one-time products already bought
	paint: { [string]: string }, -- vehicle id -> paint id (Config/Paints); missing = Factory
	paints: { [string]: boolean }, -- paid paint colours
	daily: { day: number, streak: number }?, -- last UTC day the login streak was collected, checked by DailyService
	sale: { day: number, id: string? }?, -- this player's car of the day and the UTC day it was picked, by DailyService
	rookieDone: boolean, -- rookie pay (Config/Economy) has ended for good: they could afford the RookieUntil car
}

local ROOKIE_PRICE = Vehicles.ById[Economy.RookieUntil].price

local Data = {}

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("Profiles_v1")
end)

local profiles: { [Player]: Profile } = {}
local loadFailed: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}
local inFlight = 0

local function default(): Profile
	return {
		money = Economy.StartMoney,
		owned = { [Vehicles.Starter] = true },
		groupClaimed = false,
		roadsterPassPaid = false,
		tutorial = 1,
		quests = {},
		stats = {},
		receipts = {},
		bought = {},
		paint = {},
		paints = {},
		rookieDone = false,
	}
end

local function publish(player: Player, profile: Profile)
	-- every money or garage change passes here: once rookie pay is over it stays over, even after spending
	if
		not profile.rookieDone
		and Impact.rookieOver(profile.owned, profile.money, false, Vehicles.ById, ROOKIE_PRICE)
	then
		profile.rookieDone = true
	end
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
		local m = Instance.new("IntValue")
		m.Name = "Money"
		m.Parent = stats
	end
	((stats :: Instance):FindFirstChild("Money") :: IntValue).Value = math.floor(profile.money)
	player:SetAttribute("Money", profile.money)
	local owned = {}
	for id in profile.owned do
		table.insert(owned, id)
	end
	player:SetAttribute("Owned", table.concat(owned, ","))
	player:SetAttribute("GroupClaimed", profile.groupClaimed)
	player:SetAttribute("Tutorial", profile.tutorial)
	local bought = {}
	for key, yes in profile.bought do
		if yes then
			table.insert(bought, key)
		end
	end
	player:SetAttribute("Bought", table.concat(bought, ","))
	player:SetAttribute("Paint", PaintRules.encode(profile.paint))
	local paints = {}
	for id in profile.paints do
		table.insert(paints, id)
	end
	table.sort(paints)
	player:SetAttribute("Paints", table.concat(paints, ","))
end

function Data.get(player: Player): Profile?
	return profiles[player]
end

function Data.changed(player: Player)
	local p = profiles[player]
	if p then
		publish(player, p)
	end
end

local earnListeners: { (Player, number) -> () } = {}

-- called whenever money is earned by playing (not goal rewards or purchases)
function Data.onEarn(listener: (Player, number) -> ())
	table.insert(earnListeners, listener)
end

function Data.addMoney(player: Player, amount: number)
	local p = profiles[player]
	if p and amount == amount then
		p.money = math.max(0, p.money + amount)
		publish(player, p)
		if amount > 0 then
			for _, listener in earnListeners do
				task.spawn(listener, player, amount)
			end
		end
	end
end

-- Session lock: a saved profile carries { job, at } for the server using it. Another server waits for it
-- (or for it to go stale) before loading, so two servers never write over each other's progress.
local LOCK_STALE = 150 -- seconds without a save before a lock counts as abandoned (autosave refreshes it)

local function withLock(p: Profile, release: boolean): string
	local copy = table.clone(p) :: any
	copy.lock = if release then nil else { job = game.JobId, at = os.time() }
	return HttpService:JSONEncode(copy)
end

local function save(player: Player, release: boolean?): boolean
	local p = profiles[player]
	if not (store and p) or loadFailed[player] or saving[player] then
		return false
	end
	saving[player] = true
	inFlight += 1
	local blob = withLock(p, release == true)
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync("u" .. player.UserId, blob)
	end)
	if not ok then
		warn("save failed for", player.UserId, err)
	end
	inFlight -= 1
	saving[player] = nil
	return ok
end

-- save right away (after a Robux purchase); true when the profile is safely stored, or when this
-- server has no DataStore at all (Studio, unpublished), where everything is session-only anyway
function Data.saveNow(player: Player): boolean
	if not store or not profiles[player] then
		return store == nil and profiles[player] ~= nil
	end
	if loadFailed[player] then
		return false
	end
	while saving[player] do
		task.wait(0.1)
	end
	return save(player)
end

local function load(player: Player)
	local profile = default()
	if store then
		-- take the session lock; wait for another server to let go (up to ~20 s), then take it anyway
		local ok, decoded = false, nil
		for attempt = 1, 5 do
			local locked = false
			local loaded: any = nil
			ok = pcall(function()
				(store :: DataStore):UpdateAsync("u" .. player.UserId, function(old)
					local data = if typeof(old) == "string"
						then HttpService:JSONDecode(old)
						else nil
					if typeof(data) ~= "table" then
						data = {}
					end
					local lock = data.lock
					local fresh = typeof(lock) == "table"
						and lock.job ~= game.JobId
						and os.time() - (tonumber(lock.at) or 0) < LOCK_STALE
					if fresh and attempt < 5 then
						locked = true
						return nil -- leave it alone and try again shortly
					end
					data.lock = { job = game.JobId, at = os.time() }
					loaded = data
					return HttpService:JSONEncode(data)
				end)
			end)
			if not ok or not locked then
				decoded = loaded
				break
			end
			task.wait(5)
			if not player.Parent then
				return
			end
		end
		if not ok then
			loadFailed[player] = true
			warn("load failed, session-only data for", player.UserId)
		else
			if typeof(decoded) == "table" and decoded.money ~= nil then
				profile.money = tonumber(decoded.money) or profile.money
				profile.groupClaimed = decoded.groupClaimed == true
				profile.roadsterPassPaid = decoded.roadsterPassPaid == true
				profile.rookieDone = decoded.rookieDone == true
				-- saves from before the tutorial skip it, and so do saves past its old end
				profile.tutorial =
					OnboardingRules.migrate(tonumber(decoded.tutorial) or 99, Onboarding)
				if typeof(decoded.quests) == "table" then
					profile.quests = decoded.quests
				end
				if typeof(decoded.stats) == "table" then
					profile.stats = decoded.stats
				end
				if typeof(decoded.receipts) == "table" then
					profile.receipts = decoded.receipts
				end
				if typeof(decoded.bought) == "table" then
					profile.bought = decoded.bought
				end
				profile.paint, profile.paints = PaintRules.clean(decoded.paint, decoded.paints)
				local daily = decoded.daily
				if typeof(daily) == "table" and tonumber(daily.day) and tonumber(daily.streak) then
					profile.daily = {
						day = tonumber(daily.day) :: number,
						streak = tonumber(daily.streak) :: number,
					}
				end
				local sale = decoded.sale
				if typeof(sale) == "table" and tonumber(sale.day) then
					profile.sale = {
						day = tonumber(sale.day) :: number,
						id = if typeof(sale.id) == "string" then sale.id else nil,
					}
				end
				if typeof(decoded.owned) == "table" then
					for id, yes in decoded.owned do
						if yes == true and Vehicles.ById[id] then
							profile.owned[id] = true
						end
					end
				end
			end
		end
	else
		loadFailed[player] = true -- no DataStore access (unpublished place): session only
	end
	if player.Parent then
		profiles[player] = profile
		publish(player, profile)
		player:SetAttribute("DataReady", true)
	end
end

function Data.start()
	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player, true)
		profiles[player] = nil
		loadFailed[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Economy.AutosaveSeconds)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)
	game:BindToClose(function()
		-- PlayerRemoving may already have taken the profiles; wait for every save in flight
		for player in profiles do
			task.spawn(save, player, true)
		end
		local deadline = os.clock() + 25
		task.wait(0.1)
		while inFlight > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return Data
