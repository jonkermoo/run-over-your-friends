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
local SF = O.Shopfront
local BLACK = Color3.new(0, 0, 0)

export type OfficeColours = {
	wall: Color3,
	trim: Color3,
	accent: Color3,
	roof: Color3,
	stone: Color3,
	glass: Color3?, -- the tower's own tint (Config/Buildings Office.Tints); Office.Glass if missing
	shops: { Color3 }?, -- its shopfronts' colours, in turn (Office.Shopfront); stone lobby walls if missing
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
	local glassColour = c.glass or Kit.rgb(O.Glass)
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
		-- the front and both sides face streets and get shop windows; the back faces the car park
		local shops = if outward:Dot(front) > -0.9 then c.shops else nil
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
				elseif f == 0 and (isFront or shops) then
					-- lobby or shop window under a stone (or the shop's coloured) fascia, a shop's awning
					local fascia = if shops then SF.Fascia else SF.LobbyFascia
					part(
						model,
						Vector3.new(pw, 1.5, T),
						cf + Vector3.new(0, 0.75, 0),
						c.stone,
						stoneMat
					)
					local window = glass(
						Vector3.new(pw, FH - 1.5 - fascia, T * 0.6),
						cf + Vector3.new(0, 1.5 + (FH - 1.5 - fascia) / 2, 0)
					)
					if shops then
						local colour = shops[i % #shops + 1]
						local shopBand = part(
							model,
							Vector3.new(pw, fascia, T),
							cf + Vector3.new(0, FH - fascia / 2, 0),
							colour
						)
						local depth = SF.AwningDepth
						local awning = part(
							model,
							Vector3.new(pw - SF.AwningInset * 2, SF.AwningThick, depth),
							cf
								* CFrame.new(0, FH - fascia, -T / 2)
								* CFrame.Angles(-SF.AwningTilt, 0, 0)
								* CFrame.new(0, 0, -depth / 2),
							colour,
							Enum.Material.Fabric
						)
						awning.CanCollide = false
						-- pay as before: a side bay was one stone panel, so only its sill pays; awnings never do
						awning:SetAttribute("Pieces", 0)
						if not isFront then
							window:SetAttribute("Pieces", 0)
							shopBand:SetAttribute("Pieces", 0)
						end
					else
						part(
							model,
							Vector3.new(pw, fascia, T),
							cf + Vector3.new(0, FH - fascia / 2, 0),
							c.stone,
							stoneMat
						)
					end
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

-- a big 3D icon of what a shop sells, standing on its roof over the front parapet on a short post, facing the
-- street (Config/Buildings Shops.Icons): a donut, a wheel, a book, a toy box, a phone, an apple, a top hat, a
-- bone, an ice lolly, a light bulb, a cheese wedge or a sock. `frame` is at the icon's centre, -Z to the street.
local function icon(model: Model, frame: CFrame, kind: string, accent: Color3)
	local function p(
		size: Vector3,
		cf: CFrame,
		colour: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	): Part
		local q = Instance.new("Part")
		q.Anchored = true
		q.Size = size
		q.CFrame = frame * cf
		q.Color = colour
		q.Material = material or Enum.Material.SmoothPlastic
		q.TopSurface = Enum.SurfaceType.Smooth
		q.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			q.Shape = shape
		end
		q.Parent = model
		return q
	end
	local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
	local facing = CFrame.Angles(0, math.pi / 2, 0) -- a cylinder's axis turned to face the street
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis turned upright
	local white, dark = Color3.fromRGB(250, 248, 240), Color3.fromRGB(34, 34, 38)
	if kind == "donut" then
		p(
			Vector3.new(1.4, 8.4, 8.4),
			CFrame.new(0, 0, 0.4) * facing,
			Color3.fromRGB(214, 160, 96),
			nil,
			CYL
		)
		p(
			Vector3.new(1.4, 7.6, 7.6),
			CFrame.new(0, 0, -0.2) * facing,
			Color3.fromRGB(244, 126, 176),
			nil,
			CYL
		)
		p(
			Vector3.new(1.8, 2.6, 2.6),
			CFrame.new(0, 0, -0.3) * facing,
			Color3.fromRGB(120, 80, 50),
			nil,
			CYL
		)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2 + 0.3
			p(
				Vector3.new(1.2, 0.35, 0.3),
				CFrame.new(math.cos(a) * 2.8, math.sin(a) * 2.8, -1) * CFrame.Angles(0, 0, a * 2),
				if k % 2 == 0 then Color3.fromRGB(255, 208, 0) else Color3.fromRGB(90, 160, 240)
			)
		end
	elseif kind == "wheel" then
		p(Vector3.new(1.6, 8.4, 8.4), facing, dark, nil, CYL)
		p(Vector3.new(1.8, 6, 6), facing, Color3.fromRGB(200, 204, 210), Enum.Material.Metal, CYL)
		p(Vector3.new(2, 2, 2), facing, accent, nil, CYL)
	elseif kind == "book" then
		p(Vector3.new(6, 8, 1.4), CFrame.new(0, 0, 0), accent)
		p(Vector3.new(5.4, 7.6, 1.2), CFrame.new(0.5, 0, 0.1), white)
		p(Vector3.new(4.6, 1, 0.2), CFrame.new(0, 2, -0.75), Color3.fromRGB(255, 208, 0))
	elseif kind == "gift" then
		p(Vector3.new(6.4, 6.4, 6.4), CFrame.new(), accent)
		p(Vector3.new(1.2, 6.6, 6.6), CFrame.new(), Color3.fromRGB(255, 208, 0))
		p(Vector3.new(6.6, 1.2, 6.6), CFrame.new(), Color3.fromRGB(255, 208, 0))
		for _, e in { -1, 1 } do
			p(
				Vector3.one * 2.2,
				CFrame.new(e * 1.1, 3.8, 0),
				Color3.fromRGB(255, 208, 0),
				nil,
				BALL
			)
		end
	elseif kind == "phone" then
		p(Vector3.new(4.6, 8.4, 0.8), CFrame.new(), dark)
		p(
			Vector3.new(3.8, 6.6, 0.2),
			CFrame.new(0, 0.2, -0.45),
			Color3.fromRGB(120, 200, 255),
			Enum.Material.Neon
		)
	elseif kind == "apple" then
		p(Vector3.one * 7, CFrame.new(), Color3.fromRGB(220, 50, 50), nil, BALL)
		p(Vector3.new(0.6, 2, 0.6), CFrame.new(0, 4, 0), Color3.fromRGB(110, 70, 40))
		p(
			Vector3.new(2.4, 0.3, 1.2),
			CFrame.new(1.2, 4.4, 0) * CFrame.Angles(0, 0, 0.5),
			Color3.fromRGB(70, 160, 60)
		)
	elseif kind == "hat" then
		p(Vector3.new(6, 5, 5), CFrame.new(0, 0.6, 0) * upright, dark, nil, CYL)
		p(Vector3.new(0.5, 8.4, 8.4), CFrame.new(0, -2.4, 0) * upright, dark, nil, CYL)
		p(Vector3.new(1.1, 5.1, 5.1), CFrame.new(0, -1.4, 0) * upright, accent, nil, CYL)
	elseif kind == "bone" then
		p(Vector3.new(6.4, 1.8, 1.8), CFrame.new(), white, nil, CYL)
		for _, x in { -3.2, 3.2 } do
			for _, y in { -0.9, 0.9 } do
				p(Vector3.one * 2.6, CFrame.new(x, y, 0), white, nil, BALL)
			end
		end
	elseif kind == "lolly" then
		p(Vector3.new(4.4, 6, 1.4), CFrame.new(0, 1, 0), Color3.fromRGB(244, 126, 176))
		p(Vector3.new(4.4, 1.2, 1.5), CFrame.new(0, 3.4, 0), Color3.fromRGB(120, 70, 50))
		p(Vector3.new(0.8, 3, 0.4), CFrame.new(0, -3.4, 0), Color3.fromRGB(226, 196, 140))
	elseif kind == "bulb" then
		p(
			Vector3.one * 6,
			CFrame.new(0, 1, 0),
			Color3.fromRGB(255, 226, 120),
			Enum.Material.Neon,
			BALL
		)
		p(
			Vector3.new(2.4, 2.8, 2.8),
			CFrame.new(0, -2.6, 0) * upright,
			Color3.fromRGB(170, 174, 180),
			Enum.Material.Metal,
			CYL
		)
	elseif kind == "cheese" then
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.Size = Vector3.new(2.4, 6, 8)
		w.CFrame = frame * CFrame.Angles(0, math.pi / 2, 0)
		w.Color = Color3.fromRGB(255, 204, 60)
		w.Parent = model
		for k = 1, 3 do
			p(
				Vector3.new(0.3, 1.2, 1.2),
				CFrame.new(-1.8 + k * 1.2, -1.6 + (k % 2) * 1.2, -1.25) * facing,
				Color3.fromRGB(226, 170, 30),
				nil,
				CYL
			)
		end
	elseif kind == "sock" then
		p(Vector3.new(3, 6, 1.4), CFrame.new(-1, 1, 0), accent)
		p(Vector3.new(5, 2.6, 1.4), CFrame.new(0, -2.6, 0), accent)
		p(Vector3.new(3.1, 1, 1.5), CFrame.new(-1, 3.4, 0), white)
		p(Vector3.new(3.1, 0.7, 1.5), CFrame.new(-1, 1.6, 0), white)
	else
		p(Vector3.one * 6, CFrame.new(), accent, nil, BALL)
	end
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
	-- what it sells, big on the roof over the parapet (Config/Buildings Shops.Icons)
	local kind = S.Icons[label]
	if kind then
		local lift = S.IconLift
		put(
			ctx,
			Vector3.new(0.8, lift, 0.8),
			0,
			top + 2.5 + lift / 2,
			zf - 2.5,
			Color3.fromRGB(58, 58, 62),
			Enum.Material.Metal
		)
		icon(model, ctx.base * CFrame.new(0, top + 2.5 + lift + 4, -(zf - 2.5)), kind, ctx.accent)
	end
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
		true,
		"Shop_" .. label
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
