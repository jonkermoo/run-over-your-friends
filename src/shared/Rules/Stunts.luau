--!strict
-- Stunts: what a finished jump is worth and what it's called. Pure, so Lune tests it. StuntService measures the
-- jump (air time, how far it spun flat, how it landed); the numbers live in Config/Stunts. Cars level
-- themselves in the air (Drive), so there are no flips: air time and 360s are what every car can do.

local Stunts = {}

export type Config = {
	MinAir: number,
	PerSecond: number,
	Spin: number,
	TrickSlack: number,
	MaxPay: number,
	Park: number,
	RefSpeed: number,
	MaxBoost: number,
}

-- a measured jump: seconds up, degrees turned about the car's up
export type Jump = {
	air: number,
	yaw: number,
	upright: boolean,
	gravity: number, -- the server's gravity over normal (low gravity makes air cheap)
	topSpeed: number,
	inPark: boolean,
}

export type Result = {
	counts: boolean, -- long enough to be a jump at all
	clean: boolean, -- landed on its wheels (pays)
	pay: number,
	air: number, -- seconds, scaled for gravity
	spins: number,
	label: string,
}

-- whole turns in `degrees`, a little short still counting
function Stunts.turns(degrees: number, slack: number): number
	return math.floor((math.abs(degrees) + slack) / 360)
end

function Stunts.boost(topSpeed: number, cfg: Config): number
	return math.clamp(cfg.RefSpeed / math.max(topSpeed, 1), 1, cfg.MaxBoost)
end

-- the popup's name for the jump: its spins, else how much air
function Stunts.label(air: number, spins: number): string
	if spins > 0 then
		return `{spins * 360}`
	elseif air >= 3 then
		return "HUGE AIR"
	elseif air >= 1.5 then
		return "BIG AIR"
	end
	return "AIR"
end

function Stunts.score(j: Jump, cfg: Config): Result
	local air = j.air * math.min(j.gravity, 1)
	local spins = Stunts.turns(j.yaw, cfg.TrickSlack)
	local counts = air >= cfg.MinAir
	local raw = air * cfg.PerSecond + spins * cfg.Spin
	local pay = raw * Stunts.boost(j.topSpeed, cfg) * (if j.inPark then cfg.Park else 1)
	pay = math.min(math.floor(pay / 10 + 0.5) * 10, cfg.MaxPay)
	local clean = counts and j.upright
	return {
		counts = counts,
		clean = clean,
		pay = if clean then pay else 0,
		air = air,
		spins = spins,
		label = if not counts
			then ""
			elseif not j.upright then "WIPEOUT"
			else Stunts.label(air, spins),
	}
end

return Stunts
