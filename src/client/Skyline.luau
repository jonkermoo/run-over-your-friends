--!strict
-- The far stand-ins (server SkylineKit): each building's box shows only while that building isn't loaded here.
-- Buildings stream in and out whole, so a building arriving hides its box and one leaving shows it again.
-- The boxes and the buildings can arrive in any order, so both sides check.

local Skyline = {}

function Skyline.start()
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local buildings = map:WaitForChild("Buildings")
		local boxes = map:WaitForChild("Skyline")
		local here: { [string]: boolean } = {}
		local function apply(id: string)
			local b = boxes:FindFirstChild(id)
			if b and b:IsA("BasePart") then
				local t = if here[id] then 1 else 0
				b.Transparency = t
				-- a house's roof is a child of its box
				for _, c in b:GetChildren() do
					if c:IsA("BasePart") then
						c.Transparency = t
					end
				end
			end
		end
		local function set(model: Instance, loaded: boolean)
			local id = model:GetAttribute("Sky")
			if typeof(id) == "number" then
				local key = tostring(id)
				here[key] = loaded or nil
				apply(key)
			end
		end
		buildings.ChildAdded:Connect(function(m)
			set(m, true)
		end)
		buildings.ChildRemoved:Connect(function(m)
			set(m, false)
		end)
		boxes.ChildAdded:Connect(function(b)
			apply(b.Name)
		end)
		for _, m in buildings:GetChildren() do
			set(m, true)
		end
		for _, b in boxes:GetChildren() do
			apply(b.Name)
		end
	end)
end

return Skyline
