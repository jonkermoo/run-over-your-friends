--!strict
-- The next car to buy, under the cash: a yellow plate, "NEXT CAR: SEDAN  $1,240 / $3,000", and a little road the car
-- drives along as the cash comes in; a BUY! sticker once the cash covers it (a tap opens the garage on that car),
-- and a "!" badge on the GARAGE tile while it can be bought. Same pick as the
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
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local LayoutConfig = require(ReplicatedStorage.Shared.Config.Layout)
local Hud = require(script.Parent.Hud)
local Style = require(script.Parent.Style)

local C, F = Style.colors, Style.fonts
local player = Players.LocalPlayer

local NOT_FOR_CASH = { Roadster = true } -- the pass is the way to it
local FIRST_STEP_UP = (Vehicles.ById[Economy.RookieUntil] or { price = 0 }).price
local COLUMN = LayoutConfig.Column
local TOP = COLUMN.Top + COLUMN.Row + COLUMN.Gap -- under the cash
-- the car drawn on the road: the icon nearest each car's look (a plain red car otherwise)
local CAR_ICON: { [string]: number } = {
	Taxi = Icons.RoadCarTaxi,
	Sedan = Icons.RoadCarBlue,
	Muscle = Icons.RoadCarBlack,
	IceCream = Icons.RoadCarPink,
	Supercar = Icons.RoadCarYellow,
	Hatchback = Icons.RoadCarGreen,
	FireTruck = Icons.RoadCarRed,
}

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
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(1, 0)
	bar.Position = UDim2.new(1, -COLUMN.Right, 0, TOP)
	bar.Size = UDim2.fromOffset(COLUMN.Width, COLUMN.NextCar)
	bar.Visible = false
	bar.Parent = hud
	Style.sign(bar, "yellow", true)
	local name = Style.label(bar, "", 18, F.display, C.ink)
	name.AutoLocalize = false
	name.Position = UDim2.fromOffset(14, 8)
	name.Size = UDim2.new(1, -28, 0, 20)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local progress = Style.label(bar, "", 13, F.display, C.ink)
	progress.AutoLocalize = false
	progress.AnchorPoint = Vector2.new(1, 0)
	progress.Position = UDim2.new(1, -14, 0, 11)
	progress.Size = UDim2.fromOffset(120, 16)
	progress.TextXAlignment = Enum.TextXAlignment.Right
	-- the road: an asphalt bar with a lane line, the paint behind the car shows how far along you are
	local back, fill = Style.bar(bar, C.green)
	back.Position = UDim2.new(0, 14, 1, -32)
	back.Size = UDim2.new(1, -28, 0, 22)
	fill.BackgroundTransparency = 0.35
	local lane = Style.lane(back)
	lane.Position = UDim2.new(0, 6, 0.5, -2)
	lane.Size = UDim2.new(1, -12, 0, 4)
	lane.ZIndex = back.ZIndex + 1
	local car = Style.image(bar, Icons.RoadCarRed)
	car.Name = "Car"
	car.AnchorPoint = Vector2.new(0.5, 1)
	car.Size = UDim2.fromOffset(46, 46)
	car.ZIndex = 4
	-- the BUY! sticker on the top right corner once the cash covers it
	local buy = Style.pill(bar, "BUY!", C.red)
	buy.Name = "Buy"
	buy.TextSize = 18
	buy.AnchorPoint = Vector2.new(1, 0)
	buy.Position = UDim2.new(1, 12, 0, -14)
	buy.Size = UDim2.fromOffset(0, 28)
	buy.ZIndex = 5
	local buyPulse = Instance.new("UIScale")
	buyPulse.Parent = buy
	TweenService:Create(
		buyPulse,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.12 }
	):Play()

	-- the GARAGE tile's badge while the next car can be bought
	local garageButton = hud:FindFirstChild("GarageButton", true) :: GuiObject?
	local dot = Style.stop(hud, "!", 24)
	dot.Name = "AffordDot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -2, 0, 20)
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
		name.Text = "NEXT CAR: " .. string.upper(v and v.name or target)
		progress.Text = `{Style.money(math.min(cash, price))} / {Style.money(price)}`
		progress.Visible = not ready
		name.Size = UDim2.new(1, if ready then -28 else -150, 0, 20)
		buy.Visible = ready
		local k = math.clamp(cash / math.max(price, 1), 0, 1)
		fill.Size = UDim2.fromScale(k, 1)
		car.Image = `rbxassetid://{CAR_ICON[target] or Icons.RoadCarRed}`
		-- the car drives along the road (its middle stays on the road between 23 px from either end)
		car.Position = UDim2.new(0, 14 + 23 + k * (COLUMN.Width - 28 - 46), 1, -12)
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
