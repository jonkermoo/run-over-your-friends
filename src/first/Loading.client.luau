--!strict
-- The loading cover. Runs from ReplicatedFirst before anything else, so it replaces Roblox's own loading
-- screen at once. It is drawn like real roadside signs on cracked asphalt: a yellow warning diamond (a car
-- creeping up on a friend) with a FRIENDS AHEAD plaque on a punched steel post, the game's name, a green
-- guide sign whose exit tab shows the percent and whose lines carry the status and a rotating tip, and a road
-- along the bottom where a line-painting cart lays fresh double yellow over the faded old line as loading
-- goes on. It covers the HUD and the bare terrain while the map streams in around the spawn plaza, and goes
-- when the character stands on a real floor (or after Config/Loading Timeout, whatever happens first).
-- client/Style can't be required here (it isn't replicated yet), so its colours and fonts are copied.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local shownAt = os.clock()
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local INK = Color3.fromRGB(16, 16, 18)
local ASPHALT = Color3.fromRGB(30, 30, 33)
local PATCH = Color3.fromRGB(25, 25, 27)
local CRACK = Color3.fromRGB(20, 20, 22)
local ROAD = Color3.fromRGB(42, 42, 46)
local EDGE_LINE = Color3.fromRGB(217, 217, 220)
local SIGN_YELLOW = Color3.fromRGB(246, 196, 0)
local TITLE_WHITE = Color3.fromRGB(244, 244, 246)
local GUIDE_GREEN = Color3.fromRGB(0, 105, 62)
local WHITE = Color3.fromRGB(255, 255, 255)
local TIP_WHITE = Color3.fromRGB(233, 243, 238)
local STEEL = Color3.fromRGB(154, 156, 163)
local STEEL_LIT = Color3.fromRGB(201, 203, 209)
local STEEL_DARK = Color3.fromRGB(110, 112, 120)
local BOLT = Color3.fromRGB(184, 186, 192)
local BOLT_EDGE = Color3.fromRGB(85, 87, 94)
local TANK = Color3.fromRGB(207, 209, 214)
local CONE = Color3.fromRGB(255, 106, 0)
local DISPLAY = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local OSWALD = "rbxasset://fonts/families/Oswald.json"
local SIGN_BOLD = Font.new(OSWALD, Enum.FontWeight.SemiBold)
local SIGN_MEDIUM = Font.new(OSWALD, Enum.FontWeight.Medium)
local SIGN_TEXT = Font.new(OSWALD, Enum.FontWeight.Regular)

-- The scene is laid out on a 960-wide board scaled to fit the screen: 540 tall on PCs and tablets, 444 on
-- wide landscape phones, where the sign shrinks and the rest moves up. Road heights are board pixels.
type Layout = {
	height: number,
	signBase: Vector2, -- where the sign post meets the ground
	signScale: number,
	title: Vector2,
	titleSizes: { number },
	guide: Vector2,
	guideWidth: number,
	guideHeight: number,
	road: number,
}
local WIDE: Layout = {
	height = 540,
	signBase = Vector2.new(235, 510),
	signScale = 1,
	title = Vector2.new(440, 40),
	titleSizes = { 74, 62 },
	guide = Vector2.new(440, 214),
	guideWidth = 470,
	guideHeight = 168,
	road = 96,
}
local PHONE: Layout = {
	height = 444,
	signBase = Vector2.new(205, 390),
	signScale = 0.76,
	title = Vector2.new(410, 22),
	titleSizes = { 66, 56 },
	guide = Vector2.new(410, 150),
	guideWidth = 510,
	guideHeight = 150,
	road = 80,
}
local PHONE_ASPECT = 1.9 -- screens at least this much wider than tall use the phone layout
local BOARD_W = 960
local MIN_TEXT = 14 -- the smallest the guide sign's lines shrink to
local MARGIN = Vector2.new(60, 20) -- board pixels kept clear around the board (phone notches, rounded corners)

local gui = Instance.new("ScreenGui")
gui.Name = "Loading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 10000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function box(
	parent: Instance,
	color: Color3,
	w: number,
	h: number,
	x: number,
	y: number
): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Size = UDim2.fromOffset(w, h)
	f.Position = UDim2.fromOffset(x, y)
	f.Parent = parent
	return f
end

local function holder(parent: Instance, w: number, h: number): Frame
	local f = box(parent, INK, w, h, 0, 0)
	f.BackgroundTransparency = 1
	return f
end

local function round(obj: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = if radius < 1 then UDim.new(radius, 0) else UDim.new(0, radius)
	c.Parent = obj
end

local function stroke(obj: GuiObject, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = obj
end

local function text(parent: Instance, s: string, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.Text = s
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local cover = box(gui, ASPHALT, 0, 0, 0, 0)
cover.Size = UDim2.fromScale(1, 1)
cover.Active = true -- swallow taps while it's up

-- worn asphalt: a couple of tar patches and sealed cracks
for _, p in { { 0.58, 0.06, 0.14, 0.09 }, { 0.04, 0.70, 0.09, 0.06 } } do
	local patch = box(cover, PATCH, 0, 0, 0, 0)
	patch.Size = UDim2.fromScale(p[3], p[4])
	patch.Position = UDim2.fromScale(p[1], p[2])
end
for _, c in { { 0.13, 0.13, 0.22, 8 }, { 0.46, 0.47, 0.12, -14 }, { 0.86, 0.11, 0.16, 21 } } do
	local crack = box(cover, CRACK, 0, 3, 0, 0)
	crack.AnchorPoint = Vector2.new(0.5, 0.5)
	crack.Size = UDim2.new(c[3], 0, 0, 3)
	crack.Position = UDim2.fromScale(c[1], c[2])
	crack.Rotation = c[4]
end

local board = holder(cover, BOARD_W, WIDE.height)
board.AnchorPoint = Vector2.new(0.5, 0.5)
board.Position = UDim2.fromScale(0.5, 0.5)
local boardFit = Instance.new("UIScale")
boardFit.Parent = board

---------------------------------------------------------------- the warning sign

-- The sign is drawn in the top half of a holder twice its height, so the holder's centre (where Roblox turns
-- it) is the foot of the post: knocking the sign crooked turns it about its base.
local SIGN_W, SIGN_H = 330, 480
local sign = holder(board, SIGN_W, SIGN_H * 2)
sign.AnchorPoint = Vector2.new(0.5, 0.5)
sign.Rotation = -2
local signFit = Instance.new("UIScale")
signFit.Parent = sign

-- the punched steel post: lit and shaded edges, a hole every 22 px
local post = box(sign, STEEL, 24, 220, 153, 260)
box(post, STEEL_LIT, 4, 220, 0, 0)
box(post, STEEL_DARK, 4, 220, 20, 0)
for i = 0, 9 do
	local hole = box(post, ROAD, 7, 7, 8.5, 6 + i * 22)
	round(hole, 0.5)
end

-- the diamond: reflective yellow, rounded corners, a thin black edge and the black border line inset
local shade = box(sign, INK, 234, 234, 53, 47)
shade.Rotation = 45
shade.BackgroundTransparency = 0.65
round(shade, 16)
local diamond = box(sign, SIGN_YELLOW, 234, 234, 48, 48)
diamond.Rotation = 45
round(diamond, 16)
stroke(diamond, INK, 2)
local inset = holder(diamond, 208, 208)
inset.Position = UDim2.fromOffset(13, 13)
round(inset, 8)
stroke(inset, INK, 6)
for _, y in { 30, 286 } do
	local bolt = box(sign, BOLT, 14, 14, 158, y)
	round(bolt, 0.5)
	stroke(bolt, BOLT_EDGE, 2)
end

-- the symbol: a car on the left, a blocky friend with their arms up on the right
local PICTO = Vector2.new(68, 208) -- the symbol's bottom-left corner on the sign
local car = holder(sign, 96, 52)
car.AnchorPoint = Vector2.new(0, 1)
local carBody = box(car, INK, 96, 20, 0, 21)
round(carBody, 6)
local carCab = box(car, INK, 50, 20, 22, 6)
round(carCab, 7)
carCab.ZIndex = 0 -- under the body, which hides its lower corners
for _, x in { 12, 64 } do
	local wheel = box(car, INK, 22, 22, x, 30)
	round(wheel, 0.5)
	stroke(wheel, SIGN_YELLOW, 3) -- the gap between tyre and body
end
local function carAt(p: number): UDim2
	return UDim2.fromOffset(PICTO.X + p * 44, PICTO.Y)
end
car.Position = carAt(0)

local FRIEND_AT = Vector2.new(PICTO.X + 152, PICTO.Y - 80)
local friend = holder(sign, 40, 80)
friend.Position = UDim2.fromOffset(FRIEND_AT.X, FRIEND_AT.Y)
box(friend, INK, 18, 18, 11, 0)
box(friend, INK, 22, 28, 9, 21)
box(friend, INK, 7, 24, -2, 8).Rotation = -28
box(friend, INK, 7, 24, 35, 8).Rotation = 28
box(friend, INK, 9, 30, 10, 50)
box(friend, INK, 9, 30, 21, 50)

-- the plaque under the diamond
local plaque = box(sign, SIGN_YELLOW, 220, 62, 55, 346)
round(plaque, 8)
stroke(plaque, INK, 2)
local plaqueLine = holder(plaque, 202, 44)
plaqueLine.Position = UDim2.fromOffset(9, 9)
round(plaqueLine, 4)
stroke(plaqueLine, INK, 4)
local plaqueText = text(plaque, "FRIENDS AHEAD", SIGN_BOLD, 29, INK)
plaqueText.Size = UDim2.fromScale(1, 1)
plaqueText.TextXAlignment = Enum.TextXAlignment.Center

---------------------------------------------------------------- title and guide sign

local titleLines = {
	text(board, "RUN OVER", DISPLAY, 74, SIGN_YELLOW),
	text(board, "YOUR FRIENDS!", DISPLAY, 62, TITLE_WHITE),
}

local guide = holder(board, WIDE.guideWidth, 42 + WIDE.guideHeight)
-- the exit tab on top carries the percent; its lower edge hides behind the sign
local tab = box(guide, GUIDE_GREEN, 126, 58, 0, 0)
round(tab, 10)
local tabLine = holder(tab, 112, 58)
tabLine.Position = UDim2.fromOffset(7, 7)
round(tabLine, 6)
stroke(tabLine, WHITE, 3)
local pctLabel = text(tab, "0%", SIGN_MEDIUM, 30, WHITE)
pctLabel.AutoLocalize = false
pctLabel.Size = UDim2.fromOffset(126, 42)
pctLabel.Position = UDim2.fromOffset(0, 2)
pctLabel.TextXAlignment = Enum.TextXAlignment.Center
local green = box(guide, GUIDE_GREEN, WIDE.guideWidth, WIDE.guideHeight, 0, 42)
round(green, 12)
local greenLine = holder(green, 0, 0)
greenLine.Position = UDim2.fromOffset(9, 9)
greenLine.Size = UDim2.new(1, -18, 1, -18)
round(greenLine, 7)
stroke(greenLine, WHITE, 4)
-- an "ahead" arrow: the head is a turned square whose lower half is hidden under a green mask (one solid
-- triangle, no seam), then the shaft drawn over the mask
local arrow = holder(green, 40, 62)
arrow.AnchorPoint = Vector2.new(0, 0.5)
local head = box(arrow, WHITE, 28.3, 28.3, 5.85, 5.85)
head.Rotation = 45
box(arrow, GUIDE_GREEN, 48, 44, -4, 20)
box(arrow, WHITE, 12, 44, 14, 18)
-- Both shrink a step at a time while the shown (translated) text doesn't fit its box. TextScaled can't be
-- used: under the board's UIScale it picks sizes far too small.
local function shrinkToFit(l: TextLabel, max: number)
	local function fit()
		l.TextSize = max
		task.defer(function()
			while not l.TextFits and l.TextSize > MIN_TEXT do
				l.TextSize -= 1
				task.wait()
			end
		end)
	end
	l:GetPropertyChangedSignal("Text"):Connect(fit)
	l:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
end
local status = text(green, "LOADING THE CITY", SIGN_BOLD, 40, WHITE)
shrinkToFit(status, 40)
local tip = text(green, "", SIGN_TEXT, 23, TIP_WHITE)
tip.TextWrapped = true
tip.TextYAlignment = Enum.TextYAlignment.Top
shrinkToFit(tip, 23)

---------------------------------------------------------------- the road

-- Full width along the bottom of the screen, in board pixels: its own UIScale matches the board's.
local road = box(cover, ROAD, 0, WIDE.road, 0, 0)
road.AnchorPoint = Vector2.new(0, 1)
road.Position = UDim2.fromScale(0, 1)
local roadFit = Instance.new("UIScale")
roadFit.Parent = road
local edgeLine = box(road, EDGE_LINE, 0, 5, 0, 12)
edgeLine.Size = UDim2.new(1, 0, 0, 5)
local function doubleYellow(parent: Instance, transparency: number): { Frame }
	local out = {}
	for _, dy in { 0, 9 } do
		local strip = box(parent, SIGN_YELLOW, 0, 5, 0, dy)
		strip.Size = UDim2.new(1, 0, 0, 5)
		strip.BackgroundTransparency = transparency
		table.insert(out, strip)
	end
	return out
end
local oldLine = holder(road, 0, 14)
oldLine.Size = UDim2.new(1, 0, 0, 14)
doubleYellow(oldLine, 0.82)
local freshLine = holder(road, 0, 14)
doubleYellow(freshLine, 0)

-- the striping cart, and two cones behind it
local cart = box(road, SIGN_YELLOW, 52, 30, 0, 0)
round(cart, 4)
box(cart, TANK, 18, 16, 6, -14).ZIndex = 0
for _, x in { 4, 36 } do
	local w = box(cart, INK, 12, 12, x, 24)
	round(w, 0.5)
end
local cones: { Frame } = {}
for _ = 1, 2 do
	local cone = holder(road, 22, 30)
	box(cone, CONE, 9, 10, 6.5, 0)
	box(cone, WHITE, 13, 5, 4.5, 10)
	box(cone, CONE, 16, 11, 3, 15)
	box(cone, CONE, 22, 4, 0, 26)
	table.insert(cones, cone)
end

local layout: Layout = WIDE
local progressShown = 0
local function placeRoad(p: number)
	local lineY = if layout == PHONE then 40 else 48
	freshLine.Size = UDim2.new(p, 0, 0, 14)
	freshLine.Position = UDim2.fromOffset(0, lineY)
	oldLine.Position = UDim2.fromOffset(0, lineY)
	cart.Position = UDim2.new(p, -26, 0, lineY - 18)
	for i, cone in cones do
		cone.Position = UDim2.new(p, -80 - (i - 1) * 70, 0, lineY - 24)
	end
end

local function applyLayout(l: Layout)
	layout = l
	board.Size = UDim2.fromOffset(BOARD_W, l.height)
	sign.Position = UDim2.fromOffset(l.signBase.X, l.signBase.Y)
	signFit.Scale = l.signScale
	local y = l.title.Y
	for i, line in titleLines do
		local size = l.titleSizes[i]
		line.TextSize = size
		line.Size = UDim2.fromOffset(BOARD_W - l.title.X - 20, size)
		line.Position = UDim2.fromOffset(l.title.X, y)
		y += size
	end
	guide.Position = UDim2.fromOffset(l.guide.X, l.guide.Y)
	guide.Size = UDim2.fromOffset(l.guideWidth, 42 + l.guideHeight)
	tab.Position = UDim2.fromOffset(l.guideWidth - 22 - 126, 0)
	green.Size = UDim2.fromOffset(l.guideWidth, l.guideHeight)
	arrow.Position = UDim2.fromOffset(28, l.guideHeight / 2)
	status.Position = UDim2.fromOffset(88, 20)
	status.Size = UDim2.fromOffset(l.guideWidth - 116, 44)
	tip.Position = UDim2.fromOffset(88, 72)
	tip.Size = UDim2.fromOffset(l.guideWidth - 116, l.guideHeight - 86)
	edgeLine.Position = UDim2.fromOffset(0, if l == PHONE then 9 else 12)
	placeRoad(progressShown)
end

local function refit()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local v = cam.ViewportSize
	if v.X <= 0 or v.Y <= 0 then
		return
	end
	local l = if v.X / v.Y >= PHONE_ASPECT then PHONE else WIDE
	if l ~= layout or board.Size.Y.Offset ~= l.height then
		applyLayout(l)
	end
	local s = math.clamp(math.min(v.X / (BOARD_W + MARGIN.X), v.Y / (l.height + MARGIN.Y)), 0.3, 2)
	boardFit.Scale = s
	roadFit.Scale = s
	road.Size = UDim2.fromOffset(v.X / s, l.road)
end
-- the camera this script first sees is replaced once the game loads, so follow whichever one is current
local camWatch: RBXScriptConnection? = nil
local function watchCamera()
	if camWatch then
		camWatch:Disconnect()
	end
	local cam = workspace.CurrentCamera
	camWatch = cam and cam:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
	refit()
end
applyLayout(WIDE)
local camSwap = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

gui.Parent = playerGui

---------------------------------------------------------------- loading

-- Everything after this needs the game's settings, which arrive with the first replication.
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
local configFolder = sharedFolder and sharedFolder:FindFirstChild("Config")
local configModule = configFolder and configFolder:FindFirstChild("Loading")
if not (configModule and configModule:IsA("ModuleScript")) then
	-- a broken build must never leave players stuck behind the cover
	warn("Loading: Config/Loading is missing, dropping the cover")
	gui:Destroy()
	return
end
local Config = require(configModule) :: any

local done = false
local progress = 0
local paint = Instance.new("NumberValue") -- the painted share of the road, eased by tweens
paint.Changed:Connect(function(p: number)
	progressShown = p
	placeRoad(p)
end)
local function reach(step: string)
	local p = Config.Steps[step]
	if done or not p or p <= progress then
		return
	end
	progress = p
	local ease = TweenInfo.new(Config.Advance, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(car, ease, { Position = carAt(p) }):Play()
	TweenService:Create(paint, ease, { Value = p }):Play()
	pctLabel.Text = string.format("%d%%", math.floor(p * 100 + 0.5))
end
reach("start")
reach("game")

-- the tips rotate, starting from a random one
task.spawn(function()
	local i = math.random(1, #Config.Tips)
	while not done do
		tip.Text = Config.Tips[i]
		i = i % #Config.Tips + 1
		task.wait(Config.TipEvery)
	end
end)

-- the spawn is ready when the character is in, the area around it has streamed in, and there is a real
-- floor part under its feet (the plaza, not the terrain under it)
local function waitForSpawn()
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", Config.Timeout)
	if not (root and root:IsA("BasePart")) then
		return
	end
	reach("character")
	pcall(function()
		player:RequestStreamAroundAsync(root.Position, Config.StreamTimeout)
	end)
	reach("streamed")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	while not done do
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -Config.GroundDepth, 0), params)
		if hit and hit.Instance ~= workspace.Terrain then
			break
		end
		task.wait(0.1)
	end
	reach("ground")
end

local ready = false
task.spawn(function()
	waitForSpawn()
	ready = true
end)
while not ready and os.clock() - shownAt < Config.Timeout do
	task.wait(0.1)
end
-- for analytics (client/Track): seconds from client start to spawn-ready, and whether it got there in time
ReplicatedFirst:SetAttribute("LoadReady", ready)
ReplicatedFirst:SetAttribute("LoadSeconds", time())
local left = Config.MinShow - (os.clock() - shownAt)
if left > 0 then
	task.wait(left)
end

-- the finish: the car taps the friend off the sign, the sign is knocked crooked on its post, LET'S GO!
done = true
progress = 1
pctLabel.Text = "100%"
status.Text = "LET'S GO!"
local F = Config.Finish
TweenService:Create(paint, TweenInfo.new(F.hit), { Value = 1 }):Play()
TweenService:Create(car, TweenInfo.new(F.hit, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
	Position = UDim2.fromOffset(PICTO.X + 58, PICTO.Y),
}):Play()
task.wait(F.hit)
local fly = TweenInfo.new(F.fly, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(friend, fly, {
	Position = UDim2.fromOffset(FRIEND_AT.X + 120, FRIEND_AT.Y - 90),
	Rotation = 100,
}):Play()
for _, part in friend:GetChildren() do
	if part:IsA("Frame") then
		TweenService:Create(part, fly, { BackgroundTransparency = 1 }):Play()
	end
end
TweenService
	:Create(sign, TweenInfo.new(F.knock, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Rotation = F.knockAngle,
	})
	:Play()
task.wait(F.hold)

-- fade every piece out together
local fade = TweenInfo.new(Config.Fade, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
for _, d in gui:GetDescendants() do
	if d:IsA("Frame") and d.BackgroundTransparency < 1 then
		TweenService:Create(d, fade, { BackgroundTransparency = 1 }):Play()
	elseif d:IsA("TextLabel") then
		TweenService:Create(d, fade, { TextTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, fade, { Transparency = 1 }):Play()
	end
end
task.wait(Config.Fade)
camSwap:Disconnect()
if camWatch then
	camWatch:Disconnect()
end
gui:Destroy()
