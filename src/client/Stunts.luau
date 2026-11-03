--!strict
-- The AIR ticker: while your car is off the ground, a big tilted "AIR 1.4s" counts up over the speedometer,
-- yellow road paint on an ink outline, growing a little with the time. Just a show: the server measures the
-- jump and pays it (StuntService). Jet cars fly, so they get no ticker.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Stunts)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Drive = require(script.Parent.Drive)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local C, F = Style.colors, Style.fonts

local Stunts = {}

local gui = Instance.new("ScreenGui")
gui.Name = "Stunts"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local ticker = Style.label(gui, "", 40, F.display, C.yellow)
ticker.Name = "AirTicker"
ticker.AnchorPoint = Vector2.new(0.5, 1)
ticker.Position = UDim2.new(0.5, 0, 1, -140)
ticker.Size = UDim2.fromOffset(320, 50)
ticker.Rotation = -4
ticker.Visible = false
Style.outline(ticker, 3)
local scale = Instance.new("UIScale")
scale.Parent = ticker

function Stunts.start()
	local upSince: number? = nil
	RunService.RenderStepped:Connect(function()
		local s = Drive.state
		local stats = Vehicles.ById[s.vehicleId]
		local now = os.clock()
		if not (s.driving and s.airborne and stats and not Vehicles.has(stats, "Jet")) then
			upSince = nil
			ticker.Visible = false
			return
		end
		upSince = upSince or now
		local air = now - (upSince :: number)
		ticker.Visible = air >= Config.TickerAfter
		ticker.Text = `AIR {string.format("%.1f", air)}s`
		ticker.TextColor3 = if air >= 3 then C.money elseif air >= 1.5 then C.orange else C.yellow
		scale.Scale = 1 + math.min(air, 4) * 0.08
	end)
end

return Stunts
