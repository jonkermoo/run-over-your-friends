--!strict
-- The Roadster free trial's rules (Config/Trial): who may start one, the driving clock, when the swap back
-- happens, and what counts as a converted trial. Pure, so Lune tests it (tests/trial).

local Trial = {}

export type Cfg = {
	Seconds: number,
	WarnSeconds: number,
	CooldownSeconds: number,
	LandWaitSeconds: number,
	ConvertSeconds: number,
}

export type Facts = {
	tutorialDone: boolean,
	ownsCar: boolean, -- owns the trial car (bought, or from its pass)
	lastAt: number, -- os.time the last trial started; 0 = never
	now: number, -- os.time
	active: boolean, -- a trial is already running this session
}

-- why a new trial can't start now, or nil when it can
function Trial.problem(f: Facts, cfg: Cfg): string?
	if f.ownsCar then
		return "Owned"
	end
	if not f.tutorialDone then
		return "Tutorial"
	end
	if f.active then
		return "Active"
	end
	if f.lastAt > 0 and f.now < Trial.nextAt(f.lastAt, cfg) then
		return "Cooldown"
	end
	return nil
end

-- os.time the next trial may start; 0 = any time
function Trial.nextAt(lastAt: number, cfg: Cfg): number
	if lastAt <= 0 then
		return 0
	end
	return lastAt + cfg.CooldownSeconds
end

-- the clock after dt seconds: it only runs while the player sits in the trial car's driver seat
function Trial.tick(left: number, dt: number, inSeat: boolean): number
	if not inSeat or dt <= 0 or dt ~= dt then
		return left
	end
	return math.max(0, left - dt)
end

-- the countdown chip's whole seconds (rounded up, so it shows 0 only at the end)
function Trial.shown(left: number): number
	return math.max(0, math.ceil(left - 1e-6))
end

-- did the clock just pass the warning mark?
function Trial.warnNow(before: number, after: number, cfg: Cfg): boolean
	return before > cfg.WarnSeconds and after <= cfg.WarnSeconds and after > 0
end

-- time's up: swap back now? Only once the car is on the ground, or after LandWaitSeconds at zero, or at once
-- when the player isn't in the trial car at all
function Trial.swapNow(
	left: number,
	inCar: boolean,
	grounded: boolean,
	waited: number,
	cfg: Cfg
): boolean
	if left > 0 then
		return false
	end
	return not inCar or grounded or waited >= cfg.LandWaitSeconds
end

-- bought the car (or its pass) at `now`: does it count for a trial started at trialAt?
function Trial.converted(trialAt: number, now: number, cfg: Cfg): boolean
	if trialAt <= 0 then
		return false
	end
	local since = now - trialAt
	return since >= 0 and since <= cfg.ConvertSeconds
end

-- the end card's bar: cash toward the car's price, 0-1
function Trial.progress(cash: number, price: number): number
	if price <= 0 then
		return 1
	end
	return math.clamp(cash / price, 0, 1)
end

return Trial
