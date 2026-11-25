--!strict
-- The next car to buy, under the cash: "SEDAN $1,240 / $3,000" with a bar, BUY NOW once the cash covers it (a
-- tap opens the garage on that car), and a red dot on the GARAGE tab while it can be bought. Same pick as the
-- garage's NEXT UP and the tutorial: the cheapest car not owned, never the Scooter or Cart (a step down) or a pass
-- car.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)
local DailyRules = require(ReplicatedStorage.Shared.Rules.Daily)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local GarageRules = require(ReplicatedStorage.Shared.Rules.Garage)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Hud = require(script.Parent.Hud)
local Style = require(script.Parent.Style)

local C, F = Style.colors, Style.fonts
local player = Players.LocalPlayer

local NOT_FOR_CASH = { Roadster = true } -- the pass is the way to it
local FIRST_STEP_UP = (Vehicles.ById[Economy.RookieUntil] or { price = 0 }).price
local TOP, WIDTH, HEIGHT = 68, 196, 46 -- layout px, right under the cash box (Hud: 8 + 54 + 6)

local NextCar = {}

local function priceOf(id: string): number
	local v = Vehicles.ById[id]
	local sale = player:GetAttribute("CarOfDay")
	return DailyRules.price(
		id,
		v and v.price or 0,
		if typeof(sale) == "string" and sale ~= "" then sale else nil,
		DailyConfig.DiscountShare,
		DailyConfig.DiscountRound
	)
end

local function ownedSet(): { [string]: boolean }
	local set = {}
	for id in string.gmatch((player:GetAttribute("Owned") or "") :: string, "[^,]+") do
		set[id] = true
	end
	return set
end

function NextCar.start()
	local hud = player:WaitForChild("PlayerGui"):WaitForChild("Hud") :: ScreenGui

	local bar = Instance.new("TextButton")
	bar.Name = "NextCar"
	bar.AutoButtonColor = false
	bar.Text = ""
	bar.BackgroundColor3 = C.panel
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(1, 0)
	bar.Position = UDim2.new(1, -14, 0, TOP)
	bar.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	bar.Visible = false
	bar.Parent = hud
	Style.sign(bar, "green", true)
	local tag = Style.label(bar, "NEXT CAR", 10, F.heavy, C.yellow)
	tag.Position = UDim2.fromOffset(10, 5)
	tag.Size = UDim2.fromOffset(90, 11)
	local name = Style.label(bar, "", 17, F.display, C.text)
	name.AutoLocalize = false
	name.Position = UDim2.fromOffset(10, 15)
	name.Size = UDim2.fromOffset(110, 18)
	local progress = Style.label(bar, "", 12, F.heavy, C.dim)
	progress.AutoLocalize = false
	progress.AnchorPoint = Vector2.new(1, 0)
	progress.Position = UDim2.new(1, -10, 0, 17)
	progress.Size = UDim2.fromOffset(90, 14)
	progress.TextXAlignment = Enum.TextXAlignment.Right
	local buy = Style.pill(bar, "BUY NOW", C.yellow)
	buy.AnchorPoint = Vector2.new(1, 0)
	buy.Position = UDim2.new(1, -8, 0, 8)
	buy.Size = UDim2.fromOffset(78, 24)
	buy.TextSize = 14
	local back, fill = Style.bar(bar, C.money)
	back.Position = UDim2.new(0, 10, 1, -10)
	back.Size = UDim2.new(1, -20, 0, 5)

	-- the GARAGE tab's red dot while the next car can be bought
	local garageButton = hud:FindFirstChild("GarageButton", true) :: GuiObject?
	-- a stop-sign "!" badge on the sign's top right corner
	local dot = Style.stop(hud, "!", 22)
	dot.Name = "AffordDot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -4, 0, 12)
	dot.ZIndex = 5
	dot.Visible = false
	local pulse = Instance.new("UIScale")
	pulse.Parent = dot
	TweenService:Create(
		pulse,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.15 }
	):Play()
	dot.Parent = garageButton

	local target: string? = nil
	local function refresh()
		target =
			GarageRules.buyNext(Vehicles.List, ownedSet(), priceOf, NOT_FOR_CASH, FIRST_STEP_UP)
		local cash = (player:GetAttribute("Money") or 0) :: number
		local price = if target then priceOf(target) else 0
		local ready = target ~= nil and cash >= price
		bar.Visible = target ~= nil and not Style.sheetOpen()
		dot.Visible = ready
		if not target then
			return
		end
		local v = Vehicles.ById[target]
		name.Text = string.upper(v and v.name or target)
		progress.Text = `{Style.money(math.min(cash, price))} / {Style.money(price)}`
		progress.Visible = not ready
		buy.Visible = ready
		fill.Size = UDim2.fromScale(math.clamp(cash / math.max(price, 1), 0, 1), 1)
		Style.ring(bar, if ready then C.yellow else nil)
	end

	Style.onTap(bar, function()
		if target then
			Hud.openCar(target)
		end
	end)
	for _, key in { "Money", "Owned", "CarOfDay" } do
		player:GetAttributeChangedSignal(key):Connect(refresh)
	end
	-- sheets come and go without an attribute change: check a few times a second
	task.spawn(function()
		while true do
			refresh()
			task.wait(0.3)
		end
	end)
end

return NextCar
