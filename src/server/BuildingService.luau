--!strict
-- Destructible buildings: every building is anchored chunks (wall panels, windows, slabs, columns).
-- A hit or a blast unanchors the chunks in a radius and drops what stood on them, up to the next floor slab;
-- parts marked Fixed (office floor slabs and roofs) are structure and never break. Debris fades and the
-- building puts itself back together later.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Impact = require(ReplicatedStorage.Shared.Rules.Impact)
local Net = require(ReplicatedStorage.Shared.Net)
local Smash = require(ReplicatedStorage.Shared.Config.Smash)
local Streets = require(ReplicatedStorage.Shared.Config.Streets)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local World = require(ReplicatedStorage.Shared.Config.World)
local VehicleService = require(script.Parent.VehicleService)

local BuildingService = {}
local CFG = World.Debris

type Chunk = { cf: CFrame, transparency: number, glass: boolean }
local chunks: { [BasePart]: Chunk } = {}
local loose: { { part: BasePart, at: number } } = {}
local buildingsFolder: Folder? = nil
local propsFolder: Folder? = nil
local propDownUntil: { [Model]: number } = {}
local lastBreak: { [Player]: number } = {}
local random = Random.new()

function BuildingService.register(folder: Folder)
	buildingsFolder = folder
	for _, p in folder:GetDescendants() do
		if p:IsA("BasePart") and not p:GetAttribute("Fixed") then
			chunks[p] = {
				cf = p.CFrame,
				transparency = p.Transparency,
				glass = p:GetAttribute("Glass") == true,
			}
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

local function restore(part: BasePart)
	local c = chunks[part]
	if not c or not part.Parent then
		return
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

local function loosen(part: BasePart, push: Vector3)
	if part:GetAttribute("Broken") then
		return
	end
	part:SetAttribute("Broken", true)
	local c = chunks[part]
	if c and c.glass then
		shatter(part)
		hide(part)
	else
		part.CollisionGroup = "Debris"
		part.Anchored = false
		part.AssemblyLinearVelocity = push
		part.AssemblyAngularVelocity = Vector3.new(
			random:NextNumber(-3, 3),
			random:NextNumber(-3, 3),
			random:NextNumber(-3, 3)
		)
		pcall(function()
			part:SetNetworkOwner(nil)
		end)
		table.insert(loose, { part = part, at = os.clock() })
	end
	task.delay(CFG.RebuildSeconds + random:NextNumber(0, 8), restore, part)
end

local breakListeners: { (Player, number) -> () } = {}

-- called with the player and how many pieces they broke
function BuildingService.onBreak(listener: (Player, number) -> ())
	table.insert(breakListeners, listener)
end

-- break everything within radius of pos; push is the hitter's velocity (studs/s); returns the pieces broken
function BuildingService.breakAt(
	pos: Vector3,
	radius: number,
	push: Vector3,
	player: Player?
): number
	if not buildingsFolder or radius <= 0 then
		return 0
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { buildingsFolder }
	local hit = workspace:GetPartBoundsInRadius(pos, radius, params)
	local count = 0
	for _, p in hit do
		if p.Anchored and chunks[p] and not p:GetAttribute("Broken") then
			local away = p.Position - pos
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.yAxis
			loosen(
				p,
				push * 0.55
					+ away * random:NextNumber(15, 35)
					+ Vector3.new(0, random:NextNumber(5, 25), 0)
			)
			count += 1
		end
	end
	if count == 0 then
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
	local dropped = 0
	for _, p in above do
		if dropped > 260 then
			break
		end
		if
			p.Anchored
			and chunks[p]
			and not p:GetAttribute("Broken")
			and p.Position.Y > pos.Y + 2
			and p.Position.Y < ceiling
		then
			loosen(p, Vector3.new(random:NextNumber(-4, 4), 0, random:NextNumber(-4, 4)))
			dropped += 1
		end
	end
	Net.remote("Fx")
		:FireAllClients("Break", pos, count + dropped, radius, if player then player.UserId else 0)
	if player then
		for _, listener in breakListeners do
			task.spawn(listener, player, count + dropped)
		end
	end
	return count + dropped
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
	local radius = Impact.smashRadius(stats.weight, speed / spm, Smash, stats.maxBreak)
	BuildingService.breakAt(pos, radius, velocity.Unit * speed, player)
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
	local push = (if speed > 0.1 then velocity.Unit * speed else Vector3.zero) * 0.8
	for _, p in prop:GetDescendants() do
		if p:IsA("BasePart") and chunks[p] and not p:GetAttribute("Broken") then
			p:SetAttribute("Broken", true)
			p.CollisionGroup = "Debris"
			p.Anchored = false
			p.AssemblyLinearVelocity = push
				+ Vector3.new(
					random:NextNumber(-6, 6),
					random:NextNumber(18, 34),
					random:NextNumber(-6, 6)
				)
			p.AssemblyAngularVelocity = Vector3.new(
				random:NextNumber(-6, 6),
				random:NextNumber(-6, 6),
				random:NextNumber(-6, 6)
			)
			pcall(function()
				p:SetNetworkOwner(nil)
			end)
			task.delay(Streets.PropRebuildSeconds, restore, p)
		end
	end
	if prop:GetAttribute("Prop") == "Hydrant" then
		spray(pivot + Vector3.new(0, 1, 0))
	end
	Net.remote("Fx"):FireAllClients("Break", pivot, 3, 4, player.UserId)
end

function BuildingService.start()
	Net.remote("BreakAt").OnServerEvent:Connect(onBreak)
	Net.remote("KnockProp").OnServerEvent:Connect(onKnockProp)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		lastProp[p] = nil
		lastBreak[p] = nil
	end)
	-- debris: fade out after a while; over budget, the oldest goes first
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			local over = #loose - CFG.MaxLoose
			for i = #loose, 1, -1 do
				local e = loose[i]
				if now - e.at > 14 or i <= over then
					if e.part.Parent and e.part:GetAttribute("Broken") then
						hide(e.part)
					end
					table.remove(loose, i)
				end
			end
		end
	end)
end

return BuildingService
