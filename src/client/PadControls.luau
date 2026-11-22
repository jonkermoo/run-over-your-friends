--!strict
-- The console's controls card (Hud shows the keyboard one): the same asphalt card in the bottom right, each row
-- the platform's own button pictures (Xbox or PlayStation) and what they do (Rules/DriveHud padRows, sizes in
-- Config/DriveHud). It is open for the same first drives as the keyboard card, then folds away. While a pad
-- is in use the stuck hint over the speedometer shows the D-pad-left picture instead of the T cap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CockpitConfig = require(ReplicatedStorage.Shared.Config.Cockpit)
local DriveHudConfig = require(ReplicatedStorage.Shared.Config.DriveHud)
local DriveHudRules = require(ReplicatedStorage.Shared.Rules.DriveHud)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Drive = require(script.Parent.Drive)
local Pad = require(script.Parent.Pad)
local Style = require(script.Parent.Style)

local PadControls = {}

local C, F = Style.colors, Style.fonts
local CFG = DriveHudConfig
local PAD = CFG.CardPad

export type Options = {
	open: () -> boolean, -- the keyboard card's open state (Hud: open for the first drives)
	hint: Frame, -- the stuck hint over the speedometer
	hintCap: GuiObject, -- its T cap, swapped for the D-pad picture on a pad
}

-- a row of button pictures, left to right, sized to fit
local function icons(parent: Instance, keys: { string }): Frame
	local f = Instance.new("Frame")
	f.Name = "Buttons"
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0, 0.5)
	f.Position = UDim2.fromScale(0, 0.5)
	f.Size = UDim2.fromOffset(#keys * CFG.PadIcon + (#keys - 1) * CFG.PadIconGap, CFG.PadIcon)
	f.Parent = parent
	for i, name in keys do
		local img = Instance.new("ImageLabel")
		img.Name = name
		img.BackgroundTransparency = 1
		img.Position = UDim2.fromOffset((i - 1) * (CFG.PadIcon + CFG.PadIconGap), 0)
		img.Size = UDim2.fromOffset(CFG.PadIcon, CFG.PadIcon)
		img.Image = UserInputService:GetImageForKeyCode((Enum.KeyCode :: any)[name])
		img.Parent = f
	end
	return f
end

function PadControls.start(gui: ScreenGui, opts: Options)
	local player = Players.LocalPlayer

	local card = Style.panel(gui)
	card.Name = "PadControls"
	card.AnchorPoint = Vector2.new(1, 1)
	card.Position = UDim2.new(1, -CFG.Margin, 1, -CFG.Margin)
	card.Visible = false
	local edge = Instance.new("Frame")
	edge.BackgroundColor3 = C.pink
	edge.BorderSizePixel = 0
	edge.Size = UDim2.new(0, 4, 1, 0)
	edge.Parent = card
	local title = Style.label(card, "CONTROLS", 17, F.display, C.pink)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(PAD + 4, PAD - 2)
	title.Size = UDim2.fromOffset(100, CFG.TitleHeight)

	-- one row per binding; rebuilt only when the buttons change, labels are updated in place
	local rows: { { row: Frame, buttons: Frame, label: TextLabel } } = {}
	local shown = ""
	local function setRows(list: { DriveHudRules.PadRow })
		local sig = {}
		for _, r in list do
			table.insert(sig, table.concat(r.keys, "+"))
		end
		local signature = table.concat(sig, ",")
		if signature ~= shown then
			shown = signature
			for _, r in rows do
				r.row:Destroy()
			end
			table.clear(rows)
			for i, r in list do
				local row = Instance.new("Frame")
				row.BackgroundTransparency = 1
				row.Position = UDim2.fromOffset(
					PAD + 4,
					PAD + CFG.TitleHeight + 4 + (i - 1) * (CFG.PadRowHeight + CFG.RowGap)
				)
				row.Size = UDim2.new(1, -PAD * 2 - 4, 0, CFG.PadRowHeight)
				row.Parent = card
				local label = Style.label(row, r.label, 14, F.bold, C.text)
				label.AutoLocalize = false
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.Size = UDim2.new(0, 200, 1, 0)
				table.insert(rows, { row = row, buttons = icons(row, r.keys), label = label })
			end
		end
		for i, r in list do
			rows[i].label.Text = if r.wait
				then Loc.text("UnstuckWait", { n = r.wait })
				else Loc.source(r.label)
		end
	end

	-- line the labels up after the widest set of pictures and size the card round its rows
	local function layout()
		local s = Style.scale()
		local iconW = 0
		for _, r in rows do
			iconW = math.max(iconW, r.buttons.Size.X.Offset)
		end
		local labelW = 0
		for _, r in rows do
			r.label.Position = UDim2.fromOffset(iconW + 10, 0)
			labelW = math.max(labelW, r.label.TextBounds.X / s)
		end
		local width = math.max(PAD + 4 + iconW + 10 + labelW + PAD, PAD + 4 + 100 + PAD)
		local height = PAD
			+ CFG.TitleHeight
			+ 4
			+ #rows * (CFG.PadRowHeight + CFG.RowGap)
			- CFG.RowGap
			+ PAD
		card.Size = UDim2.fromOffset(math.ceil(width), height)
	end

	-- the stuck hint's D-pad-left picture, where the T cap sits
	local hintIcon = Instance.new("ImageLabel")
	hintIcon.Name = "PadKey"
	hintIcon.BackgroundTransparency = 1
	hintIcon.AnchorPoint = Vector2.new(0, 0.5)
	hintIcon.Position = UDim2.new(0, 10, 0.5, -1)
	hintIcon.Size = UDim2.fromOffset(CFG.PadHintIcon, CFG.PadHintIcon)
	hintIcon.Image = UserInputService:GetImageForKeyCode(Enum.KeyCode.DPadLeft)
	hintIcon.Visible = false
	hintIcon.Parent = opts.hint

	RunService.RenderStepped:Connect(function()
		local s = Drive.state
		local pad = s.driving and Pad.console()
		hintIcon.Visible = pad
		opts.hintCap.Visible = not pad
		card.Visible = pad and opts.open()
		if not card.Visible then
			return
		end
		local stats = Vehicles.ById[s.vehicleId]
		local feature: string? = nil
		if stats then
			for f, text in DriveHudRules.Features do
				if Vehicles.has(stats, f :: any) then
					feature = text
				end
			end
		end
		local car = Drive.view.car
		local step = player:GetAttribute("Tutorial")
		setRows(DriveHudRules.padRows({
			feature = feature,
			jingleOn = car ~= nil and car.PrimaryPart ~= nil and car.PrimaryPart:GetAttribute(
				"JingleOn"
			) == true,
			jet = stats ~= nil and Vehicles.has(stats, "Jet"),
			thruster = stats ~= nil and Vehicles.has(stats, "Thruster"),
			unstuckWait = math.ceil(s.unstuckIn),
			view = CockpitConfig.pads[1],
			tutorial = step ~= nil and step ~= Onboarding.Steps.Done,
		}))
		layout()
	end)
end

return PadControls
