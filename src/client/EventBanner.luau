--!strict
-- The event banner (top left): next event countdown while quiet, a pulsing warning before one starts,
-- and the live event with what it does and how long it has left. A big title flies in when it starts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Events)
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

local banner = Style.panel(gui, 16)
banner.Position = UDim2.fromOffset(14, 8)
banner.Size = UDim2.fromOffset(330, 40)
banner.Visible = false
local edge = Style.stroke(banner, C.gold, 2.5, 1)
local pill = Style.pill(banner, "", C.gold)
pill.Position = UDim2.fromOffset(12, 11)
local title = Style.label(banner, "", 20, F.display, C.text)
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -24, 0, 24)
title.TextXAlignment = Enum.TextXAlignment.Left
Style.outline(title, 1.5)
local text = Style.label(banner, "", 14, F.bold, C.dim)
text.Position = UDim2.fromOffset(12, 56)
text.Size = UDim2.new(1, -24, 0, 18)
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextTruncate = Enum.TextTruncate.AtEnd
local timer = Style.label(banner, "", 16, F.display, C.text)
timer.AnchorPoint = Vector2.new(1, 0)
timer.Position = UDim2.new(1, -12, 0, 10)
timer.Size = UDim2.fromOffset(110, 20)
timer.TextXAlignment = Enum.TextXAlignment.Right

local sting = Instance.new("Sound")
sting.SoundId = "rbxassetid://9125648149"
sting.Volume = 0.8
sting.Parent = gui

local function fmt(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function bigTitle(event: Config.Event)
	sting:Play()
	local color = Style.colors[event.color] or C.gold
	local t = Style.label(gui, event.title, 72, F.display, color)
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.3)
	t.Size = UDim2.fromOffset(900, 90)
	Style.outline(t, 5)
	local s = Style.label(gui, event.text, 24, F.display, C.text)
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Position = UDim2.new(0.5, 0, 0.3, 64)
	s.Size = UDim2.fromOffset(900, 30)
	Style.outline(s, 3)
	local scale = Instance.new("UIScale")
	scale.Scale = 2.5
	scale.Parent = t
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(3, function()
		for _, l in { t, s } do
			TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			local stroke = l:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end
		task.delay(0.6, function()
			t:Destroy()
			s:Destroy()
		end)
	end)
end

local lastPhase, lastKey = "", ""

local function update()
	local phase = workspace:GetAttribute("EventPhase")
	local key = workspace:GetAttribute("EventKey")
	local endsAt = workspace:GetAttribute("EventEndsAt")
	if typeof(phase) ~= "string" or typeof(key) ~= "string" or typeof(endsAt) ~= "number" then
		banner.Visible = false
		return
	end
	local event = byKey[key]
	if not event then
		banner.Visible = false
		return
	end
	banner.Visible = true
	local color = Style.colors[event.color] or C.gold
	local left = endsAt - workspace:GetServerTimeNow()
	if phase == "live" and (lastPhase ~= "live" or lastKey ~= key) then
		bigTitle(event)
	end
	lastPhase, lastKey = phase, key

	if phase == "quiet" then
		-- a slim line: what's coming and when
		banner.Size = UDim2.fromOffset(330, 40)
		pill.Visible = false
		text.Visible = false
		title.Text = "NEXT EVENT"
		title.TextSize = 18
		title.TextColor3 = C.dim
		timer.Text = fmt(left + Config.WarnSeconds)
		timer.TextColor3 = C.dim
		edge.Transparency = 1
	else
		banner.Size = UDim2.fromOffset(330, 82)
		pill.Visible = true
		pill.Text = if phase == "live" then "EVENT LIVE" else "EVENT SOON"
		pill.BackgroundColor3 = color
		title.Text = event.title
		title.TextSize = 20
		title.TextColor3 = color
		title.Position = UDim2.fromOffset(12, 30)
		text.Visible = true
		text.Text = event.text
		timer.Text = (if phase == "live" then "ends in " else "starts in ") .. fmt(left)
		timer.TextColor3 = C.text
		edge.Color = color
		edge.Transparency = if phase == "warn" then 0.3 + 0.3 * math.sin(os.clock() * 8) else 0.2
		return
	end
	title.Position = UDim2.fromOffset(12, 8)
end

function EventBanner.start()
	RunService.RenderStepped:Connect(update)
end

return EventBanner
