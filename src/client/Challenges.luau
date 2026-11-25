--!strict
-- Daily and weekly challenges on the client (server/ChallengeService, Config/Challenges):
-- - their section at the top of the GOALS sheet: today's three with a countdown to the new ones, this week's one,
--   and the chests waiting to be opened, each with an OPEN button (Goals.luau calls Challenges.build);
-- - the chest card in the middle of the screen: the chest shakes, bursts open and shows what it held;
-- - on join, a card saying today's challenges are new (or that chests are waiting), through the Popups queue,
--   and a mark on the GOALS tab until the sheet is opened (or while chests wait).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cfg = require(ReplicatedStorage.Shared.Config.Challenges)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local PaintConfig = require(ReplicatedStorage.Shared.Config.Paints)
local Rules = require(ReplicatedStorage.Shared.Rules.Challenges)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Pad = require(script.Parent.Pad)
local Popups = require(script.Parent.Popups)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local C, F = Style.colors, Style.fonts

local Challenges = {}

type View = {
	id: string,
	kind: string,
	text: string,
	target: number,
	car: string?,
	progress: number,
	done: boolean,
}
type State = {
	daily: { View },
	dailyEnds: number,
	weekly: { View },
	weeklyEnds: number,
	chests: { Daily: number, Weekly: number },
	day: number,
}

local SECTION_H = 42
local ROW_H = 76
local CHEST_H = 64
local DAILY_COLOR, WEEKLY_COLOR = C.purple, C.orange

local state: State? = nil
local clockOffset = 0
local changed = Instance.new("BindableEvent")
Challenges.changed = changed.Event -- the section's rows or chests changed: the sheet rebuilds
Challenges.onOpenGoals = nil :: (() -> ())? -- set by init: opens the GOALS sheet

-- the rows built in the sheet, updated in place while only progress moves
local views: { { fill: Frame, amount: TextLabel, view: View } } = {}
local countdowns: { daily: TextLabel?, weekly: TextLabel? } = {}
local seen = { sheet = false, nudged = false }

local function fmt(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d, h, m =
		math.floor(seconds / 86400), math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	elseif h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%d:%02d", m, seconds % 60)
end

local function number(n: number): string
	if n ~= math.floor(n) then
		return string.format("%.1f", n)
	elseif n >= 1000 then
		return string.format("%.1fk", n / 1000)
	end
	return tostring(n)
end

-- each template's Lines.csv key: its own line, or Challenge_<id>
local lineKeys: { [string]: string } = {}
for _, slot in Cfg.Daily.Slots do
	for _, t in slot do
		lineKeys[t.id] = t.line or ("Challenge_" .. t.id)
	end
end
for _, t in Cfg.Weekly do
	lineKeys[t.id] = t.line or ("Challenge_" .. t.id)
end

-- a challenge's line in the player's language, with its target and car
local function line(v: View): string
	local key = lineKeys[v.id]
	if not key then
		return v.text
	end
	local car = if v.car and Vehicles.ById[v.car] then Vehicles.ById[v.car].name else ""
	local out = Loc.text(key, { n = tostring(v.target), car = car })
	return if out == key then v.text else out
end

local function label(
	parent: Instance,
	text: string,
	size: number,
	font: Font,
	color: Color3
): TextLabel
	local l = Style.label(parent, text, size, font, color)
	l.TextXAlignment = Enum.TextXAlignment.Left
	return l
end

---------------- the GOALS sheet's section

function Challenges.shape(): string
	local s = state
	if not s then
		return "none"
	end
	local parts = { tostring(s.day), tostring(s.chests.Daily), tostring(s.chests.Weekly) }
	for _, list in { s.daily, s.weekly } do
		for _, v in list do
			table.insert(parts, `{v.id}:{v.target}:{v.done}`)
		end
	end
	return table.concat(parts, "|")
end

local function chestRows(s: State): number
	return (if s.chests.Daily > 0 then 1 else 0) + (if s.chests.Weekly > 0 then 1 else 0)
end

function Challenges.height(): number
	local s = state
	if not s then
		return 0
	end
	return 2 * SECTION_H + (#s.daily + #s.weekly) * ROW_H + chestRows(s) * CHEST_H + 4
end

local function heading(
	body: Instance,
	y: number,
	text: string,
	color: Color3,
	ink: Color3
): TextLabel
	local head = Style.label(body, text, 22, F.display, ink)
	head.BackgroundColor3 = color
	head.BackgroundTransparency = 0
	head.AutomaticSize = Enum.AutomaticSize.X
	head.Position = UDim2.fromOffset(12, y + 4)
	head.Size = UDim2.fromOffset(0, 30)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 4)
	pad.Parent = head
	local cd = Style.label(body, "", 14, F.bold, C.dim)
	cd.AnchorPoint = Vector2.new(1, 0)
	cd.Position = UDim2.new(1, -14, 0, y + 10)
	cd.Size = UDim2.fromOffset(160, 18)
	cd.TextXAlignment = Enum.TextXAlignment.Right
	return cd
end

local function row(body: Instance, y: number, v: View, color: Color3, prize: string)
	local r = Style.card(body)
	r.Name = "Challenge" .. v.id
	r.Position = UDim2.fromOffset(12, y)
	r.Size = UDim2.new(1, -24, 0, ROW_H - 8)
	r.BackgroundTransparency = if v.done then 0.5 else 0
	local text = label(r, line(v), 16, F.heavy, if v.done then C.dim else C.text)
	text.AutoLocalize = false
	text.Position = UDim2.fromOffset(12, 8)
	text.Size = UDim2.new(1, -130, 0, 20)
	text.TextTruncate = Enum.TextTruncate.AtEnd
	local pill = Style.pill(r, if v.done then "DONE" else prize, if v.done then C.green else color)
	pill.TextSize = 15
	pill.Size = UDim2.fromOffset(0, 22)
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.new(1, -12, 0, 8)
	local back, fill = Style.bar(r, if v.done then C.green else color)
	back.BackgroundColor3 = C.ink
	back.BackgroundTransparency = 0
	back.Position = UDim2.fromOffset(12, 34)
	back.Size = UDim2.new(1, -24, 0, 10)
	Style.laneGaps(back, C.ink)
	fill.Size = UDim2.fromScale(math.clamp(v.progress / math.max(v.target, 1), 0, 1), 1)
	local amount = label(r, `{number(v.progress)} / {number(v.target)}`, 14, F.bold, C.dim)
	amount.AutoLocalize = false
	amount.Position = UDim2.fromOffset(12, 48)
	amount.Size = UDim2.fromOffset(200, 16)
	table.insert(views, { fill = fill, amount = amount, view = v })
end

local function chestRow(body: Instance, y: number, set: "Daily" | "Weekly", count: number)
	local r = Style.card(body)
	r.Name = set .. "Chests"
	r.Position = UDim2.fromOffset(12, y)
	r.Size = UDim2.new(1, -24, 0, CHEST_H - 8)
	Style.stroke(r, if set == "Daily" then DAILY_COLOR else WEEKLY_COLOR, 2, 0)
	local name =
		label(r, if set == "Daily" then "DAILY CHEST" else "WEEKLY CHEST", 20, F.display, C.text)
	name.Position = UDim2.fromOffset(12, 6)
	name.Size = UDim2.new(1, -150, 0, 24)
	name.AutomaticSize = Enum.AutomaticSize.None
	local holds = label(r, "", 12, F.bold, C.dim)
	holds.Position = UDim2.fromOffset(12, 32)
	holds.Size = UDim2.new(1, -150, 0, 16)
	holds.TextTruncate = Enum.TextTruncate.AtEnd
	if set == "Daily" then
		Loc.set(
			holds,
			"ChestDailyHolds",
			{ pct = tostring(math.floor(Rules.odds("Daily", Cfg).paint * 100 + 0.5)) }
		)
	else
		Loc.set(holds, "ChestWeeklyHolds", { n = Style.money(Cfg.Chests.Weekly.Cash[1].amount) })
	end
	local open = Style.button(r, "OPEN", "gold", 20)
	open.Name = "Open" .. set
	open.AnchorPoint = Vector2.new(1, 0.5)
	open.Position = UDim2.new(1, -12, 0.5, 0)
	open.Size = UDim2.fromOffset(110, 40)
	local badge = Style.pill(open, "x" .. count, C.pink)
	badge.AutoLocalize = false
	badge.TextSize = 14
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(0, 0, 0, 0)
	badge.Size = UDim2.fromOffset(0, 20)
	badge.ZIndex = 3
	Style.onTap(open, function()
		Challenges.open(set)
	end)
end

-- build the section into the sheet's body from y; returns the y under it
function Challenges.build(body: Instance, y: number): number
	table.clear(views)
	countdowns.daily, countdowns.weekly = nil, nil
	local s = state
	if not s then
		return y
	end
	countdowns.daily = heading(body, y, "CHALLENGES", DAILY_COLOR, C.text)
	y += SECTION_H
	for _, v in s.daily do
		row(body, y, v, DAILY_COLOR, "CHEST")
		y += ROW_H
	end
	countdowns.weekly = heading(body, y, "THIS WEEK", WEEKLY_COLOR, C.ink)
	y += SECTION_H
	for _, v in s.weekly do
		row(body, y, v, WEEKLY_COLOR, "BIG CHEST")
		y += ROW_H
	end
	if s.chests.Daily > 0 then
		chestRow(body, y, "Daily", s.chests.Daily)
		y += CHEST_H
	end
	if s.chests.Weekly > 0 then
		chestRow(body, y, "Weekly", s.chests.Weekly)
		y += CHEST_H
	end
	Challenges.tick()
	return y + 4
end

-- the countdowns to the new day's and week's challenges
function Challenges.tick()
	local s = state
	if not s then
		return
	end
	local now = os.time() + clockOffset
	if countdowns.daily and countdowns.daily.Parent then
		Loc.set(countdowns.daily, "GoalsNewIn", { time = fmt(s.dailyEnds - now) })
	end
	if countdowns.weekly and countdowns.weekly.Parent then
		Loc.set(countdowns.weekly, "GoalsEndsIn", { time = fmt(s.weeklyEnds - now) })
	end
end

-- the sheet was opened: today's challenges aren't news any more
function Challenges.sheetOpened()
	seen.sheet = true
end

---------------- the chest card

local gui = Instance.new("ScreenGui")
gui.Name = "ChestCard"
gui.ResetOnSpawn = false
gui.DisplayOrder = 7
gui.Parent = playerGui
Style.fit(gui)

local W, H = 420, 380
local card = Style.panel(gui)
card.Name = "ChestCard"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(W, H)
card.Visible = false
Style.stroke(card, C.yellow, 4, 0)
local cardScale = Instance.new("UIScale")
cardScale.Parent = card
Style.hazard(card, W, 14)

local cardTitle = Style.label(card, "DAILY CHEST", 40, F.display, C.yellow)
cardTitle.Position = UDim2.fromOffset(0, 24)
cardTitle.Size = UDim2.new(1, 0, 0, 44)
Style.outline(cardTitle, 2)

-- the chest, drawn: a box with bands and a lid that flies off
local chest = Instance.new("Frame")
chest.Name = "Chest"
chest.BackgroundTransparency = 1
chest.AnchorPoint = Vector2.new(0.5, 0.5)
chest.Position = UDim2.fromOffset(W / 2, 175)
chest.Size = UDim2.fromOffset(150, 120)
chest.Parent = card
local function block(
	parent: Instance,
	color: Color3,
	x: number,
	y: number,
	w: number,
	h: number
): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.Parent = parent
	Style.stroke(f, C.ink, 3, 0)
	return f
end
local wood = Color3.fromRGB(150, 84, 40)
local box = block(chest, wood, 5, 46, 140, 74)
block(box, C.yellow, 20, -2, 14, 78)
block(box, C.yellow, 106, -2, 14, 78)
local lid = block(chest, wood, 0, 14, 150, 36)
lid.Name = "Lid"
block(lid, C.yellow, 25, -2, 14, 40)
block(lid, C.yellow, 111, -2, 14, 40)
local lock = block(chest, C.yellow, 63, 38, 24, 26)
local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.AnchorPoint = Vector2.new(0.5, 0.5)
flash.Position = UDim2.fromScale(0.5, 0.5)
flash.BackgroundColor3 = C.yellow
flash.BorderSizePixel = 0
flash.Rotation = 45
flash.Visible = false
flash.Parent = chest

-- what it held
local prize = Instance.new("Frame")
prize.Name = "Prize"
prize.BackgroundTransparency = 1
prize.Position = UDim2.fromOffset(0, 96)
prize.Size = UDim2.new(1, 0, 0, 190)
prize.Visible = false
prize.Parent = card
local prizeScale = Instance.new("UIScale")
prizeScale.Parent = prize
local cashIcon = Style.image(prize, Icons.Bill)
cashIcon.AnchorPoint = Vector2.new(0.5, 0)
cashIcon.Position = UDim2.new(0.5, 0, 0, 6)
cashIcon.Size = UDim2.fromOffset(96, 96)
local swatch = Instance.new("Frame")
swatch.Name = "Swatch"
swatch.AnchorPoint = Vector2.new(0.5, 0)
swatch.Position = UDim2.new(0.5, 0, 0, 14)
swatch.Size = UDim2.fromOffset(120, 80)
swatch.BorderSizePixel = 0
swatch.Parent = prize
local swatchEdge = Style.stroke(swatch, C.ink, 4, 0)
local prizeBig = Style.label(prize, "", 40, F.display, C.money)
prizeBig.AutoLocalize = false
prizeBig.Position = UDim2.fromOffset(0, 108)
prizeBig.Size = UDim2.new(1, 0, 0, 44)
Style.outline(prizeBig, 2)
local prizeSmall = Style.label(prize, "", 16, F.bold, C.text)
prizeSmall.Position = UDim2.fromOffset(20, 154)
prizeSmall.Size = UDim2.new(1, -40, 0, 40)
prizeSmall.TextWrapped = true

local nice = Style.button(card, "NICE!", "gold", 28)
nice.Name = "Nice"
nice.AnchorPoint = Vector2.new(0.5, 1)
nice.Position = UDim2.new(0.5, 0, 1, -20)
nice.Size = UDim2.fromOffset(220, 54)
nice.Visible = false

local opening = { set = "", token = 0, startedAt = 0 }

local function tween(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad), props):Play()
end

local function resetChest()
	chest.Visible = true
	chest.Rotation = 0
	lid.Position = UDim2.fromOffset(0, 14)
	lid.Rotation = 0
	lid.BackgroundTransparency = 0
	lid.Visible = true
	lock.Visible = true
	flash.Visible = false
	prize.Visible = false
	nice.Visible = false
end

local function closeCard()
	card.Visible = false
	opening.token += 1
end
nice.Activated:Connect(closeCard)
Pad.menu(card, {
	first = function()
		return nice
	end,
	close = closeCard,
})

-- open a chest of `set`: the card comes up shaking until the server says what was inside
function Challenges.open(set: "Daily" | "Weekly")
	local s = state
	if not s or s.chests[set] <= 0 or card.Visible then
		return
	end
	opening.set = set
	opening.token += 1
	opening.startedAt = os.clock()
	local token = opening.token
	resetChest()
	cardTitle.Text = if set == "Daily" then "DAILY CHEST" else "WEEKLY CHEST"
	cardTitle.TextColor3 = if set == "Daily" then C.yellow else C.orange
	card.Visible = true
	cardScale.Scale = 0.8
	tween(cardScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	Net.waitFor("OpenChest"):FireServer(set)
	-- shake while waiting
	task.spawn(function()
		local t = 0
		while opening.token == token and not prize.Visible and t < 6 do
			t += task.wait()
			chest.Rotation = math.sin(t * 40) * math.min(t * 8, 7)
		end
		chest.Rotation = 0
		if opening.token == token and not prize.Visible then
			closeCard() -- no answer: nothing was opened
		end
	end)
end

local function reveal(set: string, cash: number, paintId: string)
	if not card.Visible or set ~= opening.set then
		return
	end
	local token = opening.token
	-- shake a moment at least, so the burst lands
	local wait = 0.8 - (os.clock() - opening.startedAt)
	if wait > 0 then
		task.wait(wait)
	end
	if opening.token ~= token then
		return
	end
	tween(
		lid,
		0.35,
		{ Position = UDim2.fromOffset(-30, -70), Rotation = -35, BackgroundTransparency = 1 }
	)
	lock.Visible = false
	flash.Visible = true
	flash.Size = UDim2.fromOffset(20, 20)
	flash.BackgroundTransparency = 0
	tween(flash, 0.35, { Size = UDim2.fromOffset(260, 260), BackgroundTransparency = 1 })
	task.wait(0.3)
	if opening.token ~= token then
		return
	end
	chest.Visible = false
	local paint = PaintConfig.ById[paintId]
	cashIcon.Visible = paint == nil
	swatch.Visible = paint ~= nil
	if paint then
		local rgb = paint.rgb or { 255, 255, 255 }
		swatch.BackgroundColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		swatchEdge.Color = if paint.material == "Neon" then swatch.BackgroundColor3 else C.ink
		prizeBig.Text = Loc.upper(Loc.source(paint.name))
		prizeBig.TextColor3 = C.yellow
		if cash > 0 then
			Loc.set(prizeSmall, "ChestPaintAndCash", { n = Style.money(cash) })
		else
			prizeSmall.AutoLocalize = true
			prizeSmall.Text = "New paint! Put it on any car in the GARAGE"
		end
	else
		prizeBig.Text = "+" .. Style.money(cash)
		prizeBig.TextColor3 = C.money
		prizeSmall.Text = ""
	end
	prize.Visible = true
	prizeScale.Scale = 0.4
	tween(prizeScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	nice.Visible = true
end

---------------- the join card and the GOALS tab mark

local NUDGE_W, NUDGE_H = 440, 210
local ngui = Instance.new("ScreenGui")
ngui.Name = "ChallengeNudge"
ngui.ResetOnSpawn = false
ngui.DisplayOrder = 5
ngui.Parent = playerGui
Style.fit(ngui)
local nudge = Style.panel(ngui)
nudge.Name = "NudgeCard"
nudge.AnchorPoint = Vector2.new(0.5, 0.5)
nudge.Position = UDim2.fromScale(0.5, 0.5)
nudge.Size = UDim2.fromOffset(NUDGE_W, NUDGE_H)
nudge.Visible = false
Style.stroke(nudge, C.yellow, 4, 0)
Style.hazard(nudge, NUDGE_W, 12)
local nTitle = Style.label(nudge, "DAILY CHALLENGES", 34, F.display, C.yellow)
nTitle.Position = UDim2.fromOffset(0, 26)
nTitle.Size = UDim2.new(1, 0, 0, 40)
Style.outline(nTitle, 2)
local nSub = Style.label(nudge, "", 17, F.bold, C.text)
nSub.Position = UDim2.fromOffset(20, 72)
nSub.Size = UDim2.new(1, -40, 0, 48)
nSub.TextWrapped = true
local nGo = Style.button(nudge, "GOALS", "gold", 24)
nGo.Name = "NudgeGoals"
nGo.AnchorPoint = Vector2.new(1, 1)
nGo.Position = UDim2.new(0.5, -8, 1, -20)
nGo.Size = UDim2.fromOffset(170, 50)
local nLater = Style.button(nudge, "LATER", "dark", 22)
Style.closeX(nudge, function()
	Popups.snooze("Challenges")
end)
nLater.Name = "NudgeLater"
nLater.AnchorPoint = Vector2.new(0, 1)
nLater.Position = UDim2.new(0.5, 8, 1, -20)
nLater.Size = UDim2.fromOffset(170, 50)
nGo.Activated:Connect(function()
	nudge.Visible = false
	if Challenges.onOpenGoals then
		Challenges.onOpenGoals()
	end
end)
nLater.Activated:Connect(function()
	nudge.Visible = false
end)
Pad.menu(nudge, {
	first = function()
		return nGo
	end,
	close = function()
		nudge.Visible = false
	end,
})

local function fresh(s: State): boolean
	for _, v in s.daily do
		if v.done or v.progress > 0 then
			return false
		end
	end
	return true
end

local function waiting(s: State): number
	return s.chests.Daily + s.chests.Weekly
end

-- once a session, after the tutorial: today's challenges are untouched, or chests wait
local function maybeNudge()
	local s = state
	local step = (player:GetAttribute("Tutorial") or 0) :: number
	if seen.nudged or not s or step < Onboarding.Steps.Done then
		return
	end
	local chests = waiting(s)
	if not fresh(s) and chests == 0 then
		return
	end
	seen.nudged = true
	Popups.want("Challenges", 3, function()
		-- the words as things stand when it opens: chests first, else today's challenges
		local now = state or s
		local count = waiting(now)
		if count > 0 then
			Loc.set(nSub, "ChestsWaiting", { n = tostring(count) })
		else
			Loc.set(nSub, "ChallengesNew", { n = tostring(#now.daily) })
		end
		nudge.Visible = true
	end, function()
		nudge.Visible = false
	end, function()
		return nudge.Visible
	end)
end

-- a mark on the GOALS tab: chests wait, or today's challenges are new and the sheet wasn't opened yet
local mark: Frame? = nil
local function updateMark()
	local s = state
	if not mark then
		local hud = playerGui:FindFirstChild("Hud")
		local tab = hud and hud:FindFirstChild("GoalsButton", true)
		if not tab then
			return
		end
		local m = Instance.new("Frame")
		m.Name = "ChallengeMark"
		m.AnchorPoint = Vector2.new(0.5, 0.5)
		m.Position = UDim2.new(1, -2, 0, 2)
		m.Size = UDim2.fromOffset(14, 14)
		m.Rotation = 45
		m.BackgroundColor3 = C.pink
		m.BorderSizePixel = 0
		m.ZIndex = 5
		Style.stroke(m, C.ink, 2, 0)
		m.Parent = tab
		mark = m
	end
	local m = mark :: Frame
	m.Visible = s ~= nil and (waiting(s) > 0 or (fresh(s) and not seen.sheet))
end

function Challenges.start()
	Net.waitFor("Challenges").OnClientEvent:Connect(function(newState, serverNow)
		if typeof(newState) ~= "table" or typeof(newState.daily) ~= "table" then
			return
		end
		local before = Challenges.shape()
		local s = newState :: State
		if state and state.day ~= s.day then
			seen.sheet = false -- a new day: new challenges to see
		end
		state = s
		if typeof(serverNow) == "number" then
			clockOffset = serverNow - os.time()
		end
		if Challenges.shape() ~= before then
			changed:Fire()
		else
			-- only progress moved: the bars and numbers in place
			local all = {}
			for _, v in s.daily do
				all[v.id] = v
			end
			for _, v in s.weekly do
				all[v.id] = v
			end
			for _, rv in views do
				local v = all[rv.view.id]
				if v and rv.fill.Parent then
					rv.fill.Size =
						UDim2.fromScale(math.clamp(v.progress / math.max(v.target, 1), 0, 1), 1)
					rv.amount.Text = `{number(v.progress)} / {number(v.target)}`
				end
			end
		end
		maybeNudge()
		updateMark()
	end)
	Net.waitFor("ChestPrize").OnClientEvent:Connect(function(set, cash, paint)
		if typeof(set) == "string" and typeof(cash) == "number" and typeof(paint) == "string" then
			task.spawn(reveal, set, cash, paint)
		end
	end)
	player:GetAttributeChangedSignal("Tutorial"):Connect(maybeNudge)
	local last = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - last < 0.5 then
			return
		end
		last = now
		Challenges.tick()
		updateMark()
	end)
end

return Challenges
