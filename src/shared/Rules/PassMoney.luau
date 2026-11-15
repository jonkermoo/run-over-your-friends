--!strict
-- The money passes' multiplier on hit cash: 2x Money and VIP multiply (Config/Economy DoubleMoney, VipMoney).
-- Pure, so Lune tests it.

local PassMoney = {}

function PassMoney.multiplier(
	double: boolean,
	vip: boolean,
	economy: { DoubleMoney: number, VipMoney: number }
): number
	return (if double then economy.DoubleMoney else 1) * (if vip then economy.VipMoney else 1)
end

return PassMoney
