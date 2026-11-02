--!strict
-- First-person driving view (src/client/Cockpit) and the cabin's moving parts (gauge needles, joysticks, crawler
-- tracks). Studs, degrees and seconds unless a line says otherwise.

return table.freeze({
	-- the camera sits at the driver's eyes, fixed to the seat (every avatar sees the same view, whatever its
	-- head is like): measured in Studio, a seated avatar's head is 2.87 above the seat part and 0.17 behind it
	eyeAboveSeat = 3.0, -- studs above the seat part's middle
	eyeAhead = 0.18, -- studs ahead of it
	hideRadius = 1.3, -- the driver's own parts this close to the eye are hidden (head, hair, hats, face pieces)
	fov = 65, -- base field of view in first person (third person keeps the player's own)
	fovPunch = 0.6, -- share of the speed / acceleration FOV widening kept in first person
	shake = 0.5, -- share of camera shake kept in first person (it feels stronger on a locked head)
	shakeSway = 0.1, -- studs of sideways shake at full trauma in first person (third person: 0.6)
	-- looking around: mouse, right stick or a drag on a phone; it springs back to the road when let go
	lookYaw = 120, -- either way
	lookUp = 30,
	lookDown = 50,
	mouseSpeed = 0.25, -- degrees per pixel
	stickSpeed = 200, -- degrees per second at full stick
	touchSpeed = 0.3, -- degrees per pixel dragged
	recentreAfter = 1.2, -- seconds without looking before it eases back
	recentreRate = 4, -- how fast it eases back (per second)
	-- the head leans into a turn and is pushed by acceleration
	turnLook = 8, -- degrees of yaw towards the turn at full steering lock
	gSway = 0.08, -- studs of head movement per g, either way
	gSwayMax = 0.25,
	glass = 0.8, -- the own car's glass this see-through in first person (0 solid, 1 invisible)
	keys = { "V" }, -- KeyCode names that toggle the view
	pads = { "ButtonR3" }, -- gamepad buttons that toggle it

	-- dials: needles swing from 7 o'clock (empty) round to 5 o'clock (full)
	gaugeTilt = 15, -- every dial leans back this much; tools/blender/export_vehicles.py builds them to match
	needleZero = 135, -- degrees from straight up, anticlockwise as the driver sees it
	needleSweep = 270,
	needleRate = 8, -- how fast needles follow (per second)
	speedoTop = 1.25, -- the speedo's full scale as a share of the vehicle's top speed
	idleRev = 0.15, -- rev needle at idle (0-1)

	-- joysticks (bulldozer): how far they lean with the driver's input
	stickLean = 18,
	stickRate = 10,

	-- crawler tracks: link plate spacing target along the loop
	shoePitch = 1.1,
})
