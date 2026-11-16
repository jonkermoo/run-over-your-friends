--!strict
-- The day/night cycle. Night is a mood, never darkness: the shade is lifted and the exposure raised so players,
-- people, cars and roads read as well as by day; the sky turns navy with stars and a big moon, windows and lamps
-- glow. The server only fixes when the cycle started (Lighting attributes); each client works out the same time
-- from the shared server clock and sets its own Lighting. Seconds, studs, colours { r, g, b }.
local World = if typeof(script) == "Instance"
	then require(script.Parent.World)
	else require("./World")

local L = World.Look

export type Look = {
	Brightness: number,
	Exposure: number,
	Ambient: { number },
	OutdoorAmbient: { number },
	SunTint: { number }, -- the sun's (or moon's) colour on lit faces
	AirDensity: number,
	AirHaze: number,
	AirGlare: number,
	AirColor: { number },
	AirDecay: { number },
	Tint: { number },
	Saturation: number,
	BloomIntensity: number,
	BloomThreshold: number,
	SunRays: number,
	CloudColor: { number },
	Stars: number, -- Sky.StarCount
	Glow: number, -- 0..1: how many of the lit windows are on, and the headlights
}

-- the day is the approved "golden afternoon" look (Config/World Look), unchanged
local Day: Look = table.freeze({
	Brightness = L.Brightness,
	Exposure = L.Exposure,
	Ambient = L.Ambient,
	OutdoorAmbient = L.OutdoorAmbient,
	SunTint = L.SunTint,
	AirDensity = L.AirDensity,
	AirHaze = L.AirHaze,
	AirGlare = L.AirGlare,
	AirColor = L.AirColor,
	AirDecay = L.AirDecay,
	Tint = L.Tint,
	Saturation = L.Saturation,
	BloomIntensity = L.BloomIntensity,
	BloomThreshold = L.BloomThreshold,
	SunRays = L.SunRays,
	CloudColor = L.CloudColor,
	Stars = 0,
	Glow = 0,
})

return table.freeze({
	Cycle = 1200, -- one full day: 13 min day, 1.5 sunset, ~4 night, 1.5 sunrise
	StartAt = 120, -- a new server opens here: early morning with the whole day ahead
	MoonSize = 14, -- Sky.MoonAngularSize, degrees: big and cartoony
	Looks = table.freeze({
		Day = Day,
		-- the late afternoon going gold, the first windows coming on
		Golden = table.freeze({
			Brightness = 2.9,
			Exposure = 0.25,
			Ambient = { 150, 140, 150 },
			OutdoorAmbient = { 170, 155, 180 },
			SunTint = { 255, 200, 150 },
			AirDensity = 0.2,
			AirHaze = 0.6,
			AirGlare = 0.4,
			AirColor = { 250, 215, 190 },
			AirDecay = { 200, 140, 170 },
			Tint = { 255, 244, 232 },
			Saturation = 0.28,
			BloomIntensity = 0.4,
			BloomThreshold = 1.5,
			SunRays = 0.08,
			CloudColor = { 255, 236, 220 },
			Stars = 0,
			Glow = 0.2,
		}),
		-- sunset: pink-purple haze (orange over the darkening sky read olive). Between sun and moon nothing
		-- lights the ground, so the shade and exposure peak here, above night
		Dusk = table.freeze({
			Brightness = 2.4,
			Exposure = 0.7,
			Ambient = { 175, 155, 180 },
			OutdoorAmbient = { 210, 185, 220 },
			SunTint = { 255, 165, 120 },
			AirDensity = 0.2,
			AirHaze = 0.7,
			AirGlare = 0.3,
			AirColor = { 215, 150, 200 },
			AirDecay = { 150, 100, 190 },
			Tint = { 255, 240, 240 },
			Saturation = 0.3,
			BloomIntensity = 0.5,
			BloomThreshold = 1.4,
			SunRays = 0.04,
			CloudColor = { 235, 185, 220 },
			Stars = 800,
			Glow = 0.7,
		}),
		-- night (stills user-approved 2026-11-15): navy sky, stars, a cool moon, the shade raised to near day
		Night = table.freeze({
			Brightness = 2,
			Exposure = 0.4,
			Ambient = { 140, 135, 175 },
			OutdoorAmbient = { 160, 155, 215 },
			SunTint = { 190, 205, 255 },
			AirDensity = 0.2,
			AirHaze = 0.6,
			AirGlare = 0,
			AirColor = { 95, 85, 170 },
			AirDecay = { 120, 80, 170 },
			Tint = { 235, 235, 255 },
			Saturation = 0.3,
			BloomIntensity = 0.5,
			BloomThreshold = 1.4,
			SunRays = 0,
			CloudColor = { 150, 150, 200 },
			Stars = 3000,
			Glow = 1,
		}),
		-- sunrise: soft peach, windows going off
		Dawn = table.freeze({
			Brightness = 2.4,
			Exposure = 0.6,
			Ambient = { 165, 155, 180 },
			OutdoorAmbient = { 205, 190, 220 },
			SunTint = { 255, 200, 170 },
			AirDensity = 0.2,
			AirHaze = 0.6,
			AirGlare = 0.3,
			AirColor = { 230, 185, 210 },
			AirDecay = { 170, 140, 200 },
			Tint = { 255, 244, 240 },
			Saturation = 0.28,
			BloomIntensity = 0.45,
			BloomThreshold = 1.4,
			SunRays = 0.05,
			CloudColor = { 255, 225, 220 },
			Stars = 300,
			Glow = 0.4,
		}),
	}),
	-- the cycle as stops: `at` seconds into it, the clock (hours, rising; past 24 wraps), and the look there.
	-- Between stops everything eases; the last stop runs on into the first (at + Cycle, clock + 24).
	Stops = table.freeze({
		table.freeze({ at = 0, clock = 6.8, look = "Dawn" }),
		table.freeze({ at = 90, clock = 8.5, look = "Day" }),
		table.freeze({ at = 690, clock = 16.4, look = "Day" }),
		table.freeze({ at = 780, clock = 17.4, look = "Golden" }),
		table.freeze({ at = 870, clock = 18.5, look = "Dusk" }),
		table.freeze({ at = 930, clock = 19.5, look = "Night" }),
		table.freeze({ at = 1110, clock = 28.8, look = "Night" }),
		table.freeze({ at = 1170, clock = 29.9, look = "Dawn" }),
	}),
	-- office and shop windows (Glass parts in the town's buildings) light up warm at night; each pane has its
	-- own switch-on point so they come on one by one through the dusk. Only parts already streamed in change.
	Windows = table.freeze({
		Share = 0.4, -- of panes that ever light
		FirstAt = 0.15, -- Glow at which the first pane comes on
		LastAt = 0.85, -- and the last
		Transparency = 0.25,
		Colors = table.freeze({
			table.freeze({ 220, 180, 120 }),
			table.freeze({ 220, 160, 100 }),
			table.freeze({ 225, 200, 150 }),
		}),
		Batch = 1500, -- panes looked at per frame when first sorting them
		Every = 0.5, -- seconds between window passes
	}),
	-- the only real light added: your own car's headlights
	Headlights = table.freeze({
		From = 0.35, -- on when Glow reaches this
		Range = 60,
		Angle = 55,
		Brightness = 6,
		Tilt = 8, -- degrees down, so the pool lands on the road ahead
		Color = { 255, 240, 210 },
		Up = 0.5, -- studs above the chassis middle, before VehicleScale
	}),
})
