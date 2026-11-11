--!strict
-- Pure choices for the driving HUD (numbers in Config/DriveHud): which key rows the controls card lists for a
-- car, and whether the card starts open.

local DriveHud = {}

export type Row = { key: string, label: string }

export type Car = {
	feature: string?, -- "TAXI!", "JINGLE", "WATER" or nil
	jingleOn: boolean?,
	jet: boolean?, -- Roadster flight
	thruster: boolean?,
	unstuckWait: number?, -- whole seconds until T works again
}

type Config = { OpenDrives: number, OpenDrivesReturning: number }

-- the rows, in the order they show
function DriveHud.rows(car: Car): { Row }
	local wait = car.unstuckWait or 0
	local rows: { Row } = {
		{ key = "WASD", label = "Drive" },
		{ key = "SPACE", label = "Get out" },
		{ key = "V", label = "View" },
		{ key = "H", label = "Horn" },
		{ key = "T", label = if wait > 0 then `Unstuck ({wait})` else "Unstuck" },
	}
	if car.feature == "JINGLE" then
		table.insert(
			rows,
			{ key = "G", label = if car.jingleOn then "Jingle off" else "Jingle on" }
		)
	elseif car.feature == "WATER" then
		table.insert(rows, { key = "G", label = "Water (aim with mouse)" })
	elseif car.feature then
		table.insert(rows, {
			key = "G",
			label = string.upper(string.sub(car.feature, 1, 1))
				.. string.lower(string.sub(car.feature, 2)),
		})
	end
	if car.jet then
		table.insert(rows, { key = "SHIFT", label = "Jet up (hold)" })
		table.insert(rows, { key = "Q/E", label = "Roll (hold)" })
		table.insert(rows, { key = "S", label = "Reverse jet" })
		table.insert(rows, { key = "R", label = "Rear jet (hold)" })
	elseif car.thruster then
		table.insert(rows, { key = "R", label = "Thruster" })
	end
	return rows
end

-- is the card open on this drive (1 = the first drive since joining)?
function DriveHud.startsOpen(drive: number, returning: boolean, cfg: Config): boolean
	return drive <= (if returning then cfg.OpenDrivesReturning else cfg.OpenDrives)
end

return DriveHud
