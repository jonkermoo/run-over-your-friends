--!strict
-- Pure choices for the driving HUD (numbers in Config/DriveHud): which key rows the controls card lists for a
-- car (keyboard, or gamepad buttons on console), and whether the card starts open.

local DriveHud = {}

-- label is English; wait: the unstuck countdown in it (its translated line is UnstuckWait, src/shared/Loc)
export type Row = { key: string, label: string, wait: number? }

export type Car = {
	feature: string?, -- "TAXI!", "JINGLE", "WATER" or nil
	jingleOn: boolean?,
	jet: boolean?, -- Roadster flight
	thruster: boolean?,
	unstuckWait: number?, -- whole seconds until T works again
}

-- a gamepad row: KeyCode names whose button pictures show side by side, then the label
export type PadRow = { keys: { string }, label: string, wait: number? }

export type PadCar = Car & {
	view: string, -- the KeyCode name that toggles the view (Config/Cockpit pads)
	tutorial: boolean?, -- the tutorial is running, so its SKIP takes D-pad down
}

type Config = { OpenDrives: number, OpenDrivesReturning: number }

-- the car features the G row names, by Config/Vehicles feature
DriveHud.Features = table.freeze({ Taxi = "TAXI!", Jingle = "JINGLE", Cannon = "WATER" })

-- the G row's label for a feature (nil: the car has none); water: how the fire truck aims
local function featureLabel(car: Car, water: string): string?
	if car.feature == "JINGLE" then
		return if car.jingleOn then "Jingle off" else "Jingle on"
	elseif car.feature == "WATER" then
		return water
	elseif car.feature then
		return string.upper(string.sub(car.feature, 1, 1))
			.. string.lower(string.sub(car.feature, 2))
	end
	return nil
end

-- the rows, in the order they show
function DriveHud.rows(car: Car): { Row }
	local wait = car.unstuckWait or 0
	local rows: { Row } = {
		{ key = "WASD", label = "Drive" },
		{ key = "SPACE", label = "Get out" },
		{ key = "V", label = "View" },
		{ key = "H", label = "Horn" },
		{
			key = "T",
			label = if wait > 0 then `Unstuck ({wait})` else "Unstuck",
			wait = if wait > 0 then wait else nil,
		},
	}
	local feature = featureLabel(car, "Water (aim with mouse)")
	if feature then
		table.insert(rows, { key = "G", label = feature })
	end
	if car.jet then
		table.insert(rows, { key = "SHIFT", label = "Jet up (hold)" })
		table.insert(rows, { key = "Q/E", label = "Roll (hold)" })
		table.insert(rows, { key = "S", label = "Reverse jet" })
		table.insert(rows, { key = "R", label = "Rear jet (hold)" })
	elseif car.thruster then
		table.insert(rows, { key = "R", label = "Thruster" })
	end
	table.insert(rows, { key = "M", label = "Map" }) -- Config/CityMap Key
	return rows
end

-- the same card for a gamepad: the buttons Drive.bind and the vehicle seat use (RT/LT and the left stick
-- drive, A gets out), D-pad right for the menu tabs (Pad.strip), a left-stick click for the city map and D-pad
-- down for the tutorial's SKIP
function DriveHud.padRows(car: PadCar): { PadRow }
	local wait = car.unstuckWait or 0
	local rows: { PadRow } = {
		{ keys = { "ButtonR2", "ButtonL2" }, label = "Gas / reverse" },
		{ keys = { "Thumbstick1" }, label = "Steer" },
		{ keys = { "ButtonA" }, label = "Get out" },
		{ keys = { car.view }, label = "View" },
		{ keys = { "DPadUp" }, label = "Horn" },
		{
			keys = { "DPadLeft" },
			label = if wait > 0 then `Unstuck ({wait})` else "Unstuck",
			wait = if wait > 0 then wait else nil,
		},
	}
	local feature = featureLabel(car, "Water (aim with camera)")
	if feature then
		table.insert(rows, { keys = { "ButtonY" }, label = feature })
	end
	if car.jet then
		table.insert(rows, { keys = { "ButtonB" }, label = "Jet up (hold)" })
		table.insert(rows, { keys = { "ButtonL1", "ButtonR1" }, label = "Roll (hold)" })
		table.insert(rows, { keys = { "ButtonL2" }, label = "Reverse jet" })
		table.insert(rows, { keys = { "ButtonX" }, label = "Rear jet (hold)" })
	elseif car.thruster then
		table.insert(rows, { keys = { "ButtonX" }, label = "Thruster" })
	end
	table.insert(rows, { keys = { "DPadRight" }, label = "Menu" })
	table.insert(rows, { keys = { "ButtonL3" }, label = "Map" }) -- Config/CityMap PadKey
	if car.tutorial then
		table.insert(rows, { keys = { "DPadDown" }, label = "Skip step" })
	end
	return rows
end

-- is the card open on this drive (1 = the first drive since joining)?
function DriveHud.startsOpen(drive: number, returning: boolean, cfg: Config): boolean
	return drive <= (if returning then cfg.OpenDrivesReturning else cfg.OpenDrives)
end

return DriveHud
