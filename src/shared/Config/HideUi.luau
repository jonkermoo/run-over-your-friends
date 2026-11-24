--!strict
-- SHOW UI in the Settings panel (client/HideUi, client/Settings, Rules/HideUi): it hides every screen and
-- world label of ours, and Roblox's chat, player list and backpack, so the screen shows only the game.
-- GUI pixels at desktop size (Style.fit scales them).

return table.freeze({
	Key = "U", -- a KeyCode name that also toggles it (free: see Config/DriveHud, Cockpit and client/Drive)
	-- ScreenGuis and BillboardGuis (by name) that stay up while the UI is off: the SETTINGS tile and panel,
	-- the phone driving buttons, and Roblox's own touch stick and jump button
	Keep = table.freeze({ "Settings", "HudTouch", "TouchGui" }),
	-- Roblox's own screens hidden with ours (Enum.CoreGuiType names)
	Core = table.freeze({ "Chat", "PlayerList", "Backpack", "EmotesMenu" }),
})
