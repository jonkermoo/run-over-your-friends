--!strict
-- Which finishing-detail piece a vehicle part is (Config/CarDetail), pure so Lune tests it.

local CarDetail = {}

-- "Lamp" for Lamp or Z2_Lamp, nil for anything else (Body, Paint, Z2_Paint, Glass ...)
function CarDetail.kind(name: string, kinds: { string }): string?
	local short = string.match(name, "^Z%d+_(.+)$") or name
	return if table.find(kinds, short) then short else nil
end

return CarDetail
