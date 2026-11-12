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

-- who invited a player who just joined: Roblox's referrer when the join came from an invite, else the
-- "invite:<userId>" launch data our invite prompt sets; nil for themselves, nonsense or no one
function Social.inviter(referredBy: number?, launchData: string?, selfId: number): number?
	local id = if typeof(referredBy) == "number" and referredBy > 0 then referredBy else nil
	if not id and typeof(launchData) == "string" then
		id = tonumber(string.match(launchData, "^invite:(%d+)$"))
	end
	if id and id ~= selfId then
		return id
	end
	return nil
end

-- what an invite pays when the invited friend joins the inviter's server: the inviter once per friend, up to
-- maxPaid friends ever (so alt accounts can't farm it), and the newcomer one welcome bonus ever
function Social.inviteReward(
	paidFor: { [string]: boolean },
	friendId: number,
	newcomerWelcomed: boolean,
	reward: number,
	welcome: number,
	maxPaid: number
): (number, number)
	local paid = 0
	for _ in paidFor do
		paid += 1
	end
	local forInviter = if paidFor[tostring(friendId)] or paid >= maxPaid then 0 else reward
	local forNewcomer = if newcomerWelcomed then 0 else welcome
	return forInviter, forNewcomer
end

return Social
