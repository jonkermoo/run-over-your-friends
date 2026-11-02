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

local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)
local DailyRules = require(ReplicatedStorage.Shared.Rules.Daily)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Net = require(ReplicatedStorage.Shared.Net)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Cockpit = require(script.Parent.Cockpit)
local Drive = require(script.Parent.Drive)
local PaintPicker = require(script.Parent.PaintPicker)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local Hud = {}
Hud.onGoals = nil :: (() -> ())? -- set by the goals sheet; the GOALS tab calls it
Hud.onMenu = nil :: (() -> ())? -- set by the goals sheet; called when the garage or store opens
local C, F = Style.colors, Style.fonts
local money = Style.money

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

---------------------------------------------------------------- money and pop-ups

-- top right: the money in a parking-bay box (white painted lines round asphalt)
local moneyBox = Style.panel(gui)
moneyBox.AnchorPoint = Vector2.new(1, 0)
moneyBox.Position = UDim2.new(1, -14, 0, 8)
moneyBox.Size = UDim2.fromOffset(196, 54)
Style.stroke(moneyBox, C.text, 3, 0)
local moneyScale = Instance.new("UIScale")
moneyScale.Parent = moneyBox
local cashTag = Style.label(moneyBox, "CASH", 11, F.heavy, C.yellow)
cashTag.AnchorPoint = Vector2.new(1, 0)
cashTag.Position = UDim2.new(1, -12, 0, 5)
cashTag.Size = UDim2.fromOffset(60, 12)
cashTag.TextXAlignment = Enum.TextXAlignment.Right
local moneyLabel = Style.label(moneyBox, "$0", 30, F.display, C.money)
moneyLabel.AnchorPoint = Vector2.new(1, 0)
moneyLabel.Position = UDim2.new(1, -12, 0, 17)
moneyLabel.Size = UDim2.new(1, -20, 0, 32)
moneyLabel.TextXAlignment = Enum.TextXAlignment.Right
moneyLabel.TextScaled = true
local moneyFit = Instance.new("UITextSizeConstraint")
moneyFit.MaxTextSize = 30
moneyFit.Parent = moneyLabel

-- the feed under the money: gains and messages stack downwards and fade, the newest on top
local feed = Instance.new("Frame")
feed.BackgroundTransparency = 1
feed.AnchorPoint = Vector2.new(1, 0)
feed.Position = UDim2.new(1, -14, 0, 76)
feed.Size = UDim2.fromOffset(320, 260)
feed.Parent = gui
local feedItems: { GuiObject } = {}

local function fadeOut(obj: GuiObject, seconds: number)
	local info = TweenInfo.new(seconds)
	for _, d in { obj, table.unpack(obj:GetDescendants()) } do
		if d:IsA("TextLabel") then
			TweenService:Create(d, info, { TextTransparency = 1, BackgroundTransparency = 1 })
				:Play()
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
			TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		end
	end
end

local function pushFeed(item: GuiObject, hold: number, height: number)
	local h = height + 10
	for _, other in feedItems do
		TweenService:Create(other, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
			Position = other.Position + UDim2.fromOffset(0, h),
		}):Play()
	end
	table.insert(feedItems, item)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = item
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(hold, function()
		fadeOut(item, 0.4)
		task.delay(0.45, function()
			local i = table.find(feedItems, item)
			if i then
				table.remove(feedItems, i)
			end
			item:Destroy()
		end)
	end)
end

-- one feed plate: paint colour, text colour, size
local function plate(text: string, fill: Color3, ink: Color3, size: number, font: Font): TextLabel
	local l = Style.label(feed, text, size, font, ink)
	l.BackgroundColor3 = fill
	l.BackgroundTransparency = 0
	l.AnchorPoint = Vector2.new(1, 0)
	l.Position = UDim2.fromScale(1, 0)
	Style.fitText(l, 12, 4)
	Style.shadow(l, C.ink, 4)
	return l
end

local function popup(text: string, kind: string)
	local item: TextLabel
	local hold = 1.4
	if kind == "goal" then
		item =
			plate(`<font color="#FFD000">GOAL DONE</font>   {text}`, C.panel, C.text, 15, F.heavy)
		item.RichText = true
		hold = 3
	elseif kind == "big" then
		item = plate(text, C.yellow, C.ink, 26, F.display)
		hold = 2.4
	elseif kind == "info" then
		item = plate(text, C.panel, C.text, 15, F.heavy)
		hold = 2.4
	else
		item = plate(text, C.money, C.ink, 24, F.display)
	end
	pushFeed(item, hold, item.TextSize + 8)
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
		moneyLabel.Text = money(from + (target - from) * k)
		if k >= 1 then
			conn:Disconnect()
		end
	end)
end

---------------------------------------------------------------- speedometer

-- bottom centre: a gear chip, the big number and a yellow MPH tab on one asphalt plate; flight and
-- thruster meters run under it as dashed lane bars
local DASH_W, DASH_H, METER_H = 214, 64, 12
local dash = Style.panel(gui)
dash.Name = "Speedometer"
dash.AnchorPoint = Vector2.new(0.5, 1)
dash.Position = UDim2.new(0.5, 0, 1, -18)
dash.Size = UDim2.fromOffset(DASH_W, DASH_H)
dash.Visible = false
local gearLabel = Style.label(dash, "D", 26, F.display, C.text)
gearLabel.BackgroundColor3 = C.blue
gearLabel.BackgroundTransparency = 0
gearLabel.Size = UDim2.fromOffset(40, DASH_H)
local speedLabel = Style.label(dash, "0", 52, F.display, C.text)
speedLabel.Position = UDim2.fromOffset(40, 6)
speedLabel.Size = UDim2.new(1, -40 - 30, 0, DASH_H - 6)
local unitLabel = Style.label(dash, "MPH", 13, F.heavy, C.ink)
unitLabel.BackgroundColor3 = C.yellow
unitLabel.BackgroundTransparency = 0
unitLabel.AnchorPoint = Vector2.new(1, 0)
unitLabel.Position = UDim2.fromScale(1, 0)
unitLabel.Size = UDim2.fromOffset(DASH_H, 30)
unitLabel.Rotation = -90
-- a rotated label turns about its centre: shift it so it fills the 30 px strip on the right edge
unitLabel.Position = UDim2.new(1, (DASH_H - 30) / 2, 0, (DASH_H - 30) / 2)

local function meter(color: Color3): (Frame, Frame)
	local back, fill = Style.bar(dash, color)
	back.BackgroundColor3 = C.card
	back.BackgroundTransparency = 0
	back.Size = UDim2.new(1, -16, 0, 6)
	back.Visible = false
	-- gaps every 14 px make it a painted lane line
	for x = 10, DASH_W, 14 do
		local gap = Instance.new("Frame")
		gap.BackgroundColor3 = C.panel
		gap.BorderSizePixel = 0
		gap.Position = UDim2.fromOffset(x, 0)
		gap.Size = UDim2.new(0, 4, 1, 0)
		gap.ZIndex = 2
		gap.Parent = back
	end
	back.ClipsDescendants = true
	return back, fill
end
local jetBar, jetFill = meter(C.blue)
local thrustBar, thrustFill = meter(C.orange)

-- lay the meters out under the number and grow the plate to fit them
local function layoutMeters()
	local y = DASH_H + 2
	for _, bar in { jetBar, thrustBar } do
		if bar.Visible then
			bar.Position = UDim2.fromOffset(8, y)
			y += METER_H
		end
	end
	dash.Size = UDim2.fromOffset(DASH_W, if y > DASH_H + 2 then y + 4 else DASH_H)
end

-- the hint line above the speedometer: an asphalt strip with a yellow edge line under it
local hint = Style.label(gui, "", 14, F.bold, C.text)
hint.BackgroundColor3 = C.panel
hint.BackgroundTransparency = 0
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -104)
hint.Visible = false
Style.fitText(hint, 14, 6)
local hintEdge = Instance.new("Frame")
hintEdge.BackgroundColor3 = C.yellow
hintEdge.BorderSizePixel = 0
hintEdge.AnchorPoint = Vector2.new(0, 1)
hintEdge.Position = UDim2.fromScale(0, 1)
hintEdge.Size = UDim2.new(1, 0, 0, 3)
hintEdge.Parent = hint
local hintBox = hint

local bombLabel = Style.label(gui, "SELF-DESTRUCT", 56, F.display, C.red)
bombLabel.Rotation = -4
bombLabel.AnchorPoint = Vector2.new(0.5, 0.5)
bombLabel.Position = UDim2.fromScale(0.5, 0.4)
bombLabel.Size = UDim2.fromOffset(600, 60)
Style.outline(bombLabel, 4)
bombLabel.Visible = false

---------------------------------------------------------------- side buttons and panels

-- top left: one asphalt strip of tabs split by dashed lane lines (the left middle of the screen is
-- the phone thumbstick's, so no buttons there)
local strip = Style.panel(gui)
strip.Name = "Menu"
strip.Position = UDim2.fromOffset(14, 8)
strip.Size = UDim2.fromOffset(0, 46)
Style.setShadow(strip, C.pink)
local tabRow = Instance.new("Frame") -- the layout lives in here so it doesn't move the shadow
tabRow.BackgroundTransparency = 1
tabRow.Size = UDim2.fromScale(0, 1)
tabRow.AutomaticSize = Enum.AutomaticSize.X
tabRow.Parent = strip
tabRow:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	strip.Size = UDim2.fromOffset(tabRow.AbsoluteSize.X, 46)
end)
local stripList = Instance.new("UIListLayout")
stripList.FillDirection = Enum.FillDirection.Horizontal
stripList.SortOrder = Enum.SortOrder.LayoutOrder
stripList.Parent = tabRow

local tabs: { TextButton } = {}
local function tab(text: string, order: number): TextButton
	if order > 1 then
		local divider = Style.dashes(tabRow, C.yellow, true, 3)
		divider.LayoutOrder = order * 2 - 1
		divider.Size = UDim2.new(0, 3, 1, 0)
	end
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = C.yellow
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	b.Text = text
	b.TextSize = 21
	b.FontFace = F.display
	b.TextColor3 = C.text
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Size = UDim2.fromOffset(0, 46)
	b.LayoutOrder = order * 2
	b.Parent = tabRow
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.PaddingTop = UDim.new(0, 5)
	pad.Parent = b
	table.insert(tabs, b)
	return b
end
local garageButton = tab("GARAGE", 1)
garageButton.Name = "GarageButton"
local storeButton = tab("STORE", 2)
local goalsButton = tab("GOALS", 3)
goalsButton.Visible = false

-- the open tab is painted yellow
local function markTab(active: TextButton?)
	for _, b in tabs do
		b.BackgroundTransparency = if b == active then 0 else 1
		b.TextColor3 = if b == active then C.ink else C.text
	end
end

-- the garage and the store share one full-height sheet under the menu strip (the strip's tabs switch
-- between them): a big title, a dashed lane line, a yellow X, and a scrolling list
local function panel(title: string, accent: Color3): (Frame, ScrollingFrame)
	local p = Style.panel(gui)
	p.AnchorPoint = Vector2.new(0.5, 0)
	p.Position = UDim2.new(0.5, 0, 0, 68)
	p.Size = UDim2.new(1, -28, 1, -86)
	p.Visible = false
	p.ZIndex = 5
	Style.setShadow(p, accent)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(1100, 760)
	limit.Parent = p
	-- the title sits on the right, by the X: the job card can cover the sheet's top-left corner
	local t = Style.label(p, title, 36, F.display, C.text)
	t.AnchorPoint = Vector2.new(1, 0)
	t.Position = UDim2.new(1, -72, 0, 12)
	t.Size = UDim2.fromOffset(300, 40)
	t.TextXAlignment = Enum.TextXAlignment.Right
	local line = Style.dashes(p, C.yellow, false, 4)
	line.Position = UDim2.fromOffset(0, 58)
	local close = Style.button(p, "X", "gold", 22)
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -14, 0, 9)
	close.Size = UDim2.fromOffset(44, 44)
	close.Activated:Connect(function()
		p.Visible = false
	end)
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(16, 72)
	list.Size = UDim2.new(1, -32, 1, -84)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = C.yellow
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = p
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = list
	return p, list
end

local garage, garageList = panel("GARAGE", C.pink)
garage.Name = "Garage"
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(244, 316)
grid.CellPadding = UDim2.fromOffset(14, 14)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = garageList

type Card = {
	stats: Vehicles.Vehicle,
	action: TextButton,
	price: TextLabel,
	frame: Frame,
	picker: PaintPicker.Picker,
	sale: TextLabel,
	was: TextLabel,
}

-- the car of the day (Config/Daily) is cheaper; the server charges the same price from the same UTC day
local saleIds = DailyRules.saleIds(Vehicles.List, DailyConfig.DiscountSkip)
local function onSaleToday(): string?
	local day = DailyRules.day(workspace:GetServerTimeNow(), DailyConfig.DaySeconds)
	return DailyRules.carOfDay(saleIds, day, DailyConfig.DiscountSalt)
end
local function priceOf(stats: Vehicles.Vehicle): number
	return DailyRules.price(
		stats.id,
		stats.price,
		onSaleToday(),
		DailyConfig.DiscountShare,
		DailyConfig.DiscountRound
	)
end
local offerFor: ((Vehicles.Vehicle) -> ())? = nil -- set once the store exists
local cards: { Card } = {}
local refreshCards: () -> ()

local function statBar(parent: Instance, y: number, name: string, value: number, color: Color3)
	local l = Style.label(parent, name, 10, F.heavy, C.dim)
	l.Position = UDim2.fromOffset(14, y)
	l.Size = UDim2.fromOffset(72, 12)
	l.TextXAlignment = Enum.TextXAlignment.Left
	local back, fill = Style.bar(parent, color)
	back.BackgroundColor3 = C.panel
	back.BackgroundTransparency = 0
	back.Position = UDim2.fromOffset(88, y + 3)
	back.Size = UDim2.new(1, -102, 0, 7)
	fill.Size = UDim2.fromScale(math.clamp(value, 0.05, 1), 1)
	Style.laneGaps(back, C.card)
end

local function preview(parent: Instance, id: string): Model?
	local vf = Instance.new("ViewportFrame")
	vf.Position = UDim2.fromOffset(6, 6)
	vf.Size = UDim2.new(1, -12, 0, 122)
	vf.BackgroundColor3 = Color3.fromRGB(46, 46, 54) -- no UIGradient here: it would tint the 3D model
	vf.Ambient = Color3.fromRGB(175, 175, 190)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(-1, -2, -1)
	vf.Parent = parent
	local line = Style.dashes(parent, C.yellow, false, 3)
	line.Position = UDim2.fromOffset(6, 128)
	line.Size = UDim2.new(1, -12, 0, 3)
	local models = ReplicatedStorage:WaitForChild("VehicleModels")
	local template = models:FindFirstChild(id) :: Model?
	if not template then
		return nil
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
	return m
end

for _, stats in Vehicles.List do
	local card = Style.card(garageList, 16)
	card.LayoutOrder = stats.order
	card.Name = stats.id
	local shown = preview(card, stats.id)
	-- painted bay number in the corner of the preview
	local bay = Style.label(card, string.format("%02d", stats.order), 30, F.display, C.yellow)
	bay.Position = UDim2.fromOffset(14, 10)
	bay.Size = UDim2.fromOffset(60, 32)
	bay.TextXAlignment = Enum.TextXAlignment.Left
	bay.TextTransparency = 0.15
	bay.ZIndex = 2
	Style.outline(bay, 2)
	local name = Style.label(card, stats.name, 22, F.display, C.text)
	name.Position = UDim2.fromOffset(14, 132)
	name.Size = UDim2.new(1, -28, 0, 26)
	name.TextXAlignment = Enum.TextXAlignment.Left
	-- the blurb and stat bars, covered by the paint swatches while the PAINT side is open
	local info = Instance.new("Frame")
	info.Name = "Info"
	info.BackgroundTransparency = 1
	info.Size = UDim2.fromScale(1, 1)
	info.Parent = card
	local blurb = Style.label(info, stats.blurb, 12, F.bold, C.dim)
	blurb.Position = UDim2.fromOffset(14, 158)
	blurb.Size = UDim2.new(1, -28, 0, 30)
	blurb.TextWrapped = true
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.TextYAlignment = Enum.TextYAlignment.Top
	statBar(info, 192, "SPEED", stats.topSpeed / 250, C.orange)
	statBar(info, 208, "ACCEL", stats.launch / 15, C.blue)
	statBar(info, 224, "HANDLING", stats.grip / 22, C.green)
	statBar(info, 240, "WEIGHT", math.log10(stats.weight / 50) / math.log10(20000 / 50), C.pink)
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
	-- car of the day: a paint tag on the preview and the old price struck through above the new one
	local sale = Style.pill(
		card,
		`CAR OF THE DAY  -{math.floor(DailyConfig.DiscountShare * 100 + 0.5)}%`,
		C.pink
	)
	sale.Name = "Sale"
	sale.TextColor3 = C.text
	sale.AnchorPoint = Vector2.new(1, 0)
	sale.Position = UDim2.new(1, -12, 0, 14)
	sale.ZIndex = 2
	sale.Visible = false
	local was = Style.label(card, "", 13, F.heavy, C.dim)
	was.Name = "Was"
	was.AutomaticSize = Enum.AutomaticSize.X
	was.Position = UDim2.fromOffset(14, 260)
	was.Size = UDim2.fromOffset(0, 14)
	was.TextXAlignment = Enum.TextXAlignment.Left
	was.Visible = false
	local strike = Instance.new("Frame")
	strike.BackgroundColor3 = C.pink
	strike.BorderSizePixel = 0
	strike.AnchorPoint = Vector2.new(0, 0.5)
	strike.Position = UDim2.fromScale(0, 0.5)
	strike.Size = UDim2.new(1, 0, 0, 2)
	strike.Parent = was
	local action = Style.button(card, "SPAWN", "green", 18)
	action.Name = "Action"
	action.AnchorPoint = Vector2.new(1, 0)
	action.Position = UDim2.new(1, -12, 0, 268)
	action.Size = UDim2.fromOffset(112, 38)
	local picker = PaintPicker.attach(card, stats.id, shown, info, action, function()
		refreshCards()
	end)
	action.Activated:Connect(function()
		if picker.action() then
			return -- buying the paint colour shown
		end
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
			and ((player:GetAttribute("Money") or 0) :: number) < priceOf(stats)
		then
			Net.waitFor("BuyPass"):FireServer("Roadster")
		elseif ((player:GetAttribute("Money") or 0) :: number) < priceOf(stats) and offerFor then
			offerFor(stats) -- not enough yet: offer the pack that covers it
		else
			Net.waitFor("BuyVehicle"):FireServer(stats.id)
		end
	end)
	table.insert(cards, {
		stats = stats,
		action = action,
		price = price,
		frame = card,
		picker = picker,
		sale = sale,
		was = was,
	})
end

function refreshCards()
	local owned = "," .. ((player:GetAttribute("Owned") or "") :: string) .. ","
	local cash = (player:GetAttribute("Money") or 0) :: number
	for _, c in cards do
		local price = priceOf(c.stats)
		if string.find(owned, "," .. c.stats.id .. ",", 1, true) then
			c.action.Text = "SPAWN"
			Style.setKind(c.action, "green")
			c.price.Text = "OWNED"
			c.price.TextColor3 = C.dim
			c.sale.Visible = false
			c.was.Visible = false
		else
			c.price.Text = if price == 0 then "FREE" else money(price)
			c.price.TextColor3 = C.money
			c.sale.Visible = price < c.stats.price
			c.was.Visible = price < c.stats.price
			c.was.Text = money(c.stats.price)
			if cash >= price then
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
		c.picker.refresh()
	end
end

local store, storeList = panel("STORE", C.blue)
store.Name = "Store"
local storeLayout = Instance.new("UIListLayout")
storeLayout.Padding = UDim.new(0, 12)
storeLayout.SortOrder = Enum.SortOrder.LayoutOrder
storeLayout.Parent = storeList

local function header(order: number, text: string)
	local h = Style.label(storeList, text, 22, F.display, C.yellow)
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
	local row = Style.card(storeList)
	row.Size = UDim2.new(1, -12, 0, 88)
	row.LayoutOrder = order
	local stripe = Instance.new("Frame")
	stripe.BackgroundColor3 = accent
	stripe.BorderSizePixel = 0
	stripe.Position = UDim2.fromOffset(0, 0)
	stripe.Size = UDim2.new(0, 8, 1, 0)
	stripe.Parent = row
	local t = Style.label(row, title, 24, F.display, C.text)
	t.Position = UDim2.fromOffset(24, 10)
	t.Size = UDim2.new(1, -220, 0, 30)
	t.TextXAlignment = Enum.TextXAlignment.Left
	local d = Style.label(row, text, 13, F.bold, C.dim)
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
	local card = Style.card(packs)
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
	local name = Style.label(card, string.upper(pack.title), 13, F.heavy, C.dim)
	name.Position = UDim2.fromOffset(0, 78)
	name.Size = UDim2.new(1, 0, 0, 18)
	local buy = Style.button(card, "", "gold", 18)
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
	passButtons[p.name] = storeRow(5 + i, p.title, p.text, "GET", p.accent, "gold", function()
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
			Style.setKind(b, "gold")
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

local offer = Style.panel(gui)
offer.AnchorPoint = Vector2.new(0.5, 0.5)
offer.Position = UDim2.fromScale(0.5, 0.5)
offer.Size = UDim2.fromOffset(440, 270)
offer.ZIndex = 10
offer.Visible = false
Style.stroke(offer, C.yellow, 4, 0)
Style.setShadow(offer, C.pink)
local hazard = Instance.new("Frame")
hazard.BackgroundColor3 = C.yellow
hazard.BorderSizePixel = 0
hazard.Size = UDim2.new(1, 0, 0, 14)
hazard.ClipsDescendants = true
hazard.ZIndex = 11
hazard.Parent = offer
for x = -20, 460, 28 do
	local stripe = Instance.new("Frame")
	stripe.BackgroundColor3 = C.ink
	stripe.BorderSizePixel = 0
	stripe.Position = UDim2.fromOffset(x, -10)
	stripe.Size = UDim2.fromOffset(12, 40)
	stripe.Rotation = 40
	stripe.ZIndex = 11
	stripe.Parent = hazard
end
local offerTitle = Style.label(offer, "", 32, F.display, C.yellow)
offerTitle.Position = UDim2.fromOffset(0, 28)
offerTitle.Size = UDim2.new(1, 0, 0, 38)
offerTitle.ZIndex = 11
local offerText = Style.label(offer, "", 15, F.bold, C.text)
offerText.Position = UDim2.fromOffset(28, 72)
offerText.Size = UDim2.new(1, -56, 0, 64)
offerText.TextWrapped = true
offerText.ZIndex = 11
local offerBuy = Style.button(offer, "", "gold", 22)
offerBuy.AnchorPoint = Vector2.new(0.5, 0)
offerBuy.Position = UDim2.new(0.5, 0, 0, 146)
offerBuy.Size = UDim2.fromOffset(300, 54)
offerBuy.ZIndex = 11
local offerNo = Style.button(offer, "KEEP DRIVING", "dark", 16)
offerNo.AnchorPoint = Vector2.new(0.5, 0)
offerNo.Position = UDim2.new(0.5, 0, 0, 214)
offerNo.Size = UDim2.fromOffset(200, 40)
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
	local gap = priceOf(stats) - cash
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

-- the Starter Pack ad waits until the player has had a proper go: Products.StarterOfferAfter seconds
-- of play, the tutorial done, nothing else open. Once per session, never once bought.
local joinedAt = os.clock()
local starterOffered = false
local function maybeOfferStarter()
	if starterOffered then
		return
	end
	local bought = string.find(
		"," .. ((player:GetAttribute("Bought") or "") :: string) .. ",",
		",Starter,",
		1,
		true
	) ~= nil
	local step = (player:GetAttribute("Tutorial") or 0) :: number
	if bought then
		starterOffered = true
		return
	end
	if
		os.clock() - joinedAt < Products.StarterOfferAfter
		or step < Onboarding.Steps.Save
		or offer.Visible
		or garage.Visible
		or store.Visible
	then
		return
	end
	starterOffered = true
	showOffer(
		"STARTER PACK",
		`{money(starter.money)} + the {Vehicles.ById[starter.vehicle or ""].name}, once per account. A big head start!`,
		starter,
		"GET IT",
		"NO THANKS"
	)
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
goalsButton.Activated:Connect(function()
	garage.Visible = false
	store.Visible = false
	if Hud.onGoals then
		Hud.onGoals()
	end
end)
for _, p in { garage, store } do
	p:GetPropertyChangedSignal("Visible"):Connect(function()
		if p.Visible and Hud.onMenu then
			Hud.onMenu()
		end
		markTab(if garage.Visible then garageButton elseif store.Visible then storeButton else nil)
	end)
end

---------------------------------------------------------------- phone driving buttons

local touch = Instance.new("Frame")
touch.BackgroundTransparency = 1
touch.AnchorPoint = Vector2.new(1, 1)
touch.Position = UDim2.new(1, -20, 1, -150)
touch.Size = UDim2.fromOffset(240, 200)
touch.Visible = false
touch.Parent = gui

local BAND = { blue = C.blue, gold = C.yellow, orange = C.orange, red = C.red, dark = C.pink }
local function holdButton(
	text: string,
	pos: UDim2,
	kind: string,
	down: () -> (),
	up: () -> ()
): TextButton
	-- an asphalt plate with a yellow painted edge; a band of the button's own colour along the top tells
	-- them apart at a glance. The touch area is the same 74 px square in the same spot as before; the
	-- plate is drawn a little inside it so neighbours keep a clear gap.
	local b = Style.button(touch, text, "dark", 16)
	b.BackgroundTransparency = 1
	b.TextTransparency = 1 -- the label below shows the text; code keeps setting b.Text
	b.Size = UDim2.fromOffset(74, 74)
	b.Position = pos
	for _, extra in { b:FindFirstChild("Edge"), b:FindFirstChild("Shadow") } do
		extra:Destroy()
	end
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BackgroundColor3 = C.panel
	face.BorderSizePixel = 0
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.new(1, -10, 1, -10)
	face.Parent = b
	Style.stroke(face, C.yellow, 2, 0)
	Style.shadow(face, C.ink, 3)
	local band = Instance.new("Frame")
	band.BackgroundColor3 = BAND[kind] or C.grey
	band.BorderSizePixel = 0
	band.Size = UDim2.new(1, 0, 0, 8)
	band.Parent = face
	local caption = Style.label(face, text, 15, F.display, C.text)
	caption.Position = UDim2.fromOffset(0, 8)
	caption.Size = UDim2.new(1, 0, 1, -8)
	b:GetPropertyChangedSignal("Text"):Connect(function()
		caption.Text = b.Text
	end)
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
-- first-person view: a tap toggles it
local viewB = holdButton("VIEW", UDim2.fromOffset(0, -80), "dark", function()
	Cockpit.toggle()
end, function() end)
local rollR = holdButton("ROLL R", UDim2.fromOffset(80, 80), "dark", function()
	Drive.input.roll = 1
end, function()
	Drive.input.roll = 0
end)

---------------------------------------------------------------- per frame

local FEATURE_NAMES = { Taxi = "TAXI!", Jingle = "JINGLE", Cannon = "WATER" }

RunService.RenderStepped:Connect(function()
	local s = Drive.state
	-- the GOALS tab is painted while the goals sheet is open
	local goalsGui = playerGui:FindFirstChild("Goals")
	local sheet = goalsGui and goalsGui:FindFirstChild("GoalsSheet") :: GuiObject?
	if not (garage.Visible or store.Visible) then
		markTab(if sheet and sheet.Visible then goalsButton else nil)
	end
	dash.Visible = s.driving
	local guide = playerGui:FindFirstChild("Guide")
	local tipShown = guide ~= nil
		and (guide:FindFirstChild("Tip") :: GuiObject?) ~= nil
		and (guide:FindFirstChild("Tip") :: GuiObject).Visible
	hintBox.Visible = s.driving and not UserInputService.TouchEnabled and not tipShown
	touch.Visible = s.driving and UserInputService.TouchEnabled
	if not s.driving then
		bombLabel.Visible = false
		return
	end
	local stats = Vehicles.ById[s.vehicleId]
	speedLabel.Text = tostring(s.speedMph)
	gearLabel.Text = if s.reverse then "R" else "D"
	gearLabel.BackgroundColor3 = if s.reverse then C.red else C.blue
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
	layoutMeters()
	hint.Position = UDim2.new(0.5, 0, 1, -(18 + dash.Size.Y.Offset + 14))
	thrustFill.Size = UDim2.fromScale(s.thruster, 1)
	local keys = { "WASD drive", "SPACE get out", "V view" }
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
	viewB.Visible = true
	viewB.Text = if Cockpit.isOn() then "OUT" else "VIEW"
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
	player:GetAttributeChangedSignal("Paint"):Connect(refreshCards)
	player:GetAttributeChangedSignal("Paints"):Connect(refreshCards)
	player:GetAttributeChangedSignal("LikeClaimed"):Connect(refreshStore)
	player:GetAttributeChangedSignal("Bought"):Connect(refreshStore)
	local function tutorialStep()
		local step = (player:GetAttribute("Tutorial") or 0) :: number
		goalsButton.Visible = step >= Onboarding.Steps.Save
	end
	player:GetAttributeChangedSignal("Tutorial"):Connect(tutorialStep)
	tutorialStep()
	task.spawn(function()
		while not starterOffered do
			task.wait(2)
			maybeOfferStarter()
		end
	end)
	for _, p in PASSES do
		player:GetAttributeChangedSignal("Pass" .. p.name):Connect(refreshStore)
	end
	refreshMoney()
	refreshCards()
	refreshStore()
	-- a new car of the day at UTC midnight
	task.spawn(function()
		local shown = onSaleToday()
		while true do
			task.wait(15)
			if onSaleToday() ~= shown then
				shown = onSaleToday()
				refreshCards()
			end
		end
	end)
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
