--!strict
-- One vehicle per player: spawn from the garage, sit the owner in it, hand the driver network ownership,
-- hide closed-cab drivers, step them out beside the vehicle, despawn on leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ground = require(ReplicatedStorage.Shared.Ground)
local Net = require(ReplicatedStorage.Shared.Net)
local PaintRules = require(ReplicatedStorage.Shared.Rules.Paints)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Data = require(script.Parent.Data)
local RateLimit = require(script.Parent.RateLimit)
local VehicleBuilder = require(script.Parent.VehicleBuilder)

local VehicleService = {}

local LEVEL_RATE = 6
local folder = Instance.new("Folder")
folder.Name = "Vehicles"
folder.Parent = workspace

local owned: { [Player]: Model } = {}
local cooldownUntil: { [Player]: number } = {}
local spawnPoints: { Vector3 } = {}
local spawnListeners: { (Player, string) -> () } = {}

-- the vehicle's collider nearest a point: the chassis, or its trailer's (for hit range checks)
function VehicleService.bodyNear(vehicle: Model, pos: Vector3): BasePart?
	local best = vehicle.PrimaryPart
	local trailer = vehicle:FindFirstChild("Trailer") :: Model?
	local other = trailer and trailer.PrimaryPart
	if best and other and (other.Position - pos).Magnitude < (best.Position - pos).Magnitude then
		best = other
	end
	return best
end

-- called with the player and vehicle id after every spawn
function VehicleService.onSpawn(listener: (Player, string) -> ())
	table.insert(spawnListeners, listener)
end

function VehicleService.of(player: Player): Model?
	local m = owned[player]
	if m and m.Parent then
		return m
	end
	return nil
end

function VehicleService.ownerOf(model: Model): Player?
	for p, m in owned do
		if m == model then
			return p
		end
	end
	return nil
end

function VehicleService.stats(model: Model): Vehicles.Vehicle?
	local id = model:GetAttribute("VehicleId")
	return if typeof(id) == "string" then Vehicles.ById[id] else nil
end

function VehicleService.setSpawnPoints(points: { Vector3 })
	spawnPoints = points
end

function VehicleService.setCooldown(player: Player, seconds: number)
	cooldownUntil[player] = os.clock() + seconds
	player:SetAttribute("SpawnCooldownUntil", workspace:GetServerTimeNow() + seconds)
end

-- the driver's client simulates the vehicle and its trailer together
local function own(model: Model, who: Player?)
	local trailer = model:FindFirstChild("Trailer") :: Model?
	for _, part in { model.PrimaryPart, trailer and trailer.PrimaryPart } do
		if part then
			part:SetNetworkOwner(who)
		end
	end
end

local function setHidden(character: Model, hidden: boolean)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			if hidden then
				if d:GetAttribute("ShownT") == nil then
					d:SetAttribute("ShownT", d.Transparency)
				end
				d.Transparency = 1
			else
				local t = d:GetAttribute("ShownT")
				if typeof(t) == "number" then
					d.Transparency = t
					d:SetAttribute("ShownT", nil)
				end
			end
		end
	end
end

function VehicleService.despawn(player: Player)
	local m = owned[player]
	owned[player] = nil
	player:SetAttribute("VehicleId", nil)
	if m then
		local seat = m:FindFirstChild("DriverSeat") :: VehicleSeat?
		local occupant = seat and seat.Occupant
		m:SetAttribute("Despawning", true)
		if occupant then
			occupant.Sit = false
		end
		m:Destroy()
	end
end

local function blocked(cf: CFrame, size: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.CollisionGroup = "Vehicles"
	local parts = workspace:GetPartBoundsInBox(
		cf * CFrame.new(0, size.Y / 2 + 1, 0),
		size * Vector3.new(1.1, 0.9, 1.1),
		params
	)
	for _, p in parts do
		if p.CanCollide then
			return true
		end
	end
	return false
end

local function ground(pos: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 10, 0), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position else pos - Vector3.new(0, 3, 0)
end

function VehicleService.spawn(player: Player, id: string): boolean
	local stats = Vehicles.ById[id]
	local profile = Data.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if
		not (stats and profile and profile.owned[id] and humanoid and root and humanoid.Health > 0)
	then
		return false
	end
	if (cooldownUntil[player] or 0) > os.clock() then
		Net.remote("Popup"):FireClient(player, "Your last ride is still smoking...", "info")
		return false
	end
	if humanoid.SeatPart then
		humanoid.Sit = false
		task.wait()
	end
	VehicleService.despawn(player)

	local model = VehicleBuilder.build(id)
	VehicleBuilder.paint(model, PaintRules.colour(id, profile.paint[id]))
	local _, size = model:GetBoundingBox()
	local ignore = { character, folder }
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local at = ground(root.Position, ignore)
	local cf = CFrame.lookAt(at, at + look)
	if blocked(cf, size, ignore) then
		local best, bestD = nil, math.huge
		for _, p in spawnPoints do
			local d = (p - root.Position).Magnitude
			if d < bestD and not blocked(CFrame.new(p), size, ignore) then
				best, bestD = p, d
			end
		end
		if best then
			cf = CFrame.lookAt(best, best + look)
		end
	end
	model:PivotTo(cf + Vector3.new(0, 0.4, 0))
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("SpawnedAt", workspace:GetServerTimeNow())
	model.Parent = folder
	owned[player] = model
	player:SetAttribute("VehicleId", id)
	for _, listener in spawnListeners do
		task.spawn(listener, player, id)
	end

	local chassis = model.PrimaryPart :: BasePart
	local seat = model:FindFirstChild("DriverSeat") :: VehicleSeat
	local turn = chassis:FindFirstChild("Turn") :: AngularVelocity
	local drive = chassis:FindFirstChild("Drive") :: LinearVelocity

	-- the owner gets back in with a prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Drive"
	prompt.ObjectText = stats.name
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = math.max(12, size.Z * 0.6)
	prompt.RequiresLineOfSight = false
	prompt.Parent = chassis
	prompt.Triggered:Connect(function(who)
		local h = who.Character and who.Character:FindFirstChildOfClass("Humanoid")
		if who == player and h and not h.SeatPart and seat.Occupant == nil then
			seat:Sit(h)
		end
	end)

	local driver: Humanoid? = nil
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local now = seat.Occupant
		if now then
			local who = Players:GetPlayerFromCharacter(now.Parent)
			if who ~= player then
				now.Sit = false -- only the owner drives
				return
			end
			driver = now
			prompt.Enabled = false
			pcall(function()
				own(model, player)
			end)
			if not stats.showDriver then
				setHidden(now.Parent :: Model, true)
			end
		else
			local left = driver
			driver = nil
			prompt.Enabled = true
			drive.Enabled = true
			turn.Enabled = true
			drive.VectorVelocity = Vector3.zero
			pcall(function()
				own(model, nil)
			end)
			local ch = left and left.Parent :: Model?
			if ch then
				setHidden(ch, false)
				local r = ch:FindFirstChild("HumanoidRootPart") :: BasePart?
				-- a replaced or exploded vehicle doesn't step its driver out beside it
				if r and left and left.Health > 0 and not model:GetAttribute("Despawning") then
					local exit = chassis.CFrame * CFrame.new(-(size.X / 2 + 3), 2, 0)
					task.defer(function()
						r.AssemblyLinearVelocity = Vector3.zero
						r.CFrame = CFrame.lookAt(
							exit.Position,
							exit.Position + chassis.CFrame.LookVector * Vector3.new(1, 0, 1)
						)
					end)
				end
			end
		end
	end)

	-- parked: hold still and rest on the ground (the driver's client does this while driving)
	local groundUp, groundAt = Vector3.yAxis, 0
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	groundParams.CollisionGroup = "Vehicles"
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not model.Parent then
			conn:Disconnect()
			return
		end
		-- fell out of the world: put it back on the nearest road
		if chassis.Position.Y < -40 then
			local best, bestD = chassis.Position, math.huge
			for _, p in spawnPoints do
				local d = (p - chassis.Position * Vector3.new(1, 0, 1)).Magnitude
				if d < bestD then
					best, bestD = p, d
				end
			end
			pcall(function()
				own(model, nil)
			end)
			model:PivotTo(
				CFrame.lookAt(
					best + Vector3.new(0, 3, 0),
					best + Vector3.new(0, 3, 0) + chassis.CFrame.LookVector * Vector3.new(1, 0, 1)
				)
			)
			chassis.AssemblyLinearVelocity = Vector3.zero
			task.delay(0.3, function()
				if driver and model.Parent then
					pcall(function()
						own(model, player)
					end)
				end
			end)
		end
		if seat.Occupant == nil and turn.Enabled then
			-- rest on the slope under it; nothing under it, level to world up
			local now = os.clock()
			if now - groundAt > Vehicles.Ground.parkedEvery then
				groundAt = now
				groundParams.FilterDescendantsInstances = { model }
				groundUp = Ground.normal(chassis, groundParams) or Vector3.yAxis
			end
			turn.AngularVelocity = chassis.CFrame.UpVector:Cross(groundUp) * LEVEL_RATE
		end
	end)

	-- a moment after spawning, once any old seat has let go
	task.delay(0.15, function()
		if humanoid.Health > 0 and model.Parent and not humanoid.SeatPart then
			humanoid.Jump = false
			seat:Sit(humanoid)
		end
	end)
	return true
end

function VehicleService.start()
	Net.remote("SpawnVehicle").OnServerEvent:Connect(function(player, id)
		if typeof(id) == "string" and RateLimit.allow(player, "spawn", 1) then
			VehicleService.spawn(player, id)
		end
	end)
	Net.remote("DespawnVehicle").OnServerEvent:Connect(function(player)
		if not RateLimit.allow(player, "despawn", 1) then
			return
		end
		VehicleService.despawn(player)
	end)
	-- the driver already heard their own horn; everyone else plays it from the vehicle
	Net.remote("Horn").OnServerEvent:Connect(function(player)
		local vehicle = VehicleService.of(player)
		if not vehicle or not RateLimit.allow(player, "horn", Vehicles.HornCooldown * 0.8) then
			return
		end
		for _, other in Players:GetPlayers() do
			if other ~= player then
				Net.remote("Horn"):FireClient(other, vehicle)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		VehicleService.despawn(player)
		cooldownUntil[player] = nil
	end)
	local function onCharacter(character: Model)
		-- vehicles pass through players
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = "Characters"
			end
		end
		character.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				d.CollisionGroup = "Characters"
			end
		end)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
end

return VehicleService
