--!strict
-- The day/night cycle on this client: reads the server's cycle start (Lighting attributes, see
-- DayNightService), works out the time from the shared server clock and eases Lighting, the sky, haze, grade
-- and bloom through Config/DayNight's stops. Night keeps the shade lifted so nothing gets harder to see.
-- Also lights the town's windows one by one through the dusk (Neon swap on streamed-in Glass panes, no lights)
-- and gives your own car one headlight beam. Interiors' indoor easing is folded in here (Interiors.blend), so
-- only this module writes Lighting's Ambient and ExposureCompensation.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.DayNight)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Rules = require(ReplicatedStorage.Shared.Rules.DayNight)
local Interiors = require(script.Parent.Interiors)

local DayNight = {}

local player = Players.LocalPlayer
local W = Config.Windows
local H = Config.Headlights

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local WINDOW_COLORS = {}
for i, c in W.Colors do
	WINDOW_COLORS[i] = rgb(c)
end

local glow = 0 -- the current look's Glow, read by the window and headlight passes

-- windows -----------------------------------------------------------------------------------------------------

type Pane =
	{ on: number, color: Color3, material: Enum.Material, transparency: number, lit: boolean }
local panes: { [BasePart]: Pane } = {}

local function setLit(part: BasePart, pane: Pane, lit: boolean)
	if pane.lit == lit then
		return
	end
	pane.lit = lit
	if lit then
		local p = part.Position
		local pick = math.floor(Rules.hash(p.Z, p.Y, p.X) * #WINDOW_COLORS) + 1
		part.Material = Enum.Material.Neon
		part.Color = WINDOW_COLORS[pick]
		part.Transparency = W.Transparency
	else
		part.Material = pane.material
		part.Color = pane.color
		part.Transparency = pane.transparency
	end
end

-- a window pane: Glass, upright (a flat glass part is a pond or a skylight), in a building
local function consider(d: Instance)
	if not d:IsA("BasePart") or d.Material ~= Enum.Material.Glass or panes[d] then
		return
	end
	local s = d.Size
	if s.Y < math.min(s.X, s.Z) then
		return
	end
	local p = d.Position
	local on = Rules.paneOn(Rules.hash(p.X, p.Y, p.Z), W.Share, W.FirstAt, W.LastAt)
	if not on then
		return
	end
	local pane = {
		on = on,
		color = d.Color,
		material = d.Material,
		transparency = d.Transparency,
		lit = false,
	}
	panes[d] = pane
	if glow >= on then
		setLit(d, pane, true)
	end
end

local function watchWindows()
	local map = workspace:WaitForChild("Map")
	local buildings = map:WaitForChild("Buildings")
	buildings.DescendantAdded:Connect(consider)
	buildings.DescendantRemoving:Connect(function(d)
		if d:IsA("BasePart") then
			panes[d] = nil
		end
	end)
	local all = buildings:GetDescendants()
	for i, d in all do
		consider(d)
		if i % W.Batch == 0 then
			task.wait()
		end
	end
	local passGlow = -1
	while true do
		if glow ~= passGlow then
			passGlow = glow
			for part, pane in panes do
				setLit(part, pane, glow >= pane.on)
			end
		end
		task.wait(W.Every)
	end
end

-- headlights --------------------------------------------------------------------------------------------------

local beamCar: Model? = nil
local beam: Attachment? = nil

local function dropBeam()
	if beam then
		beam:Destroy()
	end
	beam, beamCar = nil, nil
end

local function updateBeam()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local car = if seat
			and seat:IsA("VehicleSeat")
			and seat.Parent
			and seat.Parent:IsA("Model")
		then seat.Parent
		else nil
	local chassis = car and car.PrimaryPart
	if not car or not chassis or glow < H.From then
		dropBeam()
		return
	end
	if beamCar == car and beam and beam.Parent == chassis then
		return
	end
	dropBeam()
	local at = Instance.new("Attachment")
	at.Name = "Headlights"
	at.CFrame = CFrame.new(0, H.Up * Game.VehicleScale, -chassis.Size.Z / 2)
		* CFrame.Angles(-math.rad(H.Tilt), 0, 0)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Range = H.Range
	light.Angle = H.Angle
	light.Brightness = H.Brightness
	light.Color = rgb(H.Color)
	light.Shadows = false
	light.Parent = at
	at.Parent = chassis
	beam, beamCar = at, car
end

-- lighting ----------------------------------------------------------------------------------------------------

local function child<T>(className: string, name: string?): T
	local found = if name
		then Lighting:FindFirstChild(name)
		else Lighting:FindFirstChildOfClass(className)
	if found and found:IsA(className) then
		return found :: any
	end
	local made = Instance.new(className :: any)
	if name then
		made.Name = name
	end
	made.Parent = Lighting
	return made :: any
end

local function apply(look: { [string]: any }, clock: number)
	local sky = child("Sky") :: Sky
	local air = child("Atmosphere") :: Atmosphere
	local grade = child("ColorCorrectionEffect", "Grade") :: ColorCorrectionEffect
	local bloom = child("BloomEffect", "Bloom") :: BloomEffect
	local rays = child("SunRaysEffect", "Rays") :: SunRaysEffect
	local ambient, exposure = Interiors.blend(rgb(look.Ambient), look.Exposure)
	Lighting.ClockTime = clock
	Lighting.Brightness = look.Brightness
	Lighting.ExposureCompensation = exposure
	Lighting.Ambient = ambient
	Lighting.OutdoorAmbient = rgb(look.OutdoorAmbient)
	Lighting.ColorShift_Top = rgb(look.SunTint)
	air.Density = look.AirDensity
	air.Haze = look.AirHaze
	air.Glare = look.AirGlare
	air.Color = rgb(look.AirColor)
	air.Decay = rgb(look.AirDecay)
	grade.TintColor = rgb(look.Tint)
	grade.Saturation = look.Saturation
	bloom.Intensity = look.BloomIntensity
	bloom.Threshold = look.BloomThreshold
	rays.Intensity = look.SunRays
	sky.StarCount = math.floor(look.Stars + 0.5)
	sky.MoonAngularSize = Config.MoonSize
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Color = rgb(look.CloudColor)
	end
end

function DayNight.start()
	task.spawn(watchWindows)
	RunService.RenderStepped:Connect(function()
		local epoch = Lighting:GetAttribute("DayNightEpoch")
		local speed = Lighting:GetAttribute("DayNightSpeed")
		if typeof(epoch) ~= "number" or typeof(speed) ~= "number" then
			return
		end
		local t = Rules.phase(workspace:GetServerTimeNow(), epoch, speed, Config.Cycle)
		local s = Rules.sample(Config.Stops, Config.Looks, t, Config.Cycle)
		glow = s.look.Glow
		apply(s.look, s.clock)
		updateBeam()
	end)
end

return DayNight
