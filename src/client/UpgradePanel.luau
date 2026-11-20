--!strict
-- The garage's mastery part of each car's panel (client/Hud builds the panel and calls attach): a mastery badge
-- and the "mastery road" (what each level opens) on the 3D picture, UPGRADES / PAINT / DECALS tabs on the right
-- (PAINT is client/PaintPicker's swatches), a yellow piece on the stat bars for the switched-on upgrades, five
-- mastery pips on the car's row, and the picture dressed with the car's upgrades and decal. Reads the player's
-- Owned, VehicleId, Money, Paint, Mastery, Upgrades and Decals attributes (server/Data); asks the server through
-- BuyUpgrade, SetUpgrade and SetDecal (server/UpgradeService).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Upgrades)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local PaintRules = require(ReplicatedStorage.Shared.Rules.Paints)
local Rules = require(ReplicatedStorage.Shared.Rules.Upgrades)
local VehicleParts = require(ReplicatedStorage.Shared.VehicleParts)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Style = require(script.Parent.Style)

local C, F = Style.colors, Style.fonts
local player = Players.LocalPlayer

local UpgradePanel = {}

export type Parts = {
	card: Frame,
	stats: Vehicles.Vehicle,
	shown: Model?, -- the 3D picture's model (a full template copy; parts are shown or hidden here)
	stage: Frame, -- the picture's frame
	info: Frame, -- the blurb and stat bars (bars are named SPEED, ACCEL, HANDLING, WEIGHT)
	bottom: Frame, -- the block under the picture
	paintSpot: Frame, -- client/PaintPicker's swatches
	row: TextButton, -- the car's row in the list
	rowTag: TextLabel,
}

export type Panel = { refresh: () -> () }

local ROMAN = { "I", "II", "III" }
local RIGHT = UDim2.new(0.5, 12, 0, 0) -- the right half of the bottom block, where the swatches sit
local RIGHT_SIZE = UDim2.new(0.5, -12, 0, 124)

local function json(name: string): { [string]: any }
	local raw = player:GetAttribute(name)
	if typeof(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, out = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and typeof(out) == "table" then out else {}
end

local function owns(id: string): boolean
	return string.find(
		"," .. ((player:GetAttribute("Owned") or "") :: string) .. ",",
		"," .. id .. ",",
		1,
		true
	) ~= nil
end

local function money(n: number): string
	local s = tostring(math.floor(n + 0.5))
	while true do
		local k
		s, k = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return "$" .. s
end

-- show or hide a picture's parts for these upgrades (a template copy keeps every piece; the swatches recolour
-- all the painted ones) and print its decal
function UpgradePanel.dress(model: Model, vehicleId: string, on: { number }, decalId: string?)
	local names = {}
	for _, p in model:GetChildren() do
		table.insert(names, p.Name)
	end
	local sets = Rules.wheelSets(names, on)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			if p:GetAttribute("BaseT") == nil then
				p:SetAttribute("BaseT", p.Transparency)
			end
			p.Transparency = if Rules.part(p.Name, on, sets) == "drop"
				then 1
				else p:GetAttribute("BaseT") :: number
		end
	end
	VehicleParts.decal(model, Rules.image(vehicleId, decalId))
end

-- the share of each stat bar a car fills (the same scales as client/Hud's bars)
local function shares(s: Vehicles.Vehicle): { [string]: number }
	return {
		SPEED = s.topSpeed / 250,
		ACCEL = s.launch / 15,
		HANDLING = s.grip / 22,
		WEIGHT = math.log10(s.weight / 50) / math.log10(20000 / 50),
	}
end

local function smallButton(parent: Instance, text: string, kind: string): TextButton
	local b = Style.button(parent, text, kind, 15)
	b.AnchorPoint = Vector2.new(0, 1)
	b.Position = UDim2.new(0, 8, 1, -8)
	b.Size = UDim2.new(1, -20, 0, 26)
	return b
end

function UpgradePanel.attach(p: Parts): Panel
	local stats = p.stats
	local id = stats.id
	local ups = Config.ByVehicle[id] or {}
	local tab = "Upgrades"

	-- mastery badge on the picture, beside the bay number
	local badge = Instance.new("Frame")
	badge.Name = "Mastery"
	badge.BackgroundColor3 = C.card
	badge.BorderSizePixel = 0
	badge.Position = UDim2.fromOffset(112, 14)
	badge.Size = UDim2.fromOffset(236, 44)
	badge.ZIndex = 2
	badge.Parent = p.stage
	local lvlBox = Style.label(badge, "0", 22, F.display, C.ink)
	lvlBox.BackgroundTransparency = 0
	lvlBox.BackgroundColor3 = C.yellow
	lvlBox.Position = UDim2.fromOffset(5, 5)
	lvlBox.Size = UDim2.fromOffset(36, 34)
	lvlBox.ZIndex = 3
	local lvlText = Style.label(badge, "", 13, F.heavy, C.dim)
	lvlText.Position = UDim2.fromOffset(50, 5)
	lvlText.Size = UDim2.new(1, -58, 0, 16)
	lvlText.TextXAlignment = Enum.TextXAlignment.Left
	lvlText.ZIndex = 3
	local back, fill = Style.bar(badge, C.yellow)
	back.BackgroundColor3 = C.ink
	back.BackgroundTransparency = 0
	back.Position = UDim2.fromOffset(50, 25)
	back.Size = UDim2.new(1, -60, 0, 10)
	back.ZIndex = 3
	fill.ZIndex = 3
	Style.laneGaps(back, C.card)

	-- the mastery road along the bottom of the picture: what each level opens
	local road = Instance.new("Frame")
	road.Name = "MasteryRoad"
	road.BackgroundColor3 = C.ink
	road.BackgroundTransparency = 0.12
	road.BorderSizePixel = 0
	road.AnchorPoint = Vector2.new(0, 1)
	road.Position = UDim2.fromScale(0, 1)
	road.Size = UDim2.new(1, 0, 0, 58)
	road.ZIndex = 2
	road.Parent = p.stage
	local lane = Style.dashes(road, C.grey, false, 4)
	lane.Position = UDim2.new(0.1, 0, 0, 17)
	lane.Size = UDim2.new(0.8, 0, 0, 4)
	lane.ZIndex = 2
	local laneDone = Style.dashes(road, C.yellow, false, 4)
	laneDone.Position = UDim2.new(0.1, 0, 0, 17)
	laneDone.ZIndex = 2
	local stops: { { dot: TextLabel, what: TextLabel } } = {}
	for level = 1, Config.MaxLevel do
		local x = 0.1 + 0.8 * (level - 1) / (Config.MaxLevel - 1)
		local dot = Style.label(road, tostring(level), 16, F.display, C.dim)
		dot.BackgroundTransparency = 0
		dot.BackgroundColor3 = C.grey
		dot.AnchorPoint = Vector2.new(0.5, 0)
		dot.Position = UDim2.new(x, 0, 0, 6)
		dot.Size = UDim2.fromOffset(26, 26)
		dot.ZIndex = 3
		local upgradeAt = table.find(Config.UpgradeLevel, level)
		local what = if upgradeAt and ups[upgradeAt]
			then string.upper(ups[upgradeAt].name)
			else string.upper(Config.Decals[level].name)
		local label = Style.label(road, what, 11, F.heavy, C.dim)
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(x, 0, 0, 36)
		label.Size = UDim2.new(0.19, 0, 0, 16)
		label.TextScaled = true
		label.ZIndex = 3
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = 12
		cap.Parent = label
		table.insert(stops, { dot = dot, what = label })
	end

	-- tabs over the right half of the bottom block
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.new(0.5, 12, 0, -30)
	tabs.Size = UDim2.new(0.5, -12, 0, 26)
	tabs.Parent = p.bottom
	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.Padding = UDim.new(0, 6)
	tabList.Parent = tabs
	local tabButtons: { [string]: TextButton } = {}
	local refresh: () -> ()
	for i, name in { "Upgrades", "Paint", "Decals" } do
		local b = Instance.new("TextButton")
		b.Name = name
		b.AutoButtonColor = false
		b.BorderSizePixel = 0
		b.FontFace = F.display
		b.TextSize = 16
		b.Text = string.upper(name)
		b.AutomaticSize = Enum.AutomaticSize.X
		b.Size = UDim2.fromOffset(0, 26)
		b.LayoutOrder = i
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.PaddingTop = UDim.new(0, 3)
		pad.Parent = b
		b.Parent = tabs
		b.Activated:Connect(function()
			tab = name
			refresh()
		end)
		tabButtons[name] = b
	end

	-- the three upgrade cards
	local upFrame = Instance.new("Frame")
	upFrame.Name = "Upgrades"
	upFrame.BackgroundTransparency = 1
	upFrame.Position = RIGHT
	upFrame.Size = RIGHT_SIZE
	upFrame.Parent = p.bottom
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(8, 0)
	grid.CellSize = UDim2.new(1 / 3, -6, 1, 0)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = upFrame
	local cards: { { frame: Frame, name: TextLabel, eff: TextLabel, state: TextLabel, button: TextButton } } =
		{}
	for n, up in ups do
		local f = Style.card(upFrame)
		f.Name = "Upgrade" .. n
		f.LayoutOrder = n
		local roman = Style.label(f, ROMAN[n], 14, F.display, C.yellow)
		roman.Position = UDim2.fromOffset(8, 5)
		roman.Size = UDim2.fromOffset(30, 16)
		roman.TextXAlignment = Enum.TextXAlignment.Left
		local state = Style.pill(f, "", C.yellow)
		state.TextSize = 10
		state.AnchorPoint = Vector2.new(1, 0)
		state.Position = UDim2.new(1, -6, 0, 5)
		state.Size = UDim2.fromOffset(0, 15)
		local name = Style.label(f, string.upper(up.name), 15, F.display, C.text)
		name.Position = UDim2.fromOffset(8, 22)
		name.Size = UDim2.new(1, -14, 0, 18)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextScaled = true
		local nameCap = Instance.new("UITextSizeConstraint")
		nameCap.MaxTextSize = 15
		nameCap.Parent = name
		local eff = Style.label(f, up.text, 11, F.heavy, C.money)
		eff.Position = UDim2.fromOffset(8, 42)
		eff.Size = UDim2.new(1, -14, 0, 40)
		eff.TextWrapped = true
		eff.TextXAlignment = Enum.TextXAlignment.Left
		eff.TextYAlignment = Enum.TextYAlignment.Top
		local button = smallButton(f, "", "dark")
		button.Name = "Action"
		button.Activated:Connect(function()
			local level = Rules.level((json("Mastery")[id] or 0) :: number)
			local set = json("Upgrades")[id]
			local bought = set and set[tostring(n)]
			if not Rules.upgradeOpen(level, n) then
				return
			elseif bought == nil then
				Net.waitFor("BuyUpgrade"):FireServer(id, n)
			else
				Net.waitFor("SetUpgrade"):FireServer(id, n, not bought)
			end
		end)
		table.insert(cards, { frame = f, name = name, eff = eff, state = state, button = button })
	end

	-- decal tiles: none and the five decals, each a strip of its art on the car's paint colour
	local decalFrame = Instance.new("Frame")
	decalFrame.Name = "Decals"
	decalFrame.BackgroundTransparency = 1
	decalFrame.Position = RIGHT
	decalFrame.Size = RIGHT_SIZE
	decalFrame.Parent = p.bottom
	local dgrid = Instance.new("UIGridLayout")
	dgrid.CellPadding = UDim2.fromOffset(8, 8)
	dgrid.CellSize = UDim2.new(1 / 3, -6, 0.5, -4)
	dgrid.SortOrder = Enum.SortOrder.LayoutOrder
	dgrid.Parent = decalFrame
	local tiles: {
		{
			id: string,
			level: number,
			button: TextButton,
			art: ImageLabel,
			lock: TextLabel,
			edge: UIStroke,
		}
	} =
		{}
	local list = { { id = "None", level = 0, name = "None" } }
	for _, d in Config.Decals do
		table.insert(list, d :: any)
	end
	for i, d in list do
		local b = Instance.new("TextButton")
		b.Name = d.id
		b.AutoButtonColor = false
		b.BackgroundColor3 = C.card
		b.BorderSizePixel = 0
		b.Text = ""
		b.LayoutOrder = i
		b.Parent = decalFrame
		local edge = Style.stroke(b, C.yellow, 3, 1)
		local art = Instance.new("ImageLabel")
		art.Name = "Art"
		art.BorderSizePixel = 0
		art.Position = UDim2.fromOffset(4, 4)
		art.Size = UDim2.new(1, -8, 1, -22)
		art.ScaleType = Enum.ScaleType.Stretch
		-- the left-side band of the decal image (its top third)
		art.ImageRectOffset = Vector2.new(0, 0)
		art.ImageRectSize = Vector2.new(1024, 341)
		art.Parent = b
		local name = if d.id == "Signature" then Config.Signature[id] or d.name else d.name
		local label = Style.label(b, string.upper(name), 11, F.heavy, C.text)
		label.AnchorPoint = Vector2.new(0, 1)
		label.Position = UDim2.new(0, 4, 1, -2)
		label.Size = UDim2.new(1, -8, 0, 15)
		label.TextScaled = true
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = 11
		cap.Parent = label
		local lock = Style.label(b, "", 12, F.display, C.yellow)
		lock.Position = UDim2.fromOffset(4, 4)
		lock.Size = UDim2.new(1, -8, 1, -22)
		lock.ZIndex = 2
		Style.outline(lock, 2)
		b.Activated:Connect(function()
			local level = Rules.level((json("Mastery")[id] or 0) :: number)
			if d.level <= level then
				Net.waitFor("SetDecal"):FireServer(id, d.id)
			end
		end)
		table.insert(
			tiles,
			{ id = d.id, level = d.level, button = b, art = art, lock = lock, edge = edge }
		)
	end

	-- a yellow piece on the end of each stat bar: what the switched-on upgrades add
	local extras: { [string]: Frame } = {}
	for _, name in { "SPEED", "ACCEL", "HANDLING", "WEIGHT" } do
		local bar = p.info:FindFirstChild(name)
		if bar and bar:IsA("Frame") then
			local up = Instance.new("Frame")
			up.Name = "Up"
			up.BackgroundColor3 = C.yellow
			up.BorderSizePixel = 0
			up.Size = UDim2.fromScale(0, 1)
			up.Parent = bar
			extras[name] = up
		end
	end

	-- five mastery pips on the car's row (in place of OWNED)
	local pips = Instance.new("Frame")
	pips.Name = "Pips"
	pips.BackgroundTransparency = 1
	pips.AnchorPoint = Vector2.new(1, 0.5)
	pips.Position = UDim2.new(1, -14, 0.5, 0)
	pips.Size = UDim2.fromOffset(50, 16)
	pips.Visible = false
	pips.Parent = p.row
	local pipList = Instance.new("UIListLayout")
	pipList.FillDirection = Enum.FillDirection.Horizontal
	pipList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	pipList.Padding = UDim.new(0, 3)
	pipList.Parent = pips
	local pipFrames: { Frame } = {}
	for i = 1, Config.MaxLevel do
		local pip = Instance.new("Frame")
		pip.BorderSizePixel = 0
		pip.Size = UDim2.fromOffset(7, 16)
		pip.LayoutOrder = i
		pip.Parent = pips
		table.insert(pipFrames, pip)
	end

	function refresh()
		local mine = owns(id)
		local points = (json("Mastery")[id] or 0) :: number
		local level, into, span = Rules.progress(points)
		local saved = (json("Upgrades")[id] or {}) :: { [string]: boolean }
		local on = Rules.onList(saved)
		local decal = json("Decals")[id] :: string?
		local cash = (player:GetAttribute("Money") or 0) :: number

		-- badge and road
		lvlBox.Text = tostring(level)
		if level >= Config.MaxLevel then
			Loc.set(lvlText, "Mastered")
			fill.Size = UDim2.fromScale(1, 1)
		else
			Loc.set(lvlText, "MasteryPoints", { have = into, need = span })
			fill.Size = UDim2.fromScale(if span > 0 then into / span else 0, 1)
		end
		laneDone.Size = UDim2.new(
			0.8
				* math.clamp(
					(level - 1 + (if span > 0 then into / span else 0)) / (Config.MaxLevel - 1),
					0,
					1
				),
			0,
			0,
			4
		)
		for i, s in stops do
			local done = level >= i
			s.dot.BackgroundColor3 = if done then C.yellow else C.grey
			s.dot.TextColor3 = if done then C.ink else C.dim
			s.what.TextColor3 = if done then C.text else C.dim
		end

		-- tabs: only for a car you own; PAINT shows client/PaintPicker's swatches
		tabs.Visible = mine
		for name, b in tabButtons do
			b.BackgroundColor3 = if name == tab then C.yellow else C.card
			b.TextColor3 = if name == tab then C.ink else C.dim
		end
		upFrame.Visible = mine and tab == "Upgrades"
		decalFrame.Visible = mine and tab == "Decals"
		if mine and tab ~= "Paint" then
			p.paintSpot.Visible = false
		end

		-- upgrade cards
		for n, c in cards do
			local open = Rules.upgradeOpen(level, n)
			local bought = saved[tostring(n)]
			c.name.TextTransparency = if open then 0 else 0.5
			c.eff.TextTransparency = if open then 0 else 0.5
			c.state.Visible = bought ~= nil
			if bought ~= nil then
				Loc.say(c.state, if bought then "FITTED" else "STORED")
				c.state.BackgroundColor3 = if bought then C.yellow else C.grey
				c.state.TextColor3 = if bought then C.ink else C.text
			end
			if not open then
				Loc.set(c.button, "MasteryNeed", { n = Config.UpgradeLevel[n] })
				Style.setKind(c.button, "dark")
			elseif bought == nil then
				local price = Rules.price(id, stats.price, n)
				Loc.set(c.button, "BuyPrice", { price = money(price) })
				Style.setKind(c.button, if cash >= price then "green" else "dark")
			else
				Loc.say(c.button, if bought then "ON" else "OFF")
				Style.setKind(c.button, if bought then "gold" else "dark")
			end
		end

		-- decal tiles on the car's paint colour
		local paintId = PaintRules.decode((player:GetAttribute("Paint") or "") :: string)[id]
		local rgb = PaintRules.colour(id, paintId)
		for _, t in tiles do
			local open = t.level <= level
			local image = if t.id == "None" then 0 else Rules.image(id, t.id)
			t.art.Image = if image ~= 0 then `rbxassetid://{image}` else ""
			t.art.BackgroundColor3 = if rgb then Color3.fromRGB(rgb[1], rgb[2], rgb[3]) else C.grey
			t.art.ImageTransparency = if open then 0 else 0.6
			t.art.BackgroundTransparency = if open then 0 else 0.6
			t.lock.Visible = not open
			if not open then
				Loc.set(t.lock, "MasteryNeed", { n = t.level })
			end
			local chosen = (decal or "None") == t.id
			t.edge.Transparency = if chosen then 0 else 1
		end

		-- stat bars: the base share stays the car's own; the upgrades' extra is yellow on the end
		local base, now = shares(stats), shares(Rules.stats(stats, on))
		for name, up in extras do
			local from = math.clamp(base[name], 0.05, 1)
			local to = math.clamp(now[name], 0.05, 1)
			up.Position = UDim2.fromScale(from, 0)
			up.Size = UDim2.fromScale(math.max(0, to - from), 1)
		end

		-- the row: pips while owned and not out (client/Hud shows IN USE then)
		local inUse = player:GetAttribute("VehicleId") == id
		pips.Visible = mine and not inUse
		if pips.Visible then
			p.rowTag.Visible = false
		end
		for i, pip in pipFrames do
			pip.BackgroundColor3 = if i <= level then C.yellow else C.grey
		end

		-- the picture wears the car's upgrades and decal
		if p.shown then
			UpgradePanel.dress(p.shown, id, on, decal)
		end
	end

	for _, attr in { "Mastery", "Upgrades", "Decals", "Money", "Owned" } do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	refresh()
	return { refresh = refresh }
end

return UpgradePanel
