--!strict
-- Flight maths: the car's speeds along its heading, sideways and up, one step at a time.
-- With the jet on it climbs and burns fuel, W/S speed it up and back it up, and
-- sideways drift dies out; with the jet off (or out of fuel) it just falls, keeping its momentum. Pure numbers, so Lune tests it.

local Flight = {}

export type Config = {
	climb: number,
	climbAccel: number,
	gravity: number,
	top: number,
	reverseTop: number,
	accel: number,
	drag: number,
	sideDrag: number,
	drain: number,
}

export type State = { forward: number, side: number, up: number, fuel: number }

local function toward(x: number, target: number, step: number): number
	if x < target then
		return math.min(target, x + step)
	end
	return math.max(target, x - step)
end

function Flight.step(s: State, throttle: number, jet: boolean, dt: number, c: Config): State
	if not jet or s.fuel <= 0 then
		return { forward = s.forward, side = s.side, up = s.up - c.gravity * dt, fuel = s.fuel }
	end
	local target = if throttle > 0
		then c.top * throttle
		elseif throttle < 0 then -c.reverseTop
		else 0
	local pushing = throttle ~= 0 and math.sign(target - s.forward) == math.sign(throttle)
	return {
		forward = toward(s.forward, target, (if pushing then c.accel else c.drag) * dt),
		side = toward(s.side, 0, c.sideDrag * dt),
		up = toward(s.up, c.climb, c.climbAccel * dt),
		fuel = math.max(0, s.fuel - c.drain * dt),
	}
end

return Flight
