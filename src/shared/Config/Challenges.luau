--!strict
-- Daily and weekly challenges (Rules/Challenges, server/ChallengeService, client/Challenges): the same for
-- everyone on a UTC day or week, picked from the date. Each day has one challenge from each daily slot (a car, a
-- stunt, mayhem); each week has one weekly challenge. A finished challenge gives a chest of its set, opened from
-- the GOALS sheet: a Daily chest is cash or now and then a chest-only paint, a Weekly chest is a chest-only paint
-- and cash. Kept small on purpose: a daily challenge takes minutes, the weekly one under an hour over the week.
--
-- A template's text has {n} for the target and {car} for the day's car. kind is the game event it counts:
--   Hits (people run over), Breaks (building pieces), Jumps (clean landings), Spins (360s in landed jumps),
--   ParkJumps (landings in the stunt park), BestAir (seconds of air in one jump), Collapses (whole buildings
--   brought down), Combo (people in one combo), Launch (studs someone flew), Events (live events taken part in).
-- mode "add" counts up, "max" keeps the best single one. car = true: only counts in the day's car.

export type Template = {
	id: string,
	kind: string,
	mode: "add" | "max",
	text: string,
	min: number,
	max: number,
	step: number,
	car: boolean?,
	line: string?, -- the Lines.csv key of its text when it isn't Challenge_<id> (the same words as another line)
}

local function t(row: Template): Template
	return table.freeze(row)
end

return table.freeze({
	DaySeconds = 86400,
	WeekSeconds = 604800,
	-- unix time 0 was a Thursday: weeks start this many seconds later, Monday 00:00 UTC
	WeekOffset = 4 * 86400,
	DailySalt = 7349,
	WeeklySalt = 9161,
	-- the cars a daily car challenge may name: cheap ones, so a new player can do it the same day
	Cars = table.freeze({ "Hatchback", "Scooter", "Cart", "Sedan" }),
	Daily = table.freeze({
		-- one challenge from each slot, in this order
		Slots = table.freeze({
			table.freeze({
				t({
					id = "CarHits",
					kind = "Hits",
					mode = "add",
					text = "Flatten {n} people in the {car}",
					min = 25,
					max = 40,
					step = 5,
					car = true,
				}),
				t({
					id = "CarBreaks",
					kind = "Breaks",
					mode = "add",
					text = "Smash {n} building pieces in the {car}",
					min = 40,
					max = 80,
					step = 10,
					car = true,
				}),
				t({
					id = "CarJumps",
					kind = "Jumps",
					mode = "add",
					text = "Land {n} jumps in the {car}",
					min = 3,
					max = 6,
					step = 1,
					car = true,
				}),
			}),
			table.freeze({
				t({
					id = "Spin",
					kind = "Spins",
					mode = "add",
					text = "Land a 360",
					min = 1,
					max = 1,
					step = 1,
				}),
				t({
					id = "ParkJumps",
					kind = "ParkJumps",
					mode = "add",
					text = "Land {n} jumps in the stunt park",
					min = 3,
					max = 5,
					step = 1,
				}),
				t({
					id = "BigAir",
					kind = "BestAir",
					mode = "max",
					text = "Stay in the air {n} seconds in one jump",
					min = 2,
					max = 3,
					step = 1,
				}),
			}),
			table.freeze({
				t({
					id = "Collapse",
					kind = "Collapses",
					mode = "add",
					text = "Bring down {n} whole buildings",
					min = 2,
					max = 3,
					step = 1,
				}),
				t({
					id = "Combo",
					line = "Quest_Combo",
					kind = "Combo",
					mode = "max",
					text = "Hit {n} people in one combo",
					min = 5,
					max = 7,
					step = 1,
				}),
				t({
					id = "Launch",
					line = "Quest_Launch",
					kind = "Launch",
					mode = "max",
					text = "Launch someone {n} studs",
					min = 120,
					max = 180,
					step = 20,
				}),
				t({
					id = "Event",
					kind = "Events",
					mode = "add",
					text = "Join a live event",
					min = 1,
					max = 1,
					step = 1,
				}),
			}),
		}),
	}),
	Weekly = table.freeze({
		t({
			id = "WeekHits",
			kind = "Hits",
			mode = "add",
			text = "Flatten {n} people",
			min = 400,
			max = 600,
			step = 50,
		}),
		t({
			id = "WeekCollapses",
			line = "Challenge_Collapse",
			kind = "Collapses",
			mode = "add",
			text = "Bring down {n} whole buildings",
			min = 12,
			max = 20,
			step = 2,
		}),
		t({
			id = "WeekSpins",
			kind = "Spins",
			mode = "add",
			text = "Land {n} 360s",
			min = 8,
			max = 12,
			step = 1,
		}),
		t({
			id = "WeekEvents",
			kind = "Events",
			mode = "add",
			text = "Join {n} live events",
			min = 4,
			max = 6,
			step = 1,
		}),
		t({
			id = "WeekPark",
			line = "Challenge_ParkJumps",
			kind = "ParkJumps",
			mode = "add",
			text = "Land {n} jumps in the stunt park",
			min = 25,
			max = 40,
			step = 5,
		}),
	}),
	Chests = table.freeze({
		Daily = table.freeze({
			-- cash: one of these, by weight
			Cash = table.freeze({
				table.freeze({ amount = 500, weight = 40 }),
				table.freeze({ amount = 1000, weight = 30 }),
				table.freeze({ amount = 1750, weight = 20 }),
				table.freeze({ amount = 2500, weight = 10 }),
			}),
			PaintChance = 0.2, -- instead of cash, a chest-only paint the player doesn't have yet
		}),
		Weekly = table.freeze({
			Cash = table.freeze({ table.freeze({ amount = 5000, weight = 1 }) }),
			PaintChance = 1, -- always a paint, and the cash as well
			PaintAndCash = true,
			NoPaintCash = 7500, -- with every chest paint already owned: this cash instead
		}),
	}),
	OpenEvery = 1, -- seconds between chest opens a player may ask for
	SendEvery = 0.5, -- progress goes to the client at most this often
	-- Studio only, for testing: set this workspace attribute to "Kind:amount" (counts for every player, in the car
	-- they drive), or to "Chest:Daily" / "Chest:Weekly" (gives every player one)
	StudioAttribute = "StudioChallenge",
})
