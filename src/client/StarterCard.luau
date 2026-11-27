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

local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Offer = require(ReplicatedStorage.Shared.Rules.Offer)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Pad = require(script.Parent.Pad)
local Popups = require(script.Parent.Popups)
local Style = require(script.Parent.Style)
local Track = require(script.Parent.Track)

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

local CARD_W, CARD_H = 580, 560
local TILE_W, TILE_H, PLUS_W = 156, 160, 36
local PIC_H = 104 -- the picture at the top of each tile

type Preview = (Instance, Vehicles.Vehicle, boolean?) -> Model?

-- one of the things inside: a picture on top, a yellow lane edge, its name and what it's worth
local function tile(
	parent: Instance,
	order: number,
	name: string,
	value: string,
	nameColor: Color3
): Frame
	local t = Style.card(parent)
	t.Size = UDim2.fromOffset(TILE_W, TILE_H)
	t.LayoutOrder = order
	local pic = Instance.new("Frame")
	pic.Name = "Picture"
	pic.BackgroundColor3 = Color3.fromRGB(46, 46, 54)
	pic.BorderSizePixel = 0
	pic.ClipsDescendants = true
	pic.Size = UDim2.new(1, 0, 0, PIC_H)
	pic.Parent = t
	local edge = Instance.new("Frame")
	edge.BackgroundColor3 = C.yellow
	edge.BorderSizePixel = 0
	edge.Position = UDim2.fromOffset(0, PIC_H)
	edge.Size = UDim2.new(1, 0, 0, 3)
	edge.Parent = t
	local n = Style.label(t, name, 17, F.display, nameColor)
	n.Position = UDim2.fromOffset(6, PIC_H + 10)
	n.Size = UDim2.new(1, -12, 0, 20)
	local v = Style.label(t, value, 14, F.heavy, if nameColor == C.money then C.dim else C.money)
	v.Position = UDim2.fromOffset(6, PIC_H + 32)
	v.Size = UDim2.new(1, -12, 0, 18)
	return t
end

local function plus(parent: Instance, order: number)
	local p = Style.label(parent, "+", 34, F.display, C.yellow)
	p.Size = UDim2.fromOffset(PLUS_W, TILE_H)
	p.LayoutOrder = order
	Style.outline(p, 2)
end

local function build(gui: ScreenGui, preview: Preview)
	card = Style.panel(gui)
	card.Name = "StarterCard"
	Style.slot(card)
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.ZIndex = 10
	card.Visible = false
	Style.hazard(card, CARD_W, 14)

	local title = Style.label(card, "STARTER PACK", 52, F.display, C.yellow)
	title.Position = UDim2.fromOffset(0, 28)
	title.Size = UDim2.new(1, -70, 0, 54) -- a little left of centre: the deal sticker takes the corner
	Style.outline(title, 3)
	-- the deal's sticker, slapped on the top-right corner while it runs
	offPill = Style.label(card, "", 24, F.display, C.text)
	offPill.Name = "DealSticker"
	offPill.BackgroundColor3 = C.red
	offPill.BackgroundTransparency = 0
	offPill.AnchorPoint = Vector2.new(1, 0)
	offPill.Position = UDim2.new(1, -8, 0, 22)
	offPill.Size = UDim2.fromOffset(100, 40)
	offPill.ZIndex = 3
	Style.stroke(offPill, C.ink, 3, 0)
	local once = Style.pill(card, "ONE TIME ONLY  ·  ONCE PER ACCOUNT", C.pink)
	once.TextColor3 = C.text
	once.TextSize = 15
	once.Size = UDim2.fromOffset(0, 24)
	once.AnchorPoint = Vector2.new(0.5, 0)
	once.Position = UDim2.new(0.5, 0, 0, 92)

	-- what's inside: a picture of each car, then the cash, with a + between them
	local row = Instance.new("Frame")
	row.Name = "Contents"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 130)
	row.Size = UDim2.new(1, 0, 0, TILE_H)
	row.Parent = card
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	local order = 0
	for _, id in FULL.vehicles or {} do
		local stats = Vehicles.ById[id]
		if stats then
			order += 1
			local t = tile(row, order, string.upper(stats.name), Style.money(stats.price), C.text)
			preview(t:FindFirstChild("Picture") :: Frame, stats, true)
			order += 1
			plus(row, order)
		end
	end
	local cash = tile(row, order + 1, Style.money(FULL.money), "CASH", C.money)
	local pic = cash:FindFirstChild("Picture") :: Frame
	local bill = Style.image(pic, Icons.Bill)
	bill.AnchorPoint = Vector2.new(0.5, 0.5)
	bill.Position = UDim2.fromScale(0.4, 0.45)
	bill.Size = UDim2.fromOffset(70, 70)
	local coin = Style.image(pic, Icons.Coin)
	coin.AnchorPoint = Vector2.new(0.5, 0.5)
	coin.Position = UDim2.fromScale(0.66, 0.6)
	coin.Size = UDim2.fromOffset(46, 46)

	-- the value bar: honest numbers from Rules/Offer
	local value = Instance.new("Frame")
	value.BackgroundColor3 = C.money
	value.BorderSizePixel = 0
	value.Position = UDim2.fromOffset(24, 304)
	value.Size = UDim2.new(1, -48, 0, 40)
	value.Parent = card
	valueText = Style.label(value, "", 24, F.display, C.ink)
	valueText.Size = UDim2.fromScale(1, 1)

	-- the price: the full one struck through and the deal while it runs, and its countdown on the right
	local priceRow = Instance.new("Frame")
	priceRow.BackgroundTransparency = 1
	priceRow.Position = UDim2.fromOffset(24, 354)
	priceRow.Size = UDim2.new(1, -48, 0, 46)
	priceRow.Parent = card
	local left = Instance.new("Frame")
	left.BackgroundTransparency = 1
	left.Size = UDim2.fromScale(0.6, 1)
	left.Parent = priceRow
	local priceList = Instance.new("UIListLayout")
	priceList.FillDirection = Enum.FillDirection.Horizontal
	priceList.VerticalAlignment = Enum.VerticalAlignment.Center
	priceList.SortOrder = Enum.SortOrder.LayoutOrder
	priceList.Padding = UDim.new(0, 12)
	priceList.Parent = left
	priceWas = Style.label(left, "", 24, F.display, C.dim)
	priceWas.AutomaticSize = Enum.AutomaticSize.X
	priceWas.Size = UDim2.fromOffset(0, 46)
	priceWas.LayoutOrder = 1
	strike = Instance.new("Frame")
	strike.BackgroundColor3 = C.red
	strike.BorderSizePixel = 0
	strike.AnchorPoint = Vector2.new(0.5, 0.5)
	strike.Position = UDim2.fromScale(0.5, 0.45)
	strike.Size = UDim2.new(1, 4, 0, 4)
	strike.Parent = priceWas
	priceNow = Style.label(left, "", 36, F.display, C.yellow)
	priceNow.AutomaticSize = Enum.AutomaticSize.X
	priceNow.Size = UDim2.fromOffset(0, 46)
	priceNow.LayoutOrder = 2
	Style.outline(priceNow, 2)
	timer = Style.label(priceRow, "", 19, F.display, C.text)
	timer.BackgroundColor3 = C.red
	timer.BackgroundTransparency = 0
	timer.AnchorPoint = Vector2.new(1, 0.5)
	timer.Position = UDim2.fromScale(1, 0.5)
	timer.AutomaticSize = Enum.AutomaticSize.X
	timer.Size = UDim2.fromOffset(0, 32)
	local timerPad = Instance.new("UIPadding")
	timerPad.PaddingLeft = UDim.new(0, 10)
	timerPad.PaddingRight = UDim.new(0, 10)
	timerPad.PaddingTop = UDim.new(0, 4)
	timerPad.Parent = timer

	buy = Style.button(card, "", "gold", 30)
	buy.Name = "StarterBuy"
	buy.AnchorPoint = Vector2.new(0.5, 1)
	buy.Position = UDim2.new(0.5, 0, 1, -58)
	buy.Size = UDim2.fromOffset(340, 62)
	-- X: away for now; the unasked-for card (client/Popups "Starter") comes back later
	Style.closeX(card, function()
		StarterCard.hide()
		Popups.snooze("Starter")
	end)
	local no = Style.button(card, "NO THANKS", "dark", 16)
	no.Name = "StarterNo"
	no.AnchorPoint = Vector2.new(0.5, 1)
	no.Position = UDim2.new(0.5, 0, 1, -14)
	no.Size = UDim2.fromOffset(180, 36)

	buy.Activated:Connect(function()
		local product = StarterCard.current()
		Track.offer("Starter", "Pressed")
		StarterCard.hide()
		Net.waitFor("BuyProduct"):FireServer(product.key)
	end)
	no.Activated:Connect(StarterCard.hide)
	-- gamepad: it starts on VIEW OFFER, and B is NO THANKS
	Pad.menu(card, {
		first = function()
			return buy
		end,
		close = StarterCard.hide,
	})
end

-- lay the price row out for what's on sale now
local function refresh()
	local product = StarterCard.current()
	local deal = product == DEAL
	local times = Offer.valueTimes(WORTH, robuxShown[product.key], Products.MoneyPacks)
	Loc.set(valueText, "StarterWorth", { money = Style.money(WORTH), times = times })
	priceNow.Text = "R$ " .. robuxShown[product.key]
	priceWas.Visible = deal
	offPill.Visible = deal
	timer.Visible = deal
	if deal then
		priceWas.Text = "R$ " .. robuxShown[FULL.key]
		offPill.Text = `-{Offer.percentOff(robuxShown[FULL.key], robuxShown[DEAL.key])}%`
		Loc.set(timer, "EventEnds", { time = Offer.clock(dealEnds() - now()) })
	end
	buy.AutoLocalize = false
	buy.Text = Loc.source("VIEW OFFER") .. "  ·  " .. rs(product)
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
	Track.offer("Starter", "Shown")
end

-- the store's banner: its line, the deal's % off, struck-through full price and countdown, and the price
-- button follow the deal, and it hides once bought
export type StoreParts = {
	row: GuiObject,
	text: TextLabel,
	button: TextButton,
	off: TextLabel,
	was: TextLabel,
	timer: TextLabel,
}
local storeRow: StoreParts? = nil
function StarterCard.bindStore(parts: StoreParts)
	storeRow = parts
end

local function refreshStore()
	local s = storeRow
	if not s then
		return
	end
	s.row.Visible = not StarterCard.bought()
	local product = StarterCard.current()
	local deal = product == DEAL
	Loc.set(s.text, "StarterWorthLine", { money = Style.money(WORTH) })
	s.off.Visible = deal
	s.was.Visible = deal
	s.timer.Visible = deal
	if deal then
		Loc.set(
			s.off,
			"OffToday",
			{ pct = Offer.percentOff(robuxShown[FULL.key], robuxShown[DEAL.key]) }
		)
		s.was.Text = "R$ " .. robuxShown[FULL.key]
		Loc.set(s.timer, "EventEnds", { time = Offer.clock(dealEnds() - now()) })
	end
	s.button.Text = rs(product)
end

function StarterCard.start(gui: ScreenGui, preview: Preview)
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
