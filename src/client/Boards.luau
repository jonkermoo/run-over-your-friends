--!strict
-- Draws the weekly leaderboards on the board stands at the spawn plaza (parts named Board_<key>):
-- title, a reset countdown, and the top 10 with rank badges, avatar headshots, names and scores.
-- Your own row is outlined in gold.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Leaderboards)
local Net = require(ReplicatedStorage.Shared.Net)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local C, F = Style.colors, Style.fonts

local Boards = {}

type Entry = { userId: number, name: string, value: number }
type View = { gui: SurfaceGui, list: Frame, countdown: TextLabel, board: Config.Board }

local PPS = 14 -- pixels per stud on the board face (52 x 46 studs → 728 x 644 px)
local LIST_TOP, LIST_BOTTOM = 146, 16
local MEDALS = { C.gold, Color3.fromRGB(205, 215, 230), Color3.fromRGB(225, 140, 80) }
local views: { [string]: View } = {}
local headshots: { [number]: string } = {}
local endsAt, clockOffset = 0, 0

local function fmt(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d, h, m =
		math.floor(seconds / 86400), math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	end
	return string.format("%dh %02dm", h, m)
end

local function headshot(userId: number, image: ImageLabel)
	local cached = headshots[userId]
	if cached then
		image.Image = cached
		return
	end
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)
		if ok and url then
			headshots[userId] = url
			if image.Parent then
				image.Image = url
			end
		end
	end)
end

local function build(part: BasePart, board: Config.Board): View
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board_" .. board.key
	gui.Adornee = part
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	Style.gradient(bg, C.panelTop, C.ink)
	Style.corner(bg, 24)
	local accent = Style.colors[board.color] or C.gold
	Style.stroke(bg, accent, 8, 0)

	local title = Style.label(bg, board.title, 58, F.display, C.text)
	title.Position = UDim2.fromOffset(0, 10)
	title.Size = UDim2.new(1, 0, 0, 64)
	Style.outline(title, 5)
	local week = Style.pill(bg, "THIS WEEK", accent)
	week.AnchorPoint = Vector2.new(0.5, 0)
	week.Position = UDim2.new(0.5, 0, 0, 78)
	week.TextSize = 20
	week.Size = UDim2.fromOffset(0, 28)
	Style.corner(week, 14)
	local countdown = Style.label(bg, "", 20, F.bold, C.dim)
	countdown.Position = UDim2.fromOffset(0, 110)
	countdown.Size = UDim2.new(1, 0, 0, 26)

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(22, LIST_TOP)
	list.Size = UDim2.new(1, -44, 1, -(LIST_TOP + LIST_BOTTOM))
	list.Parent = bg
	return { gui = gui, list = list, countdown = countdown, board = board }
end

local function fill(view: View, entries: { Entry })
	for _, c in view.list:GetChildren() do
		c:Destroy()
	end
	if #entries == 0 then
		local empty = Style.label(view.list, "Nobody yet. Be the first!", 32, F.display, C.dim)
		empty.Size = UDim2.fromScale(1, 0.3)
		return
	end
	local face = view.gui.Adornee :: BasePart
	local rowH = math.floor((face.Size.Y * PPS - LIST_TOP - LIST_BOTTOM) / Config.Top)
	for i, e in entries do
		local row = Style.card(view.list, 14)
		row.Position = UDim2.fromOffset(0, (i - 1) * rowH)
		row.Size = UDim2.new(1, 0, 0, rowH - 6)
		if e.userId == player.UserId then
			Style.stroke(row, C.gold, 4, 0)
		end
		local badge = Style.label(row, tostring(i), 26, F.display, if i <= 3 then C.ink else C.text)
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, 10, 0.5, 0)
		badge.Size = UDim2.fromOffset(rowH - 16, rowH - 16)
		badge.BackgroundTransparency = if i <= 3 then 0 else 1
		badge.BackgroundColor3 = MEDALS[i] or C.grey
		Style.corner(badge, (rowH - 16) // 2)
		local avatar = Instance.new("ImageLabel")
		avatar.AnchorPoint = Vector2.new(0, 0.5)
		avatar.Position = UDim2.new(0, rowH + 4, 0.5, 0)
		avatar.Size = UDim2.fromOffset(rowH - 12, rowH - 12)
		avatar.BackgroundColor3 = C.panelTop
		avatar.Parent = row
		Style.corner(avatar, (rowH - 12) // 2)
		headshot(e.userId, avatar)
		local name = Style.label(row, e.name, 26, F.heavy, C.text)
		name.Position = UDim2.fromOffset(rowH * 2, 0)
		name.Size = UDim2.new(0.62, -rowH * 2, 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local value = Style.label(
			row,
			`{view.board.prefix}{e.value}{view.board.suffix}`,
			28,
			F.display,
			Style.colors[view.board.color] or C.gold
		)
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(1, -16, 0, 0)
		value.Size = UDim2.fromScale(0.38, 1)
		value.TextXAlignment = Enum.TextXAlignment.Right
		Style.outline(value, 2)
	end
end

local latest: { [string]: { Entry } } = {}

local function attach()
	local map = workspace:WaitForChild("Map", 60)
	local static = map and map:WaitForChild("Static", 60)
	local stands = static and static:WaitForChild("Boards", 60)
	if not stands then
		return
	end
	for _, board in Config.Boards do
		local part = stands:WaitForChild("Board_" .. board.key, 30) :: BasePart?
		if part then
			views[board.key] = build(part, board)
			fill(views[board.key], latest[board.key] or {})
		end
	end
end

function Boards.start()
	Net.waitFor("Boards").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		endsAt = payload.endsAt or 0
		clockOffset = (payload.now or os.time()) - os.time()
		latest = payload.boards or {}
		for key, view in views do
			fill(view, latest[key] or {})
		end
	end)
	task.spawn(attach)
	local last = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() - last < 1 then
			return
		end
		last = os.clock()
		local left = endsAt - (os.time() + clockOffset)
		for _, view in views do
			view.countdown.Text = if endsAt > 0 then "resets in " .. fmt(left) else ""
		end
	end)
end

return Boards
