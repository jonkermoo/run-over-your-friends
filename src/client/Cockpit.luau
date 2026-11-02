--!strict
-- First-person driving view. V, the right-stick click or the phone VIEW button puts the camera at the driver's
-- eyes (measured off their head once seated, riding with the body on its suspension), hides the driver's own
-- head, face and head accessories on this screen only, and clears the car's glass a little. Hold the right
-- mouse button, push the right stick or drag on a phone to look around; it eases back to the road. The choice
-- is kept for the next vehicle. Numbers in Config/Cockpit; nothing here is sent to the server.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.Cockpit)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Drive = require(script.Parent.Drive)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Cockpit = {}

local G = 9.81
local PITCH = math.rad(-6) -- resting look, a touch down at the road

local wanted = false -- the player asked for first person
local active = false
local car: Model? = nil
local eye: Vector3? = nil -- in the sprung body's frame
local satAt = 0
local yaw, pitch = 0, 0 -- look offsets, radians
local lookedAt = 0
local looking = false -- right mouse held
local stick = Vector2.zero
local hidden: { [Instance]: boolean } = {}
local glass: BasePart? = nil

local function headOf(): BasePart?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

-- the driver's own head, face and anything worn on the head: hidden on this screen while inside
local function hideHead(on: boolean)
	local character = player.Character
	local head = headOf()
	if not character or not head then
		return
	end
	local function set(inst: Instance)
		if inst:IsA("BasePart") or inst:IsA("Decal") then
			inst.LocalTransparencyModifier = if on then 1 else 0
			hidden[inst] = on or nil
		end
	end
	set(head)
	for _, d in head:GetDescendants() do
		set(d)
	end
	for _, acc in character:GetChildren() do
		local handle = acc:IsA("Accessory") and acc:FindFirstChild("Handle")
		local weld = handle and handle:FindFirstChild("AccessoryWeld")
		if handle and weld and weld:IsA("Weld") and (weld.Part0 == head or weld.Part1 == head) then
			set(handle)
			for _, d in handle:GetDescendants() do
				set(d)
			end
		end
	end
end

local function restore()
	for inst in hidden do
		if inst.Parent then
			(inst :: any).LocalTransparencyModifier = 0
		end
	end
	table.clear(hidden)
	if glass then
		glass.LocalTransparencyModifier = 0
	end
end

local function exit()
	if not active then
		return
	end
	active = false
	restore()
	car, eye, glass = nil, nil, nil
	camera.CameraType = Enum.CameraType.Custom
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	Drive.view.firstPerson = false
end

-- the eye in the sprung body's frame, just ahead of the head (the cabins keep their roofs clear of it:
-- tools/blender/export_vehicles.py reports the closest surface to each driver's eye)
local function measure(head: BasePart, body: BasePart): Vector3
	local cf = body.CFrame
	return cf:PointToObjectSpace(
		head.Position + cf.UpVector * Config.eyeUp + cf.LookVector * Config.eyeForward
	)
end

function Cockpit.toggle()
	wanted = not wanted
	if not wanted then
		exit()
	end
end

function Cockpit.isOn(): boolean
	return wanted
end

local function enter(model: Model)
	active = true
	car, eye = model, nil
	satAt = os.clock()
	yaw, pitch = 0, 0
	local g = model:FindFirstChild("Glass")
	glass = if g and g:IsA("BasePart") then g else nil
	if glass then
		local base = glass.Transparency
		glass.LocalTransparencyModifier =
			math.clamp((Config.glass - base) / math.max(1 - base, 0.01), 0, 1)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	Drive.view.firstPerson = true
end

local function step(dt: number)
	local model = Drive.view.car
	local head = headOf()
	local body = model and model:FindFirstChild("Sprung")
	if
		not wanted
		or not Drive.state.driving
		or not model
		or not head
		or not body
		or not body:IsA("BasePart")
	then
		exit()
		return
	end
	if not active or model ~= car then
		exit()
		enter(model)
	end
	local now = os.clock()
	if not eye and now - satAt > Config.settle then
		eye = measure(head, body)
	end
	hideHead(true)

	-- look around: mouse while the right button is held, the right stick, or a drag (all set yaw/pitch)
	if stick.Magnitude > 0.15 then
		yaw -= stick.X * math.rad(Config.stickSpeed) * dt
		pitch += stick.Y * math.rad(Config.stickSpeed) * dt
		lookedAt = now
	end
	UserInputService.MouseBehavior = if looking
		then Enum.MouseBehavior.LockCurrentPosition
		else Enum.MouseBehavior.Default
	yaw = math.clamp(yaw, -math.rad(Config.lookYaw), math.rad(Config.lookYaw))
	pitch = math.clamp(pitch, -math.rad(Config.lookDown), math.rad(Config.lookUp))
	if not looking and now - lookedAt > Config.recentreAfter then
		local k = math.min(1, dt * Config.recentreRate)
		yaw -= yaw * k
		pitch -= pitch * k
	end

	-- the head turns a little into the turn and is pushed about by acceleration
	local cf = (body :: BasePart).CFrame
	local stats = Vehicles.ById[(model:GetAttribute("VehicleId") or "") :: string]
	local lock = if stats then math.rad(stats.maxSteer) else 0.6
	local turn = math.rad(Config.turnLook) * math.clamp(Drive.view.steer / lock, -1, 1)
	local a = Drive.view.accel / G * Config.gSway
	local sway = Vector3.new(
		-math.clamp(a.X, -Config.gSwayMax, Config.gSwayMax),
		0,
		math.clamp(a.Z, -Config.gSwayMax, Config.gSwayMax)
	)
	local at = if eye
		then cf:PointToWorldSpace(eye + sway)
		else head.Position + cf.UpVector * Config.eyeUp + cf.LookVector * Config.eyeForward
	camera.CFrame = CFrame.new(at)
		* cf.Rotation
		* CFrame.Angles(0, yaw + turn, 0)
		* CFrame.Angles(PITCH + pitch, 0, 0)
end

local function keyCodes(names: { string }): { Enum.KeyCode }
	local out = {}
	for _, n in names do
		local ok, code = pcall(function()
			return (Enum.KeyCode :: any)[n]
		end)
		if ok and code then
			table.insert(out, code)
		end
	end
	return out
end

function Cockpit.start()
	local codes = keyCodes(Config.keys)
	for _, c in keyCodes(Config.pads) do
		table.insert(codes, c)
	end
	ContextActionService:BindAction("RoyfView", function(_, state)
		if state == Enum.UserInputState.Begin and Drive.state.driving then
			Cockpit.toggle()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(codes))

	UserInputService.InputBegan:Connect(function(input, used)
		if input.UserInputType == Enum.UserInputType.MouseButton2 and not used then
			looking = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			looking = false
			lookedAt = os.clock()
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.zero
		end
	end)
	UserInputService.InputChanged:Connect(function(input, used)
		if not active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement and looking then
			yaw -= math.rad(input.Delta.X * Config.mouseSpeed)
			pitch -= math.rad(input.Delta.Y * Config.mouseSpeed)
			lookedAt = os.clock()
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.UserInputType == Enum.UserInputType.Touch and not used then
			-- drags on the right half of the screen (the left half steers)
			if input.Position.X > camera.ViewportSize.X / 2 then
				yaw -= math.rad(input.Delta.X * Config.touchSpeed)
				pitch -= math.rad(input.Delta.Y * Config.touchSpeed)
				lookedAt = os.clock()
			end
		end
	end)
	-- after the default camera, before the shake (Fx, Camera + 1)
	RunService:BindToRenderStep("RoyfCockpit", Enum.RenderPriority.Camera.Value, step)
end

return Cockpit
