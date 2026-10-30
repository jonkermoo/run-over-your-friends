--!strict
-- Robux developer products: money packs and the one-time starter pack.
-- Each receipt is granted once (its PurchaseId is kept in the profile) and only confirmed to Roblox after
-- the profile is saved, so a failed save means Roblox retries instead of the buyer losing the purchase.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Analytics = require(script.Parent.Analytics)
local Data = require(script.Parent.Data)
local RateLimit = require(script.Parent.RateLimit)

local ProductService = {}

local byKey: { [string]: Products.Product } = {}
local byId: { [number]: Products.Product } = {}
for _, product in Products.MoneyPacks do
	byKey[product.key] = product
end
byKey[Products.Starter.key] = Products.Starter
for _, product in byKey do
	if product.id ~= 0 then
		byId[product.id] = product
	end
end

local function money(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return "$" .. out
end

-- add what the product gives; purchased money doesn't count toward "Earn" goals
local function grant(player: Player, product: Products.Product): boolean
	local profile = Data.get(player)
	if not profile then
		return false
	end
	if product.once and profile.bought[product.key] then
		return false
	end
	profile.money += product.money
	if product.vehicle and Vehicles.ById[product.vehicle] then
		profile.owned[product.vehicle] = true
	end
	if product.once then
		profile.bought[product.key] = true
	end
	Data.changed(player)
	Analytics.source(player, product.money, Enum.AnalyticsEconomyTransactionType.IAP, product.key)
	local extra = if product.vehicle then ` + the {Vehicles.ById[product.vehicle].name}` else ""
	Net.remote("Celebrate"):FireClient(
		player,
		string.upper(product.title) .. "!",
		`+{money(product.money)}{extra}. Thanks for the support!`
	)
	return true
end

function ProductService.start()
	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local profile = player and Data.get(player)
		local product = byId[info.ProductId]
		if not (player and profile and product) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local receipt = tostring(info.PurchaseId)
		if profile.receipts[receipt] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		grant(player, product)
		profile.receipts[receipt] = true
		if Data.saveNow(player) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Net.remote("BuyProduct").OnServerEvent:Connect(function(player, key)
		if not RateLimit.allow(player, "product", 1) then
			return
		end
		local product = if typeof(key) == "string" then byKey[key] else nil
		local profile = Data.get(player)
		if not (product and profile) or (product.once and profile.bought[product.key]) then
			return
		end
		if product.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, product.id)
		elseif RunService:IsStudio() then
			grant(player, product) -- test purchase until the product exists
		else
			Net.remote("Popup"):FireClient(player, "Coming soon", "info")
		end
	end)
end

return ProductService
