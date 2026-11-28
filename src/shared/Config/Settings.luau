--!strict
-- The SETTINGS panel (client/Settings; its tile sits left of the cash box, sized by Config/Layout Column):
-- music, show UI and who can ride in my car (Config/Riders). GUI pixels at desktop size (Style.fit scales them).

return table.freeze({
	PanelWidth = 460,
	Pad = 16, -- inside the panel's edges
	Header = 62, -- the title strip
	RowHeight = 64, -- a toggle row
	RideRowHeight = 104, -- the ride row: words above, three choices below
	RowGap = 10,
	ChoiceWidth = 72, -- an ON / OFF button
	ChoiceHeight = 44,
	ChoiceGap = 6,
	PadKey = "ButtonSelect", -- the gamepad's View / Select button opens and closes it
	-- the words on the ride choices, in Config/Riders Modes order
	RideWords = table.freeze({ "EVERYONE", "FRIENDS", "NOBODY" }),
})
