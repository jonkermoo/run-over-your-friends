--!strict
-- The daily streak card: once a UTC day, after the tutorial, a road-sign card in the middle shows the
-- streak as a row of day tiles (collected, today, still to come) and a COLLECT button. The server pays.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Daily)
local Daily = require(ReplicatedStorage.Shared.Rules.Daily)
local Net = require(ReplicatedStorage.Shared.Net)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local C, F = Style.colors, Style.fonts
local money = Style.money

local Streak = {}

local W, H = 440, 268
local TILE_W, TILE_H, TILE_GAP = 52, 70, 6
local TILES = 7

local gui = Instance.new("ScreenGui")
gui.Name = "Streak"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui

local card = Style.panel(gui)
card.Name = "StreakCard"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(W, H)
card.Visible = false
Style.stroke(card, C.yellow, 4, 0)
Style.setShadow(card, C.blue)
local scale = Instance.new("UIScale")
scale.Parent = card

local title = Style.label(card, "DAILY STREAK", 32, F.display, C.yellow)
title.Position = UDim2.fromOffset(0, 14)
title.Size = UDim2.new(1, 0, 0, 38)
Style.outline(title, 1.5)
local sub = Style.label(card, "", 14, F.bold, C.text)
sub.Position = UDim2.fromOffset(20, 54)
sub.Size = UDim2.new(1, -40, 0, 20)
local line = Style.dashes(card, C.yellow)
line.Position = UDim2.fromOffset(0, 82)

local row = Instance.new("Frame")
row.BackgroundTransparency = 1
row.AnchorPoint = Vector2.new(0.5, 0)
row.Position = UDim2.new(0.5, 0, 0, 96)
row.Size = UDim2.fromOffset(TILES * TILE_W + (TILES - 1) * TILE_GAP, TILE_H)
row.Parent = card

type Tile = { frame: Frame, day: TextLabel, pay: TextLabel, tick: TextLabel }
local tiles: { Tile } = {}
for i = 1, TILES do
	local f = Style.card(row)
	f.Position = UDim2.fromOffset((i - 1) * (TILE_W + TILE_GAP), 0)
	f.Size = UDim2.fromOffset(TILE_W, TILE_H)
	local day = Style.label(f, "", 11, F.heavy, C.dim)
	day.Position = UDim2.fromOffset(0, 6)
	day.Size = UDim2.new(1, 0, 0, 14)
	local pay = Style.label(f, "", 14, F.display, C.money)
	pay.Position = UDim2.fromOffset(0, 26)
	pay.Size = UDim2.new(1, 0, 0, 18)
	local tick = Style.label(f, "", 18, F.display, C.money)
	tick.Position = UDim2.fromOffset(0, 46)
	tick.Size = UDim2.new(1, 0, 0, 20)
	table.insert(tiles, { frame = f, day = day, pay = pay, tick = tick })
end

local collect = Style.button(card, "COLLECT", "gold", 22)
collect.Name = "Collect"
collect.AnchorPoint = Vector2.new(0.5, 0)
collect.Position = UDim2.new(0.5, 0, 0, 190)
collect.Size = UDim2.fromOffset(260, 54)

local state = { streak = 0, ready = false }

-- a short pay label for a tile: $500, $2.5K, $10K
local function short(n: number): string
	if n >= 1000 then
		local k = n / 1000
		return "$" .. (if k == math.floor(k) then tostring(k) else string.format("%.1f", k)) .. "K"
	end
	return money(n)
end

local function draw()
	local today = math.max(state.streak, 1)
	local reward = Daily.reward(today, Config.StreakRewards)
	sub.Text = `Day {today} in a row: {money(reward)}. Come back tomorrow for {money(
		Daily.reward(today + 1, Config.StreakRewards)
	)}!`
	-- the row shows the week this day falls in; past the 7th it slides so today stays at the end
	local first = if today <= TILES then 1 else today - TILES + 1
	for i, t in tiles do
		local d = first + i - 1
		t.day.Text = "DAY " .. d
		t.pay.Text = short(Daily.reward(d, Config.StreakRewards))
		if d < today then
			t.frame.BackgroundColor3 = C.card
			t.tick.Text = "✓"
			t.tick.TextColor3 = C.money
			t.day.TextColor3 = C.dim
			t.pay.TextColor3 = C.dim
		elseif d == today then
			t.frame.BackgroundColor3 = C.yellow
			t.tick.Text = "TODAY"
			t.tick.TextSize = 12
			t.tick.TextColor3 = C.ink
			t.day.TextColor3 = C.ink
			t.pay.TextColor3 = C.ink
		else
			t.frame.BackgroundColor3 = C.grey
			t.tick.Text = ""
			t.day.TextColor3 = C.dim
			t.pay.TextColor3 = C.text
		end
		if d ~= today then
			t.tick.TextSize = 18
		end
	end
end

local function fit()
	local cam = workspace.CurrentCamera
	local view = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	scale.Scale = math.min(1, (view.X - 32) / W, (view.Y - 32) / H)
end

local function update()
	local step = (player:GetAttribute("Tutorial") or 0) :: number
	local show = state.ready and step >= Onboarding.Steps.Save
	if show and not card.Visible then
		draw()
		fit()
		local target = scale.Scale
		scale.Scale = target * 0.8
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = target })
			:Play()
	end
	card.Visible = show
end

collect.Activated:Connect(function()
	card.Visible = false
	state.ready = false
	Net.waitFor("ClaimDaily"):FireServer()
end)

function Streak.start()
	Net.waitFor("Daily").OnClientEvent:Connect(function(s)
		if typeof(s) == "table" and typeof(s.streak) == "number" then
			state = { streak = s.streak, ready = s.ready == true }
			update()
		end
	end)
	player:GetAttributeChangedSignal("Tutorial"):Connect(update)
end

return Streak
