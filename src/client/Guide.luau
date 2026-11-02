--!strict
-- First-session guidance and goals: the goal card under the menu strip (spawn → run over 3 → next ride),
-- a bouncing arrow over the nearest pedestrian, glowing GARAGE button, timed hints for stuck players,
-- one-time tips when you first drive a vehicle with a feature, and the confetti moment.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
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
local corner = Style.corner
local label = Style.label
local money = Style.money

local gui = Instance.new("ScreenGui")
gui.Name = "Guide"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui

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

---------------------------------------------------------------- arrow over the nearest pedestrian

local arrow = Instance.new("BillboardGui")
arrow.Name = "GuideArrow"
arrow.Size = UDim2.fromOffset(60, 60)
arrow.StudsOffset = Vector3.new(0, 5, 0)
arrow.AlwaysOnTop = true
arrow.Enabled = false
arrow.ResetOnSpawn = false
arrow.Parent = playerGui -- a BillboardGui inside a ScreenGui never draws
-- a chevron from two bars (font glyphs like ▼ don't draw)
for _, side in { -1, 1 } do
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.new(0.5, side * 11, 0.45, 0)
	bar.Size = UDim2.fromOffset(34, 10)
	bar.Rotation = side * -45
	bar.BackgroundColor3 = GOLD
	bar.BorderSizePixel = 0
	bar.Parent = arrow
	corner(bar, 5)
	local edge = Instance.new("UIStroke")
	edge.Color = INK
	edge.Thickness = 2
	edge.Parent = bar
end

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
	local t = label(gui, title, 58, BOLD, GOLD)
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.36)
	t.Size = UDim2.fromOffset(760, 68)
	t.Rotation = -4
	Style.outline(t, 4)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = t
	-- the subtitle on a black paint strip
	local s = label(gui, subtitle, 18, F.heavy, WHITE)
	s.BackgroundColor3 = INK
	s.BackgroundTransparency = 0
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Position = UDim2.new(0.5, 0, 0.36, 54)
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

local function owns(id: string): boolean
	return string.find(
		"," .. ((player:GetAttribute("Owned") or "") :: string) .. ",",
		"," .. id .. ",",
		1,
		true
	) ~= nil
end

-- the cheapest vehicle you don't have yet
local function nextRide(): Vehicles.Vehicle?
	local best: Vehicles.Vehicle? = nil
	for _, v in Vehicles.List do
		if not owns(v.id) and (best == nil or v.price < best.price) then
			best = v
		end
	end
	return best
end

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

local stepStarted = os.clock()
local lastStep = -1
local lastHits = 0
local tipsShown: { [string]: boolean } = {}
local lastVehicle = ""

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
			then "Tap HORN to play the jingle. Everyone wants ice cream."
			else "Press G to play the jingle. Everyone wants ice cream."
	elseif Vehicles.has(v, "Cannon") then
		text = if touch
			then "Hold WATER to blast people off their feet."
			else "Hold G to blast people off their feet with the water cannon."
	end
	if v.breaksBuildings then
		text = (if text then text .. "  " else "") .. "This one smashes through buildings!"
	end
	if text then
		showTip(text)
	end
end

local function update()
	local hud = playerGui:FindFirstChild("Hud")
	local garageButton = hud and hud:FindFirstChild("GarageButton", true) :: GuiObject?
	local garage = hud and hud:FindFirstChild("Garage") :: GuiObject?
	-- the tip sits just above the speedometer when it shows, like the Hud's key hint
	local dash = hud and hud:FindFirstChild("Speedometer") :: GuiObject?
	local dashH = if dash and dash.Visible then dash.AbsoluteSize.Y else 0
	tipBox.Position = UDim2.new(0.5, 0, 1, -(18 + dashH + 14))
	local stepValue = (player:GetAttribute("Tutorial") or Steps.Done) :: number
	if not player:GetAttribute("DataReady") then
		card.Visible = false
		return
	end
	if stepValue ~= lastStep then
		lastStep = stepValue
		stepStarted = os.clock()
	end
	local hits = (player:GetAttribute("TutorialHits") or 0) :: number
	if hits ~= lastHits then
		lastHits = hits
		stepStarted = os.clock()
	end
	local stuck = os.clock() - stepStarted > Onboarding.HintAfter
	local cash = (player:GetAttribute("Money") or 0) :: number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local touch = UserInputService.TouchEnabled

	card.Visible = true
	hintText.Visible = false
	arrow.Enabled = false
	local glowGarage = false
	local glowCard: string? = nil
	stroke.Transparency = 1

	local tutorial = stepValue == Steps.Spawn or stepValue == Steps.Hits
	tag.Text = if tutorial then "TUTORIAL" else "NEXT RIDE"
	tag.BackgroundColor3 = if tutorial then GOLD else MONEY
	cardStripe.BackgroundColor3 = tag.BackgroundColor3
	if stepValue == Steps.Spawn then
		goalText.Text = "Spawn your Hatchback from the GARAGE"
		barFill.Size = UDim2.fromScale(0, 1)
		glowGarage = true
		glowCard = Vehicles.Starter
		stroke.Transparency = 0.4 + 0.4 * math.sin(os.clock() * 5)
		if stuck then
			hintText.Text = "Tap GARAGE at the top left, then SPAWN"
			hintText.Visible = true
		end
	elseif stepValue == Steps.Hits then
		goalText.Text = `Run over {Onboarding.HitsGoal} people!   {hits} / {Onboarding.HitsGoal}`
		barFill.Size = UDim2.fromScale(math.clamp(hits / Onboarding.HitsGoal, 0, 1), 1)
		stroke.Transparency = 0.4 + 0.4 * math.sin(os.clock() * 5)
		if root then
			local target = nearestPedestrian(root.Position)
			if target then
				arrow.Adornee = target
				arrow.StudsOffset = Vector3.new(0, 5 + math.sin(os.clock() * 6) * 0.8, 0)
				arrow.Enabled = true
			end
		end
		if not Drive.state.driving then
			glowGarage = true
			hintText.Text = "Spawn your car from the GARAGE"
			hintText.Visible = stuck
		elseif stuck then
			hintText.Text = if touch
				then "Use the thumbstick to drive at the arrow"
				else "Hold W to drive, A/D to steer. Aim for the arrow!"
			hintText.Visible = true
		end
	else
		local v = nextRide()
		if v then
			local ready = cash >= v.price
			goalText.Text = if ready
				then `Buy the {v.name} in the GARAGE!`
				else `{v.name}   {money(cash)} / {money(v.price)}`
			barFill.Size = UDim2.fromScale(math.clamp(cash / math.max(v.price, 1), 0, 1), 1)
			if ready then
				glowGarage = true
				glowCard = v.id
				stroke.Transparency = 0.4 + 0.4 * math.sin(os.clock() * 5)
			end
		else
			card.Visible = false
		end
	end

	glow(garageButton, glowGarage and not (garage and garage.Visible))
	-- the nudge sits where the garage/store sheet opens: keep it out of the way while one is open
	local store = hud and hud:FindFirstChild("Store") :: GuiObject?
	if (garage and garage.Visible) or (store and store.Visible) then
		hintText.Visible = false
	end
	if garage then
		for _, c in garage:GetDescendants() do
			if c:IsA("TextButton") and c.Name == "Action" then
				local cardFrame = c.Parent
				glow(
					c,
					garage.Visible
						and glowCard ~= nil
						and cardFrame ~= nil
						and cardFrame.Name == glowCard
				)
			end
		end
	end

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
	local wreckerTipped = false
	player:GetAttributeChangedSignal("PassWrecker"):Connect(function()
		if player:GetAttribute("PassWrecker") == true and not wreckerTipped then
			wreckerTipped = true
			showTip(
				if UserInputService.TouchEnabled
					then "Wrecker: drive into players to launch them. Hold BOMB to self-destruct."
					else "Wrecker: drive into players to launch them. Hold X to self-destruct."
			)
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return Guide
