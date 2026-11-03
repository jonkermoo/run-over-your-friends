--!strict
-- Is a vehicle's weight over the ground under it? The ground probes that touched something give the support,
-- and the centre of mass must sit over it (or within `margin` of it): only the rear wheels on a ledge with the
-- nose out in the air, or one side over a drop, and it tips. Points are in the chassis's own flat x/z, any
-- unit. Plain numbers so Lune can test it.

local Balance = {}

export type Point = { x: number, z: number }

local function cross(o: Point, a: Point, b: Point): number
	return (a.x - o.x) * (b.z - o.z) - (a.z - o.z) * (b.x - o.x)
end

local function segment(p: Point, a: Point, b: Point): number
	local dx, dz = b.x - a.x, b.z - a.z
	local len2 = dx * dx + dz * dz
	local t = if len2 > 0 then math.clamp(((p.x - a.x) * dx + (p.z - a.z) * dz) / len2, 0, 1) else 0
	local ex, ez = p.x - (a.x + dx * t), p.z - (a.z + dz * t)
	return math.sqrt(ex * ex + ez * ez)
end

-- the convex hull, anticlockwise (monotone chain); collinear points drop out
function Balance.hull(points: { Point }): { Point }
	local sorted = table.clone(points)
	table.sort(sorted, function(a, b)
		return a.x < b.x or (a.x == b.x and a.z < b.z)
	end)
	if #sorted < 3 then
		return sorted
	end
	local out: { Point } = {}
	for _, pass in { 1, -1 } do
		local start = #out
		local from, to = if pass == 1 then 1 else #sorted, if pass == 1 then #sorted else 1
		for i = from, to, pass do
			local p = sorted[i]
			while #out >= start + 2 and cross(out[#out - 1], out[#out], p) <= 0 do
				table.remove(out)
			end
			table.insert(out, p)
		end
		table.remove(out) -- the last point starts the other pass
	end
	return out
end

-- how far `p` sits outside the support the points span (0 inside it); math.huge with no points
function Balance.overhang(points: { Point }, p: Point): number
	local hull = Balance.hull(points)
	local n = #hull
	if n == 0 then
		return math.huge
	elseif n == 1 then
		return segment(p, hull[1], hull[1])
	elseif n == 2 then
		return segment(p, hull[1], hull[2])
	end
	local inside, nearest = true, math.huge
	for i = 1, n do
		local a, b = hull[i], hull[i % n + 1]
		if cross(a, b, p) < 0 then
			inside = false
		end
		nearest = math.min(nearest, segment(p, a, b))
	end
	return if inside then 0 else nearest
end

function Balance.supported(points: { Point }, com: Point, margin: number): boolean
	return Balance.overhang(points, com) <= margin
end

return Balance
