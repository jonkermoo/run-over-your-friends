--!strict
-- Far stand-ins for the buildings: one plain box per house, shop, office and farm building, in its wall colour
-- (a gabled house's box also gets its roof, in the roof's colour), in a Persistent model so it is always on
-- every client. A building streams in and out whole (Atomic); the client (Skyline.luau) hides a box while its
-- real building is loaded, so from afar the town, the skyline and the suburbs never vanish to bare road.
-- Each building gets a `Sky` number attribute; its box is named the same. (Model.LevelOfDetail can't be set by
-- a game script, and the engine makes no stand-ins for models built at run time.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World = require(ReplicatedStorage.Shared.Config.World)

local SkylineKit = {}

local function kindOf(name: string): boolean
	local base = string.gsub(name, "%d+$", "")
	return table.find(World.Skyline.Kinds, base) ~= nil
end

-- the box round a building's walls, in the building's own frame, and the colour most of its walls are
local function standIn(model: Model): (CFrame?, Vector3?, Color3?)
	local frame = model:GetPivot()
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	local weight: { [string]: number } = {}
	local colours: { [string]: Color3 } = {}
	local any = false
	for _, p in model:GetDescendants() do
		if not p:IsA("BasePart") or p.Transparency >= 0.5 then
			continue
		end
		local s = p.Size
		if math.max(s.X, s.Y, s.Z) < World.Skyline.MinPart then
			continue
		end
		any = true
		local local_ = frame:ToObjectSpace(p.CFrame)
		local h = s / 2
		for _, c in { -1, 1 } do
			for _, d in { -1, 1 } do
				for _, e in { -1, 1 } do
					local v = local_ * Vector3.new(c * h.X, d * h.Y, e * h.Z)
					lo = lo:Min(v)
					hi = hi:Max(v)
				end
			end
		end
		-- upright faces count most: that is what is seen from afar
		local area = s.Y * math.max(s.X, s.Z)
		local key = p.Color:ToHex()
		weight[key] = (weight[key] or 0) + area
		colours[key] = p.Color
	end
	if not any then
		return nil, nil, nil
	end
	local best, bestW = nil :: string?, -1
	for k, w in weight do
		if w > bestW then
			best, bestW = k, w
		end
	end
	local size = hi - lo
	local centre = frame * ((lo + hi) / 2)
	return frame.Rotation + centre, size, colours[best :: string]
end

-- a gabled house's roof on its stand-in (World.Skyline RoofMinWall): the box is cut down to the walls and a box
-- turned 45 degrees about the ridge sits on it, its lower half hidden in the walls (and the ground); a child of
-- the stand-in, so it shows and hides with it
local function roof(box: Part, ridge: string, colour: Color3)
	local s = box.Size
	local frame = box.CFrame
	local across = if ridge == "x" then s.Z else s.X
	local along = if ridge == "x" then s.X else s.Z
	local bottom = -s.Y / 2
	-- never above the box's own top, so the walls never poke past the real ones
	local wallsTop =
		math.min(math.max(s.Y / 2 - across / 2, bottom + World.Skyline.RoofMinWall), s.Y / 2)
	box.Size = Vector3.new(s.X, wallsTop - bottom, s.Z)
	box.CFrame = frame * CFrame.new(0, (bottom + wallsTop) / 2, 0)
	local side = across / math.sqrt(2)
	local top = box:Clone()
	top.Name = "Roof"
	top.Color = colour
	if ridge == "x" then
		top.Size = Vector3.new(along, side, side)
		top.CFrame = frame * CFrame.new(0, wallsTop, 0) * CFrame.Angles(math.pi / 4, 0, 0)
	else
		top.Size = Vector3.new(side, side, along)
		top.CFrame = frame * CFrame.new(0, wallsTop, 0) * CFrame.Angles(0, 0, math.pi / 4)
	end
	top.Parent = box
end

function SkylineKit.build(map: Instance, buildings: Instance): Model
	local skyline = Instance.new("Model")
	skyline.Name = "Skyline"
	skyline.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local n = 0
	for _, m in buildings:GetChildren() do
		if not (m:IsA("Model") and kindOf(m.Name)) then
			continue
		end
		local cf, size, colour = standIn(m)
		if not (cf and size and colour) then
			continue
		end
		n += 1
		m:SetAttribute("Sky", n)
		local box = Instance.new("Part")
		box.Name = tostring(n)
		box.Anchored = true
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.CastShadow = false
		box.Material = Enum.Material.SmoothPlastic
		box.TopSurface = Enum.SurfaceType.Smooth
		box.BottomSurface = Enum.SurfaceType.Smooth
		box.Color = colour
		-- a hair inside the real walls, so a box that is still showing never pokes through
		box.Size = size - Vector3.one * World.Skyline.Inset
		box.CFrame = cf
		local ridge = m:GetAttribute("Ridge")
		local roofColour = m:GetAttribute("RoofColour")
		if (ridge == "x" or ridge == "z") and typeof(roofColour) == "Color3" then
			roof(box, ridge, roofColour)
		end
		box.Parent = skyline
	end
	skyline.Parent = map
	return skyline
end

return SkylineKit
