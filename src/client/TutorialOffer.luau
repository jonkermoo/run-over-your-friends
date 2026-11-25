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

local CARD_W, CARD_H = 560, 440

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
Style.hazard(card, CARD_W, 14)
local scale = Instance.new("UIScale")
scale.Parent = card

local tag = Style.pill(card, "NEW HERE?", C.pink)
tag.TextColor3 = C.text
tag.TextSize = 15
tag.Size = UDim2.fromOffset(0, 24)
tag.AnchorPoint = Vector2.new(0.5, 0)
tag.Position = UDim2.new(0.5, 0, 0, 30)

local title = Style.label(card, "LEARN TO WRECK THE CITY", 46, F.display, C.yellow)
title.Position = UDim2.fromOffset(20, 62)
title.Size = UDim2.new(1, -40, 0, 54)
title.Rotation = -3
title.TextScaled = true
Style.outline(title, 3)
local titleFit = Instance.new("UITextSizeConstraint")
titleFit.MaxTextSize = 46
titleFit.Parent = title

local sub = Style.label(card, "Hit people, smash buildings, tune your car", 17, F.heavy, C.dim)
sub.Position = UDim2.fromOffset(20, 122)
sub.Size = UDim2.new(1, -40, 0, 22)
sub.TextScaled = true
local subFit = Instance.new("UITextSizeConstraint")
subFit.MaxTextSize = 17
subFit.Parent = sub

-- the reward: the money pictures on the left, what you get on the right
local reward = Style.card(card)
reward.Name = "Reward"
reward.Position = UDim2.fromOffset(40, 158)
reward.Size = UDim2.new(1, -80, 0, 100)
local edge = Instance.new("Frame")
edge.BackgroundColor3 = C.money
edge.BorderSizePixel = 0
edge.Size = UDim2.new(0, 6, 1, 0)
edge.Parent = reward
local bill = Style.image(reward, Icons.Bill)
bill.AnchorPoint = Vector2.new(0.5, 0.5)
bill.Position = UDim2.fromOffset(70, 46)
bill.Size = UDim2.fromOffset(78, 78)
bill.Rotation = -8
local coin = Style.image(reward, Icons.Coin)
coin.AnchorPoint = Vector2.new(0.5, 0.5)
coin.Position = UDim2.fromOffset(104, 64)
coin.Size = UDim2.fromOffset(46, 46)
local finish = Style.label(reward, "FINISH IT AND GET", 16, F.heavy, C.yellow)
finish.Position = UDim2.fromOffset(150, 14)
finish.Size = UDim2.new(1, -164, 0, 20)
finish.TextXAlignment = Enum.TextXAlignment.Left
local amount = Style.label(reward, "", 52, F.display, C.money)
amount.AutoLocalize = false
amount.Text = "+" .. Style.money(Onboarding.FinishBonus)
amount.Position = UDim2.fromOffset(150, 36)
amount.Size = UDim2.new(1, -164, 0, 56)
amount.TextXAlignment = Enum.TextXAlignment.Left
Style.outline(amount, 3)

local start = Style.button(card, "START TUTORIAL", "green", 38)
start.Name = "StartTutorial"
start.AnchorPoint = Vector2.new(0.5, 0)
start.Position = UDim2.new(0.5, 0, 0, 280)
start.Size = UDim2.fromOffset(440, 84)
start.ZIndex = 3
local no = Style.button(card, "NO THANKS", "dark", 16)
no.Name = "NoThanks"
no.AnchorPoint = Vector2.new(0.5, 1)
no.Position = UDim2.new(0.5, 0, 1, -16)
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
	-- the big button breathes a little so the eye lands on it
	task.spawn(function()
		while true do
			task.wait()
			if gui.Enabled then
				start.Rotation = 1.5 * math.sin(os.clock() * 5)
			end
		end
	end)
	task.spawn(bindTab)
end

return TutorialOffer
