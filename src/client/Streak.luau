--!strict
-- The daily streak card: once a UTC day, after the tutorial and once the player has stopped (src/client/Popups),
-- a road-sign card in the middle shows the streak as a row of day tiles (collected ones stamped GOT, today's
-- standing taller in yellow, the week's prize at the end) and a COLLECT button. The server pays. On a gamepad it
-- starts on COLLECT and B puts it away for later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Daily)
local PopupsConfig = require(ReplicatedStorage.Shared.Config.Popups)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Daily = require(ReplicatedStorage.Shared.Rules.Daily)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Pad = require(script.Parent.Pad)
local Popups = require(script.Parent.Popups)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local C, F = Style.colors, Style.fonts
local money = Style.money

local Streak = {}

local W, H = 620, 360
local TILE_W, TILE_H, TILE_GAP = 72, 104, 8
local TODAY_H = 124 -- today's tile stands taller
local PRIZE_W = 88 -- the last tile, the week's big prize, is wider
local TILES = 7

local gui = Instance.new("ScreenGui")
gui.Name = "Streak"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui
Style.fit(gui)

local card = Style.panel(gui)
card.Name = "StreakCard"
Style.slot(card)
card.Size = UDim2.fromOffset(W, H)
card.Visible = false
local scale = Instance.new("UIScale")
scale.Parent = card
Style.hazard(card, W, 14)

local title = Style.label(card, "DAILY STREAK", 44, F.display, C.yellow)
title.Position = UDim2.fromOffset(0, 26)
title.Size = UDim2.new(1, 0, 0, 46)
Style.outline(title, 2)
local sub = Style.label(card, "", 16, F.bold, C.text)
sub.Position = UDim2.fromOffset(20, 76)
sub.Size = UDim2.new(1, -40, 0, 22)

-- the week: a row of mile markers (small green signs on posts), today's yellow and raised
local row = Instance.new("Frame")
row.BackgroundTransparency = 1
row.AnchorPoint = Vector2.new(0.5, 0)
row.Position = UDim2.new(0.5, 0, 0, 110)
row.Size = UDim2.fromOffset((TILES - 1) * (TILE_W + TILE_GAP) + PRIZE_W, TODAY_H + 10)
row.Parent = card

type Tile = {
	frame: Frame,
	day: TextLabel,
	icon: ImageLabel,
	pay: TextLabel,
	stamp: TextLabel,
	prize: boolean,
}
local tiles: { Tile } = {}
for i = 1, TILES do
	local prize = i == TILES
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0, 1)
	f.Position = UDim2.new(0, (i - 1) * (TILE_W + TILE_GAP), 1, -10)
	f.Size = UDim2.fromOffset(if prize then PRIZE_W else TILE_W, TILE_H)
	f.Parent = row
	local post = Instance.new("Frame")
	post.Name = "Post"
	post.BackgroundColor3 = C.steel
	post.BorderSizePixel = 0
	post.AnchorPoint = Vector2.new(0.5, 0)
	post.Position = UDim2.new(0.5, 0, 1, 2)
	post.Size = UDim2.fromOffset(7, 10)
	post.Parent = f
	Style.sign(f, "green", true)
	local day = Style.label(f, "", 14, F.heavy, C.dim)
	day.Position = UDim2.fromOffset(0, 6)
	day.Size = UDim2.new(1, 0, 0, 18)
	local icon = Style.image(f, Icons.Bill)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 26)
	icon.Size = UDim2.fromOffset(42, 42)
	local pay = Style.label(f, "", 17, F.display, C.text)
	pay.AnchorPoint = Vector2.new(0, 1)
	pay.Position = UDim2.new(0, 0, 1, -8)
	pay.Size = UDim2.new(1, 0, 0, 22)
	-- collected days get a rubber stamp over the picture
	local stamp = Style.label(f, "GOT", 16, F.display, C.money)
	stamp.AnchorPoint = Vector2.new(0.5, 0.5)
	stamp.Position = UDim2.new(0.5, 0, 0, 48)
	stamp.Size = UDim2.fromOffset(50, 26)
	stamp.Rotation = -12
	stamp.ZIndex = 2
	Style.stroke(stamp, C.money, 3, 0)
	table.insert(tiles, {
		frame = f,
		day = day,
		icon = icon,
		pay = pay,
		stamp = stamp,
		prize = prize,
	})
end

local collect = Style.button(card, "COLLECT", "gold", 30)
collect.Name = "Collect"
collect.AnchorPoint = Vector2.new(0.5, 1)
collect.Position = UDim2.new(0.5, 0, 1, -22)
collect.Size = UDim2.fromOffset(300, 60)
local collectHint = Pad.chip(card, { Enum.KeyCode.ButtonA }, "collect")
collectHint.AnchorPoint = Vector2.new(1, 0.5)
collectHint.Position = UDim2.new(1, -18, 1, -52)

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
	Loc.set(sub, "StreakSub", {
		n = today,
		money = money(Daily.reward(today + 1, Config.StreakRewards)),
	})
	Loc.set(collect, "CollectReward", { money = money(reward) })
	-- the row shows the week this day falls in; past the 7th it slides so today stays at the end
	local first = if today <= TILES then 1 else today - TILES + 1
	for i, t in tiles do
		local d = first + i - 1
		local pay = Daily.reward(d, Config.StreakRewards)
		local got, now = d < today, d == today
		t.day.AutoLocalize = false
		t.day.Text = if now then Loc.source("TODAY") else Loc.text("StreakDay", { n = d })
		t.pay.Text = short(pay)
		t.pay.TextSize = if now then 22 else 17
		-- small pay is a coin, bigger is a banknote
		t.icon.Image = `rbxassetid://{if pay < Config.CoinBelow then Icons.Coin else Icons.Bill}`
		local big = now or t.prize
		local iconSize = if big then 54 else 42
		t.icon.Size = UDim2.fromOffset(iconSize, iconSize)
		t.icon.ImageTransparency = if got then 0.6 else 0
		t.stamp.Visible = got
		t.frame.Size =
			UDim2.fromOffset(if t.prize then PRIZE_W else TILE_W, if big then TODAY_H else TILE_H)
		-- today's marker is yellow with a black line; the week prize carries a yellow ring
		Style.sign(t.frame, if now then "yellow" else "green", true)
		Style.ring(t.frame, if t.prize and not now then C.yellow else nil)
		local ink = if now then C.ink elseif got then C.dim elseif t.prize then C.yellow else C.text
		t.frame.BackgroundColor3 = if now
			then C.yellow
			elseif t.prize then C.prize
			else Color3.fromRGB(11, 125, 75)
		t.frame.BackgroundTransparency = if got then 0.4 else 0
		t.day.TextColor3 = if now or t.prize then ink else C.dim
		t.pay.TextColor3 = ink
	end
end

local function fit()
	local cam = workspace.CurrentCamera
	local view = (if cam then cam.ViewportSize else Vector2.new(1280, 720)) / Style.scale()
	scale.Scale = math.min(1, (view.X - 32) / W, (view.Y - 32) / H)
end

local function showCard()
	draw()
	fit()
	local target = scale.Scale
	scale.Scale = target * 0.8
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = target })
		:Play()
	card.Visible = true
end

local function hideCard()
	card.Visible = false
end

local function isOpen(): boolean
	return card.Visible
end
Style.closeX(card, function()
	Popups.snooze("Streak")
end)

local function update()
	local step = (player:GetAttribute("Tutorial") or 0) :: number
	if state.ready and step >= Onboarding.Steps.Done then
		Popups.want("Streak", PopupsConfig.Collect, showCard, hideCard, isOpen)
	else
		Popups.drop("Streak")
	end
end

Pad.menu(card, {
	first = function()
		return collect
	end,
	close = function()
		hideCard()
	end,
})

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
