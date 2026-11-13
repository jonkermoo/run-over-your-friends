--!strict
-- Robux developer products: money packs and the one-time Starter Pack, sold at its full price in the store or
-- as StarterDeal while the player's discount window runs (Config/Products, Rules/Offer).
-- Each receipt is granted once (its PurchaseId is kept in the profile) and only confirmed to Roblox after
-- the profile is saved, so a failed save means Roblox retries instead of the buyer losing the purchase.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Offer = require(ReplicatedStorage.Shared.Rules.Offer)
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
byKey[Products.StarterDeal.key] = Products.StarterDeal
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
	local onceKey = Offer.onceKey(product)
	if product.once and profile.bought[onceKey] then
		return false
	end
	profile.money += product.money
	local names = {}
	for _, id in product.vehicles or {} do
		if Vehicles.ById[id] then
			profile.owned[id] = true
			table.insert(names, Vehicles.ById[id].name)
		end
	end
	if product.once then
		profile.bought[onceKey] = true
	end
	Data.changed(player)
	Analytics.source(player, product.money, Enum.AnalyticsEconomyTransactionType.IAP, product.key)
	local extra = if #names > 0 then ` + the {table.concat(names, " + the ")}` else ""
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
		-- the deal only while its window runs; a receipt that arrives later (prompt opened in time) still grants
		if
			not (product and profile)
			or not Offer.mayBuy(product, profile.bought, profile.starterDealEnds, os.time())
		then
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

	-- the Starter Pack card showed: start the discount window, once ever, for a player it's meant for
	Net.remote("StarterDealSeen").OnServerEvent:Connect(function(player)
		local profile = Data.get(player)
		if not profile or not RateLimit.allow(player, "starterDeal", 1) then
			return
		end
		if profile.starterDealEnds ~= 0 or profile.bought[Products.Starter.key] then
			return
		end
		local owned, prices = {}, {}
		for id in profile.owned do
			table.insert(owned, id)
		end
		for _, v in Vehicles.List do
			prices[v.id] = v.price
		end
		if not Offer.eligible(owned, prices, Vehicles.ById[Products.StarterUntil].price) then
			return
		end
		profile.starterDealEnds = os.time() + Products.StarterDealSeconds
		Data.changed(player)
	end)
end

return ProductService
