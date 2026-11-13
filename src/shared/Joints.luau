--!strict
-- Keeps a rescaled R15 rig's joints in step with it. The rig's AnimationConstraints hold their offsets (C0/C1,
-- read-only) apart from their attachments and re-read them only when an attachment moves; after Model:ScaleTo
-- the giant's attachments were scaled but its joint offsets often stayed ordinary-sized (on the server, on
-- clients, or both), so its 6x limbs were drawn heaped round its root: sunk to the chest, floating or folded.
-- Used on the server (CrowdService, as the giant enters the world) and on every client (client/GiantFinder).

local Joints = {}

local TOLERANCE = 0.05 -- studs a joint's offset may sit from its attachment before it counts as stale

-- how many joints hold an offset that no longer matches their attachments
function Joints.stale(model: Model): number
	local n = 0
	for _, c in model:GetDescendants() do
		if c:IsA("AnimationConstraint") then
			local a0, a1 = c.Attachment0, c.Attachment1
			if
				(a0 and (c.C0.Position - a0.Position).Magnitude > TOLERANCE)
				or (a1 and (c.C1.Position - a1.Position).Magnitude > TOLERANCE)
			then
				n += 1
			end
		end
	end
	return n
end

-- nudge every joint attachment there and back so each joint re-reads it
function Joints.refresh(model: Model)
	for _, c in model:GetDescendants() do
		if c:IsA("AnimationConstraint") then
			for _, a in { c.Attachment0, c.Attachment1 } do
				if a then
					local cf = a.CFrame
					a.CFrame = cf * CFrame.new(0, 1e-3, 0)
					a.CFrame = cf
				end
			end
		end
	end
end

return Joints
