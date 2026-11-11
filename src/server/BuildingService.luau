--!strict
-- Destructible buildings: every building is anchored chunks (wall panels, windows, slabs, columns).
-- A hit breaks the chunks in a radius and drops what stood on them, up to the next floor slab; parts marked
-- Fixed (office floor slabs and roofs) are structure and never break in those. A broken wall crumbles
-- (Rules/Crumble): the cells near the hit are thrown out as bricks that every client simulates on its own
-- (src/client/Crumble), and the rest stands on here as a few real blocks ("remnants", breakable in turn) until
-- the building puts itself back together. Nothing goes loose in the server's physics. The biggest hits bring
-- the whole building down: every client draws the fall (src/client/Collapse) and the pieces just go.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollapseRules = require(ReplicatedStorage.Shared.Rules.Collapse)
local CrumbleRules = require(ReplicatedStorage.Shared.Rules.Crumble)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Impact = require(ReplicatedStorage.Shared.Rules.Impact)
local Net = require(ReplicatedStorage.Shared.Net)
local Smash = require(ReplicatedStorage.Shared.Config.Smash)
local Streets = require(ReplicatedStorage.Shared.Config.Streets)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local World = require(ReplicatedStorage.Shared.Config.World)
local Analytics = require(script.Parent.Analytics)
local Data = require(script.Parent.Data)
local Passes = require(script.Parent.Passes)
local VehicleService = require(script.Parent.VehicleService)

local BuildingService = {}
local CFG = World.Debris
local COLLAPSE = Smash.Collapse
local CRUMBLE = Smash.Crumble

type Chunk = { cf: CFrame, transparency: number, glass: boolean }
local chunks: { [BasePart]: Chunk } = {}
-- whole buildings that can come down: their Fixed floors and roofs, every part, and which are down right now
local structure: { [BasePart]: Chunk } = {}
local buildingParts: { [Model]: { BasePart } } = {}
local ownerOf: { [BasePart]: Model } = {}
local down: { [Model]: boolean } = {}
-- the blocks still standing of each broken wall, and the wall each came from
local remnantsOf: { [BasePart]: { BasePart } } = {}
local rootOf: { [BasePart]: BasePart } = {}
local remnantCount = 0
local buildingsFolder: Folder? = nil
local propsFolder: Folder? = nil
local propDownUntil: { [Model]: number } = {}
local lastBreak: { [Player]: number } = {}
local random = Random.new()

function BuildingService.register(folder: Folder)
	buildingsFolder = folder
	for _, p in folder:GetDescendants() do
		if p:IsA("BasePart") then
			local chunk = {
				cf = p.CFrame,
				transparency = p.Transparency,
				glass = p:GetAttribute("Glass") == true,
			}
			if p:GetAttribute("Fixed") then
				structure[p] = chunk
			else
				chunks[p] = chunk
			end
		end
	end
	-- houses and town buildings can come down; containers, cranes and ships only lose pieces
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and (m:GetAttribute("HouseType") or m:GetAttribute("Interior")) then
			local parts = {}
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") and (chunks[p] or structure[p]) then
					table.insert(parts, p)
					ownerOf[p] = m
				end
			end
			buildingParts[m] = parts
		end
	end
end

-- street furniture: knocked flying by any vehicle, stood back up later
function BuildingService.registerProps(folder: Folder)
	propsFolder = folder
	for _, p in folder:GetDescendants() do
		if p:IsA("BasePart") then
			chunks[p] = { cf = p.CFrame, transparency = p.Transparency, glass = false }
		end
	end
end

local function hide(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
end

local function dropRemnant(rem: BasePart)
	local root = rootOf[rem]
	chunks[rem] = nil
	ownerOf[rem] = nil
	rootOf[rem] = nil
	local list = root and remnantsOf[root]
	if list then
		local i = table.find(list, rem)
		if i then
			table.remove(list, i)
		end
	end
	remnantCount -= 1
	rem:Destroy()
end

local function restore(part: BasePart, always: boolean?)
	local c = chunks[part] or structure[part]
	local owner = ownerOf[part]
	-- a piece's own timer doesn't bring it back while its building is down; the building's does
	if not c or not part.Parent or rootOf[part] or (owner and down[owner] and not always) then
		return
	end
	local standing = remnantsOf[part]
	if standing then
		for i = #standing, 1, -1 do
			dropRemnant(standing[i])
		end
		remnantsOf[part] = nil
	end
	part.Anchored = true
	part.AssemblyLinearVelocity = Vector3.zero
	part.CFrame = c.cf
	part.CollisionGroup = "Default"
	part.Transparency = c.transparency
	part.CanCollide = true
	part.CanQuery = true
	part:SetAttribute("Broken", nil)
end

local function shatter(part: BasePart)
	local a = Instance.new("Attachment")
	a.Parent = workspace.Terrain
	a.WorldPosition = part.Position
	local fx = Instance.new("ParticleEmitter")
	fx.Color = ColorSequence.new(Color3.fromRGB(190, 225, 245))
	fx.Size = NumberSequence.new(0.6, 0.1)
	fx.Speed = NumberRange.new(10, 30)
	fx.SpreadAngle = Vector2.new(180, 180)
	fx.Lifetime = NumberRange.new(0.6, 1.2)
	fx.Acceleration = Vector3.new(0, -60, 0)
	fx.Rate = 0
	fx.Parent = a
	fx:Emit(25)
	Debris:AddItem(a, 2)
end

-- how many pieces a part counts for: town buildings join a few wall panels into one part ("Pieces")
local function worth(p: BasePart): number
	local n = p:GetAttribute("Pieces")
	return if typeof(n) == "number" then n else 1
end

export type Burst = {
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	transparency: number,
	shape: string,
	part: BasePart?,
	na: number,
	nb: number,
	fly: { number },
}

-- the hitting vehicle's way through: no block is left standing within `radius` of the line from `at` along `dir`
type Way = { at: Vector3, dir: Vector3, radius: number }

local function shapeOf(p: BasePart): string
	if p:IsA("Part") then
		if p.Shape == Enum.PartType.Block then
			return "Block"
		elseif p.Shape == Enum.PartType.Cylinder then
			return "Cylinder"
		end
	end
	return "Other"
end

-- a vector with x on side a and y on side b (1 = X, 2 = Y, 3 = Z), the third side from `rest` (or 0)
local function onAxes(a: number, b: number, x: number, y: number, rest: { number }?): Vector3
	local v = if rest then { rest[1], rest[2], rest[3] } else { 0, 0, 0 }
	v[a], v[b] = x, y
	return Vector3.new(v[1], v[2], v[3])
end

-- a standing block cut from `source` (a wall or an earlier block of it), a real part until the wall rebuilds
local function addRemnant(source: BasePart, root: BasePart, cf: CFrame, size: Vector3)
	local rem = source:Clone()
	for _, child in rem:GetChildren() do
		if not child:IsA("Texture") then
			child:Destroy()
		end
	end
	rem:SetAttribute("Broken", nil)
	rem:SetAttribute("Pieces", 0) -- the wall paid when it broke; what's left pays nothing more
	rem.Size = size
	rem.CFrame = cf
	local c = chunks[source]
	chunks[rem] = {
		cf = cf,
		transparency = if c then c.transparency else source.Transparency,
		glass = false,
	}
	rootOf[rem] = root
	ownerOf[rem] = ownerOf[root]
	local list = remnantsOf[root] or {}
	remnantsOf[root] = list
	table.insert(list, rem)
	remnantCount += 1
	rem.Parent = source.Parent
end

-- cut a broken part for throwing: around the hit (a hole of `radius`, the rest left standing as remnants) or,
-- with no hit, all of it; about `most` bricks at most
local function crumble(
	part: BasePart,
	hit: Vector3?,
	radius: number,
	most: number,
	way: Way?
): Burst
	local shape = shapeOf(part)
	local size = part.Size
	local s = { size.X, size.Y, size.Z }
	local k, a, b = CrumbleRules.axes(s[1], s[2], s[3])
	if shape == "Cylinder" then
		k, a, b = 3, 1, 2
	end
	local A, B = s[a], s[b]
	local grid: CrumbleRules.Grid? = nil
	local fly: { number } = {}
	local stays: { CrumbleRules.Rect } = {}
	if shape == "Block" and hit then
		local l = part.CFrame:PointToObjectSpace(hit)
		local lp = { l.X, l.Y, l.Z }
		local r = CrumbleRules.reach(radius, math.max(math.abs(lp[k]) - s[k] / 2, 0))
		local cut = CrumbleRules.grid(A, B, r, most, CRUMBLE)
		local seed = random:NextInteger(0, 2 ^ 31 - 1)
		fly = CrumbleRules.hole(cut, A, B, lp[a], lp[b], r, most, seed, CRUMBLE)
		if way then
			local gone = {}
			for _, cell in fly do
				gone[cell] = true
			end
			for j = 0, cut.nb - 1 do
				for i = 0, cut.na - 1 do
					local cell = j * cut.na + i + 1
					if not gone[cell] then
						local u, v = CrumbleRules.cellCentre(cut, A, B, i, j)
						local rel = part.CFrame:PointToWorldSpace(onAxes(a, b, u, v)) - way.at
						if (rel - way.dir * rel:Dot(way.dir)).Magnitude < way.radius then
							table.insert(fly, cell)
						end
					end
				end
			end
		end
		stays = CrumbleRules.mesh(cut, fly)
		local left = 1 - #fly / (cut.na * cut.nb)
		if
			#stays <= CRUMBLE.MaxStay
			and left >= CRUMBLE.MinStayShare
			and remnantCount + #stays <= CRUMBLE.MaxRemnants
		then
			grid = cut
		else
			stays = {}
		end
	end
	if not grid then
		local whole = CrumbleRules.grid(A, B, math.huge, most, CRUMBLE)
		if shape == "Cylinder" then
			whole = { na = math.min(whole.na, most), nb = 1 }
		elseif shape == "Other" then
			whole = { na = 1, nb = 1 }
		end
		grid = whole
		fly = CrumbleRules.all(whole)
	end
	local cut = grid :: CrumbleRules.Grid
	local root = rootOf[part] or part
	for _, rect in stays do
		local u, v, w, h = CrumbleRules.rectBox(cut, A, B, rect)
		addRemnant(part, root, part.CFrame * CFrame.new(onAxes(a, b, u, v)), onAxes(a, b, w, h, s))
	end
	local c = chunks[part]
	return {
		cf = part.CFrame,
		size = size,
		color = part.Color,
		material = part.Material,
		transparency = if c then c.transparency else part.Transparency,
		shape = shape,
		part = if shape == "Other" then part else nil,
		na = cut.na,
		nb = cut.nb,
		fly = fly,
	}
end

-- send the bricks of a break only to players near enough to see them (Config/Smash Crumble FarStuds)
local function sendBricks(at: Vector3, bursts: { Burst }, push: Vector3, scatter: number?)
	if #bursts == 0 then
		return
	end
	local remote = Net.remote("Crumble")
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local root = character and character.PrimaryPart
		if root and (root.Position - at).Magnitude < CRUMBLE.FarStuds + 100 then
			remote:FireClient(p, bursts, at, push, scatter)
		end
	end
end

-- break one part: glass shatters, anything else crumbles into `bursts`; a wall rebuilds later (with whatever
-- of it was left standing), a remnant just goes. Returns the pieces it counts for.
local function loosen(
	part: BasePart,
	bursts: { Burst },
	hit: Vector3?,
	radius: number,
	most: number,
	way: Way?
): number
	if part:GetAttribute("Broken") then
		return 0
	end
	part:SetAttribute("Broken", true)
	local c = chunks[part]
	if c and c.glass then
		shatter(part)
	else
		table.insert(bursts, crumble(part, hit, radius, most, way))
	end
	hide(part)
	local pieces = worth(part)
	if rootOf[part] then
		dropRemnant(part)
	else
		task.delay(CFG.RebuildSeconds + random:NextNumber(0, 8), restore, part)
	end
	return pieces
end

local breakListeners: { (Player, number) -> () } = {}

-- called with the player and how many pieces they broke
function BuildingService.onBreak(listener: (Player, number) -> ())
	table.insert(breakListeners, listener)
end

-- break everything within radius of pos; push is the hitter's velocity (studs/s); `way` keeps the hitter's path
-- through the wall open. Returns the pieces broken.
function BuildingService.breakAt(
	pos: Vector3,
	radius: number,
	push: Vector3,
	player: Player?,
	way: Way?
): number
	if not buildingsFolder or radius <= 0 then
		return 0
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { buildingsFolder }
	local struck: { BasePart } = {}
	local taken: { [BasePart]: boolean } = {}
	for _, p in workspace:GetPartBoundsInRadius(pos, radius, params) do
		if p.Anchored and chunks[p] and not p:GetAttribute("Broken") then
			table.insert(struck, p)
			taken[p] = true
		end
	end
	if #struck == 0 then
		return 0
	end
	-- whatever stood on the broken part falls too, unless the break is only a small hole; a floor slab above
	-- holds up everything over it
	local reach = radius * CFG.ChunkFallReach
	local above = if radius >= Smash.FloorsFallFrom
		then workspace:GetPartBoundsInBox(
			CFrame.new(pos.X, pos.Y + 300, pos.Z),
			Vector3.new(reach * 2, 600, reach * 2),
			params
		)
		else {}
	local ceiling = math.huge
	for _, p in above do
		if p:GetAttribute("Fixed") and p.Position.Y > pos.Y + 2 then
			ceiling = math.min(ceiling, p.Position.Y)
		end
	end
	local falling: { BasePart } = {}
	for _, p in above do
		if #falling >= 260 then
			break
		end
		if
			not taken[p]
			and p.Anchored
			and chunks[p]
			and not p:GetAttribute("Broken")
			and p.Position.Y > pos.Y + 2
			and p.Position.Y < ceiling
		then
			table.insert(falling, p)
		end
	end
	-- the bricks one break may throw are shared out over everything it breaks
	local most = CrumbleRules.share(CRUMBLE.Budget, #struck + #falling, CRUMBLE.MaxFly)
	local thrown: { Burst } = {}
	local count = 0
	for _, p in struck do
		count += loosen(p, thrown, pos, radius, most, way)
	end
	sendBricks(pos, thrown, push * CRUMBLE.PushShare)
	if #falling > 0 then
		local dropping: { Burst } = {}
		for _, p in falling do
			count += loosen(p, dropping, nil, 0, most)
		end
		sendBricks(pos, dropping, Vector3.zero, CRUMBLE.DropScatter)
	end
	Net.remote("Fx")
		:FireAllClients(
			"Break",
			pos,
			math.max(count, 1),
			radius,
			if player then player.UserId else 0
		)
	if player and count > 0 then
		for _, listener in breakListeners do
			task.spawn(listener, player, count)
		end
	end
	return count
end

-- bring the whole building at pos down; true when it did (false: none there, or it's down already)
local function collapse(pos: Vector3, velocity: Vector3, player: Player): boolean
	local folder = buildingsFolder
	if not folder then
		return false
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local building: Model? = nil
	local best = math.huge
	for _, p in workspace:GetPartBoundsInRadius(pos, 6, params) do
		local owner = ownerOf[p]
		local d = (p.Position - pos).Magnitude
		if owner and not down[owner] and not p:GetAttribute("Broken") and d < best then
			building, best = owner, d
		end
	end
	if not building then
		return false
	end
	local model = building :: Model
	down[model] = true
	model:SetAttribute("Collapsed", true)
	local parts = buildingParts[model]
	local count = 0
	for _, p in parts do
		if not p:GetAttribute("Broken") then
			p:SetAttribute("Broken", true)
			p.CanCollide = false
			p.CanQuery = false
			count += worth(p)
		end
		-- what was left standing of its broken walls comes down with it (and goes when they rebuild)
		for _, rem in remnantsOf[p] or {} do
			rem:SetAttribute("Broken", true)
			rem.CanCollide = false
			rem.CanQuery = false
		end
	end
	local pay = CollapseRules.payout(count, COLLAPSE)
		* (if Passes.has(player, "DoubleMoney") then Economy.DoubleMoney else 1)
	Net.remote("Collapse"):FireAllClients(model, pos, velocity, pay, player.UserId)
	task.delay(COLLAPSE.PaySeconds, function()
		if player.Parent then
			Data.addMoney(player, pay)
		end
	end)
	Analytics.custom(player, "Demolished")
	task.delay(COLLAPSE.HideSeconds, function()
		for _, p in parts do
			if p.Anchored and p:GetAttribute("Broken") then
				hide(p)
			end
			for _, rem in remnantsOf[p] or {} do
				hide(rem)
			end
		end
	end)
	task.delay(CFG.RebuildSeconds, function()
		down[model] = nil
		model:SetAttribute("Collapsed", nil)
		for _, p in parts do
			restore(p, true)
		end
	end)
	for _, listener in breakListeners do
		task.spawn(listener, player, math.min(count, COLLAPSE.GoalPieces))
	end
	return true
end

local function onBreak(player: Player, pos: unknown, velocity: unknown)
	if
		typeof(pos) ~= "Vector3"
		or typeof(velocity) ~= "Vector3"
		or pos ~= pos
		or velocity ~= velocity
	then
		return
	end
	local now = os.clock()
	if (lastBreak[player] or 0) + 0.12 > now then
		return
	end
	lastBreak[player] = now
	local vehicle = VehicleService.of(player)
	local stats = vehicle and VehicleService.stats(vehicle)
	local chassis = vehicle and vehicle.PrimaryPart
	if not (stats and chassis) then
		return
	end
	local spm = Vehicles.StudsPerMetre
	local maxStuds = stats.topSpeed
			/ 2.237
			* spm
			* (if Vehicles.has(stats, "Jet") then 1.45 else 1.2)
		+ 10
	local speed = math.min(velocity.Magnitude, maxStuds)
	local body = VehicleService.bodyNear(vehicle :: Model, pos) or chassis
	if (pos - body.Position).Magnitude > body.Size.Magnitude / 2 + 16 + speed * 0.3 then
		return
	end
	local metres = speed / spm
	if
		Impact.collapses(stats.weight, metres, Smash, stats.maxBreak)
		and collapse(pos, velocity.Unit * speed, player)
	then
		return
	end
	local radius = Impact.smashRadius(stats.weight, metres, Smash, stats.maxBreak)
	-- the vehicle's own outline (plus a little) stays open along its way, so it never sticks in what's left
	local extents = (vehicle :: Model):GetExtentsSize()
	local way: Way? = if speed > 0.1
		then {
			at = pos,
			dir = velocity.Unit,
			radius = math.max(math.min(extents.X, extents.Z), extents.Y) / 2 + CRUMBLE.ClearStuds,
		}
		else nil
	BuildingService.breakAt(pos, radius, velocity.Unit * speed, player, way)
end

local function spray(at: Vector3)
	local a = Instance.new("Attachment")
	a.Parent = workspace.Terrain
	a.WorldPosition = at
	local fx = Instance.new("ParticleEmitter")
	fx.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
	fx.Size = NumberSequence.new(0.8, 2.4)
	fx.Transparency = NumberSequence.new(0.2, 1)
	fx.Speed = NumberRange.new(40, 60)
	fx.SpreadAngle = Vector2.new(12, 12)
	fx.Lifetime = NumberRange.new(1, 1.6)
	fx.Acceleration = Vector3.new(0, -70, 0)
	fx.EmissionDirection = Enum.NormalId.Top
	fx.Rate = 120
	fx.Parent = a
	Debris:AddItem(a, Streets.HydrantSpraySeconds)
end

local lastProp: { [Player]: number } = {}

local function onKnockProp(player: Player, prop: unknown, velocity: unknown)
	local folder = propsFolder
	if
		not folder
		or typeof(prop) ~= "Instance"
		or not prop:IsA("Model")
		or prop.Parent ~= folder
		or typeof(velocity) ~= "Vector3"
		or velocity ~= velocity
	then
		return
	end
	local now = os.clock()
	if (lastProp[player] or 0) + 0.03 > now or (propDownUntil[prop] or 0) > now then
		return
	end
	lastProp[player] = now
	local vehicle = VehicleService.of(player)
	local stats = vehicle and VehicleService.stats(vehicle)
	local chassis = vehicle and vehicle.PrimaryPart
	if not (vehicle and stats and chassis) then
		return
	end
	local spm = Vehicles.StudsPerMetre
	local maxStuds = stats.topSpeed
			/ 2.237
			* spm
			* (if Vehicles.has(stats, "Jet") then 1.45 else 1.2)
		+ 10
	local speed = math.min(velocity.Magnitude, maxStuds)
	local pivot = prop:GetPivot().Position
	local body = VehicleService.bodyNear(vehicle, pivot) or chassis
	if (pivot - body.Position).Magnitude > body.Size.Magnitude / 2 + 18 + speed * 0.3 then
		return
	end
	propDownUntil[prop] = now + Streets.PropRebuildSeconds
	local push = (if speed > 0.1 then velocity.Unit * speed else Vector3.zero) * CRUMBLE.PropPush
		+ Vector3.new(0, CRUMBLE.PropLift, 0)
	-- it breaks into a few pieces that fly on every screen; the real one waits, hidden, to be stood back up
	local thrown: { Burst } = {}
	for _, p in prop:GetDescendants() do
		if p:IsA("BasePart") and chunks[p] and not p:GetAttribute("Broken") then
			p:SetAttribute("Broken", true)
			table.insert(thrown, crumble(p, nil, 0, CRUMBLE.PropFly))
			hide(p)
			task.delay(Streets.PropRebuildSeconds, restore, p)
		end
	end
	sendBricks(pivot, thrown, push)
	if prop:GetAttribute("Prop") == "Hydrant" then
		spray(pivot + Vector3.new(0, 1, 0))
	end
	Net.remote("Fx"):FireAllClients("Break", pivot, 3, 4, player.UserId)
end

function BuildingService.start()
	Net.remote("BreakAt").OnServerEvent:Connect(onBreak)
	Net.remote("KnockProp").OnServerEvent:Connect(onKnockProp)
	Players.PlayerRemoving:Connect(function(p)
		lastProp[p] = nil
		lastBreak[p] = nil
	end)
end

return BuildingService
