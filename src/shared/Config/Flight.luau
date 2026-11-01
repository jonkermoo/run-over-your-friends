--!strict
-- Roadster flight: holding the jet lifts it on its belly thrusters; letting go cuts the jet and it drops.
-- It keeps itself level, and Q/E roll it while held. Speeds in m/s, angles in degrees, fuel 0-100.

return table.freeze({
	climb = 10, -- m/s up while the jet is held
	climbAccel = 22, -- how fast it reaches the climb speed
	gravity = 9.81,
	top = 45, -- forward m/s on W under the jet (about 100 mph)
	reverseTop = 10,
	accel = 14, -- forward/back m/s^2 under the jet
	drag = 5, -- m/s^2 it slows by with no throttle (and above top speed)
	sideDrag = 12, -- sideways drift after a turn dies out at this rate, so it ends up flying where it points
	drain = 25, -- meter per second of jet (4 s from full)
	refill = 20, -- meter per second back, on the ground only
	refillDelay = 0.6,
	yawRate = 1.7, -- rad/s on A/D at full speed
	yawSpeed = 12, -- m/s from which it turns at the full rate; slower, it turns slower
	yawRamp = 6,
	bank = 18, -- leans into turns
	tilt = 7, -- nose dips speeding up, lifts slowing down
	level = 6, -- how hard it keeps its nose and wings level
	rollRate = 3, -- rad/s while Q/E are held
	rollLevel = 1.5, -- how gently it rolls back upright once they're let go
	minLift = 0.4, -- seconds a lift-off stays in flight mode before it can land again
})
