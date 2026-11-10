--!strict
-- When centre-screen cards that nobody asked for (daily streak, Starter Pack) may open: never over a road
-- someone is driving down, and never one straight after another (Rules/Popups, src/client/Popups).

return table.freeze({
	StoppedMph = 3, -- at or under this, with no throttle held, a driver counts as stopped...
	StoppedSeconds = 1.5, -- ...once it has lasted this long
	MovingMph = 15, -- a card still open when the car gets up to this goes away and comes back at the next stop
	GapSeconds = 90, -- after one card is answered, the next waits this long
})
