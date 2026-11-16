--!strict
-- The map build's breathing: a long build has to yield now and then or the script times out, but every yield
-- costs a whole frame of nothing (360 of them were about 3 s of a server's start). Pace.step() yields only once
-- Config/World Build.YieldEvery seconds of work have gone by since the last yield.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Config.World)

local Pace = {}

local last = os.clock()

function Pace.step()
	if os.clock() - last >= World.Build.YieldEvery then
		task.wait()
		last = os.clock()
	end
end

return Pace
