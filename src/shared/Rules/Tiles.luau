--!strict
-- Roblox caps a part at 2048 studs per side (a bigger size is silently cut down), so long map pieces
-- (the ground, the outer roads, the ring highway) are laid as equal tiles that cover the same area.
-- Pure, so Lune tests it.

local Tiles = {}

export type Tile = { x: number, z: number, sx: number, sz: number } -- centre offset and size, in studs

function Tiles.split(sizeX: number, sizeZ: number, max: number): { Tile }
	local nx, nz = math.max(1, math.ceil(sizeX / max)), math.max(1, math.ceil(sizeZ / max))
	local sx, sz = sizeX / nx, sizeZ / nz
	local out: { Tile } = {}
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			table.insert(out, {
				x = -sizeX / 2 + (i + 0.5) * sx,
				z = -sizeZ / 2 + (j + 0.5) * sz,
				sx = sx,
				sz = sz,
			})
		end
	end
	return out
end

return Tiles
