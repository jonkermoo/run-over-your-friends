--!strict
-- First-session guidance: the job card under the menu strip (spawn, run over 3, smash, first goal, buy, event;
-- after that the pinned goals sit there, PinnedGoals), a big bouncing marker over the target with a light
-- column and an off-screen edge pointer, an arrow at the button to press, timed hints for stuck players, the
-- first goal's big CLAIM pop-up, one-time tips when you first drive a vehicle with a feature, and the confetti moment.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Callouts = require(ReplicatedStorage.Shared.Config.Callouts)
local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local DailyRules = require(ReplicatedStorage.Shared.Rules.Daily)
local EventConfig = require(ReplicatedStorage.Shared.Config.Events)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Rules = require(ReplicatedStorage.Shared.Rules.Onboarding)
local Clear = require(ReplicatedStorage.Shared.Rules.Clear)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Drive = require(script.Parent.Drive)
local Pad = require(script.Parent.Pad)
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
local CARD_TOP, HINT_TOP = 68, 146 -- layout px under the menu strip
card.Position = UDim2.fromOffset(14, CARD_TOP)
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
hintText.Position = UDim2.fromOffset(18, HINT_TOP)
hintText.Size = UDim2.fromOffset(420, 22)
hintText.TextXAlignment = Enum.TextXAlignment.Left
Style.outline(hintText, 2)
hintText.Visible = false

---------------------------------------------------------------- first goal's CLAIM pop-up

-- shown the moment the first goal is done (player attribute "TutorialClaim"); the bar runs down to the
-- server's own claim (Config/Onboarding ClaimAutoAfter), so leaving it alone claims it too. That is also the
-- gamepad's way: selecting the button would take A away from driving mid-run
local claimBox = Style.panel(gui)
claimBox.Name = "FirstGoalClaim"
claimBox.AnchorPoint = Vector2.new(0.5, 0.5)
claimBox.Position = UDim2.fromScale(0.5, 0.42)
claimBox.Size = UDim2.fromOffset(440, 196)
claimBox.ZIndex = 20
claimBox.Visible = false
Style.stroke(claimBox, GOLD, 4, 0)
local claimScale = Instance.new("UIScale")
claimScale.Parent = claimBox
local claimTitle = label(claimBox, "FIRST GOAL DONE!", 30, BOLD, GOLD)
claimTitle.Position = UDim2.fromOffset(0, 12)
claimTitle.Size = UDim2.new(1, 0, 0, 36)
claimTitle.ZIndex = 21
Style.outline(claimTitle, 2)
local claimSub = label(claimBox, "", 16, F.heavy, WHITE)
claimSub.Position = UDim2.fromOffset(0, 50)
claimSub.Size = UDim2.new(1, 0, 0, 22)
claimSub.ZIndex = 21
local claimButton = Style.button(
	claimBox,
	Loc.text("ClaimReward", { n = Onboarding.Rewards[Steps.Goal] }),
	"green",
	28
)
claimButton.AutoLocalize = false
claimButton.Name = "TutorialClaim"
claimButton.AnchorPoint = Vector2.new(0.5, 0)
claimButton.Position = UDim2.new(0.5, 0, 0, 84)
claimButton.Size = UDim2.fromOffset(280, 72)
claimButton.ZIndex = 21
local claimBack, claimFill = Style.bar(claimBox, GOLD)
claimBack.Position = UDim2.fromOffset(50, 172)
claimBack.Size = UDim2.new(1, -100, 0, 6)
claimBack.ZIndex = 21
claimFill.ZIndex = 22
-- when it showed (0: not showing) and whether this one was pressed
local claimState = { shownAt = 0, sent = false }

---------------------------------------------------------------- markers

local Z_ARROW = 30 -- arrows sit above the sheets they point into

-- the block arrow pointing down (Config/Icons.Arrow, white so it takes the target's colour), centred on
-- `centre` in a square box `size` px wide; it turns about its middle
local function blockArrow(parent: Instance, centre: UDim2, size: number, z: number): ImageLabel
	local img = Style.image(parent, Icons.Arrow)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = centre
	img.Size = UDim2.fromOffset(size, size)
	img.ZIndex = z
	return img
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
-- its tip at the holder's bottom, under the words
local arrowImage = blockArrow(arrowHolder, UDim2.new(0.5, 0, 1, -64), 150, 1)
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
local edgeImage = blockArrow(edgeTurn, UDim2.new(0.5, 0, 0.5, 16), 116, Z_ARROW)
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
blockArrow(press, UDim2.fromScale(0.5, 0.5), 78, Z_ARROW).ImageColor3 = GOLD

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

-- a line in the player's language: English text (matched in the table) or a Loc.msg (src/shared/Loc)
local function say(l: TextLabel, text: string | Loc.Msg)
	l.AutoLocalize = false
	l.Text = Loc.resolve(text)
end

local function showTip(text: string)
	tipToken += 1
	local mine = tipToken
	say(tip, text)
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

local function showCelebrate(title: string | Loc.Msg, subtitle: string | Loc.Msg, plain: boolean?)
	cheer:Play()
	local t = label(gui, "", Callouts.CheerSize, BOLD, GOLD)
	say(t, title)
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.new(0.5, 0, 0, Callouts.CheerTop)
	t.Size = UDim2.fromOffset(760, Callouts.CheerSize + 10)
	t.Rotation = -4
	Style.outline(t, 3)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = t
	-- the subtitle on a black paint strip
	local s = label(gui, "", Callouts.CheerSubSize, F.heavy, WHITE)
	say(s, subtitle)
	s.BackgroundColor3 = INK
	s.BackgroundTransparency = 0
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Position = UDim2.new(0.5, 0, 0, Callouts.CheerTop + math.floor(Callouts.CheerSize * 0.95))
	Style.fitText(s, 16, 5)
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	-- confetti from the top of the screen (not for a plain banner, like a new tutorial step)
	for _ = 1, if plain then 0 else 70 do
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
	task.delay(Callouts.CheerHold - Callouts.CheerFade, function()
		for _, l in { t, s } do
			TweenService:Create(
				l,
				TweenInfo.new(Callouts.CheerFade),
				{ TextTransparency = 1, BackgroundTransparency = 1 }
			):Play()
		end
		task.delay(0.6, function()
			t:Destroy()
			s:Destroy()
		end)
	end)
end

-- waits its turn for the middle of the screen (Style.stage) so two moments never land at once
-- title, subtitle: English text or Loc.msg lines (the server sends either)
local function celebrate(title: string | Loc.Msg, subtitle: string | Loc.Msg)
	task.delay(Style.stage(Callouts.CheerHold), showCelebrate, title, subtitle)
end
Guide.celebrate = celebrate -- client/NewRide's cheer after the turntable

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

-- the building nearest the player: its centre and roof line, measured once
type Spot = { centre: Vector3, top: number }
-- measured again every few seconds: buildings stream in and out round the player
local spots: { Spot }? = nil
local spotsAt = -math.huge
local function buildingSpots(): { Spot }
	if spots and os.clock() - spotsAt < 5 then
		return spots
	end
	spotsAt = os.clock()
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

-- the first real step up: the cheapest car you don't own yet that costs at least the rookie-pay car (the
-- Sedan), at the price the garage shows. The Scooter and the Cart are cheaper but slower and weaker than the
-- free Hatchback, so they'd make a poor first buy; buying one still finishes the step.
local FIRST_BUY_MIN = (Vehicles.ById[Economy.RookieUntil] or { price = 0 }).price
local function cheapestCar(): (Vehicles.Vehicle?, number)
	local owned = "," .. ((player:GetAttribute("Owned") or "") :: string) .. ","
	local today = player:GetAttribute("CarOfDay")
	local best, bestPrice = nil, math.huge
	for _, v in Vehicles.List do
		if
			v.price >= math.max(FIRST_BUY_MIN, 1)
			and not string.find(owned, "," .. v.id .. ",", 1, true)
		then
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
	arrowImage.ImageColor3 = target.color
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
		-- off the controls card and the speedometer, sliding along the edge it's on
		local keep = Style.keepClear()
		for _, r in keep do
			r.x, r.y, r.w, r.h = r.x / k, r.y / k, r.w / k, r.h / k
		end
		local box = Onboarding.EdgeBox
		local ex, ey = Clear.slide(e.x, e.y, box, box, keep, size.X, size.Y, Onboarding.ClearGap)
		edge.Position = UDim2.fromOffset(ex, ey)
		edgeTurn.Rotation = e.angle
		-- the label sits on the screen side of the arrow, clear of its tip
		local away = math.rad(e.angle + 90)
		local gap = Callouts.EdgeTextGap
		edgeText.Position = UDim2.new(0.5, -math.cos(away) * gap, 0.5, -math.sin(away) * gap)
		edgeImage.ImageColor3 = target.color
		local metres = (target.at - root.Position).Magnitude / Vehicles.StudsPerMetre
		say(
			edgeText,
			Loc.msg("EdgeDistance", { text = Loc.src(target.text), m = math.floor(metres) })
		)
	end
end

-- the arrow at a button; under it when the button is in the top half of the screen, over it otherwise
-- fromSide: point in from the right (a button in a list row, whose text sits above and left of it)
local function showPress(target: GuiObject?, fromSide: boolean?)
	if not (target and target.Visible and target.AbsoluteSize.X > 0) then
		press.Visible = false
		return
	end
	local k = Style.scale()
	local at, s = target.AbsolutePosition / k, target.AbsoluteSize / k
	local under = at.Y + s.Y / 2 < gui.AbsoluteSize.Y / k / 2
	local bob = math.sin(os.clock() * 7) * 9
	press.Visible = true
	if fromSide and at.X + s.X + 92 < gui.AbsoluteSize.X / k then
		press.Rotation = 90 -- the down arrow turned to point left, at the button's right edge
		press.Position = UDim2.fromOffset(at.X + s.X + 46 + bob, at.Y + s.Y / 2)
		return
	end
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
	if Pad.console() then
		-- client/Drive's gamepad keys: B boost, X thruster, Y feature, LB/RB roll
		if Vehicles.has(v, "Jet") then
			text =
				"Hold B to jet upward; let go and you drop. Pull the stick back to jet backwards, hold LB/RB to roll, hold X for the rear jet."
		elseif Vehicles.has(v, "Thruster") then
			text = "Press X for a thruster burst."
		elseif Vehicles.has(v, "Taxi") then
			text = "Press Y to yell TAXI! Someone will come running..."
		elseif Vehicles.has(v, "Jingle") then
			text = "Press Y to turn the jingle on or off. While it plays, everyone wants ice cream."
		elseif Vehicles.has(v, "Cannon") then
			text = "Hold Y to blast people off their feet. It sprays where the camera looks."
		end
	elseif Vehicles.has(v, "Jet") then
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
		-- you're in the tutorial: the card's tag counts the steps, and each step opens with a banner
		local n, total = Rules.stepNumber(stepValue, Onboarding)
		say(
			tag,
			if n
				then Loc.msg("GuideStepTag", { n = tostring(n), total = tostring(total) })
				else "TUTORIAL"
		)
		local title = Onboarding.StepTitles[stepValue]
		if n and title then
			task.delay(
				Style.stage(Callouts.CheerHold),
				showCelebrate,
				Loc.msg("GuideStepBanner", { n = tostring(n), total = tostring(total) }),
				title,
				true
			)
		end
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
	local pressFromSide = false
	local glowGarage = false
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
		say(hintText, "Spawn your car from the GARAGE")
		hintText.Visible = true
		return true
	end

	if stepValue == Steps.Spawn then
		say(goalText, "Spawn your Hatchback from the GARAGE")
		barFill.Size = UDim2.fromScale(0, 1)
		glowGarage = true
		glowCard = Vehicles.Starter
		if not garageOpen then
			pressTarget = garageButton
		end
		if stuck then
			say(
				hintText,
				if Pad.console()
					then "Press D-pad right, pick GARAGE with A, then SPAWN"
					else "Tap GARAGE at the top left, then SPAWN"
			)
			hintText.Visible = true
		end
	elseif stepValue == Steps.Hits then
		say(goalText, Loc.msg("GuideHits", { goal = Onboarding.HitsGoal, n = count }))
		barFill.Size = UDim2.fromScale(math.clamp(count / Onboarding.HitsGoal, 0, 1), 1)
		local ped = root and nearestPedestrian(root.Position)
		if ped then
			target = { at = ped.Position + Vector3.new(0, 5, 0), text = "HIT!", color = C.red }
		end
		if not driving then
			glowGarage = true
			say(hintText, "Spawn your car from the GARAGE")
			hintText.Visible = stuck
		elseif stuck or count == 0 then
			-- you start in the car: how to drive shows from the start until the first hit
			say(
				hintText,
				if Pad.console()
					then "Hold RT to drive, steer with the left stick. Aim for the arrow!"
					elseif touch then "Use the thumbstick to drive at the arrow"
					else "Hold W to drive, A/D to steer. Aim for the arrow!"
			)
			hintText.Visible = true
		end
	elseif stepValue == Steps.Smash then
		say(
			goalText,
			Loc.msg(
				"GuideSmash",
				{ n = math.min(count, Onboarding.SmashGoal), goal = Onboarding.SmashGoal }
			)
		)
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
			say(hintText, "Hit the walls at full speed")
			hintText.Visible = true
		end
	elseif stepValue == Steps.Goal then
		local n = math.min(count, Onboarding.GoalHits)
		say(goalText, Loc.msg("GuideFirstGoal", { goal = Onboarding.GoalHits, n = n }))
		barFill.Size = UDim2.fromScale(n / Onboarding.GoalHits, 1)
		local ped = n < Onboarding.GoalHits and root and nearestPedestrian(root.Position)
		if ped then
			target = { at = ped.Position + Vector3.new(0, 5, 0), text = "HIT!", color = C.red }
		end
		if not needCar() and stuck then
			say(hintText, "Run over people to finish your first goal")
			hintText.Visible = true
		end
	elseif stepValue == Steps.Buy then
		local car, price = cheapestCar()
		local cash = (player:GetAttribute("Money") or 0) :: number
		if not car then
			say(goalText, "Buy a new ride from the GARAGE")
			barFill.Size = UDim2.fromScale(0, 1)
		elseif cash >= price then
			say(goalText, Loc.msg("GuideBuyNext", { car = car.name, price = Style.money(price) }))
			barFill.Size = UDim2.fromScale(1, 1)
		else
			say(
				goalText,
				Loc.msg(
					"GuideSaveUp",
					{ car = car.name, cash = Style.money(cash), price = Style.money(price) }
				)
			)
			barFill.Size = UDim2.fromScale(math.clamp(cash / price, 0, 1), 1)
			say(hintText, "Keep hitting people for cash, or SKIP this for now")
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
			say(goalText, Loc.msg("GuideEventLive", { event = Loc.src(event.title) }))
			barFill.Size = UDim2.fromScale(1, 1)
		elseif phase == "warn" and event then
			say(
				goalText,
				Loc.msg("GuideEventSoon", { event = Loc.src(event.title), time = clock(left) })
			)
			barFill.Size = UDim2.fromScale(1 - math.clamp(left / EventConfig.WarnSeconds, 0, 1), 1)
		else
			say(
				goalText,
				Loc.msg("GuideEventNext", { time = clock(left + EventConfig.WarnSeconds) })
			)
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

	-- the first goal's CLAIM pop-up: in from small when it shows, its bar running down to the auto-claim
	local claimReady = stepValue == Steps.Goal and player:GetAttribute("TutorialClaim") == true
	if not claimReady then
		claimState.shownAt, claimState.sent = 0, false
	elseif claimState.shownAt == 0 then
		claimState.shownAt = os.clock()
		say(claimSub, Loc.msg("FirstGoalSub", { goal = Onboarding.GoalHits }))
		claimScale.Scale = 0.3
		TweenService:Create(claimScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
		cheer:Play()
	end
	claimBox.Visible = claimReady and not claimState.sent
	if claimBox.Visible then
		local left = 1 - (os.clock() - claimState.shownAt) / Onboarding.ClaimAutoAfter
		claimFill.Size = UDim2.fromScale(math.clamp(left, 0, 1), 1)
		claimButton.Rotation = 2 * math.sin(os.clock() * 8)
		target = nil
		pressTarget = claimButton
		pressFromSide = true -- from above it would sit on the pop-up's title
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
	if garage then
		if not garageOpen then
			scrolled = false
		end
		for _, c in garage:GetDescendants() do
			if c:IsA("TextButton") and c.Name == "Action" then
				-- the vehicle's detail panel (client/Hud: a frame under Details named by its id)
				local id = c:GetAttribute("VehicleId")
				local detailList = garage:FindFirstChild("Details")
				local cardFrame = if typeof(id) == "string" and detailList
					then detailList:FindFirstChild(id) :: GuiObject?
					else nil
				local mine = garageOpen and glowCard ~= nil and cardFrame ~= nil and id == glowCard
				-- the garage shows one vehicle at a time: while another is shown, point at this one's row
				local shown = cardFrame ~= nil and cardFrame.Visible
				local rowList = garage:FindFirstChild("Rows", true)
				local row = if mine
						and not shown
						and rowList
					then rowList:FindFirstChild(id :: string) :: GuiObject?
					else nil
				glow(c, mine and shown)
				if mine and (stepValue == Steps.Buy or stepValue == Steps.Spawn) then
					local at = row or c
					if not scrolled then
						scrolled = true
						bringIntoView(at)
					end
					pressTarget = at
					pressFromSide = row ~= nil -- from the right: from above it would cover the row over it
				end
			end
		end
	end
	-- a card over the screen (the Starter Pack, the "need more money" card) has the player's attention: no
	-- arrow on top of it
	local upsell = hud and hud:FindFirstChild("Upsell") :: GuiObject?
	local starter = hud and hud:FindFirstChild("StarterCard") :: GuiObject?
	if (upsell and upsell.Visible) or (starter and starter.Visible) then
		pressTarget = nil
	end
	showTarget(target, root)
	showPress(pressTarget, pressFromSide)
	-- an arrow under a menu tab lands on the card: the card (and its hint) step down out of its way
	local drop = if press.Visible
			and (pressTarget == garageButton or pressTarget == goalsButton)
		then Onboarding.TabArrowDrop
		else 0
	card.Position = UDim2.fromOffset(14, CARD_TOP + drop)
	hintText.Position = UDim2.fromOffset(18, HINT_TOP + drop)

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
	Style.onTap(claimButton, function()
		claimState.sent = true
		claimBox.Visible = false
		Net.waitFor("TutorialClaim"):FireServer()
	end)
	local function skipStep()
		skip.Visible = false
		stepEntered = os.clock()
		Net.waitFor("TutorialSkip"):FireServer(player:GetAttribute("Tutorial"))
	end
	Style.onTap(skip, skipStep)
	Pad.press(skip, Enum.KeyCode.DPadDown, skipStep) -- gamepad: D-pad down while SKIP shows
	RunService.RenderStepped:Connect(update)
end

return Guide
