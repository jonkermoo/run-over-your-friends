--!strict
-- The full-screen city map: a top-down picture of the city (Config/CityMap.Tiles) with a pin per player. You are
-- a pink arrow turned the way you face, friends are yellow pins with their names, everyone else is a small faded
-- white pin, and the live contest's leader wears a crown. Tap or click a pin (gamepad: LB / RB) to see who it is
-- and what they drive. The stunt park, Stadium Row and the live event's spot are marked. Zoom with the mouse
-- wheel, a pinch, the + / - buttons or gamepad Y / X; drag (or the right stick) to move round; ME centres on you.
-- Opens from the MAP tab, M or a left-stick click (Config Key / PadKey); closes from its X, the same again, or B. Driving
-- goes on behind it; it counts as a menu (Popups.addBusy), so the phone driving buttons hide while it's open.
-- The server sends spots once a second only while it's open (MapOpen / MapDots, server/CityMapService); dots
-- slide between updates. Your own arrow follows your character every frame.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Cfg = require(ReplicatedStorage.Shared.Config.CityMap)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Rules = require(ReplicatedStorage.Shared.Rules.CityMap)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Pad = require(script.Parent.Pad)
local Popups = require(script.Parent.Popups)
local Style = require(script.Parent.Style)

local CityMap = {}
CityMap.onOpen = nil :: (() -> ())? -- set by the client entry: closes the garage, store and goals

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local C, F = Style.colors, Style.fonts

local SIDE_W = 250 -- the column beside the picture: the picked player's card and the key
local GAP = 14

local gui = Instance.new("ScreenGui")
gui.Name = "CityMap"
gui.ResetOnSpawn = false
gui.DisplayOrder = Cfg.DisplayOrder
gui.Parent = playerGui
Style.fit(gui)

local sheet = Style.panel(gui)
sheet.Name = "Sheet"
sheet.Position = UDim2.fromOffset(Cfg.Side, Cfg.Top)
sheet.Size = UDim2.new(1, -2 * Cfg.Side, 1, -(Cfg.Top + Cfg.Bottom))
sheet.Visible = false
Style.sign(sheet, "orange")

local title = Style.label(sheet, "CITY MAP", 32, F.display, C.text)
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.fromOffset(200, 40)
title.TextXAlignment = Enum.TextXAlignment.Left
local hint = Style.label(sheet, "TAP A DOT TO SEE WHO IT IS", 14, F.heavy, C.dim)
hint.Position = UDim2.fromOffset(196, 12)
hint.Size = UDim2.new(1, -420, 0, 36)
hint.TextXAlignment = Enum.TextXAlignment.Left
local close = Style.button(sheet, "X", "dark", 22)
close.Name = "Close"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -10, 0, 7)
close.Size = UDim2.fromOffset(44, 44)
local closeHint = Pad.chip(sheet, { Enum.KeyCode.ButtonB }, "close")
closeHint.AnchorPoint = Vector2.new(1, 0.5)
closeHint.Position = UDim2.new(1, -66, 0, 29)
local pickHint = Pad.chip(sheet, { Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1 }, "players")
pickHint.AnchorPoint = Vector2.new(1, 0.5)
pickHint.Position = UDim2.new(1, -170, 0, 29)
local headLine = Style.dashes(sheet, C.yellow, false, 4)
headLine.Position = UDim2.fromOffset(0, Cfg.Header - 2)

-- the window onto the map ("Picture"), and inside it the canvas: the whole picture in tiles with the layers
-- drawn on it (places, the event, pins, names), all in its 0..1 square. Zooming sizes the canvas, moving shifts it.
local picture = Instance.new("Frame")
picture.Name = "Picture"
picture.BackgroundColor3 = C.card
picture.BorderSizePixel = 0
picture.ClipsDescendants = true
picture.Parent = sheet
Style.stroke(picture, C.ink, 3, 0)
local canvas = Instance.new("Frame")
canvas.Name = "Canvas"
canvas.BackgroundTransparency = 1
canvas.Size = UDim2.fromScale(1, 1)
canvas.Parent = picture
do
	local g = Cfg.TileGrid
	for i, id in Cfg.Tiles do
		local col, row = (i - 1) % g, (i - 1) // g
		local t = Instance.new("ImageLabel")
		t.Name = `Tile{i}`
		t.BackgroundTransparency = 1
		t.Image = if id ~= 0 then `rbxassetid://{id}` else ""
		t.ScaleType = Enum.ScaleType.Stretch
		t.Position = UDim2.fromScale(col / g, row / g)
		t.Size = UDim2.new(1 / g, 1, 1 / g, 1) -- one px over, so no seam shows between tiles
		t.Parent = canvas
	end
end
-- taps, clicks, drags and the wheel land here (over the canvas, under the zoom buttons)
local tapArea = Instance.new("TextButton")
tapArea.Name = "TapArea" -- not a gamepad stop (Pad.selectAll skips it): LB / RB pick players there
tapArea.BackgroundTransparency = 1
tapArea.Text = ""
tapArea.Size = UDim2.fromScale(1, 1)
tapArea.ZIndex = 10
tapArea.Parent = picture

local function layer(name: string, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = z
	f.Parent = canvas
	return f
end
local placesLayer = layer("Places", 2)
local othersLayer = layer("Others", 3)
local friendsLayer = layer("Friends", 4)
local selfLayer = layer("You", 6)

-- + / - and ME in the window's top-right corner
local zoomBar = Instance.new("Frame")
zoomBar.Name = "Zoom"
zoomBar.BackgroundTransparency = 1
zoomBar.AnchorPoint = Vector2.new(1, 0)
zoomBar.Position = UDim2.new(1, -8, 0, 8)
zoomBar.Size = UDim2.fromOffset(40, 3 * 40 + 2 * 8)
zoomBar.ZIndex = 20
zoomBar.Parent = picture
local zoomList = Instance.new("UIListLayout")
zoomList.Padding = UDim.new(0, 8)
zoomList.SortOrder = Enum.SortOrder.LayoutOrder
zoomList.Parent = zoomBar
local function zoomButton(text: string, name: string, order: number, kind: string): TextButton
	local b = Style.button(zoomBar, text, kind, if #text > 1 then 15 else 24)
	b.Name = name
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(40, 40)
	b.ZIndex = 20
	return b
end
local zoomIn = zoomButton("+", "ZoomIn", 1, "gold")
local zoomOut = zoomButton("-", "ZoomOut", 2, "gold")
local meButton = zoomButton("ME", "ZoomMe", 3, "purple")
local zoomHint = Pad.chip(picture, { Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonX }, "zoom")
zoomHint.AnchorPoint = Vector2.new(1, 1)
zoomHint.Position = UDim2.new(1, -8, 1, -8)
zoomHint.ZIndex = 20

-- the side column: the picked player's card over a key to the dots
local side = Instance.new("Frame")
side.Name = "Side"
side.BackgroundTransparency = 1
side.Size = UDim2.fromOffset(SIDE_W, 0)
side.Parent = sheet

local card = Style.card(side)
card.Name = "Picked"
card.Size = UDim2.fromOffset(SIDE_W, 150)
local cardTag = Style.pill(card, "PLAYER", C.text)
cardTag.Position = UDim2.fromOffset(14, 14)
cardTag.TextSize = 13
cardTag.Size = UDim2.fromOffset(0, 22)
local cardLeader = Style.pill(card, "LEADER", C.yellow)
cardLeader.TextSize = 13
cardLeader.Size = UDim2.fromOffset(0, 22)
cardLeader.Visible = false
local cardName = Style.label(card, "", 28, F.display, C.text)
cardName.Position = UDim2.fromOffset(14, 42)
cardName.Size = UDim2.new(1, -28, 0, 36)
cardName.TextXAlignment = Enum.TextXAlignment.Left
cardName.TextTruncate = Enum.TextTruncate.AtEnd
local cardCarWord = Style.label(card, "DRIVING", 13, F.heavy, C.dim)
cardCarWord.Position = UDim2.fromOffset(14, 84)
cardCarWord.Size = UDim2.new(1, -28, 0, 18)
cardCarWord.TextXAlignment = Enum.TextXAlignment.Left
local cardCar = Style.label(card, "", 22, F.display, C.yellow)
cardCar.Position = UDim2.fromOffset(14, 102)
cardCar.Size = UDim2.new(1, -28, 0, 30)
cardCar.TextXAlignment = Enum.TextXAlignment.Left
cardCar.TextTruncate = Enum.TextTruncate.AtEnd
local cardEmpty = Style.label(card, "PICK A DOT ON THE MAP", 16, F.heavy, C.dim)
cardEmpty.Size = UDim2.fromScale(1, 1)
cardEmpty.TextWrapped = true

-- the key: what each mark means
local legend = Instance.new("Frame")
legend.Name = "Key"
legend.BackgroundTransparency = 1
legend.Size = UDim2.fromOffset(SIDE_W, 5 * 34)
legend.Parent = side
local legendList = Instance.new("UIListLayout")
legendList.SortOrder = Enum.SortOrder.LayoutOrder
legendList.Padding = UDim.new(0, 6)
legendList.Parent = legend

local function legendRow(order: number, text: string, draw: (Frame) -> ())
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(SIDE_W, 28)
	row.LayoutOrder = order
	row.Parent = legend
	local icon = Instance.new("Frame")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(28, 28)
	icon.Parent = row
	draw(icon)
	local l = Style.label(row, text, 16, F.heavy, C.ink) -- black on the orange sign
	l.Position = UDim2.fromOffset(40, 0)
	l.Size = UDim2.new(1, -40, 1, 0)
	l.TextXAlignment = Enum.TextXAlignment.Left
end

-- a map pin (Config/CityMap.Pin) tinted `color`, its tip on the holder's spot
local function pin(parent: Instance, size: number, color: Color3, fade: number): ImageLabel
	local d = Style.image(parent, Cfg.Pin, color)
	d.Name = "Pin"
	d.AnchorPoint = Vector2.new(0.5, 1)
	d.Position = UDim2.fromOffset(0, 0)
	d.Size = UDim2.fromOffset(size, size)
	d.ImageTransparency = fade
	return d
end

local function arrow(parent: Instance, size: number): ImageLabel
	local a = Style.image(parent, Icons.Arrow, C.pink)
	a.Name = "Arrow"
	a.AnchorPoint = Vector2.new(0.5, 0.5)
	a.Position = UDim2.fromScale(0.5, 0.5)
	a.Size = UDim2.fromOffset(size, size)
	a.Rotation = 180 -- the picture points down; 180 points it north
	return a
end

local function crown(parent: Instance, size: number): ImageLabel
	local c = Style.image(parent, Icons.PassVIP)
	c.Name = "Crown"
	c.ImageColor3 = Color3.new(1, 1, 1)
	c.AnchorPoint = Vector2.new(0.5, 1)
	c.Size = UDim2.fromOffset(size, size)
	return c
end

legendRow(1, Loc.text("BoardYou"), function(f)
	arrow(f, 26)
end)
legendRow(2, "FRIEND", function(f)
	pin(f, 26, C.yellow, 0).Position = UDim2.fromScale(0.5, 1)
end)
legendRow(3, "PLAYER", function(f)
	pin(f, 20, C.text, Cfg.OtherFade).Position = UDim2.fromScale(0.5, 0.9)
end)
legendRow(4, "EVENT LEADER", function(f)
	local c = crown(f, 26)
	c.Position = UDim2.fromScale(0.5, 1)
end)
legendRow(5, "LIVE EVENT", function(f)
	local s = Style.image(f, Icons.Sign, Color3.new(1, 1, 1))
	s.Size = UDim2.fromScale(1, 1)
end)

---------------------------------------------------------------- key places and the event's spot

local function placeLabel(parent: Instance, text: string, u: number, v: number): Frame
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(u, v)
	holder.Size = UDim2.fromOffset(0, 0)
	holder.Parent = parent
	local l = Style.label(holder, text, Cfg.PlaceText, F.display, C.text)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.fromOffset(0, 0)
	l.BackgroundColor3 = C.ink
	l.BackgroundTransparency = 0.15
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 7)
	pad.PaddingRight = UDim.new(0, 7)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 1)
	pad.Parent = l
	return holder
end

for _, p in Cfg.Places do
	local u, v = Rules.toMap(p.x, p.z, Cfg)
	placeLabel(placesLayer, p.name, u, v).Name = p.key
end

local eventPin = Instance.new("Frame")
eventPin.Name = "Event"
eventPin.BackgroundTransparency = 1
eventPin.AnchorPoint = Vector2.new(0.5, 0.5)
eventPin.Size = UDim2.fromOffset(0, 0)
eventPin.Visible = false
eventPin.ZIndex = 5
eventPin.Parent = canvas
do
	local s = Style.image(eventPin, Icons.Sign, Color3.new(1, 1, 1))
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Size = UDim2.fromOffset(Cfg.EventPin, Cfg.EventPin)
	s.ZIndex = 5
end

---------------------------------------------------------------- dots

type Dot = {
	id: number,
	holder: Frame,
	mark: GuiObject, -- the pin or your arrow
	size: number, -- the mark's size when not picked
	pinned: boolean, -- a pin (tip on the spot), not your arrow (centred)
	name: TextLabel,
	crown: ImageLabel,
	-- where it slides from and to, and when the last update came
	fromX: number,
	fromZ: number,
	fromH: number,
	toX: number,
	toZ: number,
	toH: number,
	at: number,
	x: number, -- where it's drawn now
	z: number,
	h: number,
	friend: boolean,
	inCar: boolean,
	ride: number?, -- whose car they ride in, when it's someone else's
}

local dots: { [number]: Dot } = {}
local friends: { [number]: boolean } = {}
local leaderId = 0
local selectedId: number? = nil
local isOpen = false

-- whether a player is one of yours (asked once each; Studio test players count when Config says so)
local function isFriend(p: Player): boolean
	if p == player then
		return false
	end
	local known = friends[p.UserId]
	if known ~= nil then
		return known
	end
	if p.UserId <= 0 then
		friends[p.UserId] = RunService:IsStudio() and Cfg.StudioFriends
		return friends[p.UserId]
	end
	friends[p.UserId] = false
	task.spawn(function()
		local ok, yes = pcall(function()
			return player:IsFriendsWith(p.UserId)
		end)
		friends[p.UserId] = ok and yes == true
	end)
	return false
end

local function destroyDot(id: number)
	local d = dots[id]
	if d then
		d.holder:Destroy()
		dots[id] = nil
	end
end

local function makeDot(id: number, x: number, z: number, h: number): Dot
	local p = Players:GetPlayerByUserId(id)
	local you = p == player
	local friend = p ~= nil and isFriend(p)
	local holder = Instance.new("Frame")
	holder.Name = tostring(id)
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(0, 0)
	holder.Parent = if you then selfLayer elseif friend then friendsLayer else othersLayer
	local mark: GuiObject
	local size = if you then Cfg.SelfArrow elseif friend then Cfg.FriendPin else Cfg.OtherPin
	if you then
		mark = arrow(holder, size)
	else
		mark = pin(
			holder,
			size,
			if friend then C.yellow else C.text,
			if friend then 0 else Cfg.OtherFade
		)
	end
	-- a pin's name hangs under its tip and its crown sits on its head; your arrow is centred on your spot
	local below = if you then size / 2 + 2 else 2
	local top = if you then -size / 2 + 2 else -size + 2
	local name = Style.label(
		holder,
		if p then p.DisplayName else "",
		Cfg.NameText,
		F.heavy,
		if friend then C.yellow else C.text
	)
	Style.outline(name, 2)
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.fromOffset(0, below)
	name.Size = UDim2.fromOffset(200, Cfg.NameText + 4)
	name.Visible = friend
	local c = crown(holder, Cfg.Crown)
	c.Position = UDim2.fromOffset(0, top)
	c.Visible = false
	local d: Dot = {
		id = id,
		holder = holder,
		mark = mark,
		size = size,
		pinned = not you,
		name = name,
		crown = c,
		fromX = x,
		fromZ = z,
		fromH = h,
		toX = x,
		toZ = z,
		toH = h,
		at = os.clock(),
		x = x,
		z = z,
		h = h,
		friend = friend,
		inCar = false,
	}
	dots[id] = d
	return d
end

-- the car you're sitting in (yours, or someone else's as a rider: a model with an OwnerId) and its owner's id
local function selfCar(): (Model?, number?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local at: Instance? = humanoid and humanoid.SeatPart and humanoid.SeatPart.Parent
	while at and at ~= workspace do
		local owner = at:GetAttribute("OwnerId")
		if at:IsA("Model") and typeof(owner) == "number" then
			return at, owner
		end
		at = at.Parent
	end
	return nil, nil
end

-- your own spot, straight from your character (or your car while you're in it)
local function selfSpot(): (number?, number?, number?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local cf = root.CFrame
	local car = selfCar()
	if car then
		cf = car:GetPivot()
	end
	local look = cf.LookVector
	return cf.Position.X, cf.Position.Z, Rules.heading(look.X, look.Z)
end

local function onDots(flat: { any }, leader: any, ex: any, ez: any)
	if not isOpen then
		return
	end
	leaderId = if typeof(leader) == "number" then leader else 0
	if typeof(ex) == "number" and typeof(ez) == "number" then
		local u, v = Rules.toMap(ex, ez, Cfg)
		eventPin.Position = UDim2.fromScale(u, v)
		eventPin.Visible = true
	else
		eventPin.Visible = false
	end
	local seen: { [number]: boolean } = {}
	local now = os.clock()
	for _, s in Rules.unpack(flat) do
		if s.id ~= player.UserId and Players:GetPlayerByUserId(s.id) then
			seen[s.id] = true
			local d = dots[s.id]
			if not d then
				local fresh = makeDot(s.id, s.x, s.z, s.h)
				fresh.inCar, fresh.ride = s.car, s.ride
			else
				d.fromX, d.fromZ, d.fromH = d.x, d.z, d.h
				d.toX, d.toZ, d.toH = s.x, s.z, s.h
				d.at = now
				d.inCar, d.ride = s.car, s.ride
			end
		end
	end
	for id in dots do
		if id ~= player.UserId and not seen[id] then
			destroyDot(id)
		end
	end
	if selectedId and selectedId ~= player.UserId and not dots[selectedId] then
		selectedId = nil
	end
end

---------------------------------------------------------------- the picked player's card

-- the picked player's pin grows, shows full strength and shows their name (friends' names always show)
local function setRing(id: number?)
	for did, d in dots do
		local want = did == id
		if d.pinned then
			local size = if want then d.size * Cfg.PickedGrow else d.size
			d.mark.Size = UDim2.fromOffset(size, size)
			local img = d.mark :: ImageLabel
			img.ImageTransparency = if want or d.friend then 0 else Cfg.OtherFade
			d.holder.ZIndex = if want then 2 else 1
			d.crown.Position = UDim2.fromOffset(0, -size + 2)
		end
		d.name.Visible = d.friend or (want and did ~= player.UserId)
	end
end

local function refreshCard()
	local p = selectedId and Players:GetPlayerByUserId(selectedId)
	cardEmpty.Visible = p == nil
	for _, o in { cardTag, cardName, cardCarWord, cardCar } do
		o.Visible = p ~= nil
	end
	cardLeader.Visible = p ~= nil and p.UserId == leaderId
	if not p then
		return
	end
	local you = p == player
	local friend = not you and friends[p.UserId] == true
	cardTag.Text = if you then Loc.text("BoardYou") elseif friend then "FRIEND" else "PLAYER"
	cardTag.BackgroundColor3 = if you then C.pink elseif friend then C.yellow else C.text
	cardTag.TextColor3 = if you then C.text else C.ink
	cardLeader.Position = UDim2.fromOffset(14 + cardTag.AbsoluteSize.X / Style.scale() + 6, 14)
	cardName.Text = p.DisplayName
	cardName.TextColor3 = if friend then C.blue else C.ink
	-- driving their own car, riding in someone else's, or on foot
	local d = dots[p.UserId]
	local seated, rideId = false, nil
	if you then
		local inside, owner = selfCar()
		seated = inside ~= nil and owner == player.UserId
		rideId = if inside and owner ~= player.UserId then owner else nil
	elseif d then
		seated, rideId = d.inCar, d.ride
	end
	local owner = if rideId then Players:GetPlayerByUserId(rideId) else (if seated then p else nil)
	local carId = owner and owner:GetAttribute("VehicleId")
	local car = typeof(carId) == "string" and Vehicles.ById[carId] or nil
	-- the rider line is translated here (with the name in it); the fixed words AutoLocalize
	cardCarWord.AutoLocalize = rideId == nil
	if rideId then
		cardCarWord.Text = if owner
			then Loc.text("MapRidingIn", { name = Loc.upper(owner.DisplayName) })
			else Loc.text("MapRiding")
	else
		cardCarWord.Text = if car then "DRIVING" else "ON FOOT"
	end
	cardCar.Text = if car then string.upper(car.name) else ""
end

local function pick(id: number?)
	selectedId = id
	setRing(id)
	refreshCard()
end

---------------------------------------------------------------- zoom and move

local zoom = 1
local panX, panY = 0, 0 -- the canvas's offset in the window, layout px

local function windowSize(): number
	return picture.Size.X.Offset
end

local function applyView()
	local w = windowSize()
	panX = Rules.clampPan(panX, zoom, w)
	panY = Rules.clampPan(panY, zoom, w)
	canvas.Size = UDim2.fromOffset(w * zoom, w * zoom)
	canvas.Position = UDim2.fromOffset(panX, panY)
end

-- zoom to z, keeping the window point (ax, ay) (layout px from its top left; the middle if not given) still
local function zoomTo(z: number, ax: number?, ay: number?)
	local w = windowSize()
	z = math.clamp(z, Cfg.MinZoom, Cfg.MaxZoom)
	panX = Rules.zoomAbout(panX, ax or w / 2, zoom, z)
	panY = Rules.zoomAbout(panY, ay or w / 2, zoom, z)
	zoom = z
	applyView()
end

-- put a spot on the picture (u, v: 0..1) in the window's middle (as near as the edges allow)
local function centreOn(u: number, v: number)
	local w = windowSize()
	panX = w / 2 - u * w * zoom
	panY = w / 2 - v * w * zoom
	applyView()
end

local function centreOnPlayer(id: number?)
	local d = if id then dots[id] else nil
	if d then
		local u, v = Rules.toMap(d.x, d.z, Cfg)
		centreOn(u, v)
	end
end

-- a real-px point as layout px from the window's top left
local function inWindow(pos: Vector2): (number, number)
	local k = Style.scale()
	local a = picture.AbsolutePosition
	return (pos.X - a.X) / k, (pos.Y - a.Y) / k
end

-- the marker nearest a tap or click (real px), if one is close enough and the point is inside the window
local function pickAt(pos: Vector2)
	local a, sz = picture.AbsolutePosition, picture.AbsoluteSize
	if pos.X < a.X or pos.Y < a.Y or pos.X > a.X + sz.X or pos.Y > a.Y + sz.Y then
		return
	end
	local pts, ids = {}, {}
	for id, d in dots do
		local m = d.mark.AbsolutePosition + d.mark.AbsoluteSize / 2
		table.insert(pts, { x = m.X, y = m.Y })
		table.insert(ids, id)
	end
	local i = Rules.pick(pts, pos.X, pos.Y, Cfg.TapRadius * Style.scale())
	pick(if i then ids[i] else nil)
end

local mouseDown = false
local pressAt = Vector2.zero
local lastMouse = Vector2.zero
local moved = false
local touches: { [InputObject]: Vector2 } = {}

local function touchCount(): number
	local n = 0
	for _ in touches do
		n += 1
	end
	return n
end

local function at2(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

tapArea.InputBegan:Connect(function(input)
	local pos = at2(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		mouseDown, moved = true, false
		pressAt, lastMouse = pos, pos
	elseif input.UserInputType == Enum.UserInputType.Touch then
		touches[input] = pos
		if touchCount() == 1 then
			pressAt, moved = pos, false
		else
			moved = true -- a pinch is never a tap
		end
	end
end)

-- the mouse wheel over the window zooms about the pointer
tapArea.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local ax, ay = inWindow(at2(input))
		zoomTo(zoom * Cfg.WheelStep ^ input.Position.Z, ax, ay)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not isOpen then
		return
	end
	local k = Style.scale()
	local pos = at2(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement and mouseDown then
		if (pos - pressAt).Magnitude > Cfg.DragStart * k then
			moved = true
		end
		if moved then
			local delta = (pos - lastMouse) / k
			panX += delta.X
			panY += delta.Y
			applyView()
		end
		lastMouse = pos
	elseif input.UserInputType == Enum.UserInputType.Touch and touches[input] then
		local before = touches[input]
		local other: Vector2? = nil
		for t, p in touches do
			if t ~= input then
				other = p
			end
		end
		touches[input] = pos
		if not other then
			if (pos - pressAt).Magnitude > Cfg.DragStart * k then
				moved = true
			end
			if moved then
				local delta = (pos - before) / k
				panX += delta.X
				panY += delta.Y
				applyView()
			end
		else
			-- two fingers: follow their middle, and zoom by how much further apart they are, about it
			local d0, d1 = (before - other).Magnitude, (pos - other).Magnitude
			local mid0, mid1 = (before + other) / 2, (pos + other) / 2
			panX += (mid1.X - mid0.X) / k
			panY += (mid1.Y - mid0.Y) / k
			if d0 > 1 then
				local ax, ay = inWindow(mid1)
				zoomTo(zoom * d1 / d0, ax, ay)
			else
				applyView()
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and mouseDown then
		mouseDown = false
		if isOpen and not moved then
			pickAt(at2(input))
		end
	elseif input.UserInputType == Enum.UserInputType.Touch and touches[input] then
		touches[input] = nil
		if isOpen and not moved and touchCount() == 0 then
			pickAt(at2(input))
		end
	end
end)

Style.onTap(zoomIn, function()
	zoomTo(zoom * Cfg.ZoomStep)
end)
Style.onTap(zoomOut, function()
	zoomTo(zoom / Cfg.ZoomStep)
end)
Style.onTap(meButton, function()
	pick(player.UserId)
	zoomTo(math.max(zoom, Cfg.MeZoom))
	centreOnPlayer(player.UserId)
end)

-- gamepad: the right stick moves it, Y / X zoom (bound only while it's open, over the camera and the car's keys)
local padPan = Vector2.zero
local function bindPad()
	ContextActionService:BindActionAtPriority("RoyfCityMapPan", function(_, _, input)
		padPan = at2(input)
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Thumbstick2)
	ContextActionService:BindActionAtPriority("RoyfCityMapZoom", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			zoomTo(
				if input.KeyCode == Enum.KeyCode.ButtonY
					then zoom * Cfg.ZoomStep
					else zoom / Cfg.ZoomStep
			)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonX)
end
local function unbindPad()
	ContextActionService:UnbindAction("RoyfCityMapPan")
	ContextActionService:UnbindAction("RoyfCityMapZoom")
	padPan = Vector2.zero
end

-- the players in the order LB / RB steps through them: you, then friends, then everyone else, by name
local function order(): { number }
	local list = {}
	for id in dots do
		table.insert(list, id)
	end
	table.sort(list, function(a, b)
		local da, db = dots[a], dots[b]
		local ra = if a == player.UserId then 0 elseif da.friend then 1 else 2
		local rb = if b == player.UserId then 0 elseif db.friend then 1 else 2
		if ra ~= rb then
			return ra < rb
		end
		return da.name.Text < db.name.Text
	end)
	return list
end

local function step(dir: number)
	local list = order()
	if #list == 0 then
		return
	end
	local at = table.find(list, selectedId or -math.huge)
	local i = if at then (at - 1 + dir) % #list + 1 elseif dir > 0 then 1 else #list
	pick(list[i])
	if zoom > 1 then
		centreOnPlayer(list[i])
	end
end

---------------------------------------------------------------- layout and drawing

-- the picture as big a square as fits, with the side column on its right
local function layout()
	local k = Style.scale()
	local w = sheet.AbsoluteSize.X / k
	local h = sheet.AbsoluteSize.Y / k
	local bodyTop = Cfg.Header + GAP
	local bodyH = h - bodyTop - GAP
	local size = math.max(120, math.min(bodyH, w - SIDE_W - 3 * GAP))
	local used = size + GAP + SIDE_W
	local x0 = math.max(GAP, (w - used) / 2)
	picture.Position = UDim2.fromOffset(x0, bodyTop)
	picture.Size = UDim2.fromOffset(size, size)
	applyView()
	side.Position = UDim2.fromOffset(x0 + size + GAP, bodyTop)
	side.Size = UDim2.fromOffset(SIDE_W, size)
	legend.Position = UDim2.fromOffset(0, card.Size.Y.Offset + GAP)
	hint.Visible = w > 760
	hint.Text = if UserInputService.TouchEnabled
		then "TAP A DOT TO SEE WHO IT IS"
		else "CLICK A DOT TO SEE WHO IT IS"
end
sheet:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

local lastCard = 0
local lastDraw = os.clock()
local function draw()
	local now = os.clock()
	local dt = math.min(now - lastDraw, 0.1)
	lastDraw = now
	if padPan.Magnitude > Cfg.PadDead then
		panX -= padPan.X * Cfg.PadPan * dt
		panY += padPan.Y * Cfg.PadPan * dt
		applyView()
	end
	local sx, sz, sh = selfSpot()
	if sx and sz and sh then
		local me = dots[player.UserId] or makeDot(player.UserId, sx, sz, sh)
		me.x, me.z, me.h = sx, sz, sh
	end
	for _, d in dots do
		if d.id ~= player.UserId then
			local t = Rules.slide(now - d.at, Cfg.Smooth)
			d.x = d.fromX + (d.toX - d.fromX) * t
			d.z = d.fromZ + (d.toZ - d.fromZ) * t
			d.h = Rules.blendHeading(d.fromH, d.toH, t)
		end
		local u, v = Rules.toMap(d.x, d.z, Cfg)
		d.holder.Position = UDim2.fromScale(u, v)
		if d.mark.Name == "Arrow" then
			d.mark.Rotation = d.h + 180
		end
		d.crown.Visible = d.id == leaderId
	end
	if now - lastCard > 0.25 then
		lastCard = now
		-- a friend found out after their dot was made gets the friend's look
		for id, d in dots do
			if friends[id] == true and not d.friend then
				local x, z, h = d.x, d.z, d.h
				destroyDot(id)
				makeDot(id, x, z, h)
				setRing(selectedId)
			end
		end
		refreshCard()
	end
end

---------------------------------------------------------------- open and close

local drawing: RBXScriptConnection? = nil

function CityMap.isOpen(): boolean
	return isOpen
end

function CityMap.open()
	if isOpen then
		return
	end
	if CityMap.onOpen then
		CityMap.onOpen()
	end
	isOpen = true
	zoom, panX, panY = 1, 0, 0
	layout()
	sheet.Visible = true
	bindPad()
	Net.remote("MapOpen"):FireServer(true)
	drawing = RunService.RenderStepped:Connect(draw)
	draw()
	pick(selectedId or player.UserId)
end

function CityMap.close()
	if not isOpen then
		return
	end
	isOpen = false
	sheet.Visible = false
	unbindPad()
	mouseDown = false
	table.clear(touches)
	Net.remote("MapOpen"):FireServer(false)
	if drawing then
		drawing:Disconnect()
		drawing = nil
	end
	-- the next open starts from fresh spots, not a slide from where they were minutes ago
	for id in dots do
		destroyDot(id)
	end
	eventPin.Visible = false
end

function CityMap.toggle()
	if isOpen then
		CityMap.close()
	else
		CityMap.open()
	end
end

function CityMap.start()
	Net.waitFor("MapDots").OnClientEvent:Connect(onDots)
	close.Activated:Connect(CityMap.close)
	Popups.addBusy(CityMap.isOpen)
	Pad.menu(sheet, {
		first = function()
			return close
		end,
		close = CityMap.close,
		shoulders = step,
	})
	local key = (Enum.KeyCode :: any)[Cfg.Key] :: Enum.KeyCode
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == key then
			CityMap.toggle()
		end
	end)
	-- its own gamepad key, if it has one (sunk, so nothing else takes the same press)
	if Cfg.PadKey ~= "" then
		ContextActionService:BindActionAtPriority("RoyfCityMap", function(_, state)
			if state == Enum.UserInputState.Begin then
				CityMap.toggle()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, (Enum.KeyCode :: any)[Cfg.PadKey])
	end
	Players.PlayerRemoving:Connect(function(p)
		destroyDot(p.UserId)
		friends[p.UserId] = nil
		if selectedId == p.UserId then
			pick(nil)
		end
	end)
end

return CityMap
