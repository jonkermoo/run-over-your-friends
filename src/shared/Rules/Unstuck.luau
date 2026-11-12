--!strict
-- What the unstuck button does (Config/Unstuck): the trail of safe points behind the car and which of them to
-- try. Pure, so Lune tests it.

local Unstuck = {}

export type Crumb = { x: number, y: number, z: number, lx: number, lz: number }
export type Config = {
	Spacing: number,
	MaxCrumbs: number,
	MinBack: number,
	FlipBelow: number,
	MaxMph: number,
}

-- is it time for another point on the trail? (the first one is always due)
function Unstuck.due(crumbs: { Crumb }, x: number, z: number, cfg: Config): boolean
	local last = crumbs[#crumbs]
	return last == nil or (last.x - x) ^ 2 + (last.z - z) ^ 2 >= cfg.Spacing ^ 2
end

function Unstuck.push(crumbs: { Crumb }, crumb: Crumb, cfg: Config)
	table.insert(crumbs, crumb)
	while #crumbs > cfg.MaxCrumbs do
		table.remove(crumbs, 1)
	end
end

-- the points to try, nearest in time first, all at least MinBack from (x, z)
function Unstuck.spots(crumbs: { Crumb }, x: number, z: number, cfg: Config): { Crumb }
	local out = {}
	for i = #crumbs, 1, -1 do
		local c = crumbs[i]
		if (c.x - x) ^ 2 + (c.z - z) ^ 2 >= cfg.MinBack ^ 2 then
			table.insert(out, c)
		end
	end
	return out
end

-- the nearest point on any road centreline (polylines of { x, z } points) to (x, z), the road's direction
-- there (unit, either way along it) and how far away it is; nil when there are no roads
function Unstuck.nearestRoad(
	lines: { { { number } } },
	x: number,
	z: number
): (number?, number?, number?, number?, number?)
	local bestD2, bx, bz, dx, dz = math.huge, nil, nil, nil, nil
	for _, pts in lines do
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local ex, ez = b[1] - a[1], b[2] - a[2]
			local len2 = ex * ex + ez * ez
			if len2 > 0 then
				local t = math.clamp(((x - a[1]) * ex + (z - a[2]) * ez) / len2, 0, 1)
				local px, pz = a[1] + ex * t, a[2] + ez * t
				local d2 = (px - x) ^ 2 + (pz - z) ^ 2
				if d2 < bestD2 then
					local len = math.sqrt(len2)
					bestD2, bx, bz, dx, dz = d2, px, pz, ex / len, ez / len
				end
			end
		end
	end
	if not bx then
		return nil, nil, nil, nil, nil
	end
	return bx, bz, dx, dz, math.sqrt(bestD2)
end

-- "flip" (back on its wheels where it is), "back" (along the trail), or nil (not now)
function Unstuck.action(
	upY: number,
	flying: boolean,
	flung: boolean,
	mph: number,
	readyAt: number,
	now: number,
	cfg: Config
): string?
	if flying or flung or now < readyAt or mph > cfg.MaxMph then
		return nil
	end
	return if upY < cfg.FlipBelow then "flip" else "back"
end

return Unstuck
