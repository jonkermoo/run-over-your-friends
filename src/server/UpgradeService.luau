--!strict
-- The garage's mastery upgrades and decals: buy an upgrade once (it goes on), switch bought ones on and off, and
-- pick a car's decal. Choices are saved per car; if that car is out, it is rebuilt where it stands so the new
-- parts and stats show at once (decals change in place).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Upgrades)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Rules = require(ReplicatedStorage.Shared.Rules.Upgrades)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Analytics = require(script.Parent.Analytics)
local Data = require(script.Parent.Data)
local RateLimit = require(script.Parent.RateLimit)
local VehicleBuilder = require(script.Parent.VehicleBuilder)
local VehicleService = require(script.Parent.VehicleService)

local UpgradeService = {}

local function popup(player: Player, text: string | Loc.Msg)
	Net.remote("Popup"):FireClient(player, text, "info")
end

-- the car that's out, when it is this vehicle
local function outNow(player: Player, vehicleId: string): Model?
	local model = VehicleService.of(player)
	return if model and model:GetAttribute("VehicleId") == vehicleId then model else nil
end

-- rebuild the car that's out with its new parts, in the same place, with the driver back in
local function refit(player: Player, vehicleId: string)
	local model = outNow(player, vehicleId)
	if not model then
		return
	end
	VehicleService.refit(player)
end

local function buyUpgrade(player: Player, vehicleId: any, n: any)
	local profile = Data.get(player)
	if not profile or not RateLimit.allow(player, "buyUpgrade", 0.5) then
		return
	end
	local id = if typeof(vehicleId) == "string" then vehicleId else ""
	local problem = Rules.buyProblem(
		profile.owned,
		profile.mastery[id] or 0,
		profile.upgrades[id],
		profile.money,
		vehicleId,
		n
	)
	if problem == "money" then
		popup(player, "Not enough money yet")
	elseif problem == "locked" then
		popup(player, Loc.msg("UpgradeLocked", { level = Config.UpgradeLevel[n] or 0 }))
	end
	if problem then
		return
	end
	local up = Rules.get(id, n) :: Config.Upgrade
	local price = Rules.price(id, Vehicles.ById[id].price, n)
	profile.money -= price
	local set = profile.upgrades[id] or {}
	set[tostring(n)] = true
	profile.upgrades[id] = set
	Data.changed(player)
	Analytics.spent(player, price, `Upgrade{id}{n}`)
	Net.remote("Popup")
		:FireClient(
			player,
			Loc.msg("UpgradeFitted", { name = Loc.src(string.upper(up.name)) }),
			"big"
		)
	refit(player, id)
end

local function setUpgrade(player: Player, vehicleId: any, n: any, on: any)
	local profile = Data.get(player)
	if
		not profile
		or typeof(vehicleId) ~= "string"
		or typeof(n) ~= "number"
		or typeof(on) ~= "boolean"
		or not RateLimit.allow(player, "setUpgrade", Config.SetEvery)
	then
		return
	end
	local set = profile.upgrades[vehicleId]
	local key = tostring(n)
	if not set or set[key] == nil or set[key] == on then
		return
	end
	set[key] = on
	Data.changed(player)
	refit(player, vehicleId)
end

local function setDecal(player: Player, vehicleId: any, decalId: any)
	local profile = Data.get(player)
	if not profile or not RateLimit.allow(player, "setDecal", Config.SetEvery) then
		return
	end
	local id = if typeof(vehicleId) == "string" then vehicleId else ""
	local problem = Rules.decalProblem(profile.owned, profile.mastery[id] or 0, vehicleId, decalId)
	if problem then
		return
	end
	profile.decal[id] = if decalId == "None" then nil else decalId
	Data.changed(player)
	local model = outNow(player, id)
	if model then
		VehicleBuilder.decal(model, profile.decal[id])
	end
end

-- Studio only: ServerStorage.MasteryTest (a BindableFunction) for play tests and hand tests:
-- ("points", player, vehicleId, n) adds mastery, ("money", player, n) adds cash, ("own", player, vehicleId) gives a car
local function studioHook()
	if not RunService:IsStudio() then
		return
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = "MasteryTest"
	hook.OnInvoke = function(what: string, player: Player, a: any, b: any)
		local profile = Data.get(player)
		if not profile then
			return false
		end
		if what == "points" and Vehicles.ById[a] then
			profile.mastery[a] = (profile.mastery[a] or 0) + (tonumber(b) or 0)
		elseif what == "money" then
			profile.money += tonumber(a) or 0
		elseif what == "own" and Vehicles.ById[a] then
			profile.owned[a] = true
		else
			return false
		end
		Data.changed(player)
		return true
	end
	hook.Parent = game:GetService("ServerStorage")
end

function UpgradeService.start()
	Net.remote("BuyUpgrade").OnServerEvent:Connect(buyUpgrade)
	Net.remote("SetUpgrade").OnServerEvent:Connect(setUpgrade)
	Net.remote("SetDecal").OnServerEvent:Connect(setDecal)
	studioHook()
end

return UpgradeService
