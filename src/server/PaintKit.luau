--!strict
-- Flat ground paint drawn as frames on one SurfaceGui on one invisible, non-colliding part, so a road segment's
-- lines or a car park's bays cost one part instead of one per stripe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local S = require(ReplicatedStorage.Shared.Config.Streets)

local PaintKit = {}

-- a level patch `sizeX` by `sizeZ` with its centre at `at` (its top a hair above the ground there). Returns a
-- function that paints a rectangle: centre offset (dx, dz) from `at`, extent (ex, ez), in world axes.
function PaintKit.patch(
	parent: Instance,
	at: Vector3,
	sizeX: number,
	sizeZ: number
): (dx: number, dz: number, ex: number, ez: number, color: Color3) -> ()
	local carrier = Instance.new("Part")
	carrier.Name = "Paint"
	carrier.Anchored = true
	carrier.Size = Vector3.new(sizeX, S.PaintThick, sizeZ)
	carrier.CFrame = CFrame.new(at)
	carrier.Transparency = 1
	carrier.CanCollide = false
	carrier.CanQuery = false
	carrier.CanTouch = false
	carrier.CastShadow = false
	carrier.Parent = parent
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = S.PaintPixelsPerStud
	gui.LightInfluence = 1
	gui.MaxDistance = S.PaintDrawDistance
	gui.ClipsDescendants = true
	gui.Parent = carrier
	-- on a Top face the gui's x runs along the part's -Z and its y along +X (measured in Studio)
	return function(dx: number, dz: number, ex: number, ez: number, color: Color3)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5 - dz / sizeZ, 0.5 + dx / sizeX)
		f.Size = UDim2.fromScale(ez / sizeZ, ex / sizeX)
		f.Parent = gui
	end
end

return PaintKit
