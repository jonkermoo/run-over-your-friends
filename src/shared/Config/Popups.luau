--!strict
-- When centre-screen cards that nobody asked for (daily streak, Starter Pack) may open: never over a road
-- someone is driving down, and never one straight after another (Rules/Popups, src/client/Popups).

return table.freeze({
	StoppedMph = 3, -- at or under this, with no throttle held, a driver counts as stopped...
	StoppedSeconds = 1.5, -- ...once it has lasted this long
	MovingMph = 15, -- a card still open when the car gets up to this goes away and comes back at the next stop
	GapSeconds = 90, -- after one card is answered, the next waits this long
	ReturnSeconds = 300, -- a card closed with its X comes back after this long (unless it was answered meanwhile)
	-- the order: things to collect (daily streak, chests) before progress nudges (trial over, Starter Pack, today's
	-- challenges); soonest first in each
	Collect = 1,
	Nudge = 2,
	-- every card opens in one slot over the car: the screen between these layout px from the top (under the event
	-- sign) and from the bottom (over the speedometer); a card taller than that shrinks to fit
	SlotTop = 96,
	SlotBottom = 124,
})
