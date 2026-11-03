--!strict
-- Stunts: a jump pays when the car lands back on its wheels. Pay = air time and flat spins (360s), times a
-- boost for slow vehicles (they can't jump as far), doubled in the stunt park. Rules/Stunts.

return table.freeze({
	MinAir = 0.6, -- seconds in the air before a jump counts (bumps and kerbs don't)
	PerSecond = 40, -- $ per second in the air
	Spin = 100, -- $ per full turn flat (a 360)
	TrickSlack = 60, -- degrees short of a full turn that still count as one
	MaxPay = 2000, -- one jump never pays more than this
	Park = 2, -- times the pay in the stunt park
	-- slow vehicles earn more per jump: boost = RefSpeed / top speed, between 1 and MaxBoost
	RefSpeed = 95,
	MaxBoost = 2.5,
	Clearance = 2.5, -- studs above the car's usual ride height before it counts as off the ground
	Settle = 0.3, -- seconds back on the ground before the landing is judged (bounces stay one jump)
	Upright = 0.5, -- the car's up has to point at least this far up to land clean
	FlungGrace = 3, -- seconds after a wrecker flings a car that its air doesn't count
	-- the AIR ticker on screen while the car is up
	TickerAfter = 0.4,
})
