--!strict
-- The speed a hit is paid at, from what the client claims and what the server saw (Config/HitGuard). Pure, so
-- Lune tests it.

local HitGuard = {}

export type Config = {
	MphPerMs: number,
	TopSpeedSlack: number,
	JetSlack: number,
	TopSpeedPad: number,
	ClaimMargin: number,
	TeleportSlack: number,
	TeleportPad: number,
}

-- the most any claim can be for this vehicle (studs a second)
function HitGuard.maxStuds(
	topSpeedMph: number,
	jet: boolean,
	studsPerMetre: number,
	cfg: Config
): number
	return topSpeedMph
			/ cfg.MphPerMs
			* studsPerMetre
			* (if jet then cfg.JetSlack else cfg.TopSpeedSlack)
		+ cfg.TopSpeedPad
end

-- the speed paid: the claim, capped at the vehicle's limit and at the fastest the server saw it go lately
function HitGuard.speed(
	claimed: number,
	maxStuds: number,
	seenRecently: number,
	cfg: Config
): number
	return math.min(claimed, maxStuds, seenRecently + cfg.ClaimMargin)
end

-- did the vehicle jump further across the ground than it could drive in dt seconds?
function HitGuard.teleported(
	flatDistance: number,
	dt: number,
	maxStuds: number,
	cfg: Config
): boolean
	return flatDistance > maxStuds * dt * cfg.TeleportSlack + cfg.TeleportPad
end

return HitGuard
