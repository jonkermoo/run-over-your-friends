--!strict
-- Ragdoll an R15 character: each Motor6D is swapped for a ball socket so the body flops, and swapped back
-- on recover. Made on the server so everyone sees the limbs.

local Ragdoll = {}

function Ragdoll.enable(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or character:GetAttribute("Ragdolled") then
		return
	end
	character:SetAttribute("Ragdolled", true)
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.PlatformStand = true
	for _, m in character:GetDescendants() do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 then
			local a0 = Instance.new("Attachment")
			a0.Name = "RagA0"
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "RagA1"
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local s = Instance.new("BallSocketConstraint")
			s.Name = "RagSocket"
			s.Attachment0 = a0
			s.Attachment1 = a1
			s.LimitsEnabled = true
			s.UpperAngle = 70
			s.TwistLimitsEnabled = true
			s.TwistLowerAngle = -45
			s.TwistUpperAngle = 45
			s.Parent = m.Part0
			m.Enabled = false
		end
	end
	for _, p in character:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.CanCollide = true
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.CanCollide = false
	end
end

function Ragdoll.disable(character: Model)
	if not character:GetAttribute("Ragdolled") then
		return
	end
	character:SetAttribute("Ragdolled", nil)
	for _, d in character:GetDescendants() do
		if d.Name == "RagSocket" or d.Name == "RagA0" or d.Name == "RagA1" then
			d:Destroy()
		elseif d:IsA("Motor6D") then
			d.Enabled = true
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

return Ragdoll
