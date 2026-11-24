--!strict
-- The garage card's paint picker: a PAINT button on owned cards flips the card's info to a row of colour swatches.
-- Tapping one recolours the card's 3D preview; an open colour is saved for that vehicle (the server colours the
-- real one), a locked one turns the card's action button into BUY (GET VIP for the VIP colour). Colours: Config/Paints.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Paints)
local VehicleParts = require(ReplicatedStorage.Shared.VehicleParts)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local PaintRules = require(ReplicatedStorage.Shared.Rules.Paints)
local Look = require(ReplicatedStorage.Shared.Config.Look)
local Sheen = require(ReplicatedStorage.Shared.Rules.Sheen)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local C, F = Style.colors, Style.fonts

local PaintPicker = {}

export type Picker = {
	refresh: () -> (), -- after money, owned cars or paint change
	action: () -> boolean, -- the card's action button was pressed: true when the picker handled it (a BUY)
	reset: () -> (), -- back to the saved colour (a colour tried on comes off)
}

local SWATCH, GAP, PER_ROW = 22, 5, 8
-- the garage page's swatches: INLINE_ROW across the PAINT tab's width, up to INLINE_SWATCH px square
local INLINE_ROW, INLINE_SWATCH, INLINE_GAP = 9, 56, 7
local SEND_AFTER = 0.5 -- seconds of no tapping before the chosen colour is sent

local function isVip(): boolean
	return player:GetAttribute("PassVIP") == true
end

-- paid colours, plus the VIP ones while this player has the VIP pass
local function bought(): { [string]: boolean }
	local out = {}
	for id in string.gmatch((player:GetAttribute("Paints") or "") :: string, "[^,]+") do
		out[id] = true
	end
	return PaintRules.withVip(out, isVip())
end

local function saved(vehicleId: string): string
	return PaintRules.shown(
		PaintRules.decode((player:GetAttribute("Paint") or "") :: string)[vehicleId],
		isVip()
	) or Config.FactoryId
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
-- changed: refreshes the card (the garage's refresh, which calls this picker's refresh last). With inline
-- (a frame to fill), the swatches always show there while the vehicle is owned, with no PAINT button; they're
-- built the first time the card shows.
function PaintPicker.attach(
	card: Frame,
	vehicleId: string,
	model: Model?,
	info: GuiObject,
	action: TextButton,
	changed: () -> (),
	inline: Frame?
): Picker
	local isOpen = false
	local swatch = if inline then INLINE_SWATCH else SWATCH
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
	sheet.Position = if inline then UDim2.new() else UDim2.fromOffset(14, 160)
	sheet.Size = if inline then UDim2.fromScale(1, 1) else UDim2.new(1, -28, 0, 104)
	sheet.Visible = false
	sheet.Parent = inline or card
	local rowsOf = math.ceil(#Config.List / (if inline then INLINE_ROW else PER_ROW))
	local caption = Style.label(sheet, "", if inline then 20 else 13, F.heavy, C.text)
	caption.Position = UDim2.fromOffset(
		0,
		rowsOf * (swatch + (if inline then INLINE_GAP else GAP)) + (if inline then 6 else 2)
	)
	caption.Size = UDim2.new(1, 0, 0, if inline then 26 else 16)
	caption.TextScaled = inline ~= nil
	local captionCap = Instance.new("UITextSizeConstraint")
	captionCap.MaxTextSize = if inline then 20 else 13
	captionCap.Parent = caption
	caption.TextXAlignment = Enum.TextXAlignment.Left

	local function show(paintId: string)
		local rgb = PaintRules.colour(vehicleId, paintId)
		for _, part in (if model and rgb then VehicleParts.paintParts(model) else {}) do
			local c = rgb :: { number }
			part.Color = Color3.fromRGB(c[1], c[2], c[3])
			if part:GetAttribute("BaseMaterial") == nil then
				part:SetAttribute("BaseMaterial", part.Material.Name)
			end
			local name = PaintRules.material(paintId) or part:GetAttribute("BaseMaterial") :: string
			local ok, m = pcall(function()
				return (Enum.Material :: any)[name]
			end)
			if ok and m then
				part.Material = m
				part.Reflectance = Sheen.paintReflectance(m.Name, Look.Cars)
			end
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
			if inline then
				-- a ninth of the width each (less the gap), never taller than INLINE_SWATCH: kept square
				b.Position = UDim2.new(
					((i - 1) % INLINE_ROW) / INLINE_ROW,
					0,
					0,
					(i - 1) // INLINE_ROW * (swatch + INLINE_GAP)
				)
				b.Size = UDim2.new(1 / INLINE_ROW, -INLINE_GAP, 0, swatch)
				local square = Instance.new("UIAspectRatioConstraint")
				square.Parent = b
			else
				b.Position = UDim2.fromOffset(
					((i - 1) % PER_ROW) * (swatch + GAP),
					(i - 1) // PER_ROW * (swatch + GAP)
				)
				b.Size = UDim2.fromOffset(swatch, swatch)
			end
			b.FontFace = F.display
			b.TextSize = if inline then 22 else 13
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
		if inline then
			toggle.Visible = false
			if mine and card.Visible then
				buildSwatches()
			end
			if mine and not isOpen then
				selected = saved(vehicleId)
			end
			isOpen = mine
			sheet.Visible = mine
		else
			toggle.Visible = mine
		end
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
			s.button.Text = if id == Config.FactoryId
				then "F"
				elseif open then ""
				elseif Config.ById[id].vip then "V"
				elseif Config.ById[id].chest then "?"
				else "$"
			s.edge.Color = if id == selected then C.yellow else C.ink
			s.edge.Thickness = if id == selected then 3 else 2
		end
		local p = Config.ById[selected]
		if not p then
			return
		end
		if PaintRules.isOpen(have, selected) then
			caption.AutoLocalize = false
			caption.Text = if selected == current
				then Loc.text("PaintOn", { paint = Loc.upper(Loc.source(p.name)) })
				else Loc.upper(Loc.source(p.name))
			caption.TextColor3 = C.text
		elseif p.vip then
			Loc.set(caption, "PaintVip", { paint = Loc.upper(Loc.source(p.name)) })
			caption.TextColor3 = C.gold
			action.Text = "GET VIP"
			Style.setKind(action, "gold")
		elseif p.chest then
			-- never sold: won from a challenge chest
			Loc.set(caption, "PaintChest", { paint = Loc.upper(Loc.source(p.name)) })
			caption.TextColor3 = C.purple
			action.AutoLocalize = true
			action.Text = "IN CHESTS"
			Style.setKind(action, "dark")
		else
			Loc.set(
				caption,
				"PaintBuy",
				{ paint = Loc.upper(Loc.source(p.name)), price = Style.money(p.price) }
			)
			caption.TextColor3 = C.money
			local cash = (player:GetAttribute("Money") or 0) :: number
			Loc.set(action, "BuyPrice", { price = Style.money(p.price) })
			Style.setKind(action, if cash >= p.price then "orange" else "dark")
		end
	end

	-- a colour just bought (or VIP just got): put it on this car
	local function justOpened()
		if isOpen and selected ~= saved(vehicleId) and PaintRules.isOpen(bought(), selected) then
			Net.waitFor("SetPaint"):FireServer(vehicleId, selected)
		end
	end
	player:GetAttributeChangedSignal("Paints"):Connect(justOpened)
	player:GetAttributeChangedSignal("PassVIP"):Connect(function()
		justOpened()
		changed()
	end)

	local function onAction(): boolean
		if not isOpen or PaintRules.isOpen(bought(), selected) then
			return false
		end
		local p = Config.ById[selected]
		if p and p.vip then
			Net.waitFor("BuyPass"):FireServer("VIP")
		elseif p and p.chest then
			return true -- nothing to buy: it comes from a challenge chest
		else
			Net.waitFor("BuyPaint"):FireServer(selected)
		end
		return true
	end

	local function reset()
		if selected ~= saved(vehicleId) then
			selected = saved(vehicleId)
			changed()
		end
	end

	return { refresh = refresh, action = onAction, reset = reset }
end

return PaintPicker
