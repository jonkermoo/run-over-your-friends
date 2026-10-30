--!strict
-- Run with: lune run tests/run
local Game = require("../src/shared/Config/Game")

local failures = 0
local function check(name: string, ok: boolean)
	if ok then
		print("PASS " .. name)
	else
		print("FAIL " .. name)
		failures += 1
	end
end

check("WalkSpeed is positive", Game.Player.WalkSpeed > 0)
check("JumpPower is positive", Game.Player.JumpPower > 0)

if failures > 0 then
	error(`{failures} test(s) failed`)
end
