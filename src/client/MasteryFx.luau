--!strict
-- Mastery while driving: when points come in (Net "Mastery", server/MasteryService) a small plate over the
-- speedometer shows the car, its mastery level and bar, and the points just earned, then hides again after
-- Config/Upgrades PopupSeconds. A new level is cheered by the server with the game's confetti card.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Upgrades)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Rules = require(ReplicatedStorage.Shared.Rules.Upgrades)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local C, F = Style.colors, Style.fonts

local MasteryFx = {}

local gui = Instance.new("ScreenGui")
gui.Name = "MasteryFx"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
Style.fit(gui)

-- just over the speedometer (client/Hud: 70 tall, 18 off the bottom), under the AIR ticker
local plate = Style.panel(gui)
plate.Name = "MasteryPlate"
plate.AnchorPoint = Vector2.new(0.5, 1)
plate.Position = UDim2.new(0.5, 0, 1, -98)
plate.Size = UDim2.fromOffset(260, 30)
plate.Visible = false
local name = Style.label(plate, "", 14, F.display, C.text)
name.Position = UDim2.fromOffset(8, 2)
name.Size = UDim2.fromOffset(110, 26)
name.TextXAlignment = Enum.TextXAlignment.Left
name.TextScaled = true
local nameCap = Instance.new("UITextSizeConstraint")
nameCap.MaxTextSize = 14
nameCap.Parent = name
local level = Style.label(plate, "", 13, F.display, C.ink)
level.BackgroundTransparency = 0
level.BackgroundColor3 = C.yellow
level.Position = UDim2.fromOffset(120, 6)
level.Size = UDim2.fromOffset(22, 18)
local back, fill = Style.bar(plate, C.yellow)
back.BackgroundTransparency = 0
back.BackgroundColor3 = C.ink
back.Position = UDim2.fromOffset(148, 10)
back.Size = UDim2.fromOffset(100, 10)
Style.laneGaps(back, C.panel)
local gain = Style.label(gui, "", 18, F.display, C.yellow)
gain.Name = "MasteryGain"
gain.AnchorPoint = Vector2.new(0.5, 1)
gain.Position = UDim2.new(0.5, 0, 1, -130)
gain.Size = UDim2.fromOffset(200, 22)
gain.Visible = false
Style.outline(gain, 2)
-- the outline fades with the text, or a bare ink border is left hanging after the number goes
local gainStroke = gain:FindFirstChildOfClass("UIStroke") :: UIStroke

local shownUntil = 0

local function show(vehicleId: string, points: number, total: number)
	local row = Vehicles.ById[vehicleId]
	name.Text = if row then string.upper(row.name) else vehicleId
	local lvl, into, span = Rules.progress(total)
	level.Text = tostring(lvl)
	fill.Size =
		UDim2.fromScale(if lvl >= Config.MaxLevel then 1 elseif span > 0 then into / span else 0, 1)
	Loc.set(gain, "MasteryGain", { n = points })
	plate.Visible = true
	gain.Visible = true
	gain.TextTransparency = 0
	gainStroke.Transparency = 0
	shownUntil = os.clock() + Config.PopupSeconds
	local mine = shownUntil
	local fade = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.6)
	TweenService:Create(gain, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(gainStroke, fade, { Transparency = 1 }):Play()
	task.delay(Config.PopupSeconds, function()
		if shownUntil == mine then
			plate.Visible = false
			gain.Visible = false
		end
	end)
end

function MasteryFx.start()
	Net.waitFor("Mastery").OnClientEvent:Connect(function(vehicleId: any, points: any, total: any)
		if
			typeof(vehicleId) == "string"
			and typeof(points) == "number"
			and typeof(total) == "number"
		then
			-- driving points trickle in: only flash the bigger gains, but keep the bar honest
			if points >= 5 or plate.Visible then
				show(vehicleId, points, total)
			end
		end
	end)
end

return MasteryFx
