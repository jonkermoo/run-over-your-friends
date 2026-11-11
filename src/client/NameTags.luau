--!strict
-- Name tags over the city's friends and giants, built on this screen only so each player reads their own:
-- "friend of You" for their own friends (road yellow, big and bold), "friend of <name>" for another
-- player's friends (smaller, in one fixed colour per friend), and GIANT with the hits left. Tags keep
-- the same size on screen and fade out with distance from the camera.
-- Real players who are friends get the same treatment (Config/Social.Look): your own friends a yellow
-- outline on them and their car (seen through walls) and a big YOUR FRIEND tag; another player's friends a
-- faint outline in that player's colour and a smaller "friend of <name>" tag.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Crowd)
local Social = require(ReplicatedStorage.Shared.Rules.Social)
local SocialConfig = require(ReplicatedStorage.Shared.Config.Social)
local Style = require(script.Parent.Style)

local NameTags = {}

local T = Config.Tags
local L = SocialConfig.Look
local INK = Color3.fromRGB(20, 20, 24)

type Tag = {
	gui: BillboardGui,
	labels: { TextLabel },
	strokes: { UIStroke },
	from: number, -- fade starts this far from the camera (studs)
	to: number,
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
	if typeof(hp) == "number" then
		name, sub, color, size, bold =
			"GIANT",
			`{hp} {if hp == 1 then "hit" else "hits"} left`,
			rgb(T.Giant),
			T.GiantSize,
			true
	else
		local line, mine = friendLine(m)
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
	local giant = typeof(hp) == "number"
	tags[m] = {
		gui = gui,
		labels = { nameLabel, subLabel },
		strokes = strokes,
		from = if giant then T.GiantFadeFrom else T.FadeFrom,
		to = if giant then T.GiantFadeTo else T.FadeTo,
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
	}
	refresh()
end

-- fade with distance; hidden while knocked down
local function fade()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local eye = cam.CFrame.Position
	for m, t in tags do
		local head = t.gui.Adornee :: BasePart?
		if not head or not head.Parent then
			continue
		end
		local d = (head.Position - eye).Magnitude
		local a = math.clamp((d - t.from) / (t.to - t.from), 0, 1)
		local show = a < 1 and not m:GetAttribute("Down")
		t.gui.Enabled = show
		if show then
			for _, l in t.labels do
				l.TextTransparency = a
			end
			for _, s in t.strokes do
				s.Transparency = a
			end
		end
	end
end

-- Real players who are friends ------------------------------------------------------------------------

type Look = { kind: "mine" | "other", owner: Social.FriendEntry }

local looks: { [Player]: Look } = {} -- players drawn as friends right now
local outlines: { Highlight } = {}
local playerTags: { [Model]: boolean } = {}

local function lookOf(p: Player): Look?
	local raw = p:GetAttribute("FriendsHere")
	local kind, owner = Social.friendTag(
		Social.decodeFriends(if typeof(raw) == "string" then raw else ""),
		Players.LocalPlayer.UserId
	)
	if kind and owner then
		return { kind = kind, owner = owner }
	end
	return nil
end

local function colourOf(look: Look): Color3
	if look.kind == "mine" then
		return rgb(L.Mine)
	end
	return rgb(L.Others[math.abs(look.owner.id) % #L.Others + 1])
end

local function carOf(p: Player): Model?
	local folder = workspace:FindFirstChild("Vehicles")
	if not folder then
		return nil
	end
	for _, car in folder:GetChildren() do
		if car:IsA("Model") and car:GetAttribute("OwnerId") == p.UserId then
			return car
		end
	end
	return nil
end

local function outline(target: Model, look: Look)
	local h = Instance.new("Highlight")
	h.Name = "FriendOutline"
	h.Adornee = target
	h.FillTransparency = 1
	h.OutlineColor = colourOf(look)
	h.OutlineTransparency = if look.kind == "mine" then 0 else L.OtherOutline
	h.DepthMode = if look.kind == "mine"
		then Enum.HighlightDepthMode.AlwaysOnTop
		else Enum.HighlightDepthMode.Occluded
	h.Parent = target
	table.insert(outlines, h)
end

local function playerTag(character: Model, p: Player, look: Look)
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local mine = look.kind == "mine"
	local gui = Instance.new("BillboardGui")
	gui.Name = "FriendTag"
	gui.Adornee = head
	gui.ResetOnSpawn = false
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true -- still readable when they sit under a car roof
	gui.Size = UDim2.fromOffset(L.Width, L.Height)
	gui.SizeOffset = Vector2.new(0, 0.5) -- the tag sits on its bottom edge
	gui.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2 + L.Lift, 0)
	local colour = colourOf(look)
	local top, sub, topSize, subSize, topColour, subColour
	if mine then
		top, sub = "YOUR FRIEND", p.DisplayName
		topSize, subSize = L.MineSize, math.floor(L.MineSize * 0.7 + 0.5)
		topColour, subColour = colour, Color3.new(1, 1, 1)
	else
		top, sub = p.DisplayName, `friend of {look.owner.name}`
		topSize, subSize = L.OtherSize, math.floor(L.OtherSize * 0.6 + 0.5)
		topColour, subColour = Color3.new(1, 1, 1), colour
	end
	local y = L.Height - topSize - subSize - 2
	local topLabel = label(gui, top, Style.fonts.display, topSize, topColour, y)
	local subLabel = label(gui, sub, Style.fonts.bold, subSize, subColour, y + topSize + 2)
	local strokes = {}
	for _, l in { topLabel, subLabel } do
		local s = Instance.new("UIStroke")
		s.Color = INK
		s.Thickness = if mine and l == topLabel then 3 else 2
		s.Parent = l
		table.insert(strokes, s)
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	drop(character)
	tags[character] = {
		gui = gui,
		labels = { topLabel, subLabel },
		strokes = strokes,
		from = if mine then L.MineFadeFrom else L.OtherFadeFrom,
		to = if mine then L.MineFadeTo else L.OtherFadeTo,
	}
	playerTags[character] = true
end

-- the Roblox name over a friend is replaced by the tag; strangers keep it
local function showRobloxName(character: Model, on: boolean)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = if on
			then Enum.HumanoidDisplayDistanceType.Viewer
			else Enum.HumanoidDisplayDistanceType.None
	end
end

-- redraw every friend outline and tag (cheap; runs only when friends, characters or cars change)
local function redrawPlayers()
	for _, h in outlines do
		h:Destroy()
	end
	table.clear(outlines)
	for character in playerTags do
		drop(character)
		if character.Parent then
			showRobloxName(character, true)
		end
	end
	table.clear(playerTags)
	table.clear(looks)
	local order: { Player } = {}
	for _, p in Players:GetPlayers() do
		local look = if p ~= Players.LocalPlayer then lookOf(p) else nil
		if look then
			looks[p] = look
			table.insert(order, p)
		end
	end
	-- your friends first, so they keep their outlines when there are more than MaxOutlines to draw
	table.sort(order, function(a, b)
		return looks[a].kind == "mine" and looks[b].kind ~= "mine"
	end)
	for _, p in order do
		local look = looks[p]
		local character = p.Character
		if character then
			playerTag(character, p, look)
			showRobloxName(character, false)
		end
		for _, target in { character, carOf(p) } do
			if target and #outlines < L.MaxOutlines then
				outline(target :: Model, look)
			end
		end
	end
end

local redrawQueued = false
local function queueRedraw()
	if not redrawQueued then
		redrawQueued = true
		task.defer(function()
			redrawQueued = false
			redrawPlayers()
		end)
	end
end

local function watchPlayer(p: Player)
	p:GetAttributeChangedSignal("FriendsHere"):Connect(queueRedraw)
	p.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		queueRedraw()
	end)
	queueRedraw()
end

local function watchFriends()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerRemoving:Connect(queueRedraw)
	local cars = workspace:WaitForChild("Vehicles")
	cars.ChildAdded:Connect(queueRedraw)
	cars.ChildRemoved:Connect(queueRedraw)
end

function NameTags.start()
	task.spawn(NameTags.run)
	task.spawn(watchFriends)
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
