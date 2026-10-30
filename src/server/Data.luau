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

function Data.addMoney(player: Player, amount: number)
	local p = profiles[player]
	if p and amount == amount then
		p.money = math.max(0, p.money + amount)
		publish(player, p)
	end
end

local function save(player: Player)
	local p = profiles[player]
	if not (store and p) or loadFailed[player] or saving[player] then
		return
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
