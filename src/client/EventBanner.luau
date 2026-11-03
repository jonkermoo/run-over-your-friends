--!strict
-- The event banner (top centre): next event countdown while quiet, a pulsing warning before one starts,
-- and the live event with what it does and how long it has left. A big title flies in when it starts.
-- Under it, a slim strip shows the shared server goal's progress (finishing it brings the next event).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Events)
local Net = require(ReplicatedStorage.Shared.Net)
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

-- the server goal strip hangs under the sign (or its chip), clear of its shadow. Like the sign, an X beside
-- it shrinks it to a small chip with the progress, and tapping the chip brings it back.
local STRIP_W, STRIP_H = 250, 24
local strip = Style.panel(gui)
strip.Name = "ServerGoalStrip"
strip.AnchorPoint = Vector2.new(0.5, 0)
strip.Size = UDim2.fromOffset(STRIP_W, STRIP_H)
strip.Visible = false
local stripTag = Style.pill(strip, "SERVER GOAL", C.yellow)
stripTag.Position = UDim2.fromOffset(4, 3)
local stripBack, stripFill = Style.bar(strip, C.yellow)
stripBack.BackgroundColor3 = C.card
stripBack.BackgroundTransparency = 0
stripBack.AnchorPoint = Vector2.new(0, 0.5)
stripBack.Position = UDim2.new(0, 104, 0.5, 0)
stripBack.Size = UDim2.new(1, -176, 0, 6)
Style.laneGaps(stripBack, C.panel)
local stripAmount = Style.label(strip, "", 13, F.display, C.yellow)
stripAmount.AnchorPoint = Vector2.new(1, 0)
stripAmount.Position = UDim2.new(1, -8, 0, 3)
stripAmount.Size = UDim2.fromOffset(62, 18)
stripAmount.TextXAlignment = Enum.TextXAlignment.Right
local stripShrunk = false
local stripHide = Style.button(gui, "X", "dark", 14)
stripHide.Name = "HideServerGoal"
stripHide.BackgroundColor3 = C.panel
stripHide.Size = UDim2.fromOffset(STRIP_H, STRIP_H)
stripHide.Visible = false
local stripChip = Style.button(gui, "", "dark", 14)
stripChip.Name = "ServerGoalChip"
stripChip.BackgroundColor3 = C.panel
stripChip.AnchorPoint = Vector2.new(0.5, 0)
stripChip.Size = UDim2.fromOffset(104, STRIP_H)
stripChip.Visible = false
local stripChipDot = Instance.new("Frame")
stripChipDot.BorderSizePixel = 0
stripChipDot.BackgroundColor3 = C.yellow
stripChipDot.AnchorPoint = Vector2.new(0, 0.5)
stripChipDot.Position = UDim2.new(0, 8, 0.5, 0)
stripChipDot.Size = UDim2.fromOffset(10, 10)
stripChipDot.Parent = stripChip
local stripChipText = Style.label(stripChip, "", 14, F.display, C.yellow)
stripChipText.Position = UDim2.fromOffset(22, 0)
stripChipText.Size = UDim2.new(1, -26, 1, 0)
stripHide.Activated:Connect(function()
	stripShrunk = true
end)
stripChip.Activated:Connect(function()
	stripShrunk = false
end)
local serverGoal: { text: string, progress: number, target: number, done: boolean }? = nil

local function drawStrip()
	local g = serverGoal
	if g then
		stripFill.Size = UDim2.fromScale(math.clamp(g.progress / math.max(g.target, 1), 0, 1), 1)
		stripAmount.Text = `{g.progress}/{g.target}`
		stripChipText.Text = `{g.progress}/{g.target}`
	end
end

-- the player can shrink the sign to a small chip with just a colour dot and the timer (X beside the
-- sign), and tap the chip to bring it back. Kept for the session; big event titles still show.
local shrunk = false
local hide = Style.button(gui, "X", "dark", 18)
hide.Name = "HideEvent"
hide.BackgroundColor3 = C.panel
hide.Size = UDim2.fromOffset(40, 40)
hide.Visible = false
local chip = Style.button(gui, "", "dark", 18)
chip.Name = "EventChip"
chip.BackgroundColor3 = C.panel
chip.AnchorPoint = Vector2.new(0.5, 0)
chip.Position = UDim2.new(0.5, 0, 0, 8)
chip.Size = UDim2.fromOffset(104, 44)
chip.Visible = false
local chipDot = Instance.new("Frame")
chipDot.BorderSizePixel = 0
chipDot.AnchorPoint = Vector2.new(0, 0.5)
chipDot.Position = UDim2.new(0, 10, 0.5, 0)
chipDot.Size = UDim2.fromOffset(16, 16)
chipDot.Parent = chip
local chipTimer = Style.label(chip, "", 18, F.display, C.yellow)
chipTimer.Position = UDim2.fromOffset(32, 3)
chipTimer.Size = UDim2.new(1, -38, 1, 0)
hide.Activated:Connect(function()
	shrunk = true
end)
chip.Activated:Connect(function()
	shrunk = false
end)

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
		banner.Visible, hide.Visible, chip.Visible = false, false, false
		return
	end
	local event = byKey[key]
	if not event then
		banner.Visible, hide.Visible, chip.Visible = false, false, false
		return
	end
	banner.Visible = not shrunk
	hide.Visible = not shrunk
	chip.Visible = shrunk
	local color = Style.colors[event.color] or C.gold
	local left = endsAt - workspace:GetServerTimeNow()
	if phase == "live" and (lastPhase ~= "live" or lastKey ~= key) then
		bigTitle(event)
	end
	lastPhase, lastKey = phase, key
	if shrunk then
		chipDot.BackgroundColor3 = if phase == "quiet" then C.grey else color
		chipTimer.Text = fmt(if phase == "quiet" then left + Config.WarnSeconds else left)
		local blink = phase == "warn" and math.floor(os.clock() * 4) % 2 == 0
		Style.setShadow(chip, if blink then C.text else C.ink)
		return
	end
	-- the X sits just right of the sign
	hide.Position = UDim2.new(0.5, banner.AbsoluteSize.X / 2 + 10, 0, 8)

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

-- the strip (or its chip) sits under whatever of the event sign is showing
local function placeStrip()
	local g = serverGoal
	local show = g ~= nil and not g.done
	local above: GuiObject? = if banner.Visible then banner elseif chip.Visible then chip else nil
	local y = if above then above.AbsolutePosition.Y + above.AbsoluteSize.Y + 9 else 8
	strip.Visible = show and not stripShrunk
	stripHide.Visible = show and not stripShrunk
	stripChip.Visible = show and stripShrunk
	-- on a narrow screen the middle runs into the job card or the pinned goals (top left, drawn above
	-- us): slide right of them
	local width = if stripShrunk then stripChip.AbsoluteSize.X else STRIP_W
	local x = gui.AbsoluteSize.X / 2
	for _, path in { { "Guide", "JobCard" }, { "PinnedGoals", "PinnedStack" } } do
		local holder = playerGui:FindFirstChild(path[1])
		local card = holder and holder:FindFirstChild(path[2]) :: GuiObject?
		if
			card
			and card.Visible
			and card.AbsoluteSize.Y > 0
			and card.AbsolutePosition.Y < y + STRIP_H
		then
			x = math.max(x, card.AbsolutePosition.X + card.AbsoluteSize.X + 12 + width / 2)
			y = math.max(y, 72) -- slid right, it also clears the cash box (top right, 62 px tall + shadow)
		end
	end
	strip.Position = UDim2.fromOffset(x, y)
	stripChip.Position = UDim2.fromOffset(x, y)
	stripHide.Position = UDim2.fromOffset(x + STRIP_W / 2 + 10, y)
end

function EventBanner.start()
	Net.waitFor("ServerGoal").OnClientEvent:Connect(function(set)
		local g = typeof(set) == "table" and typeof(set.goals) == "table" and set.goals[1]
		serverGoal = if typeof(g) == "table" then g else nil
		drawStrip()
	end)
	RunService.RenderStepped:Connect(function()
		update()
		placeStrip()
	end)
end

return EventBanner
