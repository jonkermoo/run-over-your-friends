--!strict
-- How far the server trusts the speed a client claims for a hit (NpcService HitNpc, BuildingService BreakAt and
-- KnockProp, PlayerHitService PlayerHit; Rules/HitGuard). Studs and seconds unless noted.

return table.freeze({
	MphPerMs = 2.237, -- mph in one metre a second
	TopSpeedSlack = 1.2, -- a claim may reach the vehicle's top speed times this...
	JetSlack = 1.45, -- ...or this with the Roadster's jet...
	TopSpeedPad = 10, -- ...plus this many studs a second
	ClaimMargin = 15, -- and no more than the fastest the server saw the vehicle go lately, plus this (as traffic hits)
	RecentSeconds = 0.6, -- "lately": the fastest server-side speed over this long
	SampleSeconds = 0.2, -- how often the server samples each driven vehicle
	TeleportSlack = 1.5, -- a vehicle moving further than its top speed (with slack) times this between samples...
	TeleportPad = 30, -- ...plus this many studs, teleported...
	SuspectSeconds = 3, -- ...and its hits pay nothing for this long
})
