--!strict
-- Vehicle finishing detail checks (Config/CarDetail, Rules/CarDetail), called from tests/run.

local Config = require("../src/shared/Config/CarDetail")
local Rules = require("../src/shared/Rules/CarDetail")

return function(check: (string, boolean) -> ())
	local kinds = Config.Kinds
	check("car detail: a stock piece is its kind", Rules.kind("Lamp", kinds) == "Lamp")
	check("car detail: a zone piece is its kind", Rules.kind("Z12_Plate", kinds) == "Plate")
	check("car detail: the body is not detail", Rules.kind("Body", kinds) == nil)
	check("car detail: zone paint is not detail", Rules.kind("Z2_Paint", kinds) == nil)
	check("car detail: a rebuilt zone is not detail", Rules.kind("U2_Lamp", kinds) == nil)
	check("car detail: glass is not detail", Rules.kind("Glass", kinds) == nil)
	for _, kind in kinds do
		local look = Config.Look[kind]
		check(`car detail: {kind} has a look`, look ~= nil)
		if look and look.rgb then
			local ok = #look.rgb == 3
			for _, c in look.rgb do
				ok = ok and c >= 0 and c <= 255 and c % 1 == 0
			end
			check(`car detail: {kind} colour is 0-255`, ok)
		end
	end
	for _, kind in Config.Parked do
		check(`car detail: parked {kind} is a detail kind`, table.find(kinds, kind) ~= nil)
	end
	-- lit lenses glow: the tail red stays deep so bloom doesn't turn it pink
	local tail = Config.Look.Tail.rgb :: { number }
	check("car detail: tail red is deep", tail[1] <= 180 and tail[2] <= 40 and tail[3] <= 40)
end
