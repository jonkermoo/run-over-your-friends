--!strict
-- Hourly and daily goals. Each template rolls a target between min and max (rounded to step);
-- the reward is target * perUnit, rounded to $10. "add" goals count up, "max" goals keep your best.
-- needs: only offered when the player owns a vehicle with that ability.

export type Template = {
	kind: string,
	mode: "add" | "max",
	text: string, -- {n} is the target
	min: number,
	max: number,
	step: number,
	perUnit: number,
	needs: string?,
}

local function t(row: Template): Template
	return table.freeze(row)
end

return table.freeze({
	Hourly = table.freeze({
		Count = 3,
		Seconds = 3600,
		Templates = table.freeze({
			t({
				kind = "Hits",
				mode = "add",
				text = "Run over {n} people",
				min = 15,
				max = 30,
				step = 5,
				perUnit = 20,
			}),
			t({
				kind = "Earn",
				mode = "add",
				text = "Earn ${n}",
				min = 1500,
				max = 3000,
				step = 500,
				perUnit = 0.2,
			}),
			t({
				kind = "Drive",
				mode = "add",
				text = "Drive {n} studs",
				min = 8000,
				max = 15000,
				step = 1000,
				perUnit = 0.04,
			}),
			t({
				kind = "Combo",
				mode = "max",
				text = "Hit a x{n} combo",
				min = 4,
				max = 6,
				step = 1,
				perUnit = 90,
			}),
			t({
				kind = "Launch",
				mode = "max",
				text = "Launch someone {n} studs",
				min = 80,
				max = 140,
				step = 20,
				perUnit = 4,
			}),
			t({
				kind = "Breaks",
				mode = "add",
				text = "Smash {n} building pieces",
				min = 30,
				max = 60,
				step = 10,
				perUnit = 10,
			}),
		}),
	}),
	Daily = table.freeze({
		Count = 3,
		Seconds = 86400,
		Templates = table.freeze({
			t({
				kind = "Hits",
				mode = "add",
				text = "Run over {n} people",
				min = 150,
				max = 250,
				step = 25,
				perUnit = 25,
			}),
			t({
				kind = "Earn",
				mode = "add",
				text = "Earn ${n}",
				min = 20000,
				max = 35000,
				step = 5000,
				perUnit = 0.25,
			}),
			t({
				kind = "Drive",
				mode = "add",
				text = "Drive {n} studs",
				min = 80000,
				max = 120000,
				step = 10000,
				perUnit = 0.05,
			}),
			t({
				kind = "Combo",
				mode = "max",
				text = "Hit a x{n} combo",
				min = 8,
				max = 12,
				step = 1,
				perUnit = 400,
			}),
			t({
				kind = "Launch",
				mode = "max",
				text = "Launch someone {n} studs",
				min = 200,
				max = 320,
				step = 40,
				perUnit = 15,
			}),
			t({
				kind = "Breaks",
				mode = "add",
				text = "Smash {n} building pieces",
				min = 300,
				max = 500,
				step = 50,
				perUnit = 12,
			}),
		}),
	}),
})
