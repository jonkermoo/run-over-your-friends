--!strict
-- Car paint: buy a colour once, then set it on any owned vehicle. The choice is saved per vehicle, and the
-- server colours the vehicle's Paint part (at spawn, or at once if it's out), so every player sees it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Paints)
local Net = require(ReplicatedStorage.Shared.Net)
local PaintRules = require(ReplicatedStorage.Shared.Rules.Paints)
local Analytics = require(script.Parent.Analytics)
local Data = require(script.Parent.Data)
local RateLimit = require(script.Parent.RateLimit)
local VehicleBuilder = require(script.Parent.VehicleBuilder)
local VehicleService = require(script.Parent.VehicleService)

local PaintService = {}

local function isVip(player: Player): boolean
	return player:GetAttribute("PassVIP") == true
end

-- the car out now, in its saved colour (VIP colours only with the pass)
local function repaint(player: Player)
	local profile = Data.get(player)
	local model = VehicleService.of(player)
	local vehicleId = model and model:GetAttribute("VehicleId")
	if not profile or not model or typeof(vehicleId) ~= "string" then
		return
	end
	local paint = PaintRules.shown(profile.paint[vehicleId], isVip(player))
	VehicleBuilder.paint(model, PaintRules.colour(vehicleId, paint), PaintRules.material(paint))
end

local function popup(player: Player, text: string)
	Net.remote("Popup"):FireClient(player, text, "info")
end

local function setPaint(player: Player, vehicleId: any, paintId: any)
	local profile = Data.get(player)
	if not profile or not RateLimit.allow(player, "paint", Config.SetEvery) then
		return
	end
	local bought = PaintRules.withVip(profile.paints, isVip(player))
	local problem = PaintRules.setProblem(profile.owned, bought, vehicleId, paintId)
	if problem == "locked" then
		local p = Config.ById[paintId]
		popup(
			player,
			if p and p.vip then "VIP only: get VIP in the store" else "Buy that colour first"
		)
	end
	if problem then
		return
	end
	profile.paint[vehicleId] = if paintId == Config.FactoryId then nil else paintId
	Data.changed(player)
	local model = VehicleService.of(player)
	if model and model:GetAttribute("VehicleId") == vehicleId then
		VehicleBuilder.paint(
			model,
			PaintRules.colour(vehicleId, paintId),
			PaintRules.material(paintId)
		)
	end
end

local function buyPaint(player: Player, paintId: any)
	local profile = Data.get(player)
	if not profile or not RateLimit.allow(player, "buyPaint", 0.5) then
		return
	end
	local problem = PaintRules.buyProblem(profile.money, profile.paints, paintId)
	if problem == "money" then
		popup(player, "Not enough money yet")
	elseif problem == "vip" then
		popup(player, "VIP only: get VIP in the store")
	end
	if problem then
		return
	end
	local paint = Config.ById[paintId]
	profile.money -= paint.price
	profile.paints[paint.id] = true
	Data.changed(player)
	Analytics.spent(player, paint.price, "Paint" .. paint.id)
	Net.remote("Popup"):FireClient(player, paint.name .. " paint unlocked for every car", "big")
end

function PaintService.start()
	Net.remote("SetPaint").OnServerEvent:Connect(setPaint)
	Net.remote("BuyPaint").OnServerEvent:Connect(buyPaint)
	-- VIP bought (or found on join) with a VIP colour saved on the car that's out: show it now
	local function watch(player: Player)
		player:GetAttributeChangedSignal("PassVIP"):Connect(function()
			repaint(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
end

return PaintService
