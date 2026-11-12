--!strict
-- One queue for the centre-screen cards nobody asked for (daily streak, Starter Pack): the front one opens
-- once the player has stopped and no menu is open, the next waits a while after it is answered, and a card
-- still up when the car gets going goes away and comes back at the next stop (Config/Popups). Cards the
-- player opens themselves, and the tutorial's, don't come through here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Popups)
local Rules = require(ReplicatedStorage.Shared.Rules.Popups)
local Drive = require(script.Parent.Drive)
local Style = require(script.Parent.Style)

local Popups = {}

type Entry = {
	id: string,
	order: number,
	show: () -> (),
	hide: () -> (),
	isOpen: () -> boolean,
	open: boolean,
}

local TICK = 0.2

local queue: { Entry } = {}
local busyChecks: { () -> boolean } = {}
local stillSince: number? = nil
local closedAt: number? = nil

-- ask for a card; a lower order goes first. Asking again for one already waiting does nothing.
function Popups.want(
	id: string,
	order: number,
	show: () -> (),
	hide: () -> (),
	isOpen: () -> boolean
)
	for _, e in queue do
		if e.id == id then
			return
		end
	end
	table.insert(
		queue,
		{ id = id, order = order, show = show, hide = hide, isOpen = isOpen, open = false }
	)
	-- a card already on screen stays at the front
	table.sort(queue, function(a, b)
		if a.open ~= b.open then
			return a.open
		end
		return a.order < b.order
	end)
end

-- the card isn't needed any more (collected elsewhere): takes it off the screen if it's up
function Popups.drop(id: string)
	for i, e in queue do
		if e.id == id then
			table.remove(queue, i)
			if e.open then
				e.hide()
			end
			return
		end
	end
end

-- something else is on screen that a card shouldn't open over (the garage, the store...)
function Popups.addBusy(check: () -> boolean)
	table.insert(busyChecks, check)
end

local function isBusy(): boolean
	for _, check in busyChecks do
		if check() then
			return true
		end
	end
	return false
end

local function tick()
	local now = os.clock()
	local s = Drive.state
	if Rules.isStill(s.driving, s.speedMph, s.throttle, Cfg) then
		stillSince = stillSince or now
	else
		stillSince = nil
	end
	local head = queue[1]
	if not head then
		return
	end
	if head.open then
		if not head.isOpen() then
			table.remove(queue, 1)
			closedAt = now
		elseif Rules.isMoving(s.driving, s.speedMph, Cfg) or Style.sheetOpen() then
			-- driving off, or the player opened the garage, store or goals: it comes back at the next stop
			head.open = false
			head.hide()
		end
	elseif Rules.mayOpen(now, stillSince, closedAt, Cfg) and not isBusy() then
		head.open = true
		head.show()
	end
end

function Popups.start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			tick()
		end
	end)
end

return Popups
