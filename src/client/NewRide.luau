--!strict
-- A new car's moment (any way it arrives: the garage, the Starter Pack): it turns once on a lit turntable in
-- the middle of the screen with the till, then the NEW RIDE! cheer and confetti (client/Guide). Waits its turn
-- for the middle of the screen (Style.stage); a tap skips the turn. Timings: Config/Callouts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Callouts = require(ReplicatedStorage.Shared.Config.Callouts)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Guide = require(script.Parent.Guide)
local Sfx = require(script.Parent.Sfx)
local Style = require(script.Parent.Style)

local NewRide = {}

local C, F = Style.colors, Style.fonts
local player = Players.LocalPlayer

-- marker parts in the vehicle templates (pivots, hand grips) that a picture shouldn't show (as in client/Hud)
local MARKERS =
	{ SteerPivot = true, GripL = true, GripR = true, StickLPivot = true, StickRPivot = true }

local gui = Instance.new("ScreenGui")
gui.Name = "NewRide"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6 -- over the HUD and the garage sheet
Style.fit(gui)

local function turntable(stats: Vehicles.Vehicle)
	local models = ReplicatedStorage:FindFirstChild("VehicleModels")
	local template = models and models:FindFirstChild(stats.id) :: Model?
	if not template then
		return
	end
	local card = Style.panel(gui)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.45)
	card.Size = UDim2.fromOffset(420, 270)
	Style.stroke(card, C.yellow, 3, 0)
	local vf = Instance.new("ViewportFrame")
	vf.Position = UDim2.fromOffset(8, 8)
	vf.Size = UDim2.new(1, -16, 0, 210)
	vf.BackgroundColor3 = Color3.fromRGB(46, 46, 54)
	vf.Ambient = Color3.fromRGB(150, 150, 170)
	vf.LightColor = Color3.fromRGB(255, 236, 200)
	vf.LightDirection = Vector3.new(-1, -1.5, -0.6)
	vf.ClipsDescendants = true -- the light sweep stays inside the picture
	vf.Parent = card
	local name = Style.label(card, string.upper(stats.name), 30, F.display, C.yellow)
	name.Position = UDim2.fromOffset(0, 222)
	name.Size = UDim2.new(1, 0, 0, 36)
	Style.outline(name, 2)
	-- a light sweep across the picture
	local sweep = Instance.new("Frame")
	sweep.BackgroundColor3 = Color3.new(1, 1, 1)
	sweep.BackgroundTransparency = 0.8
	sweep.BorderSizePixel = 0
	sweep.Size = UDim2.new(0, 60, 1, 0)
	sweep.Position = UDim2.fromOffset(-80, 0)
	sweep.ZIndex = 3
	sweep.Parent = vf

	local m = template:Clone()
	for _, part in m:GetChildren() do
		if MARKERS[part.Name] then
			part:Destroy()
		end
	end
	m.Parent = vf
	local cf, size = m:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vf
	vf.CurrentCamera = cam
	local dist = size.Magnitude * 1.6
	local centre = cf.Position

	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = card
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService
		:Create(
			sweep,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad),
			{ Position = UDim2.new(1, 20, 0, 0) }
		)
		:Play()
	Sfx.play("Till")

	local t0 = os.clock()
	local done = false
	local skip = Instance.new("TextButton")
	skip.BackgroundTransparency = 1
	skip.Text = ""
	skip.Size = UDim2.fromScale(1, 1)
	skip.ZIndex = 4
	skip:SetAttribute("Quiet", true)
	skip.Parent = card
	skip.Activated:Connect(function()
		done = true
	end)
	local spin = RunService.RenderStepped:Connect(function()
		local a = (os.clock() - t0) / Callouts.NewRideTurn * math.pi * 2 + math.rad(225)
		cam.CFrame =
			CFrame.lookAt(centre + Vector3.new(math.cos(a), 0.45, math.sin(a)).Unit * dist, centre)
	end)
	while not done and os.clock() - t0 < Callouts.NewRideHold do
		task.wait()
	end
	spin:Disconnect()
	TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
	task.delay(0.25, function()
		card:Destroy()
	end)
end

local function arrived(stats: Vehicles.Vehicle)
	task.delay(Style.stage(Callouts.NewRideHold), function()
		turntable(stats)
		local hud = player.PlayerGui:FindFirstChild("Hud")
		local garage = hud and hud:FindFirstChild("Garage") :: GuiObject?
		Guide.celebrate(
			"NEW RIDE!",
			if garage and garage.Visible
				then `{stats.name} is yours. Tap SPAWN to drive it!`
				else `{stats.name} is yours. Open the GARAGE to drive it!`
		)
	end)
end

local function ownedSet(): { [string]: boolean }
	local set = {}
	for _, id in string.split((player:GetAttribute("Owned") or "") :: string, ",") do
		if id ~= "" then
			set[id] = true
		end
	end
	return set
end

function NewRide.start()
	gui.Parent = player:WaitForChild("PlayerGui")
	while not player:GetAttribute("DataReady") do
		task.wait(0.5)
	end
	local known = ownedSet()
	player:GetAttributeChangedSignal("Owned"):Connect(function()
		local now = ownedSet()
		for id in now do
			local stats = Vehicles.ById[id]
			if not known[id] and stats then
				arrived(stats)
			end
		end
		known = now
	end)
end

return NewRide
