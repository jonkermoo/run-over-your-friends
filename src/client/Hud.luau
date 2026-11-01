--!strict
-- Screen UI: money and pop-ups, the speedometer with jet and thruster meters, the garage (3D previews,
-- stats, buy and spawn), the store (passes, like reward, credits) and the phone driving buttons.
-- Every visual comes from Style.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Drive = require(script.Parent.Drive)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local Hud = {}
local C, F = Style.colors, Style.fonts
local money = Style.money

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

---------------------------------------------------------------- money and pop-ups

local moneyBox = Style.panel(gui, 24)
moneyBox.AnchorPoint = Vector2.new(0.5, 0)
moneyBox.Position = UDim2.new(0.5, 0, 0, 8)
moneyBox.Size = UDim2.fromOffset(240, 48)
local moneyScale = Instance.new("UIScale")
moneyScale.Parent = moneyBox
local coin = Style.label(moneyBox, "$", 22, F.display, C.ink)
coin.BackgroundColor3 = Color3.new(1, 1, 1)
coin.BackgroundTransparency = 0
coin.AnchorPoint = Vector2.new(0, 0.5)
coin.Position = UDim2.new(0, 8, 0.5, 0)
coin.Size = UDim2.fromOffset(34, 34)
Style.corner(coin, 17)
Style.gradient(coin, Color3.fromRGB(255, 230, 120), Color3.fromRGB(240, 160, 30))
Style.stroke(coin, Color3.fromRGB(150, 90, 10), 2, 0)
local moneyLabel = Style.label(moneyBox, "0", 30, F.display, C.money)
moneyLabel.Position = UDim2.fromOffset(48, 0)
moneyLabel.Size = UDim2.new(1, -60, 1, 0)
moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
Style.outline(moneyLabel)

local popups = Instance.new("Frame")
popups.BackgroundTransparency = 1
popups.AnchorPoint = Vector2.new(0.5, 0)
popups.Position = UDim2.new(0.5, 0, 0, 140)
popups.Size = UDim2.fromOffset(520, 220)
popups.Parent = gui

local function rise(obj: GuiObject, seconds: number, distance: number)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = obj
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local start = obj.Position
	task.delay(0.3, function()
		local fade = TweenService:Create(
			obj,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = start + UDim2.fromOffset(0, distance),
			}
		)
		fade:Play()
		for _, d in obj:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(seconds), { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(seconds), { Transparency = 1 }):Play()
			end
		end
		if obj:IsA("TextLabel") then
			TweenService:Create(obj, TweenInfo.new(seconds), { TextTransparency = 1 }):Play()
		end
		if obj:IsA("Frame") then
			TweenService:Create(obj, TweenInfo.new(seconds), { BackgroundTransparency = 1 }):Play()
		end
		fade.Completed:Once(function()
			obj:Destroy()
		end)
	end)
end

local function popup(text: string, kind: string)
	if kind == "goal" then
		-- a gold toast: pill + the goal text
		local toast = Style.panel(popups, 14)
		toast.AnchorPoint = Vector2.new(0.5, 0)
		toast.Position = UDim2.new(0.5, 0, 0, 40)
		toast.Size = UDim2.fromOffset(480, 46)
		Style.stroke(toast, C.gold, 2, 0.1)
		local pill = Style.pill(toast, "GOAL COMPLETE", C.gold)
		pill.AnchorPoint = Vector2.new(0, 0.5)
		pill.Position = UDim2.new(0, 12, 0.5, 0)
		local l = Style.label(toast, text, 17, F.heavy, C.text)
		l.Position = UDim2.fromOffset(140, 0)
		l.Size = UDim2.new(1, -150, 1, 0)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		rise(toast, 2.6, -30)
		return
	end
	local big = kind == "big"
	local l = Style.label(
		popups,
		text,
		if big then 36 elseif kind == "info" then 24 else 32,
		F.display,
		if kind == "info" then C.text elseif big then C.gold else C.money
	)
	Style.outline(l, 3)
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, (math.random() - 0.5) * 60, 0, 0)
	l.Size = UDim2.new(1, 0, 0, 40)
	rise(l, if big then 2 else 1, if big then 40 else 70)
end

local shownMoney = 0
local function refreshMoney()
	local target = (player:GetAttribute("Money") or 0) :: number
	local from = shownMoney
	shownMoney = target
	if target > from then
		moneyScale.Scale = 1.12
		TweenService:Create(moneyScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - t0) / 0.4, 0, 1)
		moneyLabel.Text = string.sub(money(from + (target - from) * k), 2)
		if k >= 1 then
			conn:Disconnect()
		end
	end)
end

---------------------------------------------------------------- speedometer

local dash = Style.panel(gui, 20)
dash.AnchorPoint = Vector2.new(0.5, 1)
dash.Position = UDim2.new(0.5, 0, 1, -16)
dash.Size = UDim2.fromOffset(210, 104)
dash.Visible = false
local speedLabel = Style.label(dash, "0", 54, F.display, C.text)
speedLabel.Position = UDim2.fromOffset(0, 2)
speedLabel.Size = UDim2.new(1, 0, 0, 56)
Style.outline(speedLabel)
local unitLabel = Style.label(dash, "MPH", 13, F.heavy, C.dim)
unitLabel.Position = UDim2.fromOffset(0, 56)
unitLabel.Size = UDim2.new(1, 0, 0, 14)
local gearLabel = Style.pill(dash, "D", C.money)
gearLabel.Position = UDim2.fromOffset(12, 12)
local function meter(y: number, color: Color3): (Frame, Frame)
	local back, fill = Style.bar(dash, color)
	back.Position = UDim2.fromOffset(20, y)
	back.Size = UDim2.new(1, -40, 0, 7)
	back.Visible = false
	return back, fill
end
local jetBar, jetFill = meter(76, C.blue)
local thrustBar, thrustFill = meter(88, C.orange)

local hintBox = Style.panel(gui, 12, 0.25)
hintBox.AnchorPoint = Vector2.new(0.5, 1)
hintBox.Position = UDim2.new(0.5, 0, 1, -128)
hintBox.Size = UDim2.fromOffset(0, 28)
hintBox.AutomaticSize = Enum.AutomaticSize.X
hintBox.Visible = false
local hintPad = Instance.new("UIPadding")
hintPad.PaddingLeft = UDim.new(0, 14)
hintPad.PaddingRight = UDim.new(0, 14)
hintPad.Parent = hintBox
local hint = Style.label(hintBox, "", 14, F.bold, C.text)
hint.AutomaticSize = Enum.AutomaticSize.X
hint.Size = UDim2.fromScale(0, 1)

local bombLabel = Style.label(gui, "SELF-DESTRUCT", 52, F.display, C.red)
bombLabel.AnchorPoint = Vector2.new(0.5, 0.5)
bombLabel.Position = UDim2.fromScale(0.5, 0.4)
bombLabel.Size = UDim2.fromOffset(600, 60)
Style.outline(bombLabel, 4)
bombLabel.Visible = false

---------------------------------------------------------------- side buttons and panels

local side = Instance.new("Frame")
side.BackgroundTransparency = 1
side.AnchorPoint = Vector2.new(0, 0.5)
side.Position = UDim2.new(0, 14, 0.5, 0)
side.Size = UDim2.fromOffset(140, 130)
side.Parent = gui
local garageButton = Style.button(side, "GARAGE", "red", 20)
garageButton.Name = "GarageButton"
garageButton.Size = UDim2.fromOffset(140, 56)
local storeButton = Style.button(side, "STORE", "blue", 20)
storeButton.Position = UDim2.fromOffset(0, 68)
storeButton.Size = UDim2.fromOffset(140, 56)

local function panel(title: string, accent: Color3): (Frame, ScrollingFrame)
	local p = Style.panel(gui, 22, 0.04)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.53)
	p.Size = UDim2.fromScale(0.86, 0.78)
	p.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(1100, 700)
	limit.Parent = p
	local stripe = Instance.new("Frame")
	stripe.BackgroundColor3 = accent
	stripe.BorderSizePixel = 0
	stripe.Position = UDim2.fromOffset(22, 16)
	stripe.Size = UDim2.fromOffset(6, 32)
	stripe.Parent = p
	Style.corner(stripe, 3)
	local t = Style.label(p, title, 34, F.display, C.text)
	t.Position = UDim2.fromOffset(38, 10)
	t.Size = UDim2.new(1, -100, 0, 44)
	t.TextXAlignment = Enum.TextXAlignment.Left
	Style.outline(t)
	local close = Style.button(p, "X", "dark", 20)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -14, 0, 12)
	close.Size = UDim2.fromOffset(42, 42)
	close.Activated:Connect(function()
		p.Visible = false
	end)
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(16, 66)
	list.Size = UDim2.new(1, -32, 1, -80)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = C.dim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = p
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = list
	return p, list
end

local garage, garageList = panel("GARAGE", C.red)
garage.Name = "Garage"
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(244, 316)
grid.CellPadding = UDim2.fromOffset(14, 14)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = garageList

type Card = { stats: Vehicles.Vehicle, action: TextButton, price: TextLabel, frame: Frame }
local offerFor: ((Vehicles.Vehicle) -> ())? = nil -- set once the store exists
local cards: { Card } = {}

local function statBar(parent: Instance, y: number, name: string, value: number, color: Color3)
	local l = Style.label(parent, name, 11, F.heavy, C.dim)
	l.Position = UDim2.fromOffset(14, y)
	l.Size = UDim2.fromOffset(72, 12)
	l.TextXAlignment = Enum.TextXAlignment.Left
	local back, fill = Style.bar(parent, color)
	back.Position = UDim2.fromOffset(88, y + 3)
	back.Size = UDim2.new(1, -102, 0, 7)
	fill.Size = UDim2.fromScale(math.clamp(value, 0.05, 1), 1)
end

local function preview(parent: Instance, id: string)
	local vf = Instance.new("ViewportFrame")
	vf.Position = UDim2.fromOffset(6, 6)
	vf.Size = UDim2.new(1, -12, 0, 122)
	vf.BackgroundColor3 = Color3.fromRGB(52, 54, 84) -- no UIGradient here: it would tint the 3D model
	vf.Ambient = Color3.fromRGB(175, 175, 190)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(-1, -2, -1)
	vf.Parent = parent
	Style.corner(vf, 12)
	local models = ReplicatedStorage:WaitForChild("VehicleModels")
	local template = models:FindFirstChild(id) :: Model?
	if not template then
		return
	end
	local m = template:Clone()
	m.Parent = vf
	local cf, size = m:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local dist = size.Magnitude * 1.85
	cam.CFrame =
		CFrame.lookAt(cf.Position + Vector3.new(-0.75, 0.45, -0.75).Unit * dist, cf.Position)
	cam.Parent = vf
	vf.CurrentCamera = cam
end

for _, stats in Vehicles.List do
	local card = Style.card(garageList, 16)
	card.LayoutOrder = stats.order
	card.Name = stats.id
	preview(card, stats.id)
	local name = Style.label(card, stats.name, 21, F.display, C.text)
	name.Position = UDim2.fromOffset(14, 132)
	name.Size = UDim2.new(1, -28, 0, 26)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local blurb = Style.label(card, stats.blurb, 12, F.medium, C.dim)
	blurb.Position = UDim2.fromOffset(14, 158)
	blurb.Size = UDim2.new(1, -28, 0, 30)
	blurb.TextWrapped = true
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.TextYAlignment = Enum.TextYAlignment.Top
	statBar(card, 192, "SPEED", stats.topSpeed / 250, C.orange)
	statBar(card, 208, "ACCEL", stats.launch / 15, C.blue)
	statBar(card, 224, "HANDLING", stats.grip / 22, C.green)
	statBar(card, 240, "WEIGHT", math.log10(stats.weight / 50) / math.log10(20000 / 50), C.purple)
	if stats.breaksBuildings then
		local tag = Style.pill(card, "BREAKS BUILDINGS", C.orange)
		tag.AnchorPoint = Vector2.new(1, 0)
		tag.Position = UDim2.new(1, -12, 0, 12)
		tag.ZIndex = 3
	end
	local price = Style.label(
		card,
		if stats.price == 0 then "FREE" else money(stats.price),
		20,
		F.display,
		C.money
	)
	price.Position = UDim2.fromOffset(14, 272)
	price.Size = UDim2.fromOffset(110, 32)
	price.TextXAlignment = Enum.TextXAlignment.Left
	Style.outline(price, 1.5)
	local action = Style.button(card, "SPAWN", "green", 18)
	action.Name = "Action"
	action.AnchorPoint = Vector2.new(1, 0)
	action.Position = UDim2.new(1, -12, 0, 268)
	action.Size = UDim2.fromOffset(112, 38)
	action.Activated:Connect(function()
		local owned = string.find(
			"," .. ((player:GetAttribute("Owned") or "") :: string) .. ",",
			"," .. stats.id .. ",",
			1,
			true
		)
		if owned then
			Net.waitFor("SpawnVehicle"):FireServer(stats.id)
			garage.Visible = false
		elseif
			stats.id == "Roadster"
			and ((player:GetAttribute("Money") or 0) :: number) < stats.price
		then
			Net.waitFor("BuyPass"):FireServer("Roadster")
		elseif ((player:GetAttribute("Money") or 0) :: number) < stats.price and offerFor then
			offerFor(stats) -- not enough yet: offer the pack that covers it
		else
			Net.waitFor("BuyVehicle"):FireServer(stats.id)
		end
	end)
	table.insert(cards, { stats = stats, action = action, price = price, frame = card })
end

local function refreshCards()
	local owned = "," .. ((player:GetAttribute("Owned") or "") :: string) .. ","
	local cash = (player:GetAttribute("Money") or 0) :: number
	for _, c in cards do
		if string.find(owned, "," .. c.stats.id .. ",", 1, true) then
			c.action.Text = "SPAWN"
			Style.setKind(c.action, "green")
			c.price.Text = "OWNED"
			c.price.TextColor3 = C.dim
		else
			c.price.Text = if c.stats.price == 0 then "FREE" else money(c.stats.price)
			c.price.TextColor3 = C.money
			if cash >= c.stats.price then
				c.action.Text = "BUY"
				Style.setKind(c.action, "orange")
			elseif c.stats.id == "Roadster" then
				c.action.Text = "GET PASS"
				Style.setKind(c.action, "blue")
			else
				c.action.Text = "BUY"
				Style.setKind(c.action, "dark")
			end
		end
	end
end

local store, storeList = panel("STORE", C.blue)
store.Name = "Store"
local storeLayout = Instance.new("UIListLayout")
storeLayout.Padding = UDim.new(0, 12)
storeLayout.SortOrder = Enum.SortOrder.LayoutOrder
storeLayout.Parent = storeList

local function header(order: number, text: string)
	local h = Style.label(storeList, text, 22, F.display, C.dim)
	h.Size = UDim2.new(1, -12, 0, 26)
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.LayoutOrder = order
end

-- "R$ 99": the configured label until the product exists, then Roblox's real price
local function robuxText(product: Products.Product, label: TextButton)
	label.Text = "R$ " .. product.robux
	if product.id ~= 0 then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(product.id, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				label.Text = "R$ " .. info.PriceInRobux
			end
		end)
	elseif RunService:IsStudio() then
		label.Text ..= " (test)"
	end
end

local passButtons: { [string]: TextButton } = {}
local function storeRow(
	order: number,
	title: string,
	text: string,
	buttonText: string,
	accent: Color3,
	kind: string,
	onClick: () -> ()
): TextButton
	local row = Style.card(storeList, 16)
	row.Size = UDim2.new(1, -12, 0, 88)
	row.LayoutOrder = order
	local stripe = Instance.new("Frame")
	stripe.BackgroundColor3 = accent
	stripe.BorderSizePixel = 0
	stripe.Position = UDim2.fromOffset(0, 0)
	stripe.Size = UDim2.new(0, 8, 1, 0)
	stripe.Parent = row
	Style.corner(stripe, 4)
	local t = Style.label(row, title, 24, F.display, C.text)
	t.Position = UDim2.fromOffset(24, 10)
	t.Size = UDim2.new(1, -220, 0, 30)
	t.TextXAlignment = Enum.TextXAlignment.Left
	Style.outline(t, 1.5)
	local d = Style.label(row, text, 14, F.medium, C.dim)
	d.Position = UDim2.fromOffset(24, 42)
	d.Size = UDim2.new(1, -220, 0, 36)
	d.TextWrapped = true
	d.TextXAlignment = Enum.TextXAlignment.Left
	d.TextYAlignment = Enum.TextYAlignment.Top
	local b = Style.button(row, buttonText, kind, 18)
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -16, 0.5, 0)
	b.Size = UDim2.fromOffset(170, 48)
	b.Activated:Connect(onClick)
	return b
end

local PASSES = {
	{
		name = "Roadster",
		title = "ROADSTER",
		accent = C.red,
		text = "The dream car: rear jet, air control and a thruster. Plus $1,000,000 in game.",
	},
	{
		name = "Wrecker",
		title = "WRECKER",
		accent = C.orange,
		text = "Run over other players and fling their cars. Includes self-destruct.",
	},
	{
		name = "DoubleMoney",
		title = "2x MONEY",
		accent = C.money,
		text = "Double money from every hit.",
	},
}
header(1, "SPECIAL OFFER")
local starter = Products.Starter
local starterButton = storeRow(
	2,
	string.upper(starter.title),
	`{money(starter.money)} + the {Vehicles.ById[starter.vehicle or ""].name}. Once per account.`,
	"",
	C.gold,
	"gold",
	function()
		Net.waitFor("BuyProduct"):FireServer(starter.key)
	end
)
robuxText(starter, starterButton)

header(3, "MONEY")
local packs = Instance.new("Frame")
packs.BackgroundTransparency = 1
packs.Size = UDim2.new(1, -12, 0, 176)
packs.LayoutOrder = 4
packs.Parent = storeList
local packGrid = Instance.new("UIGridLayout")
packGrid.CellSize = UDim2.new(0.25, -10, 1, 0)
packGrid.CellPadding = UDim2.fromOffset(12, 0)
packGrid.SortOrder = Enum.SortOrder.LayoutOrder
packGrid.Parent = packs
for i, pack in Products.MoneyPacks do
	local card = Style.card(packs, 16)
	card.LayoutOrder = i
	if pack.tag then
		local tag =
			Style.pill(card, pack.tag, if i == #Products.MoneyPacks then C.gold else C.orange)
		tag.AnchorPoint = Vector2.new(0.5, 0)
		tag.Position = UDim2.new(0.5, 0, 0, 10)
	end
	local amount = Style.label(card, money(pack.money), 30, F.display, C.money)
	amount.Position = UDim2.fromOffset(0, 36)
	amount.Size = UDim2.new(1, 0, 0, 40)
	Style.outline(amount, 2)
	local name = Style.label(card, pack.title, 15, F.heavy, C.dim)
	name.Position = UDim2.fromOffset(0, 78)
	name.Size = UDim2.new(1, 0, 0, 18)
	local buy = Style.button(card, "", "green", 18)
	buy.AnchorPoint = Vector2.new(0.5, 1)
	buy.Position = UDim2.new(0.5, 0, 1, -12)
	buy.Size = UDim2.new(1, -24, 0, 46)
	robuxText(pack, buy)
	buy.Activated:Connect(function()
		Net.waitFor("BuyProduct"):FireServer(pack.key)
	end)
end

header(5, "GAME PASSES")
for i, p in PASSES do
	passButtons[p.name] = storeRow(5 + i, p.title, p.text, "GET", p.accent, "blue", function()
		Net.waitFor("BuyPass"):FireServer(p.name)
	end)
end
header(9, "FREE")
local likeButton = storeRow(
	10,
	"LIKE REWARD",
	`Liked the game? Thanks! Here's {money(Economy.LikeReward)}, once.`,
	"CLAIM",
	C.gold,
	"green",
	function()
		Net.waitFor("ClaimLike"):FireServer()
	end
)
local credits = Style.label(
	storeList,
	"Vehicle models: Pavel 3D, Low Poly City Vehicles Pack (CC BY 4.0). "
		.. "Roadster: simplified from a model by metarex.4d on Sketchfab (CC BY 4.0).",
	12,
	F.medium,
	C.dim
)
credits.TextWrapped = true
credits.Size = UDim2.new(1, -12, 0, 44)
credits.LayoutOrder = 20

local function refreshStore()
	for name, b in passButtons do
		local test = RunService:IsStudio() and Economy.Passes[name] == 0
		if player:GetAttribute("Pass" .. name) == true then
			b.Text = if test then "OWNED (test)" else "OWNED"
			Style.setKind(b, "dark")
		else
			b.Text = if test then "TEST TOGGLE" else "GET"
			Style.setKind(b, "blue")
		end
	end
	local bought = string.find(
		"," .. ((player:GetAttribute("Bought") or "") :: string) .. ",",
		",Starter,",
		1,
		true
	) ~= nil
	local starterRow = starterButton.Parent :: GuiObject
	starterRow.Visible = not bought
	for _, h in storeList:GetChildren() do
		if h:IsA("TextLabel") and h.LayoutOrder == 1 then
			h.Visible = not bought
		end
	end
	local claimed = player:GetAttribute("LikeClaimed") == true
	likeButton.Text = if claimed then "CLAIMED" else "CLAIM"
	Style.setKind(likeButton, if claimed then "dark" else "green")
end

local function open(p: Frame)
	local scale = p:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = p
	scale.Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	p.Visible = true
end

---------------------------------------------------------------- offers

local offer = Style.panel(gui, 20, 0.02)
offer.AnchorPoint = Vector2.new(0.5, 0.5)
offer.Position = UDim2.fromScale(0.5, 0.5)
offer.Size = UDim2.fromOffset(420, 250)
offer.ZIndex = 10
offer.Visible = false
Style.stroke(offer, C.gold, 3, 0)
local offerTitle = Style.label(offer, "", 30, F.display, C.gold)
offerTitle.Position = UDim2.fromOffset(0, 16)
offerTitle.Size = UDim2.new(1, 0, 0, 36)
offerTitle.ZIndex = 11
Style.outline(offerTitle, 2)
local offerText = Style.label(offer, "", 17, F.bold, C.text)
offerText.Position = UDim2.fromOffset(24, 58)
offerText.Size = UDim2.new(1, -48, 0, 70)
offerText.TextWrapped = true
offerText.ZIndex = 11
local offerBuy = Style.button(offer, "", "green", 20)
offerBuy.AnchorPoint = Vector2.new(0.5, 0)
offerBuy.Position = UDim2.new(0.5, 0, 0, 136)
offerBuy.Size = UDim2.fromOffset(260, 50)
offerBuy.ZIndex = 11
local offerNo = Style.button(offer, "KEEP DRIVING", "dark", 16)
offerNo.AnchorPoint = Vector2.new(0.5, 0)
offerNo.Position = UDim2.new(0.5, 0, 0, 194)
offerNo.Size = UDim2.fromOffset(200, 38)
offerNo.ZIndex = 11
local offerKey = ""
offerBuy.Activated:Connect(function()
	offer.Visible = false
	Net.waitFor("BuyProduct"):FireServer(offerKey)
end)
offerNo.Activated:Connect(function()
	offer.Visible = false
end)

local function showOffer(
	title: string,
	text: string,
	product: Products.Product,
	buyLabel: string,
	noLabel: string
)
	offerTitle.Text = title
	offerText.Text = text
	offerKey = product.key
	robuxText(product, offerBuy)
	offerBuy.Text = buyLabel .. "  ·  " .. offerBuy.Text
	offerNo.Text = noLabel
	local scale = offer:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = offer
	scale.Scale = 0.8
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	offer.Visible = true
end

-- tapping BUY on a car you can't afford: suggest the smallest pack that covers the gap
offerFor = function(stats: Vehicles.Vehicle)
	local cash = (player:GetAttribute("Money") or 0) :: number
	local gap = stats.price - cash
	local pick = Products.MoneyPacks[#Products.MoneyPacks]
	for _, pack in Products.MoneyPacks do
		if pack.money >= gap then
			pick = pack
			break
		end
	end
	showOffer(
		`NEED {money(gap)} MORE`,
		`Keep running people over to earn it, or grab {pick.title} ({money(pick.money)}) for the {stats.name} right now.`,
		pick,
		"GET " .. money(pick.money),
		"KEEP DRIVING"
	)
end

local starterOffered = false
local function maybeOfferStarter()
	local bought = string.find(
		"," .. ((player:GetAttribute("Bought") or "") :: string) .. ",",
		",Starter,",
		1,
		true
	) ~= nil
	if starterOffered or bought then
		return
	end
	starterOffered = true
	task.delay(8, function()
		if not offer.Visible then
			showOffer(
				"STARTER PACK",
				`{money(starter.money)} + the {Vehicles.ById[starter.vehicle or ""].name}, once per account. A big head start!`,
				starter,
				"GET IT",
				"NO THANKS"
			)
		end
	end)
end

garageButton.Activated:Connect(function()
	store.Visible = false
	if garage.Visible then
		garage.Visible = false
	else
		refreshCards()
		open(garage)
	end
end)
storeButton.Activated:Connect(function()
	garage.Visible = false
	if store.Visible then
		store.Visible = false
	else
		refreshStore()
		open(store)
	end
end)

---------------------------------------------------------------- phone driving buttons

local touch = Instance.new("Frame")
touch.BackgroundTransparency = 1
touch.AnchorPoint = Vector2.new(1, 1)
touch.Position = UDim2.new(1, -20, 1, -150)
touch.Size = UDim2.fromOffset(240, 200)
touch.Visible = false
touch.Parent = gui

local function holdButton(
	text: string,
	pos: UDim2,
	kind: string,
	down: () -> (),
	up: () -> ()
): TextButton
	local b = Style.button(touch, text, kind, 15)
	b.Size = UDim2.fromOffset(74, 74)
	b.Position = pos
	local round = b:FindFirstChildOfClass("UICorner") :: UICorner
	round.CornerRadius = UDim.new(1, 0)
	b.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			down()
		end
	end)
	b.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			up()
		end
	end)
	return b
end
local boostB = holdButton("FLY", UDim2.fromOffset(160, 0), "blue", function()
	Drive.input.boost = true
end, function()
	Drive.input.boost = false
end)
local featureB = holdButton("HORN", UDim2.fromOffset(80, 0), "gold", function()
	Drive.input.feature = true
end, function()
	Drive.input.feature = false
end)
local thrustB = holdButton("BOOST", UDim2.fromOffset(160, 80), "orange", function()
	Drive.input.thrust = true
	Drive.thruster()
end, function()
	Drive.input.thrust = false
end)
local bombB = holdButton("BOMB", UDim2.fromOffset(0, 0), "red", function()
	Drive.input.bomb = true
end, function()
	Drive.input.bomb = false
end)
local rollL = holdButton("ROLL L", UDim2.fromOffset(0, 80), "dark", function()
	Drive.input.roll = -1
end, function()
	Drive.input.roll = 0
end)
local rollR = holdButton("ROLL R", UDim2.fromOffset(80, 80), "dark", function()
	Drive.input.roll = 1
end, function()
	Drive.input.roll = 0
end)

---------------------------------------------------------------- per frame

local FEATURE_NAMES = { Taxi = "TAXI!", Jingle = "JINGLE", Cannon = "WATER" }

RunService.RenderStepped:Connect(function()
	local s = Drive.state
	dash.Visible = s.driving
	hintBox.Visible = s.driving and not UserInputService.TouchEnabled
	touch.Visible = s.driving and UserInputService.TouchEnabled
	if not s.driving then
		bombLabel.Visible = false
		return
	end
	local stats = Vehicles.ById[s.vehicleId]
	speedLabel.Text = tostring(s.speedMph)
	gearLabel.Text = if s.reverse then "R" else "D"
	gearLabel.BackgroundColor3 = if s.reverse then C.red else C.money
	local hasJet = stats ~= nil and Vehicles.has(stats, "Jet")
	local hasThruster = stats ~= nil and Vehicles.has(stats, "Thruster")
	local wrecker = player:GetAttribute("PassWrecker") == true
	local feature: string? = nil
	if stats then
		for f, text in FEATURE_NAMES do
			if Vehicles.has(stats, f :: any) then
				feature = text
			end
		end
	end
	jetBar.Visible = hasJet
	jetFill.Size = UDim2.fromScale(s.boost / 100, 1)
	thrustBar.Visible = hasThruster and not hasJet -- the Roadster's rear jet runs on the flight meter
	thrustFill.Size = UDim2.fromScale(s.thruster, 1)
	local keys = { "WASD drive", "SPACE get out" }
	if feature then
		table.insert(keys, "G " .. string.lower(feature))
	end
	if hasJet then
		table.insert(keys, "hold SHIFT jet up")
		table.insert(keys, "hold Q/E roll")
		table.insert(keys, "S reverse jet")
	end
	if hasJet then
		table.insert(keys, "hold R rear jet")
	elseif hasThruster then
		table.insert(keys, "R thruster")
	end
	if wrecker then
		table.insert(keys, "hold X self-destruct")
	end
	hint.Text = table.concat(keys, "   ·   ")
	boostB.Visible = hasJet
	featureB.Visible = feature ~= nil
	featureB.Text = feature or ""
	thrustB.Visible = hasThruster
	bombB.Visible = wrecker
	rollL.Visible = hasJet and s.airborne
	rollR.Visible = hasJet and s.airborne
	bombLabel.Visible = s.bombHold > 0.05
	bombLabel.TextTransparency = if math.floor(os.clock() * (4 + s.bombHold * 12)) % 2 == 0
		then 0
		else 0.6
end)

function Hud.start()
	Net.waitFor("Popup").OnClientEvent:Connect(popup)
	player:GetAttributeChangedSignal("Money"):Connect(function()
		refreshMoney()
		refreshCards()
	end)
	player:GetAttributeChangedSignal("Owned"):Connect(refreshCards)
	player:GetAttributeChangedSignal("LikeClaimed"):Connect(refreshStore)
	player:GetAttributeChangedSignal("Bought"):Connect(refreshStore)
	player:GetAttributeChangedSignal("Tutorial"):Connect(function()
		if player:GetAttribute("Tutorial") == 3 then
			maybeOfferStarter()
		end
	end)
	for _, p in PASSES do
		player:GetAttributeChangedSignal("Pass" .. p.name):Connect(refreshStore)
	end
	refreshMoney()
	refreshCards()
	refreshStore()
	-- first visit: open the garage so the starter car is one click away
	task.delay(2, function()
		while not player:GetAttribute("DataReady") do
			task.wait(0.2)
		end
		if not Drive.state.driving and player:GetAttribute("Tutorial") == 1 then
			refreshCards()
			open(garage)
		end
	end)
end

return Hud
