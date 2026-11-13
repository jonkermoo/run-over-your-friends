--!strict
-- The Starter Pack card (Config/Products, Rules/Offer): what's inside (the cars as pictures, the cash), what it's
-- worth and how that compares with the money packs, and the price. The first time it shows, the server starts
-- the player's discount window; while that runs the card sells the StarterDeal at the struck-through full
-- price's discount with a live countdown, and afterwards the full price. client/Hud decides when it shows (the
-- timed pop-up and the garage when a car is out of reach) and keeps the store row in step through here.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Offer = require(ReplicatedStorage.Shared.Rules.Offer)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Style = require(script.Parent.Style)

local StarterCard = {}

local C, F = Style.colors, Style.fonts
local player = Players.LocalPlayer
local FULL, DEAL = Products.Starter, Products.StarterDeal

local prices: { [string]: number } = {}
for _, v in Vehicles.List do
	prices[v.id] = v.price
end
local WORTH = Offer.worth(FULL, prices)
local UNTIL_PRICE = prices[Products.StarterUntil] or math.huge

-- the Robux price shown: the configured one until the product exists, then Roblox's own
local robuxShown: { [string]: number } = { [FULL.key] = FULL.robux, [DEAL.key] = DEAL.robux }
for _, product in { FULL, DEAL } do
	if product.id ~= 0 then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(product.id, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				robuxShown[product.key] = info.PriceInRobux
			end
		end)
	end
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function dealEnds(): number
	return (player:GetAttribute("StarterDealEnds") or 0) :: number
end

function StarterCard.bought(): boolean
	return string.find(
		"," .. ((player:GetAttribute("Bought") or "") :: string) .. ",",
		"," .. FULL.key .. ",",
		1,
		true
	) ~= nil
end

-- not bought and still near the start (owns nothing as dear as Products.StarterUntil)
function StarterCard.eligible(): boolean
	if StarterCard.bought() then
		return false
	end
	local owned = string.split((player:GetAttribute("Owned") or "") :: string, ",")
	return Offer.eligible(owned, prices, UNTIL_PRICE)
end

function StarterCard.dealState(): string
	return Offer.dealState(dealEnds(), now())
end

-- the product on sale right now: the deal while its window runs, else the full price
function StarterCard.current(): Products.Product
	return if StarterCard.dealState() == "open" then DEAL else FULL
end

local function rs(product: Products.Product): string
	local text = "R$ " .. robuxShown[product.key]
	if product.id == 0 and RunService:IsStudio() then
		text ..= " (test)"
	end
	return text
end

---------------------------------------------------------------- the card

local card: Frame
local priceNow: TextLabel
local priceWas: TextLabel
local strike: Frame
local offPill: TextLabel
local timer: TextLabel
local valueText: TextLabel
local buy: TextButton
local onClose: (() -> ())? = nil

local CARD_W, CARD_H = 520, 476
local TILE_W, TILE_H, TILE_GAP = 150, 176, 12

local function tile(parent: Instance, x: number): Frame
	local t = Style.card(parent)
	t.Position = UDim2.fromOffset(x, 0)
	t.Size = UDim2.fromOffset(TILE_W, TILE_H)
	return t
end

local function tileText(t: Frame, name: string, value: string)
	local n = Style.label(t, name, 15, F.heavy, C.text)
	n.Position = UDim2.fromOffset(6, 134)
	n.Size = UDim2.new(1, -12, 0, 18)
	local v = Style.label(t, value, 14, F.heavy, C.money)
	v.Position = UDim2.fromOffset(6, 153)
	v.Size = UDim2.new(1, -12, 0, 16)
end

local function build(gui: ScreenGui, preview: (Instance, Vehicles.Vehicle) -> Model?)
	card = Style.panel(gui)
	card.Name = "StarterCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.ZIndex = 10
	card.Visible = false
	Style.stroke(card, C.yellow, 4, 0)
	Style.setShadow(card, C.pink)

	local hazard = Instance.new("Frame")
	hazard.BackgroundColor3 = C.yellow
	hazard.BorderSizePixel = 0
	hazard.Size = UDim2.new(1, 0, 0, 14)
	hazard.ClipsDescendants = true
	hazard.Parent = card
	for x = -20, CARD_W + 20, 28 do
		local stripe = Instance.new("Frame")
		stripe.BackgroundColor3 = C.ink
		stripe.BorderSizePixel = 0
		stripe.Position = UDim2.fromOffset(x, -10)
		stripe.Size = UDim2.fromOffset(12, 40)
		stripe.Rotation = 40
		stripe.Parent = hazard
	end

	local title = Style.label(card, "STARTER PACK", 36, F.display, C.yellow)
	title.Position = UDim2.fromOffset(0, 24)
	title.Size = UDim2.new(1, 0, 0, 40)
	Style.outline(title, 2)
	local once = Style.pill(card, "ONE TIME ONLY · ONCE PER ACCOUNT", C.pink)
	once.AnchorPoint = Vector2.new(0.5, 0)
	once.Position = UDim2.new(0.5, 0, 0, 66)

	-- what's inside: a picture of each car, then the cash
	local row = Instance.new("Frame")
	row.Name = "Contents"
	row.BackgroundTransparency = 1
	local count = #(FULL.vehicles or {}) + 1
	local rowW = count * TILE_W + (count - 1) * TILE_GAP
	row.Position = UDim2.fromOffset((CARD_W - rowW) // 2, 96)
	row.Size = UDim2.fromOffset(rowW, TILE_H)
	row.Parent = card
	local x = 0
	for _, id in FULL.vehicles or {} do
		local stats = Vehicles.ById[id]
		if stats then
			local t = tile(row, x)
			preview(t, stats)
			tileText(t, string.upper(stats.name), Style.money(stats.price))
			x += TILE_W + TILE_GAP
		end
	end
	local cash = tile(row, x)
	local bills = Instance.new("Frame")
	bills.BackgroundColor3 = Color3.fromRGB(46, 46, 54)
	bills.BorderSizePixel = 0
	bills.Position = UDim2.fromOffset(6, 6)
	bills.Size = UDim2.new(1, -12, 0, 122)
	bills.Parent = cash
	local big = Style.label(bills, Style.money(FULL.money), 30, F.display, C.money)
	big.Size = UDim2.fromScale(1, 1)
	Style.outline(big, 2)
	local line = Style.dashes(cash, C.yellow, false, 3)
	line.Position = UDim2.fromOffset(6, 128)
	line.Size = UDim2.new(1, -12, 0, 3)
	tileText(cash, "CASH", "spend it on anything")

	-- the value line: honest numbers from Rules/Offer
	local value = Instance.new("Frame")
	value.BackgroundColor3 = C.money
	value.BorderSizePixel = 0
	value.Position = UDim2.fromOffset(23, 284)
	value.Size = UDim2.new(1, -46, 0, 34)
	value.Parent = card
	valueText = Style.label(value, "", 22, F.display, C.ink)
	valueText.Size = UDim2.fromScale(1, 1)

	-- the price: the full one struck through and the deal while it runs, with its countdown
	local priceRow = Instance.new("Frame")
	priceRow.BackgroundTransparency = 1
	priceRow.Position = UDim2.fromOffset(23, 326)
	priceRow.Size = UDim2.new(1, -46, 0, 40)
	priceRow.Parent = card
	-- the struck price, the price and the % off sit in a row that sizes itself (TextBounds are screen pixels)
	local left = Instance.new("Frame")
	left.BackgroundTransparency = 1
	left.Size = UDim2.fromScale(0.62, 1)
	left.Parent = priceRow
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 10)
	list.Parent = left
	priceWas = Style.label(left, "", 22, F.display, C.dim)
	priceWas.AutomaticSize = Enum.AutomaticSize.X
	priceWas.Size = UDim2.fromOffset(0, 40)
	priceWas.LayoutOrder = 1
	strike = Instance.new("Frame")
	strike.BackgroundColor3 = C.red
	strike.BorderSizePixel = 0
	strike.AnchorPoint = Vector2.new(0.5, 0.5)
	strike.Position = UDim2.fromScale(0.5, 0.5)
	strike.Size = UDim2.new(1, 0, 0, 3)
	strike.Rotation = -8
	strike.Parent = priceWas
	priceNow = Style.label(left, "", 30, F.display, C.yellow)
	priceNow.AutomaticSize = Enum.AutomaticSize.X
	priceNow.Size = UDim2.fromOffset(0, 40)
	priceNow.LayoutOrder = 2
	Style.outline(priceNow, 2)
	offPill = Style.pill(left, "", C.red)
	offPill.TextColor3 = C.text
	offPill.LayoutOrder = 3
	timer = Style.label(priceRow, "", 16, F.heavy, C.text)
	timer.AnchorPoint = Vector2.new(1, 0)
	timer.Position = UDim2.fromScale(1, 0)
	timer.Size = UDim2.fromOffset(170, 40)
	timer.TextXAlignment = Enum.TextXAlignment.Right

	buy = Style.button(card, "", "gold", 24)
	buy.Name = "StarterBuy"
	buy.AnchorPoint = Vector2.new(0.5, 0)
	buy.Position = UDim2.new(0.5, 0, 0, 374)
	buy.Size = UDim2.fromOffset(320, 54)
	local no = Style.button(card, "NO THANKS", "dark", 15)
	no.Name = "StarterNo"
	no.AnchorPoint = Vector2.new(0.5, 0)
	no.Position = UDim2.new(0.5, 0, 0, 434)
	no.Size = UDim2.fromOffset(180, 32)

	buy.Activated:Connect(function()
		local product = StarterCard.current()
		StarterCard.hide()
		Net.waitFor("BuyProduct"):FireServer(product.key)
	end)
	no.Activated:Connect(StarterCard.hide)
end

-- lay the price row out for what's on sale now
local function refresh()
	local product = StarterCard.current()
	local deal = product == DEAL
	local times = Offer.valueTimes(WORTH, robuxShown[product.key], Products.MoneyPacks)
	valueText.Text = `WORTH {Style.money(WORTH)}  ·  {times}x VALUE`
	priceNow.Text = "R$ " .. robuxShown[product.key]
	priceWas.Visible = deal
	offPill.Visible = deal
	timer.Visible = deal
	if deal then
		priceWas.Text = "R$ " .. robuxShown[FULL.key]
		offPill.Text = `{Offer.percentOff(robuxShown[FULL.key], robuxShown[DEAL.key])}% OFF`
		timer.Text = "DEAL ENDS IN " .. Offer.clock(dealEnds() - now())
	end
	buy.Text = "GET IT  ·  " .. rs(product)
end

function StarterCard.isOpen(): boolean
	return card ~= nil and card.Visible
end

function StarterCard.hide()
	if card and card.Visible then
		card.Visible = false
		if onClose then
			onClose()
		end
	end
end

-- show the card (nothing if bought); the first showing starts the discount window on the server
function StarterCard.show(closed: (() -> ())?)
	if not card or StarterCard.bought() then
		return
	end
	onClose = closed
	if StarterCard.dealState() == "fresh" then
		Net.waitFor("StarterDealSeen"):FireServer()
	end
	refresh()
	local scale = card:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = card
	scale.Scale = 0.8
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	card.Visible = true
end

-- the store row: its description and button follow the deal (price, countdown) and it hides once bought
local storeRow: { text: TextLabel, button: TextButton, row: GuiObject, header: GuiObject? }? = nil
function StarterCard.bindStore(
	row: GuiObject,
	text: TextLabel,
	button: TextButton,
	header: GuiObject?
)
	storeRow = { text = text, button = button, row = row, header = header }
end

local function refreshStore()
	local s = storeRow
	if not s then
		return
	end
	local bought = StarterCard.bought()
	s.row.Visible = not bought
	if s.header then
		s.header.Visible = not bought
	end
	local product = StarterCard.current()
	local cars = {}
	for _, id in FULL.vehicles or {} do
		table.insert(cars, Vehicles.ById[id].name)
	end
	local what =
		`The {table.concat(cars, " + the ")} + {Style.money(FULL.money)}. Worth {Style.money(WORTH)}, once per account.`
	if product == DEAL then
		s.text.Text =
			`{what} {Offer.percentOff(robuxShown[FULL.key], robuxShown[DEAL.key])}% off for {Offer.clock(
				dealEnds() - now()
			)} more.`
	else
		s.text.Text = what
	end
	s.button.Text = rs(product)
end

function StarterCard.start(gui: ScreenGui, preview: (Instance, Vehicles.Vehicle) -> Model?)
	build(gui, preview)
	for _, name in { "Bought", "StarterDealEnds", "Owned" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if StarterCard.bought() then
				StarterCard.hide()
			end
			refreshStore()
			if card.Visible then
				refresh()
			end
		end)
	end
	refreshStore()
	-- the countdowns tick; when the deal runs out the card and the row fall back to the full price
	task.spawn(function()
		while true do
			task.wait(1)
			if card.Visible then
				refresh()
			end
			refreshStore()
		end
	end)
end

return StarterCard
