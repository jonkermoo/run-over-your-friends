--!strict
-- Launch ramps and the AIR ticker. Your car is yours to move, so the kick off a yellow ramp happens here: leave
-- its lip still climbing and you're thrown up to Config.RampAir of air, whatever you drive. While you're up,
-- a big tilted "AIR 1.4s" counts up over the speedometer. The server measures the jump and pays it
-- (StuntService). Jet cars fly, so they get neither.

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

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.CollisionGroup = "Vehicles"

local lastGround: Instance? = nil
local lastGroundAt = 0
local kicked = false

-- off a launch ramp's lip, still climbing: up to at least RampAir of flight
local function launch(car: Model, now: number)
	local chassis = car.PrimaryPart
	if not chassis then
		return
	end
	rayParams.FilterDescendantsInstances = { car, player.Character :: Instance }
	local hit =
		workspace:Raycast(chassis.Position, Vector3.new(0, -(chassis.Size.Y / 2 + 4), 0), rayParams)
	if hit then
		lastGround, lastGroundAt, kicked = hit.Instance, now, false
		return
	end
	local v = chassis.AssemblyLinearVelocity
	if
		not kicked
		and lastGround
		and lastGround:GetAttribute("Launch") == true
		and now - lastGroundAt < 0.15
		and v.Y > Config.RampUp
	then
		kicked = true
		local want = workspace.Gravity * Config.RampAir / 2
		if v.Y < want then
			chassis.AssemblyLinearVelocity = Vector3.new(v.X, want, v.Z)
		end
	end
end

function Stunts.start()
	local upSince: number? = nil
	RunService.RenderStepped:Connect(function()
		local s = Drive.state
		local stats = Vehicles.ById[s.vehicleId]
		local now = os.clock()
		local car = Drive.view.car
		if s.driving and car and stats and not Vehicles.has(stats, "Jet") then
			launch(car, now)
		end
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
