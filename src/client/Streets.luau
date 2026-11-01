--!strict
-- Traffic lights: every lamp tagged Signal = "NS" or "EW" cycles green, amber, red on this screen only
-- (all crossings change together, so it costs one colour change per lamp every few seconds).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local S = require(ReplicatedStorage.Shared.Config.Streets)

local Streets = {}

local GREEN = Color3.fromRGB(60, 200, 90)
local AMBER = Color3.fromRGB(255, 180, 40)
local RED = Color3.fromRGB(230, 50, 40)

function Streets.start()
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local props = map:WaitForChild("Props")
		task.wait(2)
		local lamps: { NS: { BasePart }, EW: { BasePart } } = { NS = {}, EW = {} }
		for _, p in props:GetDescendants() do
			local which = p:GetAttribute("Signal")
			if p:IsA("BasePart") and (which == "NS" or which == "EW") then
				table.insert(lamps[which], p)
			end
		end
		local function set(list: { BasePart }, color: Color3)
			for _, l in list do
				l.Color = color
			end
		end
		local nsGo = true
		while true do
			local go, stop =
				if nsGo then lamps.NS else lamps.EW, if nsGo then lamps.EW else lamps.NS
			set(go, GREEN)
			set(stop, RED)
			task.wait(S.SignalSeconds)
			set(go, AMBER)
			task.wait(S.AmberSeconds)
			nsGo = not nsGo
		end
	end)
end

return Streets
