--!strict
-- Paint rules: which colours a player may use, what one costs, the colour a vehicle shows, and cleaning saved
-- choices. Pure, so Lune tests it. `bought` is the set of paid colour ids; `chosen` maps vehicle id to colour id.

local Config = if typeof(script) == "Instance"
	then require(script.Parent.Parent.Config.Paints)
	else require("../Config/Paints")

local Paints = {}

function Paints.isOpen(bought: { [string]: boolean }, id: string): boolean
	local p = Config.ById[id]
	return p ~= nil and (p.price == 0 or bought[id] == true)
end

-- why a colour can't be bought, or nil when it can
function Paints.buyProblem(money: number, bought: { [string]: boolean }, id: any): string?
	local p = if typeof(id) == "string" then Config.ById[id] else nil
	if not p then
		return "unknown"
	elseif Paints.isOpen(bought, p.id) then
		return "owned"
	elseif money < p.price then
		return "money"
	end
	return nil
end

-- why a vehicle can't take a colour, or nil when it can
function Paints.setProblem(
	owned: { [string]: boolean },
	bought: { [string]: boolean },
	vehicleId: any,
	paintId: any
): string?
	if typeof(vehicleId) ~= "string" or typeof(paintId) ~= "string" then
		return "bad"
	elseif not Config.Factory[vehicleId] or not owned[vehicleId] then
		return "vehicle"
	elseif not Paints.isOpen(bought, paintId) then
		return "locked"
	end
	return nil
end

-- the 0-255 colour a vehicle shows with this choice (Factory, unknown or nil: its own colour)
function Paints.colour(vehicleId: string, paintId: string?): { number }?
	local p = if paintId then Config.ById[paintId] else nil
	return (p and p.rgb) or Config.Factory[vehicleId]
end

-- a saved profile's paint, keeping only known colours (paid ones still bought) on known vehicles; Factory is
-- the default, so it isn't stored
function Paints.clean(chosen: any, bought: any): ({ [string]: string }, { [string]: boolean })
	local outBought: { [string]: boolean } = {}
	if typeof(bought) == "table" then
		for id, yes in bought do
			local p = if typeof(id) == "string" then Config.ById[id] else nil
			if yes == true and p and p.price > 0 then
				outBought[id] = true
			end
		end
	end
	local outChosen: { [string]: string } = {}
	if typeof(chosen) == "table" then
		for vid, pid in chosen do
			if
				typeof(vid) == "string"
				and typeof(pid) == "string"
				and pid ~= Config.FactoryId
				and Config.Factory[vid]
				and Paints.isOpen(outBought, pid)
			then
				outChosen[vid] = pid
			end
		end
	end
	return outChosen, outBought
end

-- "Sedan=Red,Taxi=Pink" for a player attribute (the garage reads it), sorted so it only changes with the data
function Paints.encode(chosen: { [string]: string }): string
	local out = {}
	for vid, pid in chosen do
		table.insert(out, vid .. "=" .. pid)
	end
	table.sort(out)
	return table.concat(out, ",")
end

function Paints.decode(text: string): { [string]: string }
	local out = {}
	for _, pair in string.split(text, ",") do
		local vid, pid = string.match(pair, "^(%w+)=(%w+)$")
		if vid and pid then
			out[vid] = pid
		end
	end
	return out
end

return Paints
