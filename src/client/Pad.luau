--!strict
-- Gamepad support for the menus: a white outline marks the selected button, a sheet or card that opens
-- selects its main button (only when the player is on a gamepad, so mouse and touch players never see the
-- outline), B closes it, and the shoulder buttons can run extra actions (the store's sections). Every
-- binding lives only while its menu is open, at a priority over the driving keys (B is boost there).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Style = require(script.Parent.Style)

local Pad = {}

local PRIORITY = Enum.ContextActionPriority.High.Value + 50
local menus = 0 -- each menu's actions get their own name

-- the outline drawn round the selected button (one shared look for every menu)
local outline = Instance.new("Frame")
outline.Name = "PadSelection"
outline.BackgroundTransparency = 1
outline.Size = UDim2.fromScale(1, 1)
do
	local stroke = Instance.new("UIStroke")
	stroke.Color = Style.colors.text
	stroke.Thickness = 4
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = outline
end

function Pad.usingGamepad(): boolean
	local t = UserInputService:GetLastInputType()
	return t.Name:sub(1, 7) == "Gamepad"
end

-- make a button reachable with the gamepad and give it the shared outline
function Pad.selectable(b: GuiObject)
	b.Selectable = true
	b.SelectionImageObject = outline
end

-- every button inside a menu, now and later
function Pad.selectAll(root: Instance)
	local function mark(d: Instance)
		if d:IsA("GuiButton") and d.Name ~= "TapArea" then
			Pad.selectable(d)
		end
	end
	for _, d in root:GetDescendants() do
		mark(d)
	end
	root.DescendantAdded:Connect(mark)
end

local function inside(obj: Instance?, root: Instance): boolean
	return obj ~= nil and (obj == root or obj:IsDescendantOf(root))
end

export type Options = {
	first: () -> GuiObject?, -- the button to select when it opens
	close: () -> (), -- B
	shoulders: ((dir: number) -> ())?, -- LB (-1) and RB (+1)
}

-- wire a menu frame: while it's Visible, B closes it and a gamepad player starts on `first`
function Pad.menu(frame: GuiObject, opts: Options)
	menus += 1
	local key = "RoyfMenu" .. frame.Name .. menus
	frame.SelectionGroup = true
	frame.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
	frame.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
	frame.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
	frame.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
	Pad.selectAll(frame)

	local function selectFirst()
		if not Pad.usingGamepad() or not frame.Visible then
			return
		end
		if inside(GuiService.SelectedObject, frame) then
			return
		end
		local b = opts.first()
		if b and b.Visible then
			GuiService.SelectedObject = b
		end
	end

	local lastInput: RBXScriptConnection? = nil
	local function opened()
		ContextActionService:BindActionAtPriority(key, function(_, state)
			if state == Enum.UserInputState.Begin then
				opts.close()
			end
			return Enum.ContextActionResult.Sink
		end, false, PRIORITY, Enum.KeyCode.ButtonB)
		local shoulders = opts.shoulders
		if shoulders then
			ContextActionService:BindActionAtPriority(key .. "Shoulder", function(_, state, input)
				if state == Enum.UserInputState.Begin then
					shoulders(if input.KeyCode == Enum.KeyCode.ButtonL1 then -1 else 1)
				end
				return Enum.ContextActionResult.Sink
			end, false, PRIORITY, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
		end
		-- picking up the gamepad while the menu is open selects its main button too
		lastInput = UserInputService.LastInputTypeChanged:Connect(function()
			selectFirst()
		end)
		task.defer(selectFirst) -- after the opener has filled the menu in
	end
	local function closed()
		ContextActionService:UnbindAction(key)
		ContextActionService:UnbindAction(key .. "Shoulder")
		if lastInput then
			lastInput:Disconnect()
			lastInput = nil
		end
		if inside(GuiService.SelectedObject, frame) then
			GuiService.SelectedObject = nil
		end
	end
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			opened()
		else
			closed()
		end
	end)
	if frame.Visible then
		opened()
	end
end

-- a key hint: the platform's own button picture (Xbox or PlayStation) and a word, e.g. "close"; it shows
-- only while a gamepad is connected. Sized to its content, anchored by the caller.
function Pad.chip(parent: Instance, keys: { Enum.KeyCode }, word: string, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = "PadHint"
	f.BackgroundTransparency = 1
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, 26)
	f.Parent = parent
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 5)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = f
	for i, k in keys do
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromOffset(26, 26)
		img.LayoutOrder = i
		img.Image = UserInputService:GetImageForKeyCode(k)
		img.Parent = f
	end
	local l = Style.label(f, word, 15, Style.fonts.heavy, color or Style.colors.dim)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, 26)
	l.LayoutOrder = #keys + 1
	Pad.hint(f)
	return f
end

-- a console player: the last input was a gamepad, or a gamepad is the only way in (no keyboard, no touch:
-- before the first press GetLastInputType can still say None). Guide picks its hint wording by this.
function Pad.console(): boolean
	return Pad.usingGamepad()
		or (
			UserInputService.GamepadEnabled
			and not UserInputService.KeyboardEnabled
			and not UserInputService.TouchEnabled
		)
end

-- a key that only acts when no button has the gamepad selection (with one selected, the D-pad moves it)
local function shortcut(name: string, key: Enum.KeyCode, run: () -> boolean)
	ContextActionService:BindAction(name, function(_, state)
		if state ~= Enum.UserInputState.Begin or GuiService.SelectedObject ~= nil then
			return Enum.ContextActionResult.Pass
		end
		return if run() then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
	end, false, key)
end

-- the HUD's tab strip (GARAGE, STORE, GOALS, INVITE): `key` puts the gamepad selection on `first`, the D-pad
-- or stick moves along the tabs, A opens one and B leaves the strip. A chip with the key's picture sits
-- at the strip's start while a gamepad is connected.
function Pad.strip(row: GuiObject, key: Enum.KeyCode, first: () -> GuiObject?)
	row.SelectionGroup = true
	row.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
	row.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
	row.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
	row.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
	Pad.selectAll(row)
	local chip = Pad.chip(row, { key }, "")
	chip.Name = "PadMenuHint"
	chip.LayoutOrder = 0
	chip.Size = UDim2.fromOffset(0, 46)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.Parent = chip
	shortcut("RoyfPadMenu", key, function()
		local b = first()
		if not (b and b.Visible) then
			return false
		end
		GuiService.SelectedObject = b
		return true
	end)
	-- B leaves the strip while one of its tabs is selected (B is boost in the car, so it's sunk then)
	local bound = false
	GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		local on = inside(GuiService.SelectedObject, row)
		if on == bound then
			return
		end
		bound = on
		if on then
			ContextActionService:BindActionAtPriority("RoyfPadMenuLeave", function(_, state)
				if
					state == Enum.UserInputState.Begin and inside(GuiService.SelectedObject, row)
				then
					GuiService.SelectedObject = nil
				end
				return Enum.ContextActionResult.Sink
			end, false, PRIORITY, Enum.KeyCode.ButtonB)
		else
			ContextActionService:UnbindAction("RoyfPadMenuLeave")
		end
	end)
end

-- a button pressed with one gamepad key while it shows (the tutorial's SKIP), with the key's picture just
-- left of it while a gamepad is connected
function Pad.press(b: GuiButton, key: Enum.KeyCode, run: () -> ())
	local icon = Instance.new("ImageLabel")
	icon.Name = "PadKey"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(1, 0.5)
	icon.Position = UDim2.new(0, -4, 0.5, 0)
	icon.Size = UDim2.fromOffset(22, 22)
	icon.Image = UserInputService:GetImageForKeyCode(key)
	icon.ZIndex = b.ZIndex
	icon.Parent = b
	Pad.hint(icon)
	shortcut("RoyfPadPress" .. b.Name, key, function()
		if not (b.Visible and b:FindFirstAncestorWhichIsA("LayerCollector")) then
			return false
		end
		local shown: Instance? = b
		while shown and shown:IsA("GuiObject") do
			if not shown.Visible then
				return false
			end
			shown = shown.Parent
		end
		run()
		return true
	end)
end

-- show a key hint (a "B close" chip) only while a gamepad is connected
function Pad.hint(obj: GuiObject)
	local function sync()
		obj.Visible = Pad.usingGamepad() or UserInputService.GamepadEnabled
	end
	UserInputService.LastInputTypeChanged:Connect(sync)
	UserInputService.GamepadConnected:Connect(sync)
	UserInputService.GamepadDisconnected:Connect(sync)
	sync()
end

return Pad
