--!strict
-- Wrecker pass: hitting a player sends them flying, hitting another player's vehicle flings it,
-- and self-destruct blows up your own vehicle and everything around it.
-- Without Wrecker, players and their vehicles pass straight through (collision groups, set up in init).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Impact = require(ReplicatedStorage.Shared.Rules.Impact)
local Net = require(ReplicatedStorage.Shared.Net)
local Ragdoll = require(ReplicatedStorage.Shared.Ragdoll)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local BuildingService = require(script.Parent.BuildingService)
local NpcService = require(script.Parent.NpcService)
local Passes = require(script.Parent.Passes)
local VehicleService = require(script.Parent.VehicleService)

local WreckerService = {}
local random = Random.new()
local lastHit: { [Player]: number } = {}
local lastBlast: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function protected(player: Player): boolean
	local t = player:GetAttribute("NoHitUntil")
	return typeof(t) == "number" and t > now()
end

local function protect(player: Player)
	player:SetAttribute("NoHitUntil", now() + Economy.NoHitWindow)
end

local function spin(): Vector3
	return Vector3.new(random:NextNumber(-6, 6), random:NextNumber(-6, 6), random:NextNumber(-6, 6))
end

-- send a player on foot flying (they get up after a moment)
function WreckerService.flingCharacter(victim: Player, velocity: Vector3)
	local character = victim.Character
	if not character then
		return
	end
	protect(victim)
	Ragdoll.enable(character)
	Net.remote("Fling"):FireClient(victim, "Character", velocity, spin())
	task.delay(2.6, function()
		if character.Parent then
			Ragdoll.disable(character)
		end
	end)
end

-- fling a vehicle: its driver's client applies it, or the server when it's parked
function WreckerService.flingVehicle(model: Model, velocity: Vector3)
	local chassis = model.PrimaryPart
	if not chassis then
		return
	end
	local owner = VehicleService.ownerOf(model)
	if owner then
		protect(owner)
	end
	local seat = model:FindFirstChild("DriverSeat") :: VehicleSeat?
	local driver = seat and seat.Occupant and Players:GetPlayerFromCharacter(seat.Occupant.Parent)
	if driver then
		Net.remote("Fling"):FireClient(driver, "Vehicle", velocity, spin() * 0.6)
	else
		local drive = chassis:FindFirstChild("Drive") :: LinearVelocity
		local turn = chassis:FindFirstChild("Turn") :: AngularVelocity
		drive.Enabled = false
		turn.Enabled = false
		chassis.AssemblyLinearVelocity = velocity
		chassis.AssemblyAngularVelocity = spin() * 0.6
		task.delay(2.5, function()
			if chassis.Parent then
				drive.Enabled = true
				turn.Enabled = true
			end
		end)
	end
end

local function onHit(player: Player, target: unknown, velocity: unknown)
	if
		typeof(target) ~= "Instance"
		or not target:IsA("Model")
		or typeof(velocity) ~= "Vector3"
		or velocity ~= velocity
	then
		return
	end
	local t = os.clock()
	if (lastHit[player] or 0) + 0.2 > t or not Passes.has(player, "Wrecker") then
		return
	end
	local vehicle = VehicleService.of(player)
	local stats = vehicle and VehicleService.stats(vehicle)
	local chassis = vehicle and vehicle.PrimaryPart
	if not (vehicle and stats and chassis) or target == vehicle then
		return
	end
	local spm = Vehicles.StudsPerMetre
	local maxStuds = stats.topSpeed
			/ 2.237
			* spm
			* (if Vehicles.has(stats, "Jet") then 1.45 else 1.2)
		+ 10
	local speed = math.min(velocity.Magnitude, maxStuds)
	if speed / spm < Economy.MinHitSpeed then
		return
	end
	local targetPos = target:GetPivot().Position
	if (targetPos - chassis.Position).Magnitude > chassis.Size.Magnitude / 2 + 25 + speed * 0.3 then
		return
	end
	local energy = Impact.energy(stats.weight, speed / spm)
	local dir = (velocity * Vector3.new(1, 0, 1)).Unit
	local victim = Players:GetPlayerFromCharacter(target)
	if victim then
		if victim == player or protected(victim) then
			return
		end
		lastHit[player] = t
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.SeatPart then
			return -- a seated player is hit through their vehicle
		end
		WreckerService.flingCharacter(
			victim,
			(dir + Vector3.new(0, 0.7, 0)).Unit * Impact.launchSpeed(energy)
		)
	elseif target.Parent == workspace:FindFirstChild("Vehicles") then
		local owner = VehicleService.ownerOf(target)
		if owner and protected(owner) then
			return
		end
		lastHit[player] = t
		local other = VehicleService.stats(target)
		local ratio = math.clamp(stats.weight / (if other then other.weight else 1500), 0.25, 4)
			^ 0.5
		local launch = math.min(Impact.launchSpeed(energy) * ratio, 320)
		WreckerService.flingVehicle(target, (dir + Vector3.new(0, 0.55, 0)).Unit * launch)
	end
end

local function wreck(model: Model)
	for _, p in model:GetChildren() do
		if p:IsA("MeshPart") then
			local piece = p:Clone()
			for _, c in piece:GetChildren() do
				c:Destroy()
			end
			piece.TextureID = ""
			piece.Color = Color3.fromRGB(35, 32, 30)
			piece.Anchored = false
			piece.CanCollide = true
			piece.CollisionGroup = "Debris"
			piece.Massless = false
			piece.Parent = workspace
			piece.AssemblyLinearVelocity = Vector3.new(
				random:NextNumber(-30, 30),
				random:NextNumber(40, 80),
				random:NextNumber(-30, 30)
			)
			piece.AssemblyAngularVelocity = spin()
			if p.Name == "Body" then
				local fire = Instance.new("Fire")
				fire.Size = 12
				fire.Heat = 15
				fire.Parent = piece
				local smoke = Instance.new("Smoke")
				smoke.RiseVelocity = 12
				smoke.Size = 6
				smoke.Opacity = 0.35
				smoke.Parent = piece
			end
			Debris:AddItem(piece, 9)
		end
	end
end

local function onSelfDestruct(player: Player)
	local t = os.clock()
	if (lastBlast[player] or 0) + 3 > t or not Passes.has(player, "Wrecker") then
		return
	end
	local vehicle = VehicleService.of(player)
	local stats = vehicle and VehicleService.stats(vehicle)
	local chassis = vehicle and vehicle.PrimaryPart
	if not (vehicle and stats and chassis) then
		return
	end
	lastBlast[player] = t
	local spm = Vehicles.StudsPerMetre
	local pos = chassis.Position
	local speed = chassis.AssemblyLinearVelocity.Magnitude / spm
	local radius = Impact.blastRadius(stats.weight, speed)
	local energy = Impact.energy(math.max(stats.weight, 1500), 30)

	local boom = Instance.new("Explosion")
	boom.Position = pos
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.BlastRadius = radius
	boom.Parent = workspace

	BuildingService.breakAt(pos, radius * 0.75, Vector3.zero)
	local function outward(at: Vector3, power: number): Vector3
		local away = (at - pos) * Vector3.new(1, 0, 1)
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
		return (away + Vector3.new(0, 1.1, 0)).Unit * power
	end
	for _, npc in NpcService.inRadius(pos, radius) do
		NpcService.knock(
			npc,
			outward(npc:GetPivot().Position, Impact.launchSpeed(energy)),
			energy,
			player,
			1
		)
	end
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			other ~= player
			and root
			and humanoid
			and not humanoid.SeatPart
			and not protected(other)
		then
			if (root.Position - pos).Magnitude <= radius then
				WreckerService.flingCharacter(
					other,
					outward(root.Position, Impact.launchSpeed(energy))
				)
			end
		end
	end
	local vehicles = workspace:FindFirstChild("Vehicles")
	if vehicles then
		for _, m in vehicles:GetChildren() do
			if m ~= vehicle and m:IsA("Model") then
				local owner = VehicleService.ownerOf(m)
				local at = m:GetPivot().Position
				if (at - pos).Magnitude <= radius * 1.2 and not (owner and protected(owner)) then
					WreckerService.flingVehicle(m, outward(at, 150))
				end
			end
		end
	end

	-- the driver is thrown sky-high; the vehicle burns
	local seat = vehicle:FindFirstChild("DriverSeat") :: VehicleSeat?
	local humanoid = seat and seat.Occupant
	wreck(vehicle)
	VehicleService.despawn(player)
	VehicleService.setCooldown(player, Economy.SelfDestructCooldown)
	if humanoid then
		task.wait(0.1)
		WreckerService.flingCharacter(
			player,
			Vector3.new(random:NextNumber(-25, 25), 190, random:NextNumber(-25, 25))
		)
	end
end

function WreckerService.start()
	Net.remote("WreckerHit").OnServerEvent:Connect(onHit)
	Net.remote("SelfDestruct").OnServerEvent:Connect(onSelfDestruct)
	local function onPlayer(p: Player)
		p.CharacterAdded:Connect(function()
			protect(p)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastHit[p] = nil
		lastBlast[p] = nil
	end)
end

return WreckerService
