--!strict
-- Per-player cooldowns for remotes: allow(player, key, seconds) is true at most once per `seconds`.

local Players = game:GetService("Players")

local RateLimit = {}
local last: { [Player]: { [string]: number } } = {}

function RateLimit.allow(player: Player, key: string, seconds: number): boolean
	local t = last[player]
	if not t then
		t = {}
		last[player] = t
	end
	local now = os.clock()
	if (t[key] or -math.huge) + seconds > now then
		return false
	end
	t[key] = now
	return true
end

Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
end)

return RateLimit
