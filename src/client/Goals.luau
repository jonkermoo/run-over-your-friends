--!strict
-- The goals sheet: today's and this week's challenges and their chests on top (Challenges.luau builds them), the
-- shared SERVER goal on its own card, then HOURLY and DAILY sets with reset countdowns, progress
-- and rewards. It hangs from the top left under the menu strip, opens from the GOALS tab and closes from its X, the
-- tab or B on a gamepad. Not
-- available until the tutorial's goal step. Each unfinished goal,
-- the server goal included, has a pin button that puts it on screen (PinnedGoals, up to three).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local LayoutConfig = require(ReplicatedStorage.Shared.Config.Layout)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local OnboardingRules = require(ReplicatedStorage.Shared.Rules.Onboarding)
local QuestConfig = require(ReplicatedStorage.Shared.Config.Quests)
local Challenges = require(script.Parent.Challenges)
local GiftRows = require(script.Parent.GiftRows)
local Pad = require(script.Parent.Pad)
local PinnedGoals = require(script.Parent.PinnedGoals)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local C, F = Style.colors, Style.fonts

local Goals = {}

type GoalView = { text: string, target: number, reward: number, progress: number, done: boolean }
type SetView = { goals: { GoalView }, endsAt: number }

local ORDER = { "Server", "Hourly", "Daily" }
local COLORS = { Server = C.yellow, Hourly = C.blue, Daily = C.pink }
local SHEET_W = LayoutConfig.GoalsWidth
local HEAD_H = 66 -- the title row and its lane line
local HERO_H = 112 -- the server goal's card (and the gap under it)
local SECTION_H = 42 -- an HOURLY / DAILY heading
local ROW_H = 76 -- a goal row (and the gap under it)
local PIN = 36 -- the pin button

local gui = Instance.new("ScreenGui")
gui.Name = "Goals"
gui.ResetOnSpawn = false
gui.Parent = playerGui
Style.fit(gui)

local TOP, BOTTOM_MARGIN = LayoutConfig.SheetTop, LayoutConfig.SheetBottom

-- the sheet hangs from the top left, under the menu strip and its GOALS tab
local panel = Style.panel(gui)
panel.Name = "GoalsSheet"
panel.Position = UDim2.fromOffset(14, TOP)
panel.Size = UDim2.fromOffset(SHEET_W, HEAD_H)
panel.Visible = false
Style.sign(panel, "red")
local headLine = Style.dashes(panel, C.yellow, false, 4)
headLine.Position = UDim2.fromOffset(0, HEAD_H - 6)

local title = Style.label(panel, "GOALS", 32, F.display, C.text)
title.Position = UDim2.fromOffset(16, 12)
title.Size = UDim2.fromOffset(110, 38)
title.TextXAlignment = Enum.TextXAlignment.Left
local countPill = Style.pill(panel, "0 / 0 DONE", C.gold)
countPill.TextSize = 15
countPill.Size = UDim2.fromOffset(0, 24)
countPill.AnchorPoint = Vector2.new(0, 0.5)
countPill.Position = UDim2.fromOffset(122, 31)
local close = Style.button(panel, "X", "dark", 22)
close.Name = "Close"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -10, 0, 8)
close.Size = UDim2.fromOffset(44, 44)
local closeHint = Pad.chip(panel, { Enum.KeyCode.ButtonB }, "close")
closeHint.AnchorPoint = Vector2.new(1, 0.5)
closeHint.Position = UDim2.new(1, -66, 0, 31)

-- the rows scroll when the sheet is taller than the screen has room for (phones)
local body = Instance.new("ScrollingFrame")
body.Name = "Body"
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.Position = UDim2.fromOffset(0, HEAD_H + 6)
body.Size = UDim2.fromScale(1, 0)
body.CanvasSize = UDim2.new()
body.ScrollBarThickness = 5
body.ScrollBarImageColor3 = C.yellow
body.ScrollingDirection = Enum.ScrollingDirection.Y
body.Parent = panel

local state: { [string]: SetView } = {}
local serverSet: SetView? = nil -- from its own remote; kept when the player's sets arrive
local clockOffset = 0 -- server unix time minus local unix time
local open = false
local forGifts = false -- opened from the gift chip: shows even before the tutorial's goals step
local fullUntil = 0 -- the count pill says "MAX 3 PINNED" until then, after a pin past the limit
local countdowns: { [string]: TextLabel } = {}
local function fmt(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%d:%02d", m, s)
end

-- the bar and the numbers of each goal row, updated in place while only progress changes
local rowViews: { { fill: Frame, amount: TextLabel } } = {}
local builtShape = ""

-- the screen's GUI height in layout pixels (the drawn scale undone)
local function guiHeight(): number
	local fit = gui:FindFirstChild("ScreenFit") :: UIScale?
	return gui.AbsoluteSize.Y / (if fit then fit.Scale else Style.scale())
end

-- layout pixels the whole sheet may take on this screen
local function maxHeight(): number
	return math.floor(guiHeight()) - TOP - BOTTOM_MARGIN
end

local function shape(): string
	local parts = { tostring(open), tostring(maxHeight()), Challenges.shape(), GiftRows.key() }
	for _, name in ORDER do
		local set = state[name]
		if set then
			for i, g in set.goals do
				table.insert(parts, `{name}:{g.text}:{g.done}:{PinnedGoals.isPinned(name, i)}`)
			end
		end
	end
	return table.concat(parts, "|")
end

local function tickCountdowns()
	local t = os.time() + clockOffset
	for name, cd in countdowns do
		local set = state[name]
		if set then
			local left = fmt(set.endsAt - t)
			Loc.set(
				cd,
				if name ~= "Server"
					then "GoalsNewIn"
					elseif not set.goals[1] or set.goals[1].done then "GoalsNextIn"
					else "GoalsEndsIn",
				{ time = left }
			)
		end
	end
end

local function shortNumber(n: number): string
	if n >= 10000 then
		return string.format("%.0fk", n / 1000)
	elseif n >= 1000 then
		return string.format("%.1fk", n / 1000)
	end
	return tostring(math.floor(n))
end

local function height(): number
	local h = HEAD_H + 6
	if open then
		h += Challenges.height()
		for _, name in ORDER do
			local set = state[name]
			if set then
				h += if name == "Server"
					then #set.goals * HERO_H
					else SECTION_H + #set.goals * ROW_H
			end
		end
	end
	return h + 4
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

-- a goal's progress bar: a dark track with the set's paint in lane-line dashes
local function goalBar(
	parent: Instance,
	g: GoalView,
	color: Color3,
	x: number,
	y: number,
	h: number,
	inset: number
): Frame
	local back, fill = Style.bar(parent, if g.done then C.green else color)
	back.BackgroundColor3 = C.ink
	back.BackgroundTransparency = 0
	back.Position = UDim2.fromOffset(x, y)
	back.Size = UDim2.new(1, -(x + 12 + inset), 0, h)
	Style.laneGaps(back, C.ink)
	fill.Size = UDim2.fromScale(math.clamp(g.progress / math.max(g.target, 1), 0, 1), 1)
	return fill
end

-- the pin button that puts an unfinished goal on screen (PinnedGoals, up to three)
local function pinButton(parent: Instance, name: string, i: number): TextButton
	local pinned = PinnedGoals.isPinned(name, i)
	local b = Style.button(parent, "", if pinned then "gold" else "dark", 14)
	b.Name = `Pin{name}{i}`
	b.Size = UDim2.fromOffset(PIN, PIN)
	PinnedGoals.pinIcon(b, PIN - 4, if pinned then C.ink else C.dim)
	Style.onTap(b, function()
		if PinnedGoals.toggle(name, i) == "full" then
			fullUntil = os.clock() + 2
		end
	end)
	return b
end

local function rebuild()
	builtShape = shape()
	-- a rebuild replaces every button: a gamepad selection moves to the new one with the same name
	local selected = GuiService.SelectedObject
	local keep = if selected and selected:IsDescendantOf(body) then selected.Name else nil
	body:ClearAllChildren()
	table.clear(countdowns)
	table.clear(rowViews)
	local y, done, total = 0, 0, 0
	y = GiftRows.build(body, y)
	y = Challenges.build(body, y)
	-- first day: what coming back tomorrow pays (DailyService publishes it once today's reward is in)
	local tomorrowPay = player:GetAttribute("TomorrowPays")
	if typeof(tomorrowPay) == "number" then
		local line = Style.label(body, "", 16, F.heavy, C.yellow)
		Loc.set(
			line,
			"TomorrowPays",
			{ n = player:GetAttribute("TomorrowDay") or 2, pay = Style.money(tomorrowPay) }
		)
		line.Position = UDim2.fromOffset(12, y + 6)
		line.Size = UDim2.new(1, -24, 0, 22)
		y += 32
	end
	for _, name in ORDER do
		local set = state[name]
		if not set then
			continue
		end
		local color = COLORS[name]
		if name ~= "Server" then
			-- the set's heading: its name painted in its colour, and when it renews
			local head = Style.label(body, string.upper(name), 22, F.display, C.text)
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
			countdowns[name] = cd
			y += SECTION_H
		end
		for i, g in set.goals do
			total += 1
			if g.done then
				done += 1
			end
			local pinnable = not g.done and PinnedGoals.colors[name] ~= nil
			local inset = if pinnable then PIN + 14 else 0
			local amountText = `{shortNumber(g.progress)} / {shortNumber(g.target)}`
			local row = Style.card(body)
			row.Position = UDim2.fromOffset(12, y)
			row.BackgroundTransparency = if g.done then 0.5 else 0
			local reward = Style.pill(
				row,
				if g.done then "DONE" else "$" .. shortNumber(g.reward),
				if g.done then C.green else C.gold
			)
			reward.TextSize = 15
			reward.Size = UDim2.fromOffset(0, 22)
			reward.AnchorPoint = Vector2.new(1, 0)
			local fill: Frame, amount: TextLabel
			if name == "Server" then
				-- the shared goal: a card of its own with a yellow edge and a thick bar
				row.Size = UDim2.new(1, -24, 0, HERO_H - 12)
				local edge = Instance.new("Frame")
				edge.BackgroundColor3 = color
				edge.BorderSizePixel = 0
				edge.Size = UDim2.new(0, 8, 1, 0)
				edge.Parent = row
				local kicker = label(row, "SERVER GOAL  ·  EVERYONE HERE", 14, F.heavy, color)
				kicker.Position = UDim2.fromOffset(20, 8)
				kicker.Size = UDim2.new(1, -150, 0, 18)
				local text = label(row, Loc.upper(Loc.goal(g, true)), 22, F.display, C.text)
				text.AutoLocalize = false
				text.Position = UDim2.fromOffset(20, 28)
				text.Size = UDim2.new(1, -32 - inset, 0, 26)
				text.TextScaled = true -- long shared goals shrink to fit beside the pin
				local fit = Instance.new("UITextSizeConstraint")
				fit.MaxTextSize = 22
				fit.MinTextSize = 15
				fit.Parent = text
				reward.Position = UDim2.new(1, -12 - inset, 0, 8)
				fill = goalBar(row, g, color, 20, 58, 14, 0)
				amount = label(row, amountText, 14, F.bold, C.dim)
				amount.Position = UDim2.fromOffset(20, 76)
				amount.Size = UDim2.fromOffset(160, 18)
				local cd = Style.label(row, "", 14, F.bold, C.dim)
				cd.AnchorPoint = Vector2.new(1, 0)
				cd.Position = UDim2.new(1, -12, 0, 76)
				cd.Size = UDim2.fromOffset(160, 18)
				cd.TextXAlignment = Enum.TextXAlignment.Right
				countdowns[name] = cd
				if pinnable then
					local b = pinButton(row, name, i)
					b.AnchorPoint = Vector2.new(1, 0)
					b.Position = UDim2.new(1, -12, 0, 8)
				end
				y += HERO_H
			else
				row.Size = UDim2.new(1, -24, 0, ROW_H - 8)
				local text = label(row, Loc.goal(g), 16, F.heavy, if g.done then C.dim else C.text)
				text.AutoLocalize = false
				text.Position = UDim2.fromOffset(12, 8)
				text.Size = UDim2.new(1, -100 - inset, 0, 20)
				text.TextTruncate = Enum.TextTruncate.AtEnd
				reward.Position = UDim2.new(1, -12 - inset, 0, 8)
				fill = goalBar(row, g, color, 12, 34, 10, inset)
				amount = label(row, amountText, 14, F.bold, C.dim)
				amount.Position = UDim2.fromOffset(12, 48)
				amount.Size = UDim2.fromOffset(160, 16)
				if pinnable then
					local b = pinButton(row, name, i)
					b.AnchorPoint = Vector2.new(1, 0.5)
					b.Position = UDim2.new(1, -12, 0.5, 0)
				end
				y += ROW_H
			end
			table.insert(rowViews, { fill = fill, amount = amount })
		end
		y += 2
	end
	Loc.set(countPill, "GoalsDone", { done = done, total = total })
	tickCountdowns()
	local sheetH = math.min(height(), maxHeight())
	body.CanvasSize = UDim2.fromOffset(0, y)
	body.Size = UDim2.new(1, 0, 0, sheetH - HEAD_H - 10)
	panel.Size = UDim2.fromOffset(SHEET_W, sheetH)
	if keep then
		local again = body:FindFirstChild(keep, true)
		if again and again:IsA("GuiObject") then
			GuiService.SelectedObject = again
		end
	end
end

function Goals.toggle()
	open = not open
	if not open then
		forGifts = false
	end
	if open then
		Challenges.sheetOpened()
	end
	PinnedGoals.setSheetOpen(open)
	rebuild()
end

function Goals.open()
	if not open then
		Goals.toggle()
	end
end

-- from the HUD gift chip: the sheet with its PLAY GIFTS section, even early in the tutorial
function Goals.openGifts()
	forGifts = true
	Goals.open()
end

function Goals.close()
	if open then
		Goals.toggle()
	end
end

close.Activated:Connect(Goals.close)
GiftRows.changed = function()
	if open and shape() ~= builtShape then
		rebuild()
	end
end

-- gamepad: B closes; a gamepad player starts on a chest's OPEN, else the first pin, else the X
Pad.menu(panel, {
	first = function()
		local chest = body:FindFirstChild("OpenDaily", true)
			or body:FindFirstChild("OpenWeekly", true)
		if chest and chest:IsA("GuiObject") then
			return chest
		end
		for _, d in body:GetDescendants() do
			if d:IsA("TextButton") and string.sub(d.Name, 1, 3) == "Pin" then
				return d
			end
		end
		return close
	end,
	close = Goals.close,
})

-- new state from the server: rebuild when the list changed, else just move the bars and numbers
local function apply()
	state.Server = serverSet
	if shape() ~= builtShape then
		rebuild()
		return
	end
	local i = 0
	for _, name in ORDER do
		local set = state[name]
		if set then
			for _, g in set.goals do
				i += 1
				local view = rowViews[i]
				if view then
					view.fill.Size =
						UDim2.fromScale(math.clamp(g.progress / math.max(g.target, 1), 0, 1), 1)
					view.amount.Text = `{shortNumber(g.progress)}/{shortNumber(g.target)}`
				end
			end
		end
	end
end

function Goals.start()
	Net.waitFor("Goals").OnClientEvent:Connect(function(newState, serverNow)
		if typeof(newState) == "table" then
			state = newState
			if typeof(serverNow) == "number" then
				clockOffset = serverNow - os.time()
			end
			PinnedGoals.setGoals(newState)
			apply()
		end
	end)
	Net.waitFor("ServerGoal").OnClientEvent:Connect(function(set, serverNow)
		serverSet = if typeof(set) == "table" and typeof(set.goals) == "table" then set else nil
		if typeof(serverNow) == "number" then
			clockOffset = serverNow - os.time()
		end
		PinnedGoals.setServer(serverSet, if typeof(serverNow) == "number" then serverNow else nil)
		apply()
	end)
	-- challenges or chests changed: redraw
	Challenges.changed:Connect(function()
		if open and shape() ~= builtShape then
			rebuild()
		end
	end)
	-- pins changed (here or from a card's X): redraw the pin buttons
	PinnedGoals.changed:Connect(function()
		if open then
			rebuild()
		end
	end)
	local last = 0
	RunService.RenderStepped:Connect(function()
		local step = (player:GetAttribute("Tutorial") or 99) :: number
		panel.Visible = open
			and player:GetAttribute("DataReady") == true
			and (forGifts or OnboardingRules.reached(step, Onboarding.Steps.Goal, Onboarding))
			and (forGifts or next(state) ~= nil)
		local now = os.clock()
		if now - last < 0.5 then
			return
		end
		last = now
		if open and shape() ~= builtShape then
			rebuild() -- the screen changed size: refit the sheet
		end
		tickCountdowns()
		if now < fullUntil then
			Loc.set(countPill, "MaxPinned", { n = QuestConfig.Pins.Max })
			countPill.BackgroundColor3 = C.red
		elseif countPill.BackgroundColor3 == C.red then
			countPill.BackgroundColor3 = C.gold
			rebuild()
		end
	end)
end

return Goals
