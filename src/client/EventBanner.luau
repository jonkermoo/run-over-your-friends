--!strict
-- The event banner (top centre): next event countdown while quiet, a pulsing warning before one starts,
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

-- a road sign at the top centre with painted lane lines along its top and bottom edges
local banner = Style.panel(gui)
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 8)
banner.Size = UDim2.fromOffset(250, 42)
banner.Visible = false
local topLine = Style.dashes(banner, C.yellow)
topLine.Position = UDim2.fromOffset(0, 3)
local bottomLine = Style.dashes(banner, C.yellow)
bottomLine.AnchorPoint = Vector2.new(0, 1)
bottomLine.Position = UDim2.new(0, 0, 1, -3)
local pill = Style.pill(banner, "", C.ink)
pill.Position = UDim2.fromOffset(12, 10)
local title = Style.label(banner, "", 20, F.display, C.text)
title.Position = UDim2.fromOffset(14, 10)
title.Size = UDim2.new(1, -28, 0, 24)
title.TextXAlignment = Enum.TextXAlignment.Left
local text = Style.label(banner, "", 13, F.bold, C.text)
text.Position = UDim2.fromOffset(14, 54)
text.Size = UDim2.new(1, -28, 0, 16)
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextTruncate = Enum.TextTruncate.AtEnd
local timer = Style.label(banner, "", 18, F.display, C.yellow)
timer.AnchorPoint = Vector2.new(1, 0)
timer.Position = UDim2.new(1, -14, 0, 11)
timer.Size = UDim2.fromOffset(150, 22)
timer.TextXAlignment = Enum.TextXAlignment.Right

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

local function bigTitle(event: Config.Event)
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
		-- a slim asphalt sign: what's coming and when
		banner.Size = UDim2.fromOffset(250, 42)
		banner.BackgroundColor3 = C.panel
		paintLines(C.yellow)
		pill.Visible = false
		text.Visible = false
		title.Text = "NEXT EVENT"
		title.TextColor3 = C.text
		title.Position = UDim2.fromOffset(14, 10)
		timer.Text = fmt(left + Config.WarnSeconds)
		timer.TextColor3 = C.yellow
		Style.setShadow(banner, C.ink)
		return
	end
	-- warn or live: the sign is painted the event's colour
	local ink = inkOn(color)
	banner.Size = UDim2.fromOffset(380, 80)
	banner.BackgroundColor3 = color
	paintLines(ink)
	pill.Visible = true
	pill.Text = if phase == "live" then "LIVE" else "SOON"
	pill.BackgroundColor3 = ink
	pill.TextColor3 = color
	pill.Position = UDim2.fromOffset(14, 12)
	title.Text = event.title
	title.TextColor3 = ink
	title.Position = UDim2.fromOffset(14, 30)
	text.Visible = true
	text.Text = event.text
	text.TextColor3 = ink
	timer.Text = (if phase == "live" then "ENDS " else "IN ") .. fmt(left)
	timer.TextColor3 = ink
	-- the warning blinks its shadow
	local blink = phase == "warn" and math.floor(os.clock() * 4) % 2 == 0
	Style.setShadow(banner, if blink then C.text else C.ink)
end

function EventBanner.start()
	RunService.RenderStepped:Connect(update)
end

return EventBanner
