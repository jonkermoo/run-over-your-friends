--!strict
-- One look for every screen, "Road Paint": asphalt-black plates with square corners and a hard offset
-- shadow, road-yellow and hot accent colours, Luckiest Guy for headings, numbers and shouts, and heavy
-- italic Montserrat for small text. Dashed lane lines divide things. No rounded corners, glows or soft
-- gradients. Everything visual goes through here so the UI stays consistent.

local TweenService = game:GetService("TweenService")

local Style = {}

Style.colors = table.freeze({
	ink = Color3.fromRGB(16, 16, 18),
	panel = Color3.fromRGB(23, 23, 26), -- asphalt
	panelTop = Color3.fromRGB(23, 23, 26),
	card = Color3.fromRGB(36, 36, 40), -- lighter asphalt for cards inside a panel
	edge = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(255, 255, 255),
	dim = Color3.fromRGB(188, 188, 196),
	yellow = Color3.fromRGB(255, 208, 0), -- road paint
	red = Color3.fromRGB(255, 46, 46),
	pink = Color3.fromRGB(255, 46, 154),
	orange = Color3.fromRGB(255, 122, 0),
	gold = Color3.fromRGB(255, 208, 0),
	money = Color3.fromRGB(43, 255, 106),
	blue = Color3.fromRGB(31, 107, 255),
	purple = Color3.fromRGB(150, 70, 255),
	green = Color3.fromRGB(43, 220, 90),
	grey = Color3.fromRGB(70, 70, 78),
})
local C = Style.colors

local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"
Style.fonts = table.freeze({
	display = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
	heavy = Font.new(MONTSERRAT, Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
	bold = Font.new(MONTSERRAT, Enum.FontWeight.ExtraBold, Enum.FontStyle.Italic),
	medium = Font.new(MONTSERRAT, Enum.FontWeight.Bold),
})
local F = Style.fonts

Style.SHADOW = 5 -- hard shadow offset, px

-- button looks: fill, text colour
local KINDS: { [string]: { Color3 } } = {
	red = { C.red, C.text },
	orange = { C.orange, C.ink },
	gold = { C.yellow, C.ink },
	green = { C.money, C.ink },
	blue = { C.blue, C.text },
	purple = { C.pink, C.text },
	dark = { C.grey, C.text },
}

-- kept so older callers still work: corners are square in this style
function Style.corner(obj: Instance, _radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 0)
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
	s.LineJoinMode = Enum.LineJoinMode.Miter
	s.Parent = obj
	return s
end

-- flat colour: gradients are gone from this style, the bottom colour is ignored
function Style.gradient(obj: Instance, top: Color3, _bottom: Color3): UIGradient
	if obj:IsA("GuiObject") then
		obj.BackgroundColor3 = top
	end
	local g = Instance.new("UIGradient")
	g.Parent = obj
	return g
end

-- a hard offset shadow, drawn as an L of two strips outside the right and bottom edges (children
-- always draw over their parent, so the shadow can't sit behind it; outside the edges it doesn't
-- have to). Works when the object sits in a layout, but a UIListLayout/UIGridLayout INSIDE the object
-- would lay the shadow out too: put such a layout in an inner frame. Never give a shadowed object
-- AutomaticSize: the strips outside its edges make it grow without end. Size it from its content
-- instead (Style.fitText, or follow an inner frame's AbsoluteSize).
function Style.shadow(obj: GuiObject, color: Color3?, offset: number?): Frame
	local o = offset or Style.SHADOW
	local holder = Instance.new("Frame")
	holder.Name = "Shadow"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = obj
	local right = Instance.new("Frame")
	right.BackgroundColor3 = color or C.ink
	right.BorderSizePixel = 0
	right.Position = UDim2.new(1, 0, 0, o)
	right.Size = UDim2.new(0, o, 1, 0)
	right.Parent = holder
	local bottom = right:Clone()
	bottom.Position = UDim2.new(0, o, 1, 0)
	bottom.Size = UDim2.new(1, -o, 0, o)
	bottom.Parent = holder
	return holder
end

-- recolour a shadow made by Style.shadow
function Style.setShadow(obj: GuiObject, color: Color3)
	local holder = obj:FindFirstChild("Shadow")
	if holder then
		for _, f in holder:GetChildren() do
			(f :: Frame).BackgroundColor3 = color
		end
	end
end

-- a dashed lane line along the top or bottom edge (or a vertical one with vertical = true)
function Style.dashes(
	parent: Instance,
	color: Color3?,
	vertical: boolean?,
	thickness: number?
): Frame
	local t = thickness or 3
	local line = Instance.new("Frame")
	line.Name = "Dashes"
	line.BackgroundTransparency = 1
	line.ClipsDescendants = true
	line.Size = if vertical then UDim2.new(0, t, 1, 0) else UDim2.new(1, 0, 0, t)
	line.Parent = parent
	local list = Instance.new("UIListLayout")
	list.FillDirection = if vertical
		then Enum.FillDirection.Vertical
		else Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 7)
	list.Parent = line
	for _ = 1, 60 do
		local dash = Instance.new("Frame")
		dash.BackgroundColor3 = color or C.yellow
		dash.BorderSizePixel = 0
		dash.Size = if vertical then UDim2.fromOffset(t, 12) else UDim2.fromOffset(16, t)
		dash.Parent = line
	end
	return line
end

-- text: white heavy italic by default
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

-- size a label to its text plus padding, and keep it that way when the text changes
function Style.fitText(l: TextLabel | TextButton, padX: number, padY: number)
	local function fit()
		l.Size = UDim2.fromOffset(l.TextBounds.X + padX * 2, l.TextBounds.Y + padY * 2)
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
	s.LineJoinMode = Enum.LineJoinMode.Miter
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = l
end

-- an asphalt plate: flat black, square, hard shadow. radius is ignored (kept for older callers).
function Style.panel(parent: Instance, _radius: number?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = C.panel
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	Style.shadow(f)
	return f
end

-- a card inside a panel: lighter asphalt, no shadow
function Style.card(parent: Instance, _radius: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = C.card
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function press(b: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local function to(v: number, t: number)
		TweenService:Create(scale, TweenInfo.new(t, Enum.EasingStyle.Back), { Scale = v }):Play()
	end
	b.MouseEnter:Connect(function()
		to(1.05, 0.12)
	end)
	b.MouseLeave:Connect(function()
		to(1, 0.12)
	end)
	b.MouseButton1Down:Connect(function()
		to(0.9, 0.06)
	end)
	b.MouseButton1Up:Connect(function()
		to(1.05, 0.18)
	end)
end

-- a flat paint-coloured button in Luckiest Guy with an ink edge and a hard shadow; squashes on press
function Style.button(parent: Instance, text: string, kind: string?, size: number?): TextButton
	local look = KINDS[kind or "red"] or KINDS.red
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = look[1]
	b.BorderSizePixel = 0
	b.Text = text
	b.TextSize = size or 17
	b.FontFace = F.display
	b.TextColor3 = look[2]
	b.Parent = parent
	local edge = Style.stroke(b, C.ink, 2, 0)
	edge.Name = "Edge"
	Style.shadow(b, C.ink, 4)
	press(b)
	return b
end

-- recolour a button made by Style.button
function Style.setKind(b: TextButton, kind: string)
	local look = KINDS[kind] or KINDS.red
	b.BackgroundColor3 = look[1]
	b.TextColor3 = look[2]
end

-- a flat progress bar: dark track, paint fill; returns the back and the fill
function Style.bar(parent: Instance, color: Color3?): (Frame, Frame)
	local back = Instance.new("Frame")
	back.BackgroundColor3 = C.ink
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color or C.money
	fill.BorderSizePixel = 0
	fill.Parent = back
	return back, fill
end

-- a square paint tag ("TUTORIAL", "HOURLY")
function Style.pill(parent: Instance, text: string, color: Color3): TextLabel
	local p = Style.label(parent, text, 12, F.heavy, C.ink)
	p.BackgroundColor3 = color
	p.BackgroundTransparency = 0
	p.AutomaticSize = Enum.AutomaticSize.X
	p.Size = UDim2.fromOffset(0, 18)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 7)
	pad.PaddingRight = UDim.new(0, 9)
	pad.Parent = p
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
