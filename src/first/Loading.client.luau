--!strict
-- The loading cover. Runs from ReplicatedFirst before anything else, so it replaces Roblox's own loading
-- screen at once: a full screen in the "Road Paint" look (client/Style: asphalt, road yellow, hot pink,
-- Luckiest Guy) with the title, a little car driving along a progress road towards a blocky friend, and a
-- rotating tip. It covers the HUD and the bare terrain while the map streams in around the spawn plaza,
-- and goes when the character stands on a real floor (or after Config/Loading Timeout, whatever happens).
-- client/Style can't be required here (it isn't replicated yet), so the few colours it needs are copied.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local shownAt = os.clock()
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local INK = Color3.fromRGB(16, 16, 18)
local ASPHALT = Color3.fromRGB(23, 23, 26)
local ROAD = Color3.fromRGB(46, 46, 52)
local WHITE = Color3.fromRGB(255, 255, 255)
local DIM = Color3.fromRGB(188, 188, 196)
local YELLOW = Color3.fromRGB(255, 208, 0)
local PINK = Color3.fromRGB(255, 46, 154)
local RED = Color3.fromRGB(255, 46, 46)
local BLUE = Color3.fromRGB(31, 107, 255)
local GLASS = Color3.fromRGB(150, 220, 255)
local SKIN = Color3.fromRGB(245, 205, 48)
local LEGS = Color3.fromRGB(75, 151, 75)
local DISPLAY = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local HEAVY = Font.new(
	"rbxasset://fonts/families/Montserrat.json",
	Enum.FontWeight.Heavy,
	Enum.FontStyle.Italic
)

-- the scene is laid out on a 960 x 600 board, scaled to fit the screen
local BOARD_W, BOARD_H = 960, 600

local gui = Instance.new("ScreenGui")
gui.Name = "Loading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 10000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function box(parent: Instance, color: Color3, size: UDim2, pos: UDim2, z: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = pos
	f.ZIndex = z or 1
	f.Parent = parent
	return f
end

local function text(parent: Instance, s: string, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.Text = s
	l.TextSize = size
	l.TextColor3 = color
	l.Parent = parent
	return l
end

local function stroke(obj: Instance, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = thickness
	s.LineJoinMode = Enum.LineJoinMode.Miter
	s.Parent = obj
end

local cover = box(gui, ASPHALT, UDim2.fromScale(1, 1), UDim2.new(), 1)
cover.Active = true -- swallow taps while it's up

-- a yellow road-paint band along the top and bottom edges, with dashes, so the screen reads as a road sign
for _, top in { true, false } do
	local band =
		box(cover, YELLOW, UDim2.new(1, 0, 0, 14), UDim2.fromScale(0, if top then 0 else 1), 2)
	band.AnchorPoint = Vector2.new(0, if top then 0 else 1)
end

local board = box(cover, ASPHALT, UDim2.fromOffset(BOARD_W, BOARD_H), UDim2.fromScale(0.5, 0.5), 2)
board.AnchorPoint = Vector2.new(0.5, 0.5)
board.BackgroundTransparency = 1
local fit = Instance.new("UIScale")
fit.Parent = board

local function refit()
	local cam = workspace.CurrentCamera
	if cam then
		local v = cam.ViewportSize
		fit.Scale = math.clamp(math.min(v.X / (BOARD_W + 40), v.Y / (BOARD_H + 40)), 0.3, 1.6)
	end
end
refit()
local cam = workspace.CurrentCamera
local camWatch = cam and cam:GetPropertyChangedSignal("ViewportSize"):Connect(refit)

-- title: two lines, yellow then pink, tilted a touch, each with a hard ink shadow
local title = Instance.new("Frame")
title.BackgroundTransparency = 1
title.Size = UDim2.fromOffset(BOARD_W, 230)
title.Position = UDim2.fromOffset(0, 20)
title.Rotation = -3
title.ZIndex = 3
title.Parent = board
local function titleLine(s: string, y: number, size: number, color: Color3)
	for _, shadow in { true, false } do
		local l = text(title, s, DISPLAY, size, if shadow then INK else color)
		l.Size = UDim2.new(1, 0, 0, size)
		l.Position = UDim2.fromOffset(if shadow then 7 else 0, y + (if shadow then 7 else 0))
		l.ZIndex = if shadow then 3 else 4
		if not shadow then
			stroke(l, 4)
		end
	end
end
titleLine("RUN OVER", 10, 96, YELLOW)
titleLine("YOUR FRIENDS!", 108, 104, PINK)

-- the progress road: dark asphalt, yellow dashes down the middle, a pink skid trail behind the car
local ROAD_X, ROAD_Y, ROAD_W, ROAD_H = 40, 400, BOARD_W - 80, 64
local road = box(board, ROAD, UDim2.fromOffset(ROAD_W, ROAD_H), UDim2.fromOffset(ROAD_X, ROAD_Y), 3)
stroke(road, 4)
for i = 0, 16 do
	box(road, YELLOW, UDim2.fromOffset(28, 6), UDim2.fromOffset(16 + i * 50, ROAD_H / 2 - 3), 4)
end
local trail = box(road, PINK, UDim2.fromOffset(0, 10), UDim2.fromOffset(0, ROAD_H - 10), 5)

-- the friend waiting at the end of the road: a blocky avatar, yellow head, blue shirt, green legs
local FRIEND_X = ROAD_X + ROAD_W - 70
local friend = Instance.new("Frame")
friend.BackgroundTransparency = 1
friend.Size = UDim2.fromOffset(44, 96)
friend.AnchorPoint = Vector2.new(0.5, 1)
friend.Position = UDim2.fromOffset(FRIEND_X, ROAD_Y + 26)
friend.ZIndex = 6
friend.Parent = board
stroke(box(friend, SKIN, UDim2.fromOffset(26, 26), UDim2.fromOffset(9, 0), 7), 3)
stroke(box(friend, BLUE, UDim2.fromOffset(32, 34), UDim2.fromOffset(6, 28), 7), 3)
stroke(box(friend, SKIN, UDim2.fromOffset(9, 30), UDim2.fromOffset(-5, 28), 6), 3)
stroke(box(friend, SKIN, UDim2.fromOffset(9, 30), UDim2.fromOffset(40, 28), 6), 3)
stroke(box(friend, LEGS, UDim2.fromOffset(14, 34), UDim2.fromOffset(7, 62), 6), 3)
stroke(box(friend, LEGS, UDim2.fromOffset(14, 34), UDim2.fromOffset(23, 62), 6), 3)
local face = text(friend, ":O", DISPLAY, 16, INK)
face.Size = UDim2.fromOffset(26, 26)
face.Position = UDim2.fromOffset(9, 2)
face.Rotation = 90
face.ZIndex = 8

-- the car: a red cartoon hatchback, wheels and all; it drives along the road as loading goes on
local CAR_W, CAR_H = 150, 84
local car = Instance.new("Frame")
car.BackgroundTransparency = 1
car.Size = UDim2.fromOffset(CAR_W, CAR_H)
car.AnchorPoint = Vector2.new(0, 1)
car.ZIndex = 8
car.Parent = board
stroke(box(car, RED, UDim2.fromOffset(CAR_W, 40), UDim2.fromOffset(0, 26), 9), 4)
stroke(box(car, RED, UDim2.fromOffset(84, 32), UDim2.fromOffset(24, 0), 9), 4)
box(car, GLASS, UDim2.fromOffset(34, 22), UDim2.fromOffset(32, 6), 10)
box(car, GLASS, UDim2.fromOffset(30, 22), UDim2.fromOffset(72, 6), 10)
box(car, YELLOW, UDim2.fromOffset(14, 10), UDim2.fromOffset(CAR_W - 16, 34), 10) -- headlight
local wheels: { Frame } = {}
for _, x in { 20, CAR_W - 52 } do
	local w = box(car, INK, UDim2.fromOffset(34, 34), UDim2.fromOffset(x, CAR_H - 34), 11)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = w
	local hub = box(w, DIM, UDim2.fromOffset(12, 12), UDim2.fromOffset(11, 11), 12)
	hub.Rotation = 45
	table.insert(wheels, w)
end
local CAR_START = ROAD_X + 8
local CAR_END = FRIEND_X - 22 - CAR_W -- the bumper just touching the friend
local function carAt(p: number): UDim2
	return UDim2.fromOffset(CAR_START + (CAR_END - CAR_START) * p, ROAD_Y + 22)
end
car.Position = carAt(0)

local bonk = text(board, "BONK!", DISPLAY, 70, YELLOW)
bonk.Size = UDim2.fromOffset(260, 80)
bonk.AnchorPoint = Vector2.new(0.5, 0.5)
bonk.Position = UDim2.fromOffset(FRIEND_X - 40, ROAD_Y - 120)
bonk.Rotation = 10
bonk.ZIndex = 12
bonk.Visible = false
stroke(bonk, 5)

local status = text(board, "LOADING THE CITY...", DISPLAY, 34, WHITE)
status.Size = UDim2.fromOffset(BOARD_W, 40)
status.Position = UDim2.fromOffset(0, 286)
status.ZIndex = 4
stroke(status, 3)

local tip = text(board, "", HEAVY, 26, DIM)
tip.Size = UDim2.fromOffset(BOARD_W - 80, 40)
tip.Position = UDim2.fromOffset(40, 500)
tip.TextWrapped = true
tip.ZIndex = 4

gui.Parent = playerGui

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
local function reach(step: string)
	local p = Config.Steps[step]
	if done or not p or p <= progress then
		return
	end
	progress = p
	TweenService:Create(
		car,
		TweenInfo.new(Config.CarDrive, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = carAt(p) }
	):Play()
	TweenService:Create(
		trail,
		TweenInfo.new(Config.CarDrive, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(carAt(p).X.Offset - ROAD_X + 20, 10) }
	):Play()
	status.Text = string.format("LOADING THE CITY... %d%%", math.floor(p * 100 + 0.5))
end
reach("start")
reach("game")

-- the tips rotate, starting from a random one; the wheels spin and the car bobs while it waits
task.spawn(function()
	local i = math.random(1, #Config.Tips)
	while not done do
		tip.Text = Config.Tips[i]
		i = i % #Config.Tips + 1
		task.wait(Config.TipEvery)
	end
end)
task.spawn(function()
	local t = 0
	while not done do
		t += task.wait()
		for _, w in wheels do
			w.Rotation = (t * 360) % 360
		end
		car.Rotation = math.sin(t * 14) * 1.5
		friend.Rotation = math.sin(t * 5) * 4
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
local left = Config.MinShow - (os.clock() - shownAt)
if left > 0 then
	task.wait(left)
end

-- the finish: the car hits the friend, the friend flies off with a BONK!, then the cover fades
done = true
progress = 1
status.Text = "LET'S GO!"
TweenService
	:Create(car, TweenInfo.new(Config.Finish.hit, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = carAt(1),
		Rotation = 0,
	})
	:Play()
TweenService:Create(
	trail,
	TweenInfo.new(Config.Finish.hit),
	{ Size = UDim2.fromOffset(carAt(1).X.Offset - ROAD_X + 20, 10) }
):Play()
task.wait(Config.Finish.hit)
bonk.Visible = true
TweenService
	:Create(
		friend,
		TweenInfo.new(Config.Finish.fly, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = UDim2.fromOffset(FRIEND_X + 140, ROAD_Y - 260),
			Rotation = 400,
		}
	)
	:Play()
TweenService:Create(
	bonk,
	TweenInfo.new(Config.Finish.pop, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	{ TextSize = 96 }
):Play()
task.wait(Config.Finish.hold)

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
if camWatch then
	camWatch:Disconnect()
end
gui:Destroy()
