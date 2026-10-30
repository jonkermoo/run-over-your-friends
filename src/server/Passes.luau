--!strict
-- Game passes. Ownership shows as player attributes Pass<Name> (true/false).
-- Pass ids live in Config/Economy; while an id is 0 (not created yet) the shop toggles it in Studio only.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Data = require(script.Parent.Data)

local Passes = {}

function Passes.has(player: Player, name: string): boolean
	return player:GetAttribute("Pass" .. name) == true
end

-- the Roadster pass gives the car and a one-time $1M
local function grant(player: Player, name: string)
	player:SetAttribute("Pass" .. name, true)
	if name == "Roadster" then
		local profile = Data.get(player)
		if profile then
			profile.owned.Roadster = true
			if not profile.roadsterPassPaid then
				profile.roadsterPassPaid = true
				profile.money += Economy.RoadsterPassMoney
				Net.remote("Popup"):FireClient(player, "+$1,000,000  Roadster unlocked!", "big")
			end
			Data.changed(player)
		end
	end
end

local function check(player: Player)
	while player.Parent and not player:GetAttribute("DataReady") do
		task.wait(0.2)
	end
	for name, id in Economy.Passes do
		local owns = false
		if id ~= 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			owns = ok and result == true
		end
		if owns then
			grant(player, name)
		else
			player:SetAttribute("Pass" .. name, false)
		end
	end
end

function Passes.start()
	Players.PlayerAdded:Connect(check)
	for _, p in Players:GetPlayers() do
		task.spawn(check, p)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		if not bought then
			return
		end
		for name, id in Economy.Passes do
			if id == passId then
				grant(player, name)
			end
		end
	end)
	Net.remote("BuyPass").OnServerEvent:Connect(function(player, name)
		if typeof(name) ~= "string" or Economy.Passes[name] == nil then
			return
		end
		local id = Economy.Passes[name]
		if id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, id)
		elseif RunService:IsStudio() then
			-- test toggle until the pass exists
			if Passes.has(player, name) then
				player:SetAttribute("Pass" .. name, false)
			else
				grant(player, name)
			end
		else
			Net.remote("Popup"):FireClient(player, "Coming soon", "info")
		end
	end)
end

return Passes
