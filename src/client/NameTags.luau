--!strict
-- Name tags over the city's friends and giants, built on this screen only so each player reads their own:
-- "friend of You" for their own friends (road yellow, big and bold), "friend of <name>" for another
-- player's friends (smaller, in one fixed colour per friend), and GIANT with the hits left. Tags keep
-- the same size on screen and fade out with distance from the camera. Your own friends also get a yellow
-- outline (only where you can see them) and stay tagged further out.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Crowd)
local Style = require(script.Parent.Style)

local NameTags = {}

local T = Config.Tags
local INK = Color3.fromRGB(20, 20, 24)

type Tag = {
	gui: BillboardGui,
	labels: { TextLabel },
	strokes: { UIStroke },
	from: number, -- fade starts this far from the camera (studs)
	to: number,
	outline: Highlight?, -- your own friends: a yellow outline, drawn only where you can see them
}

local tags: { [Model]: Tag } = {}
local watching: { [Model]: { RBXScriptConnection } } = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function label(
	parent: Instance,
	text: string,
	font: Font,
	size: number,
	color: Color3,
	y: number
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, y)
	l.Size = UDim2.new(1, 0, 0, size)
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
end

-- whose friend this is, as this player should read it
local function friendLine(m: Model): (string, boolean)
	local me = Players.LocalPlayer
	local owners = tostring(m:GetAttribute("FriendOf") or "")
	local other: string? = nil
	for id in string.gmatch(owners, "%d+") do
		local n = tonumber(id)
		if n == me.UserId then
			return "friend of You", true
		end
		local p = n and Players:GetPlayerByUserId(n)
		if p and not other then
			other = p.DisplayName
		end
	end
	local fallback = m:GetAttribute("FriendOfName")
	return `friend of {other or (if typeof(fallback) == "string" then fallback else "a player")}`,
		false
end

local function drop(m: Model)
	local t = tags[m]
	if t then
		t.gui:Destroy()
		if t.outline then
			t.outline:Destroy()
		end
		tags[m] = nil
	end
end

local function build(m: Model)
	drop(m)
	local head = m:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local hp = m:GetAttribute("GiantHp")
	local friendName = m:GetAttribute("FriendName")
	if typeof(hp) ~= "number" and typeof(friendName) ~= "string" then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Adornee = head
	gui.ResetOnSpawn = false
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Size = UDim2.fromOffset(T.Width, T.Height)
	gui.SizeOffset = Vector2.new(0, 0.5) -- the tag sits on its bottom edge
	gui.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2 + T.Lift * m:GetScale(), 0)

	local name, sub, color, size, bold
	local mine = false
	if typeof(hp) == "number" then
		name, sub, color, size, bold =
			"GIANT",
			`{hp} {if hp == 1 then "hit" else "hits"} left`,
			rgb(T.Giant),
			T.GiantSize,
			true
	else
		local line
		line, mine = friendLine(m)
		local id = m:GetAttribute("FriendId")
		local pick = (if typeof(id) == "number" then id else 0) % #T.Others + 1
		name, sub = string.upper(friendName :: string), line
		color = if mine then rgb(T.Mine) else rgb(T.Others[pick])
		size = if mine then T.MineSize else T.OtherSize
		bold = mine
	end
	local subSize = math.floor(size * 0.5 + 0.5)
	local top = T.Height - size - subSize - 2
	local nameLabel = label(gui, name, Style.fonts.display, size, color, top)
	local subLabel = label(gui, sub, Style.fonts.bold, subSize, Color3.new(1, 1, 1), top + size + 2)
	local strokes = {}
	for _, l in { nameLabel, subLabel } do
		local s = Instance.new("UIStroke")
		s.Color = INK
		s.Thickness = if l == nameLabel then (if bold then 3 else 2) else 2
		s.Parent = l
		table.insert(strokes, s)
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	-- a golden pedestrian keeps its gold glow instead (one highlight per character shows)
	local outline: Highlight? = nil
	if mine and not m:GetAttribute("Golden") then
		local h = Instance.new("Highlight")
		h.Name = "FriendOutline"
		h.Adornee = m
		h.FillTransparency = 1
		h.OutlineColor = rgb(T.Mine)
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Enabled = false -- fade() turns it on in range
		h.Parent = m
		outline = h
	end
	local giant = typeof(hp) == "number"
	tags[m] = {
		gui = gui,
		labels = { nameLabel, subLabel },
		strokes = strokes,
		from = if giant then T.GiantFadeFrom elseif mine then T.MineFadeFrom else T.FadeFrom,
		to = if giant then T.GiantFadeTo elseif mine then T.MineFadeTo else T.FadeTo,
		outline = outline,
	}
end

local function unwatch(m: Model)
	local list = watching[m]
	if list then
		for _, c in list do
			c:Disconnect()
		end
		watching[m] = nil
	end
	drop(m)
end

local function watch(m: Model)
	if not m:IsA("Model") or watching[m] then
		return
	end
	local function refresh()
		build(m)
	end
	watching[m] = {
		m:GetAttributeChangedSignal("GiantHp"):Connect(refresh),
		m:GetAttributeChangedSignal("FriendOf"):Connect(refresh),
		m:GetAttributeChangedSignal("FriendName"):Connect(refresh),
		m:GetAttributeChangedSignal("FriendOfName"):Connect(refresh),
		m:GetAttributeChangedSignal("Golden"):Connect(refresh),
	}
	refresh()
end

-- fade with distance; hidden while knocked down. Outlines go on the nearest friends in range only.
local function fade()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local eye = cam.CFrame.Position
	local outlined: { { h: Highlight, d: number } } = {}
	for m, t in tags do
		local head = t.gui.Adornee :: BasePart?
		if not head or not head.Parent then
			continue
		end
		local d = (head.Position - eye).Magnitude
		local a = math.clamp((d - t.from) / (t.to - t.from), 0, 1)
		local show = a < 1 and not m:GetAttribute("Down")
		t.gui.Enabled = show
		if t.outline then
			t.outline.Enabled = false
			if show then
				t.outline.OutlineTransparency = a
				table.insert(outlined, { h = t.outline, d = d })
			end
		end
		if show then
			for _, l in t.labels do
				l.TextTransparency = a
			end
			for _, s in t.strokes do
				s.Transparency = a
			end
		end
	end
	table.sort(outlined, function(x, y)
		return x.d < y.d
	end)
	for i = 1, math.min(#outlined, T.MaxOutlines) do
		outlined[i].h.Enabled = true
	end
end

function NameTags.start()
	task.spawn(NameTags.run)
end

function NameTags.run()
	local folder = workspace:WaitForChild("Npcs")
	folder.ChildAdded:Connect(watch)
	folder.ChildRemoved:Connect(function(m)
		if m:IsA("Model") then
			unwatch(m)
		end
	end)
	for _, m in folder:GetChildren() do
		watch(m :: Model)
	end
	-- a player joining or leaving changes whose friend a tag names
	local function rebuildAll()
		for m in tags do
			build(m)
		end
	end
	Players.PlayerAdded:Connect(rebuildAll)
	Players.PlayerRemoving:Connect(function()
		task.defer(rebuildAll)
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= T.FadeEvery then
			acc = 0
			fade()
		end
	end)
end

return NameTags
