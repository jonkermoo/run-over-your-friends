--!strict
-- The cars' finish (Config/Look Cars), pure so Lune tests it: which template parts are painted panels or
-- window glass, the material and reflectance each gets, and a painted panel's reflectance once a paint colour
-- sets its material.

local Sheen = {}

export type Config = {
	PaintMaterial: string,
	PaintReflectance: number,
	GlassMaterial: string,
	GlassReflectance: number,
}

-- a painted panel: the car's Paint, or a zone's painted piece (Z1_Paint, U2_Paint...)
function Sheen.isPaint(name: string): boolean
	return name == "Paint" or string.sub(name, -6) == "_Paint"
end

-- the material and reflectance a template part gets, or nil to leave it as it is (the body, wheels, cabin)
function Sheen.finish(name: string, cfg: Config): (string?, number?)
	if Sheen.isPaint(name) then
		return cfg.PaintMaterial, cfg.PaintReflectance
	elseif name == "Glass" then
		return cfg.GlassMaterial, cfg.GlassReflectance
	end
	return nil, nil
end

-- a painted panel's reflectance under a material: the sheen on the stock paint material only, so a paint with its
-- own finish (Neon, Foil, Ice...) looks as it did
function Sheen.paintReflectance(material: string, cfg: Config): number
	return if material == cfg.PaintMaterial then cfg.PaintReflectance else 0
end

return Sheen
