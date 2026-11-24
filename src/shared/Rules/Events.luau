--!strict
-- Event schedule: given seconds since the server started, which phase it is (quiet, warning, running),
-- which event, and when that phase ends. Events take turns in order, starting at a seeded position.
-- Pure, so Lune tests it.

local Events = {}

export type Phase = { phase: "quiet" | "warn" | "live", index: number, endsIn: number }

-- t: seconds since start; count: how many events; first: when the first one starts
function Events.phase(
	t: number,
	count: number,
	first: number,
	gap: number,
	duration: number,
	warn: number,
	offset: number
): Phase
	if count <= 0 then
		return { phase = "quiet", index = 0, endsIn = math.huge }
	end
	local cycle = gap + duration
	-- start times: first, first + cycle, first + 2 * cycle, ...
	local n = math.floor((t - first) / cycle)
	local start = first + math.max(n, 0) * cycle
	if t < first then
		start = first
		n = 0
	end
	local index = (math.max(n, 0) + offset) % count + 1
	if t >= start and t < start + duration then
		return { phase = "live", index = index, endsIn = start + duration - t }
	end
	-- after this one ends, the next one starts a gap later
	local nextStart = if t < start then start else start + cycle
	local nextIndex = if t < start then index else (math.max(n, 0) + 1 + offset) % count + 1
	local untilNext = nextStart - t
	if untilNext <= warn then
		return { phase = "warn", index = nextIndex, endsIn = untilNext }
	end
	return { phase = "quiet", index = nextIndex, endsIn = untilNext - warn }
end

-- where the event sign goes, kept clear of the menu strip (the tab strip, top left). All in layout px from the
-- top left of the screen area both sit in: y, h, w are the sign's top, height and width (it's centred on a
-- screen screenW wide), menu the strip's edges (nil while it's hidden). With no top bar to sit in (a Studio
-- client, some consoles) the sign shares the strip's row, so where the two would touch, the sign drops under
-- the strip.
export type Box = { left: number, top: number, right: number, bottom: number }
function Events.signTop(
	y: number,
	h: number,
	w: number,
	screenW: number,
	menu: Box?,
	gap: number
): number
	if not menu then
		return y
	end
	local rowsApart = y >= menu.bottom + gap or y + h + gap <= menu.top
	local besideIt = screenW / 2 - w / 2 >= menu.right + gap
	if rowsApart or besideIt then
		return y
	end
	return menu.bottom + gap
end

return Events
