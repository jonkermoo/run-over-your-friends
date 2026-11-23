--!strict
-- Moves the sea's boats round their loops and turns the lighthouse beam (server SeaKit builds them; Config/Sea).
-- Everything runs off the shared server clock, so every player sees the boats in the same places.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cfg = require(ReplicatedStorage.Shared.Config.Sea)
local Sea = require(ReplicatedStorage.Shared.Rules.Sea)

local SeaLife = {}

type Boat = { model: Model, centre: Vector3, loop: Sea.Loop, sway: number }

function SeaLife.start()
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local sea = map:WaitForChild("Sea")
		local boats: { Boat } = {}
		local folder = sea:WaitForChild("Boats")
		local function add(m: Instance)
			if not m:IsA("Model") then
				return
			end
			local centre, across, along, lap, phase =
				m:GetAttribute("Centre"),
				m:GetAttribute("Across"),
				m:GetAttribute("Along"),
				m:GetAttribute("Lap"),
				m:GetAttribute("Phase")
			if
				typeof(centre) ~= "Vector3"
				or typeof(across) ~= "number"
				or typeof(along) ~= "number"
				or typeof(lap) ~= "number"
				or typeof(phase) ~= "number"
			then
				return
			end
			table.insert(boats, {
				model = m,
				centre = centre,
				loop = { across = across, along = along, lap = lap, phase = phase },
				sway = #boats * 1.7, -- each boat rocks out of step with the others
			})
		end
		for _, m in folder:GetChildren() do
			add(m)
		end
		folder.ChildAdded:Connect(add)

		local beam = sea:FindFirstChild("Beam")
		local lamp = beam and beam:GetAttribute("Lamp")
		local blades: { BasePart } = {}
		if beam and typeof(lamp) == "Vector3" then
			for _, b in beam:GetChildren() do
				if b:IsA("BasePart") then
					table.insert(blades, b)
				end
			end
		end

		local Bob, B = Cfg.Bob, Cfg.Beam
		RunService.Heartbeat:Connect(function()
			local t = workspace:GetServerTimeNow()
			for _, b in boats do
				if not b.model.Parent then
					continue
				end
				local x, z, hx, hz = Sea.boatAt(b.loop, t)
				local w = 2 * math.pi * (t / Bob.period) + b.sway
				local at = b.centre + Vector3.new(x, Cfg.WaterY + math.sin(w) * Bob.heave, z)
				b.model:PivotTo(
					CFrame.lookAt(at, at + Vector3.new(hx, 0, hz))
						* CFrame.Angles(
							math.rad(Bob.pitch) * math.sin(w * 0.7),
							0,
							math.rad(Bob.roll) * math.sin(w)
						)
				)
			end
			if #blades > 0 then
				local show = Sea.beam(Lighting.ClockTime, B.on, B.off, B.fade)
				local clear = if show > 0 then 1 - (1 - B.clear) * show else 1
				local turn = 2 * math.pi * (t / B.turn)
				for k, blade in blades do
					blade.Transparency = clear
					if show > 0 then
						blade.CFrame = CFrame.new(lamp :: Vector3)
							* CFrame.Angles(0, turn + (k - 1) * math.pi, 0)
							* CFrame.new(0, 0, -B.length / 2)
					end
				end
			end
		end)
	end)
end

return SeaLife
