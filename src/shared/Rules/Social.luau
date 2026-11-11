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

-- Friends in the server, as the player attribute FriendsHere carries them: one "<userId> <display name>"
-- per line. The server writes it; each client reads it to draw friend outlines and tags.
export type FriendEntry = { id: number, name: string }

function Social.encodeFriends(list: { FriendEntry }): string
	local lines = {}
	for _, f in list do
		table.insert(lines, `{f.id} {f.name}`)
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end

function Social.decodeFriends(s: string): { FriendEntry }
	local out = {}
	for line in string.gmatch(s, "[^\n]+") do
		local id, name = string.match(line, "^(-?%d+) (.+)$")
		if id and name then
			table.insert(out, { id = tonumber(id) :: number, name = name })
		end
	end
	return out
end

-- how `viewer` sees a player with these friends: "mine" (a friend of the viewer), "other" with the
-- first other friend (the one the tag names), or nil for a stranger
function Social.friendTag(
	list: { FriendEntry },
	viewer: number
): ("mine" | "other" | nil, FriendEntry?)
	for _, f in list do
		if f.id == viewer then
			return "mine", f
		end
	end
	if list[1] then
		return "other", list[1]
	end
	return nil, nil
end

return Social
