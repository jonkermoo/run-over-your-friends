--!strict
-- The goals panel (right side): HOURLY and DAILY sets with reset countdowns, progress and rewards.
-- Hidden until the tutorial is done, so new players see one goal at a time. Collapses to its header.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local C, F = Style.colors, Style.fonts

local Goals = {}

type GoalView = { text: string, target: number, reward: number, progress: number, done: boolean }
type SetView = { goals: { GoalView }, endsAt: number }

local ORDER = { "Hourly", "Daily" }
local COLORS = { Hourly = C.blue, Daily = C.purple }
local ROW_H, HEAD_H, SECTION_H = 52, 46, 30

local gui = Instance.new("ScreenGui")
gui.Name = "Goals"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local panel = Style.panel(gui, 18)
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -14, 0.24, 0)
panel.Size = UDim2.fromOffset(310, HEAD_H)
panel.ClipsDescendants = true
panel.Visible = false

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
local chevron = Style.label(header, "-", 26, F.display, C.dim)
chevron.AnchorPoint = Vector2.new(1, 0.5)
chevron.Position = UDim2.new(1, -12, 0.5, 0)
chevron.Size = UDim2.fromOffset(24, 24)

local body = Instance.new("Frame")
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(0, HEAD_H)
body.Size = UDim2.fromScale(1, 0)
body.Parent = panel

local state: { [string]: SetView } = {}
local clockOffset = 0 -- server unix time minus local unix time
local open = not UserInputService.TouchEnabled
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

local function shape(): string
	local parts = { tostring(open) }
	for _, name in ORDER do
		local set = state[name]
		if set then
			for _, g in set.goals do
				table.insert(parts, `{name}:{g.text}:{g.done}`)
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
			cd.Text = "new in " .. fmt(set.endsAt - t)
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
	for _, c in body:GetChildren() do
		c:Destroy()
	end
	table.clear(countdowns)
	table.clear(rowViews)
	local y, done, total = 0, 0, 0
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
			for _, g in set.goals do
				total += 1
				if g.done then
					done += 1
				end
				local row = Style.card(body, 12)
				row.Position = UDim2.fromOffset(10, y)
				row.Size = UDim2.new(1, -20, 0, ROW_H - 6)
				row.BackgroundTransparency = if g.done then 0.5 else 0
				local text = Style.label(row, g.text, 15, F.heavy, if g.done then C.dim else C.text)
				text.Position = UDim2.fromOffset(12, 5)
				text.Size = UDim2.new(1, -90, 0, 18)
				text.TextXAlignment = Enum.TextXAlignment.Left
				text.TextTruncate = Enum.TextTruncate.AtEnd
				local reward = Style.pill(
					row,
					if g.done then "DONE" else "$" .. shortNumber(g.reward),
					if g.done then C.green else C.gold
				)
				reward.AnchorPoint = Vector2.new(1, 0)
				reward.Position = UDim2.new(1, -10, 0, 6)
				local back, fill = Style.bar(row, if g.done then C.green else COLORS[name])
				back.Position = UDim2.fromOffset(12, 28)
				back.Size = UDim2.new(1, -86, 0, 7)
				fill.Size = UDim2.fromScale(math.clamp(g.progress / math.max(g.target, 1), 0, 1), 1)
				local amount = Style.label(
					row,
					`{shortNumber(g.progress)}/{shortNumber(g.target)}`,
					12,
					F.bold,
					C.dim
				)
				amount.AnchorPoint = Vector2.new(1, 0)
				amount.Position = UDim2.new(1, -10, 0, 24)
				amount.Size = UDim2.fromOffset(66, 14)
				amount.TextXAlignment = Enum.TextXAlignment.Right
				table.insert(rowViews, { fill = fill, amount = amount })
				y += ROW_H
			end
			y += 6
		end
	end
	countPill.Text = `{done} / {total}`
	tickCountdowns()
	body.Size = UDim2.new(1, 0, 0, y)
	chevron.Text = if open then "-" else "+"
	TweenService:Create(
		panel,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad),
		{ Size = UDim2.fromOffset(310, height()) }
	):Play()
end

header.Activated:Connect(function()
	open = not open
	rebuild()
end)

function Goals.start()
	Net.waitFor("Goals").OnClientEvent:Connect(function(newState, serverNow)
		if typeof(newState) == "table" then
			state = newState
			if typeof(serverNow) == "number" then
				clockOffset = serverNow - os.time()
			end
			if shape() ~= builtShape then
				rebuild()
			else
				-- same goals: just move the bars and numbers
				local i = 0
				for _, name in ORDER do
					local set = state[name]
					if set then
						for _, g in set.goals do
							i += 1
							local view = rowViews[i]
							if view then
								view.fill.Size = UDim2.fromScale(
									math.clamp(g.progress / math.max(g.target, 1), 0, 1),
									1
								)
								view.amount.Text =
									`{shortNumber(g.progress)}/{shortNumber(g.target)}`
							end
						end
					end
				end
			end
		end
	end)
	local last = 0
	RunService.RenderStepped:Connect(function()
		local step = (player:GetAttribute("Tutorial") or 99) :: number
		panel.Visible = player:GetAttribute("DataReady") == true
			and step >= Onboarding.Steps.Save
			and next(state) ~= nil
		local now = os.clock()
		if now - last < 0.5 then
			return
		end
		last = now
		tickCountdowns()
	end)
end

return Goals
