--!strict
-- Pure numbers and rules. No Roblox objects here, so Lune can test this file.
-- Every tweakable value (speed, damage, prices) lives in src/shared/Config.

return table.freeze({
	Player = table.freeze({
		WalkSpeed = 16,
		JumpPower = 50,
	}),
})
