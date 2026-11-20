--!strict
-- Roadside dressing outside the city (RoadsideKit): wooden power poles with sagging wires along the suburb
-- streets and the roads out of town, split-rail fences along the roads out of town, and a bus stop at each
-- suburb's entrance. Poles and fences are one mesh each (assets/Scenery.rbxm: Pole, RailFence); wires are
-- Beams (no parts). Studs; colours are { r, g, b }.

export type RGB = { number }

return table.freeze({
	Poles = table.freeze({
		Every = 72, -- along the road
		Height = 26,
		Colour = { 112, 82, 58 } :: RGB,
		-- the crossbar's ends, where the wires hang, from the pole's box middle: across and up, as shares of its
		-- height (the Pole mesh: ends 0.13 out, the wires at 0.96 of its 1.025)
		ArmAcross = 0.128,
		ArmUp = 0.437,
		WireColour = { 44, 44, 48 } :: RGB,
		WireWidth = 0.18,
		Sag = 3, -- how far each wire's curve pulls down between poles
		WireSegments = 8, -- how smooth each wire's curve is drawn
		MaxSpan = 130, -- poles further apart than this get no wire between them
		Clear = 6, -- off driveways, paths and lamps
		MouthClear = 4, -- and this much more off side streets' mouths than the sidewalks' outer edge
		BulbClear = 10, -- and this far past a cul-de-sac's turning circle
		Sink = 0.5,
		-- in the suburbs on the verge between the kerb and the sidewalk, on one side of each street; on the roads
		-- out of town this far past the road's edge
		RoadOut = 9,
	}),
	Fence = table.freeze({
		Length = 18, -- one section
		Height = 4.2,
		Colour = { 150, 112, 76 } :: RGB,
		Out = 5, -- past the road's edge
		EndGap = 45, -- none this close to either end of a road (junctions)
		SignClear = 34, -- none this close to a suburb's name board
		Sink = 0.3,
	}),
	BusStop = table.freeze({
		Back = 50, -- this far before the suburb's name board, on the other side of the road
		Out = 7, -- past the road's edge
		Shelter = table.freeze({ 12, 9, 5 }), -- wide, tall, deep
		Frame = { 60, 66, 76 } :: RGB,
		Roof = { 255, 208, 0 } :: RGB, -- the UI's road yellow
		Glass = { 180, 214, 230 } :: RGB,
		Bench = { 150, 112, 76 } :: RGB,
		SignColour = { 40, 110, 200 } :: RGB,
	}),
})
