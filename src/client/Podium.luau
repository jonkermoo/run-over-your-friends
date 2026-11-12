--!strict
-- The contest podium: when a contest event ends (server/EventService, Podium message) the top 3 stand on
-- steps of a podium, 1st in the middle and tallest, with their avatar head, score and prize, a fanfare, and
-- your own place under it. Waits its turn for the middle of the screen (Style.stage); a tap closes it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Callouts = require(ReplicatedStorage.Shared.Config.Callouts)
local Net = require(ReplicatedStorage.Shared.Net)
local Contest = require(ReplicatedStorage.Shared.Rules.Contest)
local Sfx = require(script.Parent.Sfx)
local Style = require(script.Parent.Style)

local Podium = {}

local C, F = Style.colors, Style.fonts
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Podium"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
Style.fit(gui)

type Entry = { id: number, name: string, score: number, prize: number }
type Result = {
	title: string,
	unit: string,
	top: { Entry },
	place: number,
	score: number,
	prize: number,
}

-- left to right: 2nd, 1st, 3rd; step heights in layout px and colours
local SLOTS = {
	{ place = 2, x = 0, height = 70, color = C.dim },
	{ place = 1, x = 1, height = 100, color = C.yellow },
	{ place = 3, x = 2, height = 50, color = C.orange },
}
local COLUMN = 150
local HEAD = 72

local function headshot(id: number): string
	if id <= 0 then
		return "" -- Studio test players have no avatar
	end
	local ok, url = pcall(function()
		return Players:GetUserThumbnailAsync(
			id,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size150x150
		)
	end)
	return if ok then url else ""
end

local function show(r: Result)
	local card = Style.panel(gui)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.45)
	card.Size = UDim2.fromOffset(COLUMN * 3 + 40, 340)
	Style.stroke(card, C.yellow, 3, 0)
	local title = Style.label(card, `{r.title} RESULTS`, 28, F.display, C.yellow)
	title.Position = UDim2.fromOffset(0, 10)
	title.Size = UDim2.new(1, 0, 0, 34)
	Style.outline(title, 2)

	local floor = 286 -- where the steps stand
	for _, slot in SLOTS do
		local e = r.top[slot.place]
		local left = 20 + slot.x * COLUMN
		local step = Instance.new("Frame")
		step.BorderSizePixel = 0
		step.BackgroundColor3 = slot.color
		step.Position = UDim2.fromOffset(left + 8, floor - slot.height)
		step.Size = UDim2.fromOffset(COLUMN - 16, slot.height)
		step.Parent = card
		local num = Style.label(step, Contest.ordinal(slot.place), 26, F.display, C.ink)
		num.Size = UDim2.new(1, 0, 0, 30)
		num.Position = UDim2.fromOffset(0, 4)
		if e then
			local top = floor - slot.height
			local head = Instance.new("ImageLabel")
			head.BackgroundColor3 = C.card
			head.BorderSizePixel = 0
			head.Position = UDim2.fromOffset(left + (COLUMN - HEAD) / 2, top - HEAD - 50)
			head.Size = UDim2.fromOffset(HEAD, HEAD)
			head.Parent = card
			Style.stroke(head, slot.color, 3, 0)
			task.spawn(function()
				head.Image = headshot(e.id)
			end)
			local name = Style.label(card, e.name, 15, F.heavy, C.text)
			name.Position = UDim2.fromOffset(left, top - 46)
			name.Size = UDim2.fromOffset(COLUMN, 18)
			name.TextTruncate = Enum.TextTruncate.AtEnd
			local line = Style.label(
				card,
				`{Contest.amount(e.score, r.unit)}  +{Style.money(e.prize)}`,
				13,
				F.heavy,
				C.money
			)
			line.Position = UDim2.fromOffset(left, top - 26)
			line.Size = UDim2.fromOffset(COLUMN, 16)
		end
	end
	local mine = if r.place == 0
		then "You didn't take part. Join the next one!"
		elseif r.place <= #r.top then `YOU CAME {Contest.ordinal(r.place)}!  +{Style.money(
			r.prize
		)}`
		else `YOU: {Contest.ordinal(r.place)}  ({Contest.amount(r.score, r.unit)})  +{Style.money(
			r.prize
		)}`
	local you = Style.label(card, mine, 16, F.heavy, if r.place > 0 then C.money else C.dim)
	you.Position = UDim2.fromOffset(0, floor + 14)
	you.Size = UDim2.new(1, 0, 0, 22)

	local close = Instance.new("TextButton")
	close.BackgroundTransparency = 1
	close.Text = ""
	close.Size = UDim2.fromScale(1, 1)
	close.ZIndex = 5
	close:SetAttribute("Quiet", true)
	close.Parent = card
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = card
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Sfx.play("Fanfare")
	local t0 = os.clock()
	local closed = false
	close.Activated:Connect(function()
		closed = true
	end)
	while not closed and os.clock() - t0 < Callouts.PodiumHold do
		task.wait(0.1)
	end
	TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
	task.delay(0.25, function()
		card:Destroy()
	end)
end

function Podium.start()
	gui.Parent = player:WaitForChild("PlayerGui")
	Net.waitFor("Podium").OnClientEvent:Connect(function(r: Result)
		if typeof(r) ~= "table" or typeof(r.top) ~= "table" or #r.top == 0 then
			return
		end
		task.delay(Style.stage(Callouts.PodiumHold), show, r)
	end)
end

return Podium
