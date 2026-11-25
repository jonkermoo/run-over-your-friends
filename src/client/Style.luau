--!strict
-- One look for every screen, "Street Sign": every panel is a road sign (highway green with a white inner
-- line, a dark edge and corner rivets; each menu in its own sign colour), buttons are sign plates (yellow
-- for go, white for no) with a black inner line, and type is heavy Builder Sans. Panels, buttons, cards,
-- bars and the tour bubble are images drawn outside the game (tools/ui/ui_kit.py, Config/Icons Kit*),
-- 9-sliced, with live text on top. Everything visual goes through here so the UI stays consistent.

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
	red = {
		face = C.red,
		edge = Color3.fromRGB(110, 15, 18),
		line = C.edge,
		text = C.text,
		dim = Color3.fromRGB(255, 214, 214),
		money = C.money,
	},
	purple = {
		face = Color3.fromRGB(122, 62, 196),
		edge = Color3.fromRGB(60, 24, 104),
		line = C.edge,
		text = C.text,
		dim = Color3.fromRGB(226, 211, 250),
		money = C.money,
	},
	grey = {
		face = Color3.fromRGB(128, 134, 140),
		edge = Color3.fromRGB(52, 56, 60),
		line = C.edge,
		text = C.text,
		dim = Color3.fromRGB(226, 230, 233),
		money = C.money,
	},
	yellow = {
		face = C.yellow,
		edge = Color3.fromRGB(143, 106, 0),
		line = C.ink,
		text = C.ink,
		dim = Color3.fromRGB(90, 66, 0),
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

-- button looks: face colour, and whether the words and inner line are black (else white)
local KINDS: { [string]: { any } } = {
	red = { C.red, false },
	orange = { C.orange, true },
	gold = { C.yellow, true }, -- go
	green = { C.yellow, true }, -- go (buttons are never green in this style)
	blue = { C.blue, false },
	purple = { C.pink, false },
	grey = { Color3.fromRGB(128, 134, 140), false },
	ink = { C.card, false }, -- a tab that isn't open
	dark = { C.white, true }, -- no / back / close
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

-- flat colour (the shading is in the kit images); the bottom colour is ignored
function Style.gradient(obj: Instance, top: Color3, _bottom: Color3): UIGradient
	if obj:IsA("GuiObject") then
		obj.BackgroundColor3 = top
	end
	local g = Instance.new("UIGradient")
	g.Parent = obj
	return g
end

-- keep a piece's own images and words drawn in the right order in either ZIndex mode. `layer` (0 face,
-- 1 trim, 2 bolts...) puts a backing image under everything else in the piece: in a ScreenGui that sorts
-- siblings, below every sibling (any ZIndex the caller gave its labels); in one that sorts globally, on the
-- piece's own ZIndex, drawn before the labels made after it. Without a layer it takes the piece's ZIndex.
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

---------------------------------------------------------------- the UI kit's images

-- 9-slice sets drawn outside the game (tools/ui/ui_kit.py) at 2x: a white face the game tints, trims that keep
-- their colours (light = white inner line, dark = black), the slice insets in image px (left, top, right,
-- bottom) and the image's size
type Kit = { face: number, light: number, dark: number, slice: { number }, w: number, h: number }
local KIT: { [string]: Kit } = {
	panel = {
		face = Icons.KitPanelFace,
		light = Icons.KitPanelTrimLight,
		dark = Icons.KitPanelTrimDark,
		slice = { 40, 40, 40, 40 },
		w = 128,
		h = 128,
	},
	plate = {
		face = Icons.KitPlateFace,
		light = Icons.KitPlateTrimLight,
		dark = Icons.KitPlateTrimDark,
		slice = { 28, 28, 28, 28 },
		w = 96,
		h = 96,
	},
	button = {
		face = Icons.KitButtonFace,
		light = Icons.KitButtonTrimLight,
		dark = Icons.KitButtonTrimDark,
		slice = { 30, 30, 30, 38 },
		w = 96,
		h = 96,
	},
	inset = {
		face = Icons.KitInset,
		light = 0,
		dark = 0,
		slice = { 20, 20, 20, 20 },
		w = 64,
		h = 64,
	},
	fill = {
		face = Icons.KitBarFill,
		light = 0,
		dark = 0,
		slice = { 10, 10, 10, 10 },
		w = 32,
		h = 32,
	},
	bubble = {
		face = Icons.KitBubble,
		light = 0,
		dark = 0,
		slice = { 64, 96, 64, 52 },
		w = 200,
		h = 180,
	},
}
local HALF = 0.5 -- the images are drawn at twice layout size
local BUTTON_LIFT = 2 -- a button's words sit this far up, over its face rather than its drawn-in depth

-- an image filling the whole object even when the object has a UIPadding (for its words)
local function unpad(obj: GuiObject, img: GuiObject)
	local function fit()
		local pad = obj:FindFirstChildOfClass("UIPadding")
		if not pad then
			img.Position = UDim2.new()
			img.Size = UDim2.fromScale(1, 1)
			return
		end
		local l, r = pad.PaddingLeft.Offset, pad.PaddingRight.Offset
		local t, b = pad.PaddingTop.Offset, pad.PaddingBottom.Offset
		img.Position = UDim2.fromOffset(-l, -t)
		img.Size = UDim2.new(1, l + r, 1, t + b)
	end
	obj.ChildAdded:Connect(function(c)
		if c:IsA("UIPadding") then
			fit()
		end
	end)
	fit()
end

local function sliced(obj: GuiObject, name: string, id: number, kit: Kit): ImageLabel
	local img = obj:FindFirstChild(name) :: ImageLabel?
	if not img then
		local new = Instance.new("ImageLabel")
		new.Name = name
		new.BackgroundTransparency = 1
		new.ScaleType = Enum.ScaleType.Slice
		new.SliceScale = HALF
		new.Parent = obj
		unpad(obj, new)
		follow(obj, new, if name == "Face" then 0 else 1)
		img = new
	end
	local i = img :: ImageLabel
	local s = kit.slice
	i.Image = if id ~= 0 then `rbxassetid://{id}` else ""
	i.SliceCenter = Rect.new(s[1], s[2], kit.w - s[3], kit.h - s[4])
	return i
end

-- small pieces draw their corners smaller, so the slices never overlap
local function fitSlices(obj: GuiObject)
	local function fit()
		local k = currentScale
		local w, h = obj.AbsoluteSize.X / k, obj.AbsoluteSize.Y / k
		for _, c in obj:GetChildren() do
			local kit = if c:IsA("ImageLabel") then KIT[c:GetAttribute("Kit") :: string] else nil
			if kit then
				local s = kit.slice
				local scale = math.max(0.05, math.min(HALF, w / (s[1] + s[3]), h / (s[2] + s[4])));
				(c :: ImageLabel).SliceScale = scale
			end
		end
	end
	obj:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	obj.ChildAdded:Connect(fit)
	task.defer(fit)
end

-- the object's own background gives way to the images: BackgroundColor3 tints the face and
-- BackgroundTransparency fades it, so code that recolours a sign or button keeps working
local function adopt(obj: GuiObject, face: ImageLabel, tinted: boolean)
	if obj:GetAttribute("Skinned") then
		return
	end
	obj:SetAttribute("Skinned", true)
	local busy = false
	local function color()
		if tinted then
			face.ImageColor3 = obj.BackgroundColor3
		end
	end
	local function fade()
		if busy then
			return
		end
		busy = true
		face.ImageTransparency = obj.BackgroundTransparency
		obj.BackgroundTransparency = 1
		busy = false
	end
	obj:GetPropertyChangedSignal("BackgroundColor3"):Connect(color)
	obj:GetPropertyChangedSignal("BackgroundTransparency"):Connect(fade)
	color()
	fade()
end

-- put a kit set on any frame or button: the tinted face and the trim (light or dark inner line)
local function skin(obj: GuiObject, kitName: string, tint: Color3?, dark: boolean?)
	local kit = KIT[kitName]
	obj.BorderSizePixel = 0
	local face = sliced(obj, "Face", kit.face, kit)
	face:SetAttribute("Kit", kitName)
	if kit.light ~= 0 then
		local trim = sliced(obj, "Trim", if dark then kit.dark else kit.light, kit)
		trim:SetAttribute("Kit", kitName)
	end
	if not obj:GetAttribute("Skinned") then
		fitSlices(obj)
	end
	if tint then
		obj.BackgroundColor3 = tint
	end
	adopt(obj, face, kit.light ~= 0 or kitName == "fill")
	if tint then
		face.ImageColor3 = tint
	end
end

-- a text label or button's words drawn by a child over its kit images (an object's own text draws under its
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
	-- a size cap or outline put on the object applies to the words
	local function take(c: Instance)
		local stroke = c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual
		if c:IsA("UITextSizeConstraint") or stroke then
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

-- a highlight ring round a sign (an event about to end, a car you can buy): pass nil to take it off
function Style.ring(obj: GuiObject, color: Color3?)
	local ring = obj:FindFirstChild("SignEdge") :: UIStroke?
	if not ring then
		local r = Style.stroke(obj, C.yellow, 3, 1)
		r.Name = "SignEdge"
		ring = r
	end
	local r = ring :: UIStroke
	r.Color = color or C.yellow
	r.Transparency = if color then 0 else 1
end

---------------------------------------------------------------- signs, cards and buttons

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

-- Turn any frame or button into a sign drawn from the kit: a face in the kind's colour (green, blue, red,
-- brown, orange, white, yellow, purple, grey) with its dark edge, white (or black) inner line and, on big
-- ones, a rivet in each corner. Calling it again repaints it in another kind. Labels made with Style.label
-- inside it afterwards take the kind's text colours.
function Style.sign(obj: GuiObject, kind: string?, small: boolean?)
	local k = kind or "green"
	local sign = SIGNS[k] or SIGNS.green
	obj:SetAttribute("Sign", k)
	Style.corner(obj, if small then 8 else 11)
	local dark = sign.line == C.ink
	if small then
		skin(obj, "plate", sign.face, dark)
	else
		skin(obj, "panel", sign.face, dark)
	end
	if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and not obj:FindFirstChild("Words") then
		words(obj :: any, 0)
	end
	if small then
		return
	end
	-- the riveted trim only on signs big enough to carry it
	if not obj:GetAttribute("Sized") then
		obj:SetAttribute("Sized", true)
		local function check()
			local s = currentScale
			local big = obj.AbsoluteSize.X / s >= 150 and obj.AbsoluteSize.Y / s >= 90
			local kit = if big then KIT.panel else KIT.plate
			local name = if big then "panel" else "plate"
			local isDark = (SIGNS[obj:GetAttribute("Sign") :: string] or SIGNS.green).line == C.ink
			local face = obj:FindFirstChild("Face") :: ImageLabel
			if face and face:GetAttribute("Kit") ~= name then
				sliced(obj, "Face", kit.face, kit):SetAttribute("Kit", name)
				sliced(obj, "Trim", if isDark then kit.dark else kit.light, kit):SetAttribute(
					"Kit",
					name
				)
			end
		end
		obj:GetPropertyChangedSignal("AbsoluteSize"):Connect(check)
		task.defer(check)
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

-- the garage tour's callout: a white body under a yellow title band, its tail at the bottom left (the
-- bottom 13 layout px are the tail). Labels inside it take black words.
function Style.bubble(parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Parent = parent
	f:SetAttribute("Sign", "white")
	skin(f, "bubble")
	return f
end
Style.BUBBLE_HEAD = 44 -- the bubble's title band, layout px
Style.BUBBLE_TAIL = 13

-- a recessed box inside a sign: the sign's colour darkened, with a faint light rim
function Style.card(parent: Instance, _radius: number?): Frame
	local f = Instance.new("Frame")
	f.Parent = parent
	Style.corner(f, 8)
	skin(f, "inset")
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
	local ink = if dark then C.ink else C.text
	b.BackgroundColor3 = look[1]
	b.TextColor3 = ink
	skin(b, "button", look[1], dark)
	if not b:FindFirstChild("Words") then
		words(b, BUTTON_LIFT)
	end
	local arrow = b:FindFirstChild("ExitArrow") :: ImageLabel?
	if arrow then
		arrow.ImageColor3 = ink
	end
end

-- a sign-plate button drawn from the kit: yellow for go, white for no (and blue, red, orange, grey), a black
-- or white inner line, its depth drawn in; it sinks when pressed. Big ones carry two mounting bolts and an
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
	paintButton(b, look)
	-- bolts and the arrow show only on big plates with room beside the words
	local bolts = Instance.new("Frame")
	bolts.Name = "Bolts"
	bolts.BackgroundTransparency = 1
	bolts.Size = UDim2.fromScale(1, 1)
	bolts.Visible = false
	bolts.Parent = b
	for _, at in { { 0, 13 }, { 1, -13 } } do
		local bolt = Style.image(bolts, Icons.KitBolt, Color3.new(1, 1, 1))
		bolt.AnchorPoint = Vector2.new(0.5, 0.5)
		bolt.Position = UDim2.new(at[1], at[2], 0.5, -BUTTON_LIFT)
		bolt.Size = UDim2.fromOffset(12, 12)
	end
	local arrow = Style.image(b, Icons.KitExitArrow, b.TextColor3)
	arrow.Name = "ExitArrow"
	arrow.AnchorPoint = Vector2.new(0, 0.5)
	arrow.Size = UDim2.fromOffset(16, 16)
	arrow.Visible = false
	follow(b, bolts, 2)
	follow(b, arrow, 2)
	local function decorate()
		local s = currentScale
		local w, h = b.AbsoluteSize.X / s, b.AbsoluteSize.Y / s
		local tw = b.TextBounds.X / s
		local big = w >= 150 and h >= 44
		bolts.Visible = big
		arrow.Visible = big and w - tw >= 96
		arrow.Position = UDim2.new(0.5, tw / 2 + 9, 0.5, -BUTTON_LIFT)
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

-- a progress bar: a recessed track and a shaded fill (yellow unless told); returns the back and the fill
function Style.bar(parent: Instance, color: Color3?): (Frame, Frame)
	local back = Instance.new("Frame")
	back.ClipsDescendants = true
	back.Parent = parent
	skin(back, "inset")
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = back
	skin(fill, "fill", color or C.yellow)
	return back, fill
end

-- kept for older callers: bars are solid in this style
function Style.laneGaps(_back: Frame, _behind: Color3) end

-- a yellow-and-black construction band along the top of a card, just inside its edge (`width` is kept for
-- older callers)
function Style.hazard(parent: Instance, _width: number, height: number): ImageLabel
	local band = Instance.new("ImageLabel")
	band.Name = "Hazard"
	band.BackgroundTransparency = 1
	band.Image = `rbxassetid://{Icons.KitHazard}`
	band.ScaleType = Enum.ScaleType.Tile
	band.TileSize = UDim2.fromOffset(height * 2, height)
	band.Position = UDim2.fromOffset(4, 4)
	band.Size = UDim2.new(1, -8, 0, height)
	band.Parent = parent
	Style.corner(band, 8)
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

-- a small sign tag ("TUTORIAL", "HOURLY"): a little plate with a thin inner line; black words on light
-- colours, white on dark ones
function Style.pill(parent: Instance, text: string, color: Color3): TextLabel
	local light = color.R * 0.3 + color.G * 0.59 + color.B * 0.11 > 0.55
	local ink = if light then C.ink else C.text
	local p = Instance.new("TextLabel")
	p.Text = text
	p.TextSize = 12
	p.FontFace = F.heavy
	p.TextColor3 = ink
	p.Size = UDim2.fromOffset(0, 20)
	p.Parent = parent
	skin(p, "button", color, light)
	-- as wide as its words plus a margin (a UIPadding would pull the plate's images in too)
	local function fit()
		p.Size = UDim2.new(0, p.TextBounds.X / currentScale + 16, p.Size.Y.Scale, p.Size.Y.Offset)
	end
	p:GetPropertyChangedSignal("TextBounds"):Connect(fit)
	fit()
	words(p, 1)
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

-- the X in a card's top right corner: every pop-up has one (a white sign plate), clear of the card's edge
function Style.closeX(card: GuiObject, onClose: () -> ()): TextButton
	local x = Style.button(card, "X", "dark", 22)
	x.Name = "CloseX"
	x.AnchorPoint = Vector2.new(1, 0)
	-- under the hazard band when the card has one
	x.Position = UDim2.new(1, -12, 0, if card:FindFirstChild("Hazard") then 24 else 12)
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
