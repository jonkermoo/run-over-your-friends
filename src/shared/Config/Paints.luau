--!strict
-- Car paint: the colours a player can put on a vehicle's painted panels (its Paint part, split from the body in
-- tools/blender/export_vehicles.py). Free colours are always open; the rest are bought once and then work on every
-- vehicle. "Factory" puts a vehicle back to its own colour. Colours are 0-255 sRGB.

export type Paint = {
	id: string,
	name: string,
	order: number,
	price: number, -- in-game money, paid once; 0 = always open
	rgb: { number }?, -- nil for Factory (each vehicle's own colour)
}

local Paints = {}

Paints.FactoryId = "Factory"
Paints.SetEvery = 0.4 -- seconds between paint changes a player may make

local list: { Paint } = {
	{ id = "Factory", name = "Factory", order = 1, price = 0 },
	{ id = "White", name = "White", order = 2, price = 0, rgb = { 236, 236, 232 } },
	{ id = "Silver", name = "Silver", order = 3, price = 0, rgb = { 160, 165, 172 } },
	{ id = "Black", name = "Black", order = 4, price = 0, rgb = { 34, 34, 38 } },
	{ id = "Red", name = "Red", order = 5, price = 0, rgb = { 200, 40, 36 } },
	{ id = "Orange", name = "Orange", order = 6, price = 0, rgb = { 240, 120, 30 } },
	{ id = "Yellow", name = "Yellow", order = 7, price = 0, rgb = { 242, 194, 48 } },
	{ id = "Green", name = "Green", order = 8, price = 0, rgb = { 54, 160, 80 } },
	{ id = "Blue", name = "Blue", order = 9, price = 0, rgb = { 43, 100, 205 } },
	{ id = "Pink", name = "Hot Pink", order = 10, price = 2500, rgb = { 255, 80, 165 } },
	{ id = "Purple", name = "Purple", order = 11, price = 2500, rgb = { 132, 72, 224 } },
	{ id = "Teal", name = "Teal", order = 12, price = 2500, rgb = { 20, 170, 165 } },
	{ id = "Lime", name = "Lime", order = 13, price = 2500, rgb = { 150, 220, 40 } },
	{ id = "Sky", name = "Sky", order = 14, price = 2500, rgb = { 110, 190, 250 } },
	{ id = "Maroon", name = "Maroon", order = 15, price = 2500, rgb = { 118, 22, 42 } },
	{ id = "Gold", name = "Gold", order = 16, price = 2500, rgb = { 212, 168, 58 } },
	{ id = "Midnight", name = "Midnight", order = 17, price = 2500, rgb = { 26, 36, 84 } },
}
for _, p in list do
	table.freeze(p)
end
Paints.List = table.freeze(list)

local byId: { [string]: Paint } = {}
for _, p in list do
	byId[p.id] = p
end
Paints.ById = table.freeze(byId)

-- each vehicle's own paint colour: the palette cell its Paint faces use (PAINT in export_vehicles.py)
Paints.Factory = table.freeze({
	Hatchback = { 87, 125, 71 },
	Scooter = { 194, 69, 48 },
	Sedan = { 56, 112, 176 },
	Cart = { 184, 184, 181 },
	Taxi = { 232, 163, 56 },
	Muscle = { 194, 69, 48 },
	IceCream = { 204, 204, 199 },
	FireTruck = { 173, 61, 41 },
	Semi = { 204, 204, 199 },
	Bulldozer = { 235, 163, 54 },
	Monster = { 87, 125, 71 },
	Supercar = { 232, 163, 56 },
	Roadster = { 204, 15, 18 },
} :: { [string]: { number } })

return table.freeze(Paints)
