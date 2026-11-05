--!strict
-- First-person driving view. V, the right-stick click or the phone VIEW button puts the camera at the driver's
-- eyes (a fixed spot above the seat, riding with the body on its suspension, so every avatar gets the same
-- view), hides whatever of the driver is near the eye on this screen only (head, hair, hats, however they're
-- worn; the arms and hands stay), and clears the car's glass a little. Hold the right
-- mouse button, push the right stick or drag on a phone to look around; it eases back to the road. The choice
-- is kept for the next vehicle. Numbers in Config/Cockpit; nothing here is sent to the server.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.Cockpit)
local Game = require(ReplicatedStorage.Shared.Config.Game)
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
local eye = Vector3.zero -- in the sprung body's frame
local yaw, pitch = 0, 0 -- look offsets, radians
local lookedAt = 0
local looking = false -- right mouse held
local stick = Vector2.zero
local hidden: { [Instance]: boolean } = {}
local glass: BasePart? = nil

-- arms and hands stay in view (they hold the wheel), even when they come near the eye
local KEEP = { "Hand", "LowerArm", "UpperArm", "Left Arm", "Right Arm" }

local function kept(part: BasePart): boolean
	if part.Parent and part.Parent:IsA("Accessory") then
		return false
	end
	for _, k in KEEP do
		if string.find(part.Name, k, 1, true) then
			return true
		end
	end
	return false
end

-- how far a point is from a part's box
local function gap(part: BasePart, at: Vector3): number
	local p = part.CFrame:PointToObjectSpace(at)
	local h = part.Size / 2
	local q = Vector3.new(
		math.clamp(p.X, -h.X, h.X),
		math.clamp(p.Y, -h.Y, h.Y),
		math.clamp(p.Z, -h.Z, h.Z)
	)
	return (p - q).Magnitude
end

-- every frame: hide what of the driver is near the eye, show the rest (Roblox's own camera fades a character
-- whose camera comes close; this runs after it and sets every part)
local function hideNear(at: Vector3)
	local character = player.Character
	if not character then
		return
	end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local near = part.Name == "Head"
				or (not kept(part) and gap(part, at) < Config.hideRadius * Game.BodyScale)
			local m = if near then 1 else 0
			part.LocalTransparencyModifier = m
			hidden[part] = true
			for _, d in part:GetChildren() do
				if d:IsA("Decal") then
					d.LocalTransparencyModifier = m
					hidden[d] = true
				end
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
	car, glass = nil, nil
	camera.CameraType = Enum.CameraType.Custom
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	Drive.view.firstPerson = false
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

-- the eye sits over the seat, in the sprung body's frame (the cabins keep their roofs clear of it:
-- tools/blender/export_vehicles.py reports the closest surface to each driver's eye)
local function enter(model: Model, body: BasePart, seat: BasePart)
	active = true
	car = model
	eye = body.CFrame:PointToObjectSpace(
		seat.CFrame * (Vector3.new(0, Config.eyeAboveSeat, -Config.eyeAhead) * Game.BodyScale)
	)
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
	local body = model and model:FindFirstChild("Sprung")
	local seat = model and model:FindFirstChild("DriverSeat")
	if
		not wanted
		or not Drive.state.driving
		or not model
		or not body
		or not body:IsA("BasePart")
		or not seat
		or not seat:IsA("BasePart")
	then
		exit()
		return
	end
	if not active or model ~= car then
		exit()
		enter(model, body, seat)
	end
	local now = os.clock()

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
	local at = cf:PointToWorldSpace(eye + sway)
	hideNear(cf:PointToWorldSpace(eye))
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
	-- after the default camera (and its character fading), before the shake (Fx, Camera + 2)
	RunService:BindToRenderStep("RoyfCockpit", Enum.RenderPriority.Camera.Value + 1, step)
end

return Cockpit
