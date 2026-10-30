--!strict
-- One look for every screen: dark glass panels with a soft top highlight and a fine light edge,
-- a chunky rounded display font for headlines, a clean UI font for the rest, gradient buttons that
-- squash when pressed. Everything visual goes through here so the UI stays consistent.

local TweenService = game:GetService("TweenService")

local Style = {}

Style.colors = table.freeze({
	ink = Color3.fromRGB(12, 12, 20),
	panel = Color3.fromRGB(24, 24, 38),
	panelTop = Color3.fromRGB(44, 44, 66),
	card = Color3.fromRGB(32, 32, 50),
	edge = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(255, 255, 255),
	dim = Color3.fromRGB(168, 170, 196),
	red = Color3.fromRGB(255, 70, 70),
	orange = Color3.fromRGB(255, 140, 50),
	gold = Color3.fromRGB(255, 205, 70),
	money = Color3.fromRGB(110, 240, 130),
	blue = Color3.fromRGB(70, 150, 255),
	purple = Color3.fromRGB(160, 100, 255),
	green = Color3.fromRGB(60, 210, 120),
	grey = Color3.fromRGB(78, 80, 100),
})
local C = Style.colors

Style.fonts = table.freeze({
	display = Font.fromEnum(Enum.Font.FredokaOne),
	bold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	heavy = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold),
	medium = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
})
local F = Style.fonts

-- button looks: top colour, bottom colour
local KINDS: { [string]: { Color3 } } = {
	red = { Color3.fromRGB(255, 96, 86), Color3.fromRGB(214, 38, 52) },
	orange = { Color3.fromRGB(255, 178, 70), Color3.fromRGB(240, 106, 30) },
	gold = { Color3.fromRGB(255, 226, 110), Color3.fromRGB(242, 168, 30) },
	green = { Color3.fromRGB(96, 232, 140), Color3.fromRGB(30, 170, 90) },
	blue = { Color3.fromRGB(100, 176, 255), Color3.fromRGB(44, 100, 230) },
	purple = { Color3.fromRGB(186, 130, 255), Color3.fromRGB(116, 64, 230) },
	dark = { Color3.fromRGB(80, 82, 110), Color3.fromRGB(52, 54, 76) },
}

function Style.corner(obj: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
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
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0.86
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

function Style.gradient(obj: Instance, top: Color3, bottom: Color3): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = obj
	return g
end

-- text with a dark outline so it reads over the world
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
	l.TextColor3 = color or C.text
	l.Parent = parent
	return l
end

function Style.outline(l: TextLabel | TextButton, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = C.ink
	s.Thickness = thickness or 2
	s.Transparency = 0.15
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = l
end

-- a glass panel: a gradient from a lighter top, a fine light edge, rounded corners
function Style.panel(parent: Instance, radius: number?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = transparency or 0.08
	f.BorderSizePixel = 0
	f.Parent = parent
	Style.gradient(f, C.panelTop, C.panel)
	Style.corner(f, radius or 16)
	Style.stroke(f)
	return f
end

-- a small inner card
function Style.card(parent: Instance, radius: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = C.card
	f.BorderSizePixel = 0
	f.Parent = parent
	Style.corner(f, radius or 14)
	Style.stroke(f, nil, 1, 0.9)
	return f
end

local function press(b: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local function to(v: number, t: number)
		TweenService:Create(scale, TweenInfo.new(t, Enum.EasingStyle.Back), { Scale = v }):Play()
	end
	b.MouseEnter:Connect(function()
		to(1.04, 0.15)
	end)
	b.MouseLeave:Connect(function()
		to(1, 0.15)
	end)
	b.MouseButton1Down:Connect(function()
		to(0.92, 0.08)
	end)
	b.MouseButton1Up:Connect(function()
		to(1.04, 0.2)
	end)
end

-- a chunky gradient button with a dark edge and a squash on press. A UIGradient tints a button's text
-- as well as its fill, so the colour lives in BackgroundColor3 and the gradient only darkens toward the
-- bottom (white text stays near white).
local SHADE = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(176, 176, 176))

function Style.button(parent: Instance, text: string, kind: string?, size: number?): TextButton
	local colors = KINDS[kind or "red"] or KINDS.red
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = colors[1]
	b.BorderSizePixel = 0
	b.Text = text
	b.TextSize = size or 17
	b.FontFace = F.display
	b.TextColor3 = C.text
	b.Parent = parent
	Style.corner(b, 12)
	local g = Instance.new("UIGradient")
	g.Name = "Fill"
	g.Color = SHADE
	g.Rotation = 90
	g.Parent = b
	local edge = Style.stroke(b, colors[2]:Lerp(Color3.new(0, 0, 0), 0.45), 2, 0)
	edge.Name = "Edge"
	local ts = Instance.new("UIStroke")
	ts.Name = "TextEdge"
	ts.Color = colors[2]:Lerp(Color3.new(0, 0, 0), 0.6)
	ts.Thickness = 1.5
	ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ts.Parent = b
	press(b)
	return b
end

-- recolour a button made by Style.button
function Style.setKind(b: TextButton, kind: string)
	local colors = KINDS[kind] or KINDS.red
	b.BackgroundColor3 = colors[1]
	local edge = b:FindFirstChild("Edge") :: UIStroke?
	if edge then
		edge.Color = colors[2]:Lerp(Color3.new(0, 0, 0), 0.45)
	end
	local ts = b:FindFirstChild("TextEdge") :: UIStroke?
	if ts then
		ts.Color = colors[2]:Lerp(Color3.new(0, 0, 0), 0.6)
	end
end

-- a thin rounded progress bar; returns the back and the fill
function Style.bar(parent: Instance, color: Color3?): (Frame, Frame)
	local back = Instance.new("Frame")
	back.BackgroundColor3 = C.ink
	back.BackgroundTransparency = 0.3
	back.BorderSizePixel = 0
	back.Parent = parent
	Style.corner(back, 4)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Style.corner(fill, 4)
	local c = color or C.money
	Style.gradient(fill, c:Lerp(Color3.new(1, 1, 1), 0.25), c)
	return back, fill
end

-- a coloured pill tag ("TUTORIAL", "HOURLY")
function Style.pill(parent: Instance, text: string, color: Color3): TextLabel
	local p = Style.label(parent, text, 12, F.heavy, C.ink)
	p.BackgroundColor3 = color
	p.BackgroundTransparency = 0
	p.AutomaticSize = Enum.AutomaticSize.X
	p.Size = UDim2.fromOffset(0, 18)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = p
	Style.corner(p, 9)
	return p
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
