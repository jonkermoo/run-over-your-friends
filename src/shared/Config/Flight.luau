--!strict
-- Roadster hover flight: belly thrusters lift it, it stays level by itself, and it glides down softly.
-- Speeds in m/s, angles in degrees, fuel in meter points (0-100).

return table.freeze({
	climb = 10, -- m/s up while lift is held
	climbAccel = 22, -- how fast it reaches the climb (and the cushion) speed
	sink = 4, -- fastest it drifts down with lift let go
	gravity = 9.81,
	top = 45, -- forward m/s on W (about 100 mph)
	reverseTop = 10,
	accel = 14, -- forward/back m/s^2 in the air
	drag = 5, -- m/s^2 it slows by with no throttle (and above top speed)
	sideDrag = 12, -- sideways slide dies out fast, so it flies where it points
	drain = 14, -- meter per second of lift
	refill = 20, -- meter per second back, on the ground only
	refillDelay = 0.6,
	yawRate = 1.7, -- rad/s on A/D
	yawRamp = 6,
	bank = 18, -- leans into turns
	tilt = 7, -- nose dips speeding up, lifts slowing down
	level = 6, -- how hard it rights itself
	flipTime = 0.75, -- seconds for a full roll on Q/E
	minLift = 0.4, -- seconds a lift-off stays in flight mode before it can land again
})
