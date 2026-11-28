--!strict
-- The play-time gift in the right column, under the next-car road (the left middle is the phone thumbstick's):
-- a purple plate with the gift icon poking out of it and a countdown chip, OPEN YOUR GIFT! once it can be claimed (a tap opens the goals sheet,
-- where client/GiftRows claims it), and after the last gift the first-day "come back tomorrow" line, else nothing. GiftService publishes
-- GiftStart and GiftsClaimed; DailyService publishes TomorrowDay and TomorrowPays.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Gifts)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Gifts = require(ReplicatedStorage.Shared.Rules.Gifts)
local LayoutConfig = require(ReplicatedStorage.Shared.Config.Layout)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Goals = require(script.Parent.Goals)
local Hud = require(script.Parent.Hud)
local Style = require(script.Parent.Style)

local C, F = Style.colors, Style.fonts
local player = Players.LocalPlayer

local COLUMN = LayoutConfig.Column
local TOP = COLUMN.Top + COLUMN.Row + COLUMN.NextCar + COLUMN.Gap * 2 -- under the next-car road (client/NextCar)

local GiftChip = {}

-- the gift icon, poking out of the plate's left end
local function giftBox(parent: Instance): ImageLabel
	local box = Style.image(parent, Icons.RoadGift)
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Size = UDim2.fromOffset(58, 58)
	box.Position = UDim2.new(0, 8, 0.5, -6)
	box.ZIndex = 4
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
	chip.BorderSizePixel = 0
	chip.AnchorPoint = Vector2.new(1, 0)
	chip.Position = UDim2.new(1, -COLUMN.Right, 0, TOP)
	chip.Size = UDim2.fromOffset(COLUMN.Width, COLUMN.Gift)
	chip.Visible = false
	chip.Parent = hud
	Style.sign(chip, "purple", true)
	local box = giftBox(chip)
	-- one line: the title and a black timer chip; after the last gift, two lines (title over the tomorrow line)
	local title = Style.label(chip, "", 20, F.display, C.text)
	title.AutoLocalize = false
	title.AnchorPoint = Vector2.new(0, 0.5)
	title.Position = UDim2.new(0, 46, 0.5, -1)
	title.Size = UDim2.new(1, -140, 0, 22)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextScaled = true
	do
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = 20
		fit.Parent = title
	end
	local sub = Style.chip(chip, "", 18)
	sub.AutoLocalize = false
	sub.AnchorPoint = Vector2.new(1, 0.5)
	sub.Position = UDim2.new(1, -8, 0.5, -1)
	sub.Size = UDim2.fromOffset(82, 32)
	local line = Style.label(chip, "", 12, F.bold, C.text)
	line.AutoLocalize = false
	line.Position = UDim2.fromOffset(46, 26)
	line.Size = UDim2.new(1, -56, 0, 16)
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextTruncate = Enum.TextTruncate.AtEnd
	line.Visible = false
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
			sub.Text = clock(Gifts.wait(index, played, Config.Minutes))
			sub.Visible = not ready
			title.Size = UDim2.new(1, if ready then -56 else -140, 0, 22)
			title.Position = UDim2.new(0, 46, 0.5, -1)
			line.Visible = false
			box.Visible = true
		else
			local pay = player:GetAttribute("TomorrowPays")
			if typeof(pay) ~= "number" then
				chip.Visible = false
				return
			end
			title.Text = Loc.text("GiftTomorrow")
			line.Text = Loc.text(
				"TomorrowPays",
				{ n = player:GetAttribute("TomorrowDay") or 2, pay = Style.money(pay) }
			)
			line.Visible = true
			sub.Visible = false
			title.Size = UDim2.new(1, -56, 0, 20)
			title.Position = UDim2.fromOffset(46, 15)
			box.Visible = true
		end
		chip.Visible = true
		Style.ring(chip, if ready then C.yellow else nil)
		if ready ~= wasReady then
			if ready then
				pulse:Play()
			else
				pulse:Cancel()
				bounce.Scale = 1
			end
		end
	end

	-- the gifts are claimed in the goals sheet (client/GiftRows)
	Style.onTap(chip, function()
		Hud.closeSheets()
		Goals.openGifts()
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(0.25)
		end
	end)
end

return GiftChip
