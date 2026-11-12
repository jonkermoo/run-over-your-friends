--!strict
-- Menu sounds, the contest fanfare and the background music (client/Sfx, client/Music). Only sounds licensed
-- for every Roblox game: Roblox's own, Pro Sound Effects and APM Music from the Creator Store.

return table.freeze({
	Click = table.freeze({ id = 15675059323, volume = 0.35 }), -- Roblox UI Bright Click: every button
	Whoosh = table.freeze({ id = 9126229267, volume = 0.25 }), -- Pro Sound Effects: a garage/store/goals sheet opens
	Till = table.freeze({ id = 9113728756, volume = 0.5 }), -- Pro Sound Effects: a new ride (same till as Fx Cash)
	Fanfare = table.freeze({ id = 9047100306, volume = 0.6 }), -- APM "Hustler Sting 2": the contest podium
	ClickGap = 0.05, -- seconds: a button that fires twice at once clicks once
	-- background music: upbeat funk from APM Music, shuffled; on by default at a low volume, the speaker
	-- button turns it off (saved per player)
	Music = table.freeze({
		Tracks = table.freeze({
			1839367225, -- Funk Addict
			1836773720, -- Basement Hipsters
			9038367768, -- Funky Disco Beats
		}),
		Volume = 0.22,
		DuckTo = 0.4, -- share of the volume while a big callout has the middle of the screen (Style.stage)
		Fade = 0.6, -- seconds to dip or come back
		Gap = 2, -- seconds of quiet between tracks
	}),
})
