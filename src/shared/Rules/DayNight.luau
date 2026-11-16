--!strict
-- Day/night rules, pure so Lune tests them: where in the cycle the shared clock is, the look there (eased
-- between stops), and when each window pane switches on.

local DayNight = {}

export type Stop = { at: number, clock: number, look: string }
export type Sample = { clock: number, look: { [string]: any } }

-- seconds into the cycle: `epoch` is when the cycle's second 0 was (server time), `speed` how fast it runs
function DayNight.phase(now: number, epoch: number, speed: number, cycle: number): number
	return ((now - epoch) * speed) % cycle
end

-- a new epoch that keeps the cycle where it is while the speed changes
function DayNight.rebase(now: number, epoch: number, speed: number, newSpeed: number): number
	return now - (now - epoch) * speed / newSpeed
end

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

local function mix(a: any, b: any, t: number): any
	if type(a) == "number" then
		return a + (b - a) * t
	end
	local out = {}
	for i, v in a do
		out[i] = v + (b[i] - v) * t
	end
	return out
end

-- the stops either side of `t` and how far between them (eased), wrapping the last stop into the first
function DayNight.between(stops: { Stop }, t: number, cycle: number): (Stop, Stop, number, number)
	local n = #stops
	for i = n, 1, -1 do
		local a = stops[i]
		if t >= a.at then
			local b = stops[i % n + 1]
			local bAt = if i == n then b.at + cycle else b.at
			local span = bAt - a.at
			local f = if span > 0 then (t - a.at) / span else 0
			local wrap = if i == n then 24 else 0
			return a, b, ease(f), wrap
		end
	end
	-- before the first stop (only when the first isn't at 0): run on from the last
	local a, b = stops[n], stops[1]
	local span = b.at + cycle - a.at
	local f = (t + cycle - a.at) / span
	return a, b, ease(f), 24
end

-- the clock (0..24) and every look value at `t`
function DayNight.sample(
	stops: { Stop },
	looks: { [string]: any },
	t: number,
	cycle: number
): Sample
	local a, b, f, wrap = DayNight.between(stops, t, cycle)
	local clock = (a.clock + (b.clock + wrap - a.clock) * f) % 24
	local la, lb = looks[a.look], looks[b.look]
	local look = {}
	for k, v in la do
		look[k] = mix(v, lb[k], f)
	end
	return { clock = clock, look = look }
end

-- a steady 0..1 number from a position, so each pane keeps its own fate on every client
function DayNight.hash(x: number, y: number, z: number): number
	local h = math.floor(x * 7.31 + 0.5) * 73856093
		+ math.floor(y * 3.17 + 0.5) * 19349663
		+ math.floor(z * 5.53 + 0.5) * 83492791
	h = h % 1000003
	return h / 1000003
end

-- the Glow a pane switches on at, or nil if it never does
function DayNight.paneOn(h: number, share: number, firstAt: number, lastAt: number): number?
	if h >= share then
		return nil
	end
	return firstAt + (lastAt - firstAt) * (h / share)
end

return DayNight
