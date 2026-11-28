--!strict
-- Event schedule: after each event, how long until the next and which one. A longer wait brings a bigger event
-- (Config/Events Tiers: quick ones after short gaps, contests in the middle, big ones after the longest). The
-- same event never runs twice in a row, and neither do two place contests. Pure (the random rolls are passed
-- in), so Lune tests it.

local Events = {}

export type Tier = { key: string, weight: number, gap: { number }, duration: number }
export type Item = { tier: number, duration: number?, contest: { pay: string? }? }

-- a contest paid by place (top 3): these never run back to back. Share contests (the Boss Truck) don't count.
function Events.isContest(e: Item): boolean
	return e.contest ~= nil and e.contest.pay ~= "share"
end

-- the tier a wait of `gap` seconds belongs to (the first before the shortest, the last past the longest)
function Events.tierOf(gap: number, tiers: { Tier }): number
	for i, t in tiers do
		if gap < t.gap[2] then
			return i
		end
	end
	return #tiers
end

-- how long an event runs: its own length, else its tier's
function Events.duration(e: Item, tiers: { Tier }): number
	return e.duration or tiers[e.tier].duration
end

-- the next event (an index into `list`) and the wait before it starts, in seconds. `last` is the event that
-- just ran (nil at the start). rTier, rGap, rPick are random rolls 0-1: which tier (by weight), where in its
-- gap range, which of its events. forceGap fixes the wait (a new server's first event) and so the tier. A
-- tier with nothing allowed (a contest just ran and only contests are left) falls back to the tiers below,
-- then above, with that tier's own gap.
function Events.pick(
	list: { Item },
	tiers: { Tier },
	last: number?,
	rTier: number,
	rGap: number,
	rPick: number,
	forceGap: number?
): (number, number)
	local want = 1
	if forceGap then
		want = Events.tierOf(forceGap, tiers)
	else
		local total = 0
		for _, t in tiers do
			total += t.weight
		end
		local at = rTier * total
		want = #tiers
		for i, t in tiers do
			at -= t.weight
			if at < 0 then
				want = i
				break
			end
		end
	end
	local lastWasContest = last ~= nil and list[last] ~= nil and Events.isContest(list[last])
	local order = { want }
	for t = want - 1, 1, -1 do
		table.insert(order, t)
	end
	for t = want + 1, #tiers do
		table.insert(order, t)
	end
	for _, t in order do
		local options = {}
		for i, e in list do
			if e.tier == t and i ~= last and not (lastWasContest and Events.isContest(e)) then
				table.insert(options, i)
			end
		end
		if #options > 0 then
			local index = options[math.clamp(math.floor(rPick * #options) + 1, 1, #options)]
			local range = tiers[t].gap
			local gap = forceGap or (range[1] + (range[2] - range[1]) * rGap)
			return index, gap
		end
	end
	return 1, forceGap or tiers[1].gap[1]
end

-- how much a server of `players` needs (truck hits, boss health): base for one, plus `per` for each other one,
-- up to `max`
function Events.needed(base: number, per: number, players: number, max: number?): number
	local n = base + per * math.max(players - 1, 0)
	return if max then math.min(n, max) else n
end

export type DamageConfig = {
	Damage: number,
	DamageSpeed: number,
	WeightRef: number,
	DamageMin: number,
	DamageMax: number,
}
-- one hit on the Boss Truck: in step with the closing speed (m/s) and the square root of the hitter's weight (kg)
function Events.damage(closing: number, weightKg: number, c: DamageConfig): number
	local d = c.Damage * (closing / c.DamageSpeed) * math.sqrt(math.max(weightKg, 1) / c.WeightRef)
	return math.floor(math.clamp(d, c.DamageMin, c.DamageMax) + 0.5)
end

-- the Money Truck knocked into the air by a hit, as a car hitting a car is (server/PlayerHitService): the hit's
-- launch speed (Impact.launchSpeed) times the square root of the hitter's weight over the truck's (that ratio
-- clamped RatioMin-RatioMax, as a car hit), times Scale, capped by the hitter's car launch cap and MaxSpeed.
-- studs/s.
export type KnockConfig = {
	Weight: number,
	Scale: number,
	RatioMin: number,
	RatioMax: number,
	MaxSpeed: number,
}
function Events.knockSpeed(launch: number, weightKg: number, cap: number, c: KnockConfig): number
	local ratio = math.clamp(math.max(weightKg, 1) / c.Weight, c.RatioMin, c.RatioMax) ^ 0.5
	return math.min(launch * ratio * c.Scale, cap, c.MaxSpeed)
end

-- seconds a knock with `up` studs/s upward stays in the air under gravity `g`
function Events.airTime(up: number, g: number): number
	return if up > 0 and g > 0 then 2 * up / g else 0
end

-- where a knocked truck is `t` seconds after the hit, from its spot on the route (studs): it flies on (vx, vy, vz)
-- until it lands, then drives back into its lane over `back` seconds. Also its tumble, 0-1 through the flight.
function Events.knockOffset(
	t: number,
	vx: number,
	vy: number,
	vz: number,
	g: number,
	back: number
): (number, number, number, number)
	local air = Events.airTime(vy, g)
	if t <= 0 or air <= 0 then
		return 0, 0, 0, 0
	end
	if t < air then
		return vx * t, vy * t - g * t * t / 2, vz * t, t / air
	end
	local k = if back > 0 then math.clamp((t - air) / back, 0, 1) else 1
	local keep = 1 - k * k * (3 - 2 * k)
	return vx * air * keep, 0, vz * air * keep, 1
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
