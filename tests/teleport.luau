--!strict
-- Teleport checks (Config/Teleport, Rules/Teleport), called from tests/run.

local Cfg = require("../src/shared/Config/Teleport")
local Country = require("../src/shared/Config/Country")
local Net = require("../src/shared/Net")
local Rules = require("../src/shared/Rules/Teleport")
local Suburbs = require("../src/shared/Config/Suburbs")
local World = require("../src/shared/Config/World")

return function(check: (string, boolean) -> ())
	check("teleport: remote named in Net", Net.Messages.Teleport ~= nil)
	check("teleport: a cooldown", Cfg.Cooldown > 0)

	local areas = Rules.areas(Cfg.Places, World.Map, Suburbs.Hoods, Country.Moto.Rect)
	check("teleport: every Config place resolves to an area", #areas == #Cfg.Places)
	do
		local keys, ok = {}, true
		for _, a in areas do
			ok = ok and not keys[a.key] and a.radius > 0 and (a.roads or a.count >= 2)
			keys[a.key] = true
		end
		check("teleport: area keys unique, each with room for several spots", ok)
	end

	-- the plaza is the city grid's middle block (MapBuilder): with 8 x 8 blocks of 220 and roads of 64 that's 142
	do
		local x, z = Rules.plaza({ BlockSize = 220, RoadWidth = 64, BlocksX = 8, BlocksZ = 8 })
		check("teleport: spawn plaza middle", x == 142 and z == 142)
	end
	do
		local x, z = Rules.hoodMiddle({
			name = "T",
			dir = { 1, 0 },
			offset = -800,
			start = 2900,
			length = 1600,
		})
		local x2, z2 = Rules.hoodMiddle({
			name = "T",
			dir = { 0, -1 },
			offset = 600,
			start = 2500,
			length = 1000,
		})
		check(
			"teleport: suburb middle along its spine",
			x == 3700 and z == -800 and x2 == 600 and z2 == -3000
		)
	end

	-- landing spots: road points near the middle, apart from each other
	do
		local area = { key = "A", name = "A", x = 0, z = 0, roads = true, radius = 200, count = 0 }
		local roads = {}
		for x = -300, 300, 20 do
			table.insert(roads, { x = x, z = 0 })
		end
		local s = Rules.spots(area, roads, 60, 5)
		local apart = true
		for i = 1, #s do
			for j = i + 1, #s do
				apart = apart and math.abs(s[i].x - s[j].x) >= 60
			end
			apart = apart and math.abs(s[i].x) <= 200
		end
		check(
			"teleport: road spots inside the radius, kept apart, capped",
			#s == 5 and apart and s[1].x == 0
		)
		local ring = Rules.spots(
			{ key = "B", name = "B", x = 10, z = 10, roads = false, radius = 50, count = 4 },
			{},
			60,
			5
		)
		check(
			"teleport: circle spots",
			#ring == 4 and math.abs(ring[1].x - 60) < 1e-6 and math.abs(ring[1].z - 10) < 1e-6
		)
	end

	-- two players teleporting together land apart: the second sees the first as busy
	do
		local s = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 200, z = 0 } }
		local first = Rules.order(s, {}, 30, 1)[1]
		local second = Rules.order(s, { s[first] }, 30, 1)[1]
		check("teleport: second player gets another spot", first == 1 and second ~= first)
		local o =
			Rules.order(s, { { x = 0, z = 0 }, { x = 100, z = 5 }, { x = 210, z = 0 } }, 30, 1)
		check("teleport: all taken -> emptiest first, every spot listed", #o == 3 and o[1] == 3)
		local wrapped = Rules.order(s, {}, 30, 3)
		check(
			"teleport: random start wraps",
			wrapped[1] == 3 and wrapped[2] == 1 and wrapped[3] == 2
		)
	end

	-- refusals
	do
		local base = {
			known = true,
			alive = true,
			passenger = false,
			now = 100,
			readyAt = 50,
			nearEvent = false,
		}
		local function with(k: string, v: any): string?
			local a = table.clone(base) :: any
			a[k] = v
			return Rules.refusal(a)
		end
		check("teleport: allowed when all clear", Rules.refusal(base) == nil)
		check("teleport: unknown area", with("known", false) == "Unknown")
		check("teleport: dead", with("alive", false) == "Dead")
		check("teleport: riding in someone else's car", with("passenger", true) == "Passenger")
		check("teleport: cooldown", with("readyAt", 130) == "Cooldown")
		check("teleport: by the live event", with("nearEvent", true) == "Event")
		local a = areas[1]
		check(
			"teleport: event keep-away",
			Rules.nearEvent(a, a.x + 10, a.z, Cfg.EventKeepAway)
				and not Rules.nearEvent(a, a.x + Cfg.EventKeepAway + 1, a.z, Cfg.EventKeepAway)
				and not Rules.nearEvent(a, nil, nil, Cfg.EventKeepAway)
		)
		check(
			"teleport: seconds left",
			Rules.secondsLeft(10, 12.2) == 3 and Rules.secondsLeft(10, 5) == 0
		)
	end
end
