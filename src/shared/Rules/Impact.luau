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

-- how fast a hit NPC or player flies, studs per second
function Impact.launchSpeed(energy: number): number
	local s = Impact.strength(energy, 3000, 20000000)
	return 45 + 210 * s
end

-- how far a building hit reaches, studs; 0 when it's too soft to break anything
function Impact.breakRadius(energy: number): number
	if energy < 150000 then
		return 0
	end
	return 6 + 22 * Impact.strength(energy, 150000, 30000000)
end

-- self-destruct blast radius, studs, from weight and speed
function Impact.blastRadius(weightKg: number, speed: number): number
	return math.clamp(18 * (weightKg / 1000) ^ 0.4 + speed * 0.15, 14, 75)
end

return Impact
