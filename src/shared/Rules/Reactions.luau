--!strict
-- How pedestrians react to traffic: whether a moving vehicle is about to run them over, the chance they
-- jump clear (slim at speed, so hits stay easy), which way they jump, and where they run after a crash.
-- Pure (x/z numbers), so Lune tests it. Numbers come from Config/Crowd React.

local Reactions = {}

export type Config = {
	Look: number, -- seconds ahead a pedestrian notices a vehicle coming
	Reach: number, -- studs beside the vehicle's path (beyond half its width) that still counts as in the way
	SlowSpeed: number, -- m/s at or under which the dodge chance is DodgeSlow
	FastSpeed: number, -- m/s at or over which it is DodgeFast
	DodgeSlow: number,
	DodgeFast: number,
}

-- when a vehicle at (cx, cz) moving (vx, vz) studs/s passes closest to (px, pz): seconds from now and the
-- sideways gap in studs. Seconds are negative if it's already going away.
function Reactions.approach(
	px: number,
	pz: number,
	cx: number,
	cz: number,
	vx: number,
	vz: number
): (number, number)
	local v2 = vx * vx + vz * vz
	if v2 < 1e-6 then
		return math.huge, math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
	end
	local dx, dz = px - cx, pz - cz
	local t = (dx * vx + dz * vz) / v2
	local mx, mz = dx - vx * t, dz - vz * t
	return t, math.sqrt(mx * mx + mz * mz)
end

-- is this vehicle about to hit them? (halfWidth: half the vehicle's width in studs)
function Reactions.threatened(t: number, gap: number, halfWidth: number, cfg: Config): boolean
	return t > 0 and t <= cfg.Look and gap <= halfWidth + cfg.Reach
end

-- chance to jump clear of a vehicle doing `speed` m/s: DodgeSlow when slow, down to DodgeFast when fast
function Reactions.dodgeChance(speed: number, cfg: Config): number
	local k = math.clamp((speed - cfg.SlowSpeed) / (cfg.FastSpeed - cfg.SlowSpeed), 0, 1)
	return cfg.DodgeSlow + (cfg.DodgeFast - cfg.DodgeSlow) * k
end

-- which way to jump: sideways off the vehicle's path, on the side they're already on (`coin` 0-1 picks a side
-- for someone dead ahead). Returns a unit x, z.
function Reactions.dodgeDir(
	px: number,
	pz: number,
	cx: number,
	cz: number,
	vx: number,
	vz: number,
	coin: number
): (number, number)
	local len = math.sqrt(vx * vx + vz * vz)
	if len < 1e-6 then
		return 1, 0
	end
	-- the vehicle's left (looking along its travel), then flip to the pedestrian's side
	local lx, lz = -vz / len, vx / len
	local side = (px - cx) * lx + (pz - cz) * lz
	if math.abs(side) < 0.5 then
		side = if coin < 0.5 then -1 else 1
	end
	local s = if side >= 0 then 1 else -1
	return lx * s, lz * s
end

-- where someone at (px, pz) runs after a crash at (hx, hz): straight away from it, `dist` studs
function Reactions.fleePoint(
	px: number,
	pz: number,
	hx: number,
	hz: number,
	dist: number,
	coin: number
): (number, number)
	local dx, dz = px - hx, pz - hz
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 0.5 then
		local a = coin * 2 * math.pi
		dx, dz, len = math.cos(a), math.sin(a), 1
	end
	return px + dx / len * dist, pz + dz / len * dist
end

return Reactions
