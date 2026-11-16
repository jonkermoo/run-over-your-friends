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
local UserInputService = game:GetService("UserInputService")

local Loc = require(ReplicatedStorage.Shared.Loc)
local LayoutConfig = require(ReplicatedStorage.Shared.Config.Layout)
local LayoutRules = require(ReplicatedStorage.Shared.Rules.Layout)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local QuestConfig = require(ReplicatedStorage.Shared.Config.Quests)
local ServerGoals = require(ReplicatedStorage.Shared.Config.ServerGoals)
local Pins = require(ReplicatedStorage.Shared.Rules.Pins)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
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
local NARROW = 1000 -- real px (not layout px, so phones count): narrower screens get slimmer cards

local gui = Instance.new("ScreenGui")
gui.Name = "PinnedGoals"
gui.ResetOnSpawn = false
gui.Parent = playerGui
Style.fit(gui)

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

-- a push-pin (Config/Icons.Pin, tilted, white so it takes the colour). Tint it with PinnedGoals.tintPin.
function PinnedGoals.pinIcon(parent: Instance, size: number, color: Color3): ImageLabel
	local icon = Style.image(parent, Icons.Pin, color)
	icon.Name = "PinIcon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(size, size)
	icon.ZIndex = 4
	return icon
end

function PinnedGoals.tintPin(icon: ImageLabel, color: Color3)
	icon.ImageColor3 = color
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
	-- the screen size too: the unpin X's thumb-zone check depends on it
	local parts = { tostring(width), tostring(gui.AbsoluteSize) }
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
	card.reward.AutoLocalize = false
	card.reward.Text = if g.done
		then Loc.text("PinnedDone", { n = shortNumber(g.reward) })
		else "$" .. shortNumber(g.reward)
	card.reward.BackgroundColor3 = if g.done then C.green else C.gold
	card.text.TextColor3 = if g.done or g == WAITING then C.dim else C.text
	Style.setShadow(card.frame, if g.done then C.green else C.ink)
	-- the server goal's tag carries its clock: time left, then (done or between goals) time to the next
	local s = sets[card.pin.set]
	if card.pin.set == "Server" and s then
		local left = fmt(s.endsAt - (os.time() + clockOffset))
		Loc.set(
			card.tag,
			if g.done or g == WAITING then "PinnedServerNext" else "PinnedServer",
			{ time = left }
		)
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
		local text = Style.label(frame, Loc.goal(g, p.set == "Server"), 15, F.heavy, C.text)
		text.AutoLocalize = false
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
		Style.onTap(close, function()
			PinnedGoals.toggle(pin.set, pin.index)
		end)
		-- a button in the thumbstick's zone would steal its touches; unpin from the goals sheet instead
		local k = Style.scale()
		close.Visible = not UserInputService.TouchEnabled
			or not LayoutRules.inThumbZone(
				(LEFT + width - 8) * k,
				(TOP + (i - 1) * (CARD_H + GAP) + 6) * k,
				gui.AbsoluteSize.X,
				gui.AbsoluteSize.Y,
				LayoutConfig
			)
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
