--!strict
-- Playing-together rules: the friend money bonus and when a launch toast may show. Pure, so Lune tests it.

local Social = {}

-- money multiplier for having `friends` Roblox friends in the server
function Social.friendMultiplier(friends: number, per: number, max: number): number
	return 1 + math.clamp(friends * per, 0, max)
end

-- the percent shown on the HUD chip ("FRIENDS +20%")
function Social.friendPercent(friends: number, per: number, max: number): number
	return math.floor((Social.friendMultiplier(friends, per, max) - 1) * 100 + 0.5)
end

export type ToastState = { hitter: { [number]: number }, pair: { [string]: number } }

function Social.newToasts(): ToastState
	return { hitter = {}, pair = {} }
end

local function pairKey(a: number, b: number): string
	return if a < b then `{a}:{b}` else `{b}:{a}`
end

-- may a launch of `studs` by `hitter` on `victim` (user ids) show a toast at `now`? Records it when yes.
-- Too-short flights and ones inside a gap are dropped, never queued, so a busy fight can't spam.
function Social.allowToast(
	state: ToastState,
	hitter: number,
	victim: number,
	studs: number,
	now: number,
	cfg: {
		ToastMinStuds: number,
		ToastHitterGap: number,
		ToastPairGap: number,
	}
): boolean
	if hitter == victim or studs < cfg.ToastMinStuds then
		return false
	end
	local key = pairKey(hitter, victim)
	if now - (state.hitter[hitter] or -math.huge) < cfg.ToastHitterGap then
		return false
	end
	if now - (state.pair[key] or -math.huge) < cfg.ToastPairGap then
		return false
	end
	state.hitter[hitter] = now
	state.pair[key] = now
	return true
end

-- forget a player who left
function Social.forget(state: ToastState, userId: number)
	state.hitter[userId] = nil
	local prefix, suffix = `{userId}:`, `:{userId}`
	for key in state.pair do
		if string.sub(key, 1, #prefix) == prefix or string.sub(key, -#suffix) == suffix then
			state.pair[key] = nil
		end
	end
end

-- the two toast lines: what the launcher sees, what the one launched sees
function Social.toastText(hitterName: string, victimName: string, studs: number): (string, string)
	local n = math.floor(studs + 0.5)
	return `You launched {victimName} {n} studs!`, `{hitterName} launched you {n} studs!`
end

return Social
