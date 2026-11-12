--!strict
-- Keeping screen-edge pointers (the tutorial's edge arrow, the giant finder) off the HUD pieces that sit at
-- the screen's edges (the controls card, the speedometer). Pure, so Lune tests it.

local Clear = {}

-- a box by its top-left corner and size, in the same pixels as the pointer
export type Rect = { x: number, y: number, w: number, h: number }

local function overlaps(x: number, y: number, w: number, h: number, r: Rect, gap: number): boolean
	return math.abs(x - (r.x + r.w / 2)) < (w + r.w) / 2 + gap
		and math.abs(y - (r.y + r.h / 2)) < (h + r.h) / 2 + gap
end

-- moves a box of size w x h centred at (x, y) out of every rect in `keep`, sliding it along the screen edge
-- it sits on: up or down off a box on the left or right edge, sideways off one on the top or bottom edge.
-- It goes the way that stays on a screen of sw x sh, and stays `gap` clear of the box it left.
function Clear.slide(
	x: number,
	y: number,
	w: number,
	h: number,
	keep: { Rect },
	sw: number,
	sh: number,
	gap: number
): (number, number)
	for _ = 1, 3 do -- a move can land on another box; a few passes settle it
		local moved = false
		for _, r in keep do
			if overlaps(x, y, w, h, r, gap) then
				local sideways = math.min(y, sh - y) < math.min(x, sw - x) -- on the top or bottom edge
				if sideways then
					local left = r.x - gap - w / 2
					local right = r.x + r.w + gap + w / 2
					x = if left >= w / 2 and (x <= r.x + r.w / 2 or right > sw - w / 2)
						then left
						else right
				else
					local up = r.y - gap - h / 2
					local down = r.y + r.h + gap + h / 2
					y = if up >= h / 2 and (y <= r.y + r.h / 2 or down > sh - h / 2)
						then up
						else down
				end
				moved = true
			end
		end
		if not moved then
			break
		end
	end
	return x, y
end

return Clear
