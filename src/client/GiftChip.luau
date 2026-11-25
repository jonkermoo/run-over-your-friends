--!strict
-- The play-time gift chip in the right column, under the next-car bar (the left middle is the phone
-- thumbstick's): a countdown to the next gift, OPEN! once it can be claimed (one tap claims it, the server
-- checks), and after the last gift the first-day "come back tomorrow" line, else nothing. GiftService publishes
-- GiftStart and GiftsClaimed; DailyService publishes TomorrowDay and TomorrowPays.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Gifts)
local Gifts = require(ReplicatedStorage.Shared.Rules.Gifts)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Style = require(script.Parent.Style)

local C, F = Style.colors, Style.fonts
local player = Players.LocalPlayer

local TOP, WIDTH, HEIGHT = 120, 196, 40 -- layout px: under the next-car bar (client/NextCar: 68 + 46 + 6)

local GiftChip = {}

-- a small gift box drawn from frames: gold box, pink ribbon
local function giftBox(parent: Instance): Frame
	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(24, 20)
	box.Position = UDim2.fromOffset(9, 11)
	box.BackgroundColor3 = C.yellow
	box.BorderSizePixel = 0
	box.Parent = parent
	Style.stroke(box, C.ink, 2, 0)
	for _, s in { UDim2.new(0, 4, 1, 0), UDim2.new(1, 0, 0, 4) } do
		local band = Instance.new("Frame")
		band.AnchorPoint = Vector2.new(0.5, 0.5)
		band.Position = UDim2.fromScale(0.5, 0.5)
		band.Size = s
		band.BackgroundColor3 = C.pink
		band.BorderSizePixel = 0
		band.Parent = box
	end
	return box
end

local function clock(seconds: number): string
	local s = math.ceil(seconds)
	return string.format("%d:%02d", s // 60, s % 60)
end

function GiftChip.start()
	local hud = player:WaitForChild("PlayerGui"):WaitForChild("Hud") :: ScreenGui

	local chip = Instance.new("TextButton")
	chip.Name = "GiftChip"
	chip.AutoButtonColor = false
	chip.Text = ""
	chip.BackgroundColor3 = C.panel
	chip.BorderSizePixel = 0
	chip.AnchorPoint = Vector2.new(1, 0)
	chip.Position = UDim2.new(1, -14, 0, TOP)
	chip.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	chip.Visible = false
	chip.Parent = hud
	local edge = Style.stroke(chip, C.text, 2, 0.35)
	local box = giftBox(chip)
	local title = Style.label(chip, "", 16, F.display, C.text)
	title.AutoLocalize = false
	title.Position = UDim2.fromOffset(42, 4)
	title.Size = UDim2.new(1, -50, 0, 17)
	local sub = Style.label(chip, "", 11, F.heavy, C.dim)
	sub.AutoLocalize = false
	sub.Position = UDim2.fromOffset(42, 22)
	sub.Size = UDim2.new(1, -50, 0, 13)
	local bounce = Instance.new("UIScale")
	bounce.Parent = box
	local pulse = TweenService:Create(
		bounce,
		TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.2 }
	)

	local ready = false
	local function refresh()
		local start = player:GetAttribute("GiftStart")
		local claimed = player:GetAttribute("GiftsClaimed")
		if typeof(start) ~= "number" or typeof(claimed) ~= "number" or Style.sheetOpen() then
			chip.Visible = false
			return
		end
		local index = Gifts.nextIndex(claimed, Config.Minutes)
		local wasReady = ready
		ready = false
		if index then
			local played = workspace:GetServerTimeNow() - start
			ready = Gifts.open(index, played, Config.Minutes, 0)
			title.Text =
				Loc.text(if ready then "GiftOpen" else "GiftNext", { m = Config.Minutes[index] })
			sub.Text = if ready
				then Loc.text("GiftTap")
				else clock(Gifts.wait(index, played, Config.Minutes))
			box.Visible = true
		else
			local pay = player:GetAttribute("TomorrowPays")
			if typeof(pay) ~= "number" then
				chip.Visible = false
				return
			end
			title.Text = Loc.text("GiftTomorrow")
			sub.Text =
				Loc.text("TomorrowPays", { n = player:GetAttribute("TomorrowDay") or 2, pay = pay })
			box.Visible = false
		end
		chip.Visible = true
		edge.Color = if ready then C.yellow else C.text
		edge.Transparency = if ready then 0 else 0.35
		title.TextColor3 = if ready then C.yellow else C.text
		if ready ~= wasReady then
			if ready then
				pulse:Play()
			else
				pulse:Cancel()
				bounce.Scale = 1
			end
		end
	end

	Style.onTap(chip, function()
		if ready then
			Net.waitFor("ClaimGift"):FireServer()
		end
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(0.25)
		end
	end)
end

return GiftChip
