--!strict
-- Dressing for the zones outside the city (ZoneKit), laid on the finished ground: the port's quay (cast-iron
-- bollards, lifebuoys, floodlight masts, a gatehouse), the stunt park (an asphalt ground, red and white
-- barriers round its edge), the farm (a farmhouse with a picket fence, tractors) and the beaches (a row of
-- beach huts, sun loungers under umbrellas, a volleyball net). Meshes are in assets/Scenery.rbxm. Studs;
-- colours are { r, g, b }; offsets are { x, z } from the place named.

export type RGB = { number }

return table.freeze({
	Port = table.freeze({
		Bollards = 24, -- along the quay (replacing the plain posts)
		BollardIn = 5, -- in from the quay's edge
		BollardColour = { 40, 42, 46 } :: RGB,
		Buoys = 6, -- lifebuoys on white boards, between the bollards
		BuoyIn = 9,
		BuoyColour = { 240, 110, 30 } :: RGB,
		BoardColour = { 245, 245, 240 } :: RGB,
		Masts = 4, -- floodlight masts down the yard's landward side
		MastIn = 12, -- in from that side (past where the yard's walk points reach)
		MastHeight = 60,
		MastColour = { 120, 124, 130 } :: RGB,
		Lamp = { 255, 244, 214 } :: RGB,
		MastHead = table.freeze({ 1, 3, 12 }), -- the lamp frame on top: deep, tall, wide
		HeadOut = 1, -- out toward the quay from the mast...
		HeadUp = 1, -- ...and up from its top
		LampSize = table.freeze({ 0.4, 2.2, 11 }), -- the lit face on the frame's quay side
		LampOut = 1.7,
		-- the gatehouse beside where the road comes in: a booth with a window band and a raised boom
		Gate = table.freeze({
			In = 14, -- in from the yard's landward side (past where its walk points reach)
			Off = 12, -- past the road's side
			Booth = table.freeze({ 10, 9, 8 }), -- wide (along the road), tall, deep
			Wall = { 240, 240, 236 } :: RGB,
			Band = { 40, 110, 200 } :: RGB,
			Glass = { 170, 210, 230 } :: RGB,
			Boom = 26, -- long
			BoomColour = { 220, 50, 50 } :: RGB,
			BoomUp = 1.2, -- radians, raised so traffic passes
			Post = table.freeze({ 1.4, 3.6 }), -- the boom's post: across, tall
			PostOff = table.freeze({ 2, 1 }), -- past the booth's side, and out toward the road
		}),
	}),

	Stunt = table.freeze({
		Ground = { 62, 64, 70 } :: RGB, -- the park's ground, asphalt
		DirtIn = 8, -- the terrain under it is painted dirt to this far in from its edge
		Barrier = 12.5, -- one barrier every this far round the edge...
		BarrierGap = 0.5, -- (this much between them)
		BarrierHeight = 3.2,
		BarrierIn = 4, -- ...this far in from it
		BarrierColours = table.freeze({ { 220, 50, 50 }, { 240, 240, 236 } }) :: { RGB },
		GateGap = 16, -- the gate's opening is the road's width and this much either side
	}),

	Farm = table.freeze({
		House = table.freeze({ 30, 135 }), -- from the yard's middle (Config/Country Farm), facing west
		HouseType = "A",
		Palette = 3, -- of Config/Houses Palettes
		Lawn = 14,
		Drive = 11, -- a gap in the front border for a drive, this wide...
		DriveIn = 6.5, -- ...its middle this far in from the house's side
		Path = 3, -- and one for the path to the door
		-- tractors: { x, z, turn } from the yard's middle; the body and wheel colours
		Tractors = table.freeze({ { -62, -95, 0.5 }, { -150, 60, 2.3 } }),
		TractorBody = { 46, 130, 64 } :: RGB,
		TractorWheels = { 34, 34, 38 } :: RGB,
	}),

	Beach = table.freeze({
		-- huts in a row along the back of the beach, facing the sea, `At` of the beach's width inland, `From` of
		-- its length from its middle (clear of the lifeguard tower)
		Huts = 7,
		HutAt = 0.62,
		HutFrom = 0.18,
		HutGap = 17,
		Hut = table.freeze({ 10, 9, 8 }), -- wide, wall height, deep
		HutRoof = 3,
		HutClear = 14, -- a hut's spot is skipped if anything already on the beach is this close
		HutColours = table.freeze({
			{ 120, 190, 230 },
			{ 250, 200, 90 },
			{ 240, 130, 140 },
			{ 140, 210, 160 },
			{ 250, 250, 245 },
		}) :: { RGB },
		HutRoofColour = { 236, 236, 230 } :: RGB,
		HutDoor = { 60, 110, 170 } :: RGB,
		-- umbrellas with two loungers under each, on the sand between the water and the huts
		Sets = 10,
		SetFrom = 22, -- inland from the water's edge...
		SetTo = 0.52, -- ...to this share of the beach's width
		SetClear = 16, -- off each other, the tower and the huts
		SetTries = 6, -- spots tried per set
		SetEnd = 40, -- off the beach's ends
		LoungerLength = 6.2,
		LoungerApart = 2.2, -- either side of the pole
		LoungerIn = 1, -- a little inland of it
		LoungerTurn = 0.2, -- radians either way
		Loungers = table.freeze({ { 250, 250, 245 }, { 60, 140, 220 }, { 250, 210, 70 } }) :: { RGB },
		Umbrella = table.freeze({ 10, 13 }), -- tall, across
		-- a volleyball net: `At` of the width inland, `Along` of the length from the middle
		NetAt = 0.34,
		NetAlong = -0.28,
		Net = table.freeze({ 30, 8, 3 }), -- wide, post height, net depth
		NetColour = { 240, 240, 236 } :: RGB,
		Seed = 8820,
	}),
})
