--!strict
-- Finding the giant (Giant in Town) from anywhere on the map, on this screen only: a tall light column
-- rises from its head, and a red plate with GIANT and the distance pins to the screen edge pointing the
-- way. Once the giant is in view the plate floats over its head instead; up close it hides and the name
-- tag (client/NameTags) takes over. Gone once the giant is toppled or walks off. Numbers: Config/Events
-- GiantFinder.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Events)
local CrowdConfig = require(ReplicatedStorage.Shared.Config.Crowd)
local Style = require(script.Parent.Style)

local GiantFinder = {}

local G = Config.GiantFinder
local C, F = Style.colors, Style.fonts
local tint = CrowdConfig.Tags.Giant
local RED = Color3.fromRGB(tint[1], tint[2], tint[3])

local gui = Instance.new("ScreenGui")
gui.Name = "GiantFinder"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true -- camera points and this screen share one origin
gui.Enabled = false
Style.fit(gui)

-- the diamond that points the way, tucked behind the plate's edge
local pointer = Instance.new("Frame")
pointer.Name = "Pointer"
pointer.AnchorPoint = Vector2.new(0.5, 0.5)
pointer.Size = UDim2.fromOffset(G.Pointer, G.Pointer)
pointer.Rotation = 45
pointer.BackgroundColor3 = RED
pointer.BorderSizePixel = 0
pointer.Parent = gui
Style.stroke(pointer, C.ink, 3)

local plate = Style.panel(gui)
plate.Name = "Plate"
plate.AnchorPoint = Vector2.new(0.5, 0.5)
plate.Size = UDim2.fromOffset(G.PlateWidth, G.PlateHeight)
plate.BackgroundColor3 = RED
plate.ZIndex = 2
local name = Style.label(plate, "GIANT", 22, F.display, C.text)
name.Position = UDim2.fromOffset(0, 4)
name.Size = UDim2.new(1, 0, 0, 24)
name.ZIndex = 3
Style.outline(name, 2)
local dist = Style.label(plate, "", 16, F.heavy, C.text)
dist.Position = UDim2.fromOffset(0, 27)
dist.Size = UDim2.new(1, 0, 0, 18)
dist.ZIndex = 3
Style.outline(dist, 2)

-- the light column, a local part only this player sees
local beam = Instance.new("Part")
beam.Name = "GiantBeam"
beam.Shape = Enum.PartType.Cylinder -- along its X axis, turned upright below
beam.Size = Vector3.new(G.BeamHeight, G.BeamWidth, G.BeamWidth)
beam.Material = Enum.Material.Neon
beam.Color = RED
beam.Transparency = G.BeamTransparency
beam.Anchored = true
beam.CanCollide = false
beam.CanQuery = false
beam.CanTouch = false
beam.CastShadow = false
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local giant: Model? = nil
local scanAt = 0

local function findGiant(): Model?
	local folder = workspace:FindFirstChild("Npcs")
	if not folder then
		return nil
	end
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and typeof(m:GetAttribute("GiantHp")) == "number" then
			return m
		end
	end
	return nil
end

local function hide()
	gui.Enabled = false
	beam.Parent = nil
end

local function update()
	local now = os.clock()
	if now >= scanAt or (giant and not giant.Parent) then
		scanAt = now + G.ScanSeconds
		giant = findGiant()
	end
	local m = giant
	local cam = workspace.CurrentCamera
	local head = m and m:FindFirstChild("Head") :: BasePart?
	if not m or not cam or not head or m:GetAttribute("Down") then
		hide()
		return
	end
	local top = head.Position + Vector3.new(0, head.Size.Y / 2, 0)
	beam.CFrame = CFrame.new(top + Vector3.new(0, G.BeamHeight / 2, 0)) * UPRIGHT
	beam.Parent = workspace

	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character.PrimaryPart
	local from = if root then root.Position else cam.CFrame.Position
	local studs = (Vector3.new(top.X, 0, top.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
	if studs < G.HideWithin then
		gui.Enabled = false
		return
	end
	gui.Enabled = true
	dist.Text = `{math.floor(studs + 0.5)}{G.Unit}`

	-- everything below in real pixels, then divided by the shared scale for offsets
	local s = Style.scale()
	local vp = cam.ViewportSize
	local center = vp / 2
	local margin = G.EdgeMargin * s
	local sp = cam:WorldToViewportPoint(top)
	local p = Vector2.new(sp.X, sp.Y)
	local behind = sp.Z < 0
	local at: Vector2, dir: Vector2
	if
		not behind
		and p.X >= margin
		and p.X <= vp.X - margin
		and p.Y >= margin
		and p.Y <= vp.Y - margin
	then
		-- in view: float over its head, pointing down at it
		at, dir = p - Vector2.new(0, G.AboveHead * s), Vector2.new(0, 1)
	else
		-- off screen: pin to the edge in its direction (behind the camera the projection is mirrored)
		local d = if behind then center - p else p - center
		if d.Magnitude < 1 then
			d = Vector2.new(0, 1)
		end
		local kx = if math.abs(d.X) > 1e-3 then (center.X - margin) / math.abs(d.X) else math.huge
		local ky = if math.abs(d.Y) > 1e-3 then (center.Y - margin) / math.abs(d.Y) else math.huge
		at, dir = center + d * math.min(kx, ky), d.Unit
	end
	local pos = at / s
	plate.Position = UDim2.fromOffset(pos.X, pos.Y)
	-- the pointer sits where the plate's edge meets the way to the giant
	local hw, hh = G.PlateWidth / 2, G.PlateHeight / 2
	local tx = if math.abs(dir.X) > 1e-3 then hw / math.abs(dir.X) else math.huge
	local ty = if math.abs(dir.Y) > 1e-3 then hh / math.abs(dir.Y) else math.huge
	local tip = pos + dir * (math.min(tx, ty) + G.Pointer * 0.3)
	pointer.Position = UDim2.fromOffset(tip.X, tip.Y)
end

function GiantFinder.start()
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return GiantFinder
