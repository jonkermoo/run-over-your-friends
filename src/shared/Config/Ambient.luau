--!strict
-- Gentle motion in the city, made on each screen only (client/Ambient): spray from the fountains and park
-- ponds, the spawn plaza's banners swaying, small bird flocks circling over downtown, steam from a few office
-- rooftop vents. Every piece runs only near the camera and is pooled; none of it is a map part except the vent
-- boxes. Studs, seconds, particles per second; colours are { r, g, b }.

export type RGB = { number }
export type Flock = { x: number, z: number, height: number, radius: number }

return table.freeze({
	Tags = table.freeze({ Spray = "AmbientSpray", Flag = "AmbientFlag", Steam = "AmbientSteam" }),
	-- what is checked against the camera, and how often
	Range = 450,
	RangePhone = 280,
	CheckEvery = 0.5,
	-- on a phone, emitters run at this share of their rate
	PhoneRate = 0.5,

	-- fountains and ponds: a jet straight up from the water's middle (`Lift` over the water part's middle,
	-- set per fountain by the server as the tag's attribute SprayLift)
	Spray = table.freeze({
		Rate = 40,
		Speed = table.freeze({ 22, 25 }),
		Lifetime = table.freeze({ 1.2, 1.5 }),
		Spread = 9,
		Gravity = 36,
		Size = table.freeze({ 0.7, 1.8 }), -- at birth, at death
		Transparency = table.freeze({ 0.25, 0.45 }), -- at birth, at 70% of its life (then fades out)
		Colour = { 235, 248, 255 } :: RGB,
		PondSpeed = 0.75, -- park ponds have no column: a lower jet
	}),
	FountainLift = 10.6, -- the plaza fountain's jet starts this far over the water (its column top)
	PondLift = 0.5,

	-- banners swing about their pole: this many degrees either way, one sway every `Period` seconds; each
	-- banner starts at its own point in the sway
	Flag = table.freeze({ Degrees = 9, Period = 2.6 }),

	-- bird flocks: each circles a point over downtown, `Birds` small dark birds in a loose V, flapping
	Flocks = table.freeze({
		{ x = 0, z = 0, height = 70, radius = 120 },
		{ x = -568, z = 0, height = 60, radius = 90 },
		{ x = 284, z = -284, height = 64, radius = 100 },
	}) :: { Flock },
	Birds = 7,
	BirdSize = table.freeze({ 2.4, 0.15, 0.8 }), -- wing span, thickness, body length
	BirdColour = { 52, 52, 60 } :: RGB,
	BirdGap = 3.2, -- between birds in the V
	FlockLap = 40, -- seconds for one lap
	Flap = table.freeze({ Degrees = 22, Period = 0.45 }),
	Bob = 1.5, -- the flock rises and falls this much over a lap
	Stagger = 0.6, -- birds in the V sit up to this much above or below each other

	-- rooftop vents (the server puts a vent box on every `VentEvery`th office's roof, at its back corner) and
	-- their steam
	VentEvery = 2,
	VentSize = table.freeze({ 3, 2.4, 3 }),
	VentInset = 6, -- from the roof's back and side edges
	VentColour = { 150, 152, 156 } :: RGB,
	Steam = table.freeze({
		Rate = 6,
		Speed = table.freeze({ 3, 5 }),
		Lifetime = table.freeze({ 3, 4.5 }),
		Size = table.freeze({ 2, 7 }),
		Transparency = table.freeze({ 0.45, 1 }),
		Colour = { 245, 245, 248 } :: RGB,
		Drift = table.freeze({ 1.5, 0.6, 0.8 }), -- a light wind
		Spread = 12,
		Spin = 20, -- degrees per second either way
	}),
})
