--!strict
-- Finding the giant (Giant in Town) from anywhere on the map, on this screen only: a tall light column
-- rises from its head, and a red plate with GIANT and the distance pins to the screen edge pointing the
-- way. Once the giant is in view the plate floats over its head instead; up close it hides and the name
-- tag (client/NameTags) takes over. Gone once the giant is toppled or walks off. Numbers: Config/Events
-- GiantFinder.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Events)
local CrowdConfig = require(ReplicatedStorage.Shared.Config.Crowd)
local Clear = require(ReplicatedStorage.Shared.Rules.Clear)
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

-- the light column: a billboard (drawn like screen UI, so the air's haze can't wash it out from across
-- the map), a fixed number of studs wide plus a few pixels so it never thins to nothing
local beam = Instance.new("BillboardGui")
beam.Name = "GiantBeam"
beam.ResetOnSpawn = false
beam.LightInfluence = 0
beam.AlwaysOnTop = false -- buildings in front still hide its foot
beam.Size = UDim2.new(G.BeamWidth, G.BeamMinPixels, G.BeamHeight, 0)
-- its foot on the giant's head, rising straight up the screen (a billboard stays upright on screen, so
-- centring it high in the sky would lean it away from the giant)
beam.SizeOffset = Vector2.new(0, 0.5)
beam.Enabled = false
local glow = Instance.new("Frame")
glow.Size = UDim2.fromScale(1, 1)
glow.BackgroundColor3 = RED
glow.BackgroundTransparency = G.BeamTransparency
glow.BorderSizePixel = 0
glow.Parent = beam
local core = Instance.new("Frame")
core.AnchorPoint = Vector2.new(0.5, 0)
core.Position = UDim2.fromScale(0.5, 0)
core.Size = UDim2.fromScale(G.BeamCore, 1)
core.BackgroundColor3 = Color3.new(1, 1, 1)
core.BackgroundTransparency = G.BeamTransparency
core.BorderSizePixel = 0
core.Parent = beam

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
	beam.Enabled = false
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
	if beam.Adornee ~= head then
		beam.Adornee = head
		beam.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2, 0)
	end
	beam.Enabled = true

	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character.PrimaryPart
	local from = if root then root.Position else cam.CFrame.Position
	local studs = (Vector3.new(top.X, 0, top.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
	-- close by the name tag takes over; an open sheet (garage, store, goals) has the screen
	if studs < G.HideWithin or Style.sheetOpen() then
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
	-- never past the margin (a short window, or the head right at the top)
	at = Vector2.new(
		math.clamp(at.X, margin, vp.X - margin),
		math.clamp(at.Y, margin, vp.Y - margin)
	)
	-- off the controls card and the speedometer (they're in inset space; this screen ignores the inset)
	local inset = GuiService:GetGuiInset()
	local keep = Style.keepClear()
	for _, r in keep do
		r.x += inset.X
		r.y += inset.Y
	end
	local cx, cy = Clear.slide(
		at.X,
		at.Y,
		(G.PlateWidth + G.Pointer * 2) * s,
		(G.PlateHeight + G.Pointer * 2) * s,
		keep,
		vp.X,
		vp.Y,
		G.ClearGap * s
	)
	at = Vector2.new(cx, cy)
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
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui.Parent = playerGui
	beam.Parent = playerGui
	RunService.RenderStepped:Connect(update)
end

return GiantFinder
