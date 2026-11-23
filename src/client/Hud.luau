--!strict
-- Screen UI: money and pop-ups, the speedometer with jet and thruster meters, the garage (3D previews,
-- stats, buy and spawn), the store (passes, group reward) and the phone driving buttons.
-- Every visual comes from Style.

local GroupService = game:GetService("GroupService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Callouts = require(ReplicatedStorage.Shared.Config.Callouts)
local CockpitConfig = require(ReplicatedStorage.Shared.Config.Cockpit)
local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)
local DriveHudConfig = require(ReplicatedStorage.Shared.Config.DriveHud)
local DriveHudRules = require(ReplicatedStorage.Shared.Rules.DriveHud)
local DailyRules = require(ReplicatedStorage.Shared.Rules.Daily)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local GarageRules = require(ReplicatedStorage.Shared.Rules.Garage)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local LayoutConfig = require(ReplicatedStorage.Shared.Config.Layout)
local LayoutRules = require(ReplicatedStorage.Shared.Rules.Layout)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local SmashConfig = require(ReplicatedStorage.Shared.Config.Smash)
local SocialConfig = require(ReplicatedStorage.Shared.Config.Social)
local SocialRules = require(ReplicatedStorage.Shared.Rules.Social)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Cockpit = require(script.Parent.Cockpit)
local Drive = require(script.Parent.Drive)
local PaintPicker = require(script.Parent.PaintPicker)
local Pad = require(script.Parent.Pad)
local Popups = require(script.Parent.Popups)
local StarterCard = require(script.Parent.StarterCard)
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
Style.fit(gui)

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

-- under the money: the friend bonus chip while Roblox friends are in the server (the feed moves down for it)
local friendChip = Style.pill(gui, "", C.pink)
friendChip.Name = "FriendChip"
friendChip.TextColor3 = C.text
friendChip.AnchorPoint = Vector2.new(1, 0)
friendChip.Position = UDim2.new(1, -14, 0, 70)
friendChip.Visible = false
local function refreshFriends()
	local n = (player:GetAttribute("Friends") or 0) :: number
	local pct =
		SocialRules.friendPercent(n, SocialConfig.FriendBonusPer, SocialConfig.FriendBonusMax)
	Loc.set(friendChip, if n == 1 then "FriendsHere1" else "FriendsHere", { n = n, pct = pct })
	friendChip.Visible = n > 0
	feed.Position = UDim2.new(1, -14, 0, if n > 0 then 98 else 76)
end

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

-- one feed plate: paint colour, text colour, size, and a picture at its front (Config/Icons), tinted when given
local function plate(
	text: string,
	fill: Color3,
	ink: Color3,
	size: number,
	font: Font,
	icon: number?,
	tint: Color3?
): TextLabel
	local l = Style.label(feed, text, size, font, ink)
	l.AutoLocalize = false -- already in the player's language (popup)
	l.BackgroundColor3 = fill
	l.BackgroundTransparency = 0
	l.AnchorPoint = Vector2.new(1, 0)
	l.Position = UDim2.fromScale(1, 0)
	local iconW = if icon then size + 10 else 0
	if icon then
		-- the padding keeps the words clear of the picture, which sits in the padded strip
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, iconW)
		pad.Parent = l
		local img = Style.image(l, icon, tint)
		img.AnchorPoint = Vector2.new(0, 0.5)
		img.Position = UDim2.new(0, -iconW + 4, 0.5, 0)
		img.Size = UDim2.fromOffset(size + 6, size + 6)
	end
	-- TextBounds are real pixels: undo the screen's scale and the pop-in's (pushFeed grows the plate in)
	local function fit()
		local pop = l:FindFirstChildOfClass("UIScale")
		local s = Style.scale() * (if pop then pop.Scale else 1)
		l.Size = UDim2.fromOffset(l.TextBounds.X / s + 24 + iconW, l.TextBounds.Y / s + 8)
	end
	l:GetPropertyChangedSignal("TextBounds"):Connect(fit)
	fit()
	Style.shadow(l, C.ink, 4)
	return l
end

-- text: English (matched in the translation table) or a Loc.msg line from the server (src/shared/Loc)
local function popup(line: string | Loc.Msg, kind: string)
	local text = Loc.resolve(line)
	local item: TextLabel
	local hold = 1.4
	if kind == "goal" then
		item = plate(
			`<font color="#FFD000">{Loc.text("GoalDone")}</font>   {text}`,
			C.panel,
			C.text,
			15,
			F.heavy,
			Icons.Pin,
			C.yellow
		)
		item.RichText = true
		hold = 3
	elseif kind == "big" then
		item = plate(text, C.yellow, C.ink, 26, F.display)
		hold = 2.4
	elseif kind == "social" then
		item = plate(text, C.pink, C.text, 18, F.display, Icons.Sign)
		hold = 2.6
	elseif kind == "info" then
		item = plate(text, C.panel, C.text, 15, F.heavy, Icons.Sign, C.yellow)
		hold = 2.4
	else
		item = plate(text, C.money, C.ink, 24, F.display, Icons.Coin)
	end
	pushFeed(item, hold, item.TextSize + 8)
end

local shownMoney = 0
-- coins flying up out of the cash box on a big gain
local function sparkle()
	for i = 1, Callouts.CashSparks do
		local coin = Style.image(moneyBox, if i % 2 == 0 then Icons.Coin else Icons.Bill)
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		coin.Rotation = math.random(-20, 20)
		coin.Size = UDim2.fromOffset(Callouts.CashSparkSize, Callouts.CashSparkSize)
		coin.Position = UDim2.fromScale(0.3 + math.random() * 0.6, 0.6)
		coin.ZIndex = 5
		coin.Parent = moneyBox
		local fly = TweenService:Create(
			coin,
			TweenInfo.new(0.5 + math.random() * 0.3, Enum.EasingStyle.Quad),
			{
				Position = UDim2.new(
					coin.Position.X.Scale + (math.random() - 0.5) * 0.6,
					0,
					-0.6 - math.random() * 0.6,
					0
				),
				Rotation = math.random(-180, 180),
				ImageTransparency = 1,
			}
		)
		fly:Play()
		fly.Completed:Once(function()
			coin:Destroy()
		end)
	end
end

local countUp: RBXScriptConnection? = nil
local function refreshMoney()
	local target = (player:GetAttribute("Money") or 0) :: number
	local from = shownMoney
	shownMoney = target
	if target > from then
		-- every gain bumps the box; a big one bumps harder, flashes green and throws coins
		local big = target - from >= Callouts.CashBigGain
		moneyScale.Scale = if big then 1.3 else 1.12
		TweenService:Create(
			moneyScale,
			TweenInfo.new(if big then 0.45 else 0.3, Enum.EasingStyle.Back),
			{ Scale = 1 }
		):Play()
		if big then
			moneyBox.BackgroundColor3 = C.money
			TweenService:Create(moneyBox, TweenInfo.new(0.5), { BackgroundColor3 = C.panel }):Play()
			sparkle()
		end
	end
	if countUp then
		countUp:Disconnect() -- a new gain carries on from what's shown now
	end
	local t0 = os.clock()
	local seconds = if math.abs(target - from) >= Callouts.CashBigGain then 0.8 else 0.4
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - t0) / seconds, 0, 1)
		local eased = 1 - (1 - k) ^ 3
		moneyLabel.Text = money(from + (target - from) * eased)
		if k >= 1 then
			conn:Disconnect()
		end
	end)
	countUp = conn
end

---------------------------------------------------------------- speedometer

-- bottom centre: an asphalt plate with a yellow lane line along the top, a gear chip, the big number and a
-- yellow MPH; flight and thruster meters run under it as dashed lane bars
local DASH_W, DASH_H, METER_H = 220, 70, 12
local dash = Style.panel(gui)
dash.Name = "Speedometer"
dash.AnchorPoint = Vector2.new(0.5, 1)
dash.Position = UDim2.new(0.5, 0, 1, -18)
dash.Size = UDim2.fromOffset(DASH_W, DASH_H)
dash.Visible = false
local dashTop = Instance.new("Frame")
dashTop.BackgroundColor3 = C.yellow
dashTop.BorderSizePixel = 0
dashTop.Size = UDim2.new(1, 0, 0, 4)
dashTop.Parent = dash
local gearLabel = Style.label(dash, "D", 28, F.display, C.text)
gearLabel.BackgroundColor3 = C.blue
gearLabel.BackgroundTransparency = 0
gearLabel.Position = UDim2.fromOffset(10, 14)
gearLabel.Size = UDim2.fromOffset(38, 46)
local speedLabel = Style.label(dash, "0", 54, F.display, C.text)
speedLabel.TextXAlignment = Enum.TextXAlignment.Right
speedLabel.Position = UDim2.fromOffset(54, 12)
speedLabel.Size = UDim2.new(1, -54 - 58, 0, DASH_H - 12)
local unitLabel = Style.label(dash, "MPH", 18, F.display, C.yellow)
unitLabel.TextXAlignment = Enum.TextXAlignment.Left
unitLabel.TextYAlignment = Enum.TextYAlignment.Bottom
unitLabel.Position = UDim2.new(1, -52, 0, 14)
unitLabel.Size = UDim2.fromOffset(46, 40)

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

---------------------------------------------------------------- key caps (keyboard players)

-- a key cap: lighter asphalt with a yellow rim and a thicker lip along the bottom, the key in yellow
local function keyCap(parent: Instance, text: string, color: Color3?): TextLabel
	local ink = color or C.yellow
	local cap = Style.label(parent, text, 15, F.display, ink)
	cap.Name = "Cap"
	cap.BackgroundColor3 = C.card
	cap.BackgroundTransparency = 0
	Style.stroke(cap, ink, 2, 0)
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = cap
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.BackgroundColor3 = ink
	lip.BorderSizePixel = 0
	lip.AnchorPoint = Vector2.new(0, 1)
	lip.Position = UDim2.new(0, 0, 1, 4) -- the padding moves children up; this puts it on the bottom edge
	lip.Size = UDim2.new(1, 0, 0, 4)
	lip.Parent = cap
	Style.fitText(cap, 7, 5)
	return cap
end

-- bottom right: the controls card, open for your first drives (Config/DriveHud), then folded into a
-- KEYS chip; K or a click opens and folds it
local controls = Style.panel(gui)
controls.Name = "Controls"
controls.AnchorPoint = Vector2.new(1, 1)
controls.Position = UDim2.new(1, -DriveHudConfig.Margin, 1, -DriveHudConfig.Margin)
controls.Visible = false
local controlsEdge = Instance.new("Frame")
controlsEdge.BackgroundColor3 = C.pink
controlsEdge.BorderSizePixel = 0
controlsEdge.Size = UDim2.new(0, 4, 1, 0)
controlsEdge.Parent = controls
local PAD = DriveHudConfig.CardPad
local controlsTitle = Style.label(controls, "CONTROLS", 17, F.display, C.pink)
controlsTitle.TextXAlignment = Enum.TextXAlignment.Left
controlsTitle.Position = UDim2.fromOffset(PAD + 4, PAD - 2)
controlsTitle.Size = UDim2.fromOffset(100, DriveHudConfig.TitleHeight)
local foldHint = Style.label(controls, DriveHudConfig.ToggleKey .. " to hide", 12, F.bold, C.dim)
foldHint.TextXAlignment = Enum.TextXAlignment.Right
foldHint.AnchorPoint = Vector2.new(1, 0)
foldHint.Position = UDim2.new(1, -PAD, 0, PAD - 2)
foldHint.Size = UDim2.fromOffset(80, DriveHudConfig.TitleHeight)
local foldButton = Instance.new("TextButton")
foldButton.Name = "Fold"
foldButton.BackgroundTransparency = 1
foldButton.Text = ""
foldButton.Size = UDim2.new(1, 0, 0, PAD + DriveHudConfig.TitleHeight)
foldButton.Parent = controls

-- one row per key; rebuilt only when the keys change, labels are updated in place
local keyRows: { { row: Frame, cap: TextLabel, label: TextLabel } } = {}
local shownKeys = ""
local function setRows(rows: { DriveHudRules.Row })
	local keys = {}
	for _, r in rows do
		table.insert(keys, r.key)
	end
	local signature = table.concat(keys, ",")
	if signature ~= shownKeys then
		shownKeys = signature
		for _, r in keyRows do
			r.row:Destroy()
		end
		table.clear(keyRows)
		for i, r in rows do
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Position = UDim2.fromOffset(
				PAD + 4,
				PAD
					+ DriveHudConfig.TitleHeight
					+ 4
					+ (i - 1) * (DriveHudConfig.RowHeight + DriveHudConfig.RowGap)
			)
			row.Size = UDim2.new(1, -PAD * 2 - 4, 0, DriveHudConfig.RowHeight)
			row.Parent = controls
			local cap = keyCap(row, r.key)
			cap.AnchorPoint = Vector2.new(0, 0.5)
			cap.Position = UDim2.fromScale(0, 0.5)
			local label = Style.label(row, r.label, 14, F.bold, C.text)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Size = UDim2.new(0, 200, 1, 0)
			table.insert(keyRows, { row = row, cap = cap, label = label })
		end
	end
	for i, r in rows do
		local l = keyRows[i].label
		l.AutoLocalize = false
		l.Text = if r.wait then Loc.text("UnstuckWait", { n = r.wait }) else Loc.source(r.label)
	end
end

-- line the labels up after the widest cap and size the card round its rows
local function layoutControls()
	local s = Style.scale()
	local capW = 0
	for _, r in keyRows do
		capW = math.max(capW, r.cap.Size.X.Offset)
	end
	local labelW = 0
	for _, r in keyRows do
		r.label.Position = UDim2.fromOffset(capW + 10, 0)
		labelW = math.max(labelW, r.label.TextBounds.X / s)
	end
	local width = math.max(PAD + 4 + capW + 10 + labelW + PAD, PAD + 4 + 100 + 80 + PAD)
	local n = #keyRows
	local height = PAD
		+ DriveHudConfig.TitleHeight
		+ 4
		+ n * (DriveHudConfig.RowHeight + DriveHudConfig.RowGap)
		- DriveHudConfig.RowGap
		+ PAD
	controls.Size = UDim2.fromOffset(math.ceil(width), height)
end

-- the folded card: a K cap and KEYS
local keysChip = Instance.new("TextButton")
keysChip.Name = "KeysChip"
keysChip.Text = ""
keysChip.AutoButtonColor = false
keysChip.BackgroundColor3 = C.panel
keysChip.BorderSizePixel = 0
keysChip.AnchorPoint = Vector2.new(1, 1)
keysChip.Position = controls.Position
keysChip.Size = UDim2.fromOffset(104, 42)
keysChip.Visible = false
keysChip.Parent = gui
Style.shadow(keysChip)
local chipEdge = controlsEdge:Clone()
chipEdge.Parent = keysChip
local chipCap = keyCap(keysChip, DriveHudConfig.ToggleKey)
chipCap.AnchorPoint = Vector2.new(0, 0.5)
chipCap.Position = UDim2.new(0, 14, 0.5, 0)
local chipText = Style.label(keysChip, "KEYS", 17, F.display, C.text)
chipText.TextXAlignment = Enum.TextXAlignment.Left
chipText.Position = UDim2.fromOffset(48, 0)
chipText.Size = UDim2.new(1, -48, 1, 0)

-- open for the first drives each time you join; once you open or fold it yourself, that sticks
local controlsOpen = false
local controlsChoice: boolean? = nil
local drives = 0
local returning: boolean? = nil
local function toggleControls()
	controlsOpen = not controlsOpen
	controlsChoice = controlsOpen
end
foldButton.Activated:Connect(toggleControls)
keysChip.Activated:Connect(toggleControls)
UserInputService.InputBegan:Connect(function(input, used)
	if
		not used
		and Drive.state.driving
		and input.KeyCode == (Enum.KeyCode :: any)[DriveHudConfig.ToggleKey]
	then
		toggleControls()
	end
end)
local function onDriveStart()
	drives += 1
	if returning == nil then
		returning = player:GetAttribute("Tutorial") == Onboarding.Steps.Done
	end
	controlsOpen = if controlsChoice ~= nil
		then controlsChoice
		else DriveHudRules.startsOpen(drives, returning == true, DriveHudConfig)
end

-- over the speedometer: the one hint you need right now (stuck: press T), a T cap and yellow words (a D-pad
-- picture on console, PadControls)
local hint = Style.panel(gui)
hint.Name = "DriveHint"
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -104)
hint.Size = UDim2.fromOffset(260, 38)
hint.Visible = false
local hintEdge = Instance.new("Frame")
hintEdge.BackgroundColor3 = C.yellow
hintEdge.BorderSizePixel = 0
hintEdge.AnchorPoint = Vector2.new(0, 1)
hintEdge.Position = UDim2.fromScale(0, 1)
hintEdge.Size = UDim2.new(1, 0, 0, 3)
hintEdge.Parent = hint
local hintCap = keyCap(hint, "T")
hintCap.AnchorPoint = Vector2.new(0, 0.5)
hintCap.Position = UDim2.new(0, 10, 0.5, -1)
local hintText = Style.label(hint, "Stuck? Back on the road", 15, F.heavy, C.yellow)
hintText.TextXAlignment = Enum.TextXAlignment.Left
hintText.Position = UDim2.fromOffset(44, 0)
hintText.Size = UDim2.new(1, -44, 1, -3)
hintText:GetPropertyChangedSignal("TextBounds"):Connect(function()
	hint.Size = UDim2.fromOffset(44 + hintText.TextBounds.X / Style.scale() + 14, 38)
end)
local hintBox = hint
-- console players get the same card with gamepad button pictures, and a D-pad picture on this hint
do
	require(script.Parent.PadControls).start(gui, {
		open = function()
			return controlsOpen
		end,
		hint = hint,
		hintCap = hintCap,
	})
end

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
	strip.Size = UDim2.fromOffset(tabRow.AbsoluteSize.X / Style.scale(), 46)
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
goalsButton.Name = "GoalsButton"
goalsButton.Visible = false
-- invite friends (Config/Social): Roblox's invite prompt; a friend who joins from it pays you a bonus
local inviteButton = tab("INVITE", 4)
inviteButton.Name = "InviteButton"
inviteButton.TextColor3 = C.pink
-- gamepad: D-pad right puts the selection on the tabs (client/Pad)
Pad.strip(tabRow, Enum.KeyCode.DPadRight, function()
	return garageButton
end)

-- the open tab is painted yellow
local function markTab(active: TextButton?)
	for _, b in tabs do
		b.BackgroundTransparency = if b == active then 0 else 1
		b.TextColor3 = if b == active then C.ink elseif b == inviteButton then C.pink else C.text
	end
end

-- the garage and the store share one sheet in the middle of the screen, never over the menu strip (the
-- strip's tabs switch between them): a big title, a dashed lane line, a yellow X, and a scrolling list
local SHEET_MAX = Vector2.new(LayoutConfig.SheetMaxWidth, LayoutConfig.SheetMaxHeight)
local TOP, BOTTOM = LayoutConfig.SheetTop, LayoutConfig.SheetBottom
local sheets: { Frame } = {}

local screenFit = gui:FindFirstChild("ScreenFit") :: UIScale?

-- centre the sheets on the screen's GUI area (layout px, so the drawn scale is undone first)
local function placeSheets()
	local h = gui.AbsoluteSize.Y / (if screenFit then screenFit.Scale else Style.scale())
	local y = LayoutRules.sheetCentre(h, SHEET_MAX.Y, TOP, BOTTOM)
	for _, p in sheets do
		p.Position = UDim2.new(0.5, 0, 0, y)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	task.defer(placeSheets) -- after Style.fit has picked up the new scale
end)
if screenFit then
	screenFit:GetPropertyChangedSignal("Scale"):Connect(placeSheets)
end

-- an empty sheet in the middle of the screen with its accent shadow
local function sheetFrame(accent: Color3): Frame
	local p = Style.panel(gui)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Size = UDim2.new(1, -28, 1, -(TOP + BOTTOM))
	p.Visible = false
	p.ZIndex = 5
	Style.setShadow(p, accent)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = SHEET_MAX
	limit.Parent = p
	table.insert(sheets, p)
	placeSheets()
	return p
end

-- the yellow X in a sheet's top-right corner
local function closeButton(p: Frame, y: number): TextButton
	local close = Style.button(p, "X", "gold", 22)
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -14, 0, y)
	close.Size = UDim2.fromOffset(44, 44)
	close.Activated:Connect(function()
		p.Visible = false
	end)
	return close
end

local function scroller(p: Frame, x: number, y: number): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(x, y)
	list.Size = UDim2.new(1, -(x + 16), 1, -(y + 12))
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
	return list
end

-- the garage, a showroom: every vehicle in a list on the left (bay number, name, and its price or that you
-- own it) and the chosen one big on the right: its 3D picture, blurb, stats, what a hit pays, the paint
-- swatches (owned) or the price, and one SPAWN / BUY button. Each vehicle has its own detail panel, named
-- by its id with its button named Action (client/Guide points at them); only the chosen one shows.
local LIST_W = LayoutConfig.GarageListWidth
local DETAIL_BOTTOM = LayoutConfig.GarageDetailBottom
local garage = sheetFrame(C.pink)
garage.Name = "Garage"
local carList = Instance.new("Frame")
carList.Name = "CarList"
carList.BackgroundColor3 = C.ink
carList.BorderSizePixel = 0
carList.Size = UDim2.new(0, LIST_W, 1, 0)
carList.Parent = garage
local garageTitle = Style.label(carList, "GARAGE", 40, F.display, C.text)
garageTitle.Position = UDim2.fromOffset(20, 16)
garageTitle.Size = UDim2.new(1, -28, 0, 44)
garageTitle.TextXAlignment = Enum.TextXAlignment.Left
local rows = Instance.new("ScrollingFrame")
rows.Name = "Rows"
rows.Position = UDim2.fromOffset(0, 80)
rows.Size = UDim2.new(1, -4, 1, -88)
rows.BackgroundTransparency = 1
rows.BorderSizePixel = 0
rows.ScrollBarThickness = 6
rows.ScrollBarImageColor3 = C.yellow
rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
rows.CanvasSize = UDim2.new()
rows.Parent = carList
local rowsLayout = Instance.new("UIListLayout")
rowsLayout.Padding = UDim.new(0, 4)
rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowsLayout.Parent = rows
local details = Instance.new("Frame")
details.Name = "Details"
details.BackgroundTransparency = 1
details.Position = UDim2.fromOffset(LIST_W, 0)
details.Size = UDim2.new(1, -LIST_W, 1, 0)
details.Parent = garage
local garageLine = Style.dashes(garage, C.yellow, false, 4)
garageLine.Position = UDim2.fromOffset(0, 66)
local garageClose = closeButton(garage, 12)
garageClose.ZIndex = 3
local garageHint = Pad.chip(garage, { Enum.KeyCode.ButtonB }, "close")
garageHint.AnchorPoint = Vector2.new(1, 0.5)
garageHint.Position = UDim2.new(1, -72, 0, 34)

type Card = {
	stats: Vehicles.Vehicle,
	action: TextButton,
	price: TextLabel,
	priceBox: Frame,
	frame: Frame,
	picker: PaintPicker.Picker,
	panel: { refresh: () -> () }, -- client/UpgradePanel: mastery, upgrades, decals
	sale: TextLabel,
	was: TextLabel,
	strike: Frame,
	nextUp: TextLabel,
	row: TextButton,
	rowBay: TextLabel,
	rowName: TextLabel,
	rowPrice: TextLabel,
	rowTag: TextLabel,
	rowNext: Frame,
}

-- your car of the day (Config/Daily) is cheaper: the server picks it from the cars you don't own and
-- publishes it, so the card shows the price the server charges
local function onSaleToday(): string?
	local id = player:GetAttribute("CarOfDay")
	return if typeof(id) == "string" and id ~= "" then id else nil
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
local NOT_FOR_CASH = { Roadster = true } -- never NEXT UP: the pass is the way to it
-- never NEXT UP under the rookie-pay car's price (the Sedan): the Scooter and Cart are a step down
local FIRST_STEP_UP = (Vehicles.ById[Economy.RookieUntil] or { price = 0 }).price
local cards: { Card } = {}
local refreshCards: () -> ()

-- a stat: its name and a dashed paint bar
local function statBar(parent: Instance, y: number, name: string, value: number, color: Color3)
	local l = Style.label(parent, name, 14, F.heavy, C.dim)
	l.Position = UDim2.fromOffset(0, y)
	l.Size = UDim2.fromOffset(96, 18)
	l.TextXAlignment = Enum.TextXAlignment.Left
	local back, fill = Style.bar(parent, color)
	back.Name = name -- client/UpgradePanel adds the upgrades' share to it
	back.BackgroundColor3 = C.card
	back.BackgroundTransparency = 0
	back.Position = UDim2.fromOffset(100, y + 3)
	back.Size = UDim2.new(1, -100, 0, 12)
	fill.Size = UDim2.fromScale(math.clamp(value, 0.05, 1), 1)
	Style.laneGaps(back, C.panel)
end

-- the template holds its moving parts as modelled: the steering wheel or handlebars stand upright and the marker
-- parts (pivots, hand grips) are still in it; lean the steering about its pivot as VehicleBuilder's weld does and
-- drop the markers, so the picture shows the vehicle as it drives
local MARKERS =
	{ SteerPivot = true, GripL = true, GripR = true, StickLPivot = true, StickRPivot = true }
local function posePreview(m: Model, stats: Vehicles.Vehicle)
	local steer = m:FindFirstChild("Steer")
	local mark = m:FindFirstChild("SteerPivot")
	if steer and steer:IsA("BasePart") then
		local pivot = if mark and mark:IsA("BasePart") then mark.Position else steer.Position
		local turn = m:GetPivot().Rotation
		local tilt = math.rad(stats.steerTilt or CockpitConfig.steerTilt)
		steer.CFrame = CFrame.new(pivot)
			* turn
			* CFrame.Angles(-tilt, 0, 0)
			* turn:Inverse()
			* CFrame.new(-pivot)
			* steer.CFrame
	end
	for _, part in m:GetChildren() do
		if MARKERS[part.Name] then
			part:Destroy()
		end
	end
end

-- a 3D picture of the vehicle: a card's top (122 px tall with a lane line under it, the Starter Pack card),
-- or bare, a picture that fills its parent
local function preview(
	parent: Instance,
	stats: Vehicles.Vehicle,
	bare: boolean?,
	full: boolean?
): Model?
	local vf = Instance.new("ViewportFrame")
	vf.Position = if bare then UDim2.new() else UDim2.fromOffset(6, 6)
	vf.Size = if bare then UDim2.fromScale(1, 1) else UDim2.new(1, -12, 0, 122)
	vf.BackgroundColor3 = Color3.fromRGB(46, 46, 54) -- no UIGradient here: it would tint the 3D model
	vf.Ambient = Color3.fromRGB(175, 175, 190)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(-1, -2, -1)
	vf.Parent = parent
	if not bare then
		local line = Style.dashes(parent, C.yellow, false, 3)
		line.Position = UDim2.fromOffset(6, 128)
		line.Size = UDim2.new(1, -12, 0, 3)
	end
	local models = ReplicatedStorage:WaitForChild("VehicleModels")
	local template = models:FindFirstChild(stats.id) :: Model?
	if not template then
		return nil
	end
	local m = template:Clone()
	if not full then
		-- pictures show the car stock; the garage's own picture (full) keeps every piece and client/UpgradePanel
		-- shows the owner's upgrades on it
		require(ReplicatedStorage.Shared.VehicleParts).fit(m, {})
	end
	posePreview(m, stats)
	m.Parent = vf
	local cf, size = m:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local dist = size.Magnitude * (if bare then 1.5 else 1.85) -- a bare picture frames it closer
	cam.CFrame =
		CFrame.lookAt(cf.Position + Vector3.new(-0.75, 0.45, -0.75).Unit * dist, cf.Position)
	cam.Parent = vf
	vf.CurrentCamera = cam
	return m
end

local chosenId = Vehicles.Starter -- the vehicle shown big

local function choose(id: string)
	if id ~= chosenId then
		chosenId = id
		refreshCards()
	end
	-- client/Track is required where it's used: this file is at Luau's limit of 200 top-level locals
	require(script.Parent.Track).viewed("Garage", id)
end

for _, stats in Vehicles.List do
	-- its row in the list
	local row = Instance.new("TextButton")
	row.Name = stats.id
	row.AutoButtonColor = false
	row.BackgroundColor3 = C.yellow
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Text = ""
	row.Size = UDim2.new(1, 0, 0, 50)
	row.LayoutOrder = stats.order
	row.Parent = rows
	local rowNext = Instance.new("Frame") -- the car to save for: a yellow edge
	rowNext.BackgroundColor3 = C.yellow
	rowNext.BorderSizePixel = 0
	rowNext.Size = UDim2.new(0, 6, 1, 0)
	rowNext.Visible = false
	rowNext.Parent = row
	local rowBay = Style.label(row, string.format("%02d", stats.order), 22, F.display, C.yellow)
	rowBay.Position = UDim2.fromOffset(6, 2)
	rowBay.Size = UDim2.new(0, 46, 1, 0)
	local rowName = Style.label(row, string.upper(stats.name), 20, F.display, C.text)
	rowName.Position = UDim2.fromOffset(56, 2)
	rowName.Size = UDim2.new(1, -56 - 112, 1, 0)
	rowName.TextXAlignment = Enum.TextXAlignment.Left
	rowName.TextTruncate = Enum.TextTruncate.AtEnd
	local rowPrice = Style.label(row, "", 17, F.display, C.money)
	rowPrice.AnchorPoint = Vector2.new(1, 0.5)
	rowPrice.Position = UDim2.new(1, -14, 0.5, 2)
	rowPrice.Size = UDim2.fromOffset(108, 24)
	rowPrice.TextXAlignment = Enum.TextXAlignment.Right
	local rowTag = Style.pill(row, "", C.money)
	rowTag.TextSize = 15
	rowTag.Size = UDim2.fromOffset(0, 22)
	rowTag.AnchorPoint = Vector2.new(1, 0.5)
	rowTag.Position = UDim2.new(1, -14, 0.5, 0)
	rowTag.Visible = false

	-- its detail panel
	local card = Instance.new("Frame")
	card.Name = stats.id
	card.BackgroundTransparency = 1
	card.Size = UDim2.fromScale(1, 1)
	card.Visible = false
	card.Parent = details
	local name = Style.label(card, stats.name, 40, F.display, C.text)
	name.Position = UDim2.fromOffset(24, 16)
	name.Size = UDim2.new(1, -230, 0, 44)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextScaled = true
	local nameSize = Instance.new("UITextSizeConstraint")
	nameSize.MaxTextSize = 40
	nameSize.Parent = name
	-- the picture fills what the bottom block leaves
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundColor3 = Color3.fromRGB(46, 46, 54)
	stage.BorderSizePixel = 0
	stage.ClipsDescendants = true
	stage.Position = UDim2.fromOffset(24, 84)
	stage.Size = UDim2.new(1, -48, 1, -(84 + DETAIL_BOTTOM + 30))
	stage.Parent = card
	local shown = preview(stage, stats, true, true)
	local bay = Style.label(stage, string.format("%02d", stats.order), 56, F.display, C.yellow)
	bay.Position = UDim2.fromOffset(14, 8)
	bay.Size = UDim2.fromOffset(100, 58)
	bay.TextXAlignment = Enum.TextXAlignment.Left
	bay.ZIndex = 2
	Style.outline(bay, 3)
	-- car of the day and NEXT UP tags in the picture's top-right corner
	local sale = Style.pill(stage, "", C.pink)
	Loc.set(sale, "CarOfDay", { pct = math.floor(DailyConfig.DiscountShare * 100 + 0.5) })
	sale.Name = "Sale"
	sale.TextColor3 = C.text
	sale.TextSize = 15
	sale.Size = UDim2.fromOffset(0, 22)
	sale.AnchorPoint = Vector2.new(1, 0)
	sale.Position = UDim2.new(1, -12, 0, 12)
	sale.ZIndex = 2
	sale.Visible = false
	local nextUp = Style.pill(stage, "NEXT UP", C.yellow)
	nextUp.Name = "NextUp"
	nextUp.TextColor3 = C.ink
	nextUp.TextSize = 15
	nextUp.Size = UDim2.fromOffset(0, 22)
	nextUp.AnchorPoint = Vector2.new(1, 0)
	nextUp.Position = UDim2.new(1, -12, 0, 12)
	nextUp.ZIndex = 2
	nextUp.Visible = false

	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.new(0, 24, 1, -18)
	bottom.Size = UDim2.new(1, -48, 0, DETAIL_BOTTOM)
	bottom.Parent = card
	-- left: the blurb, stat bars, what a hit pays and what it can smash (the reasons to buy the next car)
	local info = Instance.new("Frame")
	info.Name = "Info"
	info.BackgroundTransparency = 1
	info.Size = UDim2.new(0.5, -12, 1, 0)
	info.Parent = bottom
	local blurb = Style.label(info, stats.blurb, 16, F.bold, C.text)
	blurb.Size = UDim2.new(1, 0, 0, 40)
	blurb.TextWrapped = true
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.TextYAlignment = Enum.TextYAlignment.Top
	statBar(info, 46, "SPEED", stats.topSpeed / 250, C.orange)
	statBar(info, 68, "ACCEL", stats.launch / 15, C.blue)
	statBar(info, 90, "HANDLING", stats.grip / 22, C.green)
	statBar(info, 112, "WEIGHT", math.log10(stats.weight / 50) / math.log10(20000 / 50), C.pink)
	local pay =
		GarageRules.hitPay(stats.weight, stats.topSpeed, Economy.GaragePaySpeedShare, Economy)
	local payText = Style.label(info, "", 16, F.heavy, C.money)
	Loc.set(payText, "AboutPerHit", { money = money(pay) })
	payText.Position = UDim2.fromOffset(0, 142)
	payText.Size = UDim2.new(1, 0, 0, 20)
	payText.TextXAlignment = Enum.TextXAlignment.Left
	local topples = GarageRules.topples(stats.weight, stats.topSpeed, SmashConfig, stats.maxBreak)
	local smashText = Style.label(
		info,
		if topples then "TOPPLES BUILDINGS" else "SMASHES HOLES",
		14,
		F.heavy,
		if topples then C.orange else C.dim
	)
	smashText.Position = UDim2.fromOffset(0, 166)
	smashText.Size = UDim2.new(1, 0, 0, 18)
	smashText.TextXAlignment = Enum.TextXAlignment.Left
	-- right: the paint swatches when you own it, else the price (and the old one struck through on sale)
	local paintSpot = Instance.new("Frame")
	paintSpot.Name = "PaintSpot"
	paintSpot.BackgroundTransparency = 1
	paintSpot.Position = UDim2.new(0.5, 12, 0, 0)
	paintSpot.Size = UDim2.new(0.5, -12, 0, 124)
	paintSpot.Parent = bottom
	local priceBox = Instance.new("Frame")
	priceBox.Name = "PriceBox"
	priceBox.BackgroundTransparency = 1
	priceBox.Position = UDim2.new(0.5, 12, 0, 0)
	priceBox.Size = UDim2.new(0.5, -12, 0, 124)
	priceBox.Parent = bottom
	local price = Style.label(priceBox, "", 34, F.display, C.money)
	price.AnchorPoint = Vector2.new(1, 0)
	price.Position = UDim2.new(1, 0, 0, 30)
	price.Size = UDim2.new(1, 0, 0, 40)
	price.TextXAlignment = Enum.TextXAlignment.Right
	local was = Style.label(priceBox, "", 18, F.heavy, C.dim)
	was.Name = "Was"
	was.AutomaticSize = Enum.AutomaticSize.X
	was.AnchorPoint = Vector2.new(1, 0)
	was.Position = UDim2.new(1, 0, 0, 4)
	was.Size = UDim2.fromOffset(0, 22)
	was.Visible = false
	local strike = Instance.new("Frame")
	strike.BackgroundColor3 = C.pink
	strike.BorderSizePixel = 0
	strike.AnchorPoint = Vector2.new(0, 0.5)
	strike.Position = UDim2.fromScale(0, 0.5)
	strike.Size = UDim2.new(1, 0, 0, 3)
	strike.Parent = was
	local action = Style.button(bottom, "SPAWN", "green", 28)
	action.Name = "Action"
	action:SetAttribute("VehicleId", stats.id) -- client/Guide finds the button by it
	require(script.Parent.Trial).button(stats.id, action) -- the Roadster's FREE TRIAL beside it
	action.AnchorPoint = Vector2.new(1, 1)
	action.Position = UDim2.fromScale(1, 1)
	action.Size = UDim2.new(0.5, -12, 0, 60)
	local picker = PaintPicker.attach(card, stats.id, shown, info, action, function()
		refreshCards()
	end, paintSpot)
	local panel = require(script.Parent.UpgradePanel).attach({
		card = card,
		stats = stats,
		shown = shown,
		stage = stage,
		info = info,
		bottom = bottom,
		paintSpot = paintSpot,
		row = row,
		rowTag = rowTag,
	})
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
	-- a tap shows it; on a gamepad, moving onto a row shows it and A goes to its button
	row.Activated:Connect(function()
		choose(stats.id)
		if Pad.usingGamepad() then
			GuiService.SelectedObject = action
		end
	end)
	row.SelectionGained:Connect(function()
		choose(stats.id)
	end)
	table.insert(cards, {
		stats = stats,
		action = action,
		price = price,
		priceBox = priceBox,
		frame = card,
		picker = picker,
		panel = panel,
		sale = sale,
		was = was,
		strike = strike,
		nextUp = nextUp,
		row = row,
		rowBay = rowBay,
		rowName = rowName,
		rowPrice = rowPrice,
		rowTag = rowTag,
		rowNext = rowNext,
	})
end

local function setTag(c: Card, text: string?, color: Color3?, ink: Color3?)
	c.rowTag.Visible = text ~= nil
	c.rowPrice.Visible = text == nil
	if text and color then
		c.rowTag.Text = text
		c.rowTag.BackgroundColor3 = color
		c.rowTag.TextColor3 = ink or C.ink
	end
end

function refreshCards()
	local owned = "," .. ((player:GetAttribute("Owned") or "") :: string) .. ","
	local cash = (player:GetAttribute("Money") or 0) :: number
	local driving = player:GetAttribute("VehicleId")
	local ownedSet = {}
	for _, id in string.split(owned, ",") do
		ownedSet[id] = true
	end
	local save = GarageRules.nextUp(Vehicles.List, ownedSet, cash, function(id)
		return priceOf(Vehicles.ById[id])
	end, NOT_FOR_CASH, FIRST_STEP_UP)
	for _, c in cards do
		local price = priceOf(c.stats)
		local chosen = c.stats.id == chosenId
		local mine = string.find(owned, "," .. c.stats.id .. ",", 1, true) ~= nil
		local onSale = not mine and price < c.stats.price
		c.frame.Visible = chosen
		c.strike.Visible = true
		c.was.TextColor3 = C.dim
		c.nextUp.Visible = c.stats.id == save
		c.rowNext.Visible = c.stats.id == save
		c.priceBox.Visible = not mine
		c.rowName.TextColor3 = C.text
		c.rowPrice.TextColor3 = C.money
		if mine then
			local inIt = driving == c.stats.id
			Loc.say(c.action, if inIt then "DRIVING" else "SPAWN")
			Style.setKind(c.action, if inIt then "dark" else "green")
			c.sale.Visible = false
			c.was.Visible = false
			if inIt then
				setTag(c, "IN USE", C.money)
			else
				setTag(c, "OWNED", C.grey, C.text)
			end
		else
			c.price.Text = if price == 0 then "FREE" else money(price)
			c.price.TextColor3 = C.money
			c.sale.Visible = onSale
			c.was.Visible = onSale
			c.was.Text = money(c.stats.price)
			-- under the sale tag when both show
			c.nextUp.Position = UDim2.new(1, -12, 0, if c.sale.Visible then 40 else 12)
			c.rowPrice.Text = c.price.Text
			setTag(
				c,
				if onSale then `-{math.floor(DailyConfig.DiscountShare * 100 + 0.5)}%` else nil,
				C.pink,
				C.text
			)
			if cash >= price then
				Loc.set(c.action, "BuyPrice", { price = money(price) })
				Style.setKind(c.action, "orange")
			elseif c.stats.id == "Roadster" then
				-- a pass car: the pass is the way in; the cash price stays as a small "or"
				Loc.say(c.action, "GET PASS")
				Style.setKind(c.action, "blue")
				c.price.Text = "GAME PASS"
				c.price.TextColor3 = C.blue
				Loc.set(c.was, "OrPrice", { price = money(price) })
				c.was.Visible = true
				c.strike.Visible = false
				setTag(c, "PASS", C.blue, C.text)
			else
				Loc.set(c.action, "BuyPrice", { price = money(price) })
				Style.setKind(c.action, "dark")
				c.rowName.TextColor3 = C.dim -- out of reach for now
				c.rowPrice.TextColor3 = C.dim
			end
		end
		-- the chosen row is painted yellow, its words in ink
		c.row.BackgroundTransparency = if chosen then 0 else 1
		c.rowBay.TextColor3 = if chosen then C.ink else C.yellow
		if chosen then
			c.rowName.TextColor3 = C.ink
			c.rowPrice.TextColor3 = C.ink
		end
		c.picker.refresh()
		c.panel.refresh()
	end
end

Pad.menu(garage, {
	first = function()
		return rows:FindFirstChild(chosenId) :: GuiObject?
	end,
	close = function()
		garage.Visible = false
	end,
})

-- the store: a dark rail on the left lists its sections (DEALS, MONEY, PASSES, FREE: tap one to jump to it,
-- LB/RB on a gamepad), and the right side is one scrolling page: the Starter Pack banner, the money packs,
-- the game passes, and the group reward. The section in view names the page and lights its tab.
local RAIL = 200
local store = sheetFrame(C.blue)
store.Name = "Store"
local rail = Instance.new("Frame")
rail.Name = "Rail"
rail.BackgroundColor3 = C.ink
rail.BorderSizePixel = 0
rail.Size = UDim2.new(0, RAIL, 1, 0)
rail.Parent = store
local storeTitle = Style.label(rail, "STORE", 40, F.display, C.text)
storeTitle.Position = UDim2.fromOffset(20, 16)
storeTitle.Size = UDim2.new(1, -28, 0, 44)
storeTitle.TextXAlignment = Enum.TextXAlignment.Left
local pageTitle = Style.label(store, "", 36, F.display, C.text)
pageTitle.Name = "PageTitle"
pageTitle.Position = UDim2.fromOffset(RAIL + 26, 16)
pageTitle.Size = UDim2.new(1, -(RAIL + 26 + 190), 0, 44)
pageTitle.TextXAlignment = Enum.TextXAlignment.Left
pageTitle.TextTruncate = Enum.TextTruncate.AtEnd
local storeLine = Style.dashes(store, C.yellow, false, 4)
storeLine.Position = UDim2.fromOffset(0, 66)
closeButton(store, 12)
local closeHint = Pad.chip(store, { Enum.KeyCode.ButtonB }, "close")
closeHint.AnchorPoint = Vector2.new(1, 0.5)
closeHint.Position = UDim2.new(1, -72, 0, 34)
local storeList = scroller(store, RAIL + 24, 82)
storeList.Name = "Page"
local storeLayout = Instance.new("UIListLayout")
storeLayout.Padding = UDim.new(0, 14)
storeLayout.SortOrder = Enum.SortOrder.LayoutOrder
storeLayout.Parent = storeList

-- a section heading: yellow words on a dashed lane line that runs to the right edge
local function sectionHead(order: number, text: string): Frame
	local h = Instance.new("Frame")
	h.BackgroundTransparency = 1
	h.Size = UDim2.new(1, -12, 0, 28)
	h.LayoutOrder = order
	h.Parent = storeList
	local line = Style.dashes(h, C.yellow, false, 3)
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.Position = UDim2.fromScale(0, 0.5)
	local l = Style.label(h, text, 24, F.display, C.yellow)
	l.BackgroundColor3 = C.panel
	l.BackgroundTransparency = 0
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromScale(0, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.ZIndex = 2
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = l
	return h
end

-- "R$ 99" (after prefix, if given): the configured price until the product exists, then Roblox's real one
local function robuxText(product: Products.Product, label: TextButton, prefix: string?)
	local before = prefix or ""
	label.AutoLocalize = false -- a price, its prefix already translated
	label.Text = before .. "R$ " .. product.robux
	if product.id ~= 0 then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(product.id, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				label.Text = before .. "R$ " .. info.PriceInRobux
			end
		end)
	elseif RunService:IsStudio() then
		label.Text ..= " (test)"
	end
end

local function paint(parent: Instance, color: Color3, size: UDim2): Frame
	local s = Instance.new("Frame")
	s.BackgroundColor3 = color
	s.BorderSizePixel = 0
	s.Size = size
	s.Parent = parent
	return s
end

---------------- the Starter Pack banner: client/StarterCard keeps its text, prices and countdown in step

local hero = Style.card(storeList)
hero.Name = "StarterBanner"
hero.Size = UDim2.new(1, -12, 0, 222)
hero.LayoutOrder = 1
hero.ClipsDescendants = true
paint(hero, C.yellow, UDim2.new(0, 8, 1, 0))
local heroHazard = paint(hero, C.yellow, UDim2.new(1, 0, 0, 12))
heroHazard.ClipsDescendants = true
for x = -20, 1000, 28 do
	local s = paint(heroHazard, C.ink, UDim2.fromOffset(12, 40))
	s.Position = UDim2.fromOffset(x, -14)
	s.Rotation = 40
end
local heroTitle = Style.label(hero, string.upper(Products.Starter.title), 44, F.display, C.text)
heroTitle.Position = UDim2.fromOffset(24, 26)
heroTitle.Size = UDim2.new(1, -300, 0, 48)
heroTitle.TextXAlignment = Enum.TextXAlignment.Left
heroTitle.TextScaled = true
local heroTitleSize = Instance.new("UITextSizeConstraint")
heroTitleSize.MaxTextSize = 44
heroTitleSize.Parent = heroTitle
local heroText = Style.label(hero, "", 15, F.bold, C.dim)
heroText.Position = UDim2.fromOffset(26, 76)
heroText.Size = UDim2.new(1, -300, 0, 20)
heroText.TextXAlignment = Enum.TextXAlignment.Left
heroText.TextTruncate = Enum.TextTruncate.AtEnd
-- what's inside: a picture of each car and the cash
local gets = Instance.new("Frame")
gets.BackgroundTransparency = 1
gets.Position = UDim2.fromOffset(24, 106)
gets.Size = UDim2.new(1, -300, 0, 96)
gets.Parent = hero
local getsList = Instance.new("UIListLayout")
getsList.FillDirection = Enum.FillDirection.Horizontal
getsList.Padding = UDim.new(0, 12)
getsList.SortOrder = Enum.SortOrder.LayoutOrder
getsList.Parent = gets
for i, id in Products.Starter.vehicles or {} do
	local stats = Vehicles.ById[id]
	local tile = Instance.new("Frame")
	tile.BackgroundColor3 = C.ink
	tile.BorderSizePixel = 0
	tile.Size = UDim2.fromOffset(150, 96)
	tile.LayoutOrder = i
	tile.Parent = gets
	Style.stroke(tile, C.ink, 2, 0)
	if stats then
		preview(tile, stats, true)
		local n = Style.label(tile, string.upper(stats.name), 15, F.display, C.text)
		n.AnchorPoint = Vector2.new(0, 1)
		n.Position = UDim2.new(0, 8, 1, -4)
		n.Size = UDim2.new(1, -16, 0, 18)
		n.TextXAlignment = Enum.TextXAlignment.Left
		n.ZIndex = 2
		Style.outline(n, 2)
	end
end
local cashTile = Instance.new("Frame")
cashTile.BackgroundColor3 = C.ink
cashTile.BorderSizePixel = 0
cashTile.Size = UDim2.fromOffset(150, 96)
cashTile.LayoutOrder = 10
cashTile.Parent = gets
local cashAmount = Style.label(cashTile, money(Products.Starter.money), 28, F.display, C.money)
cashAmount.Position = UDim2.fromOffset(6, 24)
cashAmount.Size = UDim2.new(1, -12, 0, 32)
cashAmount.TextScaled = true
local cashAmountSize = Instance.new("UITextSizeConstraint")
cashAmountSize.MaxTextSize = 28
cashAmountSize.Parent = cashAmount
local cashIn = Style.label(cashTile, "IN GAME", 14, F.heavy, C.dim)
cashIn.Position = UDim2.fromOffset(0, 58)
cashIn.Size = UDim2.new(1, 0, 0, 18)
-- the price side: the deal's % off, the struck-through full price and the countdown, then BUY
local heroPrice = Instance.new("Frame")
heroPrice.BackgroundTransparency = 1
heroPrice.AnchorPoint = Vector2.new(1, 0)
heroPrice.Position = UDim2.new(1, -22, 0, 26)
heroPrice.Size = UDim2.fromOffset(240, 100)
heroPrice.Parent = hero
local heroOff = Style.pill(heroPrice, "", C.red)
heroOff.TextColor3 = C.text
heroOff.TextSize = 15
heroOff.Size = UDim2.fromOffset(0, 22)
heroOff.AnchorPoint = Vector2.new(1, 0)
heroOff.Position = UDim2.fromScale(1, 0)
local heroWas = Style.label(heroPrice, "", 24, F.display, C.dim)
heroWas.AnchorPoint = Vector2.new(1, 0)
heroWas.Position = UDim2.fromOffset(240, 30)
heroWas.Size = UDim2.fromOffset(0, 26)
heroWas.AutomaticSize = Enum.AutomaticSize.X
local strike = paint(heroWas, C.red, UDim2.new(1, 4, 0, 4))
strike.AnchorPoint = Vector2.new(0.5, 0.5)
strike.Position = UDim2.fromScale(0.5, 0.42)
local heroTimer = Style.label(heroPrice, "", 20, F.display, C.text)
heroTimer.BackgroundColor3 = C.red
heroTimer.BackgroundTransparency = 0
heroTimer.AnchorPoint = Vector2.new(1, 0)
heroTimer.Position = UDim2.fromOffset(240, 64)
heroTimer.Size = UDim2.fromOffset(0, 30)
heroTimer.AutomaticSize = Enum.AutomaticSize.X
do
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 4)
	pad.Parent = heroTimer
end
local heroBuy = Style.button(hero, "", "gold", 30)
heroBuy.Name = "Buy"
heroBuy.AnchorPoint = Vector2.new(1, 1)
heroBuy.Position = UDim2.new(1, -22, 1, -22)
heroBuy.Size = UDim2.fromOffset(240, 62)
heroBuy.Activated:Connect(function()
	Net.waitFor("BuyProduct"):FireServer(StarterCard.current().key)
end)
StarterCard.bindStore({
	row = hero,
	text = heroText,
	button = heroBuy,
	off = heroOff,
	was = heroWas,
	timer = heroTimer,
})
StarterCard.start(gui, preview)

---------------- money packs: a stack of bills that grows with the pack

-- where each bill of the drawing sits (px from the drawing's top-left), per pack in Products.MoneyPacks order
local BILLS = {
	{ { 17, 26 } },
	{ { 6, 30 }, { 26, 18 } },
	{ { 0, 34 }, { 30, 34 }, { 15, 14 } },
	{ { -6, 40 }, { 20, 40 }, { 46, 40 }, { 7, 20 }, { 33, 20 }, { 20, 0 } },
}
local function bill(parent: Instance, x: number, y: number)
	local b = paint(parent, C.green, UDim2.fromOffset(46, 22))
	b.Position = UDim2.fromOffset(x, y)
	Style.stroke(b, C.ink, 2, 0)
	local inner = Instance.new("UIStroke")
	inner.Color = C.billEdge
	inner.Thickness = 3
	inner.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	inner.LineJoinMode = Enum.LineJoinMode.Miter
	local face = paint(b, C.green, UDim2.new(1, -6, 1, -6))
	face.Position = UDim2.fromOffset(3, 3)
	inner.Parent = face
	local d = Style.label(b, "$", 16, F.display, C.billInk)
	d.Size = UDim2.fromScale(1, 1)
	d.ZIndex = 2
end

local moneyHead = sectionHead(2, "MONEY")
local packs = Instance.new("Frame")
packs.BackgroundTransparency = 1
packs.Size = UDim2.new(1, -12, 0, 200)
packs.LayoutOrder = 3
packs.Parent = storeList
local packGrid = Instance.new("UIGridLayout")
packGrid.CellSize = UDim2.new(0.25, -11, 1, 0)
packGrid.CellPadding = UDim2.fromOffset(14, 0)
packGrid.SortOrder = Enum.SortOrder.LayoutOrder
packGrid.Parent = packs
local firstPackBuy: TextButton? = nil
for i, pack in Products.MoneyPacks do
	local card = Style.card(packs)
	card.LayoutOrder = i
	paint(card, C.money, UDim2.new(1, 0, 0, 6))
	local drawing = Instance.new("Frame")
	drawing.BackgroundTransparency = 1
	drawing.AnchorPoint = Vector2.new(0.5, 0)
	drawing.Position = UDim2.new(0.5, 0, 0, 14)
	drawing.Size = UDim2.fromOffset(80, 62)
	drawing.Parent = card
	for _, at in BILLS[math.min(i, #BILLS)] do
		bill(drawing, at[1], at[2])
	end
	if pack.tag then
		local tag =
			Style.pill(card, pack.tag, if i == #Products.MoneyPacks then C.gold else C.orange)
		tag.TextSize = 14
		tag.Size = UDim2.fromOffset(0, 20)
		tag.AnchorPoint = Vector2.new(0.5, 0)
		tag.Position = UDim2.fromScale(0.5, 0)
		tag.ZIndex = 3
	end
	local amount = Style.label(card, money(pack.money), 34, F.display, C.money)
	amount.Position = UDim2.fromOffset(6, 78)
	amount.Size = UDim2.new(1, -12, 0, 36)
	amount.TextScaled = true
	local amountSize = Instance.new("UITextSizeConstraint")
	amountSize.MaxTextSize = 34
	amountSize.Parent = amount
	local name = Style.label(card, string.upper(pack.title), 14, F.heavy, C.dim)
	name.Position = UDim2.fromOffset(0, 114)
	name.Size = UDim2.new(1, 0, 0, 18)
	local buy = Style.button(card, "", "gold", 22)
	buy.Name = "Buy"
	buy.AnchorPoint = Vector2.new(0.5, 1)
	buy.Position = UDim2.new(0.5, 0, 1, -14)
	buy.Size = UDim2.new(1, -28, 0, 46)
	robuxText(pack, buy)
	buy.Activated:Connect(function()
		Net.waitFor("BuyProduct"):FireServer(pack.key)
	end)
	firstPackBuy = firstPackBuy or buy
end

---------------- game passes: one poster card each, in its own colour

local PASSES = {
	{
		name = "Roadster",
		title = "ROADSTER",
		icon = Icons.PassRoadster,
		accent = C.red,
		ink = C.text,
		text = Loc.text("PassRoadsterText", { money = money(Economy.RoadsterPassMoney) }),
	},
	{
		name = "DoubleMoney",
		title = "2x MONEY",
		icon = Icons.PassDoubleMoney,
		accent = C.money,
		ink = C.ink,
		text = "Double money from every hit.",
	},
	{
		name = "VIP",
		title = "VIP",
		icon = Icons.PassVIP,
		accent = C.gold,
		ink = C.ink,
		text = Loc.text("PassVipText", { pct = math.floor((Economy.VipMoney - 1) * 100 + 0.5) }),
	},
}
local passButtons: { [string]: TextButton } = {}
local passHead = sectionHead(4, "GAME PASSES")
local passRow = Instance.new("Frame")
passRow.BackgroundTransparency = 1
passRow.Size = UDim2.new(1, -12, 0, 226)
passRow.LayoutOrder = 5
passRow.Parent = storeList
local passGrid = Instance.new("UIGridLayout")
passGrid.CellSize = UDim2.new(1 / #PASSES, -10, 1, 0)
passGrid.CellPadding = UDim2.fromOffset(14, 0)
passGrid.SortOrder = Enum.SortOrder.LayoutOrder
passGrid.Parent = passRow
for i, p in PASSES do
	local card = Style.card(passRow)
	card.LayoutOrder = i
	local band = paint(card, p.accent, UDim2.new(1, 0, 0, 56))
	-- the pass's picture at the band's right end; the title shrinks to fit beside it
	local pic = Style.image(band, p.icon)
	pic.Name = "Icon"
	pic.AnchorPoint = Vector2.new(1, 0.5)
	pic.Position = UDim2.new(1, -8, 0.5, 0)
	pic.Size = UDim2.fromOffset(64, 64)
	pic.ZIndex = 2
	local t = Style.label(band, p.title, 30, F.display, p.ink)
	t.Position = UDim2.fromOffset(16, 6)
	t.Size = UDim2.new(1, -96, 1, -6)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextScaled = true
	local tSize = Instance.new("UITextSizeConstraint")
	tSize.MaxTextSize = 30
	tSize.Parent = t
	local d = Style.label(card, p.text, 15, F.bold, C.text)
	d.Position = UDim2.fromOffset(16, 68)
	d.Size = UDim2.new(1, -32, 0, 86)
	d.TextWrapped = true
	d.TextXAlignment = Enum.TextXAlignment.Left
	d.TextYAlignment = Enum.TextYAlignment.Top
	local b = Style.button(card, "GET", "gold", 22)
	b.Name = "Buy"
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Position = UDim2.new(0.5, 0, 1, -14)
	b.Size = UDim2.new(1, -28, 0, 50)
	b.Activated:Connect(function()
		Net.waitFor("BuyPass"):FireServer(p.name)
	end)
	passButtons[p.name] = b
end

---------------- free: the group reward

local freeHead = sectionHead(6, "FREE")
local groupRow = Style.card(storeList)
groupRow.Size = UDim2.new(1, -12, 0, 92)
groupRow.LayoutOrder = 7
paint(groupRow, C.blue, UDim2.new(0, 8, 1, 0))
do
	local t = Style.label(groupRow, "GROUP REWARD", 26, F.display, C.text)
	t.Position = UDim2.fromOffset(24, 12)
	t.Size = UDim2.new(1, -230, 0, 30)
	t.TextXAlignment = Enum.TextXAlignment.Left
	local d = Style.label(
		groupRow,
		Loc.text("GroupRewardText", { money = money(Economy.GroupReward) }),
		15,
		F.bold,
		C.dim
	)
	d.Position = UDim2.fromOffset(24, 46)
	d.Size = UDim2.new(1, -230, 0, 36)
	d.TextWrapped = true
	d.TextXAlignment = Enum.TextXAlignment.Left
	d.TextYAlignment = Enum.TextYAlignment.Top
end
local groupButton = Style.button(groupRow, "CLAIM", "green", 22)
groupButton.Name = "Claim"
groupButton.AnchorPoint = Vector2.new(1, 0.5)
groupButton.Position = UDim2.new(1, -16, 0.5, 0)
groupButton.Size = UDim2.fromOffset(170, 50)
groupButton.Activated:Connect(function()
	if player:GetAttribute("GroupClaimed") == true then
		return
	end
	if Economy.GroupId ~= 0 then
		-- Roblox's own join prompt; the server checks membership either way
		pcall(function()
			(GroupService :: any):PromptJoinAsync(Economy.GroupId)
		end)
	end
	Net.waitFor("ClaimGroup"):FireServer()
end)
---------------- the rail: one tab per section; the section in view is lit and names the page

type Section = {
	key: string,
	title: string,
	accent: Color3,
	anchor: GuiObject,
	first: GuiObject?,
	tab: TextButton?,
}
local SECTIONS: { Section } = {
	{ key = "DEALS", title = "TODAY'S DEALS", accent = C.red, anchor = hero, first = heroBuy },
	{ key = "MONEY", title = "MONEY", accent = C.money, anchor = moneyHead, first = firstPackBuy },
	{
		key = "PASSES",
		title = "GAME PASSES",
		accent = C.pink,
		anchor = passHead,
		first = passButtons[PASSES[1].name],
	},
	{ key = "FREE", title = "FREE STUFF", accent = C.blue, anchor = freeHead, first = groupButton },
}
local railTabs = Instance.new("Frame")
railTabs.BackgroundTransparency = 1
railTabs.Position = UDim2.fromOffset(0, 84)
railTabs.Size = UDim2.new(1, 0, 1, -130)
railTabs.Parent = rail
local railList = Instance.new("UIListLayout")
railList.Padding = UDim.new(0, 6)
railList.SortOrder = Enum.SortOrder.LayoutOrder
railList.Parent = railTabs
local shownSection = 0

local function visibleSections(): { Section }
	local out = {}
	for _, s in SECTIONS do
		if s.anchor.Visible then
			table.insert(out, s)
		end
	end
	return out
end

local function markSection(s: Section)
	if store.Visible then
		require(script.Parent.Track).viewed("Store", s.key)
	end
	pageTitle.Text = s.title
	for _, other in SECTIONS do
		local t = other.tab
		if t then
			t.BackgroundTransparency = if other == s then 0 else 1
			t.TextColor3 = if other == s then C.ink else C.text
		end
	end
end

-- the section in view: the last one whose top is at or above the page's top (a little slack), or the last
-- one once the page is scrolled to its end
local function sectionInView()
	local shown = visibleSections()
	if #shown == 0 then
		return
	end
	local tops = {}
	for _, s in shown do
		table.insert(tops, s.anchor.AbsolutePosition.Y - storeList.AbsolutePosition.Y)
	end
	local atEnd = storeList.CanvasPosition.Y
		>= storeList.AbsoluteCanvasSize.Y - storeList.AbsoluteWindowSize.Y - 2
	local i = LayoutRules.sectionAt(tops, LayoutConfig.SectionSlack * Style.scale(), atEnd)
	shownSection = i
	markSection(shown[i])
end
storeList:GetPropertyChangedSignal("CanvasPosition"):Connect(sectionInView)

-- scroll so the section's top meets the page's top
local function jumpTo(s: Section)
	local delta = s.anchor.AbsolutePosition.Y - storeList.AbsolutePosition.Y
	local maxY = math.max(0, storeList.AbsoluteCanvasSize.Y - storeList.AbsoluteWindowSize.Y)
	local y = math.clamp(storeList.CanvasPosition.Y + delta, 0, maxY)
	TweenService:Create(storeList, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
		CanvasPosition = Vector2.new(0, y),
	}):Play()
	markSection(s)
end

for i, s in SECTIONS do
	local railTab = Instance.new("TextButton")
	railTab.Name = s.key
	railTab.AutoButtonColor = false
	railTab.BackgroundColor3 = C.yellow
	railTab.BackgroundTransparency = 1
	railTab.BorderSizePixel = 0
	railTab.Size = UDim2.new(1, 0, 0, 54)
	railTab.Text = s.key
	railTab.TextSize = 22
	railTab.FontFace = F.display
	railTab.TextColor3 = C.text
	railTab.TextXAlignment = Enum.TextXAlignment.Left
	railTab.LayoutOrder = i
	railTab.Parent = railTabs
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 26)
	pad.PaddingTop = UDim.new(0, 4)
	pad.Parent = railTab
	local bar = paint(railTab, s.accent, UDim2.new(0, 8, 1, 0))
	bar.Position = UDim2.fromOffset(-26, -4) -- undo the padding
	bar.Size = UDim2.new(0, 8, 1, 4)
	s.tab = railTab
	railTab.Activated:Connect(function()
		jumpTo(s)
	end)
	-- a section that isn't offered (the pack bought, no group) loses its tab
	s.anchor:GetPropertyChangedSignal("Visible"):Connect(function()
		railTab.Visible = s.anchor.Visible
	end)
	railTab.Visible = s.anchor.Visible
end
local switchHint = Pad.chip(rail, { Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1 }, "switch")
switchHint.AnchorPoint = Vector2.new(0, 1)
switchHint.Position = UDim2.new(0, 20, 1, -16)

Pad.menu(store, {
	first = function()
		return if hero.Visible then heroBuy else firstPackBuy
	end,
	close = function()
		store.Visible = false
	end,
	shoulders = function(dir: number)
		local shown = visibleSections()
		local s = shown[math.clamp(shownSection + dir, 1, #shown)]
		if s then
			jumpTo(s)
			-- the selection follows to the section's first button
			if s.first and Pad.usingGamepad() then
				GuiService.SelectedObject = s.first
			end
		end
	end,
})

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
	local claimed = player:GetAttribute("GroupClaimed") == true
	groupButton.Text = if claimed then "CLAIMED" else "CLAIM"
	Style.setKind(groupButton, if claimed then "dark" else "green")
	-- no group yet: nothing to offer outside Studio
	local groupLive = Economy.GroupId ~= 0 or RunService:IsStudio()
	freeHead.Visible = groupLive
	groupRow.Visible = groupLive
	task.defer(sectionInView)
end
store:GetPropertyChangedSignal("Visible"):Connect(function()
	if store.Visible then
		storeList.CanvasPosition = Vector2.zero
		task.defer(sectionInView)
	end
end)

local function open(p: Frame)
	placeSheets()
	local scale = p:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = p
	scale.Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	p.Visible = true
end

---------------------------------------------------------------- offers

-- the "can't afford it" card, a poster like the Starter Pack's: how far you are from the car (its picture and a
-- bar), the smallest cash pack that covers the gap, GET IT and KEEP DRIVING
local OFFER_W, OFFER_H = 500, 410
local offer = Style.panel(gui)
offer.Name = "Upsell"
offer.AnchorPoint = Vector2.new(0.5, 0.5)
offer.Position = UDim2.fromScale(0.5, 0.5)
offer.Size = UDim2.fromOffset(OFFER_W, OFFER_H)
offer.ZIndex = 10
offer.Visible = false
Style.stroke(offer, C.yellow, 4, 0)
Style.setShadow(offer, C.pink)
Style.hazard(offer, OFFER_W, 14)
local offerTitle = Style.label(offer, "", 40, F.display, C.yellow)
offerTitle.Position = UDim2.fromOffset(0, 26)
offerTitle.Size = UDim2.new(1, 0, 0, 44)
Style.outline(offerTitle, 2)
-- the car you're saving for, and how far along you are
local offerPic = Instance.new("Frame")
offerPic.Name = "Picture"
offerPic.BackgroundColor3 = Color3.fromRGB(46, 46, 54)
offerPic.BorderSizePixel = 0
offerPic.ClipsDescendants = true
offerPic.Position = UDim2.fromOffset(24, 84)
offerPic.Size = UDim2.fromOffset(120, 70)
offerPic.Parent = offer
local offerCar = Style.label(offer, "", 20, F.display, C.text)
offerCar.Position = UDim2.fromOffset(158, 84)
offerCar.Size = UDim2.new(1, -182, 0, 24)
offerCar.TextXAlignment = Enum.TextXAlignment.Left
local offerBack, offerFill = Style.bar(offer, C.money)
offerBack.BackgroundTransparency = 0
offerBack.Position = UDim2.fromOffset(158, 112)
offerBack.Size = UDim2.new(1, -182, 0, 16)
Style.laneGaps(offerBack, C.ink)
local offerAmount = Style.label(offer, "", 14, F.bold, C.dim)
offerAmount.Position = UDim2.fromOffset(158, 132)
offerAmount.Size = UDim2.new(1, -182, 0, 18)
offerAmount.TextXAlignment = Enum.TextXAlignment.Left
-- the pack that covers it
local offerPack = Style.card(offer)
offerPack.Position = UDim2.fromOffset(24, 172)
offerPack.Size = UDim2.new(1, -48, 0, 76)
do
	local edge = Instance.new("Frame")
	edge.BackgroundColor3 = C.money
	edge.BorderSizePixel = 0
	edge.Size = UDim2.new(0, 8, 1, 0)
	edge.Parent = offerPack
	local packBill = Style.image(offerPack, Icons.Bill)
	packBill.AnchorPoint = Vector2.new(0, 0.5)
	packBill.Position = UDim2.new(0, 20, 0.5, 0)
	packBill.Size = UDim2.fromOffset(58, 58)
end
local offerPackName = Style.label(offerPack, "", 24, F.display, C.money)
offerPackName.Position = UDim2.fromOffset(90, 10)
offerPackName.Size = UDim2.new(1, -102, 0, 30)
offerPackName.TextXAlignment = Enum.TextXAlignment.Left
offerPackName.TextScaled = true
do
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 24
	fit.Parent = offerPackName
end
local offerText = Style.label(offerPack, "", 14, F.bold, C.dim)
offerText.Position = UDim2.fromOffset(90, 42)
offerText.Size = UDim2.new(1, -102, 0, 20)
offerText.TextXAlignment = Enum.TextXAlignment.Left
local offerBuy = Style.button(offer, "", "gold", 26)
offerBuy.Name = "UpsellBuy"
offerBuy.AnchorPoint = Vector2.new(0.5, 1)
offerBuy.Position = UDim2.new(0.5, 0, 1, -62)
offerBuy.Size = UDim2.fromOffset(320, 58)
local offerNo = Style.button(offer, "KEEP DRIVING", "dark", 16)
offerNo.Name = "UpsellNo"
offerNo.AnchorPoint = Vector2.new(0.5, 1)
offerNo.Position = UDim2.new(0.5, 0, 1, -14)
offerNo.Size = UDim2.fromOffset(200, 38)
local offerKey = ""
local offerIsUpsell = false -- the "can't afford it" card, which a successful buy closes
offerBuy.Activated:Connect(function()
	offer.Visible = false
	if offerIsUpsell then
		require(script.Parent.Track).offer("Upsell", "Pressed")
	end
	Net.waitFor("BuyProduct"):FireServer(offerKey)
end)
offerNo.Activated:Connect(function()
	offer.Visible = false
end)
-- gamepad: it starts on GET IT, and B is KEEP DRIVING
Pad.menu(offer, {
	first = function()
		return offerBuy
	end,
	close = function()
		offer.Visible = false
	end,
})

-- tapping BUY on a car you can't afford: suggest the smallest pack that covers the gap
offerFor = function(stats: Vehicles.Vehicle)
	-- still near the start: the Starter Pack is the better buy than any cash pack (at the deal or full price)
	if StarterCard.eligible() then
		offer.Visible = false
		StarterCard.show()
		return
	end
	local cash = (player:GetAttribute("Money") or 0) :: number
	local price = priceOf(stats)
	local gap = price - cash
	local pick = Products.MoneyPacks[#Products.MoneyPacks]
	for _, pack in Products.MoneyPacks do
		if pack.money >= gap then
			pick = pack
			break
		end
	end
	offerIsUpsell = true
	Loc.set(offerTitle, "NeedMore", { money = money(gap) })
	offerCar.Text = string.upper(stats.name)
	offerFill.Size = UDim2.fromScale(math.clamp(cash / math.max(price, 1), 0, 1), 1)
	offerAmount.Text = `{money(cash)} / {money(price)}`
	offerPic:ClearAllChildren()
	preview(offerPic, stats, true)
	Loc.set(
		offerPackName,
		"PackLine",
		{ pack = Loc.src(string.upper(pick.title)), money = money(pick.money) }
	)
	offerText.Text = "covers it now, or keep running people over"
	offerKey = pick.key
	robuxText(pick, offerBuy, Loc.source("GET IT") .. "  ·  ")
	local scale = offer:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = offer
	scale.Scale = 0.8
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	offer.Visible = true
	require(script.Parent.Track).offer("Upsell", "Shown")
end

-- the Starter Pack ad waits until the player has had a proper go: Products.StarterOfferAfter seconds
-- of play, the tutorial done; then it queues behind the streak card (src/client/Popups). Once per session,
-- only for a player still near the start (client/StarterCard), and only until its discount window has run out.
local joinedAt = os.clock()
local starterOffered = false
local function maybeOfferStarter()
	if starterOffered then
		return
	end
	local step = (player:GetAttribute("Tutorial") or 0) :: number
	if not StarterCard.eligible() or StarterCard.dealState() == "over" then
		starterOffered = true
		return
	end
	if os.clock() - joinedAt < Products.StarterOfferAfter or step < Onboarding.Steps.Done then
		return
	end
	starterOffered = true
	Popups.want("Starter", 2, function()
		if StarterCard.eligible() then
			offer.Visible = false
			StarterCard.show()
		end
	end, StarterCard.hide, StarterCard.isOpen)
end
Popups.addBusy(function()
	local goalsGui = playerGui:FindFirstChild("Goals")
	local sheet = goalsGui and goalsGui:FindFirstChild("GoalsSheet") :: GuiObject?
	return garage.Visible
		or store.Visible
		or offer.Visible
		or StarterCard.isOpen()
		or (sheet ~= nil and sheet.Visible)
end)

garageButton.Activated:Connect(function()
	store.Visible = false
	if garage.Visible then
		garage.Visible = false
	else
		refreshCards()
		open(garage)
		require(script.Parent.Track).opened("Garage")
		require(script.Parent.Track).viewed("Garage", chosenId)
	end
end)
storeButton.Activated:Connect(function()
	garage.Visible = false
	if store.Visible then
		store.Visible = false
	else
		refreshStore()
		require(script.Parent.Track).opened("Store")
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
-- Roblox's own invite prompt, carrying who invited (SocialService pays the bonus when the friend joins)
local inviting = false
inviteButton.Activated:Connect(function()
	if inviting then
		return
	end
	inviting = true
	local ok, can = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if ok and can then
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = SocialConfig.InviteMessage
		options.LaunchData = `invite:{player.UserId}`
		pcall(function()
			SocialService:PromptGameInvite(player, options)
		end)
	else
		popup("Invites can't be sent from here right now", "info")
	end
	inviting = false
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

-- their own screen, so they stay up while the UI ON/OFF button hides the rest (client/HideUi)
local touchGui = Instance.new("ScreenGui")
touchGui.Name = "HudTouch"
touchGui.ResetOnSpawn = false
touchGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
touchGui.Parent = playerGui
Style.fit(touchGui)

local touch = Instance.new("Frame")
touch.BackgroundTransparency = 1
touch.AnchorPoint = Vector2.new(1, 1)
touch.Position = UDim2.new(1, -20, 1, -LayoutConfig.TouchClearLarge)
touch.Size = UDim2.fromOffset(240, 154)
touch.Name = "TouchRack"
touch.Visible = false
touch.Parent = touchGui
local touchFit = Instance.new("UIScale")
touchFit.Parent = touch

-- each button's grid slot name (Config/Layout TouchSlots), filled as they are made
local slotOf: { [TextButton]: string } = {}
local wideRack: boolean? = nil

local function slotPos(slot: { number }): UDim2
	return UDim2.fromOffset(slot[1] * LayoutConfig.TouchPitch, slot[2] * LayoutConfig.TouchPitch)
end

-- thumb-sized on any screen, and above Roblox's jump button; on short screens the top row folds into a
-- column on the left so it stays off the cash box
local function placeTouch()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local s = Style.scale()
	local boost = LayoutRules.touchBoost(s, LayoutConfig.TouchMinScale)
	touchFit.Scale = boost
	local clear = LayoutRules.touchClear(cam.ViewportSize.X, cam.ViewportSize.Y, LayoutConfig)
	touch.Position = UDim2.new(1, -20, 1, -clear / s)
	local top = touchGui.AbsolutePosition.Y
	local wide = LayoutRules.touchWide(
		touchGui.AbsoluteSize.Y,
		clear,
		s * boost,
		moneyBox.AbsolutePosition.Y + moneyBox.AbsoluteSize.Y - top,
		LayoutConfig.TouchCashGap * s,
		LayoutConfig
	)
	if wide ~= wideRack then
		wideRack = wide
		local slots = if wide then LayoutConfig.TouchSlotsWide else LayoutConfig.TouchSlots
		for b, name in slotOf do
			b.Position = slotPos(slots[name])
		end
	end
end

local RIM = {
	blue = C.blue,
	gold = C.yellow,
	orange = C.orange,
	red = C.red,
	pink = C.pink,
	dark = C.yellow,
}
local function holdButton(
	text: string,
	slot: string,
	kind: string,
	down: () -> (),
	up: () -> ()
): TextButton
	-- a big key cap like the controls card's: an asphalt plate with a rim and a thick bottom lip in the
	-- button's colour (yellow for most, orange BOOST, blue FLY, pink STUCK?). The touch area is the 74 px
	-- square; the plate is drawn a little inside it so neighbours keep a clear gap.
	local b = Style.button(touch, text, "dark", 16)
	b.BackgroundTransparency = 1
	b.TextTransparency = 1 -- the label below shows the text; code keeps setting b.Text
	b.Size = UDim2.fromOffset(LayoutConfig.TouchKey, LayoutConfig.TouchKey)
	b.Position = slotPos(LayoutConfig.TouchSlots[slot])
	slotOf[b] = slot
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
	local rim = RIM[kind] or C.yellow
	Style.stroke(face, rim, 2, 0)
	Style.shadow(face, C.ink, 3)
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.BackgroundColor3 = rim
	lip.BorderSizePixel = 0
	lip.AnchorPoint = Vector2.new(0, 1)
	lip.Position = UDim2.fromScale(0, 1)
	lip.Size = UDim2.new(1, 0, 0, 7)
	lip.Parent = face
	local caption = Style.label(face, text, 16, F.display, C.text)
	caption.Size = UDim2.new(1, -6, 1, -7)
	caption.Position = UDim2.fromOffset(3, 0)
	-- a longer word in another language (¿ATORADO?) shrinks to fit the key
	caption.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 16
	fit.Parent = caption
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
local boostB = holdButton("FLY", "Fly", "blue", function()
	Drive.input.boost = true
end, function()
	Drive.input.boost = false
end)
local featureB = holdButton("HORN", "Feature", "gold", function()
	Drive.input.feature = true
end, function()
	Drive.input.feature = false
end)
local thrustB = holdButton("BOOST", "Boost", "orange", function()
	Drive.input.thrust = true
	Drive.thruster()
end, function()
	Drive.input.thrust = false
end)
local rollL = holdButton("ROLL L", "RollL", "dark", function()
	Drive.input.roll = -1
end, function()
	Drive.input.roll = 0
end)
-- first-person view: a tap toggles it
local viewB = holdButton("VIEW", "View", "dark", function()
	Cockpit.toggle()
end, function() end)
local hornB = holdButton("HONK", "Honk", "gold", function()
	Drive.horn()
end, function() end)
local rollR = holdButton("ROLL R", "RollR", "dark", function()
	Drive.input.roll = 1
end, function()
	Drive.input.roll = 0
end)
local unstuckB = holdButton("STUCK?", "Stuck", "pink", function()
	Drive.unstuck()
end, function() end)

---------------------------------------------------------------- per frame

local wasDriving = false
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
	local keyboard = s.driving and not UserInputService.TouchEnabled and not Pad.console() -- keys, not pads
	if s.driving and not wasDriving then
		onDriveStart()
	end
	wasDriving = s.driving
	controls.Visible = keyboard and controlsOpen
	keysChip.Visible = keyboard and not controlsOpen
	touch.Visible = s.driving and UserInputService.TouchEnabled
	if touch.Visible then
		placeTouch()
	end
	if not s.driving then
		hintBox.Visible = false
		return
	end
	local stats = Vehicles.ById[s.vehicleId]
	speedLabel.Text = tostring(s.speedMph)
	gearLabel.Text = if s.reverse then "R" else "D"
	gearLabel.BackgroundColor3 = if s.reverse then C.red else C.blue
	local hasJet = stats ~= nil and Vehicles.has(stats, "Jet")
	local hasThruster = stats ~= nil and Vehicles.has(stats, "Thruster")
	local feature: string? = nil
	if stats then
		for f, text in DriveHudRules.Features do
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
	local wait = math.ceil(s.unstuckIn)
	local jingleOn = Drive.view.car ~= nil
		and Drive.view.car.PrimaryPart ~= nil
		and Drive.view.car.PrimaryPart:GetAttribute("JingleOn") == true
	if keyboard then
		setRows(DriveHudRules.rows({
			feature = feature,
			jingleOn = jingleOn,
			jet = hasJet,
			thruster = hasThruster,
			unstuckWait = wait,
		}))
		if controls.Visible then
			layoutControls()
		end
	end
	if feature == "JINGLE" then
		feature = if jingleOn then "JINGLE OFF" else "JINGLE ON"
	end
	hintBox.Visible = (keyboard or Pad.console()) and not tipShown and s.stuck and wait == 0
	unstuckB.Text = if wait > 0 then tostring(wait) else "STUCK?"
	boostB.Visible = hasJet
	featureB.Visible = feature ~= nil
	featureB.Text = feature or ""
	thrustB.Visible = hasThruster
	viewB.Visible = true
	hornB.Visible = true
	viewB.Text = if Cockpit.isOn() then "OUT" else "VIEW"
	rollL.Visible = hasJet and s.airborne
	rollR.Visible = hasJet and s.airborne
end)

function Hud.start()
	Net.waitFor("Popup").OnClientEvent:Connect(popup)
	player:GetAttributeChangedSignal("Money"):Connect(function()
		refreshMoney()
		refreshCards()
	end)
	player:GetAttributeChangedSignal("Owned"):Connect(function()
		refreshCards()
		-- bought it: the "need more money" card from an earlier try is out of date
		if offerIsUpsell then
			offer.Visible = false
		end
	end)
	player:GetAttributeChangedSignal("Friends"):Connect(refreshFriends)
	refreshFriends()
	player:GetAttributeChangedSignal("Paint"):Connect(refreshCards)
	player:GetAttributeChangedSignal("Paints"):Connect(refreshCards)
	player:GetAttributeChangedSignal("GroupClaimed"):Connect(refreshStore)
	player:GetAttributeChangedSignal("Bought"):Connect(refreshStore)
	local function tutorialStep()
		local step = (player:GetAttribute("Tutorial") or 0) :: number
		goalsButton.Visible = step >= Onboarding.Steps.Goal
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
	player:GetAttributeChangedSignal("CarOfDay"):Connect(refreshCards)
	player:GetAttributeChangedSignal("VehicleId"):Connect(refreshCards)
	-- first visit: the server puts you in the starter car (server/Onboarding); if that hasn't happened by now,
	-- open the garage so it's one click away
	task.spawn(function()
		while not player:GetAttribute("DataReady") do
			task.wait(0.2)
		end
		task.wait(Onboarding.GarageFallback)
		if not Drive.state.driving and player:GetAttribute("Tutorial") == 1 then
			refreshCards()
			open(garage)
		end
	end)
end

return Hud
