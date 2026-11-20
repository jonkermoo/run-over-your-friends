--!strict
-- VIP pass checks (Config/Economy, Rules/PassMoney, the VIP paint in Rules/Paints), called from tests/run.

local Economy = require("../src/shared/Config/Economy")
local PaintConfig = require("../src/shared/Config/Paints")

return function(check: (string, boolean) -> ())
	local PassMoney = require("../src/shared/Rules/PassMoney")
	local PaintRules = require("../src/shared/Rules/Paints")
	check("VIP pass has an id", (Economy.Passes :: any).VIP ~= nil)
	check("VIP cash bonus is a bonus", Economy.VipMoney > 1)
	check("no pass: hit cash x1", PassMoney.multiplier(false, false, Economy) == 1)
	check("VIP alone: x VipMoney", PassMoney.multiplier(false, true, Economy) == Economy.VipMoney)
	check(
		"2x Money and VIP multiply",
		PassMoney.multiplier(true, true, Economy) == Economy.DoubleMoney * Economy.VipMoney
	)

	local vipIds = {}
	for _, p in PaintConfig.List do
		if p.vip then
			table.insert(vipIds, p.id)
		end
	end
	check("there is a VIP paint", #vipIds > 0)
	local id = vipIds[1] or "VIP"
	local owned = { Sedan = true }
	check("VIP paint is shut without the pass", not PaintRules.isOpen({}, id))
	check("VIP paint opens with the pass", PaintRules.isOpen(PaintRules.withVip({}, true), id))
	check(
		"setting VIP paint needs the pass",
		PaintRules.setProblem(owned, {}, "Sedan", id) == "locked"
			and PaintRules.setProblem(owned, PaintRules.withVip({}, true), "Sedan", id) == nil
	)
	check("VIP paint can't be bought with cash", PaintRules.buyProblem(1e9, {}, id) == "vip")
	local bought = { Pink = true }
	check(
		"withVip leaves the bought set alone",
		PaintRules.withVip(bought, true) ~= bought and bought[id] == nil
	)
	check(
		"a saved VIP paint shows only with the pass",
		PaintRules.shown(id, false) == nil
			and PaintRules.shown(id, true) == id
			and PaintRules.shown("Red", false) == "Red"
	)
	local chosen = PaintRules.clean({ Sedan = id }, {})
	check("a saved VIP paint survives loading (the pass is checked after)", chosen.Sedan == id)
	check(
		"VIP paint has its own finish",
		PaintRules.material(id) ~= nil and PaintRules.material("Red") == nil
	)
	-- paint finishes are Enum.Material names (a typo would be skipped quietly in game)
	local materials = {
		Foil = true,
		Metal = true,
		SmoothPlastic = true,
		Plastic = true,
		Neon = true,
		Glass = true,
		CrackedLava = true,
		Ice = true,
	}
	local finishesOk = true
	for _, p in PaintConfig.List do
		if p.material and not materials[p.material] then
			finishesOk = false
		end
	end
	check("paint finishes are known materials", finishesOk)
end
