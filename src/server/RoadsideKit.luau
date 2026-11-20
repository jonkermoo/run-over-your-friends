--!strict
-- Roadside dressing outside the city (Config/Roadside): power poles with sagging wires along a line, split-rail
-- fences along a straight stretch, and a bus stop. Poles and fences never collide (cars drive through them,
-- like the tufts); the bus stop is smashable street furniture.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Roadside)
local Greenery = require(script.Parent.Greenery)

local RoadsideKit = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- a wire's end on a pole's crossbar (`side` -1 or 1); its axis points down, so a beam's curve sags
local function arm(pole: BasePart, side: number): Attachment
	local P = Cfg.Poles
	local a = Instance.new("Attachment")
	a.Name = if side < 0 then "WireL" else "WireR"
	local h = pole.Size.Y
	a.CFrame = CFrame.new(side * P.ArmAcross * h, P.ArmUp * h, 0)
		* CFrame.Angles(0, 0, -math.pi / 2)
	a.Parent = pole
	return a
end

local function wire(from: Attachment, to: Attachment)
	local P = Cfg.Poles
	local b = Instance.new("Beam")
	b.Attachment0 = from
	b.Attachment1 = to
	b.Width0, b.Width1 = P.WireWidth, P.WireWidth
	b.CurveSize0, b.CurveSize1 = P.Sag, -P.Sag
	b.Color = ColorSequence.new(rgb(P.WireColour))
	b.FaceCamera = true
	b.Segments = P.WireSegments
	b.LightInfluence = 1
	b.Parent = from.Parent
end

-- poles every Poles.Every along `pts` (the line they stand on, ground heights in it), skipping spots `blocked`
-- says no to; wires between neighbours that are close enough. Returns how many poles.
function RoadsideKit.poles(
	parent: Instance,
	pts: { Vector3 },
	blocked: (Vector3) -> boolean
): number
	local P = Cfg.Poles
	local placed = 0
	local last: BasePart? = nil
	local walked = P.Every / 2
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local seg = (b - a).Magnitude
		local t = 0
		while seg > 0 and walked + (seg - t) >= P.Every do
			t += P.Every - walked
			walked = 0
			local at = a:Lerp(b, t / seg)
			local along = (b - a).Unit
			if blocked(at) then
				continue
			end
			local pole = Greenery.place(
				parent,
				"Pole",
				at - Vector3.new(0, P.Sink, 0),
				nil,
				P.Height,
				math.atan2(-along.Z, along.X) + math.pi / 2, -- the crossbar across the road
				rgb(P.Colour)
			)
			pole.Material = Enum.Material.Wood
			pole.CastShadow = true
			local l, r = arm(pole, -1), arm(pole, 1)
			if last and (last.Position - pole.Position).Magnitude <= P.MaxSpan then
				wire(last:FindFirstChild("WireL") :: Attachment, l)
				wire(last:FindFirstChild("WireR") :: Attachment, r)
			end
			last = pole
			placed += 1
		end
		walked += seg - t
	end
	return placed
end

-- split-rail fence sections from `a` to `b` (ground heights in them); returns how many
function RoadsideKit.fence(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	skip: (Vector3) -> boolean
): number
	local F = Cfg.Fence
	local len = (b - a).Magnitude
	local n = math.floor(len / F.Length)
	if n < 1 then
		return 0
	end
	local along = (b - a).Unit
	local turn = math.atan2(-along.Z, along.X)
	local placed = 0
	for k = 0, n - 1 do
		local mid = a + along * ((k + 0.5) * F.Length)
		if skip(mid) then
			continue
		end
		local f = Greenery.place(
			parent,
			"RailFence",
			mid - Vector3.new(0, F.Sink, 0),
			F.Length,
			nil,
			turn,
			rgb(F.Colour)
		)
		f.Size = Vector3.new(f.Size.X, F.Height, f.Size.Z)
		f.CFrame = CFrame.new(mid + Vector3.new(0, F.Height / 2 - F.Sink, 0))
			* CFrame.Angles(0, turn, 0)
		f.Material = Enum.Material.Wood
		placed += 1
	end
	return placed
end

-- a bus stop at `at` (on the ground) facing the road along `face`: posts, a glass back, a yellow roof, a bench
-- and a blue stop sign; one smashable model
function RoadsideKit.busStop(parent: Instance, at: Vector3, face: Vector3)
	local B = Cfg.BusStop
	local w, h, d = B.Shelter[1], B.Shelter[2], B.Shelter[3]
	local m = Instance.new("Model")
	m.Name = "BusStop"
	m:SetAttribute("Prop", "BusStop")
	m.Parent = parent
	local cf = CFrame.lookAt(at, at + face)
	local frame = rgb(B.Frame)
	for _, sx in { -1, 1 } do
		part(
			m,
			Vector3.new(0.5, h, 0.5),
			cf * CFrame.new(sx * (w / 2 - 0.3), h / 2, d / 2 - 0.3),
			frame,
			Enum.Material.Metal
		)
	end
	local glass = part(
		m,
		Vector3.new(w - 0.6, h - 1.6, 0.3),
		cf * CFrame.new(0, h / 2 + 0.3, d / 2 - 0.3),
		rgb(B.Glass),
		Enum.Material.Glass
	)
	glass.Transparency = 0.45
	part(m, Vector3.new(w + 1, 0.5, d + 0.8), cf * CFrame.new(0, h + 0.25, 0.1), rgb(B.Roof))
	part(
		m,
		Vector3.new(w - 2, 0.5, 1.6),
		cf * CFrame.new(0, 1.6, d / 2 - 1.4),
		rgb(B.Bench),
		Enum.Material.WoodPlanks
	)
	local signAt = cf * CFrame.new(w / 2 + 2, 0, -d / 2 + 0.5)
	part(m, Vector3.new(0.4, 8, 0.4), signAt * CFrame.new(0, 4, 0), frame, Enum.Material.Metal)
	local disc = part(
		m,
		Vector3.new(0.3, 2.6, 2.6),
		signAt * CFrame.new(0, 8.4, 0) * CFrame.Angles(0, math.pi / 2, 0),
		rgb(B.SignColour)
	)
	disc.Shape = Enum.PartType.Cylinder
end

return RoadsideKit
