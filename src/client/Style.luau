--!strict
-- One look for every screen, "Street Sign": every panel is a real road sign (highway green with a white
-- inner line, a dark edge, a press lip and corner rivets; each menu in its own sign colour), buttons are
-- flat sign plates (yellow for go, white for no) with a black inner line, and type is heavy Builder Sans.
-- No glows or soft gradients. Everything visual goes through here so the UI stays consistent.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Callouts = require(ReplicatedStorage.Shared.Config.Callouts)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local LayoutConfig = require(ReplicatedStorage.Shared.Config.Layout)
local LayoutRules = require(ReplicatedStorage.Shared.Rules.Layout)

local Style = {}

-- Every ScreenGui is laid out at desktop size and drawn at one shared scale (Style.fit): 1 on desktop,
-- smaller on phones. Offsets in the UI are therefore layout pixels; AbsoluteSize, AbsolutePosition and
-- camera points are real pixels, so divide those by Style.scale() before using them as offsets.
local currentScale = 1
local fitted: { UIScale } = {}

local function refreshScale()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local inset = GuiService:GetGuiInset()
	currentScale = LayoutRules.scale(cam.ViewportSize.X, cam.ViewportSize.Y - inset.Y, LayoutConfig)
	for _, s in fitted do
		s.Scale = currentScale
	end
end

local cameraWatch: RBXScriptConnection? = nil
local function watchCamera()
	if cameraWatch then
		cameraWatch:Disconnect()
	end
	local cam = workspace.CurrentCamera
	if cam then
		cameraWatch = cam:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
	end
	refreshScale()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

function Style.scale(): number
	return currentScale
end

-- the HUD pieces at the screen's edges that pointers must stay off (Rules/Clear), as real-pixel boxes in
-- the inset-adjusted space of a ScreenGui that doesn't ignore the inset; pieces that aren't showing are left out
local KEEP_CLEAR = { "Controls", "KeysChip", "Speedometer" }
function Style.keepClear(): { { x: number, y: number, w: number, h: number } }
	local out = {}
	local player = game:GetService("Players").LocalPlayer
	local hud = player
		and player:FindFirstChild("PlayerGui")
		and player.PlayerGui:FindFirstChild("Hud")
	if not hud then
		return out
	end
	for _, name in KEEP_CLEAR do
		local g = hud:FindFirstChild(name)
		if g and g:IsA("GuiObject") and g.Visible and g.AbsoluteSize.X > 0 then
			local p, s = g.AbsolutePosition, g.AbsoluteSize
			table.insert(out, { x = p.X, y = p.Y, w = s.X, h = s.Y })
		end
	end
	return out
end

-- a sheet (Garage, Store, Goals, Settings or the city map) is open over the screen
function Style.sheetOpen(): boolean
	local player = game:GetService("Players").LocalPlayer
	local pg = player and player:FindFirstChild("PlayerGui")
	if not pg then
		return false
	end
	local hud = pg:FindFirstChild("Hud")
	local goals = pg:FindFirstChild("Goals")
	local settings = pg:FindFirstChild("Settings")
	for _, g in
		{
			hud and hud:FindFirstChild("Garage"),
			hud and hud:FindFirstChild("Store"),
			goals and goals:FindFirstChild("GoalsSheet"),
			settings and settings:FindFirstChild("SettingsSheet"),
			pg:FindFirstChild("CityMap")
				and (pg:FindFirstChild("CityMap") :: Instance):FindFirstChild("Sheet"),
		}
	do
		if g and g:IsA("GuiObject") and g.Visible then
			return true
		end
	end
	return false
end

-- The middle of the screen is shared by the big callouts (tutorial cheers, SERVER GOAL, DEMOLISHED!, contest
-- winners). Each one asks for the stage for `hold` seconds and is told how long to wait, so they come one
-- after another instead of landing on top of each other; combo shouts skip while one is up.
local stageFree = 0
function Style.stage(hold: number): number
	local now = os.clock()
	local start = math.max(now, stageFree)
	stageFree = start + hold + Callouts.StageGap
	return start - now
end

function Style.stageBusy(): boolean
	return os.clock() < stageFree
end

-- the scale for world labels (BillboardGuis): they shrink with the UI but stay readable
function Style.billboardScale(): number
	return math.max(currentScale, LayoutConfig.BillboardMinScale)
end

-- draw this ScreenGui at the shared scale
function Style.fit(gui: ScreenGui)
	local s = Instance.new("UIScale")
	s.Name = "ScreenFit"
	s.Scale = currentScale
	s.Parent = gui
	table.insert(fitted, s)
end

Style.colors = table.freeze({
	ink = Color3.fromRGB(21, 21, 21),
	panel = Color3.fromRGB(0, 107, 63), -- highway sign green
	panelTop = Color3.fromRGB(0, 107, 63),
	card = Color3.fromRGB(36, 38, 42), -- dark charcoal for tracks, caps and plates inside a sign
	edge = Color3.fromRGB(247, 247, 242), -- a sign's white inner line
	text = Color3.fromRGB(255, 255, 255),
	dim = Color3.fromRGB(213, 233, 222),
	yellow = Color3.fromRGB(255, 201, 21), -- warning-sign yellow
	red = Color3.fromRGB(215, 38, 43), -- stop-sign red
	pink = Color3.fromRGB(255, 46, 154),
	orange = Color3.fromRGB(255, 122, 0), -- construction orange
	gold = Color3.fromRGB(255, 201, 21),
	money = Color3.fromRGB(255, 214, 51),
	blue = Color3.fromRGB(31, 79, 168), -- services blue
	purple = Color3.fromRGB(150, 70, 255),
	green = Color3.fromRGB(43, 200, 90),
	grey = Color3.fromRGB(70, 70, 78),
	brown = Color3.fromRGB(110, 59, 30), -- recreation brown
	white = Color3.fromRGB(246, 246, 241), -- regulatory white
	steel = Color3.fromRGB(150, 158, 166), -- gantries and posts
	billEdge = Color3.fromRGB(26, 160, 67), -- the store's drawn banknotes
	billInk = Color3.fromRGB(11, 93, 34),
	prize = Color3.fromRGB(58, 42, 85), -- the daily streak's week prize tile
})
local C = Style.colors

-- Builder Sans (Roblox's own) in its heaviest weights stands in for highway-sign type; Highway Gothic
-- (also built in) is for numbers on real-sign pieces (the speed limit, mile markers)
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
Style.fonts = table.freeze({
	display = Font.new(BUILDER, Enum.FontWeight.ExtraBold),
	heavy = Font.new(BUILDER, Enum.FontWeight.ExtraBold),
	bold = Font.new(BUILDER, Enum.FontWeight.Bold),
	medium = Font.new(BUILDER, Enum.FontWeight.Bold),
	sign = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
})
local F = Style.fonts

Style.SHADOW = 4 -- the press lip under a sign or button, px

-- sign kinds: face, dark edge and lip, inner line, text, small text, money
type Sign = {
	face: Color3,
	edge: Color3,
	line: Color3,
	text: Color3,
	dim: Color3,
	money: Color3,
}
Style.signs = table.freeze({
	green = {
		face = C.panel,
		edge = Color3.fromRGB(0, 51, 29),
		line = C.edge,
		text = C.text,
		dim = C.dim,
		money = C.money,
	},
	blue = {
		face = C.blue,
		edge = Color3.fromRGB(15, 44, 99),
		line = C.edge,
		text = C.text,
		dim = Color3.fromRGB(211, 224, 251),
		money = C.money,
	},
	brown = {
		face = C.brown,
		edge = Color3.fromRGB(51, 23, 7),
		line = C.edge,
		text = C.text,
		dim = Color3.fromRGB(240, 220, 203),
		money = C.money,
	},
	orange = {
		face = C.orange,
		edge = Color3.fromRGB(90, 40, 0),
		line = C.ink,
		text = C.ink,
		dim = Color3.fromRGB(74, 36, 0),
		money = C.ink,
	},
	white = {
		face = C.white,
		edge = Color3.fromRGB(58, 58, 58),
		line = C.ink,
		text = C.ink,
		dim = Color3.fromRGB(85, 88, 90),
		money = C.red,
	},
} :: { [string]: Sign })
local SIGNS = Style.signs

-- the sign kind a piece sits on (the nearest ancestor painted by Style.sign), green by default
local function signOf(obj: Instance?): Sign
	local o = obj
	while o and not o:IsA("LayerCollector") do
		local k = o:GetAttribute("Sign")
		if type(k) == "string" and SIGNS[k] then
			return SIGNS[k]
		end
		o = o.Parent
	end
	return SIGNS.green
end

-- white text on a green sign becomes black on an orange or white one, and so on
local function tone(parent: Instance?, color: Color3): Color3
	local sign = signOf(parent)
	if sign == SIGNS.green then
		return color
	end
	if color == C.text then
		return sign.text
	elseif color == C.dim then
		return sign.dim
	elseif color == C.money then
		return sign.money
	elseif color == C.yellow and sign.text == C.ink then
		return C.ink
	end
	return color
end
Style.tone = tone

-- button looks: face, text and inner line, lip
local LIP_YELLOW = Color3.fromRGB(143, 106, 0)
local KINDS: { [string]: { Color3 } } = {
	red = { C.red, C.text, Color3.fromRGB(110, 15, 18) },
	orange = { C.orange, C.ink, Color3.fromRGB(90, 40, 0) },
	gold = { C.yellow, C.ink, LIP_YELLOW }, -- go
	green = { C.yellow, C.ink, LIP_YELLOW }, -- go (buttons are never green in this style)
	blue = { C.blue, C.text, Color3.fromRGB(15, 44, 99) },
	purple = { C.pink, C.text, Color3.fromRGB(120, 10, 70) },
	dark = { C.white, C.ink, Color3.fromRGB(109, 116, 111) }, -- no / back / close
}

-- signs have softly rounded corners; radius is in layout px
function Style.corner(obj: Instance, radius: number)
	local c = obj:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, math.min(radius, 12))
	c.Parent = obj
end

function Style.stroke(
	obj: Instance,
	color: Color3?,
	thickness: number?,
	transparency: number?
): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or C.edge
	s.Thickness = thickness or 2
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = obj
	return s
end

-- flat colour (signs have no gradients); the bottom colour is ignored
function Style.gradient(obj: Instance, top: Color3, _bottom: Color3): UIGradient
	if obj:IsA("GuiObject") then
		obj.BackgroundColor3 = top
	end
	local g = Instance.new("UIGradient")
	g.Parent = obj
	return g
end

-- keep a sign's own pieces (line, rivets, lip, bolts) on the sign's ZIndex, so they draw in ScreenGuis
-- that sort globally too
local function follow(obj: GuiObject, part: GuiObject)
	local function sync()
		part.ZIndex = obj.ZIndex
		for _, d in part:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = obj.ZIndex
			end
		end
	end
	obj:GetPropertyChangedSignal("ZIndex"):Connect(sync)
	sync()
end

-- the lip under a sign or button: one dark strip just below the bottom edge, its ends tucked in under the
-- rounded corners (children always draw over their parent, so it can't sit behind it; below the edge it
-- doesn't have to). Works when the object sits in a layout, but a UIListLayout/UIGridLayout INSIDE the
-- object would lay the lip out too: put such a layout in an inner frame. Never give a lipped object
-- AutomaticSize: the strip below its edge makes it grow without end. Size it from its content instead
-- (Style.fitText, or follow an inner frame's AbsoluteSize).
function Style.shadow(obj: GuiObject, color: Color3?, offset: number?): Frame
	local o = offset or Style.SHADOW
	local holder = Instance.new("Frame")
	holder.Name = "Shadow"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = obj
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.BackgroundColor3 = color or signOf(obj).edge
	lip.BorderSizePixel = 0
	lip.Position = UDim2.new(0, 3, 1, -1)
	lip.Size = UDim2.new(1, -6, 0, o + 1)
	lip.Parent = holder
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, o + 1)
	round.Parent = lip
	follow(obj, holder)
	return holder
end

-- a thin line in the sign's line colour along the top or bottom edge (or a vertical one with vertical =
-- true); the colour argument is kept for older callers and ignored
function Style.dashes(
	parent: Instance,
	_color: Color3?,
	vertical: boolean?,
	thickness: number?
): Frame
	local t = math.min(thickness or 3, 3)
	local line = Instance.new("Frame")
	line.Name = "Dashes"
	line.BackgroundColor3 = signOf(parent).line
	line.BorderSizePixel = 0
	line.Size = if vertical then UDim2.new(0, t, 1, 0) else UDim2.new(1, 0, 0, t)
	line.Parent = parent
	Style.corner(line, 2)
	return line
end

-- text: white, heavy, on the sign's colours (see tone)
function Style.label(
	parent: Instance,
	text: string,
	size: number,
	font: Font?,
	color: Color3?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.FontFace = font or F.medium
	l.TextColor3 = tone(parent, color or C.text)
	l.Parent = parent
	return l
end

-- size a label to its text plus padding, and keep it that way when the text changes
function Style.fitText(l: TextLabel | TextButton, padX: number, padY: number)
	local function fit()
		local s = currentScale
		l.Size = UDim2.fromOffset(l.TextBounds.X / s + padX * 2, l.TextBounds.Y / s + padY * 2)
	end
	l:GetPropertyChangedSignal("TextBounds"):Connect(fit)
	fit()
end

-- a solid ink outline so text reads over the world
function Style.outline(l: TextLabel | TextButton, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = C.ink
	s.Thickness = thickness or 2
	s.Transparency = 0
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = l
end

-- a small round steel rivet or bolt head
local function rivet(parent: Instance, size: number): Frame
	local r = Instance.new("Frame")
	r.Name = "Rivet"
	r.BackgroundColor3 = Color3.fromRGB(230, 234, 231)
	r.BorderSizePixel = 0
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.Size = UDim2.fromOffset(size, size)
	r.Parent = parent
	Style.corner(r, size)
	local e = Instance.new("UIStroke")
	e.Color = Color3.fromRGB(89, 97, 92)
	e.Thickness = 1.5
	e.Parent = r
	return r
end

-- the white inner line a sign or a button plate carries, `inset` px in from its edge
local function innerLine(
	obj: GuiObject,
	inset: number,
	thickness: number,
	radius: number,
	color: Color3
): Frame
	local f = Instance.new("Frame")
	f.Name = "Line"
	f.BackgroundTransparency = 1
	f.Position = UDim2.fromOffset(inset, inset)
	f.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
	f.Parent = obj
	Style.corner(f, radius)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = f
	return f
end

-- Turn any frame or button into a sign: rounded face in the kind's colour (green, blue, brown, orange or
-- white), a dark edge, the white (or black) inner line, a press lip below and, once it is big enough, a
-- rivet in each corner. Calling it again repaints it in another kind. Labels made with Style.label inside
-- it afterwards take the kind's text colours.
function Style.sign(obj: GuiObject, kind: string?, small: boolean?)
	local k = kind or "green"
	local sign = SIGNS[k] or SIGNS.green
	obj:SetAttribute("Sign", k)
	obj.BackgroundColor3 = sign.face
	obj.BorderSizePixel = 0
	local radius = if small then 8 else 11
	Style.corner(obj, radius)
	local edge = obj:FindFirstChild("SignEdge") :: UIStroke?
	if not edge then
		local e = Style.stroke(obj, sign.edge, 2, 0)
		e.Name = "SignEdge"
		edge = e
	end
	(edge :: UIStroke).Color = sign.edge
	local line = obj:FindFirstChild("Line") :: Frame?
	if not line then
		line = innerLine(
			obj,
			if small then 3 else 4,
			if small then 1.8 else 2.2,
			radius - 3,
			sign.line
		)
		follow(obj, line :: Frame)
	end
	((line :: Frame):FindFirstChildOfClass("UIStroke") :: UIStroke).Color = sign.line
	local shadow = obj:FindFirstChild("Shadow")
	if not shadow then
		Style.shadow(obj, sign.edge, if small then 3 else Style.SHADOW)
	else
		for _, f in shadow:GetChildren() do
			if f:IsA("Frame") then
				f.BackgroundColor3 = sign.edge
			end
		end
	end
	if not small and not obj:FindFirstChild("Rivets") then
		local holder = Instance.new("Frame")
		holder.Name = "Rivets"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.Parent = obj
		for _, at in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
			local r = rivet(holder, 6)
			r.Position =
				UDim2.new(at[1], if at[1] == 0 then 9 else -9, at[2], if at[2] == 0 then 9 else -9)
		end
		-- rivets only on signs big enough to carry them
		local function check()
			local s = currentScale
			holder.Visible = obj.AbsoluteSize.X / s >= 150 and obj.AbsoluteSize.Y / s >= 90
		end
		obj:GetPropertyChangedSignal("AbsoluteSize"):Connect(check)
		check()
		follow(obj, holder)
	end
end

-- a highway-green sign (see Style.sign); radius is ignored (kept for older callers)
function Style.panel(parent: Instance, _radius: number?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = transparency or 0
	f.Parent = parent
	Style.sign(f, "green")
	return f
end

-- a recessed box inside a sign: the sign's colour darkened, with a faint light rim
function Style.card(parent: Instance, _radius: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = 0.74
	f.BorderSizePixel = 0
	f.Parent = parent
	Style.corner(f, 8)
	local rim = Style.stroke(f, Color3.new(1, 1, 1), 1.5, 0.78)
	rim.Name = "Rim"
	return f
end

local function press(b: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local function to(v: number, t: number)
		TweenService:Create(scale, TweenInfo.new(t, Enum.EasingStyle.Quad), { Scale = v }):Play()
	end
	b.MouseButton1Down:Connect(function()
		to(0.94, 0.05)
	end)
	b.MouseButton1Up:Connect(function()
		to(1, 0.1)
	end)
	b.MouseLeave:Connect(function()
		to(1, 0.1)
	end)
end

-- the exit-sign arrow a big button carries after its words: a shaft up and to the right with an open corner
local function exitArrow(parent: Instance): Frame
	local a = Instance.new("Frame")
	a.Name = "ExitArrow"
	a.BackgroundTransparency = 1
	a.AnchorPoint = Vector2.new(0, 0.5)
	a.Size = UDim2.fromOffset(18, 18)
	a.Parent = parent
	local function bar(x: number, y: number, w: number, h: number, rot: number)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.Rotation = rot
		f.Parent = a
		return f
	end
	bar(8, 10, 19, 4, -45) -- shaft
	bar(11, 2, 13, 4, 0) -- head, top
	bar(16, 7, 4, 13, 0) -- head, side
	return a
end

local function paintButton(b: TextButton, look: { Color3 })
	b.BackgroundColor3 = look[1]
	b.TextColor3 = look[2]
	local line = b:FindFirstChild("Line")
	if line then
		((line :: Frame):FindFirstChildOfClass("UIStroke") :: UIStroke).Color = look[2]
	end
	local shadow = b:FindFirstChild("Shadow")
	if shadow then
		for _, f in shadow:GetChildren() do
			(f :: Frame).BackgroundColor3 = look[3]
		end
	end
	local arrow = b:FindFirstChild("ExitArrow")
	if arrow then
		for _, f in arrow:GetChildren() do
			(f :: Frame).BackgroundColor3 = look[2]
		end
	end
end

-- a flat sign-plate button: yellow for go, white for no (and blue, red, orange), a black or white inner
-- line, a dark edge and a press lip; it sinks when pressed. Big ones carry two mounting bolts and an
-- exit-sign arrow after their words.
function Style.button(parent: Instance, text: string, kind: string?, size: number?): TextButton
	local look = KINDS[kind or "red"] or KINDS.red
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Text = text
	b.TextSize = size or 17
	b.FontFace = F.display
	b.Parent = parent
	Style.corner(b, 8)
	local edge = Style.stroke(b, C.ink, 2, 0)
	edge.Name = "Edge"
	follow(b, innerLine(b, 3, 1.6, 5, look[2]))
	Style.shadow(b, look[3], 4)
	-- bolts and the arrow show only on big plates with room beside the words
	local bolts = Instance.new("Frame")
	bolts.Name = "Bolts"
	bolts.BackgroundTransparency = 1
	bolts.Size = UDim2.fromScale(1, 1)
	bolts.Visible = false
	bolts.Parent = b
	rivet(bolts, 7).Position = UDim2.new(0, 11, 0.5, 0)
	rivet(bolts, 7).Position = UDim2.new(1, -11, 0.5, 0)
	local arrow = exitArrow(b)
	arrow.Visible = false
	follow(b, bolts)
	follow(b, arrow)
	paintButton(b, look)
	local function decorate()
		local s = currentScale
		local w, h = b.AbsoluteSize.X / s, b.AbsoluteSize.Y / s
		local tw = b.TextBounds.X / s
		local big = w >= 150 and h >= 44
		bolts.Visible = big
		arrow.Visible = big and w - tw >= 96
		arrow.Position = UDim2.new(0.5, tw / 2 + 9, 0.5, 0)
	end
	b:GetPropertyChangedSignal("AbsoluteSize"):Connect(decorate)
	b:GetPropertyChangedSignal("TextBounds"):Connect(decorate)
	decorate()
	press(b)
	return b
end

-- run the action when the button is pressed; on touch screens an invisible area around a small button
-- takes the tap too
function Style.onTap(button: GuiButton, action: () -> ())
	button.Activated:Connect(action)
	if UserInputService.TouchEnabled then
		local area = Instance.new("TextButton")
		area.Name = "TapArea"
		area.Text = ""
		area.BackgroundTransparency = 1
		area.AnchorPoint = Vector2.new(0.5, 0.5)
		area.Position = UDim2.fromScale(0.5, 0.5)
		area.Size = UDim2.new(1, LayoutConfig.TapPad * 2, 1, LayoutConfig.TapPad * 2)
		area.ZIndex = button.ZIndex + 1
		area.Parent = button
		area.Activated:Connect(action)
	end
end

-- recolour a button made by Style.button
function Style.setKind(b: TextButton, kind: string)
	paintButton(b, KINDS[kind] or KINDS.red)
end

-- a progress bar: a charcoal track with a dark edge and a yellow fill; returns the back and the fill
function Style.bar(parent: Instance, color: Color3?): (Frame, Frame)
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(44, 45, 49)
	back.BorderSizePixel = 0
	back.ClipsDescendants = true
	back.Parent = parent
	Style.corner(back, 4)
	local edge = Style.stroke(back, C.ink, 2, 0)
	edge.Name = "Edge"
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color or C.yellow
	fill.BorderSizePixel = 0
	fill.Parent = back
	Style.corner(fill, 3)
	return back, fill
end

-- kept for older callers: bars are solid in this style
function Style.laneGaps(_back: Frame, _behind: Color3) end

-- a yellow-and-black construction band across the top of a card; the stripes are drawn `width` layout px across
function Style.hazard(parent: Instance, width: number, height: number): Frame
	local band = Instance.new("Frame")
	band.Name = "Hazard"
	band.BackgroundColor3 = C.yellow
	band.BorderSizePixel = 0
	band.Size = UDim2.new(1, 0, 0, height)
	band.ClipsDescendants = true
	band.Parent = parent
	for x = -20, width + 20, 28 do
		local stripe = Instance.new("Frame")
		stripe.BackgroundColor3 = C.ink
		stripe.BorderSizePixel = 0
		stripe.Position = UDim2.fromOffset(x, -10)
		stripe.Size = UDim2.fromOffset(12, height + 26)
		stripe.Rotation = 40
		stripe.Parent = band
	end
	return band
end

-- one of the HUD's shape images (Config/Icons), fitted into its box; color tints the white ones
function Style.image(parent: Instance, id: number, color: Color3?): ImageLabel
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = if id ~= 0 then `rbxassetid://{id}` else ""
	img.ScaleType = Enum.ScaleType.Fit
	img.ImageColor3 = color or C.text
	img.Parent = parent
	return img
end

-- a small square-cornered sign tag ("TUTORIAL", "HOURLY") with a thin inner line; black words on light
-- colours, white on dark ones
function Style.pill(parent: Instance, text: string, color: Color3): TextLabel
	local light = color.R * 0.3 + color.G * 0.59 + color.B * 0.11 > 0.55
	local ink = if light then C.ink else C.text
	local p = Instance.new("TextLabel")
	p.Text = text
	p.TextSize = 12
	p.FontFace = F.heavy
	p.TextColor3 = ink
	p.BackgroundColor3 = color
	p.BackgroundTransparency = 0
	p.BorderSizePixel = 0
	p.AutomaticSize = Enum.AutomaticSize.X
	p.Size = UDim2.fromOffset(0, 18)
	p.Parent = parent
	Style.corner(p, 4)
	local line = Style.stroke(p, ink, 1.5, 0)
	line.Name = "Line"
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 7)
	pad.PaddingRight = UDim.new(0, 7)
	pad.PaddingTop = UDim.new(0, 2)
	pad.Parent = p
	return p
end

-- the red stop-sign octagon with a white rim that marks something new ("!" or a count); `size` layout px
function Style.stop(parent: Instance, text: string, size: number?): ImageLabel
	local s = size or 24
	local img = Instance.new("ImageLabel")
	img.Name = "Stop"
	img.BackgroundTransparency = 1
	img.Image = if Icons.Stop ~= 0 then `rbxassetid://{Icons.Stop}` else ""
	img.ScaleType = Enum.ScaleType.Fit
	img.Size = UDim2.fromOffset(s, s)
	img.Parent = parent
	if Icons.Stop == 0 then -- no image yet: a red rounded square
		img.BackgroundColor3 = C.red
		img.BackgroundTransparency = 0
		Style.corner(img, 6)
		Style.stroke(img, C.text, 1.5, 0)
	end
	local l = Instance.new("TextLabel")
	l.Name = "Count"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Position = UDim2.fromOffset(0, 1)
	l.Text = text
	l.TextSize = math.floor(s * 0.55)
	l.FontFace = F.display
	l.TextColor3 = C.text
	l.Parent = img
	return img
end

-- two steel sign posts from a pop-up's bottom edge down off the screen, so the card stands like a road sign
function Style.posts(card: GuiObject)
	local holder = Instance.new("Frame")
	holder.Name = "Posts"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = card
	for _, x in { 0.2, 0.8 } do
		local post = Instance.new("Frame")
		post.BackgroundColor3 = Color3.fromRGB(186, 192, 198)
		post.BorderSizePixel = 0
		post.AnchorPoint = Vector2.new(0.5, 0)
		post.Position = UDim2.new(x, 0, 1, Style.SHADOW)
		post.Size = UDim2.fromOffset(11, 900)
		post.Parent = holder
		Style.stroke(post, Color3.fromRGB(61, 66, 72), 1.5, 0)
	end
	follow(card, holder)
end

-- the X in a card's top right corner: every pop-up has one (a white sign plate)
function Style.closeX(card: GuiObject, onClose: () -> ()): TextButton
	local x = Style.button(card, "X", "dark", 22)
	x.Name = "CloseX"
	x.AnchorPoint = Vector2.new(1, 0)
	x.Position = UDim2.new(1, -8, 0, 8)
	x.Size = UDim2.fromOffset(42, 42)
	x.ZIndex = card.ZIndex + 10
	Style.onTap(x, onClose)
	return x
end

function Style.money(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return "$" .. out
end

return Style
