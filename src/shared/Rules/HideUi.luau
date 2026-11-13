--!strict
-- What the UI ON/OFF button hides, and what each screen goes back to when it comes back (Config/HideUi).
-- Pure, so Lune tests it.
--
-- While the UI is off, game code keeps switching its screens on and off as usual (a pointer that comes and
-- goes, a name tag fading out). Each hidden screen keeps an Entry: `was` is what the game last asked for,
-- so turning the UI back on shows exactly that, and `echo` marks our own switch-off, so the change event it
-- causes isn't taken for the game's.

local HideUi = {}

export type Config = { Keep: { string } }
export type Entry = { was: boolean, echo: boolean }

-- a screen (ScreenGui) or world label (BillboardGui) the button hides; SurfaceGuis are scenery (shop signs,
-- leaderboards) and stay
function HideUi.hides(className: string, name: string, cfg: Config): boolean
	if className ~= "ScreenGui" and className ~= "BillboardGui" then
		return false
	end
	return table.find(cfg.Keep, name) == nil
end

-- start hiding a screen that is `enabled` now; true when it has to be switched off
function HideUi.hide(enabled: boolean): (Entry, boolean)
	return { was = enabled, echo = enabled }, enabled
end

-- the screen's Enabled changed while hidden; true when it has to be switched off again
function HideUi.changed(e: Entry, enabled: boolean): boolean
	if enabled then
		e.was = true -- the game showed it: remember, keep it off
		e.echo = true
		return true
	end
	if e.echo then
		e.echo = false -- our own switch-off
	else
		e.was = false -- the game hid it
	end
	return false
end

-- what the screen goes back to when the UI comes back
function HideUi.restore(e: Entry): boolean
	return e.was
end

return HideUi
