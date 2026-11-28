--!strict
-- One look for every screen, "Road": straight shapes with 6 px (buttons) and 8 px (sheets, cards) corners, a
-- thick black outline on everything, traffic colours, Titillium Web Black type with a black text stroke on
-- colour, and a few road touches (asphalt sheets, dashed yellow lane lines, hazard stripes, checkered strips).
-- Every shape here is coded from Frames, UICorner, UIStroke and UIGradient, so nothing waits on an image;
-- only icons are images (Config/Icons). Everything visual goes through here so the UI stays consistent.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Callouts = require(ReplicatedStorage.Shared.Config.Callouts)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local PopupsConfig = require(ReplicatedStorage.Shared.Config.Popups)
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

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local INK = rgb(20, 20, 20)
local WHITE = rgb(255, 255, 255)

-- traffic colours; the menu colours are GARAGE blue, STORE green, GOALS red, MAP amber, INVITE purple and
-- settings grey. Old names (panel, card, gold, money...) are kept so every screen keeps working.
Style.colors = table.freeze({
	ink = INK,
	asphalt = rgb(52, 54, 59), -- sheets and HUD bars
	panel = rgb(52, 54, 59),
	panelTop = rgb(52, 54, 59),
	card = rgb(38, 40, 44), -- a darker box inside a sheet
	edge = WHITE,
	text = WHITE,
	dim = rgb(184, 188, 196),
	yellow = rgb(255, 204, 0),
	amber = rgb(255, 184, 0),
	red = rgb(255, 59, 48),
	pink = rgb(255, 79, 163),
	orange = rgb(255, 106, 19),
	gold = rgb(255, 204, 0),
	money = rgb(255, 204, 0),
	blue = rgb(31, 123, 255),
	purple = rgb(163, 71, 255),
	green = rgb(25, 194, 74),
	grey = rgb(138, 146, 156),
	brown = rgb(150, 96, 52),
	white = WHITE,
	steel = rgb(150, 158, 166),
	billEdge = rgb(26, 160, 67), -- the store's drawn banknotes
	billInk = rgb(11, 93, 34),
	prize = rgb(58, 42, 85), -- the daily streak's week prize tile
})
local C = Style.colors

-- Titillium Web (built into Roblox) in its Black weight for everything big, Bold for sentences
local TITILLIUM = "rbxasset://fonts/families/TitilliumWeb.json"
Style.fonts = table.freeze({
	display = Font.new(TITILLIUM, Enum.FontWeight.Heavy),
	heavy = Font.new(TITILLIUM, Enum.FontWeight.Heavy),
	bold = Font.new(TITILLIUM, Enum.FontWeight.Bold),
	medium = Font.new(TITILLIUM, Enum.FontWeight.SemiBold),
	sign = Font.new(TITILLIUM, Enum.FontWeight.Heavy),
})
local F = Style.fonts

-- the shapes' numbers, layout px
local R_SMALL = 6 -- buttons, plates
local R_BIG = 8 -- sheets, cards
local R_TINY = 4 -- tags, chips, bars
local INK_W = 4 -- the black outline round everything
local SHEET_W = 5 -- and round sheets
local SHINE = 5 -- the inner top highlight (white 28%)
local BAND = 6 -- the inner bottom band (black 22%)

-- what sits on each colour: words, small words, money; `stroke` = white words get a black text stroke
type Sign = {
	face: Color3,
	text: Color3,
	dim: Color3,
	money: Color3,
	stroke: boolean,
}
local function onColour(face: Color3): Sign
	return {
		face = face,
		text = WHITE,
		dim = WHITE:Lerp(face, 0.18),
		money = C.yellow,
		stroke = true,
	}
end
local function onLight(face: Color3, dim: Color3): Sign
	return { face = face, text = INK, dim = dim, money = INK, stroke = false }
end
Style.signs = table.freeze({
	asphalt = { face = C.asphalt, text = WHITE, dim = C.dim, money = C.yellow, stroke = false },
	card = { face = C.card, text = WHITE, dim = C.dim, money = C.yellow, stroke = false },
	green = onColour(C.green),
	blue = onColour(C.blue),
	red = onColour(C.red),
	purple = onColour(C.purple),
	orange = onColour(C.orange),
	pink = onColour(C.pink),
	grey = onColour(C.grey),
	brown = onColour(C.brown),
	ink = { face = INK, text = WHITE, dim = C.dim, money = C.yellow, stroke = false },
	yellow = onLight(C.yellow, rgb(92, 70, 0)),
	amber = onLight(C.amber, rgb(92, 62, 0)),
	white = onLight(WHITE, rgb(75, 85, 99)),
} :: { [string]: Sign })
local SIGNS = Style.signs

-- the colour a piece sits on (the nearest ancestor painted by Style.sign / card / bubble), asphalt by default
local function signOf(obj: Instance?): Sign
	local o = obj
	while o and not o:IsA("LayerCollector") do
		local k = o:GetAttribute("Sign")
		if type(k) == "string" and SIGNS[k] then
			return SIGNS[k]
		end
		o = o.Parent
	end
	return SIGNS.asphalt
end

-- white words on a colour stay white; on yellow or white they turn black, and so on
local function tone(parent: Instance?, color: Color3): Color3
	local sign = signOf(parent)
	if sign.text == WHITE then
		return color
	end
	if color == C.text then
		return sign.text
	elseif color == C.dim then
		return sign.dim
	elseif color == C.money then
		return sign.money
	end
	return color
end
Style.tone = tone

-- button looks: face colour, and whether the words are black (else white with a black stroke)
local KINDS: { [string]: { any } } = {
	red = { C.red, false },
	orange = { C.orange, false },
	gold = { C.green, false }, -- go
	green = { C.green, false }, -- go
	blue = { C.blue, false },
	purple = { C.purple, false },
	pink = { C.pink, false },
	grey = { C.grey, false },
	ink = { C.asphalt, false }, -- a tab that isn't open
	dark = { WHITE, true }, -- no / back
	white = { WHITE, true },
	yellow = { C.yellow, true },
	amber = { C.amber, true },
}

-- 6 px for buttons, 8 for sheets and cards; never rounder (999 and up stays a circle)
function Style.corner(obj: Instance, radius: number)
	local c = obj:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	if radius >= 100 then
		c.CornerRadius = UDim.new(0.5, 0)
	else
		c.CornerRadius = UDim.new(0, math.min(radius, R_BIG))
	end
	c.Parent = obj
end

local function radiusOf(obj: Instance): number
	local c = obj:FindFirstChildOfClass("UICorner")
	return if c then c.CornerRadius.Offset else 0
end

-- inside the shape, so a sheet's size is its outer size (as in the drafts)
local function inner(s: UIStroke)
	pcall(function()
		(s :: any).BorderStrokePosition = Enum.BorderStrokePosition.Inner
	end)
end

-- keep a piece's own parts drawn in the right order in either ZIndex mode. `layer` (0 shade, 1 trim...)
-- puts a part under everything else in the piece: in a ScreenGui that sorts siblings, below every sibling
-- (any ZIndex the caller gave its labels); in one that sorts globally, on the piece's own ZIndex, drawn
-- before the labels made after it. Without a layer it takes the piece's ZIndex.
local BACK = -50
local function follow(obj: GuiObject, part: GuiObject, layer: number?)
	local function sync()
		local root = obj:FindFirstAncestorWhichIsA("LayerCollector")
		local sibling = root ~= nil and (root :: any).ZIndexBehavior == Enum.ZIndexBehavior.Sibling
		local z = if layer and sibling then BACK + layer else obj.ZIndex
		part.ZIndex = z
		for _, d in part:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = z
			end
		end
	end
	obj:GetPropertyChangedSignal("ZIndex"):Connect(sync)
	obj.AncestryChanged:Connect(sync)
	sync()
end

-- a part filling the whole object even when the object has a UIPadding (for its words), `inset` px in
local function unpad(obj: GuiObject, part: GuiObject, inset: number)
	local function fit()
		local pad = obj:FindFirstChildOfClass("UIPadding")
		local l, r, t, b = 0, 0, 0, 0
		if pad then
			l, r = pad.PaddingLeft.Offset, pad.PaddingRight.Offset
			t, b = pad.PaddingTop.Offset, pad.PaddingBottom.Offset
		end
		part.Position = UDim2.fromOffset(inset - l, inset - t)
		part.Size = UDim2.new(1, l + r - inset * 2, 1, t + b - inset * 2)
	end
	obj.ChildAdded:Connect(function(c)
		if c:IsA("UIPadding") then
			fit()
		end
	end)
	fit()
end

-- the black outline (one per piece, named Ink); calling again changes its width
local function ink(obj: GuiObject, width: number): UIStroke
	local s = obj:FindFirstChild("Ink") :: UIStroke?
	if not s then
		local new = Instance.new("UIStroke")
		new.Name = "Ink"
		new.Color = INK
		new.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		new.LineJoinMode = Enum.LineJoinMode.Round
		inner(new)
		new.Parent = obj
		s = new
	end
	local stroke = s :: UIStroke
	stroke.Thickness = width
	obj:SetAttribute("InkWidth", width)
	return stroke
end

-- the inner top highlight and bottom band: one frame inside the outline whose gradient is white at the
-- top, clear in the middle and black at the bottom, hard-edged, measured in px from the piece's height
local function shadeKeys(s: Frame, obj: GuiObject, shine: number, band: number)
	local g = s:FindFirstChildOfClass("UIGradient") :: UIGradient
	local w = (obj:GetAttribute("InkWidth") :: number?) or 0
	local h = obj.AbsoluteSize.Y / currentScale - w * 2
	if h <= 2 then
		return
	end
	local room = math.max(1, math.min(1, (h - 2) / (shine + band)))
	local a = math.clamp(shine * room / h, 0.002, 0.45)
	local b = math.clamp(1 - band * room / h, 0.55, 0.998)
	local e = 0.001
	local top, bottom = 0.72, 0.78
	if shine <= 0 then
		top = 1
	end
	if band <= 0 then
		bottom = 1
	end
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, top),
		NumberSequenceKeypoint.new(a, top),
		NumberSequenceKeypoint.new(a + e, 1),
		NumberSequenceKeypoint.new(b - e, 1),
		NumberSequenceKeypoint.new(b, bottom),
		NumberSequenceKeypoint.new(1, bottom),
	})
end

local function shade(obj: GuiObject, shine: number, band: number)
	local s = obj:FindFirstChild("Shade") :: Frame?
	if not s then
		local new = Instance.new("Frame")
		new.Name = "Shade"
		new.BackgroundColor3 = WHITE
		new.BorderSizePixel = 0
		new.Active = false
		new.Parent = obj
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WHITE),
			ColorSequenceKeypoint.new(0.5, WHITE),
			ColorSequenceKeypoint.new(0.501, INK),
			ColorSequenceKeypoint.new(1, INK),
		})
		g.Parent = new
		Instance.new("UICorner").Parent = new
		follow(obj, new, 0)
		s = new
		obj:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			shadeKeys(
				new,
				obj,
				obj:GetAttribute("Shine") :: number,
				obj:GetAttribute("Band") :: number
			)
		end)
	end
	local f = s :: Frame
	obj:SetAttribute("Shine", shine)
	obj:SetAttribute("Band", band)
	local w = (obj:GetAttribute("InkWidth") :: number?) or 0
	if not f:GetAttribute("Fitted") then
		f:SetAttribute("Fitted", true)
		unpad(obj, f, w)
	end
	local corner = f:FindFirstChildOfClass("UICorner") :: UICorner
	corner.CornerRadius = UDim.new(0, math.max(0, radiusOf(obj) - w))
	f.BackgroundTransparency = obj.BackgroundTransparency
	shadeKeys(f, obj, shine, band)
end

-- the piece's outline and shade fade with its background (fades tween BackgroundTransparency)
local function fades(obj: GuiObject)
	if obj:GetAttribute("Fades") then
		return
	end
	obj:SetAttribute("Fades", true)
	obj:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
		local t = obj.BackgroundTransparency
		local s = obj:FindFirstChild("Ink")
		if s and s:IsA("UIStroke") and not obj:GetAttribute("Ringed") then
			s.Transparency = t
		end
		local f = obj:FindFirstChild("Shade")
		if f and f:IsA("Frame") then
			f.BackgroundTransparency = t
		end
	end)
end

-- a text stroke in ink on a label's words (one per label, named TextInk); width 0 takes it off
local function textInk(l: TextLabel | TextButton, width: number)
	local s = l:FindFirstChild("TextInk") :: UIStroke?
	if width <= 0 then
		if s then
			s:Destroy()
		end
		return
	end
	if not s then
		local new = Instance.new("UIStroke")
		new.Name = "TextInk"
		new.Color = INK
		new.LineJoinMode = Enum.LineJoinMode.Round
		new.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		new.Parent = l
		s = new
	end
	(s :: UIStroke).Thickness = width
end

local function inkFor(size: number): number
	return if size >= 26 then 3 else 2
end

-- a text label or button's words drawn by a child over its shade (an object's own text draws under its
-- children): the object keeps its Text, size and colours, which the words copy, and its own text is hidden
local MIRROR = {
	"Text",
	"TextSize",
	"FontFace",
	"TextColor3",
	"TextTransparency",
	"TextScaled",
	"TextWrapped",
	"RichText",
	"TextXAlignment",
	"TextYAlignment",
	"AutoLocalize",
	"LineHeight",
	"TextTruncate",
	"TextStrokeColor3",
	"TextStrokeTransparency",
}
local function words(obj: TextLabel | TextButton, lift: number): TextLabel
	local w = Instance.new("TextLabel")
	w.Name = "Words"
	w.BackgroundTransparency = 1
	w.Position = UDim2.fromOffset(0, -lift)
	w.Size = UDim2.fromScale(1, 1)
	w.Parent = obj
	for _, p in MIRROR do
		local function copy()
			(w :: any)[p] = (obj :: any)[p]
		end
		copy()
		obj:GetPropertyChangedSignal(p):Connect(copy)
	end
	obj.MaxVisibleGraphemes = 0
	-- a size cap or text outline put on the object applies to the words
	local function take(c: Instance)
		local stroke = c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual
		if c:IsA("UITextSizeConstraint") or stroke then
			if stroke then
				local old = w:FindFirstChild("TextInk")
				if old then
					old:Destroy()
				end
				c.Name = "TextInk"
			end
			c:Clone().Parent = w
		end
	end
	for _, c in obj:GetChildren() do
		take(c)
	end
	obj.ChildAdded:Connect(take)
	follow(obj, w)
	return w
end

-- a highlight ring round a piece (an event about to end, a car you can buy): its outline turns that colour;
-- pass nil to put the black back
function Style.ring(obj: GuiObject, color: Color3?)
	local s = obj:FindFirstChild("Ink") :: UIStroke?
	if s then
		obj:SetAttribute("Ringed", color ~= nil)
		s.Color = color or INK
		s.Transparency = if color then 0 else obj.BackgroundTransparency
		return
	end
	local ring = obj:FindFirstChild("SignEdge") :: UIStroke?
	if not ring then
		local r = Instance.new("UIStroke")
		r.Name = "SignEdge"
		r.Thickness = 3
		r.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		r.LineJoinMode = Enum.LineJoinMode.Round
		r.Parent = obj
		ring = r
	end
	local r = ring :: UIStroke
	r.Color = color or C.yellow
	r.Transparency = if color then 0 else 1
end

-- an outline. On a piece that already has its black outline, the new one is drawn by a ring frame laid
-- over it, so both show (and the caller's changes to the returned stroke still work).
function Style.stroke(
	obj: Instance,
	color: Color3?,
	thickness: number?,
	transparency: number?
): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or INK
	s.Thickness = thickness or 2
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	local holder: Instance = obj
	if obj:IsA("GuiObject") and obj:FindFirstChild("Ink") then
		local over = Instance.new("Frame")
		over.Name = "Ring"
		over.BackgroundTransparency = 1
		over.Size = UDim2.fromScale(1, 1)
		over.Parent = obj
		Style.corner(over, radiusOf(obj))
		follow(obj, over)
		holder = over
	end
	s.Parent = holder
	return s
end

-- the colour as a flat face with a plain gradient (kept for older callers)
function Style.gradient(obj: Instance, top: Color3, _bottom: Color3): UIGradient
	if obj:IsA("GuiObject") then
		obj.BackgroundColor3 = top
	end
	local g = Instance.new("UIGradient")
	g.Parent = obj
	return g
end

---------------------------------------------------------------- labels, sheets, cards and buttons

-- words: white, Titillium; black on yellow or white pieces, and with a black stroke on colours
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
	-- on a colour, light words get a black stroke; it goes when the words turn dark
	if signOf(parent).stroke then
		local function stroke()
			local c = l.TextColor3
			local light = c.R * 0.3 + c.G * 0.59 + c.B * 0.11 > 0.6
			textInk(l, if light then inkFor(l.TextSize) else 0)
		end
		l:GetPropertyChangedSignal("TextColor3"):Connect(stroke)
		stroke()
	end
	return l
end

-- a road marking: a dashed yellow lane line on asphalt (horizontal, or vertical with vertical = true), a
-- thin black rule on a colour; the colour argument is kept for older callers and ignored
local DASH, GAP = 26, 18
local function dashes(holder: Frame, vertical: boolean)
	local function build()
		local s = currentScale
		local long = (if vertical then holder.AbsoluteSize.Y else holder.AbsoluteSize.X) / s * 2
		local need = math.ceil(long / (DASH + GAP)) + 1
		local have = holder:GetAttribute("Dashes") :: number? or 0
		for i = have, need - 1 do
			local d = Instance.new("Frame")
			d.Name = "Dash"
			d.BorderSizePixel = 0
			d.BackgroundColor3 = C.yellow
			if vertical then
				d.Position = UDim2.fromOffset(0, i * (DASH + GAP))
				d.Size = UDim2.new(1, 0, 0, DASH)
			else
				d.Position = UDim2.fromOffset(i * (DASH + GAP), 0)
				d.Size = UDim2.new(0, DASH, 1, 0)
			end
			d.ZIndex = holder.ZIndex
			d.Parent = holder
		end
		holder:SetAttribute("Dashes", math.max(have, need))
	end
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(build)
	holder:GetPropertyChangedSignal("ZIndex"):Connect(function()
		for _, d in holder:GetChildren() do
			if d:IsA("GuiObject") then
				d.ZIndex = holder.ZIndex
			end
		end
	end)
	task.defer(build)
end

-- a dashed yellow lane line (6 px), across or (vertical) down its box; give it a Size and Position
function Style.lane(parent: Instance, vertical: boolean?): Frame
	local f = Instance.new("Frame")
	f.Name = "Lane"
	f.BackgroundTransparency = 1
	f.ClipsDescendants = true
	f.Size = if vertical then UDim2.new(0, 6, 1, 0) else UDim2.new(1, 0, 0, 6)
	f.Parent = parent
	dashes(f, vertical == true)
	return f
end

function Style.dashes(
	parent: Instance,
	_color: Color3?,
	vertical: boolean?,
	thickness: number?
): Frame
	local t = math.min(thickness or 4, 6)
	local sign = signOf(parent)
	if sign == SIGNS.asphalt or sign == SIGNS.card or sign == SIGNS.ink then
		local lane = Style.lane(parent, vertical)
		lane.Name = "Dashes"
		lane.Size = if vertical then UDim2.new(0, t, 1, 0) else UDim2.new(1, 0, 0, t)
		return lane
	end
	local line = Instance.new("Frame")
	line.Name = "Dashes"
	line.BackgroundColor3 = INK
	line.BorderSizePixel = 0
	line.Size = if vertical then UDim2.new(0, t, 1, 0) else UDim2.new(1, 0, 0, t)
	line.Parent = parent
	return line
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

-- a solid black text stroke so words read over the world or on a colour
function Style.outline(l: TextLabel | TextButton, thickness: number?)
	local w = l:FindFirstChild("Words")
	textInk(if w and w:IsA("TextLabel") then w else l, thickness or 2)
end

-- Paint any frame or button as a piece of the kit. Big ones (sheets) are asphalt with a 5 px black outline
-- and remember `kind` as their accent (Accent attribute, for a title plate); small ones (plates, tags, tiles)
-- take the kind's colour (green, blue, red, purple, orange, pink, grey, yellow, amber, white, asphalt) with a
-- 4 px outline, the inner highlight and the bottom band. Calling it again repaints it. Labels made with
-- Style.label inside it afterwards take the kind's text colours.
function Style.sign(obj: GuiObject, kind: string?, small: boolean?)
	local k = if kind and SIGNS[kind] then kind else "asphalt"
	local face = if small then k else "asphalt"
	local sign = SIGNS[face]
	obj:SetAttribute("Sign", face)
	if not small then
		obj:SetAttribute("Accent", k)
	end
	obj.BorderSizePixel = 0
	obj.BackgroundColor3 = sign.face
	Style.corner(obj, if small then R_SMALL else R_BIG)
	ink(obj, if small then INK_W else SHEET_W)
	if small then
		shade(obj, SHINE, BAND)
	end
	fades(obj)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		local w = obj:FindFirstChild("Words") :: TextLabel?
		if not w then
			w = words(obj :: any, 0)
		end
		local t = obj :: TextLabel
		if t.TextColor3 == WHITE or t.TextColor3 == INK then
			t.TextColor3 = sign.text
		end
		textInk(w :: TextLabel, if sign.stroke then inkFor(t.TextSize) else 0)
	end
end

-- an asphalt sheet (see Style.sign); radius is ignored (kept for older callers)
function Style.panel(parent: Instance, _radius: number?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = transparency or 0
	f.Parent = parent
	Style.sign(f, "asphalt")
	return f
end

-- the garage tour's callout: a white body under a yellow title band (Style.BUBBLE_HEAD px), held up by a
-- short black post at the bottom left (the bottom Style.BUBBLE_TAIL px). Labels inside it take black words.
Style.BUBBLE_HEAD = 44
Style.BUBBLE_TAIL = 13
function Style.bubble(parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = "Bubble"
	f.BackgroundTransparency = 1
	f.Parent = parent
	f:SetAttribute("Sign", "white")
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundColor3 = WHITE
	body.Size = UDim2.new(1, 0, 1, -Style.BUBBLE_TAIL)
	body.Parent = f
	Style.corner(body, R_BIG)
	ink(body, INK_W)
	follow(f, body, 0)
	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundColor3 = C.yellow
	head.BorderSizePixel = 0
	head.Position = UDim2.fromOffset(INK_W, INK_W)
	head.Size = UDim2.new(1, -INK_W * 2, 0, Style.BUBBLE_HEAD - INK_W)
	head.Parent = body
	Style.corner(head, R_BIG - INK_W)
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = INK
	rule.BorderSizePixel = 0
	rule.Position = UDim2.new(0, 0, 1, -3)
	rule.Size = UDim2.new(1, 0, 0, 3)
	rule.Parent = head
	follow(f, head, 1)
	local post = Instance.new("Frame")
	post.Name = "Post"
	post.BackgroundColor3 = INK
	post.BorderSizePixel = 0
	post.Position = UDim2.new(0, 28, 1, -Style.BUBBLE_TAIL - 2)
	post.Size = UDim2.fromOffset(10, Style.BUBBLE_TAIL + 2)
	post.Parent = f
	follow(f, post, 0)
	return f
end

-- a box inside a sheet: darker asphalt with a black outline
function Style.card(parent: Instance, _radius: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = C.card
	f.Parent = parent
	f:SetAttribute("Sign", "card")
	Style.corner(f, R_BIG)
	ink(f, INK_W)
	fades(f)
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

local function paintButton(b: TextButton, look: { any })
	local dark = look[2] == true
	b.BackgroundColor3 = look[1]
	b.TextColor3 = if dark then INK else WHITE
	local w = b:FindFirstChild("Words") :: TextLabel?
	if not w then
		w = words(b, 1)
	end
	textInk(w :: TextLabel, if dark then 0 else inkFor(b.TextSize))
end

-- a button: a flat traffic-colour face (green for go, white for no; also red, blue, orange, purple, pink,
-- grey, yellow, amber), 6 px corners, a 4 px black outline, the inner highlight and bottom band, and white
-- words with a black stroke (black words on white and yellow). It sinks when pressed.
function Style.button(parent: Instance, text: string, kind: string?, size: number?): TextButton
	local look = KINDS[kind or "red"] or KINDS.red
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Text = text
	b.TextSize = size or 17
	b.FontFace = F.display
	b.Parent = parent
	Style.corner(b, R_SMALL)
	ink(b, INK_W)
	shade(b, SHINE, BAND)
	fades(b)
	paintButton(b, look)
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

-- a progress bar: an asphalt track with a 3 px black outline and a flat fill (yellow unless told) with a
-- thin highlight; returns the track and the fill. The outline is drawn over the fill.
function Style.bar(parent: Instance, color: Color3?): (Frame, Frame)
	local back = Instance.new("Frame")
	back.BorderSizePixel = 0
	back.BackgroundColor3 = C.asphalt
	back.ClipsDescendants = true
	back.Parent = parent
	Style.corner(back, R_TINY)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = color or C.yellow
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = back
	shade(fill, 3, 0)
	fades(fill)
	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.BackgroundTransparency = 1
	edge.Size = UDim2.fromScale(1, 1)
	edge.Parent = back
	Style.corner(edge, R_TINY)
	local s = Instance.new("UIStroke")
	s.Name = "Ink"
	s.Color = INK
	s.Thickness = 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	inner(s)
	s.Parent = edge
	local function z()
		fill.ZIndex = back.ZIndex
		edge.ZIndex = back.ZIndex + 1
	end
	back:GetPropertyChangedSignal("ZIndex"):Connect(z)
	z()
	return back, fill
end

-- kept for older callers: bars are solid in this style
function Style.laneGaps(_back: Frame, _behind: Color3) end

-- yellow-and-black hazard stripes filling a box (thin black frames at 45 degrees on yellow, clipped by the
-- box): the frame round events and offers. Give it a Size and Position.
local STRIPE, PITCH = 10, 22 -- black stripe width across and stripe spacing, layout px
function Style.stripes(parent: Instance): Frame
	local band = Instance.new("Frame")
	band.Name = "Stripes"
	band.BackgroundColor3 = C.yellow
	band.BorderSizePixel = 0
	band.ClipsDescendants = true
	band.Parent = parent
	local function build()
		local s = currentScale
		local w = band.AbsoluteSize.X / s * 2
		local h = band.AbsoluteSize.Y / s * 2
		local need = math.ceil((w + h) / PITCH) + 1
		local have = band:GetAttribute("Stripes") :: number? or 0
		for i = have, need - 1 do
			local d = Instance.new("Frame")
			d.Name = "Stripe"
			d.BorderSizePixel = 0
			d.BackgroundColor3 = INK
			d.AnchorPoint = Vector2.new(0.5, 0.5)
			d.Rotation = 45 -- the one turned piece: a stripe inside its clipping band
			d.Position = UDim2.new(0, i * PITCH - h / 2, 0.5, 0)
			d.Size = UDim2.fromOffset(STRIPE / math.sqrt(2), h * 2 + 40)
			d.ZIndex = band.ZIndex
			d.Parent = band
		end
		band:SetAttribute("Stripes", math.max(have, need))
	end
	band:GetPropertyChangedSignal("AbsoluteSize"):Connect(build)
	band:GetPropertyChangedSignal("ZIndex"):Connect(function()
		for _, d in band:GetChildren() do
			if d:IsA("GuiObject") then
				d.ZIndex = band.ZIndex
			end
		end
	end)
	task.defer(build)
	return band
end

-- a hazard band along the top of a card, just inside its outline (`width` is kept for older callers)
function Style.hazard(parent: Instance, _width: number, height: number): Frame
	local band = Style.stripes(parent)
	band.Name = "Hazard"
	band.Position = UDim2.fromOffset(INK_W, INK_W)
	band.Size = UDim2.new(1, -INK_W * 2, 0, height)
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = INK
	rule.BorderSizePixel = 0
	rule.Position = UDim2.fromOffset(INK_W, INK_W + height)
	rule.Size = UDim2.new(1, -INK_W * 2, 0, 3)
	rule.Parent = parent
	return band
end

-- a checkered strip (finish-line squares, `cell` px) filling a box: the top of reward cards
function Style.checker(parent: Instance, cell: number?): Frame
	local size = cell or 12
	local strip = Instance.new("Frame")
	strip.Name = "Checker"
	strip.BackgroundColor3 = WHITE
	strip.BorderSizePixel = 0
	strip.ClipsDescendants = true
	strip.Parent = parent
	local function build()
		local s = currentScale
		local cols = math.ceil(strip.AbsoluteSize.X / s * 2 / size)
		local rows = math.ceil(strip.AbsoluteSize.Y / s * 2 / size)
		local key = cols * 1000 + rows
		if (strip:GetAttribute("Built") :: number? or 0) >= key then
			return
		end
		strip:SetAttribute("Built", key)
		for _, c in strip:GetChildren() do
			if c.Name == "Cell" then
				c:Destroy()
			end
		end
		for r = 0, rows - 1 do
			for c = r % 2, cols - 1, 2 do
				local d = Instance.new("Frame")
				d.Name = "Cell"
				d.BorderSizePixel = 0
				d.BackgroundColor3 = INK
				d.Position = UDim2.fromOffset(c * size, r * size)
				d.Size = UDim2.fromOffset(size, size)
				d.ZIndex = strip.ZIndex
				d.Parent = strip
			end
		end
	end
	strip:GetPropertyChangedSignal("AbsoluteSize"):Connect(build)
	task.defer(build)
	return strip
end

-- a checkered strip along the top of a card, just inside its outline, with a black rule under it: the top of
-- reward pop-ups (the hazard band's partner)
function Style.checkerTop(parent: Instance, height: number): Frame
	local strip = Style.checker(parent, height / 2)
	strip.Name = "CheckerTop"
	strip.Position = UDim2.fromOffset(INK_W, INK_W)
	strip.Size = UDim2.new(1, -INK_W * 2, 0, height)
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = INK
	rule.BorderSizePixel = 0
	rule.Position = UDim2.fromOffset(INK_W, INK_W + height)
	rule.Size = UDim2.new(1, -INK_W * 2, 0, 3)
	rule.Parent = parent
	return strip
end

-- a pop-up's big icon, centred on the card's top edge and poking out over it (upright, full colour)
function Style.topIcon(card: GuiObject, id: number, size: number): ImageLabel
	local icon = Style.image(card, id)
	icon.Name = "TopIcon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0)
	icon.Size = UDim2.fromOffset(size, size)
	icon.ZIndex = card.ZIndex + 5
	return icon
end

-- a quiet "no thanks": grey words with no plate, so the one real choice stands out
function Style.quiet(parent: Instance, text: string, size: number?): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Quiet"
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Text = text
	b.TextSize = size or 16
	b.FontFace = F.display
	b.TextColor3 = C.dim
	b.Parent = parent
	b.MouseEnter:Connect(function()
		b.TextColor3 = WHITE
	end)
	b.MouseLeave:Connect(function()
		b.TextColor3 = C.dim
	end)
	return b
end

-- one of the icon images (Config/Icons), fitted into its box; color tints it (white = as drawn)
function Style.image(parent: Instance, id: number, color: Color3?): ImageLabel
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = if id ~= 0 then `rbxassetid://{id}` else ""
	img.ScaleType = Enum.ScaleType.Fit
	img.ImageColor3 = color or C.text
	img.Parent = parent
	return img
end

-- a small tag ("TUTORIAL", "HOURLY"): a colour plate, 4 px corners, a 3 px black outline; black words on
-- light colours, white with a stroke on the rest
function Style.pill(parent: Instance, text: string, color: Color3): TextLabel
	local light = color.R * 0.3 + color.G * 0.59 + color.B * 0.11 > 0.62
	local p = Instance.new("TextLabel")
	p.Text = text
	p.TextSize = 12
	p.FontFace = F.heavy
	p.TextColor3 = if light then INK else WHITE
	p.BackgroundColor3 = color
	p.BorderSizePixel = 0
	p.Size = UDim2.fromOffset(0, 20)
	p.Parent = parent
	Style.corner(p, R_TINY)
	ink(p, 3)
	fades(p)
	-- as wide as its words plus a margin
	local function fit()
		p.Size = UDim2.new(0, p.TextBounds.X / currentScale + 16, p.Size.Y.Scale, p.Size.Y.Offset)
	end
	p:GetPropertyChangedSignal("TextBounds"):Connect(fit)
	fit()
	local w = words(p, 0)
	-- light words get a black stroke, dark ones none (callers recolour tags)
	local function stroke()
		local c = p.TextColor3
		textInk(w, if c.R * 0.3 + c.G * 0.59 + c.B * 0.11 > 0.6 then 2 else 0)
	end
	p:GetPropertyChangedSignal("TextColor3"):Connect(stroke)
	stroke()
	return p
end

-- a black chip with yellow words: timers and prices on a colour ("2:45", "$1,000")
function Style.chip(parent: Instance, text: string, size: number?): TextLabel
	local p = Instance.new("TextLabel")
	p.Text = text
	p.TextSize = size or 18
	p.FontFace = F.heavy
	p.TextColor3 = C.yellow
	p.BackgroundColor3 = INK
	p.BorderSizePixel = 0
	p.Parent = parent
	Style.corner(p, R_TINY)
	return p
end

-- the yellow square badge with a black number that marks something new ("!" or a count); `size` layout px
function Style.stop(parent: Instance, text: string, size: number?): Frame
	local s = size or 24
	local f = Instance.new("Frame")
	f.Name = "Stop"
	f.BackgroundColor3 = C.yellow
	f.BorderSizePixel = 0
	f.Size = UDim2.fromOffset(s, s)
	f.Parent = parent
	Style.corner(f, R_TINY)
	ink(f, 3)
	local l = Instance.new("TextLabel")
	l.Name = "Count"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = text
	l.TextSize = math.floor(s * 0.6)
	l.FontFace = F.display
	l.TextColor3 = INK
	l.Parent = f
	return f
end

-- the one slot every pop-up card opens in: over the car, between the event sign and the speedometer
-- (Config/Popups SlotTop / SlotBottom). The card goes in a full-screen holder whose scale shrinks it when it
-- is taller than the slot (the card keeps its own UIScale for its pop-in).
function Style.slot(card: GuiObject)
	local holder = Instance.new("Frame")
	holder.Name = card.Name .. "Slot"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = card.ZIndex
	holder.Parent = card.Parent
	local fit = Instance.new("UIScale")
	fit.Parent = holder
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, (PopupsConfig.SlotTop - PopupsConfig.SlotBottom) / 2)
	card.Parent = holder
	local function size()
		local root = holder:FindFirstAncestorWhichIsA("LayerCollector") :: ScreenGui?
		if not root then
			return
		end
		local room = root.AbsoluteSize.Y / currentScale
			- PopupsConfig.SlotTop
			- PopupsConfig.SlotBottom
		local h = card.Size.Y.Offset
		fit.Scale = if h > 0 then math.min(1, room / h) else 1
	end
	card:GetPropertyChangedSignal("Size"):Connect(size)
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(size)
	size()
end

-- the X on a card's top right corner, poking out over it: the stop-sign icon (a white X on red)
function Style.closeX(card: GuiObject, onClose: () -> ()): TextButton
	local x = Instance.new("TextButton")
	x.Name = "CloseX"
	x.AutoButtonColor = false
	x.BackgroundTransparency = 1
	x.Text = ""
	x.AnchorPoint = Vector2.new(0.5, 0.5)
	x.Position = UDim2.new(1, -8, 0, 8)
	x.Size = UDim2.fromOffset(60, 60)
	x.ZIndex = card.ZIndex + 10
	x.Parent = card
	local sign = Style.image(x, Icons.RoadStop, WHITE)
	sign.Name = "StopSign"
	sign.Size = UDim2.fromScale(1, 1)
	sign.ZIndex = x.ZIndex
	x:GetPropertyChangedSignal("ZIndex"):Connect(function()
		sign.ZIndex = x.ZIndex
	end)
	press(x)
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
