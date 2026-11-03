--!strict
-- Dresses a jump ramp (a WedgePart whose high end is its +Z side) in the look from Config/Ramps: a diamond-plate
-- deck, dark side skirts and rails, a hazard band across the lip, a steel strip across the foot and chevrons
-- up the slope. Everything added is paint: no collisions, no raycasts, no shadows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local R = require(ReplicatedStorage.Shared.Config.Ramps)

local RampKit = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function trim(
	parent: Instance,
	class: string,
	size: Vector3,
	cf: CFrame,
	color: Color3
): BasePart
	local p = Instance.new(class) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function RampKit.dress(w: WedgePart)
	local parent = w.Parent :: Instance
	local s = w.Size
	w.Material = (Enum.Material :: any)[R.Deck]
	local railColour = rgb(R.RailColour)
	-- skirts over both triangular sides
	for _, side in { -1, 1 } do
		trim(
			parent,
			"WedgePart",
			Vector3.new(0.1, s.Y, s.Z),
			w.CFrame * CFrame.new(side * (s.X / 2 + 0.05), 0, 0),
			railColour
		)
	end
	-- the slope's own frame: x across, z up the slope, y out of the deck; its middle is the wedge's centre
	local L = math.sqrt(s.Y * s.Y + s.Z * s.Z)
	local slope = w.CFrame * CFrame.Angles(-math.atan2(s.Y, s.Z), 0, 0)
	local function on(x: number, d: number, up: number): CFrame
		return slope * CFrame.new(x, R.Lift + up, d)
	end
	for _, side in { -1, 1 } do
		trim(
			parent,
			"Part",
			Vector3.new(R.Rail, R.Rail, L),
			on(side * (s.X / 2 - R.Rail / 2), 0, R.Rail / 2),
			railColour
		)
	end
	-- the hazard band at the top, the steel strip at the foot
	local inside = s.X - 2 * R.Rail
	local cells = math.max(2, math.floor(inside / R.HazardStripe))
	for k = 0, cells - 1 do
		trim(
			parent,
			"Part",
			Vector3.new(inside / cells, 0.1, R.Lip),
			on(-inside / 2 + (k + 0.5) * inside / cells, L / 2 - R.Lip / 2, 0),
			rgb(if k % 2 == 0 then R.Hazard else R.HazardDark)
		)
	end
	trim(
		parent,
		"Part",
		Vector3.new(inside, 0.1, R.Foot),
		on(0, -L / 2 + R.Foot / 2, 0),
		rgb(R.FootColour)
	)
	-- chevrons, evenly up the slope between the foot strip and the band
	local reach = R.ChevronSpan * s.X
	local drop = reach * 0.6
	local low, high = -L / 2 + R.Foot + drop + 1, L / 2 - R.Lip - 1
	if high <= low then
		return
	end
	local n = math.max(1, math.floor((high - low) / R.ChevronSpacing))
	local arm = math.sqrt(reach * reach + drop * drop)
	for k = 0, n - 1 do
		local apex = if n == 1 then (low + high) / 2 else low + k * (high - low) / (n - 1)
		for _, side in { -1, 1 } do
			local yaw = math.atan2(side * reach, -drop)
			trim(
				parent,
				"Part",
				Vector3.new(R.ChevronWidth, 0.1, arm),
				on(side * reach / 2, apex - drop / 2, 0.02) * CFrame.Angles(0, yaw, 0),
				rgb(R.Chevron)
			)
		end
	end
end

return RampKit
