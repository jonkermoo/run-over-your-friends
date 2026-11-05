--!strict
-- Pure numbers and rules. No Roblox objects here, so Lune can test this file.
-- Every tweakable value (speed, damage, prices) lives in src/shared/Config.

return table.freeze({
	Player = table.freeze({
		WalkSpeed = 16,
		JumpPower = 50,
	}),
	-- how much bigger than a stock Roblox avatar everyone is: players, the city's people and friend NPCs
	BodyScale = 1.2,
	-- every vehicle model is built this much bigger than its mesh: a little more than BodyScale, so tall avatars
	-- keep their heads under the low roofs (Roadster, Supercar). The city (roads, buildings, ramps) keeps its size.
	VehicleScale = 1.25,
	AppearanceWait = 8, -- seconds the server waits for a player's hats and hair before scaling them anyway
})
