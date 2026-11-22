--!strict
-- User ids kept off every leaderboard and the champions' podium, on top of Config/Leaderboards Hidden. Its own
-- file so changing it doesn't touch the map code the terrain bake is fingerprinted from.

return table.freeze({
	[180563380] = true, -- the developer
} :: { [number]: boolean })
