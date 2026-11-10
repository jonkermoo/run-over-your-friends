--!strict
-- Pinned goals: up to three goals stacked top left under the menu strip, each a small asphalt card with
-- its set's paint stripe, the goal, a lane-line bar, the reward and an X to unpin. Pins are picked in the
-- goals sheet (Goals calls toggle); the server goal and one hourly goal are pinned for you until you change
-- them. A finished hourly/daily pin shows DONE for a moment, then moves to its set's next goal; the server
-- goal's card counts down to its end, then shows DONE (or a wait) and the time to the next server goal
-- (Rules/Pins). Pins last the session. Hidden during the tutorial (its job card sits here) and while the
-- goals sheet is open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local QuestConfig = require(ReplicatedStorage.Shared.Config.Quests)
local ServerGoals = require(ReplicatedStorage.Shared.Config.ServerGoals)
local Pins = require(ReplicatedStorage.Shared.Rules.Pins)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local C, F = Style.colors, Style.fonts
local CFG = QuestConfig.Pins

local PinnedGoals = {}

type GoalView = { text: string, target: number, reward: number, progress: number, done: boolean }
type SetView = { goals: { GoalView }, endsAt: number }

PinnedGoals.colors = table.freeze({ Hourly = C.blue, Daily = C.pink, Server = C.yellow })

local TOP, LEFT, GAP = 68, 14, 10
local CARD_W, CARD_W_NARROW, CARD_H = 300, 250, 58
local NARROW = 1000 -- px: narrower screens get slimmer cards

local gui = Instance.new("ScreenGui")
gui.Name = "PinnedGoals"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- the stack's frame is sized to its cards, so other HUD pieces can keep clear of it
local stack = Instance.new("Frame")
stack.Name = "PinnedStack"
stack.BackgroundTransparency = 1
stack.Position = UDim2.fromOffset(LEFT, TOP)
stack.Size = UDim2.fromOffset(CARD_W, 0)
stack.Visible = false
stack.Parent = gui

local sets: { [string]: SetView } = {}
local serverSet: SetView? = nil -- the shared server goal (its own remote); no goals = between goals
local clockOffset = 0 -- server unix time minus local unix time
local pins: { Pins.Pin } = {}
local touched = false -- the player pinned or unpinned something: no more default pins
local doneAt: { [string]: number } = {} -- pin key -> when its goal was first seen finished
local sheetOpen = false
local changed = Instance.new("BindableEvent")
PinnedGoals.changed = changed.Event -- fires when the pins change (the sheet redraws its pin buttons)

local function keyOf(p: Pins.Pin): string
	return `{p.set}:{p.index}:{p.endsAt}`
end

local function keysOf(list: { Pins.Pin }): string
	local keys = {}
	for _, p in list do
		table.insert(keys, keyOf(p))
	end
	return table.concat(keys, ",")
end

-- a pushpin drawn from frames (emoji pins don't draw everywhere): a square head, a collar, a needle,
-- all tilted. Returns the holder; tint it with PinnedGoals.tintPin.
function PinnedGoals.pinIcon(parent: Instance, size: number, color: Color3): Frame
	local holder = Instance.new("Frame")
	holder.Name = "PinIcon"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size, size)
	holder.Rotation = 35
	holder.Parent = parent
	local function piece(x: number, y: number, w: number, h: number)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.AnchorPoint = Vector2.new(0.5, 0)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.ZIndex = 4
		f.Parent = holder
	end
	piece(0.5, 0.0, 0.62, 0.22) -- head
	piece(0.5, 0.22, 0.34, 0.26) -- body
	piece(0.5, 0.46, 0.78, 0.12) -- collar
	piece(0.5, 0.58, 0.1, 0.42) -- needle
	return holder
end

function PinnedGoals.tintPin(icon: Frame, color: Color3)
	for _, f in icon:GetChildren() do
		if f:IsA("Frame") then
			f.BackgroundColor3 = color
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

---------------------------------------------------------------- cards

type Card = {
	frame: Frame,
	fill: Frame,
	amount: TextLabel,
	reward: TextLabel,
	text: TextLabel,
	tag: TextLabel,
	pin: Pins.Pin,
}
local cards: { Card } = {}
local builtShape = ""
local shown: { [string]: boolean } = {} -- pin keys already on screen (only new ones slide in)

-- what a server pin shows while there's no goal (between one goal and the next)
local WAITING: GoalView = {
	text = "Next server goal soon",
	target = 1,
	progress = 0,
	reward = ServerGoals.Reward,
	done = false,
}

local function goalOf(p: Pins.Pin): GoalView?
	local s = sets[p.set]
	if s and #s.goals == 0 and Pins.Waits[p.set] then
		return WAITING
	end
	return s and s.goals[p.index]
end

local function fmt(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function shape(width: number): string
	local parts = { tostring(width) }
	for _, p in pins do
		local g = goalOf(p)
		table.insert(parts, `{keyOf(p)}:{g and g.text or ""}:{g and g.done or false}`)
	end
	return table.concat(parts, "|")
end

local function fillCard(card: Card, g: GoalView)
	local color = PinnedGoals.colors[card.pin.set] or C.yellow
	card.fill.Size = UDim2.fromScale(math.clamp(g.progress / math.max(g.target, 1), 0, 1), 1)
	card.fill.BackgroundColor3 = if g.done then C.green else color
	card.amount.Text = `{shortNumber(g.progress)}/{shortNumber(g.target)}`
	card.reward.Text = if g.done
		then `DONE +${shortNumber(g.reward)}`
		else "$" .. shortNumber(g.reward)
	card.reward.BackgroundColor3 = if g.done then C.green else C.gold
	card.text.TextColor3 = if g.done or g == WAITING then C.dim else C.text
	Style.setShadow(card.frame, if g.done then C.green else C.ink)
	-- the server goal's tag carries its clock: time left, then (done or between goals) time to the next
	local s = sets[card.pin.set]
	if card.pin.set == "Server" and s then
		local left = fmt(s.endsAt - (os.time() + clockOffset))
		card.tag.Text = if g.done or g == WAITING then `SERVER  NEXT {left}` else `SERVER  {left}`
		card.amount.Text = if g == WAITING then "" else card.amount.Text
	end
end

local function build(width: number)
	builtShape = shape(width)
	for _, card in cards do
		card.frame:Destroy()
	end
	table.clear(cards)
	for i, p in pins do
		local g = goalOf(p)
		if not g then
			continue
		end
		local color = PinnedGoals.colors[p.set] or C.yellow
		local frame = Style.panel(stack)
		frame.Name = "Pinned" .. i
		frame.Position = UDim2.fromOffset(0, (i - 1) * (CARD_H + GAP))
		frame.Size = UDim2.fromOffset(width, CARD_H)
		local stripe = Instance.new("Frame")
		stripe.BorderSizePixel = 0
		stripe.BackgroundColor3 = color
		stripe.Size = UDim2.new(0, 6, 1, 0)
		stripe.Parent = frame
		local tag = Style.pill(frame, string.upper(p.set), color)
		tag.TextColor3 = if p.set == "Hourly" then C.text else C.ink
		tag.Name = "Tag"
		tag.Position = UDim2.fromOffset(16, 7)
		local reward = Style.pill(frame, "", C.gold)
		reward.AnchorPoint = Vector2.new(1, 0)
		reward.Position = UDim2.new(1, -40, 0, 7)
		local text = Style.label(frame, g.text, 15, F.heavy, C.text)
		text.Position = UDim2.fromOffset(16, 28)
		text.Size = UDim2.new(1, -30, 0, 16)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextTruncate = Enum.TextTruncate.AtEnd
		local back, fill = Style.bar(frame, color)
		back.BackgroundColor3 = C.card
		back.BackgroundTransparency = 0
		back.Position = UDim2.fromOffset(16, 48)
		back.Size = UDim2.new(1, -86, 0, 5)
		Style.laneGaps(back, C.panel)
		local amount = Style.label(frame, "", 12, F.bold, C.dim)
		amount.AnchorPoint = Vector2.new(1, 0)
		amount.Position = UDim2.new(1, -12, 0, 43)
		amount.Size = UDim2.fromOffset(62, 14)
		amount.TextXAlignment = Enum.TextXAlignment.Right
		local close = Style.button(frame, "X", "dark", 14)
		close.Name = "Unpin"
		close.AnchorPoint = Vector2.new(1, 0)
		close.Position = UDim2.new(1, -8, 0, 6)
		close.Size = UDim2.fromOffset(22, 22)
		local pin = p
		close.Activated:Connect(function()
			PinnedGoals.toggle(pin.set, pin.index)
		end)
		local card: Card = {
			frame = frame,
			fill = fill,
			amount = amount,
			reward = reward,
			text = text,
			tag = tag,
			pin = p,
		}
		fillCard(card, g)
		table.insert(cards, card)
		-- a new card slides in from the left
		local key = keyOf(p)
		if not shown[key] then
			frame.Position = UDim2.fromOffset(-width - 20, (i - 1) * (CARD_H + GAP))
			TweenService:Create(
				frame,
				TweenInfo.new(0.25, Enum.EasingStyle.Back),
				{ Position = UDim2.fromOffset(0, (i - 1) * (CARD_H + GAP)) }
			):Play()
		end
	end
	table.clear(shown)
	for _, p in pins do
		shown[keyOf(p)] = true
	end
	stack.Size = UDim2.fromOffset(width, math.max(#cards * (CARD_H + GAP) - GAP, 0))
end

---------------------------------------------------------------- pins

-- finished pins stay on DONE for a moment before they move on: until then the rules see them unfinished
local function settle()
	local now = os.clock()
	sets.Server = serverSet
	local view: Pins.Sets = {}
	for name, s in sets do
		local goals = {}
		for i, g in s.goals do
			local done = g.done
			if done then
				for _, p in pins do
					if p.set == name and p.index == i and p.endsAt == s.endsAt then
						local k = keyOf(p)
						doneAt[k] = doneAt[k] or now
						done = now - doneAt[k] >= CFG.FlashSeconds
					end
				end
			end
			goals[i] = { done = done }
		end
		view[name] = { goals = goals, endsAt = s.endsAt }
	end
	local before = keysOf(pins)
	pins = Pins.advance(pins, view)
	if not touched then
		-- the defaults: one hourly/daily goal whenever none is pinned, and the server goal on top
		local own = 0
		for _, p in pins do
			if p.set ~= "Server" then
				own += 1
			end
		end
		if own == 0 then
			for _, p in Pins.default(view, CFG.Default) do
				table.insert(pins, p)
			end
		end
		local s = view.Server
		if CFG.Server and s and not Pins.isPinned(pins, "Server", 1) and #pins < CFG.Max then
			table.insert(pins, 1, { set = "Server", index = 1, endsAt = s.endsAt })
		end
	end
	if keysOf(pins) ~= before then
		changed:Fire()
	end
end

function PinnedGoals.isPinned(set: string, index: number): boolean
	return Pins.isPinned(pins, set, index)
end

function PinnedGoals.count(): number
	return #pins
end

-- pins or unpins a goal; returns what happened ("pinned" | "unpinned" | "full")
function PinnedGoals.toggle(set: string, index: number): string
	local s = sets[set]
	if not s then
		return "full"
	end
	local what
	pins, what = Pins.toggle(pins, set, index, s.endsAt, CFG.Max)
	if what ~= "full" then
		touched = true
		changed:Fire()
	end
	return what
end

-- the shared server goal, whenever the server sends it (nil before the first one)
function PinnedGoals.setServer(set: SetView?, serverNow: number?)
	serverSet = set
	if serverNow then
		clockOffset = serverNow - os.time()
	end
	settle()
end

-- the player's goal sets, whenever the server sends them
function PinnedGoals.setGoals(newSets: { [string]: SetView })
	sets = {}
	for _, name in Pins.Order do
		local s = newSets[name]
		if typeof(s) == "table" then
			sets[name] = s
		end
	end
	settle()
end

function PinnedGoals.setSheetOpen(on: boolean)
	sheetOpen = on
end

function PinnedGoals.start()
	local last = 0
	RunService.RenderStepped:Connect(function()
		local step = (player:GetAttribute("Tutorial") or Onboarding.Steps.Done) :: number
		stack.Visible = player:GetAttribute("DataReady") == true
			and step >= Onboarding.Steps.Done
			and not sheetOpen
		if not stack.Visible then
			return
		end
		local now = os.clock()
		if now - last >= 0.25 then
			last = now
			settle()
		end
		local width = if gui.AbsoluteSize.X < NARROW then CARD_W_NARROW else CARD_W
		if shape(width) ~= builtShape then
			build(width)
		else
			for _, card in cards do
				local g = goalOf(card.pin)
				if g then
					fillCard(card, g)
				end
			end
		end
	end)
end

return PinnedGoals
