--!strict
-- The island's shape (Config/Land): where the edge is, where the coast is, what is land and where the walls
-- go. Pure, so Lune tests it.

local Land = {}

export type Wave = { k: number, amp: number, phase: number }
export type Shape = {
	Radius: number,
	Waves: { Wave },
	CoastStraight: number,
	CoastBend: number,
	CoastWaves: { Wave },
	SeaReach: number,
}

-- the edge's distance from the middle in the direction `theta` (0 = +x, pi/2 = +z)
function Land.edge(shape: Shape, theta: number): number
	local r = shape.Radius
	for _, w in shape.Waves do
		r += w.amp * math.sin(w.k * theta + w.phase)
	end
	return r
end

-- the coast's x at `z`, given the straight coast's x (`seaEdge`); land is east of it
function Land.coast(shape: Shape, seaEdge: number, z: number): number
	local past = math.abs(z) - shape.CoastStraight
	if past <= 0 then
		return seaEdge
	end
	local x = seaEdge + past * past / shape.CoastBend
	-- the wiggle fades in over the first stretch, so the straight coast joins smoothly
	local fade = math.min(past / 400, 1)
	for _, w in shape.CoastWaves do
		x += fade * w.amp * math.sin(z / w.k * math.pi * 2 + w.phase)
	end
	return x
end

-- how far (x, z) is inside the edge (negative past it)
function Land.inset(shape: Shape, x: number, z: number): number
	return Land.edge(shape, math.atan2(z, x)) - math.sqrt(x * x + z * z)
end

-- land: inside the edge (by `pad`) and east of the coast (by `pad`)
function Land.isLand(shape: Shape, seaEdge: number, x: number, z: number, pad: number): boolean
	return Land.inset(shape, x, z) >= pad and x >= Land.coast(shape, seaEdge, z) + pad
end

-- inside the walls: inside the edge, and not further out to sea than SeaReach
function Land.inBounds(shape: Shape, seaEdge: number, x: number, z: number): boolean
	return Land.inset(shape, x, z) >= 0 and x >= Land.coast(shape, seaEdge, z) - shape.SeaReach
end

-- the walls' outline: `n` points round the middle, each where a ray from the middle leaves the bounds
function Land.outline(shape: Shape, seaEdge: number, n: number): { { x: number, z: number } }
	local out = {}
	for i = 0, n - 1 do
		local theta = i / n * math.pi * 2
		local dx, dz = math.cos(theta), math.sin(theta)
		local lo, hi = 0, Land.edge(shape, theta)
		if Land.inBounds(shape, seaEdge, dx * hi, dz * hi) then
			lo = hi
		else
			-- the bounds along a ray are one stretch from the middle, so halving finds the way out
			for _ = 1, 24 do
				local mid = (lo + hi) / 2
				if Land.inBounds(shape, seaEdge, dx * mid, dz * mid) then
					lo = mid
				else
					hi = mid
				end
			end
		end
		table.insert(out, { x = dx * lo, z = dz * lo })
	end
	return out
end

return Land
