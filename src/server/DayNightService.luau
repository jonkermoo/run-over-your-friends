--!strict
-- The shared day/night clock. The server only says when the cycle started and how fast it runs (Lighting
-- attributes DayNightEpoch / DayNightSpeed); every client works out the time from workspace:GetServerTimeNow(),
-- so all players see the same sky without a message per frame. To watch a cycle sped up in Studio, set
-- Lighting's DayNightSpeed attribute (e.g. 20) on the server; the time of day carries on from where it was.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.DayNight)
local Rules = require(ReplicatedStorage.Shared.Rules.DayNight)

local DayNightService = {}

function DayNightService.start()
	local speed = 1
	Lighting:SetAttribute("DayNightEpoch", workspace:GetServerTimeNow() - Config.StartAt)
	Lighting:SetAttribute("DayNightSpeed", speed)
	Lighting:GetAttributeChangedSignal("DayNightSpeed"):Connect(function()
		local new = Lighting:GetAttribute("DayNightSpeed")
		if typeof(new) ~= "number" or new <= 0 then
			Lighting:SetAttribute("DayNightSpeed", speed)
			return
		end
		if new == speed then
			return
		end
		local epoch = Lighting:GetAttribute("DayNightEpoch") :: number
		Lighting:SetAttribute(
			"DayNightEpoch",
			Rules.rebase(workspace:GetServerTimeNow(), epoch, speed, new)
		)
		speed = new
	end)
end

return DayNightService
