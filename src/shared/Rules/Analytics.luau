--!strict
-- Analytics rules: the device a client is on, what a player was doing when they left, value buckets, the
-- checks on what a client may send, and the Track rate limit. Pure, so Lune tests it (tests/analytics).

local Analytics = {}

export type Cfg = {
	PhoneShortSide: number,
	WreckedSeconds: number,
	TrackBurst: number,
	TrackPerSecond: number,
}

export type DeviceInfo = {
	tenFoot: boolean, -- GuiService:IsTenFootInterface(): a console
	touch: boolean,
	keyboard: boolean,
	gamepad: boolean,
	shortSide: number, -- the screen's shorter side, in GUI points
}

-- "Phone" | "Tablet" | "PC" | "Console" | "Unknown"
function Analytics.device(info: DeviceInfo, cfg: Cfg): string
	if info.tenFoot then
		return "Console"
	end
	if info.touch and not info.keyboard then
		if info.shortSide <= 0 then
			return "Unknown"
		end
		return if info.shortSide < cfg.PhoneShortSide then "Phone" else "Tablet"
	end
	if info.keyboard then
		return "PC"
	end
	if info.gamepad then
		return "Console"
	end
	return "Unknown"
end

export type ActivityInfo = {
	driving: boolean, -- sitting in their car's driver seat
	menu: boolean, -- a menu or card was open (client says)
	idle: boolean, -- no input for a while (client says)
	wreckedAgo: number?, -- seconds since another player's car flung them; nil = not this session
}

-- "Wrecked" | "Menu" | "Idle" | "Driving" | "OnFoot": the first that holds, in that order
function Analytics.activity(info: ActivityInfo, cfg: Cfg): string
	if info.wreckedAgo and info.wreckedAgo >= 0 and info.wreckedAgo <= cfg.WreckedSeconds then
		return "Wrecked"
	end
	if info.menu then
		return "Menu"
	end
	if info.idle then
		return "Idle"
	end
	if info.driving then
		return "Driving"
	end
	return "OnFoot"
end

-- a whole count in buckets with these tops: tops { 1, 2, 4, 8 } gives "1", "2", "3-4", "5-8", "9+"
function Analytics.countBucket(n: number, tops: { number }): string
	local low = 0
	for _, top in tops do
		if n <= top then
			return if low + 1 >= top then tostring(top) else `{low + 1}-{top}`
		end
		low = top
	end
	return `{low + 1}+`
end

-- an amount in ranges with these tops: tops { 2, 5 } gives "0-2", "2-5", "5+"
function Analytics.rangeBucket(x: number, tops: { number }): string
	local low = 0
	for _, top in tops do
		if x < top then
			return `{low}-{top}`
		end
		low = top
	end
	return `{low}+`
end

-- is v one of the fixed values?
function Analytics.oneOf(list: { string }, v: any): boolean
	if typeof(v) ~= "string" then
		return false
	end
	return table.find(list, v) ~= nil
end

-- a seconds value a client reported: a real, finite number in [0, max]
function Analytics.seconds(v: any, max: number): number?
	if typeof(v) ~= "number" or v ~= v or v < 0 or v > max then
		return nil
	end
	return v
end

-- is a car bought with game money the player's first? Only if they owned nothing but the starter car,
-- not counting cars that came with a pass or a Robux pack (gifted)
function Analytics.firstBought(
	owned: { [string]: boolean },
	starter: string,
	gifted: { [string]: boolean }
): boolean
	for id, yes in owned do
		if yes and id ~= starter and not gifted[id] then
			return false
		end
	end
	return true
end

export type Bucket = { tokens: number, at: number }

-- the Track rate limit: true (and one token used) when the message may go through
function Analytics.take(bucket: Bucket, now: number, cfg: Cfg): boolean
	local dt = math.max(0, now - bucket.at)
	bucket.tokens = math.min(cfg.TrackBurst, bucket.tokens + dt * cfg.TrackPerSecond)
	bucket.at = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

return Analytics
