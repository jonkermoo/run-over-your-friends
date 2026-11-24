--!strict
-- Where the city's people may be (Rules/Spread, Config/CrowdSpread), called from tests/run.

local SpreadConfig = require("../src/shared/Config/CrowdSpread")

return function(check: (string, boolean) -> ())
	local Spread = require("../src/shared/Rules/Spread")

	check(
		"spread: shops, parks and wandering are outings",
		Spread.isOuting("shop") and Spread.isOuting("wander")
	)
	check(
		"spread: going home is not an outing",
		not Spread.isOuting("home") and not Spread.isOuting("stay")
	)
	check(
		"spread: off the sidewalks an outing is staying in",
		Spread.goal("park", false, false) == "stay"
	)
	check(
		"spread: on the sidewalks an outing stays an outing",
		Spread.goal("park", true, false) == "park"
	)
	check("spread: going home is never changed", Spread.goal("home", false, false) == "home")
	check(
		"spread: off-network outings can be switched on",
		Spread.goal("shop", false, true) == "shop"
	)
	check(
		"spread: cells",
		Spread.cell(-1, 499, 500) == "-1,0" and Spread.cell(500, -501, 500) == "1,-2"
	)

	-- one crowded cell (home 1 with 3, home 2 with 2, home 3 with 1) and a quiet one
	local list: { Spread.Resident } = {
		{ cell = "a", home = 1 },
		{ cell = "a", home = 1 },
		{ cell = "a", home = 1 },
		{ cell = "a", home = 2 },
		{ cell = "a", home = 2 },
		{ cell = "a", home = 3 },
		{ cell = "b", home = 4 },
	}
	local keep = Spread.thin(list, 3)
	local perHome: { [number]: number } = {}
	local inA = 0
	for k, r in list do
		if keep[k] then
			perHome[r.home] = (perHome[r.home] or 0) + 1
			if r.cell == "a" then
				inA += 1
			end
		end
	end
	check("spread: a crowded cell keeps the cap", inA == 3)
	check(
		"spread: the fullest homes give up people first",
		perHome[1] == 1 and perHome[2] == 1 and perHome[3] == 1
	)
	check("spread: a quiet cell keeps everyone", perHome[4] == 1)
	local none = Spread.thin(list, 0)
	local any = false
	for _, v in none do
		any = any or v
	end
	check("spread: a cap of 0 keeps nobody", not any)

	check(
		"spread: config numbers are sane",
		SpreadConfig.OutingRange > 0
			and SpreadConfig.AreaCell > 0
			and SpreadConfig.AreaMaxResidents >= 1
	)
end
