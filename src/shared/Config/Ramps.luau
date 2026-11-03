--!strict
-- The look every jump ramp shares (server/RampKit): a diamond-plate deck, dark rails along both edges, a
-- yellow-and-black hazard band across the lip and white chevrons pointing up the slope. The trim is paint:
-- it never collides, so nothing bumps a wheel. Studs; colours are { r, g, b }.

export type RGB = { number }

return table.freeze({
	Deck = "DiamondPlate", -- Enum.Material name
	Rail = 1.2, -- wide and tall, along both edges
	RailColour = { 46, 48, 54 } :: RGB,
	Lip = 3, -- the hazard band's depth down the slope from the top edge
	HazardStripe = 3, -- each yellow or black block across the lip
	Hazard = { 250, 204, 40 } :: RGB,
	HazardDark = { 30, 30, 34 } :: RGB,
	Foot = 1.4, -- a steel strip across the bottom edge
	FootColour = { 150, 154, 160 } :: RGB,
	ChevronSpacing = 14, -- one chevron per this much slope (at least one)
	ChevronWidth = 1.4,
	ChevronSpan = 0.32, -- each arm's reach across, as a share of the ramp's width
	Chevron = { 245, 245, 240 } :: RGB,
	Lift = 0.06, -- how far the paint sits off the deck
})
