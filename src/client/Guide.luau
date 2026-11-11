--!strict
-- First-session guidance: the job card under the menu strip (spawn, run over 3, ramp, smash, goal, buy, event;
-- after that the pinned goals sit there, PinnedGoals), a big bouncing marker over the target with a light
-- column and an off-screen edge pointer, an arrow at the button to press, timed hints for stuck players,
-- one-time tips when you first drive a vehicle with a feature, and the confetti moment.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Callouts = require(ReplicatedStorage.Shared.Config.Callouts)
local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)
local DailyRules = require(ReplicatedStorage.Shared.Rules.Daily)
local EventConfig = require(ReplicatedStorage.Shared.Config.Events)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Rules = require(ReplicatedStorage.Shared.Rules.Onboarding)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Drive = require(script.Parent.Drive)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local Steps = Onboarding.Steps

local Guide = {}

local C, F = Style.colors, Style.fonts
local INK, MONEY, GOLD, WHITE = C.ink, C.money, C.gold, C.text
local BOLD = F.display
local CONFETTI = { C.red, C.gold, C.green, C.blue, C.purple, C.orange }
local label = Style.label

local gui = Instance.new("ScreenGui")
gui.Name = "Guide"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui
Style.fit(gui)

---------------------------------------------------------------- goal card

-- the job card, top left under the menu strip: a paint stripe down its left edge, a tag, the goal and
-- a lane-line progress bar. Its yellow edge pulses when the goal needs your attention.
local card = Style.panel(gui)
card.Name = "JobCard"
card.Position = UDim2.fromOffset(14, 68)
card.Size = UDim2.fromOffset(420, 68)
card.Visible = false
local stroke = Style.stroke(card, GOLD, 3, 1)
local cardStripe = Instance.new("Frame")
cardStripe.BorderSizePixel = 0
cardStripe.BackgroundColor3 = GOLD
cardStripe.Size = UDim2.new(0, 7, 1, 0)
cardStripe.Parent = card
local tag = Style.pill(card, "TUTORIAL", GOLD)
tag.Position = UDim2.fromOffset(18, 8)
local goalText = label(card, "", 19, F.display, WHITE)
goalText.Position = UDim2.fromOffset(18, 28)
goalText.Size = UDim2.new(1, -32, 0, 22)
goalText.TextXAlignment = Enum.TextXAlignment.Left
goalText.TextScaled = true
-- appears a little after a new step starts: no event on, no money yet, a car that can't jump
local skip = Style.button(card, "SKIP", "dark", 13)
skip.Name = "SkipStep"
skip.AnchorPoint = Vector2.new(1, 0)
skip.Position = UDim2.new(1, -10, 0, 5)
skip.Size = UDim2.fromOffset(64, 22)
skip.Visible = false
local goalFit = Instance.new("UITextSizeConstraint")
goalFit.MaxTextSize = 19
goalFit.Parent = goalText
local barBack, barFill = Style.bar(card, MONEY)
barBack.BackgroundColor3 = C.card
barBack.BackgroundTransparency = 0
barBack.Position = UDim2.fromOffset(18, 54)
barBack.Size = UDim2.new(1, -32, 0, 6)
Style.laneGaps(barBack, C.panel)
-- the "what to do now" nudge sits right under the card
local hintText = label(gui, "", 17, F.display, GOLD)
hintText.Position = UDim2.fromOffset(18, 146)
hintText.Size = UDim2.fromOffset(420, 22)
hintText.TextXAlignment = Enum.TextXAlignment.Left
Style.outline(hintText, 2)
hintText.Visible = false

---------------------------------------------------------------- markers

local Z_ARROW = 30 -- arrows sit above the sheets they point into

-- a chevron pointing down, from two bars (font glyphs like ▼ don't draw); returns its bars to paint
local function chevron(
	parent: Instance,
	y: UDim,
	reach: number,
	length: number,
	thick: number,
	z: number
): { Frame }
	local bars = {}
	for _, side in { -1, 1 } do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.new(UDim.new(0.5, side * reach), y)
		bar.Size = UDim2.fromOffset(length, thick)
		bar.Rotation = side * -45
		bar.BorderSizePixel = 0
		bar.ZIndex = z
		bar.Parent = parent
		local edge = Instance.new("UIStroke")
		edge.Color = INK
		edge.Thickness = 3
		edge.Parent = bar
		table.insert(bars, bar)
	end
	return bars
end

local function paint(bars: { Frame }, color: Color3)
	for _, bar in bars do
		bar.BackgroundColor3 = color
	end
end

-- moved to the target every frame: the marker hangs from it
local anchor = Instance.new("Part")
anchor.Name = "GuideAnchor"
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanQuery = false
anchor.CanTouch = false
anchor.CastShadow = false
anchor.Transparency = 1
anchor.Size = Vector3.one

-- the column of light over a far target (a ramp, a building)
local beacon = Instance.new("Part")
beacon.Name = "GuideBeacon"
beacon.Shape = Enum.PartType.Cylinder
beacon.Anchored = true
beacon.CanCollide = false
beacon.CanQuery = false
beacon.CanTouch = false
beacon.CastShadow = false
beacon.Material = Enum.Material.Neon
beacon.Size = Vector3.new(Onboarding.BeaconHeight, Onboarding.BeaconWidth, Onboarding.BeaconWidth)

-- the big arrow in the world: a fixed size on screen at any distance, its lower edge on the target
local arrow = Instance.new("BillboardGui")
arrow.Name = "GuideArrow"
arrow.Size = UDim2.fromOffset(190, 220)
arrow.SizeOffset = Vector2.new(0, 0.5)
arrow.AlwaysOnTop = true
arrow.LightInfluence = 0
arrow.MaxDistance = math.huge
arrow.Enabled = false
arrow.ResetOnSpawn = false
arrow.Adornee = anchor
arrow.Parent = playerGui -- a BillboardGui inside a ScreenGui never draws
local arrowHolder = Instance.new("Frame")
arrowHolder.BackgroundTransparency = 1
arrowHolder.AnchorPoint = Vector2.new(0.5, 1)
arrowHolder.Size = UDim2.fromOffset(170, 190)
arrowHolder.Position = UDim2.fromScale(0.5, 1)
arrowHolder.Parent = arrow
local arrowScale = Instance.new("UIScale")
arrowScale.Parent = arrowHolder
local arrowBars = chevron(arrowHolder, UDim.new(0, 92), 25, 78, 24, 1)
for _, bar in chevron(arrowHolder, UDim.new(0, 146), 25, 78, 24, 1) do
	table.insert(arrowBars, bar)
end
local arrowText = label(arrowHolder, "", 38, BOLD, WHITE)
arrowText.Size = UDim2.new(1, 0, 0, 46)
Style.outline(arrowText, 3)

-- the same arrow pinned to the edge of the screen when the target is out of view, with how far it is
local edge = Instance.new("Frame")
edge.Name = "EdgePointer"
edge.BackgroundTransparency = 1
edge.AnchorPoint = Vector2.new(0.5, 0.5)
edge.Size = UDim2.fromOffset(150, 150)
edge.Visible = false
edge.ZIndex = Z_ARROW
edge.Parent = gui
local edgeTurn = Instance.new("Frame")
edgeTurn.BackgroundTransparency = 1
edgeTurn.AnchorPoint = Vector2.new(0.5, 0.5)
edgeTurn.Position = UDim2.fromScale(0.5, 0.5)
edgeTurn.Size = UDim2.fromScale(1, 1)
edgeTurn.ZIndex = Z_ARROW
edgeTurn.Parent = edge
local edgeBars = chevron(edgeTurn, UDim.new(0.5, 10), 28, 88, 26, Z_ARROW)
local edgeScale = Instance.new("UIScale")
edgeScale.Scale = Callouts.EdgeScale
edgeScale.Parent = edgeTurn
local edgeText = label(edge, "", Callouts.EdgeTextSize, BOLD, WHITE)
edgeText.AnchorPoint = Vector2.new(0.5, 0.5)
edgeText.Position = UDim2.fromScale(0.5, 0.5)
edgeText.Size = UDim2.fromOffset(170, 24)
edgeText.ZIndex = Z_ARROW + 1
Style.outline(edgeText, 2)

-- the arrow at a button or sign to press
local press = Instance.new("Frame")
press.Name = "PressArrow"
press.BackgroundTransparency = 1
press.AnchorPoint = Vector2.new(0.5, 0.5)
press.Size = UDim2.fromOffset(90, 80)
press.Visible = false
press.ZIndex = Z_ARROW
press.Parent = gui
paint(chevron(press, UDim.new(0.5, 0), 17, 56, 18, Z_ARROW), GOLD)

---------------------------------------------------------------- tips and celebrations

-- tips share the hint line above the speedometer (the Hud hides its key hint while a tip shows):
-- an asphalt strip with a yellow edge line and a yellow TIP tag
local tipBox = Style.panel(gui)
tipBox.Name = "Tip"
tipBox.AnchorPoint = Vector2.new(0.5, 1)
tipBox.Position = UDim2.new(0.5, 0, 1, -96)
tipBox.Size = UDim2.fromOffset(600, 62)
tipBox.Visible = false
local tipEdge = Instance.new("Frame")
tipEdge.BackgroundColor3 = GOLD
tipEdge.BorderSizePixel = 0
tipEdge.AnchorPoint = Vector2.new(0, 1)
tipEdge.Position = UDim2.fromScale(0, 1)
tipEdge.Size = UDim2.new(1, 0, 0, 3)
tipEdge.Parent = tipBox
local tipPill = Style.pill(tipBox, "TIP", GOLD)
tipPill.AnchorPoint = Vector2.new(0, 0.5)
tipPill.Position = UDim2.new(0, 12, 0.5, 0)
local tip = label(tipBox, "", 14, F.bold, WHITE)
tip.Position = UDim2.fromOffset(58, 0)
tip.Size = UDim2.new(1, -70, 1, -3)
tip.TextWrapped = true
tip.TextXAlignment = Enum.TextXAlignment.Left
local tipToken = 0

local function showTip(text: string)
	tipToken += 1
	local mine = tipToken
	tip.Text = text
	tipBox.Visible = true
	task.delay(7, function()
		if tipToken == mine then
			tipBox.Visible = false
		end
	end)
end

local cheer = Instance.new("Sound")
cheer.SoundId = "rbxasset://sounds/electronicpingshort.wav"
cheer.Volume = 0.8
cheer.Parent = gui

local function celebrate(title: string, subtitle: string)
	cheer:Play()
	local t = label(gui, title, Callouts.CheerSize, BOLD, GOLD)
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.new(0.5, 0, 0, Callouts.CheerTop)
	t.Size = UDim2.fromOffset(760, Callouts.CheerSize + 10)
	t.Rotation = -4
	Style.outline(t, 3)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = t
	-- the subtitle on a black paint strip
	local s = label(gui, subtitle, Callouts.CheerSubSize, F.heavy, WHITE)
	s.BackgroundColor3 = INK
	s.BackgroundTransparency = 0
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Position = UDim2.new(0.5, 0, 0, Callouts.CheerTop + math.floor(Callouts.CheerSize * 0.95))
	Style.fitText(s, 16, 5)
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	-- confetti from the top of the screen
	for _ = 1, 70 do
		local c = Instance.new("Frame")
		c.BorderSizePixel = 0
		c.BackgroundColor3 = CONFETTI[math.random(1, #CONFETTI)]
		c.Size = UDim2.fromOffset(math.random(6, 12), math.random(10, 18))
		c.Position = UDim2.new(math.random(), 0, 0, -20)
		c.Rotation = math.random(0, 360)
		c.Parent = gui
		local fall = TweenService:Create(
			c,
			TweenInfo.new(math.random(18, 32) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.fromScale(c.Position.X.Scale + (math.random() - 0.5) * 0.3, 1.1),
				Rotation = c.Rotation + math.random(-540, 540),
			}
		)
		fall:Play()
		fall.Completed:Once(function()
			c:Destroy()
		end)
	end
	task.delay(3.2, function()
		for _, l in { t, s } do
			TweenService
				:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
				:Play()
		end
		task.delay(0.6, function()
			t:Destroy()
			s:Destroy()
		end)
	end)
end

---------------------------------------------------------------- state

local function nearestPedestrian(from: Vector3): BasePart?
	local npcs = workspace:FindFirstChild("Npcs")
	if not npcs then
		return nil
	end
	local best, bestD = nil, 500
	for _, npc in npcs:GetChildren() do
		local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and not npc:GetAttribute("Down") then
			local d = (root.Position - from).Magnitude
			if d < bestD then
				best, bestD = root, d
			end
		end
	end
	return best
end

-- the jump ramp nearest the player, kept unless another is clearly closer so the marker doesn't flip
local function nearestRamp(from: Vector3, current: BasePart?): BasePart?
	local best, bestD = nil, math.huge
	for _, r in CollectionService:GetTagged("JumpRamp") do
		if r:IsA("BasePart") then
			local d = (r.Position - from).Magnitude
			if r == current then
				d *= 0.7
			end
			if d < bestD then
				best, bestD = r, d
			end
		end
	end
	return best
end

-- the building nearest the player: its centre and roof line, measured once
type Spot = { centre: Vector3, top: number }
local spots: { Spot }? = nil
local function buildingSpots(): { Spot }
	if spots then
		return spots
	end
	local found = {}
	local map = workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("Buildings")
	if folder then
		for _, b in folder:GetChildren() do
			if b:IsA("Model") then
				local cf, size = b:GetBoundingBox()
				if size.Y >= Onboarding.SmashMinHeight then
					table.insert(found, { centre = cf.Position, top = cf.Position.Y + size.Y / 2 })
				end
			end
		end
		spots = found
	end
	return found
end

local function nearestBuilding(from: Vector3, current: Spot?): Spot?
	local best, bestD = nil, math.huge
	for _, s in buildingSpots() do
		local d = (s.centre - from).Magnitude
		if s == current then
			d *= 0.7
		end
		if d < bestD then
			best, bestD = s, d
		end
	end
	return best
end

-- the cheapest car you don't own yet, at the price the garage shows
local function cheapestCar(): (Vehicles.Vehicle?, number)
	local owned = "," .. ((player:GetAttribute("Owned") or "") :: string) .. ","
	local today = player:GetAttribute("CarOfDay")
	local best, bestPrice = nil, math.huge
	for _, v in Vehicles.List do
		if v.price > 0 and not string.find(owned, "," .. v.id .. ",", 1, true) then
			local price = DailyRules.price(
				v.id,
				v.price,
				if typeof(today) == "string" and today ~= "" then today else nil,
				DailyConfig.DiscountShare,
				DailyConfig.DiscountRound
			)
			if price < bestPrice then
				best, bestPrice = v, price
			end
		end
	end
	return best, bestPrice
end

local function eventOf(key: unknown): EventConfig.Event?
	for _, e in EventConfig.List do
		if e.key == key then
			return e
		end
	end
	return nil
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local stepStarted = os.clock()
local stepEntered = os.clock()
local lastStep = -1
local lastCount = 0
local tipsShown: { [string]: boolean } = {}
local lastVehicle = ""
local rampTarget: BasePart? = nil
local buildingTarget: Spot? = nil
local scrolled = false -- the buy arrow's card was brought into view this time the garage opened

type Target = {
	at: Vector3, -- where the marker's tip goes
	text: string,
	color: Color3,
	beacon: Vector3?, -- ground point of the light column
}

-- the marker, the column and the edge pointer for this frame's target (nil hides them)
local function showTarget(target: Target?, root: BasePart?)
	local cam = workspace.CurrentCamera
	if not (target and root and cam) then
		arrow.Enabled = false
		edge.Visible = false
		beacon.Parent = nil
		anchor.Parent = nil
		return
	end
	local t = os.clock()
	anchor.Position = target.at
	anchor.Parent = workspace
	arrow.Enabled = true
	paint(arrowBars, target.color)
	arrowText.Text = target.text
	arrowHolder.Position = UDim2.new(0.5, 0, 1, (-14 + math.sin(t * 6) * 14) * Callouts.ArrowScale)
	arrowScale.Scale = Callouts.ArrowScale
		* math.clamp(cam.ViewportSize.Y / 720, 0.6, 1)
		* (1 + 0.06 * math.sin(t * 6))
	if target.beacon then
		beacon.Color = target.color
		beacon.CFrame = CFrame.new(target.beacon + Vector3.new(0, Onboarding.BeaconHeight / 2, 0))
			* CFrame.Angles(0, 0, math.pi / 2)
		-- thin it out once you're on top of it
		local near = (target.beacon - root.Position).Magnitude < Onboarding.BeaconNear
		beacon.Transparency = if near then 0.85 else 0.45 + 0.1 * math.sin(t * 4)
		beacon.Parent = workspace
	else
		beacon.Parent = nil
	end
	local p = cam:WorldToScreenPoint(target.at)
	local k = Style.scale()
	local size = gui.AbsoluteSize / k
	local e = Rules.edgePoint(p.X / k, p.Y / k, p.Z, size.X, size.Y, Onboarding.EdgeMargins)
	edge.Visible = not e.onScreen
	if edge.Visible then
		edge.Position = UDim2.fromOffset(e.x, e.y)
		edgeTurn.Rotation = e.angle
		-- the label sits on the screen side of the arrow, clear of its tip
		local away = math.rad(e.angle + 90)
		local gap = Callouts.EdgeTextGap
		edgeText.Position = UDim2.new(0.5, -math.cos(away) * gap, 0.5, -math.sin(away) * gap)
		paint(edgeBars, target.color)
		local metres = (target.at - root.Position).Magnitude / Vehicles.StudsPerMetre
		edgeText.Text = `{target.text} {math.floor(metres)}M`
	end
end

-- the arrow at a button; under it when the button is in the top half of the screen, over it otherwise
local function showPress(target: GuiObject?)
	if not (target and target.Visible and target.AbsoluteSize.X > 0) then
		press.Visible = false
		return
	end
	local k = Style.scale()
	local at, s = target.AbsolutePosition / k, target.AbsoluteSize / k
	local under = at.Y + s.Y / 2 < gui.AbsoluteSize.Y / k / 2
	local bob = math.sin(os.clock() * 7) * 9
	press.Visible = true
	press.Rotation = if under then 180 else 0
	press.Position =
		UDim2.fromOffset(at.X + s.X / 2, if under then at.Y + s.Y + 46 + bob else at.Y - 46 - bob)
end

-- a ScrollingFrame scrolls so a card button further down its list is on screen
local function bringIntoView(button: GuiObject)
	local list = button:FindFirstAncestorOfClass("ScrollingFrame")
	if not list then
		return
	end
	local over = button.AbsolutePosition.Y
		+ button.AbsoluteSize.Y
		- (list.AbsolutePosition.Y + list.AbsoluteSize.Y)
	if over > 0 then
		list.CanvasPosition += Vector2.new(0, over / Style.scale() + 40)
	end
end

local function glow(target: GuiObject?, on: boolean)
	if not target then
		return
	end
	local s = target:FindFirstChild("GuideGlow") :: UIStroke?
	if on and not s then
		s = Instance.new("UIStroke")
		s.Name = "GuideGlow"
		s.Color = GOLD
		s.Thickness = 3
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = target
	end
	if s then
		s.Enabled = on
		s.Transparency = 0.5 + 0.5 * math.sin(os.clock() * 6)
	end
end

local function vehicleTips(id: string)
	local v = Vehicles.ById[id]
	if not v or tipsShown[id] then
		return
	end
	tipsShown[id] = true
	local touch = UserInputService.TouchEnabled
	local text: string? = nil
	if Vehicles.has(v, "Jet") then
		text = if touch
			then "Hold FLY to jet upward; let go and you drop. Steer as normal; hold ROLL L/R to roll, hold BOOST for the rear jet."
			else "Hold SHIFT to jet upward; let go and you drop. A/D steer, S jets backwards, hold Q/E to roll, hold R for the rear jet."
	elseif Vehicles.has(v, "Thruster") then
		text = if touch then "Tap BOOST for a thruster burst." else "Press R for a thruster burst."
	elseif Vehicles.has(v, "Taxi") then
		text = if touch
			then "Tap HORN to yell TAXI! Someone will come running..."
			else "Press G to yell TAXI! Someone will come running..."
	elseif Vehicles.has(v, "Jingle") then
		text = if touch
			then "Tap JINGLE to turn the tune on or off. While it plays, everyone wants ice cream."
			else "Press G to turn the jingle on or off. While it plays, everyone wants ice cream."
	elseif Vehicles.has(v, "Cannon") then
		text = if touch
			then "Hold WATER to blast people off their feet. It sprays where the camera looks."
			else "Aim with the mouse, hold the left button (or G) to blast people off their feet."
	end
	if text then
		showTip(text)
	end
end

local function update()
	local hud = playerGui:FindFirstChild("Hud")
	local garageButton = hud and hud:FindFirstChild("GarageButton", true) :: GuiObject?
	local goalsButton = hud and hud:FindFirstChild("GoalsButton", true) :: GuiObject?
	local garage = hud and hud:FindFirstChild("Garage") :: GuiObject?
	local store = hud and hud:FindFirstChild("Store") :: GuiObject?
	local goalsGui = playerGui:FindFirstChild("Goals")
	local sheet = goalsGui and goalsGui:FindFirstChild("GoalsSheet") :: GuiObject?
	local garageOpen = garage ~= nil and garage.Visible
	local sheetOpen = sheet ~= nil and sheet.Visible
	-- the tip sits just above the speedometer when it shows, like the Hud's key hint
	local dash = hud and hud:FindFirstChild("Speedometer") :: GuiObject?
	local dashH = if dash and dash.Visible then dash.Size.Y.Offset else 0
	tipBox.Position = UDim2.new(0.5, 0, 1, -(18 + dashH + 14))
	local stepValue = (player:GetAttribute("Tutorial") or Steps.Done) :: number
	if not player:GetAttribute("DataReady") then
		card.Visible = false
		return
	end
	if stepValue ~= lastStep then
		lastStep = stepValue
		stepStarted = os.clock()
		stepEntered = stepStarted
	end
	local count = (player:GetAttribute("TutorialCount") or 0) :: number
	if count ~= lastCount then
		lastCount = count
		stepStarted = os.clock()
	end
	local stuck = os.clock() - stepStarted > Onboarding.HintAfter
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local touch = UserInputService.TouchEnabled
	local driving = Drive.state.driving

	card.Visible = true
	hintText.Visible = false
	local target: Target? = nil
	local pressTarget: GuiObject? = nil
	local glowGarage, glowGoals = false, false
	local glowCard: string? = nil
	stroke.Transparency = 0.4 + 0.4 * math.sin(os.clock() * 5)
	skip.Visible = Rules.canSkip(stepValue, Onboarding)
		and os.clock() - stepEntered > Onboarding.SkipAfter

	-- the steps played from the car: without one, back to the garage
	local function needCar(): boolean
		if driving then
			return false
		end
		glowGarage = true
		pressTarget = garageButton
		hintText.Text = "Spawn your car from the GARAGE"
		hintText.Visible = true
		return true
	end

	if stepValue == Steps.Spawn then
		goalText.Text = "Spawn your Hatchback from the GARAGE"
		barFill.Size = UDim2.fromScale(0, 1)
		glowGarage = true
		glowCard = Vehicles.Starter
		if not garageOpen then
			pressTarget = garageButton
		end
		if stuck then
			hintText.Text = "Tap GARAGE at the top left, then SPAWN"
			hintText.Visible = true
		end
	elseif stepValue == Steps.Hits then
		goalText.Text = `Run over {Onboarding.HitsGoal} people!   {count} / {Onboarding.HitsGoal}`
		barFill.Size = UDim2.fromScale(math.clamp(count / Onboarding.HitsGoal, 0, 1), 1)
		local ped = root and nearestPedestrian(root.Position)
		if ped then
			target = { at = ped.Position + Vector3.new(0, 5, 0), text = "HIT!", color = C.red }
		end
		if not driving then
			glowGarage = true
			hintText.Text = "Spawn your car from the GARAGE"
			hintText.Visible = stuck
		elseif stuck then
			hintText.Text = if touch
				then "Use the thumbstick to drive at the arrow"
				else "Hold W to drive, A/D to steer. Aim for the arrow!"
			hintText.Visible = true
		end
	elseif stepValue == Steps.Ramp then
		goalText.Text = "Take a RAMP and land the jump!"
		barFill.Size = UDim2.fromScale(0, 1)
		if root then
			rampTarget = nearestRamp(root.Position, rampTarget)
			local ramp = rampTarget
			if ramp then
				-- the foot of the ramp: its low end, where you drive on
				local foot = ramp.Position
					+ ramp.CFrame.LookVector * (ramp.Size.Z / 2)
					- Vector3.new(0, ramp.Size.Y / 2, 0)
				target = {
					at = foot + Vector3.new(0, 8, 0),
					text = "RAMP",
					color = C.orange,
					beacon = foot,
				}
			end
		end
		if not needCar() and stuck then
			hintText.Text = "Follow the beam, then drive up the ramp as fast as you can"
			hintText.Visible = true
		end
	elseif stepValue == Steps.Smash then
		goalText.Text =
			`Smash a building!   {math.min(count, Onboarding.SmashGoal)} / {Onboarding.SmashGoal} pieces`
		barFill.Size = UDim2.fromScale(math.clamp(count / Onboarding.SmashGoal, 0, 1), 1)
		if root then
			buildingTarget = nearestBuilding(root.Position, buildingTarget)
			local b = buildingTarget
			if b then
				target = {
					at = Vector3.new(b.centre.X, b.top + 4, b.centre.Z),
					text = "SMASH",
					color = C.pink,
					beacon = Vector3.new(b.centre.X, b.centre.Y, b.centre.Z),
				}
			end
		end
		if not needCar() and stuck then
			hintText.Text = "Hit the walls at full speed"
			hintText.Visible = true
		end
	elseif stepValue == Steps.Goal then
		goalText.Text = `Open GOALS and claim your first ${Onboarding.Rewards[Steps.Goal]}`
		barFill.Size = UDim2.fromScale(0, 1)
		if sheetOpen then
			pressTarget = goalsGui and goalsGui:FindFirstChild("TutorialClaim", true) :: GuiObject?
		else
			glowGoals = true
			pressTarget = goalsButton
		end
	elseif stepValue == Steps.Buy then
		local car, price = cheapestCar()
		local cash = (player:GetAttribute("Money") or 0) :: number
		if not car then
			goalText.Text = "Buy a new ride from the GARAGE"
			barFill.Size = UDim2.fromScale(0, 1)
		elseif cash >= price then
			goalText.Text = `Buy your next ride: {car.name} for {Style.money(price)}`
			barFill.Size = UDim2.fromScale(1, 1)
		else
			goalText.Text =
				`Save up for the {car.name}:  {Style.money(cash)} / {Style.money(price)}`
			barFill.Size = UDim2.fromScale(math.clamp(cash / price, 0, 1), 1)
			hintText.Text = "Keep hitting people for cash, or SKIP this for now"
			hintText.Visible = stuck
		end
		if car and cash >= price then
			if garageOpen then
				glowCard = car.id
			else
				glowGarage = true
				pressTarget = garageButton
			end
		end
	elseif stepValue == Steps.Event then
		local phase = workspace:GetAttribute("EventPhase")
		local event = eventOf(workspace:GetAttribute("EventKey"))
		local endsAt = workspace:GetAttribute("EventEndsAt")
		local left = if typeof(endsAt) == "number" then endsAt - workspace:GetServerTimeNow() else 0
		local waited = os.clock() - stepEntered
		if phase == "live" and event then
			goalText.Text = `{event.title} is LIVE! Hit, smash or jump to join`
			barFill.Size = UDim2.fromScale(1, 1)
		elseif phase == "warn" and event then
			goalText.Text = `{event.title} starts in {clock(left)}. Get ready!`
			barFill.Size = UDim2.fromScale(1 - math.clamp(left / EventConfig.WarnSeconds, 0, 1), 1)
		else
			goalText.Text =
				`Events show up here. Next one in {clock(left + EventConfig.WarnSeconds)}`
			barFill.Size = UDim2.fromScale(math.clamp(waited / Onboarding.EventWait, 0, 1), 1)
		end
		local signs = playerGui:FindFirstChild("EventBanner")
		local sign = signs and signs:FindFirstChild("Sign") :: GuiObject?
		local chip = signs and signs:FindFirstChild("EventChip") :: GuiObject?
		pressTarget = if chip and chip.Visible then chip else sign
	else
		-- the tutorial is over: the pinned goals take this spot
		card.Visible = false
	end

	-- sheets cover the card's corner and the world markers would only clutter them
	local storeOpen = store ~= nil and store.Visible
	if sheetOpen then
		card.Visible = false
	end
	if garageOpen or storeOpen or sheetOpen then
		target = nil
	end
	-- the nudge sits where the garage/store sheet opens: keep it out of the way while one is open
	if garageOpen or storeOpen then
		hintText.Visible = false
	end
	glow(garageButton, glowGarage and not garageOpen)
	glow(goalsButton, glowGoals and not sheetOpen)
	if garage then
		if not garageOpen then
			scrolled = false
		end
		for _, c in garage:GetDescendants() do
			if c:IsA("TextButton") and c.Name == "Action" then
				local cardFrame = c.Parent
				local mine = garageOpen
					and glowCard ~= nil
					and cardFrame ~= nil
					and cardFrame.Name == glowCard
				glow(c, mine)
				if mine and (stepValue == Steps.Buy or stepValue == Steps.Spawn) then
					if not scrolled then
						scrolled = true
						bringIntoView(c)
					end
					pressTarget = c
				end
			end
		end
	end
	showTarget(target, root)
	showPress(pressTarget)

	local id = Drive.state.vehicleId
	if Drive.state.driving and id ~= lastVehicle then
		lastVehicle = id
		vehicleTips(id)
	elseif not Drive.state.driving then
		lastVehicle = ""
	end
end

function Guide.start()
	Net.waitFor("Celebrate").OnClientEvent:Connect(celebrate)
	Style.onTap(skip, function()
		skip.Visible = false
		stepEntered = os.clock()
		Net.waitFor("TutorialSkip"):FireServer(player:GetAttribute("Tutorial"))
	end)
	RunService.RenderStepped:Connect(update)
end

return Guide
