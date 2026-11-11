--!strict
-- The driving HUD (src/client/Hud, Rules/DriveHud): the speedometer, the controls card in the bottom right
-- (keyboard players), the hint chip over the speedometer, and the phone driving buttons. GUI pixels at
-- desktop size (Style.fit scales them).

return table.freeze({
	-- the controls card is open for this many drives each time you join, then it folds into a KEYS chip...
	OpenDrives = 3,
	-- ...and for this many when you had already finished the tutorial before joining
	OpenDrivesReturning = 1,
	ToggleKey = "K", -- opens and folds the card (a KeyCode name)

	Margin = 20, -- the card's gap from the right and bottom edges
	RowHeight = 26,
	RowGap = 6,
	CardPad = 12,
	TitleHeight = 24,
})
