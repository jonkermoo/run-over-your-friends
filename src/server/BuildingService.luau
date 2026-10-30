--!strict
-- Destructible buildings: every building is anchored chunks (wall panels, windows, slabs, columns).
-- A hit or a blast unanchors the chunks in a radius and drops the floors above them; debris fades and
-- the building puts itself back together later.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Impact = require(ReplicatedStorage.Shared.Rules.Impact)
local Net = require(ReplicatedStorage.Shared.Net)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local World = require(ReplicatedStorage.Shared.Config.World)
local VehicleService = require(script.Parent.VehicleService)

local BuildingService = {}
local CFG = World.Debris

type Chunk = { cf: CFrame, transparency: number, glass: boolean }
local chunks: { [BasePart]: Chunk } = {}
local loose: { { part: BasePart, at: number } } = {}
local buildingsFolder: Folder? = nil
local lastBreak: { [Player]: number } = {}
local random = Random.new()

function BuildingService.register(folder: Folder)
	buildingsFolder = folder
	for _, p in folder:GetDescendants() do
		if p:IsA("BasePart") then
			chunks[p] = {
				cf = p.CFrame,
				transparency = p.Transparency,
				glass = p:GetAttribute("Glass") == true,
			}
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

-- break everything within radius of pos; push is the hitter's velocity (studs/s)
function BuildingService.breakAt(pos: Vector3, radius: number, push: Vector3)
	if not buildingsFolder or radius <= 0 then
		return
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
		return
	end
	-- whatever stood on the broken part falls too
	local reach = radius * CFG.ChunkFallReach
	local above = workspace:GetPartBoundsInBox(
		CFrame.new(pos.X, pos.Y + 300, pos.Z),
		Vector3.new(reach * 2, 600, reach * 2),
		params
	)
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
		then
			loosen(p, Vector3.new(random:NextNumber(-4, 4), 0, random:NextNumber(-4, 4)))
			dropped += 1
		end
	end
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
	if not (stats and chassis and stats.breaksBuildings) then
		return
	end
	local spm = Vehicles.StudsPerMetre
	local maxStuds = stats.topSpeed
			/ 2.237
			* spm
			* (if Vehicles.has(stats, "Jet") then 1.45 else 1.2)
		+ 10
	local speed = math.min(velocity.Magnitude, maxStuds)
	if (pos - chassis.Position).Magnitude > chassis.Size.Magnitude / 2 + 16 + speed * 0.3 then
		return
	end
	local energy = Impact.energy(stats.weight, speed / spm)
	BuildingService.breakAt(pos, Impact.breakRadius(energy), velocity.Unit * speed)
end

function BuildingService.start()
	Net.remote("BreakAt").OnServerEvent:Connect(onBreak)
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
