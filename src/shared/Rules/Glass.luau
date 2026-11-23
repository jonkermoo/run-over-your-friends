--!strict
-- Window glass tints (Config/Look Glass), pure so Lune tests them: which tint a building wears, and a pane's
-- new hue, saturation and value from its old ones.

local Glass = {}

export type Config = {
	Tints: { { number } },
	ValueMin: number,
	ValueMax: number,
	ValueGain: number,
	MinTransparency: number,
}

-- a steady tint index (1..count) from a building's name, so every server and client agree
function Glass.pick(name: string, count: number): number
	local h = 0
	for i = 1, #name do
		h = (h * 31 + string.byte(name, i)) % 1000003
	end
	return h % count + 1
end

-- the pane's colour in the tint: the tint's hue, saturation capped at the tint's, lightness kept but clamped
function Glass.tint(s: number, v: number, tint: { number }, cfg: Config): (number, number, number)
	return tint[1], math.min(s, tint[2]), math.clamp(v * cfg.ValueGain, cfg.ValueMin, cfg.ValueMax)
end

return Glass
