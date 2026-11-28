--!strict
-- The first-join tutorial offer: a big card in the middle of a dimmed screen, the finish bonus on it, a huge
-- START TUTORIAL and a small NO THANKS. It shows while the player attribute "TutorialOffer" is set (by
-- server/Onboarding: a new player, or the join after one "No thanks") and holds every other pop-up back until
-- it's answered (Popups.addBusy). Also the menu strip's TUTORIAL tab (made by client/Hud, named TutorialButton),
-- shown while "TutorialTab" is set: it starts the tutorial again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Pad = require(script.Parent.Pad)
local Popups = require(script.Parent.Popups)
local PopupsConfig = require(ReplicatedStorage.Shared.Config.Popups)
local Style = require(script.Parent.Style)

local TutorialOffer = {}

local C, F = Style.colors, Style.fonts
local player = Players.LocalPlayer

local CARD_W, CARD_H = 500, 380

local gui = Instance.new("ScreenGui")
gui.Name = "TutorialOffer"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20 -- over the HUD, its sheets and the other cards
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- the card's pieces draw over the card, in build order
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
Style.fit(gui)

-- the dimmed screen behind the card takes every click, so nothing behind it can be pressed
local dim = Instance.new("TextButton")
dim.Name = "Dim"
dim.Text = ""
dim.AutoButtonColor = false
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.3
dim.BorderSizePixel = 0
dim.Size = UDim2.fromScale(1, 1)
dim.Selectable = false
dim.Parent = gui

local card = Style.panel(gui)
card.Name = "OfferCard"
Style.slot(card)
card.Size = UDim2.fromOffset(CARD_W, CARD_H)
card.ZIndex = 2
Style.hazard(card, CARD_W, 20)
local scale = Instance.new("UIScale")
scale.Parent = card
Style.topIcon(card, Icons.RoadCone, 116)

local title = Style.label(card, "LEARN TO WRECK THE CITY", 38, F.display, C.text)
title.Position = UDim2.fromOffset(20, 72)
title.Size = UDim2.new(1, -40, 0, 42)
title.TextScaled = true
Style.outline(title, 3)
local titleFit = Instance.new("UITextSizeConstraint")
titleFit.MaxTextSize = 38
titleFit.Parent = title

local sub = Style.label(card, "Hit people, smash buildings, tune your car", 18, F.bold, C.text)
sub.Position = UDim2.fromOffset(30, 118)
sub.Size = UDim2.new(1, -60, 0, 24)
sub.TextScaled = true
local subFit = Instance.new("UITextSizeConstraint")
subFit.MaxTextSize = 18
subFit.Parent = sub

-- the reward: a yellow plate, a coin and what finishing pays
local reward = Instance.new("Frame")
reward.Name = "Reward"
reward.AnchorPoint = Vector2.new(0.5, 0)
reward.Position = UDim2.new(0.5, 0, 0, 158)
reward.Size = UDim2.fromOffset(320, 50)
reward.Parent = card
Style.sign(reward, "yellow", true)
local coin = Style.image(reward, Icons.RoadCoin)
coin.AnchorPoint = Vector2.new(0.5, 0.5)
coin.Position = UDim2.new(0, 30, 0.5, -1)
coin.Size = UDim2.fromOffset(40, 40)
local amount = Style.label(reward, "", 22, F.display, C.ink)
amount.AutoLocalize = false
amount.Text = "FINISH IT: +" .. Style.money(Onboarding.FinishBonus)
amount.Position = UDim2.fromOffset(56, 0)
amount.Size = UDim2.new(1, -66, 1, -2)
amount.TextXAlignment = Enum.TextXAlignment.Left

local start = Style.button(card, "START TUTORIAL", "green", 32)
start.Name = "StartTutorial"
start.AnchorPoint = Vector2.new(0.5, 0)
start.Position = UDim2.new(0.5, 0, 0, 230)
start.Size = UDim2.new(1, -48, 0, 68)
start.ZIndex = 3
local no = Style.quiet(card, "NO THANKS", 17)
no.Name = "NoThanks"
no.AnchorPoint = Vector2.new(0.5, 1)
no.Position = UDim2.new(0.5, 0, 1, -18)
no.Size = UDim2.fromOffset(160, 36)
no.ZIndex = 3

local shownWhere: string? = nil -- the offer on screen now ("First" / "Again"), nil when hidden
local answered = false

function TutorialOffer.isOpen(): boolean
	return gui.Enabled
end

local function hide()
	gui.Enabled = false
	card.Visible = false
	shownWhere = nil
end

local function show(where: string, again: boolean?)
	if shownWhere == where then
		return
	end
	shownWhere = where
	answered = false
	gui.Enabled = true
	card.Visible = true
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if not again then
		Net.waitFor("TutorialOffer"):FireServer("Shown")
	end
end

local function answer(action: string)
	if answered or not shownWhere then
		return
	end
	answered = true
	hide()
	Net.waitFor("TutorialOffer"):FireServer(action)
end

-- X: away without an answer; it comes back after a while if still unanswered (Config/Popups ReturnSeconds)
local snoozedUntil = 0
Style.closeX(card, function()
	local where = shownWhere
	hide()
	snoozedUntil = os.clock() + PopupsConfig.ReturnSeconds
	task.delay(PopupsConfig.ReturnSeconds, function()
		local now = player:GetAttribute("TutorialOffer")
		if where and now == where and not shownWhere and not answered then
			show(where, true)
		end
	end)
end)

local function refresh()
	if os.clock() < snoozedUntil then
		return
	end
	local where = player:GetAttribute("TutorialOffer")
	if typeof(where) == "string" then
		show(where)
	else
		hide()
	end
end

-- the menu strip's TUTORIAL tab (client/Hud makes it hidden; it only shows after a "No thanks")
local function bindTab()
	local hud = player:WaitForChild("PlayerGui"):WaitForChild("Hud", 30)
	local tab = hud and hud:FindFirstChild("TutorialButton", true) :: TextButton?
	if not tab then
		return
	end
	local function showTab()
		tab.Visible = player:GetAttribute("TutorialTab") == true
	end
	player:GetAttributeChangedSignal("TutorialTab"):Connect(showTab)
	showTab()
	Style.onTap(tab, function()
		if tab.Visible then
			tab.Visible = false
			Net.waitFor("TutorialOffer"):FireServer("Restart")
		end
	end)
end

function TutorialOffer.start()
	hide()
	Style.onTap(start, function()
		answer("Start")
	end)
	Style.onTap(no, function()
		answer("Decline")
	end)
	-- gamepad: it opens on START TUTORIAL; B does nothing here, so the answer is always a real press
	Pad.menu(card, {
		first = function()
			return start
		end,
		close = function() end,
	})
	Popups.addBusy(TutorialOffer.isOpen)
	player:GetAttributeChangedSignal("TutorialOffer"):Connect(refresh)
	refresh()
	task.spawn(bindTab)
end

return TutorialOffer
