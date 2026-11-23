--!strict
-- The Roadster free trial on screen (Config/Trial, server/TrialService): the FREE TRIAL button beside GET PASS
-- on the garage's Roadster card, the countdown chip while the trial runs, and the end card ("Come back tomorrow
-- for another drive", the cash bar toward the car, the Roadster pass button). The server decides everything;
-- the button only shows what the attributes say (Tutorial, Owned, PassRoadster, TrialAt, TrialLeft, VehicleId).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Cfg = require(ReplicatedStorage.Shared.Config.Trial)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Rules = require(ReplicatedStorage.Shared.Rules.Trial)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
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

-- the countdown chip at the top of the screen while the trial car is out
local chip = Style.pill(gui, "", C.yellow)
chip.Name = "TrialChip"
chip.TextSize = 20
chip.FontFace = F.display
chip.Size = UDim2.fromOffset(0, 30)
chip.AnchorPoint = Vector2.new(0.5, 0)
chip.Position = UDim2.new(0.5, 0, 0, 64)
chip.Visible = false
Style.stroke(chip, C.ink, 2, 0)

local function refreshChip()
	local left = player:GetAttribute("TrialLeft")
	local show = typeof(left) == "number" and player:GetAttribute("VehicleId") == Cfg.Car
	chip.Visible = show
	if show then
		Loc.set(chip, "TrialChip", { time = clock(left :: number) })
		chip.BackgroundColor3 = if (left :: number) <= Cfg.WarnSeconds then C.pink else C.yellow
		chip.TextColor3 = if (left :: number) <= Cfg.WarnSeconds then C.text else C.ink
	end
end

local card: Frame? = nil

-- the end card: come back tomorrow, the cash bar toward the car, and its pass
local function endCard()
	if card then
		card:Destroy()
	end
	local c = Style.panel(gui)
	card = c
	c.Name = "TrialOver"
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Position = UDim2.fromScale(0.5, 0.45)
	c.Size = UDim2.fromOffset(440, 250)
	Style.stroke(c, C.yellow, 3, 0)
	local title = Style.label(c, "TRIAL OVER!", 34, F.display, C.yellow)
	title.Position = UDim2.fromOffset(0, 14)
	title.Size = UDim2.new(1, 0, 0, 40)
	Style.outline(title, 2)
	local sub = Style.label(c, "Come back tomorrow for another drive", 18, F.bold, C.text)
	sub.Position = UDim2.fromOffset(20, 58)
	sub.Size = UDim2.new(1, -40, 0, 24)
	sub.TextWrapped = true
	local cash = (player:GetAttribute("Money") or 0) :: number
	local back, fill = Style.bar(c, C.money)
	back.Position = UDim2.fromOffset(24, 100)
	back.Size = UDim2.new(1, -48, 0, 18)
	fill.Size = UDim2.fromScale(Rules.progress(cash, PRICE), 1)
	local amount = Style.label(c, "", 16, F.heavy, C.money)
	Loc.set(
		amount,
		"TrialBar",
		{ cash = Style.money(math.min(cash, PRICE)), price = Style.money(PRICE) }
	)
	amount.Position = UDim2.fromOffset(24, 122)
	amount.Size = UDim2.new(1, -48, 0, 20)
	local pass = Style.button(c, "GET ROADSTER PASS", "blue", 22)
	pass.AnchorPoint = Vector2.new(0, 1)
	pass.Position = UDim2.new(0, 24, 1, -20)
	pass.Size = UDim2.new(0.62, -24, 0, 56)
	local later = Style.button(c, "LATER", "dark", 22)
	later.AnchorPoint = Vector2.new(1, 1)
	later.Position = UDim2.new(1, -24, 1, -20)
	later.Size = UDim2.new(0.38, -18, 0, 56)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = c
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local function close()
		if card == c then
			card = nil
		end
		c:Destroy()
	end
	pass.Activated:Connect(function()
		Track.offer("Trial", "Pressed")
		Net.waitFor("BuyPass"):FireServer(Cfg.Car)
		close()
	end)
	later.Activated:Connect(close)
	Track.offer("Trial", "Shown")
end

function Trial.start()
	gui.Parent = player:WaitForChild("PlayerGui")
	player:GetAttributeChangedSignal("TrialLeft"):Connect(refreshChip)
	player:GetAttributeChangedSignal("VehicleId"):Connect(refreshChip)
	refreshChip()
	Net.waitFor("TrialOver").OnClientEvent:Connect(function()
		task.delay(Style.stage(2), endCard) -- after the swap back settles, and in turn for the middle of the screen
	end)
end

return Trial
