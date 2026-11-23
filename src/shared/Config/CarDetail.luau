--!strict
-- Vehicle finishing detail (tools/blender/vehicle_detail.py): each car's head lamp lenses (Lamp), tail lamp lenses
-- (Tail), chrome bezels, grille slats and side strips (Trim) and number plates (Plate) are their own small meshes,
-- named <Kind> or, inside a mastery zone, Z<n>_<Kind> (they go with that zone). tools/lune/import_vehicles gives
-- them the look below; they never collide. Colours are 0-255 sRGB; material is an Enum.Material name.

local CarDetail = {}

CarDetail.Kinds = table.freeze({ "Lamp", "Tail", "Trim", "Plate" })

CarDetail.Look = table.freeze({
	Lamp = table.freeze({ rgb = { 255, 238, 204 }, material = "Neon" }), -- warm white, lit
	Tail = table.freeze({ rgb = { 150, 16, 20 }, material = "Neon" }), -- deep red: brighter reds bloom pink
	Trim = table.freeze({ material = "Metal" }), -- keeps its palette texture (chrome, rubber)
	Plate = table.freeze({}), -- the plate sheet texture (tools/art/plates.py), plain plastic
})

return table.freeze(CarDetail)
