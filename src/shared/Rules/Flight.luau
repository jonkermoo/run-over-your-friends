--!strict
-- Hover flight maths: the car's speeds along its heading, sideways and up, one step at a time.
-- Holding lift climbs and burns fuel; letting go sinks at a capped rate (the belly thrusters cushion
-- a fall); W/S speed it up and slow it down. Pure numbers, so Lune tests it.

local Flight = {}

export type Config = {
	climb: number,
	climbAccel: number,
	sink: number,
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

function Flight.step(s: State, throttle: number, lift: boolean, dt: number, c: Config): State
	local fuel, up = s.fuel, s.up
	if lift and fuel > 0 then
		fuel = math.max(0, fuel - c.drain * dt)
		up = toward(up, c.climb, c.climbAccel * dt)
	elseif up > -c.sink then
		up = math.max(-c.sink, up - c.gravity * dt)
	else
		up = toward(up, -c.sink, c.climbAccel * dt)
	end

	local target = if throttle > 0
		then c.top * throttle
		elseif throttle < 0 then -c.reverseTop
		else 0
	local pushing = throttle ~= 0 and math.sign(target - s.forward) == math.sign(throttle)
	local forward = toward(s.forward, target, (if pushing then c.accel else c.drag) * dt)
	local side = toward(s.side, 0, c.sideDrag * dt)
	return { forward = forward, side = side, up = up, fuel = fuel }
end

return Flight
