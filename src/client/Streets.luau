--!strict
-- Traffic lights: every lamp is tagged Signal = "NS" or "EW" and Lamp = "red", "amber" or "green"; on this screen
-- only, the lamp for each way's current colour glows (Neon, full colour) and the other two show their dim colour
-- (all crossings change together, so it costs a few lamp changes every few seconds), in step with the server's
-- traffic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roads = require(ReplicatedStorage.Shared.Rules.Roads)
local S = require(ReplicatedStorage.Shared.Config.Streets)

local Streets = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local LIT: { [string]: Color3 } = {}
local DIM: { [string]: Color3 } = {}
for name, c in S.Signal.Lit :: any do
	LIT[name] = rgb(c)
end
for name, c in S.Signal.Dim :: any do
	DIM[name] = rgb(c)
end

-- one lamp shown lit or dim
local function show(lamp: BasePart, lit: boolean)
	local colour = lamp:GetAttribute("Lamp")
	if typeof(colour) ~= "string" or not LIT[colour] then
		return
	end
	lamp.Color = if lit then LIT[colour] else DIM[colour]
	lamp.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

function Streets.start()
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local props = map:WaitForChild("Props")
		local lamps: { NS: { BasePart }, EW: { BasePart } } = { NS = {}, EW = {} }
		-- the phase comes from server time (Rules/Roads), so every screen and the traffic agree
		local shown: { [string]: string } = { NS = "", EW = "" }
		local function set(list: { BasePart }, light: string)
			for _, l in list do
				show(l, l:GetAttribute("Lamp") == light)
			end
		end
		-- lamps stream in and out round the player: each one joins its list as it arrives, in the shown colour
		local function add(p: Instance)
			local which = p:GetAttribute("Signal")
			if p:IsA("BasePart") and (which == "NS" or which == "EW") then
				table.insert(lamps[which], p)
				show(p, p:GetAttribute("Lamp") == shown[which])
			end
		end
		local function remove(p: Instance)
			for _, list in lamps do
				local i = table.find(list, p :: any)
				if i then
					table.remove(list, i)
				end
			end
		end
		for _, p in props:GetDescendants() do
			add(p)
		end
		props.DescendantAdded:Connect(add)
		props.DescendantRemoving:Connect(remove)
		while true do
			local ns, ew = Roads.lights(workspace:GetServerTimeNow(), S)
			if ns ~= shown.NS then
				shown.NS = ns
				set(lamps.NS, ns)
			end
			if ew ~= shown.EW then
				shown.EW = ew
				set(lamps.EW, ew)
			end
			task.wait(0.25)
		end
	end)
end

return Streets
