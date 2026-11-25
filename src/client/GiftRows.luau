--!strict
-- The goals sheet's PLAY GIFTS section (client/Goals builds it): one row per play-time gift (Config/Gifts) with
-- its prize and a tick once claimed, CLAIM once it has opened (the server checks the time), or a countdown.
-- The HUD gift chip (client/GiftChip) opens the goals sheet to here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Gifts)
local Paints = require(ReplicatedStorage.Shared.Config.Paints)
local Gifts = require(ReplicatedStorage.Shared.Rules.Gifts)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Style = require(script.Parent.Style)

local C, F = Style.colors, Style.fonts
local player = Players.LocalPlayer

local ROW_H, GAP = 46, 6

local GiftRows = {}
GiftRows.changed = nil :: (() -> ())? -- set by client/Goals: rebuild when a gift opens or is claimed

local timers: { [number]: TextLabel } = {}

-- seconds played this session, and gifts claimed; nil before the server has started the session
local function progress(): (number?, number)
	local start = player:GetAttribute("GiftStart")
	local claimed = player:GetAttribute("GiftsClaimed")
	if typeof(start) ~= "number" then
		return nil, 0
	end
	return workspace:GetServerTimeNow() - start, if typeof(claimed) == "number" then claimed else 0
end

-- what changes the rows' shape: how many are claimed and whether the next one is open
function GiftRows.key(): string
	local played, claimed = progress()
	local index = Gifts.nextIndex(claimed, Config.Minutes)
	local open = played ~= nil and index ~= nil and Gifts.open(index, played, Config.Minutes, 0)
	return `{claimed}/{open}`
end

local function clock(seconds: number): string
	local s = math.ceil(seconds)
	return string.format("%d:%02d", s // 60, s % 60)
end

local function prizeText(i: number): string
	local p = Config.Prizes[i]
	if p.paint then
		local paint = Paints.ById[p.paint]
		return Loc.text("GiftPaint", { paint = Loc.src(paint and paint.name or p.paint) })
	end
	return Style.money(p.cash)
end

-- the section from y down in `body`; returns the y under it
function GiftRows.build(body: Instance, y: number): number
	table.clear(timers)
	local played, claimed = progress()
	if not played then
		return y
	end
	local head = Style.label(body, "PLAY GIFTS", 22, F.display, C.ink)
	head.BackgroundColor3 = C.yellow
	head.BackgroundTransparency = 0
	head.AutomaticSize = Enum.AutomaticSize.X
	head.Position = UDim2.fromOffset(12, y + 4)
	head.Size = UDim2.fromOffset(0, 30)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 4)
	pad.Parent = head
	y += 40
	local nextIndex = Gifts.nextIndex(claimed, Config.Minutes)
	for i, minute in Config.Minutes do
		local row = Style.card(body)
		row.Position = UDim2.fromOffset(12, y)
		row.Size = UDim2.new(1, -24, 0, ROW_H)
		local name = Style.label(row, "", 17, F.display, C.text)
		Loc.set(name, "GiftNext", { m = minute })
		name.Position = UDim2.fromOffset(12, 5)
		name.Size = UDim2.new(1, -150, 0, 20)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local prize = Style.label(row, prizeText(i), 14, F.heavy, C.money)
		prize.AutoLocalize = false
		prize.Position = UDim2.fromOffset(12, 25)
		prize.Size = UDim2.new(1, -150, 0, 16)
		prize.TextXAlignment = Enum.TextXAlignment.Left
		if i <= claimed then
			local done = Style.label(row, "CLAIMED", 15, F.heavy, C.dim)
			done.AnchorPoint = Vector2.new(1, 0.5)
			done.Position = UDim2.new(1, -14, 0.5, 0)
			done.Size = UDim2.fromOffset(120, 20)
			done.TextXAlignment = Enum.TextXAlignment.Right
			row.BackgroundTransparency = 0.5
		elseif i == nextIndex and Gifts.open(i, played, Config.Minutes, 0) then
			local claim = Style.button(row, "CLAIM", "green", 18)
			claim.Name = "ClaimGift"
			claim.AnchorPoint = Vector2.new(1, 0.5)
			claim.Position = UDim2.new(1, -8, 0.5, 0)
			claim.Size = UDim2.fromOffset(120, 36)
			Style.onTap(claim, function()
				Net.waitFor("ClaimGift"):FireServer()
			end)
		else
			local t = Style.label(row, "", 16, F.heavy, C.dim)
			t.AutoLocalize = false
			t.AnchorPoint = Vector2.new(1, 0.5)
			t.Position = UDim2.new(1, -14, 0.5, 0)
			t.Size = UDim2.fromOffset(120, 20)
			t.TextXAlignment = Enum.TextXAlignment.Right
			timers[i] = t
		end
		y += ROW_H + GAP
	end
	GiftRows.tick()
	return y + 4
end

-- countdowns in place; a rebuild when a gift opens or is claimed
local lastKey = ""
function GiftRows.tick()
	local played = progress()
	for i, t in timers do
		if t.Parent then
			t.Text = if played then clock(Gifts.wait(i, played, Config.Minutes)) else ""
		end
	end
	local key = GiftRows.key()
	if key ~= lastKey then
		lastKey = key
		if GiftRows.changed then
			GiftRows.changed()
		end
	end
end

function GiftRows.start()
	task.spawn(function()
		while true do
			GiftRows.tick()
			task.wait(0.5)
		end
	end)
end

return GiftRows
