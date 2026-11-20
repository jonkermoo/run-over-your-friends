--!strict
-- The champions' podium in the middle of the spawn plaza (MapBuilder builds the stage from
-- World.SpawnPlaza.Podium; server/ChampionService builds the avatars; client/Champions poses them and turns
-- the stage). Each step holds the #1 of one leaderboard (Config/Leaderboards key).

export type Joint = { x: number?, y: number?, z: number? } -- degrees, turned in the joint's own frame
export type Pose = { [string]: Joint } -- by Motor6D name (R15)

-- R15 joints: an arm hangs along -Y; +x swings it forward, z swings it out (+z right arm, -z left arm)
local POSES: { [string]: Pose } = table.freeze({
	-- both fists up
	Victory = table.freeze({
		RightShoulder = table.freeze({ z = 150, x = 10 }),
		LeftShoulder = table.freeze({ z = -150, x = 10 }),
		RightElbow = table.freeze({ z = 20 }),
		LeftElbow = table.freeze({ z = -20 }),
		RightHip = table.freeze({ z = 8 }),
		LeftHip = table.freeze({ z = -8 }),
		Neck = table.freeze({ x = 12 }),
	}),
	-- upper arms out level, forearms straight up
	Flex = table.freeze({
		RightShoulder = table.freeze({ z = 90 }),
		LeftShoulder = table.freeze({ z = -90 }),
		RightElbow = table.freeze({ z = 95 }),
		LeftElbow = table.freeze({ z = -95 }),
		RightHip = table.freeze({ z = 10 }),
		LeftHip = table.freeze({ z = -10 }),
		Waist = table.freeze({ x = 4 }),
	}),
	-- points straight at whoever is looking, other hand on the hip
	Point = table.freeze({
		RightShoulder = table.freeze({ x = 92, z = 4 }),
		LeftShoulder = table.freeze({ z = -38, x = -10 }),
		LeftElbow = table.freeze({ x = 70, z = 20 }),
		RightHip = table.freeze({ z = 6 }),
		LeftHip = table.freeze({ z = -12 }),
		Waist = table.freeze({ y = -12 }),
		Neck = table.freeze({ y = 10 }),
	}),
})

return table.freeze({
	-- left to right as you face the podium; the middle step is the tallest (World.SpawnPlaza.Podium)
	Steps = table.freeze({
		table.freeze({ key = "Earned", pose = "Flex", bills = true }),
		table.freeze({ key = "HitsAll", pose = "Victory" }),
		table.freeze({ key = "Hits", pose = "Point" }),
	}),
	Poses = POSES,
	Scale = 2.2, -- avatar size on the podium (a player's own is Config/Game.BodyScale)
	TurnSeconds = 90, -- one full turn of the stage; the same angle for everyone (server time)
	BobStuds = 0.12, -- the slow breathing bob, per 1x of Scale
	BobSeconds = 3.2,
	ShowDistance = 450, -- studs from the camera: past this the stage stops turning
	PlateDistance = 450, -- the step plates draw up to this far
	BuildGap = 2, -- seconds between two avatar builds on the server
	RetrySeconds = 300, -- a failed build is tried again after this
	Bills = 6, -- banknotes a second drifting down round the richest
})
