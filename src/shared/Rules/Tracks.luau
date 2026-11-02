--!strict
-- A crawler track's loop seen from the side: a straight run along the ground from the idler (front) back to the
-- sprocket (rear), round the sprocket, a straight run back along the top, round the idler. Plates ride the loop
-- at `radius` (the wheels' radius plus half a plate). Positions are in the vehicle's frame, front -Z, studs;
-- `angle` is the plate's turn about X (0 on the ground run, grouser down). Plain numbers so Lune can test it.

local Tracks = {}

export type Loop = {
	y: number, -- axle height of idler and sprocket
	front: number, -- idler z
	back: number, -- sprocket z (greater than front)
	radius: number,
}

function Tracks.length(loop: Loop): number
	return 2 * (loop.back - loop.front) + 2 * math.pi * loop.radius
end

-- how many plates fit at about `pitch` apart, at least 8
function Tracks.count(loop: Loop, pitch: number): number
	return math.max(8, math.floor(Tracks.length(loop) / pitch + 0.5))
end

-- where a plate `d` studs along the loop sits: (y, z, angle). d grows in the direction the ground run moves
-- relative to the vehicle when it drives forward (backwards along the bottom).
function Tracks.at(loop: Loop, d: number): (number, number, number)
	local run = loop.back - loop.front
	local r = loop.radius
	local turn = math.pi * r
	d %= Tracks.length(loop)
	if d < run then
		return loop.y - r, loop.front + d, 0
	end
	d -= run
	if d < turn then
		local t = d / r
		return loop.y - r * math.cos(t), loop.back + r * math.sin(t), -t
	end
	d -= turn
	if d < run then
		return loop.y + r, loop.back - d, -math.pi
	end
	local t = (d - run) / r
	return loop.y + r * math.cos(t), loop.front - r * math.sin(t), -math.pi - t
end

-- each track's surface speed (studs/s) for a vehicle moving `forward` studs/s and turning `yaw` rad/s (positive
-- = left), with its tracks `half` studs either side of the middle: the outside of a turn runs faster
function Tracks.speeds(forward: number, yaw: number, half: number): (number, number)
	return forward - yaw * half, forward + yaw * half
end

return Tracks
