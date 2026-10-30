--!strict
-- Screen UI: money and pop-ups, the speedometer with jet and thruster meters, the garage (3D previews,
-- stats, buy and spawn), the store (passes, like reward, credits) and the phone driving buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Drive = require(script.Parent.Drive)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local Hud = {}

local INK = Color3.fromRGB(16, 16, 22)
local PANEL = Color3.fromRGB(28, 28, 36)
local ACCENT = Color3.fromRGB(232, 52, 44)
local GOOD = Color3.fromRGB(70, 200, 110)
local MONEY = Color3.fromRGB(120, 230, 120)
local WHITE = Color3.new(1, 1, 1)
local DIM = Color3.fromRGB(160, 162, 172)
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function label(
	parent: Instance,
	text: string,
	size: number,
	font: Font?,
	color: Color3?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.FontFace = font or FONT
	l.TextColor3 = color or WHITE
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color
	b.Text = text
	b.TextSize = 16
	b.FontFace = BOLD
	b.TextColor3 = WHITE
	b.Parent = parent
	corner(b, 10)
	return b
end

local function money(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return "$" .. out
end

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

---------------------------------------------------------------- money and pop-ups

local moneyBox = Instance.new("Frame")
moneyBox.AnchorPoint = Vector2.new(0.5, 0)
moneyBox.Position = UDim2.new(0.5, 0, 0, 8)
moneyBox.Size = UDim2.fromOffset(220, 44)
moneyBox.BackgroundColor3 = INK
moneyBox.BackgroundTransparency = 0.2
moneyBox.Parent = gui
corner(moneyBox, 22)
local moneyLabel = label(moneyBox, "$0", 26, BOLD, MONEY)
moneyLabel.Size = UDim2.fromScale(1, 1)

local popups = Instance.new("Frame")
popups.BackgroundTransparency = 1
popups.AnchorPoint = Vector2.new(0.5, 0)
popups.Position = UDim2.new(0.5, 0, 0, 140)
popups.Size = UDim2.fromOffset(400, 200)
popups.Parent = gui

local function popup(text: string, kind: string)
	local big = kind == "big"
	local l =
		label(popups, text, if big then 30 else 24, BOLD, if kind == "info" then WHITE else MONEY)
	l.TextStrokeTransparency = 0.3
	l.TextStrokeColor3 = INK
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, 10)
	l.Size = UDim2.new(1, 0, 0, 34)
	local up =
		TweenService:Create(l, TweenInfo.new(if big then 2.4 else 1.3, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0.5, 0, 0, if big then 60 else 90),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
	up:Play()
	up.Completed:Once(function()
		l:Destroy()
	end)
end

local shownMoney = 0
local function refreshMoney()
	local target = (player:GetAttribute("Money") or 0) :: number
	local from = shownMoney
	shownMoney = target
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

local dash = Instance.new("Frame")
dash.AnchorPoint = Vector2.new(0.5, 1)
dash.Position = UDim2.new(0.5, 0, 1, -18)
dash.Size = UDim2.fromOffset(190, 96)
dash.BackgroundColor3 = INK
dash.BackgroundTransparency = 0.15
dash.Visible = false
dash.Parent = gui
corner(dash, 18)
local speedLabel = label(dash, "0", 44, BOLD)
speedLabel.Position = UDim2.fromOffset(0, 4)
speedLabel.Size = UDim2.new(1, 0, 0, 48)
local unitLabel = label(dash, "MPH", 12, FONT, DIM)
unitLabel.Position = UDim2.fromOffset(0, 50)
unitLabel.Size = UDim2.new(1, 0, 0, 14)
local gearLabel = label(dash, "D", 16, BOLD, ACCENT)
gearLabel.Position = UDim2.fromOffset(14, 10)
gearLabel.Size = UDim2.fromOffset(20, 20)
local function bar(y: number, color: Color3): Frame
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(18, y)
	back.Size = UDim2.new(1, -36, 0, 6)
	back.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	back.Visible = false
	back.Parent = dash
	corner(back, 3)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.Parent = back
	corner(fill, 3)
	return back
end
local jetBar = bar(70, Color3.fromRGB(110, 180, 255))
local thrustBar = bar(82, Color3.fromRGB(255, 190, 80))
local hint = label(gui, "", 13, FONT, WHITE)
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -120)
hint.Size = UDim2.fromOffset(600, 18)
hint.TextStrokeTransparency = 0.5
hint.Visible = false
local bombLabel = label(gui, "SELF-DESTRUCT", 34, BOLD, ACCENT)
bombLabel.AnchorPoint = Vector2.new(0.5, 0.5)
bombLabel.Position = UDim2.fromScale(0.5, 0.4)
bombLabel.Size = UDim2.fromOffset(500, 50)
bombLabel.TextStrokeTransparency = 0
bombLabel.Visible = false

---------------------------------------------------------------- side buttons and panels

local side = Instance.new("Frame")
side.BackgroundTransparency = 1
side.AnchorPoint = Vector2.new(0, 0.5)
side.Position = UDim2.new(0, 12, 0.5, 0)
side.Size = UDim2.fromOffset(120, 120)
side.Parent = gui
local garageButton = button(side, "GARAGE", ACCENT)
garageButton.Name = "GarageButton"
garageButton.Size = UDim2.fromOffset(120, 50)
local storeButton = button(side, "STORE", Color3.fromRGB(60, 120, 220))
storeButton.Position = UDim2.fromOffset(0, 60)
storeButton.Size = UDim2.fromOffset(120, 50)

local function panel(title: string): (Frame, ScrollingFrame)
	local p = Instance.new("Frame")
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.52)
	p.Size = UDim2.fromScale(0.86, 0.78)
	p.BackgroundColor3 = PANEL
	p.Visible = false
	p.Parent = gui
	corner(p, 18)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(1100, 700)
	limit.Parent = p
	local t = label(p, title, 26, BOLD)
	t.Position = UDim2.fromOffset(20, 10)
	t.Size = UDim2.new(1, -80, 0, 36)
	t.TextXAlignment = Enum.TextXAlignment.Left
	local close = button(p, "X", Color3.fromRGB(70, 70, 80))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(40, 40)
	close.Activated:Connect(function()
		p.Visible = false
	end)
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(14, 58)
	list.Size = UDim2.new(1, -28, 1, -70)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = p
	return p, list
end

local garage, garageList = panel("GARAGE")
garage.Name = "Garage"
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(240, 300)
grid.CellPadding = UDim2.fromOffset(12, 12)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = garageList

type Card = { stats: Vehicles.Vehicle, action: TextButton, price: TextLabel }
local cards: { Card } = {}

local function statBar(parent: Instance, y: number, name: string, value: number)
	local l = label(parent, name, 11, FONT, DIM)
	l.Position = UDim2.fromOffset(12, y)
	l.Size = UDim2.fromOffset(70, 12)
	l.TextXAlignment = Enum.TextXAlignment.Left
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(84, y + 3)
	back.Size = UDim2.new(1, -96, 0, 6)
	back.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
	back.Parent = parent
	corner(back, 3)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(value, 0.04, 1), 1)
	fill.BackgroundColor3 = ACCENT
	fill.Parent = back
	corner(fill, 3)
end

local function preview(parent: Instance, id: string)
	local vf = Instance.new("ViewportFrame")
	vf.Size = UDim2.new(1, 0, 0, 120)
	vf.BackgroundColor3 = Color3.fromRGB(42, 42, 52)
	vf.Ambient = Color3.fromRGB(170, 170, 180)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(-1, -2, -1)
	vf.Parent = parent
	corner(vf, 12)
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
	local dist = size.Magnitude * 1.9
	cam.CFrame =
		CFrame.lookAt(cf.Position + Vector3.new(-0.75, 0.45, -0.75).Unit * dist, cf.Position)
	cam.Parent = vf
	vf.CurrentCamera = cam
end

for _, stats in Vehicles.List do
	local card = Instance.new("Frame")
	card.BackgroundColor3 = INK
	card.LayoutOrder = stats.order
	card.Name = stats.id
	card.Parent = garageList
	corner(card, 14)
	preview(card, stats.id)
	local name = label(card, stats.name, 18, BOLD)
	name.Position = UDim2.fromOffset(12, 124)
	name.Size = UDim2.new(1, -24, 0, 22)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local blurb = label(card, stats.blurb, 11, FONT, DIM)
	blurb.Position = UDim2.fromOffset(12, 146)
	blurb.Size = UDim2.new(1, -24, 0, 28)
	blurb.TextWrapped = true
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.TextYAlignment = Enum.TextYAlignment.Top
	statBar(card, 178, "TOP SPEED", stats.topSpeed / 250)
	statBar(card, 194, "ACCEL", stats.launch / 15)
	statBar(card, 210, "HANDLING", stats.grip / 22)
	statBar(card, 226, "WEIGHT", math.log10(stats.weight / 50) / math.log10(20000 / 50))
	local tag = label(
		card,
		if stats.breaksBuildings then "BREAKS BUILDINGS" else "",
		11,
		BOLD,
		Color3.fromRGB(255, 190, 80)
	)
	tag.Position = UDim2.fromOffset(12, 242)
	tag.Size = UDim2.new(1, -24, 0, 12)
	tag.TextXAlignment = Enum.TextXAlignment.Left
	local price =
		label(card, if stats.price == 0 then "FREE" else money(stats.price), 16, BOLD, MONEY)
	price.Position = UDim2.fromOffset(12, 262)
	price.Size = UDim2.fromOffset(100, 28)
	price.TextXAlignment = Enum.TextXAlignment.Left
	local action = button(card, "SPAWN", GOOD)
	action.Name = "Action"
	action.AnchorPoint = Vector2.new(1, 0)
	action.Position = UDim2.new(1, -10, 0, 258)
	action.Size = UDim2.fromOffset(110, 34)
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
		else
			Net.waitFor("BuyVehicle"):FireServer(stats.id)
		end
	end)
	table.insert(cards, { stats = stats, action = action, price = price })
end

local function refreshCards()
	local owned = "," .. ((player:GetAttribute("Owned") or "") :: string) .. ","
	local cash = (player:GetAttribute("Money") or 0) :: number
	for _, c in cards do
		if string.find(owned, "," .. c.stats.id .. ",", 1, true) then
			c.action.Text = "SPAWN"
			c.action.BackgroundColor3 = GOOD
			c.price.Text = "OWNED"
			c.price.TextColor3 = DIM
		else
			c.price.Text = if c.stats.price == 0 then "FREE" else money(c.stats.price)
			c.price.TextColor3 = MONEY
			if cash >= c.stats.price then
				c.action.Text = "BUY"
				c.action.BackgroundColor3 = ACCENT
			elseif c.stats.id == "Roadster" then
				c.action.Text = "GET PASS"
				c.action.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
			else
				c.action.Text = "BUY"
				c.action.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
			end
		end
	end
end

local store, storeList = panel("STORE")
local storeLayout = Instance.new("UIListLayout")
storeLayout.Padding = UDim.new(0, 10)
storeLayout.SortOrder = Enum.SortOrder.LayoutOrder
storeLayout.Parent = storeList

local passButtons: { [string]: TextButton } = {}
local function storeRow(
	order: number,
	title: string,
	text: string,
	buttonText: string,
	color: Color3,
	onClick: () -> ()
): TextButton
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -10, 0, 78)
	row.BackgroundColor3 = INK
	row.LayoutOrder = order
	row.Parent = storeList
	corner(row, 12)
	local t = label(row, title, 20, BOLD)
	t.Position = UDim2.fromOffset(16, 10)
	t.Size = UDim2.new(1, -200, 0, 24)
	t.TextXAlignment = Enum.TextXAlignment.Left
	local d = label(row, text, 13, FONT, DIM)
	d.Position = UDim2.fromOffset(16, 38)
	d.Size = UDim2.new(1, -200, 0, 32)
	d.TextWrapped = true
	d.TextXAlignment = Enum.TextXAlignment.Left
	d.TextYAlignment = Enum.TextYAlignment.Top
	local b = button(row, buttonText, color)
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -14, 0.5, 0)
	b.Size = UDim2.fromOffset(160, 44)
	b.Activated:Connect(onClick)
	return b
end

local PASSES = {
	{
		name = "Roadster",
		title = "ROADSTER",
		text = "The dream car: rear jet, air control and a thruster. Plus $1,000,000 in game.",
	},
	{
		name = "Wrecker",
		title = "WRECKER",
		text = "Run over other players and fling their cars. Includes self-destruct (hold X).",
	},
	{ name = "DoubleMoney", title = "2x MONEY", text = "Double money from every hit." },
}
for i, p in PASSES do
	passButtons[p.name] = storeRow(
		i,
		p.title,
		p.text,
		"GET",
		Color3.fromRGB(60, 120, 220),
		function()
			Net.waitFor("BuyPass"):FireServer(p.name)
		end
	)
end
local likeButton = storeRow(
	10,
	"LIKE REWARD",
	`Liked the game? Thanks! Here's {money(Economy.LikeReward)}, once.`,
	"CLAIM",
	GOOD,
	function()
		Net.waitFor("ClaimLike"):FireServer()
	end
)
local credits = label(
	storeList,
	"Vehicle models: Pavel 3D, Low Poly City Vehicles Pack (CC BY 4.0)",
	12,
	FONT,
	DIM
)
credits.Size = UDim2.new(1, -10, 0, 30)
credits.LayoutOrder = 20

local function refreshStore()
	for name, b in passButtons do
		if player:GetAttribute("Pass" .. name) == true then
			b.Text = if RunService:IsStudio() and Economy.Passes[name] == 0
				then "OWNED (test)"
				else "OWNED"
			b.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
		else
			b.Text = if RunService:IsStudio() and Economy.Passes[name] == 0
				then "TEST TOGGLE"
				else "GET"
			b.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
		end
	end
	local claimed = player:GetAttribute("LikeClaimed") == true
	likeButton.Text = if claimed then "CLAIMED" else "CLAIM"
	likeButton.BackgroundColor3 = if claimed then Color3.fromRGB(70, 70, 80) else GOOD
end

garageButton.Activated:Connect(function()
	store.Visible = false
	garage.Visible = not garage.Visible
	refreshCards()
end)
storeButton.Activated:Connect(function()
	garage.Visible = false
	store.Visible = not store.Visible
	refreshStore()
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
	color: Color3,
	down: () -> (),
	up: () -> ()
): TextButton
	local b = button(touch, text, color)
	b.Size = UDim2.fromOffset(72, 72)
	b.Position = pos
	b.TextSize = 13
	corner(b, 36)
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
local boostB = holdButton("JET", UDim2.fromOffset(160, 0), Color3.fromRGB(60, 120, 220), function()
	Drive.input.boost = true
end, function()
	Drive.input.boost = false
end)
local featureB = holdButton(
	"HORN",
	UDim2.fromOffset(80, 0),
	Color3.fromRGB(230, 160, 40),
	function()
		Drive.input.feature = true
	end,
	function()
		Drive.input.feature = false
	end
)
local thrustB = holdButton(
	"BOOST",
	UDim2.fromOffset(160, 80),
	Color3.fromRGB(240, 120, 40),
	function()
		Drive.thruster()
	end,
	function() end
)
local bombB = holdButton("BOMB", UDim2.fromOffset(0, 0), ACCENT, function()
	Drive.input.bomb = true
end, function()
	Drive.input.bomb = false
end)
local rollL = holdButton("ROLL L", UDim2.fromOffset(0, 80), Color3.fromRGB(70, 70, 80), function()
	Drive.input.roll = -1
end, function()
	Drive.input.roll = 0
end)
local rollR = holdButton("ROLL R", UDim2.fromOffset(80, 80), Color3.fromRGB(70, 70, 80), function()
	Drive.input.roll = 1
end, function()
	Drive.input.roll = 0
end)

---------------------------------------------------------------- per frame

local FEATURE_NAMES = { Taxi = "TAXI!", Jingle = "JINGLE", Cannon = "WATER" }

RunService.RenderStepped:Connect(function()
	local s = Drive.state
	dash.Visible = s.driving
	hint.Visible = s.driving and not UserInputService.TouchEnabled
	touch.Visible = s.driving and UserInputService.TouchEnabled
	if not s.driving then
		bombLabel.Visible = false
		return
	end
	local stats = Vehicles.ById[s.vehicleId]
	speedLabel.Text = tostring(s.speedMph)
	gearLabel.Text = if s.reverse then "R" else "D"
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
	jetBar.Visible = hasJet;
	(jetBar:FindFirstChildOfClass("Frame") :: Frame).Size = UDim2.fromScale(s.boost / 100, 1)
	thrustBar.Visible = hasThruster;
	(thrustBar:FindFirstChildOfClass("Frame") :: Frame).Size = UDim2.fromScale(s.thruster, 1)
	local keys = { "WASD drive", "SPACE get out" }
	if feature then
		table.insert(keys, "G " .. string.lower(feature))
	end
	if hasJet then
		table.insert(keys, "SHIFT jet")
		table.insert(keys, "Q/E roll in air")
	end
	if hasThruster then
		table.insert(keys, "R thruster")
	end
	if wrecker then
		table.insert(keys, "hold X self-destruct")
	end
	hint.Text = table.concat(keys, "  ·  ")
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
			garage.Visible = true
			refreshCards()
		end
	end)
end

return Hud
