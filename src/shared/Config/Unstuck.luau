--!strict
-- The unstuck button (T, pad D-pad left, the phone's STUCK? button; Rules/Unstuck, src/client/Drive). A car
-- on its side is put back on its wheels where it is; otherwise it goes back along the road it just drove.
-- Studs and seconds unless noted.

return table.freeze({
	Spacing = 20, -- a point on the trail is remembered every this many studs driven...
	MaxCrumbs = 30, -- ...and this many are kept
	MinBack = 40, -- the trail point it goes back to is at least this far from where it is stuck
	SkyCheck = 60, -- a trail point needs open sky this far above it (so never inside a building)
	FlatUp = 0.97, -- the car's up vector Y must be at least this for a trail point (not on a ramp)
	FlipBelow = 0.8, -- up vector Y under this counts as on its side: flip it on the spot
	RoadMax = 400, -- no trail point to go back to: the nearest road within this many studs instead
	RoadRay = 200, -- the road's ground is found by a ray from this far above the car down to this far below it
	MaxMph = 20, -- the button does nothing faster than this
	Cooldown = 5,
	StuckSeconds = 2.5, -- throttle held this long without moving: the HUD offers the button
	StuckMps = 1, -- metres a second that count as not moving
})
