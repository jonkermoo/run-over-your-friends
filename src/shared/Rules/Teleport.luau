--!strict
-- Teleporting from the city map (Config/Teleport): where each area is, its landing spots, which spot to use and
-- whether a teleport is allowed. Pure, so Lune tests it.

local Teleport = {}

export type Area = {
	key: string,
	name: string,
	x: number,
	z: number,
	roads: boolean,
	radius: number,
	count: number,
	offsets: { Spot }?, -- fixed landing spots, as offsets from the middle (Config/Teleport `spots`)
}
export type Spot = { x: number, z: number }

type MapCfg = { BlockSize: number, RoadWidth: number, BlocksX: number, BlocksZ: number }
type Hood = { name: string, dir: { number }, offset: number, start: number, length: number }
type Rect = { x: number, z: number }

-- the spawn plaza's middle: the middle block of the city grid (MapBuilder)
function Teleport.plaza(m: MapCfg): (number, number)
	local pitch = m.BlockSize + m.RoadWidth
	local x0 = -(m.BlocksX * pitch + m.RoadWidth) / 2
	local z0 = -(m.BlocksZ * pitch + m.RoadWidth) / 2
	local half = m.RoadWidth + m.BlockSize / 2
	return x0 + half + math.floor(m.BlocksX / 2) * pitch,
		z0 + half + math.floor(m.BlocksZ / 2) * pitch
end

-- a suburb's middle: halfway along its spine (SuburbKit)
function Teleport.hoodMiddle(h: Hood): (number, number)
	local dx, dz = h.dir[1], h.dir[2]
	local along = h.start + h.length / 2
	return math.abs(dz) * h.offset + dx * along, math.abs(dx) * h.offset + dz * along
end

-- every area in Config order, with its middle worked out; an area whose source is missing is left out
function Teleport.areas(places: { any }, m: MapCfg, hoods: { Hood }, moto: Rect): { Area }
	local out = {}
	for _, p in places do
		local x, z = nil :: number?, nil :: number?
		if p.from == "Plaza" then
			x, z = Teleport.plaza(m)
		elseif p.from == "Suburb" then
			for _, h in hoods do
				if h.name == p.hood then
					x, z = Teleport.hoodMiddle(h)
				end
			end
		elseif p.from == "Moto" then
			x, z = moto.x, moto.z
		elseif p.from == "Spot" then
			x, z = p.x, p.z
		end
		if x and z then
			local offsets: { Spot }? = nil
			if p.spots then
				local list = {}
				for _, o in p.spots do
					table.insert(list, { x = o[1], z = o[2] })
				end
				offsets = list
			end
			table.insert(out, {
				key = p.key,
				name = p.name,
				x = x,
				z = z,
				roads = p.roads,
				radius = p.radius,
				count = p.count or 0,
				offsets = offsets,
			})
		end
	end
	return out
end

function Teleport.find(areas: { Area }, key: any): Area?
	for _, a in areas do
		if a.key == key then
			return a
		end
	end
	return nil
end

local function d2(ax: number, az: number, bx: number, bz: number): number
	return (ax - bx) ^ 2 + (az - bz) ^ 2
end

-- an area's landing spots: the road points within its radius, nearest first, kept minGap apart (at most
-- maxSpots), or its fixed spots if it has them, or else `count` points evenly round a circle of its radius
function Teleport.spots(area: Area, roads: { Spot }, minGap: number, maxSpots: number): { Spot }
	local out: { Spot } = {}
	if not area.roads and area.offsets then
		for _, o in area.offsets do
			table.insert(out, { x = area.x + o.x, z = area.z + o.z })
		end
		return out
	end
	if not area.roads then
		for i = 1, area.count do
			local a = (i - 1) / area.count * 2 * math.pi
			table.insert(
				out,
				{ x = area.x + math.cos(a) * area.radius, z = area.z + math.sin(a) * area.radius }
			)
		end
		return out
	end
	local near = {}
	for _, p in roads do
		if d2(p.x, p.z, area.x, area.z) <= area.radius ^ 2 then
			table.insert(near, p)
		end
	end
	table.sort(near, function(a, b)
		return d2(a.x, a.z, area.x, area.z) < d2(b.x, b.z, area.x, area.z)
	end)
	for _, p in near do
		if #out >= maxSpots then
			break
		end
		local apart = true
		for _, q in out do
			if d2(p.x, p.z, q.x, q.z) < minGap ^ 2 then
				apart = false
				break
			end
		end
		if apart then
			table.insert(out, { x = p.x, z = p.z })
		end
	end
	return out
end

-- the order to try an area's spots: every spot once, starting at `start` (1-based, wraps), the free ones (no
-- busy point within `clear`) first, then the rest from the emptiest (farthest nearest busy point) down
function Teleport.order(spots: { Spot }, busy: { Spot }, clear: number, start: number): { number }
	local n = #spots
	local free, taken = {}, {}
	local room: { [number]: number } = {}
	for k = 0, n - 1 do
		local i = (start - 1 + k) % n + 1
		local s = spots[i]
		local nearest = math.huge
		for _, b in busy do
			nearest = math.min(nearest, d2(s.x, s.z, b.x, b.z))
		end
		room[i] = nearest
		if nearest >= clear ^ 2 then
			table.insert(free, i)
		else
			table.insert(taken, i)
		end
	end
	table.sort(taken, function(a, b)
		return room[a] > room[b]
	end)
	for _, i in taken do
		table.insert(free, i)
	end
	return free
end

export type Ask = {
	known: boolean, -- the area exists
	alive: boolean,
	passenger: boolean, -- sitting in someone else's car (its driver decides where it goes)
	now: number,
	readyAt: number, -- the cooldown's end
	nearEvent: boolean, -- the area is within EventKeepAway of the live event's spot
}

-- why a teleport is refused, or nil when it may go: "Unknown", "Dead", "Passenger", "Cooldown", "Event"
function Teleport.refusal(ask: Ask): string?
	if not ask.known then
		return "Unknown"
	elseif not ask.alive then
		return "Dead"
	elseif ask.passenger then
		return "Passenger"
	elseif ask.now < ask.readyAt then
		return "Cooldown"
	elseif ask.nearEvent then
		return "Event"
	end
	return nil
end

-- is the area's middle within keepAway of the live event's spot (if there is one)?
function Teleport.nearEvent(area: Area, ex: number?, ez: number?, keepAway: number): boolean
	if not ex or not ez then
		return false
	end
	return d2(area.x, area.z, ex, ez) < keepAway ^ 2
end

-- whole seconds left on the cooldown, for the button
function Teleport.secondsLeft(now: number, readyAt: number): number
	return math.max(0, math.ceil(readyAt - now))
end

return Teleport
