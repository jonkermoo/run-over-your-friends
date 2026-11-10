--!strict
-- Hitting other players (on foot or in their cars) is free for everyone. These numbers keep it from
-- making the game unplayable for the one being hit; very expensive cars skip most of them.
-- Plain numbers only (Lune tests read this).

return table.freeze({
	BigCarPrice = 100000, -- cars at or over this shop price hit with the Big terms (Bulldozer and up)
	SpawnShield = 3, -- seconds after a spawn when nobody can hit you
	-- the same attacker hitting the same player again within RepeatWindow seconds of their last hit
	-- does RepeatFactor as much each time, never under RepeatFloor (Big cars skip this)
	RepeatWindow = 60,
	RepeatFactor = 0.5,
	RepeatFloor = 0.25,
	Normal = table.freeze({
		shield = 6, -- seconds after a hit when this attacker can't hit the victim again
		ragdoll = 1.5, -- seconds a launched player on foot lies before getting up
		carRecover = 0.8, -- seconds until a flung driver's car drives again
		parkedRecover = 1.5, -- seconds until a flung parked car's motors come back
		launchCap = 130, -- studs/s, a player on foot
		carLaunchCap = 160, -- studs/s, a car
	}),
	Big = table.freeze({
		shield = 2, -- still a short gap, so a hit can't land every frame
		ragdoll = 2.6,
		carRecover = 1.4,
		parkedRecover = 2.5,
		launchCap = 255,
		carLaunchCap = 320,
	}),
})
