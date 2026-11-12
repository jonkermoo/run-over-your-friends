--!strict
-- The garage card's paint picker: a PAINT button on owned cards flips the card's info to a row of colour swatches.
-- Tapping one recolours the card's 3D preview; an open colour is saved for that vehicle (the server colours the
-- real one), a locked one turns the card's action button into BUY. Colours: Config/Paints.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Paints)
local Net = require(ReplicatedStorage.Shared.Net)
local PaintRules = require(ReplicatedStorage.Shared.Rules.Paints)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local C, F = Style.colors, Style.fonts

local PaintPicker = {}

export type Picker = {
	refresh: () -> (), -- after money, owned cars or paint change
	action: () -> boolean, -- the card's action button was pressed: true when the picker handled it (a BUY)
}

local SWATCH, GAP, PER_ROW = 22, 5, 8
local SEND_AFTER = 0.5 -- seconds of no tapping before the chosen colour is sent

local function bought(): { [string]: boolean }
	local out = {}
	for id in string.gmatch((player:GetAttribute("Paints") or "") :: string, "[^,]+") do
		out[id] = true
	end
	return out
end

local function saved(vehicleId: string): string
	return PaintRules.decode((player:GetAttribute("Paint") or "") :: string)[vehicleId]
		or Config.FactoryId
end

local function owns(vehicleId: string): boolean
	return string.find(
		"," .. ((player:GetAttribute("Owned") or "") :: string) .. ",",
		"," .. vehicleId .. ",",
		1,
		true
	) ~= nil
end

-- card: the garage card; model: its preview's vehicle copy; info: what the swatches cover while open;
-- changed: refreshes the card (the garage's refresh, which calls this picker's refresh last)
function PaintPicker.attach(
	card: Frame,
	vehicleId: string,
	model: Model?,
	info: GuiObject,
	action: TextButton,
	changed: () -> ()
): Picker
	local isOpen = false
	local selected = saved(vehicleId)
	local sendToken = 0

	local toggle = Style.button(card, "PAINT", "purple", 14)
	toggle.Name = "PaintToggle"
	toggle.AnchorPoint = Vector2.new(1, 0)
	toggle.Position = UDim2.new(1, -14, 0, 12)
	toggle.Size = UDim2.fromOffset(70, 26)
	toggle.ZIndex = 3
	toggle.Visible = false

	local sheet = Instance.new("Frame")
	sheet.Name = "Paints"
	sheet.BackgroundTransparency = 1
	sheet.Position = UDim2.fromOffset(14, 160)
	sheet.Size = UDim2.new(1, -28, 0, 104)
	sheet.Visible = false
	sheet.Parent = card
	local caption = Style.label(sheet, "", 13, F.heavy, C.text)
	caption.Position = UDim2.fromOffset(0, 3 * (SWATCH + GAP) + 2)
	caption.Size = UDim2.new(1, 0, 0, 16)
	caption.TextXAlignment = Enum.TextXAlignment.Left

	local function show(paintId: string)
		local part = model and model:FindFirstChild("Paint")
		local rgb = PaintRules.colour(vehicleId, paintId)
		if part and part:IsA("BasePart") and rgb then
			part.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		end
	end

	local swatches: { [string]: { button: TextButton, edge: UIStroke } } = {}

	-- the swatches are built the first time PAINT is opened (13 cards x 18 swatches up front cost phones)
	local built = false
	local function buildSwatches()
		if built then
			return
		end
		built = true
		for i, p in Config.List do
			local b = Instance.new("TextButton")
			b.Name = "Paint" .. p.id
			b.AutoButtonColor = false
			b.BorderSizePixel = 0
			local rgb = PaintRules.colour(vehicleId, p.id) or { 128, 128, 128 }
			b.BackgroundColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
			b.Position = UDim2.fromOffset(
				((i - 1) % PER_ROW) * (SWATCH + GAP),
				(i - 1) // PER_ROW * (SWATCH + GAP)
			)
			b.Size = UDim2.fromOffset(SWATCH, SWATCH)
			b.FontFace = F.display
			b.TextSize = 13
			b.TextColor3 = C.text
			b.Text = ""
			b.Parent = sheet
			local edge = Style.stroke(b, C.ink, 2, 0)
			Style.outline(b, 1.5)
			swatches[p.id] = { button = b, edge = edge }
			b.Activated:Connect(function()
				selected = p.id
				show(p.id)
				sendToken += 1
				local token = sendToken
				if PaintRules.isOpen(bought(), p.id) and p.id ~= saved(vehicleId) then
					task.delay(SEND_AFTER, function()
						if token == sendToken then
							Net.waitFor("SetPaint"):FireServer(vehicleId, p.id)
						end
					end)
				end
				changed()
			end)
		end
	end

	local function setOpen(on: boolean)
		isOpen = on
		if on then
			buildSwatches()
		end
		sheet.Visible = on
		info.Visible = not on
		toggle.Text = if on then "BACK" else "PAINT"
		if not on then
			selected = saved(vehicleId)
		end
		changed()
	end
	toggle.Activated:Connect(function()
		setOpen(not isOpen)
	end)

	local function refresh()
		local mine = owns(vehicleId)
		toggle.Visible = mine
		if isOpen and not mine then
			isOpen = false
			sheet.Visible = false
			info.Visible = true
			toggle.Text = "PAINT"
		end
		local have = bought()
		local current = saved(vehicleId)
		if not isOpen then
			selected = current
		end
		show(selected)
		for id, s in swatches do
			local open = PaintRules.isOpen(have, id)
			s.button.Text = if id == Config.FactoryId then "F" elseif open then "" else "$"
			s.edge.Color = if id == selected then C.yellow else C.ink
			s.edge.Thickness = if id == selected then 3 else 2
		end
		local p = Config.ById[selected]
		if not p then
			return
		end
		if PaintRules.isOpen(have, selected) then
			caption.Text = string.upper(p.name) .. if selected == current then "  ON" else ""
			caption.TextColor3 = C.text
		else
			caption.Text = string.upper(p.name) .. "  " .. Style.money(p.price) .. "  ALL CARS"
			caption.TextColor3 = C.money
			local cash = (player:GetAttribute("Money") or 0) :: number
			action.Text = "BUY " .. Style.money(p.price)
			Style.setKind(action, if cash >= p.price then "orange" else "dark")
		end
	end

	-- a colour just bought: put it on this car
	player:GetAttributeChangedSignal("Paints"):Connect(function()
		if isOpen and selected ~= saved(vehicleId) and PaintRules.isOpen(bought(), selected) then
			Net.waitFor("SetPaint"):FireServer(vehicleId, selected)
		end
	end)

	local function onAction(): boolean
		if not isOpen or PaintRules.isOpen(bought(), selected) then
			return false
		end
		Net.waitFor("BuyPaint"):FireServer(selected)
		return true
	end

	return { refresh = refresh, action = onAction }
end

return PaintPicker
