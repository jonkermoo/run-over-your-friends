--!strict
-- The full-screen city map: a top-down picture of the city (Config/CityMap.Image) with a dot per player. You are
-- a big pink arrow turned the way you face, friends are bright yellow dots with their names, everyone else is
-- a small faded dot, and the live contest's leader wears a crown. Tap or click a dot (gamepad: LB / RB) to see
-- who it is and what they drive. The stunt park, the stadium and the live event's spot are marked.
-- Opens from the MAP tab or M (and Config PadKey on a gamepad, if set); closes from its X, the same again, or B. Driving
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
Style.setShadow(sheet, C.yellow)

local title = Style.label(sheet, "CITY MAP", 32, F.display, C.text)
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.fromOffset(200, 40)
title.TextXAlignment = Enum.TextXAlignment.Left
local hint = Style.label(sheet, "TAP A DOT TO SEE WHO IT IS", 14, F.heavy, C.dim)
hint.Position = UDim2.fromOffset(196, 12)
hint.Size = UDim2.new(1, -420, 0, 36)
hint.TextXAlignment = Enum.TextXAlignment.Left
local close = Style.button(sheet, "X", "gold", 22)
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

-- the picture, and the layers drawn on it (places, the event, dots, names), all in its 0..1 square
local picture = Instance.new("ImageLabel")
picture.Name = "Picture"
picture.BackgroundColor3 = C.card
picture.BorderSizePixel = 0
picture.Image = if Cfg.Image ~= 0 then `rbxassetid://{Cfg.Image}` else ""
picture.ScaleType = Enum.ScaleType.Stretch
picture.ClipsDescendants = true
picture.Parent = sheet
Style.stroke(picture, C.ink, 3, 0)
local tapArea = Instance.new("TextButton")
tapArea.Name = "TapArea" -- not a gamepad stop (Pad.selectAll skips it): LB / RB pick dots there
tapArea.BackgroundTransparency = 1
tapArea.Text = ""
tapArea.Size = UDim2.fromScale(1, 1)
tapArea.ZIndex = 1
tapArea.Parent = picture

local function layer(name: string, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = z
	f.Parent = picture
	return f
end
local placesLayer = layer("Places", 2)
local othersLayer = layer("Others", 3)
local friendsLayer = layer("Friends", 4)
local selfLayer = layer("You", 6)

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
	local l = Style.label(row, text, 16, F.heavy, C.text)
	l.Position = UDim2.fromOffset(40, 0)
	l.Size = UDim2.new(1, -40, 1, 0)
	l.TextXAlignment = Enum.TextXAlignment.Left
end

-- a round dot, centred on its holder
local function dot(parent: Instance, size: number, color: Color3, fade: number): Frame
	local d = Instance.new("Frame")
	d.Name = "Dot"
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.fromScale(0.5, 0.5)
	d.Size = UDim2.fromOffset(size, size)
	d.BackgroundColor3 = color
	d.BackgroundTransparency = fade
	d.BorderSizePixel = 0
	d.Parent = parent
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = d
	local edge = Style.stroke(d, C.ink, 2, 0)
	edge.Transparency = fade
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
	dot(f, Cfg.FriendDot, C.yellow, 0)
end)
legendRow(3, "PLAYER", function(f)
	dot(f, Cfg.OtherDot, C.text, Cfg.OtherFade)
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
eventPin.Parent = picture
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
	mark: GuiObject, -- the dot or the arrow
	name: TextLabel,
	crown: ImageLabel,
	ring: UIStroke?,
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
	if you then
		mark = arrow(holder, Cfg.SelfArrow)
	elseif friend then
		mark = dot(holder, Cfg.FriendDot, C.yellow, 0)
	else
		mark = dot(holder, Cfg.OtherDot, C.text, Cfg.OtherFade)
	end
	local size = mark.Size.X.Offset
	local name = Style.label(
		holder,
		if p then p.DisplayName else "",
		Cfg.NameText,
		F.heavy,
		if friend then C.yellow else C.text
	)
	Style.outline(name, 2)
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.fromOffset(0, size / 2 + 2)
	name.Size = UDim2.fromOffset(200, Cfg.NameText + 4)
	name.Visible = friend
	local c = crown(holder, Cfg.Crown)
	c.Position = UDim2.fromOffset(0, -size / 2 + 2)
	c.Visible = false
	local d: Dot = {
		id = id,
		holder = holder,
		mark = mark,
		name = name,
		crown = c,
		ring = nil,
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

-- your own car while you're sitting in it
local function selfCar(): Model?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local car = seat and seat:FindFirstAncestorOfClass("Model")
	return if car and car:GetAttribute("OwnerId") then car else nil
end

local function selfInCar(): boolean
	return selfCar() ~= nil
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
				makeDot(s.id, s.x, s.z, s.h).inCar = s.car
			else
				d.fromX, d.fromZ, d.fromH = d.x, d.z, d.h
				d.toX, d.toZ, d.toH = s.x, s.z, s.h
				d.at = now
				d.inCar = s.car
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

local function setRing(id: number?)
	for did, d in dots do
		local want = did == id
		if want and not d.ring then
			local r = Instance.new("UIStroke")
			r.Color = C.text
			r.Thickness = 3
			r.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			-- the arrow has no box edge to ring: the dot underneath does it for everyone else
			if d.mark:IsA("Frame") then
				r.Parent = d.mark
				local edge = d.mark:FindFirstChildOfClass("UIStroke")
				if edge and edge ~= r then
					edge.Enabled = false
				end
				d.ring = r
			else
				r:Destroy()
			end
		elseif not want and d.ring then
			d.ring:Destroy()
			d.ring = nil
			local edge = d.mark:FindFirstChildOfClass("UIStroke")
			if edge then
				edge.Enabled = true
			end
		end
		-- a picked player's name shows even if they aren't a friend
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
	cardName.TextColor3 = if friend then C.yellow else C.text
	local carId = p:GetAttribute("VehicleId")
	local d = dots[p.UserId]
	local seated = if you then selfInCar() else (d ~= nil and d.inCar)
	local car = seated and typeof(carId) == "string" and Vehicles.ById[carId] or nil
	cardCarWord.Text = if car then "DRIVING" else "ON FOOT"
	cardCar.Text = if car then string.upper(car.name) else ""
end

local function pick(id: number?)
	selectedId = id
	setRing(id)
	refreshCard()
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
end

tapArea.Activated:Connect(function(input: InputObject)
	local pos = input.Position
	local k = Style.scale()
	local pts, ids = {}, {}
	for id, d in dots do
		local a = d.holder.AbsolutePosition
		table.insert(pts, { x = a.X, y = a.Y })
		table.insert(ids, id)
	end
	local i = Rules.pick(pts, pos.X, pos.Y, Cfg.TapRadius * k)
	pick(if i then ids[i] else nil)
end)

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
local function draw()
	local now = os.clock()
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
	layout()
	sheet.Visible = true
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
