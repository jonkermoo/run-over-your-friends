--!strict
-- Car paint: buy a colour once, then set it on any owned vehicle. The choice is saved per vehicle, and the
-- server colours the vehicle's Paint part (at spawn, or at once if it's out), so every player sees it.

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

local function popup(player: Player, text: string)
	Net.remote("Popup"):FireClient(player, text, "info")
end

local function setPaint(player: Player, vehicleId: any, paintId: any)
	local profile = Data.get(player)
	if not profile or not RateLimit.allow(player, "paint", Config.SetEvery) then
		return
	end
	local problem = PaintRules.setProblem(profile.owned, profile.paints, vehicleId, paintId)
	if problem == "locked" then
		popup(player, "Buy that colour first")
	end
	if problem then
		return
	end
	profile.paint[vehicleId] = if paintId == Config.FactoryId then nil else paintId
	Data.changed(player)
	local model = VehicleService.of(player)
	if model and model:GetAttribute("VehicleId") == vehicleId then
		VehicleBuilder.paint(model, PaintRules.colour(vehicleId, paintId))
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
end

return PaintService
