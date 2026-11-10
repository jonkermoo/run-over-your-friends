--!strict
-- The goals sheet: the shared SERVER goal, then HOURLY and DAILY sets with reset countdowns, progress and rewards. It drops down
-- under the menu strip (top left) from the GOALS tab and closes from its header or the tab. Not
-- available until the tutorial's goal step, which puts a first goal to claim on top. Each unfinished goal,
-- the server goal included, has a pin button that puts it on screen (PinnedGoals, up to three).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local QuestConfig = require(ReplicatedStorage.Shared.Config.Quests)
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
local SHEET_W = 330
local ROW_H, HEAD_H, SECTION_H = 52, 46, 30
local CLAIM_H = 66

local gui = Instance.new("ScreenGui")
gui.Name = "Goals"
gui.ResetOnSpawn = false
gui.Parent = playerGui
Style.fit(gui)

local TOP, BOTTOM_MARGIN = 68, 18

local panel = Style.panel(gui)
panel.Name = "GoalsSheet"
panel.Position = UDim2.fromOffset(14, TOP)
panel.Size = UDim2.fromOffset(SHEET_W, HEAD_H)
panel.Visible = false
Style.setShadow(panel, C.blue)
local headLine = Style.dashes(panel, C.yellow)
headLine.Position = UDim2.fromOffset(0, HEAD_H - 3)

local header = Instance.new("TextButton")
header.BackgroundTransparency = 1
header.Text = ""
header.Size = UDim2.new(1, 0, 0, HEAD_H)
header.Parent = panel
local title = Style.label(header, "GOALS", 24, F.display, C.text)
title.Position = UDim2.fromOffset(16, 0)
title.Size = UDim2.new(1, -110, 1, 0)
title.TextXAlignment = Enum.TextXAlignment.Left
Style.outline(title, 1.5)
local countPill = Style.pill(header, "0 / 0", C.gold)
countPill.AnchorPoint = Vector2.new(1, 0.5)
countPill.Position = UDim2.new(1, -44, 0.5, 0)
local chevron = Style.label(header, "X", 22, F.display, C.text)
chevron.AnchorPoint = Vector2.new(1, 0.5)
chevron.Position = UDim2.new(1, -12, 0.5, 0)
chevron.Size = UDim2.fromOffset(24, 24)

-- the rows scroll when the sheet is taller than the screen has room for (phones)
local body = Instance.new("ScrollingFrame")
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.Position = UDim2.fromOffset(0, HEAD_H)
body.Size = UDim2.fromScale(1, 0)
body.CanvasSize = UDim2.new()
body.ScrollBarThickness = 4
body.ScrollBarImageColor3 = C.yellow
body.ScrollingDirection = Enum.ScrollingDirection.Y
body.Parent = panel

local state: { [string]: SetView } = {}
local serverSet: SetView? = nil -- from its own remote; kept when the player's sets arrive
local clockOffset = 0 -- server unix time minus local unix time
local open = false
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

-- the tutorial's goal step: a first goal to claim sits on top of the sheet
local function claiming(): boolean
	return player:GetAttribute("Tutorial") == Onboarding.Steps.Goal
end

-- layout pixels the whole sheet may take on this screen
local function maxHeight(): number
	return math.floor(gui.AbsoluteSize.Y / Style.scale()) - TOP - BOTTOM_MARGIN
end

local function shape(): string
	local parts = { tostring(open), tostring(claiming()), tostring(maxHeight()) }
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
			cd.Text = if name ~= "Server"
				then "new in " .. left
				elseif not set.goals[1] or set.goals[1].done then "next in " .. left
				else "ends in " .. left
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
	local h = HEAD_H
	if open then
		if claiming() then
			h += CLAIM_H
		end
		for _, name in ORDER do
			local set = state[name]
			if set then
				h += SECTION_H + #set.goals * ROW_H + 6
			end
		end
	end
	return h + 6
end

local function rebuild()
	builtShape = shape()
	body:ClearAllChildren()
	table.clear(countdowns)
	table.clear(rowViews)
	local y, done, total = 0, 0, 0
	if claiming() then
		local row = Style.card(body, 12)
		row.Name = "TutorialGoal"
		row.Position = UDim2.fromOffset(10, 8)
		row.Size = UDim2.new(1, -20, 0, CLAIM_H - 12)
		Style.stroke(row, C.gold, 2, 0)
		local text = Style.label(row, "Your first goal: open GOALS!", 15, F.heavy, C.text)
		text.Position = UDim2.fromOffset(12, 0)
		text.Size = UDim2.new(1, -130, 1, 0)
		text.TextWrapped = true
		text.TextXAlignment = Enum.TextXAlignment.Left
		local claim =
			Style.button(row, `CLAIM ${Onboarding.Rewards[Onboarding.Steps.Goal]}`, "green", 15)
		claim.Name = "TutorialClaim"
		claim.AnchorPoint = Vector2.new(1, 0.5)
		claim.Position = UDim2.new(1, -8, 0.5, 0)
		claim.Size = UDim2.fromOffset(112, 38)
		claim.Activated:Connect(function()
			Net.waitFor("TutorialClaim"):FireServer()
			Goals.close()
		end)
		y += CLAIM_H
	end
	for _, name in ORDER do
		local set = state[name]
		if set then
			local pill = Style.pill(body, string.upper(name), COLORS[name])
			pill.Position = UDim2.fromOffset(14, y + 6)
			local cd = Style.label(body, "", 13, F.bold, C.dim)
			cd.AnchorPoint = Vector2.new(1, 0)
			cd.Position = UDim2.new(1, -16, 0, y + 6)
			cd.Size = UDim2.fromOffset(140, 18)
			cd.TextXAlignment = Enum.TextXAlignment.Right
			countdowns[name] = cd
			y += SECTION_H
			for i, g in set.goals do
				total += 1
				if g.done then
					done += 1
				end
				-- unfinished goals get a pin button at the right; the rest of the row
				-- moves over for it
				local pinnable = not g.done and PinnedGoals.colors[name] ~= nil
				local inset = if pinnable then 32 else 0
				local row = Style.card(body, 12)
				row.Position = UDim2.fromOffset(10, y)
				row.Size = UDim2.new(1, -20, 0, ROW_H - 6)
				row.BackgroundTransparency = if g.done then 0.5 else 0
				local text = Style.label(row, g.text, 15, F.heavy, if g.done then C.dim else C.text)
				text.Position = UDim2.fromOffset(12, 5)
				text.Size = UDim2.new(1, -90 - inset, 0, 18)
				text.TextXAlignment = Enum.TextXAlignment.Left
				text.TextTruncate = Enum.TextTruncate.AtEnd
				local reward = Style.pill(
					row,
					if g.done then "DONE" else "$" .. shortNumber(g.reward),
					if g.done then C.green else C.gold
				)
				reward.AnchorPoint = Vector2.new(1, 0)
				reward.Position = UDim2.new(1, -10 - inset, 0, 6)
				local back, fill = Style.bar(row, if g.done then C.green else COLORS[name])
				back.BackgroundColor3 = C.panel
				back.BackgroundTransparency = 0
				back.Position = UDim2.fromOffset(12, 29)
				back.Size = UDim2.new(1, -86 - inset, 0, 6)
				Style.laneGaps(back, C.card)
				fill.Size = UDim2.fromScale(math.clamp(g.progress / math.max(g.target, 1), 0, 1), 1)
				local amount = Style.label(
					row,
					`{shortNumber(g.progress)}/{shortNumber(g.target)}`,
					12,
					F.bold,
					C.dim
				)
				amount.AnchorPoint = Vector2.new(1, 0)
				amount.Position = UDim2.new(1, -10 - inset, 0, 24)
				amount.Size = UDim2.fromOffset(66, 14)
				amount.TextXAlignment = Enum.TextXAlignment.Right
				if pinnable then
					local pinned = PinnedGoals.isPinned(name, i)
					local pinButton = Style.button(row, "", if pinned then "gold" else "dark", 14)
					pinButton.Name = `Pin{name}{i}`
					pinButton.AnchorPoint = Vector2.new(1, 0.5)
					pinButton.Position = UDim2.new(1, -8, 0.5, 0)
					pinButton.Size = UDim2.fromOffset(26, 26)
					PinnedGoals.pinIcon(pinButton, 16, if pinned then C.ink else C.dim)
					local setName, index = name, i
					Style.onTap(pinButton, function()
						if PinnedGoals.toggle(setName, index) == "full" then
							fullUntil = os.clock() + 2
						end
					end)
				end
				table.insert(rowViews, { fill = fill, amount = amount })
				y += ROW_H
			end
			y += 6
		end
	end
	countPill.Text = `{done} / {total}`
	tickCountdowns()
	local sheetH = math.min(height(), maxHeight())
	body.CanvasSize = UDim2.fromOffset(0, y)
	body.Size = UDim2.new(1, 0, 0, sheetH - HEAD_H - 6)
	panel.Size = UDim2.fromOffset(SHEET_W, sheetH)
end

function Goals.toggle()
	open = not open
	PinnedGoals.setSheetOpen(open)
	rebuild()
end

function Goals.close()
	if open then
		Goals.toggle()
	end
end

header.Activated:Connect(Goals.toggle)

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
			and step >= Onboarding.Steps.Goal
			and next(state) ~= nil
		local now = os.clock()
		if now - last < 0.5 then
			return
		end
		last = now
		tickCountdowns()
		if now < fullUntil then
			countPill.Text = `MAX {QuestConfig.Pins.Max} PINNED`
			countPill.BackgroundColor3 = C.red
		elseif countPill.BackgroundColor3 == C.red then
			countPill.BackgroundColor3 = C.gold
			rebuild()
		end
	end)
end

return Goals
