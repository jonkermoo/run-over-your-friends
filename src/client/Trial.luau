--!strict
-- The Roadster free trial on screen (Config/Trial, server/TrialService): the FREE TRIAL button beside GET PASS
-- on the garage's Roadster card, the countdown chip while the trial runs, and the end card ("Come back tomorrow
-- for another drive", the cash bar toward the car, the Roadster pass button). The server decides everything;
-- the button only shows what the attributes say (Tutorial, Owned, PassRoadster, TrialAt, TrialLeft, VehicleId).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Cfg = require(ReplicatedStorage.Shared.Config.Trial)
local EventConfig = require(ReplicatedStorage.Shared.Config.Events)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Rules = require(ReplicatedStorage.Shared.Rules.Trial)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Pad = require(script.Parent.Pad)
local Popups = require(script.Parent.Popups)
local Style = require(script.Parent.Style)
local Track = require(script.Parent.Track)

local Trial = {}

local C, F = Style.colors, Style.fonts
local player = Players.LocalPlayer
local PRICE = Vehicles.ById[Cfg.Car].price

local gui = Instance.new("ScreenGui")
gui.Name = "Trial"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6 -- the end card sits over the HUD and the garage sheet
Style.fit(gui)

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- "14h" / "35m" until the next trial
local function untilText(seconds: number): string
	if seconds >= 3600 then
		return `{math.ceil(seconds / 3600)}h`
	end
	return `{math.max(1, math.ceil(seconds / 60))}m`
end

local function owns(): boolean
	if player:GetAttribute("Pass" .. Cfg.Car) == true then
		return true
	end
	local owned = "," .. ((player:GetAttribute("Owned") or "") :: string) .. ","
	return string.find(owned, "," .. Cfg.Car .. ",", 1, true) ~= nil
end

local function onScreen(g: GuiObject): boolean
	local at: Instance? = g
	while at and at:IsA("GuiObject") do
		if not at.Visible then
			return false
		end
		at = at.Parent
	end
	return at ~= nil and at:IsA("ScreenGui") and at.Enabled
end

-- the garage card's FREE TRIAL button, left of its action button (GET PASS); only on the trial car's card
function Trial.button(vehicleId: string, action: TextButton)
	if vehicleId ~= Cfg.Car then
		return
	end
	local fullSize, fullText = action.Size, action.TextSize
	local b = Style.button(action.Parent :: Instance, "FREE TRIAL", "gold", 22)
	b.Name = "Trial"
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.new(0.75, 6, 1, 0)
	b.Size = UDim2.new(0.25, -12, 0, fullSize.Y.Offset)
	b.Visible = false
	local ready = false -- a trial can start (or resume) from this button
	local offered = false
	local function refresh()
		local step = (player:GetAttribute("Tutorial") or 0) :: number
		local left = player:GetAttribute("TrialLeft")
		local show = not owns() and step >= Onboarding.Steps.Done
		b.Visible = show
		action.Size = if show then UDim2.new(0.25, -12, 0, fullSize.Y.Offset) else fullSize
		action.TextSize = if show then 22 else fullText
		if not show then
			ready = false
			return
		end
		if typeof(left) == "number" then
			local driving = player:GetAttribute("VehicleId") == Cfg.Car
			ready = not driving
			if driving then
				Loc.say(b, "DRIVING")
			else
				Loc.set(b, "TrialResume", { time = clock(left) })
			end
			Style.setKind(b, if driving then "dark" else "gold")
			return
		end
		local nextAt = Rules.nextAt((player:GetAttribute("TrialAt") or 0) :: number, Cfg)
		local remaining = nextAt - workspace:GetServerTimeNow()
		ready = remaining <= 0
		if ready then
			Loc.say(b, "FREE TRIAL")
			Style.setKind(b, "gold")
			if not offered and onScreen(b) then
				offered = true
				Net.waitFor("RoadsterTrial"):FireServer("Offered")
			end
		else
			Loc.set(b, "TrialIn", { time = untilText(remaining) })
			Style.setKind(b, "dark")
		end
	end
	b.Activated:Connect(function()
		if ready then
			Net.waitFor("RoadsterTrial"):FireServer("Start")
			local sheet = action:FindFirstAncestor("Garage") :: GuiObject?
			if sheet then
				sheet.Visible = false
			end
		end
	end)
	for _, name in { "Tutorial", "Owned", "Pass" .. Cfg.Car, "TrialAt", "TrialLeft", "VehicleId" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
	task.spawn(function()
		while b.Parent do
			task.wait(1)
			refresh() -- the cooldown counts down, and the card may have come on screen
		end
	end)
end

-- the countdown under the event sign while the trial car is out, a small sign like it (client/EventBanner):
-- yellow dashes above and below, the name on the left, the time on the right (pink near the end)
local SIGN = EventConfig.Card
local chip = Style.panel(gui)
chip.Name = "TrialChip"
chip.AnchorPoint = Vector2.new(0.5, 0)
chip.Position = UDim2.new(0.5, 0, 0, SIGN.Gap + SIGN.Height + 10)
chip.Size = UDim2.fromOffset(250, SIGN.Height)
chip.Visible = false
Style.dashes(chip, C.yellow).Position = UDim2.fromOffset(0, 3)
local chipBottom = Style.dashes(chip, C.yellow)
chipBottom.AnchorPoint = Vector2.new(0, 1)
chipBottom.Position = UDim2.new(0, 0, 1, -3)
local chipName = Style.label(chip, "ROADSTER TRIAL", SIGN.TitleText, F.display, C.text)
chipName.AnchorPoint = Vector2.new(0, 0.5)
chipName.Position = UDim2.fromOffset(14, SIGN.Height / 2)
chipName.Size = UDim2.new(1, -90, 0, SIGN.TitleText + 4)
chipName.TextXAlignment = Enum.TextXAlignment.Left
local chipTime = Style.label(chip, "", SIGN.TimerText, F.display, C.yellow)
chipTime.AnchorPoint = Vector2.new(1, 0.5)
chipTime.Position = UDim2.new(1, -14, 0, SIGN.Height / 2)
chipTime.Size = UDim2.fromOffset(70, SIGN.TimerText + 4)
chipTime.TextXAlignment = Enum.TextXAlignment.Right

local function refreshChip()
	local left = player:GetAttribute("TrialLeft")
	local show = typeof(left) == "number" and player:GetAttribute("VehicleId") == Cfg.Car
	chip.Visible = show
	if show then
		chipTime.Text = clock(left :: number)
		chipTime.TextColor3 = if (left :: number) <= Cfg.WarnSeconds then C.pink else C.yellow
	end
end

-- the end card, a poster like the garage's "can't afford it" card (client/Hud Upsell): hazard band, yellow edge, pink
-- shadow, the car and a lane-line bar of cash toward it, then the pass (gold) and KEEP DRIVING (dark)
local CARD_W, CARD_H = 500, 360
local card = Style.panel(gui)
card.Name = "TrialOver"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(CARD_W, CARD_H)
card.Visible = false
Style.stroke(card, C.yellow, 4, 0)
Style.setShadow(card, C.pink)
Style.hazard(card, CARD_W, 14)
local title = Style.label(card, "TRIAL OVER!", 40, F.display, C.yellow)
title.Position = UDim2.fromOffset(0, 26)
title.Size = UDim2.new(1, 0, 0, 44)
Style.outline(title, 2)
local pic = Instance.new("Frame")
pic.Name = "Picture"
pic.BackgroundColor3 = Color3.fromRGB(46, 46, 54)
pic.BorderSizePixel = 0
pic.Position = UDim2.fromOffset(24, 84)
pic.Size = UDim2.fromOffset(120, 70)
pic.Parent = card
Style.image(pic, Icons.PassRoadster).Size = UDim2.fromScale(1, 1)
local carName = Style.label(card, string.upper(Vehicles.ById[Cfg.Car].name), 20, F.display, C.text)
carName.Position = UDim2.fromOffset(158, 84)
carName.Size = UDim2.new(1, -182, 0, 24)
carName.TextXAlignment = Enum.TextXAlignment.Left
local barBack, barFill = Style.bar(card, C.money)
barBack.BackgroundTransparency = 0
barBack.Position = UDim2.fromOffset(158, 112)
barBack.Size = UDim2.new(1, -182, 0, 16)
Style.laneGaps(barBack, C.ink)
local amount = Style.label(card, "", 14, F.bold, C.dim)
amount.Position = UDim2.fromOffset(158, 132)
amount.Size = UDim2.new(1, -182, 0, 18)
amount.TextXAlignment = Enum.TextXAlignment.Left
local sub = Style.label(card, "Come back tomorrow for another drive", 18, F.bold, C.text)
sub.Position = UDim2.fromOffset(24, 172)
sub.Size = UDim2.new(1, -48, 0, 24)
sub.TextWrapped = true
local passBtn = Style.button(card, "GET ROADSTER PASS", "gold", 26)
passBtn.Name = "TrialPass"
passBtn.AnchorPoint = Vector2.new(0.5, 1)
passBtn.Position = UDim2.new(0.5, 0, 1, -62)
passBtn.Size = UDim2.fromOffset(320, 58)
local noBtn = Style.button(card, "KEEP DRIVING", "dark", 16)
noBtn.Name = "TrialNo"
noBtn.AnchorPoint = Vector2.new(0.5, 1)
noBtn.Position = UDim2.new(0.5, 0, 1, -14)
noBtn.Size = UDim2.fromOffset(200, 38)
local cardScale = Instance.new("UIScale")
cardScale.Parent = card
local shownLogged = false -- OfferPopup Shown once per trial, even if the card comes back after a drive
passBtn.Activated:Connect(function()
	card.Visible = false
	Track.offer("Trial", "Pressed")
	Net.waitFor("BuyPass"):FireServer(Cfg.Car)
end)
noBtn.Activated:Connect(function()
	card.Visible = false
end)
-- gamepad: it starts on the pass, and B is KEEP DRIVING
Pad.menu(card, {
	first = function()
		return passBtn
	end,
	close = function()
		card.Visible = false
	end,
})

local function endCard()
	local cash = (player:GetAttribute("Money") or 0) :: number
	barFill.Size = UDim2.fromScale(Rules.progress(cash, PRICE), 1)
	Loc.set(
		amount,
		"TrialBar",
		{ cash = Style.money(math.min(cash, PRICE)), price = Style.money(PRICE) }
	)
	cardScale.Scale = 0.8
	TweenService:Create(cardScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	card.Visible = true
	if not shownLogged then
		shownLogged = true
		Track.offer("Trial", "Shown")
	end
end

function Trial.start()
	gui.Parent = player:WaitForChild("PlayerGui")
	player:GetAttributeChangedSignal("TrialLeft"):Connect(refreshChip)
	player:GetAttributeChangedSignal("VehicleId"):Connect(refreshChip)
	refreshChip()
	Net.waitFor("TrialOver").OnClientEvent:Connect(function()
		-- through the queue of unasked-for cards (client/Popups): first in line, once the car has stopped
		shownLogged = false
		Popups.want("TrialOver", 0, endCard, function()
			card.Visible = false
		end, function()
			return card.Visible
		end)
	end)
end

return Trial
