--!strict
-- Hit maths: impact energy from weight and speed, NPC payouts, combos, launch speeds and blast sizes.
-- Pure numbers, so Lune tests it.

local Impact = {}

export type PayoutConfig = {
	NpcBase: number,
	NpcBonusMax: number,
	EnergyLow: number,
	EnergyHigh: number,
	ComboStep: number,
	ComboMax: number,
}

-- joules from kg and m/s
function Impact.energy(weightKg: number, speed: number): number
	return 0.5 * math.max(weightKg, 0) * speed * speed
end

-- 0..1 position of an energy between the low and high marks, on a log scale
function Impact.strength(energy: number, low: number, high: number): number
	if energy <= low then
		return 0
	end
	return math.clamp(math.log10(energy / low) / math.log10(high / low), 0, 1)
end

function Impact.comboMultiplier(hitsInCombo: number, step: number, max: number): number
	return math.min(max, 1 + step * math.max(hitsInCombo - 1, 0))
end

-- money for one NPC hit, before passes
function Impact.npcPayout(energy: number, hitsInCombo: number, config: PayoutConfig): number
	local s = Impact.strength(energy, config.EnergyLow, config.EnergyHigh)
	local base = config.NpcBase + config.NpcBonusMax * s
	return base * Impact.comboMultiplier(hitsInCombo, config.ComboStep, config.ComboMax)
end

-- is a player past the new players' pay boost? Yes once it ended before (`done`, saved), once they hold
-- `untilPrice` in cash, or once they own a vehicle priced at `untilPrice` or more
function Impact.rookieOver(
	owned: { [string]: boolean },
	money: number,
	done: boolean,
	byId: { [string]: { price: number } },
	untilPrice: number
): boolean
	if done or money >= untilPrice then
		return true
	end
	for id in owned do
		local vehicle = byId[id]
		if vehicle and vehicle.price >= untilPrice then
			return true
		end
	end
	return false
end

-- how fast a hit NPC or player flies, studs per second
function Impact.launchSpeed(energy: number): number
	local s = Impact.strength(energy, 3000, 20000000)
	return 45 + 210 * s
end

export type SmashConfig = {
	EnergyLow: number,
	EnergyHigh: number,
	MinRadius: number,
	MaxRadius: number,
	Curve: number,
	MinSpeed: number,
	WallEnergy: number,
	KeptLight: number,
	KeptLightWeight: number,
	KeptHeavy: number,
	KeptHeavyWeight: number,
	CollapseEnergy: number,
}

-- how far a building hit reaches, studs; 0 when it's too soft to break anything
function Impact.breakRadius(energy: number, config: SmashConfig): number
	if energy < config.EnergyLow then
		return 0
	end
	local s = Impact.strength(energy, config.EnergyLow, config.EnergyHigh) ^ config.Curve
	return config.MinRadius + (config.MaxRadius - config.MinRadius) * s
end

-- break radius for a vehicle of weightKg hitting at speed (m/s); slower than MinSpeed only bumps;
-- maxBreak (studs) caps it for vehicles that only ever knock out a piece
function Impact.smashRadius(
	weightKg: number,
	speed: number,
	config: SmashConfig,
	maxBreak: number?
): number
	if speed < config.MinSpeed then
		return 0
	end
	return math.min(
		Impact.breakRadius(Impact.energy(weightKg, speed), config),
		maxBreak or math.huge
	)
end

-- share of its speed a vehicle keeps after breaking a wall: the wall takes WallEnergy joules out of it, but
-- it always keeps a floor that grows with its weight, so heavy vehicles plough through
function Impact.wallSpeedKept(weightKg: number, speed: number, config: SmashConfig): number
	local energy = Impact.energy(weightKg, speed)
	if energy <= 0 then
		return 1
	end
	local heft = Impact.strength(weightKg, config.KeptLightWeight, config.KeptHeavyWeight)
	local floor = config.KeptLight + (config.KeptHeavy - config.KeptLight) * heft
	return math.max(math.sqrt(math.max(1 - config.WallEnergy / energy, 0)), floor)
end

-- does a vehicle of weightKg hitting at speed (m/s) bring down the whole building? Never for one with a maxBreak
function Impact.collapses(
	weightKg: number,
	speed: number,
	config: SmashConfig,
	maxBreak: number?
): boolean
	return maxBreak == nil
		and speed >= config.MinSpeed
		and Impact.energy(weightKg, speed) >= config.CollapseEnergy
end

return Impact
