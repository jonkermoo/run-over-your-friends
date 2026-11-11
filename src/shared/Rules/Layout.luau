--!strict
-- Pure sums for fitting the screen UI to the device (numbers in Config/Layout).

local Layout = {}

type Config = {
	RefWidth: number,
	RefHeight: number,
	MinScale: number,
	SmallScreen: number,
	TouchClearSmall: number,
	TouchClearLarge: number,
	ThumbZoneWidth: number,
	ThumbZoneTop: number,
	TouchPitch: number,
	TouchKey: number,
}

-- the scale for a screen with this much GUI area: 1 when the layout fits, smaller when it doesn't
function Layout.scale(width: number, height: number, cfg: Config): number
	return math.clamp(math.min(width / cfg.RefWidth, height / cfg.RefHeight), cfg.MinScale, 1)
end

-- the extra scale that keeps the touch buttons at minScale when the whole UI is drawn at scale
function Layout.touchBoost(scale: number, minScale: number): number
	return math.max(scale, minScale) / scale
end

-- how far above the bottom edge the touch buttons stay, in real pixels, to clear the jump button
function Layout.touchClear(width: number, height: number, cfg: Config): number
	return if math.min(width, height) <= cfg.SmallScreen
		then cfg.TouchClearSmall
		else cfg.TouchClearLarge
end

-- should the touch buttons use the wide two-row rack? Yes when the three-row rack's top would come within
-- gap of the cash box's bottom. All real pixels from the GUI's top: guiHeight, clear (above the bottom
-- edge), cashBottom, gap; keyScale is the buttons' real size per layout px.
function Layout.touchWide(
	guiHeight: number,
	clear: number,
	keyScale: number,
	cashBottom: number,
	gap: number,
	cfg: Config
): boolean
	local tall = (2 * cfg.TouchPitch + cfg.TouchKey) * keyScale
	return guiHeight - clear - tall < cashBottom + gap
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

return Layout
