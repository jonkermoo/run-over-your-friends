--!strict
-- The SETTINGS tile left of the cash box (it took the MUSIC and UI tiles' place) and its panel
-- (Config/Settings): Music on/off (client/Music, saved), Show UI on/off (client/HideUi; U still toggles it)
-- and who can ride in my car (Config/Riders, saved with SetRideMode; the server enforces it). The tile stays
-- up while the UI is hidden. Tap or click it, or press the gamepad's View button; X, the tile again or B
-- closes it.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Settings)
local LayoutConfig = require(ReplicatedStorage.Shared.Config.Layout)
local LayoutRules = require(ReplicatedStorage.Shared.Rules.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local RiderRules = require(ReplicatedStorage.Shared.Rules.Riders)
local RidersConfig = require(ReplicatedStorage.Shared.Config.Riders)
local HideUi = require(script.Parent.HideUi)
local Music = require(script.Parent.Music)
local Pad = require(script.Parent.Pad)
local Style = require(script.Parent.Style)

local Settings = {}

local C, F = Style.colors, Style.fonts
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Settings"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6 -- over the HUD and its sheets
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Style.fit(gui)

---------------------------------------------------------------- the tile

local tile = Instance.new("TextButton")
tile.Name = "SettingsButton"
tile.AutoButtonColor = false
tile.BackgroundColor3 = C.panel
tile.BorderSizePixel = 0
tile.Text = ""
tile.AnchorPoint = Vector2.new(1, 0)
tile.Position = UDim2.new(1, -(14 + 196 + Cfg.TileGap), 0, 8)
tile.Size = UDim2.fromOffset(Cfg.TileWidth, Cfg.TileHeight)
tile.Parent = gui
Style.sign(tile, "white", true)
local tileTag = Style.label(tile, "GAME", 11, F.heavy, C.yellow)
tileTag.Position = UDim2.fromOffset(0, 6)
tileTag.Size = UDim2.new(1, 0, 0, 12)
local tileWord = Style.label(tile, "SETTINGS", 19, F.display, C.text)
tileWord.Position = UDim2.fromOffset(0, 20)
tileWord.Size = UDim2.new(1, 0, 0, 26)

---------------------------------------------------------------- the panel

local W = Cfg.PanelWidth
local H = Cfg.Header + Cfg.RowHeight * 2 + Cfg.RideRowHeight + Cfg.RowGap * 2 + Cfg.Pad

local sheet = Style.panel(gui)
sheet.Name = "SettingsSheet"
sheet.AnchorPoint = Vector2.new(0.5, 0.5)
sheet.Size = UDim2.fromOffset(W, H)
sheet.Visible = false
sheet.ZIndex = 5
Style.sign(sheet, "white")

local title = Style.label(sheet, "SETTINGS", 32, F.display, C.yellow)
title.Position = UDim2.fromOffset(Cfg.Pad, 12)
title.Size = UDim2.new(1, -(Cfg.Pad + 70), 0, 40)
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 6

local close = Style.button(sheet, "X", "dark", 22)
close.Name = "Close"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -14, 0, 10)
close.Size = UDim2.fromOffset(44, 44)
close.ZIndex = 6

-- a card row with a bold name and a dim line under it
local function row(y: number, height: number, name: string, line: string): Frame
	local r = Style.card(sheet)
	r.Position = UDim2.fromOffset(Cfg.Pad, y)
	r.Size = UDim2.new(1, -Cfg.Pad * 2, 0, height)
	r.ZIndex = 6
	local n = Style.label(r, name, 17, F.heavy, C.text)
	n.Position = UDim2.fromOffset(12, 10)
	n.Size = UDim2.new(1, -24, 0, 20)
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.ZIndex = 7
	local l = Style.label(r, line, 12, F.medium, C.dim)
	l.Position = UDim2.fromOffset(12, 32)
	l.Size = UDim2.new(1, -24, 0, 16)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.ZIndex = 7
	return r
end

-- a choice button: gold while picked, grey otherwise
local function choice(parent: Frame, word: string, size: number): TextButton
	local b = Style.button(parent, word, "dark", size)
	b.ZIndex = 8
	return b
end

local function pick(buttons: { TextButton }, on: number)
	for i, b in buttons do
		Style.setKind(b, if i == on then "gold" else "dark")
	end
end

-- an ON / OFF pair on the right of a toggle row
local function onOff(r: Frame, changed: (on: boolean) -> ()): { TextButton }
	local pair = {}
	for i, word in { "ON", "OFF" } do
		local b = choice(r, word, 20)
		b.AnchorPoint = Vector2.new(1, 0.5)
		local fromRight = 12 + (2 - i) * (Cfg.ChoiceWidth + Cfg.ChoiceGap)
		b.Position = UDim2.new(1, -fromRight, 0.5, -2)
		b.Size = UDim2.fromOffset(Cfg.ChoiceWidth, Cfg.ChoiceHeight)
		Style.onTap(b, function()
			changed(i == 1)
		end)
		pair[i] = b
	end
	return pair
end

local y = Cfg.Header
local musicRow = row(y, Cfg.RowHeight, "MUSIC", "Background tracks")
local musicPair = onOff(musicRow, function(on)
	Music.setOff(not on)
end)
y += Cfg.RowHeight + Cfg.RowGap

local uiRow = row(y, Cfg.RowHeight, "SHOW UI", "Hides every screen but this. U toggles it too")
local uiPair = onOff(uiRow, function(on)
	if HideUi.hidden() == on then
		HideUi.toggle()
	end
end)
y += Cfg.RowHeight + Cfg.RowGap

local rideRow = row(
	y,
	Cfg.RideRowHeight,
	"WHO CAN RIDE IN MY CAR",
	"Takes effect at once, for riders already in too"
)
-- three equal choices across the row, 12 in from its sides, ChoiceGap apart
local choices = Instance.new("Frame")
choices.BackgroundTransparency = 1
choices.Position = UDim2.fromOffset(12, 52)
choices.Size = UDim2.new(1, -24, 0, Cfg.ChoiceHeight)
choices.Parent = rideRow
local rideButtons: { TextButton } = {}
local n = #RidersConfig.Modes
local gap = Cfg.ChoiceGap
for i, mode in RidersConfig.Modes do
	local b = choice(choices, Cfg.RideWords[i] or string.upper(mode), 17)
	b.Position = UDim2.new((i - 1) / n, (i - 1) * gap / n, 0, 0)
	b.Size = UDim2.new(1 / n, -gap * (n - 1) / n, 1, 0)
	Style.onTap(b, function()
		player:SetAttribute("RideMode", mode) -- shown now; the server saves it and sets it back the same
		Net.waitFor("SetRideMode"):FireServer(mode)
	end)
	rideButtons[i] = b
end

local function show()
	pick(musicPair, if Music.isOff() then 2 else 1)
	pick(uiPair, if HideUi.hidden() then 2 else 1)
	local mode = RiderRules.mode(player:GetAttribute("RideMode"), RidersConfig)
	pick(rideButtons, table.find(RidersConfig.Modes, mode) or 1)
end

---------------------------------------------------------------- open and close

local screenFit = gui:FindFirstChild("ScreenFit") :: UIScale?
local function place()
	local h = gui.AbsoluteSize.Y / (if screenFit then screenFit.Scale else Style.scale())
	local centre = LayoutRules.sheetCentre(h, H, LayoutConfig.SheetTop, LayoutConfig.SheetBottom)
	sheet.Position = UDim2.new(0.5, 0, 0, centre)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	task.defer(place)
end)
if screenFit then
	screenFit:GetPropertyChangedSignal("Scale"):Connect(place)
end

local function setOpen(open: boolean)
	if open then
		show()
		place()
	end
	sheet.Visible = open
end

function Settings.open()
	setOpen(true)
end

function Settings.close()
	setOpen(false)
end

function Settings.start()
	-- the View button is ours (it opens this); Roblox's own select-mode toggle on it would fight it
	GuiService.AutoSelectGuiEnabled = false
	Style.onTap(tile, function()
		setOpen(not sheet.Visible)
	end)
	Style.onTap(close, Settings.close)
	Pad.press(tile, (Enum.KeyCode :: any)[Cfg.PadKey], function()
		setOpen(not sheet.Visible)
	end)
	Pad.menu(sheet, {
		first = function()
			return musicPair[if Music.isOff() then 2 else 1]
		end,
		close = Settings.close,
	})
	Music.changed(show)
	HideUi.changed(show)
	player:GetAttributeChangedSignal("RideMode"):Connect(show)
	show()
	gui.Parent = player:WaitForChild("PlayerGui")
	place()
end

return Settings
