--!strict
-- The event banner (top centre): next event countdown while quiet, a pulsing warning before one starts,
-- and the live event with what it does and how long it has left. A big title flies in when it starts.
-- During a contest event a slim line under the sign shows the leader and your own place (the Contest remote,
-- once a second).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Config = require(ReplicatedStorage.Shared.Config.Events)
local Contest = require(ReplicatedStorage.Shared.Rules.Contest)
local Net = require(ReplicatedStorage.Shared.Net)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Popups = require(script.Parent.Popups)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local C, F = Style.colors, Style.fonts

local EventBanner = {}

local byKey: { [string]: Config.Event } = {}
for _, e in Config.List do
	byKey[e.key] = e
end

local gui = Instance.new("ScreenGui")
gui.Name = "EventBanner"
gui.ResetOnSpawn = false
gui.Parent = playerGui
Style.fit(gui)

-- a road sign at the top centre with painted lane lines along its top and bottom edges: one line (pill,
-- title, timer) up in the empty middle of Roblox's top bar, and during a contest one slim line under it
local Card = Config.Card
local banner = Style.panel(gui)
banner.Name = "Sign"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, Card.Gap)
banner.Size = UDim2.fromOffset(Card.QuietWidth, Card.Height)
banner.Visible = false
local topLine = Style.dashes(banner, C.yellow)
topLine.Position = UDim2.fromOffset(0, 3)
local bottomLine = Style.dashes(banner, C.yellow)
bottomLine.AnchorPoint = Vector2.new(0, 1)
bottomLine.Position = UDim2.new(0, 0, 1, -3)
local pill = Style.pill(banner, "", C.ink)
pill.AnchorPoint = Vector2.new(0, 0.5)
pill.Position = UDim2.fromOffset(14, Card.Height / 2)
local title = Style.label(banner, "", Card.TitleText, F.display, C.text)
title.AnchorPoint = Vector2.new(0, 0.5)
title.Position = UDim2.fromOffset(14, Card.Height / 2)
title.Size = UDim2.new(1, -28, 0, Card.TitleText + 4)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextTruncate = Enum.TextTruncate.AtEnd
local timer = Style.label(banner, "", Card.TimerText, F.display, C.yellow)
timer.AnchorPoint = Vector2.new(1, 0.5)
timer.Position = UDim2.new(1, -14, 0, Card.Height / 2)
timer.Size = UDim2.fromOffset(150, Card.TimerText + 4)
timer.TextXAlignment = Enum.TextXAlignment.Right

-- contest standings on one line: the leader on the left (a long name gets cut), your own place on the right
local contest = Style.label(banner, "", Card.ContestText, F.heavy, C.text)
contest.Position = UDim2.fromOffset(14, Card.Height - 6)
contest.Size = UDim2.new(1, -28, 0, Card.ContestRow)
contest.TextXAlignment = Enum.TextXAlignment.Left
contest.TextTruncate = Enum.TextTruncate.AtEnd
contest.Visible = false
local contestYou = Style.label(banner, "", Card.ContestText, F.display, C.text)
contestYou.AnchorPoint = Vector2.new(1, 0)
contestYou.Position = UDim2.new(1, -14, 0, Card.Height - 6)
contestYou.Size = UDim2.new(1, -28, 0, Card.ContestRow)
contestYou.TextXAlignment = Enum.TextXAlignment.Right
contestYou.Visible = false

type Standings = {
	key: string,
	top: { { name: string, score: number } },
	place: number,
	score: number,
	count: number,
}
local standings: Standings? = nil

-- the player can shrink the sign to a small chip with just a colour dot and the timer (X beside the
-- sign), and tap the chip to bring it back. Kept for the session; big event titles still show.
local shrunk = false
local hide = Style.button(gui, "X", "dark", 18)
hide.Name = "HideEvent"
hide.BackgroundColor3 = C.panel
hide.Size = UDim2.fromOffset(Card.Height - 4, Card.Height - 4)
hide.Visible = false
local chip = Style.button(gui, "", "dark", 18)
chip.Name = "EventChip"
chip.BackgroundColor3 = C.panel
chip.AnchorPoint = Vector2.new(0.5, 0)
chip.Position = UDim2.new(0.5, 0, 0, Card.Gap)
chip.Size = UDim2.fromOffset(112, Card.Height)
chip.Visible = false
-- the chip's icon: a diamond road sign in the event's colour with a "!" on it
local chipDot = Instance.new("Frame")
chipDot.BorderSizePixel = 0
chipDot.AnchorPoint = Vector2.new(0.5, 0.5)
chipDot.Position = UDim2.new(0, 22, 0.5, 0)
chipDot.Size = UDim2.fromOffset(18, 18)
chipDot.Rotation = 45
chipDot.ZIndex = 2
chipDot.Parent = chip
local chipMark = Style.label(chip, "!", 18, F.display, C.ink)
chipMark.AnchorPoint = Vector2.new(0.5, 0.5)
chipMark.Position = UDim2.new(0, 22, 0.5, 1)
chipMark.Size = UDim2.fromOffset(18, 22)
chipMark.ZIndex = 3
local chipTimer = Style.label(chip, "", 18, F.display, C.yellow)
chipTimer.Position = UDim2.fromOffset(40, 3)
chipTimer.Size = UDim2.new(1, -46, 1, 0)
Style.onTap(hide, function()
	shrunk = true
end)
chip.Activated:Connect(function()
	shrunk = false
end)

-- dark text on bright paint, white on dark paint
local function inkOn(color: Color3): Color3
	local lum = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return if lum > 0.5 then C.ink else C.text
end

local function paintLines(color: Color3)
	for _, line in { topLine, bottomLine } do
		for _, d in line:GetChildren() do
			if d:IsA("Frame") then
				d.BackgroundColor3 = color
			end
		end
	end
end

local sting = Instance.new("Sound")
sting.SoundId = "rbxassetid://9125648149"
sting.Volume = 0.8
sting.Parent = gui

local function fmt(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local titleUntil = 0 -- the big title is on screen until then: queued cards (daily streak) wait for it
local function showTitle(event: Config.Event)
	sting:Play()
	local color = Style.colors[event.color] or C.gold
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.3)
	holder.Size = UDim2.fromOffset(900, 130)
	holder.Rotation = -4
	holder.Parent = gui
	local back = Style.label(holder, event.title, 84, F.display, C.ink)
	back.Position = UDim2.fromOffset(7, 7)
	back.Size = UDim2.new(1, 0, 0, 92)
	local t = Style.label(holder, event.title, 84, F.display, color)
	t.Size = UDim2.new(1, 0, 0, 92)
	t.ZIndex = 2
	Style.outline(t, 4)
	local s = Style.label(holder, event.text, 20, F.heavy, C.text)
	s.BackgroundColor3 = C.ink
	s.BackgroundTransparency = 0
	s.AnchorPoint = Vector2.new(0.5, 0)
	s.Position = UDim2.new(0.5, 0, 0, 100)
	s.AutomaticSize = Enum.AutomaticSize.X
	s.Size = UDim2.fromOffset(0, 30)
	s.ZIndex = 2
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = s
	local scale = Instance.new("UIScale")
	scale.Scale = 2.5
	scale.Parent = holder
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(3, function()
		for _, l in { back, t, s } do
			TweenService
				:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
				:Play()
		end
		local stroke = t:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
		task.delay(0.6, function()
			holder:Destroy()
		end)
	end)
end

-- waits its turn for the middle of the screen (Style.stage) behind a tutorial cheer or DEMOLISHED!
local function bigTitle(event: Config.Event)
	local wait = Style.stage(Config.TitleSeconds)
	titleUntil = os.clock() + wait + Config.TitleSeconds
	task.delay(wait, showTitle, event)
end

local lastPhase, lastKey = "", ""

-- fills the contest line (the leader, then you); returns the extra height it needs
local function fillStandings(event: Config.Event, ink: Color3): number
	local c = event.contest
	local s = standings
	if not c or not s or s.key ~= event.key then
		contest.Visible, contestYou.Visible = false, false
		return 0
	end
	contest.Visible, contestYou.Visible = true, true
	contest.TextColor3, contestYou.TextColor3 = ink, ink
	local lead = s.top[1]
	if not lead then
		contest.Text = "NO SCORES YET: BE THE FIRST!"
		contestYou.Visible = false
		contest.Size = UDim2.new(1, -28, 0, Card.ContestRow)
		return Card.ContestRow - 2
	end
	local first = `1st {lead.name} {Contest.amount(lead.score, c.unit)}`
	local mine = if s.place > 0
		then `YOU: {Contest.ordinal(s.place)} OF {s.count}`
		else "YOU: NOT SCORED YET"
	contest.Text = first
	contestYou.Text = mine
	contest.Size =
		UDim2.new(1, -(28 + contestYou.TextBounds.X / Style.scale() + 12), 0, Card.ContestRow)
	return Card.ContestRow - 2
end

-- the sign's top: centred in Roblox's top bar when it fits there, else just under it
local function topY(): number
	local bar = GuiService:GetGuiInset().Y / Style.scale()
	if Card.InTopBar and bar >= Card.Height then
		return -bar + (bar - Card.Height) / 2
	end
	return Card.Gap
end

local function update()
	local phase = workspace:GetAttribute("EventPhase")
	local key = workspace:GetAttribute("EventKey")
	local endsAt = workspace:GetAttribute("EventEndsAt")
	if typeof(phase) ~= "string" or typeof(key) ~= "string" or typeof(endsAt) ~= "number" then
		banner.Visible, hide.Visible, chip.Visible = false, false, false
		return
	end
	local event = byKey[key]
	if not event then
		banner.Visible, hide.Visible, chip.Visible = false, false, false
		return
	end
	banner.Visible = not shrunk
	hide.Visible = not shrunk
	chip.Visible = shrunk
	local y = topY()
	banner.Position = UDim2.new(0.5, 0, 0, y)
	chip.Position = UDim2.new(0.5, 0, 0, y)
	local color = Style.colors[event.color] or C.gold
	local left = endsAt - workspace:GetServerTimeNow()
	-- a player still early in the tutorial isn't interrupted by the big title (the card still shows it);
	-- from the tutorial's event step on, it plays
	local step = (Players.LocalPlayer:GetAttribute("Tutorial") or 0) :: number
	local inTutorial = step < Onboarding.Steps.Event
	if phase == "live" and (lastPhase ~= "live" or lastKey ~= key) and not inTutorial then
		bigTitle(event)
	end
	lastPhase, lastKey = phase, key
	if shrunk then
		chipDot.BackgroundColor3 = if phase == "quiet" then C.grey else color
		chipMark.TextColor3 = inkOn(chipDot.BackgroundColor3)
		chipTimer.Text = fmt(if phase == "quiet" then left + Config.WarnSeconds else left)
		local blink = phase == "warn" and math.floor(os.clock() * 4) % 2 == 0
		Style.setShadow(chip, if blink then C.text else C.ink)
		return
	end

	local k = Style.scale()
	if phase == "quiet" then
		-- a slim asphalt sign: what's coming and when
		banner.Size = UDim2.fromOffset(Card.QuietWidth, Card.Height)
		banner.BackgroundColor3 = C.panel
		paintLines(C.yellow)
		pill.Visible = false
		contest.Visible, contestYou.Visible = false, false
		title.Text = "NEXT EVENT"
		title.TextColor3 = C.text
		title.Position = UDim2.fromOffset(14, Card.Height / 2)
		timer.Text = fmt(left + Config.WarnSeconds)
		timer.TextColor3 = C.yellow
		Style.setShadow(banner, C.ink)
	else
		-- warn or live: the sign is painted the event's colour
		local ink = inkOn(color)
		local extra = if phase == "live" then fillStandings(event, ink) else 0
		if phase ~= "live" then
			contest.Visible, contestYou.Visible = false, false
		end
		local wide = gui.AbsoluteSize.X >= Card.NarrowPx
		banner.Size =
			UDim2.fromOffset(if wide then Card.Width else Card.WidthNarrow, Card.Height + extra)
		banner.BackgroundColor3 = color
		paintLines(ink)
		pill.Visible = true
		pill.Text = if phase == "live" then "LIVE" else "SOON"
		pill.BackgroundColor3 = ink
		pill.TextColor3 = color
		title.Text = event.title
		title.TextColor3 = ink
		title.Position = UDim2.fromOffset(14 + pill.AbsoluteSize.X / k + 8, Card.Height / 2)
		timer.Text = (if phase == "live" then "ENDS " else "IN ") .. fmt(left)
		timer.TextColor3 = ink
		-- the warning blinks its shadow
		local blink = phase == "warn" and math.floor(os.clock() * 4) % 2 == 0
		Style.setShadow(banner, if blink then C.text else C.ink)
	end
	-- the title stops short of the timer
	title.Size = UDim2.new(
		1,
		-(title.Position.X.Offset + timer.TextBounds.X / k + 22),
		0,
		Card.TitleText + 4
	)
	-- the X sits just right of the sign's top line
	hide.Position =
		UDim2.new(0.5, banner.Size.X.Offset / 2 + 8, 0, y + (Card.Height - hide.Size.Y.Offset) / 2)
end

function EventBanner.start()
	Popups.addBusy(function()
		return os.clock() < titleUntil
	end)
	Net.waitFor("Contest").OnClientEvent:Connect(function(state: Standings)
		standings = state
	end)
	RunService.RenderStepped:Connect(function()
		update()
	end)
end

return EventBanner
