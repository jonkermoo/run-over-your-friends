--!strict
-- Daily rules: which UTC day it is, the login streak, and the car of the day. Pure, so Lune tests it.

local Daily = {}

export type Streak = { day: number, streak: number }

function Daily.day(now: number, daySeconds: number): number
	return math.floor(now / daySeconds)
end

-- what collecting today would make the streak: one more after yesterday, else back to 1.
-- nil when today is already collected.
function Daily.next(saved: Streak?, today: number): number?
	if not saved then
		return 1
	end
	if saved.day >= today then
		return nil
	end
	if saved.day == today - 1 then
		return math.max(saved.streak, 0) + 1
	end
	return 1
end

function Daily.reward(streak: number, rewards: { number }): number
	return rewards[math.clamp(streak, 1, #rewards)]
end

-- a * b mod 2^32 without losing bits in a double (each half product stays under 2^49)
local function mul32(a: number, b: number): number
	local lo = bit32.band(a, 0xFFFF) * b
	local hi = (bit32.rshift(a, 16) * b) % 0x100000000
	return (lo + hi * 0x10000) % 0x100000000
end

-- murmur3's 32-bit finaliser: a real integer hash, so nearby days don't give related orders
local function fmix(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xC2B2AE35)
	return bit32.bxor(h, bit32.rshift(h, 16))
end

local function hash(a: number, b: number): number
	return fmix(bit32.bxor(fmix(bit32.band(a, 0xFFFFFFFF)), b))
end

-- one block of #ids days: every id once, in an order shuffled from the block number
local function block(ids: { string }, n: number, salt: number): { string }
	local order = table.clone(ids)
	for i = #order, 2, -1 do
		local j = hash(n * 131 + salt, i) % i + 1
		order[i], order[j] = order[j], order[i]
	end
	return order
end

-- the car on sale that day: ids is the list of cars that can be on sale, in a fixed order.
-- Every car gets one day per block, and a block never starts with the car that ended the last one.
function Daily.carOfDay(ids: { string }, day: number, salt: number): string?
	local count = #ids
	if count == 0 then
		return nil
	end
	if count == 1 then
		return ids[1]
	end
	local n = math.floor(day / count)
	local order = block(ids, n, salt)
	if order[1] == block(ids, n - 1, salt)[count] then
		order[1], order[2] = order[2], order[1]
	end
	return order[day - n * count + 1]
end

-- the cars that can be on sale: priced and not skipped, in shop order
function Daily.saleIds(
	list: { { id: string, price: number, order: number } },
	skip: { [string]: boolean }
): { string }
	local rows = {}
	for _, v in list do
		if v.price > 0 and not skip[v.id] then
			table.insert(rows, v)
		end
	end
	table.sort(rows, function(a, b)
		return a.order < b.order
	end)
	local ids = {}
	for _, v in rows do
		table.insert(ids, v.id)
	end
	return ids
end

-- a player's car of the day: the day's pick from the sale cars they don't own yet; nil if they own them all
function Daily.pickFor(
	ids: { string },
	owned: { [string]: boolean },
	day: number,
	salt: number
): string?
	local left = {}
	for _, id in ids do
		if not owned[id] then
			table.insert(left, id)
		end
	end
	return Daily.carOfDay(left, day, salt)
end

function Daily.salePrice(price: number, share: number, round: number): number
	return math.max(0, math.floor(price * (1 - share) / round + 0.5) * round)
end

-- what a car costs on a given day
function Daily.price(
	id: string,
	price: number,
	onSale: string?,
	share: number,
	round: number
): number
	return if id == onSale then Daily.salePrice(price, share, round) else price
end

return Daily
