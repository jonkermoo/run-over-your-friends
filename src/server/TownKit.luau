--!strict
-- Office towers and shop rows in the town style (Config/Buildings).
-- Office: a pale stone lobby with a glass front and a canopied door, window bands above (spandrel, glass,
-- a trim sill band), pilasters and a cornice every few floors, a parapet on the flat roof. Every wall panel
-- is its own chunk, so BuildingService smashes and rebuilds the tower; floor slabs and the roof are Fixed.
-- Shop: a townhouse front with a big shop window, an accent door, a striped awning and a hanging sign;
-- flats above with house windows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local B = require(ReplicatedStorage.Shared.Config.Buildings)
local H = require(ReplicatedStorage.Shared.Config.Houses)
local Rules = require(ReplicatedStorage.Shared.Rules.Buildings)
local World = require(ReplicatedStorage.Shared.Config.World)
local Kit = require(script.Parent.Kit)
local Places = require(script.Parent.Places)

local TownKit = {}

local M = World.Map
local O = B.Office
local S = B.Shops
local BLACK = Color3.new(0, 0, 0)

export type OfficeColours = {
	wall: Color3,
	trim: Color3,
	accent: Color3,
	roof: Color3,
	stone: Color3,
}

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- an office tower w × d with `floors` storeys at `centre` (ground); `front` is the face with the door.
-- Returns the model and the middle of the doorway at ground level.
function TownKit.office(
	parent: Folder,
	centre: Vector3,
	w: number,
	d: number,
	floors: number,
	c: OfficeColours,
	name: string,
	front: Vector3
): (Model, Vector3)
	local model = Instance.new("Model")
	model.Name = name
	local FH, T = M.FloorHeight, M.WallThickness
	local sill = FH * O.SillShare
	local top = floors * FH
	local stoneMat = (Enum.Material :: any)[O.StoneMaterial] :: Enum.Material
	local glassColour = Kit.rgb(O.Glass)
	local plinth = c.stone:Lerp(BLACK, 0.3)
	local parapet = c.wall:Lerp(BLACK, 0.3)
	local door = Vector3.new(centre.X, 0, centre.Z)
	local sections = Rules.sections(floors, O.CorniceEvery)

	local function glass(size: Vector3, cf: CFrame): Part
		local g = part(model, size, cf, glassColour, Enum.Material.Glass, 0.25)
		g:SetAttribute("Glass", true)
		return g
	end

	-- one face: `origin` is its left end on the ground, `length` along `along`, facing `outward`
	local function side(origin: Vector3, along: Vector3, outward: Vector3, length: number)
		local n = math.max(1, math.floor(length / O.PanelWidth + 0.5))
		local pw = length / n
		local isFront = outward:Dot(front) > 0.9
		local doorAt = n // 2
		local mid0 = origin + along * (length / 2)
		local faceCf = CFrame.lookAt(mid0, mid0 + outward)
		-- a band across the whole face, in pieces, from the middle of the wall out to `depth - T / 2` proud
		-- of it (never into the room, where it would fight the wall's inside face)
		local function band(
			y: number,
			h: number,
			depth: number,
			colour: Color3,
			extra: number,
			material: Enum.Material?
		)
			local reach = depth - T / 2
			for _, sp in Rules.pieces(length + extra, B.BandPiece) do
				local x = (sp.from + sp.to) / 2
				part(
					model,
					Vector3.new(sp.to - sp.from, h, reach),
					faceCf * CFrame.new(-x, y, -reach / 2),
					colour,
					material
				)
			end
		end
		for f = 0, floors - 1 do
			local y0 = f * FH
			for i = 0, n - 1 do
				local mid = origin + along * ((i + 0.5) * pw)
				local cf = CFrame.lookAt(mid, mid + outward)
				if f == 0 and isFront and i == doorAt then
					-- doorway: a stone lintel, accent jambs and header, a canopy and a step
					local DH = O.DoorHeight
					part(
						model,
						Vector3.new(pw, FH - DH, T),
						cf + Vector3.new(0, DH + (FH - DH) / 2, 0),
						c.stone,
						stoneMat
					)
					part(
						model,
						Vector3.new(pw, 0.8, T + 0.6),
						cf + Vector3.new(0, DH + 0.35, 0),
						c.accent
					)
					for _, e in { -1, 1 } do
						part(
							model,
							Vector3.new(0.8, DH, T + 0.4),
							cf * CFrame.new(e * (pw / 2 - 0.4), DH / 2, 0),
							c.accent
						)
					end
					part(
						model,
						Vector3.new(pw + 4, 0.5, 5),
						cf * CFrame.new(0, DH + 1.3, -2.5),
						c.roof
					)
					part(
						model,
						Vector3.new(pw + 4.4, 0.8, 0.4),
						cf * CFrame.new(0, DH + 1.3, -5),
						c.trim
					)
					part(
						model,
						Vector3.new(pw + 2, 0.4, 2.5),
						cf * CFrame.new(0, 0.2, -2),
						Kit.STEP,
						Enum.Material.Concrete
					)
					door = Vector3.new(mid.X, 0, mid.Z)
				elseif f == 0 and isFront then
					-- lobby window
					part(
						model,
						Vector3.new(pw, 1.5, T),
						cf + Vector3.new(0, 0.75, 0),
						c.stone,
						stoneMat
					)
					glass(
						Vector3.new(pw, FH - 4.5, T * 0.6),
						cf + Vector3.new(0, 1.5 + (FH - 4.5) / 2, 0)
					)
					part(
						model,
						Vector3.new(pw, 3, T),
						cf + Vector3.new(0, FH - 1.5, 0),
						c.stone,
						stoneMat
					)
				elseif f == 0 then
					part(
						model,
						Vector3.new(pw, FH, T),
						cf + Vector3.new(0, FH / 2, 0),
						c.stone,
						stoneMat
					)
				end
			end
			if f > 0 then
				-- spandrel below, window band above, a few panels to a piece
				for _, run in Rules.runs(n, O.UpperPanels) do
					local mid = origin + along * ((run.first + run.count / 2) * pw)
					local cf = CFrame.lookAt(mid, mid + outward)
					local width = run.count * pw
					local s = part(
						model,
						Vector3.new(width, sill, T),
						cf + Vector3.new(0, y0 + sill / 2, 0),
						c.wall
					)
					local g = glass(
						Vector3.new(width, FH - sill - 0.05, T * 0.6),
						cf + Vector3.new(0, y0 + sill + (FH - sill - 0.05) / 2, 0)
					)
					if run.count > 1 then
						s:SetAttribute("Pieces", run.count)
						g:SetAttribute("Pieces", run.count)
					end
				end
			end
		end
		-- plinth, lobby band, a sill band per floor, cornices, the top cornice and the parapet
		band(0.75, 1.5, T + 0.3, plinth, 0.4, stoneMat)
		band(FH, 1, T + 0.8, c.trim, 0.6)
		for f = 1, floors - 1 do
			band(f * FH + sill, 0.6, T + 0.8, c.trim, 0.6)
		end
		for k = 3, #sections do
			band(sections[k].from * FH, 1.4, T + 1.4, c.trim, 1)
		end
		band(top + 0.1, 1.4, T + 1.4, c.trim, 1)
		band(top + 0.8 + O.Parapet / 2, O.Parapet, T, parapet, 0)
		band(top + 0.8 + O.Parapet + 0.3, 0.6, T + 0.8, c.trim, 0.6)
		-- pilasters every few panels, one per section above the lobby
		for k = 2, #sections do
			local y0, y1 = sections[k].from * FH, sections[k].to * FH
			for _, b in Rules.pilasters(n, O.PilasterEvery) do
				local at = origin + along * (b * pw)
				local reach = T / 2 + 0.8
				part(
					model,
					Vector3.new(1.2, y1 - y0, reach),
					CFrame.lookAt(at, at + outward) * CFrame.new(0, (y0 + y1) / 2, -reach / 2),
					c.trim
				)
			end
		end
	end
	local hw, hd = w / 2, d / 2
	local base = Vector3.new(centre.X, 0, centre.Z)
	-- the walls stand on the footprint's edges (half in, half out): the long faces run the full width plus
	-- the wall's thickness and the sides fit between them, so the corners are closed
	side(
		base + Vector3.new(-hw - T / 2, 0, -hd),
		Vector3.new(1, 0, 0),
		Vector3.new(0, 0, -1),
		w + T
	)
	side(base + Vector3.new(-hw - T / 2, 0, hd), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), w + T)
	side(
		base + Vector3.new(-hw, 0, -hd + T / 2),
		Vector3.new(0, 0, 1),
		Vector3.new(-1, 0, 0),
		d - T
	)
	side(base + Vector3.new(hw, 0, -hd + T / 2), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), d - T)
	-- corner pilasters, one per section
	for _, sec in sections do
		local y0 = if sec.from == 0 then 1.5 else sec.from * FH
		local y1 = sec.to * FH
		for _, cx in { -1, 1 } do
			for _, cz in { -1, 1 } do
				part(
					model,
					Vector3.new(1.8, y1 - y0, 1.8),
					CFrame.new(
						base + Vector3.new(cx * (hw + 0.25), (y0 + y1) / 2, cz * (hd + 0.25))
					),
					c.trim
				)
			end
		end
	end
	-- floors and roof in tiles about 45 studs across
	local tx, tz = math.max(1, math.floor(w / 45 + 0.5)), math.max(1, math.floor(d / 45 + 0.5))
	for f = 1, floors do
		local y = f * FH - 0.6
		for i = 0, tx - 1 do
			for j = 0, tz - 1 do
				local cx = centre.X - hw + (i + 0.5) * w / tx
				local cz = centre.Z - hd + (j + 0.5) * d / tz
				local slab = part(
					model,
					Vector3.new(w / tx, 1.2, d / tz),
					CFrame.new(cx, y, cz),
					if f == floors then c.roof else Color3.fromRGB(190, 190, 195)
				)
				-- floors are the tower's structure: never broken, so what stands on them stays
				slab:SetAttribute("Fixed", true)
			end
		end
	end
	-- each client furnishes the lobby and the floors above from these (Rules/Interiors)
	local pivot = CFrame.lookAt(base, base + front)
	local across = Vector3.new(-front.Z, 0, front.X)
	model.WorldPivot = pivot
	model:SetAttribute("Interior", "Office")
	model:SetAttribute("W", math.abs(across:Dot(Vector3.new(w, 0, d))))
	model:SetAttribute("D", math.abs(front:Dot(Vector3.new(w, 0, d))))
	model:SetAttribute("Floors", floors)
	model:SetAttribute("DoorX", pivot:PointToObjectSpace(door).X)
	model:SetAttribute("Accent", c.accent)
	model.Parent = parent
	return model, door
end

-- one shop in a row: `width` wide, Config depth, facing the street along `out`; walls in the district's
-- colour and material, trim / accent / roof from a house palette. Returns its Place.
function TownKit.shop(
	parent: Instance,
	c: Vector3,
	out: Vector3,
	width: number,
	floors: number,
	wall: Color3,
	material: Enum.Material,
	palette: H.Palette,
	mirror: boolean,
	label: string,
	name: string
): Places.Place
	local model = Instance.new("Model")
	model.Name = name
	local ctx = Kit.context(model, c, out, mirror, {
		wall = wall,
		trim = Kit.rgb(palette.trim),
		accent = Kit.rgb(palette.accent),
		roof = Kit.rgb(palette.roof),
	}, material, H.Wall)
	local put, Y0, T = Kit.put, Kit.Y0, H.Wall
	local GF, UF = S.GroundHeight, H.FloorHeight
	local d = S.Depth
	local zf, zb = d / 2, -d / 2
	local half = width / 2
	local top = Y0 + GF + (floors - 1) * UF
	local segs, doorX = Rules.shopFront(width, S.Door)
	local front: { Kit.Seg } = {}
	for _, s in segs do
		table.insert(front, Kit.seg(s.a, s.b, s.k))
	end
	Kit.row(ctx, zf, 1, Y0, GF, front)
	-- flats above: three framed windows a floor, a string course under each floor
	for f = 1, floors - 1 do
		local y0 = Y0 + GF + (f - 1) * UF
		local third = width / 3
		Kit.row(ctx, zf, 1, y0, UF, {
			Kit.seg(-half, -half + third, "p", { fl = f == 1 }),
			Kit.seg(-half + third, half - third, "p"),
			Kit.seg(half - third, half, "p", { fl = f == 1 }),
		})
		put(ctx, Vector3.new(width + 0.6, 0.5, T / 2 + 0.2), 0, y0, zf - T / 4 + 0.1, ctx.trim)
		put(
			ctx,
			Vector3.new(width - 2 * T, 0.8, d - 2 * T),
			0,
			y0,
			0,
			Color3.fromRGB(200, 196, 188)
		)
	end
	local backSegs: { Kit.Seg } = {}
	for _, sp in Rules.pieces(width, 12) do
		table.insert(backSegs, Kit.seg(sp.from, sp.to, "s"))
	end
	Kit.row(ctx, zb, -1, Y0, top - Y0, backSegs)
	Kit.sides(ctx, half, zf, zb, Y0, top - Y0, false)
	Kit.trims(ctx, 0, half, zf, zb, top, true)
	-- flat roof, parapet with a cap
	put(ctx, Vector3.new(width, 0.8, d), 0, top - 0.45, 0, ctx.roof)
	put(
		ctx,
		Vector3.new(width + 0.4, 2, T),
		0,
		top + 1,
		zf - T / 2,
		wall:Lerp(Color3.new(0, 0, 0), 0.3),
		material
	)
	put(ctx, Vector3.new(width + 0.8, 0.5, T + 0.8), 0, top + 2.25, zf - T / 2, ctx.trim)
	-- striped awning over the window and the door, sloping down to the street
	local a0, a1 = -half + 2, half - 3
	local n = S.AwningStripes
	local sw = (a1 - a0) / n
	local tilt = math.rad(20)
	local white = Kit.rgb(S.AwningWhite)
	for k = 0, n - 1 do
		put(
			ctx,
			Vector3.new(sw, 0.3, S.AwningDepth),
			a0 + (k + 0.5) * sw,
			Y0 + GF - 2.4 - math.sin(tilt) * S.AwningDepth / 2,
			zf + math.cos(tilt) * S.AwningDepth / 2,
			if k % 2 == 0 then ctx.accent else white,
			nil,
			CFrame.Angles(-tilt, 0, 0)
		)
	end
	-- hanging sign on a bracket at the left end whether mirrored or not (so neighbours' signs never meet),
	-- readable from the sidewalk both ways
	local sx = (-half + 0.8) * ctx.m
	local signW, signH = S.Sign[1], S.Sign[2]
	put(
		ctx,
		Vector3.new(0.4, 0.4, signW + 1),
		sx,
		Y0 + GF + signH / 2 + 0.4,
		zf + (signW + 1) / 2,
		Color3.fromRGB(58, 58, 62),
		Enum.Material.Metal
	)
	local signAt = Kit.at(ctx, sx, Y0 + GF + 0.2, zf + 1 + signW / 2)
	Places.sign(
		model,
		Vector3.new(signW, signH, 0.3),
		CFrame.lookAt(signAt, signAt + ctx.base.RightVector),
		label,
		ctx.accent,
		Color3.new(1, 1, 1),
		true
	)
	-- each client furnishes the shop floor from these (Rules/Interiors); the shopkeeper and shoppers use them
	model.WorldPivot = ctx.base
	model:SetAttribute("Mirror", mirror)
	model:SetAttribute("Interior", "Shop")
	model:SetAttribute("W", width)
	model:SetAttribute("D", d)
	model:SetAttribute("H", GF)
	model:SetAttribute("DoorX", doorX)
	model:SetAttribute("Island", S.Themes[label].island)
	model:SetAttribute("Theme", label)
	model:SetAttribute("Accent", ctx.accent)
	model.Parent = parent
	return Places.shop(model, Kit.at(ctx, doorX, 0, zf), out, label)
end

return TownKit
