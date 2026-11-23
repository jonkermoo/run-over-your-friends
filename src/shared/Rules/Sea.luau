--!strict
-- The sea's motion (Config/Sea), pure so Lune tests it: where a boat is on its loop at a time, which way it
-- heads, and how strongly the lighthouse beam shows at a time of day.

local Sea = {}

export type Loop = { across: number, along: number, lap: number, phase: number }

-- the boat's offset from its loop's middle (out to sea is -x, the coast runs along z) and its heading (a unit
-- x, z) at `t` seconds
function Sea.boatAt(loop: Loop, t: number): (number, number, number, number)
	local a = 2 * math.pi * (loop.phase + t / loop.lap)
	local x = -loop.across * math.cos(a)
	local z = loop.along * math.sin(a)
	-- d/dt of (x, z): the sign of `lap` sets which way round
	local dx = loop.across * math.sin(a) / loop.lap
	local dz = loop.along * math.cos(a) / loop.lap
	local m = math.sqrt(dx * dx + dz * dz)
	if m < 1e-9 then
		return x, z, 0, 1
	end
	return x, z, dx / m, dz / m
end

-- 0..1: how much the beam shows at `clock` hours (0..24): full from `on` to `off` across midnight, fading over
-- `fade` hours at each end, none in the day
function Sea.beam(clock: number, on: number, off: number, fade: number): number
	local function up(h: number): number
		-- hours since `on`, wrapped to 0..24
		return (h - on) % 24
	end
	local night = (off - on) % 24 -- how long the beam is on
	local since = up(clock)
	if since > night + fade then
		-- daytime: still fading in before `on`?
		local before = 24 - since
		return if before < fade then 1 - before / fade else 0
	end
	if since <= night then
		return 1
	end
	return 1 - (since - night) / fade
end

return Sea
