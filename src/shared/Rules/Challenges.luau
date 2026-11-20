--!strict
-- Challenge rules (Config/Challenges): which UTC day and week it is, the day's and the week's challenges picked
-- from the date alone (so every server and every player gets the same ones), saved progress, and what a chest
-- holds. Pure, so Lune tests it. Picks come from an integer hash of (salt, period, n), not a seeded generator,
-- so they don't drift between Roblox and Lune.

local Challenges = {}

export type Template = {
	id: string,
	kind: string,
	mode: "add" | "max",
	text: string,
	min: number,
	max: number,
	step: number,
	car: boolean?,
}

export type Challenge = {
	id: string,
	kind: string,
	mode: "add" | "max",
	text: string, -- the English line, filled in
	target: number,
	car: string?, -- only counts in this vehicle
}

-- saved progress for one day or one week: progress and done by challenge id
export type Progress = {
	period: number,
	progress: { [string]: number },
	done: { [string]: boolean },
}

export type Saved = {
	daily: Progress,
	weekly: Progress,
	chests: { Daily: number, Weekly: number }, -- earned, not opened yet
}

export type Prize = { cash: number, paint: string? }

local MAX_CHESTS = 99

---------------- dates

function Challenges.day(now: number, cfg: any): number
	return math.floor(now / cfg.DaySeconds)
end

function Challenges.week(now: number, cfg: any): number
	return math.floor((now - cfg.WeekOffset) / cfg.WeekSeconds)
end

-- unix time the day / week ends
function Challenges.dayEnds(day: number, cfg: any): number
	return (day + 1) * cfg.DaySeconds
end

function Challenges.weekEnds(week: number, cfg: any): number
	return (week + 1) * cfg.WeekSeconds + cfg.WeekOffset
end

---------------- picking

-- a * b mod 2^32, exact in doubles (16-bit halves)
local function mul32(a: number, b: number): number
	local aHi, aLo = bit32.rshift(a, 16), bit32.band(a, 0xFFFF)
	return (aLo * b + bit32.lshift(bit32.band(aHi * b, 0xFFFF), 16)) % 4294967296
end

-- murmur3's finaliser: every input bit moves every output bit
local function fmix(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xC2B2AE35)
	return bit32.bxor(h, bit32.rshift(h, 16))
end

-- a number in [0, 1) from (salt, period, n): the same everywhere
function Challenges.unit(salt: number, period: number, n: number): number
	local h = fmix(bit32.band(salt, 0xFFFFFFFF))
	h = fmix(bit32.bxor(h, bit32.band(period, 0xFFFFFFFF)))
	h = fmix(bit32.bxor(h, n))
	return h / 4294967296
end

local function index(r: number, count: number): number
	return math.clamp(math.floor(r * count) + 1, 1, count)
end

local function make(tpl: Template, rTarget: number, car: string?, carName: string?): Challenge
	local steps = math.floor((tpl.max - tpl.min) / tpl.step + 1e-9)
	local target = tpl.min + (index(rTarget, steps + 1) - 1) * tpl.step
	local text = string.gsub(tpl.text, "{n}", function()
		return tostring(target)
	end)
	text = string.gsub(text, "{car}", function()
		return carName or car or ""
	end)
	return {
		id = tpl.id,
		kind = tpl.kind,
		mode = tpl.mode,
		text = text,
		target = target,
		car = if tpl.car then car else nil,
	}
end

-- the day's challenges: one per daily slot, a car challenge naming one of cfg.Cars (carName gives its name for
-- the text; the id is what counts)
function Challenges.daily(day: number, cfg: any, carName: ((string) -> string)?): { Challenge }
	local out = {}
	local carId = cfg.Cars[index(Challenges.unit(cfg.DailySalt, day, 1), #cfg.Cars)]
	for s, slot in cfg.Daily.Slots do
		local tpl = slot[index(Challenges.unit(cfg.DailySalt, day, 10 + s), #slot)]
		local name = if carName then carName(carId) else carId
		table.insert(out, make(tpl, Challenges.unit(cfg.DailySalt, day, 20 + s), carId, name))
	end
	return out
end

-- the week's challenge (a list of one, like the day's)
function Challenges.weekly(week: number, cfg: any): { Challenge }
	local pool = cfg.Weekly
	local tpl = pool[index(Challenges.unit(cfg.WeeklySalt, week, 1), #pool)]
	return { make(tpl, Challenges.unit(cfg.WeeklySalt, week, 2), nil) }
end

---------------- progress

local function cleanProgress(saved: any, period: number): Progress
	local out: Progress = { period = period, progress = {}, done = {} }
	if typeof(saved) ~= "table" or saved.period ~= period then
		return out
	end
	if typeof(saved.progress) == "table" then
		for id, n in saved.progress do
			if typeof(id) == "string" and typeof(n) == "number" and n == n and n > 0 then
				out.progress[id] = n
			end
		end
	end
	if typeof(saved.done) == "table" then
		for id, yes in saved.done do
			if typeof(id) == "string" and yes == true then
				out.done[id] = true
			end
		end
	end
	return out
end

local function count(n: any): number
	if typeof(n) ~= "number" or n ~= n then
		return 0
	end
	return math.clamp(math.floor(n), 0, MAX_CHESTS)
end

-- a saved profile entry (any shape, or nil for an old profile) for this day and week: progress from another day
-- or week starts over; unopened chests are kept
function Challenges.clean(saved: any, day: number, week: number): Saved
	local s = if typeof(saved) == "table" then saved else {}
	local chests = if typeof(s.chests) == "table" then s.chests else {}
	return {
		daily = cleanProgress(s.daily, day),
		weekly = cleanProgress(s.weekly, week),
		chests = { Daily = count(chests.Daily), Weekly = count(chests.Weekly) },
	}
end

-- a game event: `amount` of `kind`, while driving `car` (nil on foot). Returns the challenges it just finished.
function Challenges.advance(
	list: { Challenge },
	prog: Progress,
	kind: string,
	amount: number,
	car: string?
): { Challenge }
	local finished = {}
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return finished
	end
	for _, c in list do
		if c.kind == kind and not prog.done[c.id] and (c.car == nil or c.car == car) then
			local was = prog.progress[c.id] or 0
			local now = if c.mode == "max" then math.max(was, amount) else was + amount
			if now >= c.target then
				now = c.target
				prog.done[c.id] = true
				table.insert(finished, c)
			end
			prog.progress[c.id] = now
		end
	end
	return finished
end

-- add a chest of `set` ("Daily" | "Weekly"), up to the cap
function Challenges.addChest(saved: Saved, set: string)
	if set == "Daily" or set == "Weekly" then
		saved.chests[set] = math.min(saved.chests[set] + 1, MAX_CHESTS)
	end
end

-- for the client: each challenge with its progress
function Challenges.view(list: { Challenge }, prog: Progress): { any }
	local out = {}
	for _, c in list do
		table.insert(out, {
			id = c.id,
			kind = c.kind,
			text = c.text,
			target = c.target,
			car = c.car,
			progress = prog.progress[c.id] or 0,
			done = prog.done[c.id] == true,
		})
	end
	return out
end

---------------- chests

-- what a chest of `set` holds. r1 and r2 are random numbers in [0, 1); `paints` the chest-only paint ids in
-- order, `has` the paints the player owns.
function Challenges.prize(
	set: string,
	r1: number,
	r2: number,
	paints: { string },
	has: { [string]: boolean },
	cfg: any
): Prize
	local c = cfg.Chests[set]
	local missing = {}
	for _, id in paints do
		if not has[id] then
			table.insert(missing, id)
		end
	end
	local paint: string? = nil
	if #missing > 0 and r1 < c.PaintChance then
		paint = missing[index(r2, #missing)]
	end
	local cash = 0
	if paint == nil and c.NoPaintCash and c.PaintAndCash then
		cash = c.NoPaintCash -- every chest paint owned already
	elseif paint == nil or c.PaintAndCash then
		local total = 0
		for _, row in c.Cash do
			total += row.weight
		end
		-- r1 below PaintChance went to the paint roll: pick the cash from r2 then, else from r1 over the rest
		local r = if r1 < c.PaintChance then r2 else (r1 - c.PaintChance) / (1 - c.PaintChance)
		local at = math.clamp(r, 0, 0.999999) * total
		for _, row in c.Cash do
			at -= row.weight
			if at < 0 then
				cash = row.amount
				break
			end
		end
	end
	return { cash = cash, paint = paint }
end

-- the chance of each cash amount and of a paint, for the chest card's odds line (paint share 0..1)
function Challenges.odds(
	set: string,
	cfg: any
): { paint: number, cash: { { amount: number, share: number } } }
	local c = cfg.Chests[set]
	local total = 0
	for _, row in c.Cash do
		total += row.weight
	end
	local cashShare = if c.PaintAndCash then 1 else 1 - c.PaintChance
	local out = {}
	for _, row in c.Cash do
		table.insert(out, { amount = row.amount, share = cashShare * row.weight / total })
	end
	return { paint = c.PaintChance, cash = out }
end

return Challenges
