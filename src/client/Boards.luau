--!strict
-- Draws the leaderboards on the stands along the spawn plaza's north side (parts named Stand_<n>,
-- Config/Leaderboards). Boards sharing a stand take turns. Each board: a checkered strip, the stat's icon
-- badge, title, tag and reset countdown; the top 3 as tall gold, silver and bronze rows (a crown and a light
-- sweeping across #1), ranks 4-9 as slim rows with an arrow for places gained or lost, and your own row last:
-- your rank (or "100+") and how much more passes the next place up. Rows are built once and refilled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Leaderboards)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local C, F = Style.colors, Style.fonts

local Boards = {}

type Entry = { userId: number, name: string, value: number }
type You = { rank: number?, value: number, gap: number? }
type Row = {
	frame: Frame,
	rank: TextLabel,
	avatar: ImageLabel,
	name: TextLabel,
	value: TextLabel,
	arrow: ImageLabel?,
}
type View = {
	gui: SurfaceGui,
	board: Config.Board,
	rows: { Row },
	you: Row,
	youNote: TextLabel,
	empty: TextLabel,
	countdown: TextLabel,
}

local WIDTH_PX = 728 -- every board is laid out this wide
local PAD = 22
local LIST_TOP = 146
local GAP = 6
local HEIGHTS = { 76, 64, 64 } -- the top 3; the rest are SLIM
local SLIM = 44
local YOU_H = 54
local SHOWN = 9 -- rows above your own
local METAL = {
	Color3.fromRGB(255, 196, 48),
	Color3.fromRGB(218, 224, 236),
	Color3.fromRGB(226, 138, 62),
}

local views: { [string]: View } = {}
local stands: { [number]: { View } } = {}
local headshots: { [number]: string } = {}
local latest: { [string]: { Entry } } = {}
local yours: { [string]: You } = {}
local lastRank: { [string]: { [number]: number } } = {}
local moves: { [string]: { [number]: number } } = {}
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

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return out
end

local function amount(board: Config.Board, n: number): string
	local unit = string.match(board.suffix, "^ (%a+)$")
	if unit then
		return Loc.resolve(Loc.amount(n, unit))
	end
	return `{board.prefix}{commas(n)}{board.suffix}`
end

local function headshot(userId: number, image: ImageLabel)
	local cached = headshots[userId]
	if cached then
		image.Image = cached
		return
	end
	image.Image = ""
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
		end)
		if ok and url then
			headshots[userId] = url
			if image.Parent and image:GetAttribute("UserId") == userId then
				image.Image = url
			end
		end
	end)
end

-- a little crown of ink-edged gold: a band and three points
local function crown(parent: Instance, x: number, y: number, size: number)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(x, y)
	holder.Size = UDim2.fromOffset(size, size * 0.7)
	holder.Rotation = -14
	holder.ZIndex = 4
	holder.Parent = parent
	for i = -1, 1 do
		local tip = Instance.new("Frame")
		tip.AnchorPoint = Vector2.new(0.5, 0.5)
		tip.BackgroundColor3 = C.text
		tip.BorderSizePixel = 0
		tip.Rotation = 45
		local s = if i == 0 then size * 0.36 else size * 0.28
		tip.Size = UDim2.fromOffset(s, s)
		tip.Position = UDim2.new(0.5 + i * 0.34, 0, 0, if i == 0 then size * 0.2 else size * 0.27)
		tip.ZIndex = 4
		tip.Parent = holder
		Style.stroke(tip, C.ink, 2, 0)
	end
	local band = Instance.new("Frame")
	band.BackgroundColor3 = C.text
	band.BorderSizePixel = 0
	band.Position = UDim2.fromOffset(0, size * 0.32)
	band.Size = UDim2.new(1, 0, 0, size * 0.36)
	band.ZIndex = 5
	band.Parent = holder
	Style.stroke(band, C.ink, 2, 0)
end

-- a white bar that sweeps across a row every few seconds
local function shine(row: Frame)
	local clip = Instance.new("Frame")
	clip.Name = "Shine"
	clip.BackgroundTransparency = 1
	clip.Size = UDim2.fromScale(1, 1)
	clip.ClipsDescendants = true
	clip.ZIndex = 3
	clip.Parent = row
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = C.text
	bar.BackgroundTransparency = 0.55
	bar.BorderSizePixel = 0
	bar.Rotation = 20
	bar.Size = UDim2.new(0, 46, 2, 0)
	bar.Position = UDim2.fromScale(-0.2, -0.5)
	bar.ZIndex = 3
	bar.Parent = clip
	task.spawn(function()
		while bar.Parent do
			bar.Position = UDim2.fromScale(-0.2, -0.5)
			local t = TweenService:Create(
				bar,
				TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Position = UDim2.fromScale(1.1, -0.5) }
			)
			t:Play()
			task.wait(4.5)
		end
	end)
end

local function makeRow(list: Frame, y: number, h: number, place: number?): Row
	local metal = if place then METAL[place] else nil
	local row = Instance.new("Frame")
	row.BackgroundColor3 = metal or C.card
	row.BorderSizePixel = 0
	row.Position = UDim2.fromOffset(0, y)
	row.Size = UDim2.new(1, 0, 0, h)
	row.Parent = list
	local ink = if metal then C.ink else C.text
	-- the rank painted big and slanted
	local rank =
		Style.label(row, "", if metal then 50 else 30, F.display, if metal then C.ink else C.dim)
	rank.AnchorPoint = Vector2.new(0, 0.5)
	rank.Position = UDim2.new(0, 6, 0.5, 3)
	rank.Size = UDim2.fromOffset(if metal then 62 else 52, h)
	rank.Rotation = -6
	rank.ZIndex = 2
	local arrow: ImageLabel? = nil
	local x = if metal then 70 else 56
	if not metal then
		local a = Style.image(row, Icons.Arrow, C.money)
		a.AnchorPoint = Vector2.new(0, 0.5)
		a.Position = UDim2.new(0, x, 0.5, 0)
		a.Size = UDim2.fromOffset(18, 18)
		a.Visible = false
		arrow = a
		x += 26
	end
	local side = h - (if metal then 12 else 10)
	local avatar = Instance.new("ImageLabel")
	avatar.AnchorPoint = Vector2.new(0, 0.5)
	avatar.Position = UDim2.new(0, x, 0.5, 0)
	avatar.Size = UDim2.fromOffset(side, side)
	avatar.BackgroundColor3 = if metal then C.ink else C.grey
	avatar.BackgroundTransparency = if metal then 0.8 else 0
	avatar.BorderSizePixel = 0
	avatar.ZIndex = 2
	avatar.Parent = row
	if metal then
		Style.stroke(avatar, C.ink, 3, 0)
	end
	x += side + 14
	local name = Style.label(row, "", if metal then 32 else 26, F.heavy, ink)
	name.Position = UDim2.fromOffset(x, 0)
	name.Size = UDim2.new(0.66, -x, 1, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.AutoLocalize = false -- a player's name, never translated
	name.ZIndex = 2
	local value = Style.label(row, "", if metal then 36 else 28, F.display, ink)
	value.AutoLocalize = false
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.new(1, -16, 0, 0)
	value.Size = UDim2.fromScale(0.34, 1)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.ZIndex = 2
	if metal then
		Style.shadow(row, C.ink, 5)
		if place == 1 then
			crown(row, -12, -22, 42)
			shine(row)
		end
	end
	return { frame = row, rank = rank, avatar = avatar, name = name, value = value, arrow = arrow }
end

local function build(part: BasePart, board: Config.Board): View
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board_" .. board.key
	gui.Adornee = part
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = WIDTH_PX / part.Size.X
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local accent = Style.colors[board.color] or C.gold

	-- a frame of the board's colour round the asphalt
	local edge = Instance.new("Frame")
	edge.Size = UDim2.fromScale(1, 1)
	edge.BackgroundColor3 = accent
	edge.BorderSizePixel = 0
	edge.Parent = gui
	local bg = Instance.new("Frame")
	bg.Position = UDim2.fromOffset(6, 6)
	bg.Size = UDim2.new(1, -12, 1, -12)
	bg.BackgroundColor3 = C.panel
	bg.BorderSizePixel = 0
	bg.Parent = edge
	-- a checkered finish-line strip across the top
	local strip = Instance.new("Frame")
	strip.BackgroundColor3 = C.ink
	strip.BorderSizePixel = 0
	strip.Size = UDim2.new(1, 0, 0, 20)
	strip.ClipsDescendants = true
	strip.Parent = bg
	for col = 0, math.ceil(WIDTH_PX / 10) do
		for r = 0, 1 do
			if (col + r) % 2 == 0 then
				local sq = Instance.new("Frame")
				sq.BackgroundColor3 = C.text
				sq.BorderSizePixel = 0
				sq.Position = UDim2.fromOffset(col * 10, r * 10)
				sq.Size = UDim2.fromOffset(10, 10)
				sq.Parent = strip
			end
		end
	end
	-- the stat's badge, title, tag and countdown
	local badge = Instance.new("Frame")
	badge.BackgroundColor3 = accent
	badge.BorderSizePixel = 0
	badge.Position = UDim2.fromOffset(PAD, 34)
	badge.Size = UDim2.fromOffset(84, 84)
	badge.Parent = bg
	Style.shadow(badge, C.ink, 5)
	local icon = Style.image(badge, (Icons :: any)[board.icon] or 0, C.ink)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.72, 0.72)
	icon.Rotation = board.iconTurn or 0
	local title = Style.label(bg, board.title, 54, F.display, C.text)
	title.Position = UDim2.fromOffset(PAD + 104, 30)
	title.Size = UDim2.new(1, -(PAD * 2 + 104), 0, 58)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 54
	limit.Parent = title
	local tag = Style.pill(bg, board.tag, accent)
	tag.Position = UDim2.fromOffset(PAD + 104, 92)
	tag.TextSize = 20
	tag.Size = UDim2.fromOffset(0, 28)
	local countdown = Style.label(bg, "", 22, F.bold, C.dim)
	countdown.AnchorPoint = Vector2.new(1, 0)
	countdown.Position = UDim2.new(1, -PAD, 0, 92)
	countdown.Size = UDim2.fromOffset(300, 28)
	countdown.TextXAlignment = Enum.TextXAlignment.Right

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(PAD, LIST_TOP)
	list.Size = UDim2.new(1, -PAD * 2, 1, -(LIST_TOP + 16))
	list.Parent = bg
	local rows = {}
	local y = 0
	for i = 1, SHOWN do
		local h = HEIGHTS[i] or SLIM
		table.insert(rows, makeRow(list, y, h, if i <= 3 then i else nil))
		y += h + GAP + (if i == 3 then 4 else 0)
	end
	local you = makeRow(list, y + 4, YOU_H, nil)
	Style.stroke(you.frame, C.yellow, 4, 0)
	you.rank.TextColor3 = C.yellow
	you.name.AutoLocalize = false
	local youNote = Style.label(you.frame, "", 18, F.bold, C.dim)
	youNote.AnchorPoint = Vector2.new(0, 1)
	youNote.Position = UDim2.new(0, you.name.Position.X.Offset, 1, -4)
	youNote.Size = UDim2.new(0.62, -you.name.Position.X.Offset, 0, 20)
	youNote.TextXAlignment = Enum.TextXAlignment.Left
	youNote.TextTruncate = Enum.TextTruncate.AtEnd
	you.name.Size = UDim2.new(0.62, -you.name.Position.X.Offset, 0, YOU_H - 22)
	you.name.TextYAlignment = Enum.TextYAlignment.Bottom
	local empty = Style.label(list, "Nobody yet. Be the first!", 32, F.display, C.dim)
	empty.Size = UDim2.new(1, 0, 0, 120)
	empty.Visible = false
	return {
		gui = gui,
		board = board,
		rows = rows,
		you = you,
		youNote = youNote,
		empty = empty,
		countdown = countdown,
	}
end

-- remember each player's last rank so a row can show places gained or lost
local function track(key: string, entries: { Entry })
	local before = lastRank[key]
	local now: { [number]: number } = {}
	moves[key] = moves[key] or {}
	for i, e in entries do
		now[e.userId] = i
		local was = before and before[e.userId]
		if before then
			if was and was ~= i then
				moves[key][e.userId] = was - i
			elseif not was then
				moves[key][e.userId] = 1
			end
		end
	end
	lastRank[key] = now
end

local function fill(view: View)
	local key = view.board.key
	local entries = latest[key] or {}
	view.empty.Visible = #entries == 0
	for i, row in view.rows do
		local e = entries[i]
		row.frame.Visible = e ~= nil
		if not e then
			continue
		end
		row.rank.Text = tostring(i)
		row.name.Text = e.name
		row.value.Text = amount(view.board, e.value)
		row.avatar:SetAttribute("UserId", e.userId)
		headshot(e.userId, row.avatar)
		if row.arrow then
			local move = (moves[key] or {})[e.userId] or 0
			row.arrow.Visible = move ~= 0
			row.arrow.Rotation = if move > 0 then 180 else 0
			row.arrow.ImageColor3 = if move > 0 then C.money else C.red
		end
	end
	-- your own row, always there
	local y = yours[key] or { value = 0 }
	local you = view.you
	you.rank.Text = if y.rank
		then `#{y.rank}`
		else (if y.value > 0 then `{Config.ReadTop}+` else "-")
	you.name.Text = Loc.text("BoardYou")
	you.value.Text = amount(view.board, y.value)
	you.avatar:SetAttribute("UserId", player.UserId)
	headshot(player.UserId, you.avatar)
	if y.value <= 0 then
		Loc.set(view.youNote, "BoardNoScore")
	elseif y.rank == 1 then
		Loc.set(view.youNote, "BoardTop")
	elseif y.gap and y.rank then
		Loc.set(view.youNote, "BoardPass", {
			gap = amount(view.board, y.gap),
			place = tostring(y.rank - 1),
		})
	else
		Loc.set(view.youNote, "BoardClimb")
	end
	you.frame.Visible = true
end

local function attach()
	local map = workspace:WaitForChild("Map", 60)
	local static = map and map:WaitForChild("Static", 60)
	local model = static and static:WaitForChild("Boards", 60)
	if not model then
		return
	end
	for n = 1, Config.Stands do
		local part = model:WaitForChild("Stand_" .. n, 30)
		if not part or not part:IsA("BasePart") then
			continue
		end
		local list = {}
		for _, board in Config.Boards do
			if board.stand == n then
				local view = build(part, board)
				views[board.key] = view
				fill(view)
				table.insert(list, view)
			end
		end
		stands[n] = list
	end
end

function Boards.start()
	Net.waitFor("Boards").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		endsAt = payload.endsAt or 0
		clockOffset = (payload.now or os.time()) - os.time()
		local boards = payload.boards or {}
		for key, entries in boards do
			local old = latest[key]
			local changed = not old or #old ~= #entries
			if old and not changed then
				for i, e in entries do
					if old[i].userId ~= e.userId then
						changed = true
						break
					end
				end
			end
			if changed then
				track(key, entries)
			end
		end
		latest = boards
		yours = payload.you or {}
		for _, view in views do
			fill(view)
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
		local turn = math.floor(workspace:GetServerTimeNow() / Config.FlipSeconds)
		for _, list in stands do
			for i, view in list do
				view.gui.Enabled = (turn % #list) + 1 == i
			end
		end
		for _, view in views do
			if endsAt > 0 and not view.board.allTime then
				Loc.set(view.countdown, "BoardResets", { time = fmt(left) })
			else
				view.countdown.Text = ""
			end
		end
	end)
end

return Boards
