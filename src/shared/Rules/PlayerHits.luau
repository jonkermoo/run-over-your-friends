--!strict
-- Player-on-player hit rules (numbers in Config/PlayerHits): which terms an attacker's car hits with,
-- and how much a repeat hit on the same player still does.

export type Terms = {
	shield: number,
	ragdoll: number,
	carRecover: number,
	parkedRecover: number,
	launchCap: number,
	carLaunchCap: number,
}

export type Config = {
	BigCarPrice: number,
	CheapCarPrice: number,
	CheapCarLaunchCap: number,
	RepeatFactor: number,
	RepeatFloor: number,
	Normal: Terms,
	Big: Terms,
}

local PlayerHits = {}

function PlayerHits.isBig(price: number, cfg: Config): boolean
	return price >= cfg.BigCarPrice
end

function PlayerHits.terms(price: number, cfg: Config): Terms
	return if PlayerHits.isBig(price, cfg) then cfg.Big else cfg.Normal
end

-- fastest an attacker's car can knock another car: cheap cars knock less, Big cars use the Big cap
function PlayerHits.carLaunchCap(price: number, cfg: Config): number
	if PlayerHits.isBig(price, cfg) then
		return cfg.Big.carLaunchCap
	end
	local low, high = cfg.CheapCarPrice, cfg.BigCarPrice
	local t = if price <= low
		then 0
		else math.clamp(math.log(price / low) / math.log(high / low), 0, 1)
	return cfg.CheapCarLaunchCap + (cfg.Normal.carLaunchCap - cfg.CheapCarLaunchCap) * t
end

-- share of the full launch a hit does after `earlier` recent hits by the same attacker on the same player
function PlayerHits.repeatScale(earlier: number, price: number, cfg: Config): number
	if PlayerHits.isBig(price, cfg) then
		return 1
	end
	return math.max(cfg.RepeatFloor, cfg.RepeatFactor ^ earlier)
end

return PlayerHits
