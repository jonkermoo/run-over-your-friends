--!strict
-- Pure sums for fitting the screen UI to the device (numbers in Config/Layout).

local Layout = {}

type Config = {
	RefWidth: number,
	RefHeight: number,
	MinScale: number,
	SmallScreen: number,
	ThumbZoneWidth: number,
	ThumbZoneTop: number,
	JumpSmall: Jump,
	JumpLarge: Jump,
}
type Jump = { size: number, right: number, bottom: number }

-- the scale for a screen with this much GUI area: 1 when the layout fits, smaller when it doesn't
function Layout.scale(width: number, height: number, cfg: Config): number
	return math.clamp(math.min(width / cfg.RefWidth, height / cfg.RefHeight), cfg.MinScale, 1)
end

-- where a menu sheet's middle goes, from the GUI's top (layout px): the middle of the screen, nudged down
-- just enough to keep its top under the menu strip (top) and up to keep its bottom above the margin (bottom)
function Layout.sheetCentre(
	guiHeight: number,
	sheetHeight: number,
	top: number,
	bottom: number
): number
	local h = math.min(sheetHeight, guiHeight - top - bottom)
	return math.clamp(guiHeight / 2, top + h / 2, math.max(top + h / 2, guiHeight - bottom - h / 2))
end

-- the extra scale that keeps the touch buttons at minScale when the whole UI is drawn at scale
function Layout.touchBoost(scale: number, minScale: number): number
	return math.max(scale, minScale) / scale
end

-- Roblox's jump button on a screen this size when it can't be read from the screen: its centre and size,
-- real pixels from the GUI's top-left (Roblox makes it smaller when the short side is SmallScreen or less)
function Layout.jumpButton(width: number, height: number, cfg: Config): (number, number, number)
	local j = if math.min(width, height) <= cfg.SmallScreen then cfg.JumpSmall else cfg.JumpLarge
	return width - j.right - j.size / 2, height - j.bottom - j.size / 2, j.size
end

-- the centre of a touch key in slot {left, up} of the fan around the jump button (centre jx, jy, size
-- jumpSize), all real pixels: the first step clears the jump button's edge by gap, each further one is pitch
function Layout.touchSpot(
	slot: { number },
	jx: number,
	jy: number,
	jumpSize: number,
	key: number,
	pitch: number,
	gap: number
): (number, number)
	local function along(steps: number): number
		return if steps <= 0 then 0 else jumpSize / 2 + gap + key / 2 + (steps - 1) * pitch
	end
	return jx - along(slot[1]), jy - along(slot[2])
end

-- is this point (real pixels) where the thumbstick takes touches? Buttons there would steal them.
function Layout.inThumbZone(
	x: number,
	y: number,
	width: number,
	height: number,
	cfg: Config
): boolean
	return x < width * cfg.ThumbZoneWidth and y >= height * cfg.ThumbZoneTop
end

-- which section of a scrolling page is in view: the last whose top (px from the page's top, in page order)
-- is at or above `slack` px down, or the last one once the page is scrolled to its end
function Layout.sectionAt(tops: { number }, slack: number, atEnd: boolean): number
	if atEnd then
		return #tops
	end
	local at = 1
	for i, top in tops do
		if top <= slack then
			at = i
		end
	end
	return at
end

return Layout
