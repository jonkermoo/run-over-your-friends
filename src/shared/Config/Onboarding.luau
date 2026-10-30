--!strict
-- First session: steps, goals and hint timings.

return table.freeze({
	-- player attribute "Tutorial": 1 spawn a car, 2 run people over, 3 save for the next car, 99 done
	Steps = table.freeze({ Spawn = 1, Hits = 2, Save = 3, Done = 99 }),
	HitsGoal = 3,
	HitsReward = 250,
	SpawnCrowd = 12, -- NPCs that always hang around the spawn plaza
	HintAfter = 20, -- seconds stuck on a step before the hint pulses
})
