--!strict
-- The street kit and the districts: road paint, street furniture, props you can knock flying, and each
-- district's colours and materials. Studs and seconds; colours are { r, g, b }, materials are
-- Enum.Material names (Lune checks them).

export type RGB = { number }
export type District = {
	name: string,
	walls: { RGB },
	wallMaterial: string,
	sidewalk: RGB,
	sidewalkMaterial: string,
	accent: RGB, -- awnings, lamp heads, billboards
	signals: boolean, -- traffic lights at its crossings
	trees: number, -- chance of planter trees along a block side
}

return table.freeze({
	-- road paint
	PaintHeight = 0.135, -- centre of the paint, just above both road surfaces
	PaintThick = 0.04,
	LineWidth = 0.45,
	DashLength = 12,
	DashGap = 18,
	ZebraStripes = 5, -- across one road
	ZebraLength = 9,
	ZebraInset = 7, -- from the block edge: where the sidewalk crossing runs
	StopLineInset = 15,
	EndClear = 18, -- lines stop this short of a crossing

	-- furniture
	LampHeight = 16,
	KerbInset = 1.5, -- lamps, lights and hydrants stand this far in from the kerb
	BenchInset = 12.5, -- benches and shelters sit on the inner side of the sidewalk
	ParkedPerBlock = 2,
	ParkedOffset = 4.5, -- parked cars: this far out into the road from the kerb
	ShelterChance = 0.35, -- busy blocks get a bus shelter (a waiting crowd gathers there)
	SignalSeconds = 9, -- traffic lights: green this long each way
	AmberSeconds = 2,
	PropRebuildSeconds = 45, -- knocked props stand back up after this
	HydrantSpraySeconds = 5,
	CarColours = table.freeze({
		{ 200, 40, 40 },
		{ 40, 80, 160 },
		{ 235, 235, 235 },
		{ 30, 30, 34 },
		{ 120, 120, 128 },
		{ 230, 180, 40 },
		{ 60, 130, 80 },
	}) :: { RGB },
	Billboards = table.freeze({
		"SNAKKO CHIPS",
		"DRINK FIZZLE",
		"SPEED BUMPS R US",
		"CLEAN SOCKS DAILY",
		"TRY THE BARN BURGER",
		"HONK IF YOU'RE HAPPY",
		"MEGACORP IS HIRING",
	}),

	Districts = table.freeze({
		neon = table.freeze({
			name = "Neon Core",
			walls = {
				{ 70, 80, 110 },
				{ 44, 50, 74 },
				{ 150, 170, 200 },
				{ 220, 225, 235 },
				{ 96, 104, 140 },
			},
			wallMaterial = "SmoothPlastic",
			sidewalk = { 150, 152, 162 },
			sidewalkMaterial = "Concrete",
			accent = { 120, 220, 255 },
			signals = true,
			trees = 0.5,
		}) :: District,
		old = table.freeze({
			name = "Old Town",
			walls = {
				{ 170, 82, 60 },
				{ 190, 112, 82 },
				{ 140, 62, 48 },
				{ 225, 205, 170 },
				{ 160, 122, 92 },
			},
			wallMaterial = "Brick",
			sidewalk = { 150, 132, 116 },
			sidewalkMaterial = "Cobblestone",
			accent = { 232, 172, 60 },
			signals = true,
			trees = 0.3,
		}) :: District,
		maple = table.freeze({
			name = "Maple Hills",
			walls = {
				{ 240, 230, 210 },
				{ 200, 225, 200 },
				{ 210, 225, 240 },
				{ 245, 215, 200 },
				{ 250, 245, 235 },
			},
			wallMaterial = "WoodPlanks",
			sidewalk = { 192, 188, 178 },
			sidewalkMaterial = "Concrete",
			accent = { 220, 92, 70 },
			signals = false,
			trees = 0.85,
		}) :: District,
		dock = table.freeze({
			name = "Dockside",
			walls = { { 120, 126, 134 }, { 90, 100, 110 }, { 160, 150, 130 }, { 70, 90, 110 } },
			wallMaterial = "CorrodedMetal",
			sidewalk = { 140, 140, 142 },
			sidewalkMaterial = "Concrete",
			accent = { 255, 140, 20 },
			signals = false,
			trees = 0,
		}) :: District,
		canal = table.freeze({
			name = "Canal Quarter",
			walls = { { 130, 62, 46 }, { 102, 52, 42 }, { 182, 162, 142 }, { 62, 72, 82 } },
			wallMaterial = "Brick",
			sidewalk = { 122, 96, 72 },
			sidewalkMaterial = "WoodPlanks",
			accent = { 60, 160, 200 },
			signals = true,
			trees = 0.5,
		}) :: District,
		stadium = table.freeze({
			name = "Stadium Row",
			walls = { { 200, 200, 205 }, { 220, 140, 40 }, { 40, 50, 76 } },
			wallMaterial = "Concrete",
			sidewalk = { 170, 170, 176 },
			sidewalkMaterial = "Concrete",
			accent = { 220, 140, 40 },
			signals = true,
			trees = 0.2,
		}) :: District,
	}),
})
