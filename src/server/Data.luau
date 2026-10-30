--!strict
-- Player profiles: money, owned vehicles, one-time rewards. Saved with DataStores; if a load fails,
-- that player plays on session-only data and nothing is written for them.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)

export type Profile = {
	money: number, -- fractional; rounded only for display
	owned: { [string]: boolean },
	likeClaimed: boolean,
	roadsterPassPaid: boolean,
	tutorial: number, -- Config/Onboarding Steps
	quests: { [string]: any }, -- Hourly/Daily goal sets, checked by QuestService
	stats: { [string]: any }, -- leaderboard numbers, checked by LeaderboardService
	receipts: { [string]: boolean }, -- Robux purchase ids already granted
	bought: { [string]: boolean }, -- one-time products already bought
}

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
		likeClaimed = false,
		roadsterPassPaid = false,
		tutorial = 1,
		quests = {},
		stats = {},
		receipts = {},
		bought = {},
	}
end

local function publish(player: Player, profile: Profile)
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
	player:SetAttribute("LikeClaimed", profile.likeClaimed)
	player:SetAttribute("Tutorial", profile.tutorial)
	local bought = {}
	for key, yes in profile.bought do
		if yes then
			table.insert(bought, key)
		end
	end
	player:SetAttribute("Bought", table.concat(bought, ","))
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

local function save(player: Player): boolean
	local p = profiles[player]
	if not (store and p) or loadFailed[player] or saving[player] then
		return false
	end
	saving[player] = true
	inFlight += 1
	local blob = HttpService:JSONEncode(p)
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
		local ok, result = pcall(function()
			return (store :: DataStore):GetAsync("u" .. player.UserId)
		end)
		if not ok then
			loadFailed[player] = true
			warn("load failed, session-only data for", player.UserId, result)
		elseif typeof(result) == "string" then
			local decoded = HttpService:JSONDecode(result)
			if typeof(decoded) == "table" then
				profile.money = tonumber(decoded.money) or profile.money
				profile.likeClaimed = decoded.likeClaimed == true
				profile.roadsterPassPaid = decoded.roadsterPassPaid == true
				profile.tutorial = tonumber(decoded.tutorial) or 99 -- saves from before the tutorial skip it
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
		save(player)
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
			task.spawn(save, player)
		end
		local deadline = os.clock() + 25
		task.wait(0.1)
		while inFlight > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return Data
