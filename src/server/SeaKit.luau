--!strict
-- Life on the sea (Config/Sea): boats on their loops off the west coast and the lighthouse's beam, in a
-- Persistent model so they show from anywhere on the island (each client moves them: client SeaLife), and a
-- foam line along the beaches (static, streamed like the rest). Nothing here collides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Sea)
local LandCfg = require(ReplicatedStorage.Shared.Config.Land)
local Land = require(ReplicatedStorage.Shared.Rules.Land)
local Sea = require(ReplicatedStorage.Shared.Rules.Sea)

local SeaKit = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function piece(
	parent: Instance,
	class: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3
): BasePart
	local p = Instance.new(class) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Parent = parent
	return p
end

-- one boat, built round the origin (bow toward -z) and then set on its loop
local function boat(parent: Instance, b: Cfg.Boat, centre: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "Boat"
	local hs = Cfg.Hull
	local hull =
		piece(m, "Part", Vector3.new(hs[1], hs[2], hs[3]), CFrame.new(0, 0.5, 0), rgb(b.hull))
	piece(
		m,
		"WedgePart",
		Vector3.new(hs[1], hs[2], Cfg.Bow),
		CFrame.new(0, 0.5, -(hs[3] + Cfg.Bow) / 2), -- full height against the hull, raked down to the stem
		rgb(b.hull)
	)
	local white = rgb(Cfg.White)
	if b.kind == "sail" then
		piece(
			m,
			"Part",
			Vector3.new(0.8, Cfg.Mast, 0.8),
			CFrame.new(0, 2.5 + Cfg.Mast / 2, -5),
			white
		)
		piece(
			m,
			"WedgePart",
			Vector3.new(0.6, Cfg.Sail[2], Cfg.Sail[1]),
			-- turned so its tall edge is at the mast
			CFrame.new(0, 3 + Cfg.Sail[2] / 2, -5 + Cfg.Sail[1] / 2 + 0.5)
				* CFrame.Angles(0, math.pi, 0),
			white
		)
	else
		local c = Cfg.Cabin
		piece(m, "Part", Vector3.new(c[1], c[2], c[3]), CFrame.new(0, 2.5 + c[2] / 2, 5), white)
		piece(
			m,
			"Part",
			Vector3.new(c[1] + 0.4, 1.2, c[3] + 0.4),
			CFrame.new(0, 3.1 + c[2], 5),
			rgb(Cfg.CabinRoof)
		)
	end
	local wake = piece(
		m,
		"Part",
		Vector3.new(Cfg.Wake[1], 0.3, Cfg.Wake[2]),
		CFrame.new(0, -0.6, (hs[3] + Cfg.Wake[2]) / 2),
		white
	)
	wake.Transparency = Cfg.WakeClear
	m.PrimaryPart = hull
	m:SetAttribute("Centre", centre)
	m:SetAttribute("Across", b.across)
	m:SetAttribute("Along", b.along)
	m:SetAttribute("Lap", b.lap)
	m:SetAttribute("Phase", b.phase)
	-- where it is now, so it shows in the right place before the client starts moving it
	local x, z, hx, hz = Sea.boatAt(b, workspace:GetServerTimeNow())
	local at = centre + Vector3.new(x, Cfg.WaterY, z)
	m:PivotTo(CFrame.lookAt(at, at + Vector3.new(hx, 0, hz)))
	m.Parent = parent
	return m
end

-- the boats and the beam (Persistent, in `map`) and the foam line (in `static`); `seaEdge` is the straight
-- coast's x, `lamp` the lighthouse lamp's middle
function SeaKit.build(map: Instance, static: Instance, seaEdge: number, lamp: Vector3?)
	local sea = Instance.new("Model")
	sea.Name = "Sea"
	sea.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- the client moves what is in it
	local boats = Instance.new("Folder")
	boats.Name = "Boats"
	boats.Parent = sea
	for _, b in Cfg.Boats do
		local centre = Vector3.new(Land.coast(LandCfg, seaEdge, b.z) - b.off, 0, b.z)
		boat(boats, b, centre)
	end
	if lamp then
		local B = Cfg.Beam
		local beam = Instance.new("Folder")
		beam.Name = "Beam"
		beam:SetAttribute("Lamp", lamp)
		for k = 0, 1 do
			local blade = piece(
				beam,
				"Part",
				Vector3.new(B.width, B.height, B.length),
				CFrame.new(lamp)
					* CFrame.Angles(0, k * math.pi, 0)
					* CFrame.new(0, 0, -B.length / 2),
				rgb(B.colour)
			)
			blade.Material = Enum.Material.Neon
			blade.Transparency = 1 -- the client shows it after dark
		end
		beam.Parent = sea
	end
	sea.Parent = map

	-- foam: from either side of the port out along the coast until it meets the edge
	local F = Cfg.Foam
	local foam = Instance.new("Folder")
	foam.Name = "Foam"
	local white = rgb(Cfg.White)
	for _, side in { -1, 1 } do
		local z = F.from
		while true do
			local z1 = z + F.step
			local a = Vector3.new(Land.coast(LandCfg, seaEdge, side * z) - F.out, F.y, side * z)
			local b = Vector3.new(Land.coast(LandCfg, seaEdge, side * z1) - F.out, F.y, side * z1)
			if Land.inset(LandCfg, b.X, b.Z) < 0 then
				break
			end
			local p = piece(
				foam,
				"Part",
				Vector3.new(F.width, 0.2, (b - a).Magnitude + 2),
				CFrame.lookAt((a + b) / 2, b),
				white
			)
			p.Transparency = F.clear
			z = z1
		end
	end
	foam.Parent = static
end

return SeaKit
