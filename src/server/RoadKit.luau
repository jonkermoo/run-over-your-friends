--!strict
-- The roads you see: smooth meshes made from the road layout (tools/roads, Config/RoadMeshes), in chunks of up
-- to three MeshParts: the asphalt, the concrete (downtown kerbs, suburb sidewalks) and the trim laid on top
-- (paint, gutters, tyre wear, verges, manholes, drains, patches). They never collide and rays pass through
-- them: cars drive on the invisible road parts (city, ring) and on the terrain (suburbs) under them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoadMeshes = require(ReplicatedStorage.Shared.Config.RoadMeshes)

local RoadKit = {}

function RoadKit.build(static: Instance): number
	local templates = ReplicatedStorage:FindFirstChild("RoadModels")
	if not templates then
		warn("[RoadKit] ReplicatedStorage.RoadModels is missing: no road meshes")
		return 0
	end
	-- one persistent model: every player always has all the road meshes (200 parts), so a far road never
	-- streams out and leaves the bare terrain under it showing
	local folder = Instance.new("Model")
	folder.Name = "Roads"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local count = 0
	for _, m in RoadMeshes.Meshes do
		local t = templates:FindFirstChild(m.name)
		if t and t:IsA("MeshPart") then
			local p = t:Clone()
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = m.layer == "Concrete"
			p.Size = Vector3.new(m.size[1], m.size[2], m.size[3])
			p.CFrame = CFrame.new(m.at[1], m.at[2], m.at[3])
			p.Parent = folder
			count += 1
		else
			warn("[RoadKit] no template for " .. m.name)
		end
	end
	folder.Parent = static
	return count
end

return RoadKit
