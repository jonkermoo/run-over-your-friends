--!strict
-- One vehicle per player: spawn from the garage, sit the owner in it, hand the driver network ownership,
-- hide closed-cab drivers, step them out beside the vehicle, despawn on leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ground = require(ReplicatedStorage.Shared.Ground)
local Net = require(ReplicatedStorage.Shared.Net)
local PaintRules = require(ReplicatedStorage.Shared.Rules.Paints)
local RiderRules = require(ReplicatedStorage.Shared.Rules.Riders)
local RidersConfig = require(ReplicatedStorage.Shared.Config.Riders)
local UpgradeRules = require(ReplicatedStorage.Shared.Rules.Upgrades)
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
local trialCar: { [Player]: string } = {} -- a car the player may drive without owning it (server/TrialService)
-- passengers: who each rider seat was given to (only they may sit there), and server friend checks
local seatedFor: { [Seat]: Player } = {}
local friendCache: { [string]: { yes: boolean, at: number } } = {}

-- let the player spawn this car without owning it (a free trial), or nil to stop
function VehicleService.setTrial(player: Player, id: string?)
	trialCar[player] = id
end

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

-- the vehicle's row with its switched-on mastery upgrades (the model's Upgrades attribute) applied
function VehicleService.stats(model: Model): Vehicles.Vehicle?
	local id = model:GetAttribute("VehicleId")
	local row = if typeof(id) == "string" then Vehicles.ById[id] else nil
	return if row
		then UpgradeRules.stats(row, UpgradeRules.decode(model:GetAttribute("Upgrades")))
		else nil
end

-- rebuild the player's car where they are (new mastery upgrades fitted), with them back in it
function VehicleService.refit(player: Player)
	local model = owned[player]
	local id = model and model:GetAttribute("VehicleId")
	if typeof(id) == "string" then
		VehicleService.spawn(player, id)
	end
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

-- the rider seats of a vehicle, in seat order
local function riderSeats(model: Model): { Seat }
	local out = {}
	for i = 1, 8 do
		local s = model:FindFirstChild("RiderSeat" .. i)
		if not (s and s:IsA("Seat")) then
			break
		end
		table.insert(out, s)
	end
	return out
end

-- the players riding in a vehicle, in seat order
function VehicleService.riders(model: Model): { Player }
	local out = {}
	for _, s in riderSeats(model) do
		local who = s.Occupant and Players:GetPlayerFromCharacter(s.Occupant.Parent)
		if who then
			table.insert(out, who)
		end
	end
	return out
end

-- stand a rider up and put them beside the vehicle, on their seat's side
local function stepOut(model: Model, seat: Seat, humanoid: Humanoid)
	local chassis = model.PrimaryPart
	local ch = humanoid.Parent
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	humanoid.Sit = false
	if not (chassis and root and humanoid.Health > 0) then
		return
	end
	local _, size = model:GetBoundingBox()
	local x = seat:GetAttribute("SeatX")
	local side = RiderRules.exitSide(if typeof(x) == "number" then x else 1)
	local along = chassis.CFrame:PointToObjectSpace(seat.Position).Z
	local exit = chassis.CFrame * CFrame.new(side * (size.X / 2 + RidersConfig.ExitGap), 2, along)
	local look = chassis.CFrame.LookVector * Vector3.new(1, 0, 1)
	-- the seat's weld outlives Sit = false for a moment when the server stands them up (a setting change):
	-- moving them while it holds would drag the whole car along, so cut it. And the rider's own client owns
	-- their character: a move made before it has seen them unseated is overwritten by where it still has
	-- them (left standing in the seat spot), so wait for SeatPart to clear, then move them
	for _, w in seat:GetChildren() do
		if w:IsA("Weld") and w.Part1 and ch and w.Part1:IsDescendantOf(ch) then
			w:Destroy()
		end
	end
	task.spawn(function()
		local t = os.clock()
		while humanoid.SeatPart and os.clock() - t < 1 do
			task.wait()
		end
		task.wait()
		if root.Parent and humanoid.Health > 0 and not humanoid.SeatPart then
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.lookAt(exit.Position, exit.Position + look)
		end
	end)
end

-- take the car away; its riders step out beside it, unless `keepRiders` (a swap or refit), when they're
-- stood up and handed back to be seated in the next car
function VehicleService.despawn(player: Player, keepRiders: boolean?): { Player }
	local m = owned[player]
	owned[player] = nil
	player:SetAttribute("VehicleId", nil)
	local kept = {}
	if m then
		local seat = m:FindFirstChild("DriverSeat") :: VehicleSeat?
		local occupant = seat and seat.Occupant
		m:SetAttribute("Despawning", true)
		if occupant then
			occupant.Sit = false
		end
		for _, s in riderSeats(m) do
			local h = s.Occupant
			local who = h and Players:GetPlayerFromCharacter(h.Parent)
			if h and who then
				if keepRiders then
					table.insert(kept, who)
					h.Sit = false
				else
					stepOut(m, s, h)
				end
			end
			seatedFor[s] = nil
		end
		m:Destroy()
	end
	return kept
end

-- is `who` friends with `owner` (asked of Roblox, cached for a while)
local function friends(who: Player, owner: Player): boolean
	local key = who.UserId .. ":" .. owner.UserId
	local c = friendCache[key]
	if c and os.clock() - c.at < RidersConfig.FriendCache then
		return c.yes
	end
	local ok, yes = pcall(function()
		return who:IsFriendsWith(owner.UserId)
	end)
	local result = ok and yes == true
	friendCache[key] = { yes = result, at = os.clock() }
	return result
end

local function modeOf(owner: Player): string
	return RiderRules.mode(owner:GetAttribute("RideMode"), RidersConfig)
end

local function mayRide(who: Player, owner: Player): boolean
	local mode = modeOf(owner)
	local friend = mode == "Friends" and friends(who, owner)
	return RiderRules.allowed(mode, who == owner, friend)
end

-- seat a player in the vehicle's free rider seat nearest them; false if none is free or they may not ride
local function seatRider(model: Model, owner: Player, who: Player): boolean
	local ch = who.Character
	local h = ch and ch:FindFirstChildOfClass("Humanoid")
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (h and root and h.Health > 0) or h.SeatPart or model:GetAttribute("Despawning") then
		return false
	end
	if not mayRide(who, owner) then
		return false
	end
	local seats = riderSeats(model)
	local list = {}
	for _, s in seats do
		table.insert(list, { pos = s.Position, taken = s.Occupant ~= nil or seatedFor[s] ~= nil })
	end
	local i = RiderRules.nearestFree(list, root.Position)
	if not i then
		return false
	end
	local seat = seats[i]
	seatedFor[seat] = who
	seat:Sit(h)
	task.delay(1, function()
		-- the sit never took (they died or jumped first): free the seat again
		if seatedFor[seat] == who and seat.Occupant ~= h then
			seatedFor[seat] = nil
		end
	end)
	return true
end

local function blocked(cf: CFrame, size: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.CollisionGroup = "CarBodies" -- the world and other players' cars, not people
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
	-- a trial car (not owned) comes stock: factory paint, no upgrades, no decal, and is marked Trial
	local trial = profile ~= nil and not profile.owned[id] and trialCar[player] == id
	if
		not (
			stats
			and profile
			and (profile.owned[id] or trial)
			and humanoid
			and root
			and humanoid.Health > 0
		)
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
	local riders = VehicleService.despawn(player, true)

	local model =
		VehicleBuilder.build(id, if trial then {} else UpgradeRules.onList(profile.upgrades[id]))
	-- the driver's own car never streams out under them; everyone else gets it whole (like Atomic)
	model.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	model:AddPersistentPlayer(player)
	local paint = PaintRules.shown(
		if trial then nil else profile.paint[id],
		player:GetAttribute("PassVIP") == true and not trial
	)
	VehicleBuilder.paint(model, PaintRules.colour(id, paint), PaintRules.material(paint))
	VehicleBuilder.decal(model, if trial then nil else profile.decal[id])
	if trial then
		model:SetAttribute("Trial", true)
	end
	local _, size = model:GetBoundingBox()
	local ignore = { character, folder }
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local at = ground(root.Position, ignore)
	local cf = CFrame.lookAt(at, at + look)
	-- a long car whose back end would hit something behind you (the spawn plaza's tower) comes out further
	-- ahead along the way you face, before trying the nearest road
	for _, share in { 0.25, 0.5 } do
		if not blocked(cf, size, ignore) then
			break
		end
		local ahead = ground(root.Position + look * size.Z * share, ignore)
		local moved = CFrame.lookAt(ahead, ahead + look)
		if not blocked(moved, size, ignore) then
			cf = moved
		end
	end
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

	-- the owner gets back in with a prompt (client/Riding shows it to the owner only, while Open)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrivePrompt"
	prompt:SetAttribute("Open", true)
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

	-- everyone else rides along (client/Riding shows it to the others, while Open)
	local riderSeatList = riderSeats(model)
	local ride: ProximityPrompt? = nil
	if #riderSeatList > 0 then
		local r = Instance.new("ProximityPrompt")
		r.Name = "RidePrompt"
		r.ActionText = "Ride"
		r.ObjectText = player.DisplayName .. "'s " .. stats.name
		r.KeyboardKeyCode = Enum.KeyCode.F
		r.HoldDuration = 0
		r.MaxActivationDistance = math.max(RidersConfig.PromptRange, size.Z * 0.6)
		r.RequiresLineOfSight = false
		r.Parent = chassis
		r.Triggered:Connect(function(who)
			if who == player or not RateLimit.allow(who, "ride", 0.5) then
				return
			end
			if not mayRide(who, player) then
				Net.remote("Popup"):FireClient(
					who,
					if modeOf(player) == "Friends"
						then "Only " .. player.DisplayName .. "'s friends can ride"
						else player.DisplayName .. " isn't taking riders",
					"info"
				)
				return
			end
			seatRider(model, player, who)
		end)
		ride = r
	end
	local function updateRide()
		local mode = modeOf(player)
		model:SetAttribute("RideMode", mode)
		if ride then
			local free = false
			for _, s in riderSeatList do
				if s.Occupant == nil and seatedFor[s] == nil then
					free = true
				end
			end
			ride:SetAttribute("Open", free and mode ~= "Nobody")
		end
	end
	updateRide()

	-- only the owner sits: a seat holds whoever its SeatWeld holds, and Sit = false can't undo that weld
	-- (seat:Sit even seats a crowd NPC whose Seated state is off), so any weld to someone else is cut.
	-- Occupant changes before the weld is made, so this watches the welds themselves.
	-- the same holds for each rider seat and the player it was given to
	local function guard(onSeat: BasePart, whose: () -> Player?): (Instance) -> ()
		return function(w: Instance)
			if not w:IsA("Weld") then
				return
			end
			task.defer(function()
				local part = w.Part1
				local who = whose()
				local mine = who and who.Character
				if w.Parent == onSeat and part and not (mine and part:IsDescendantOf(mine)) then
					w:Destroy()
					-- the cut weld leaves SeatPart stuck on (Sit is already false), and Bodies never hits a
					-- humanoid with a SeatPart: sitting it for a frame and standing it again clears it
					local body = part.Parent
					local h = body and body:FindFirstChildOfClass("Humanoid")
					task.wait()
					if h and h.Parent and h.SeatPart == onSeat then
						h.Sit = true
						task.wait()
						h.Sit = false
					end
				end
			end)
		end
	end
	seat.ChildAdded:Connect(guard(seat, function()
		return player
	end))

	-- riders: getting out (jumping) steps them out on their seat's side
	for _, s in riderSeatList do
		s.ChildAdded:Connect(guard(s, function()
			return seatedFor[s]
		end))
		local rider: Humanoid? = nil
		s:GetPropertyChangedSignal("Occupant"):Connect(function()
			local now = s.Occupant
			if now then
				local who = Players:GetPlayerFromCharacter(now.Parent)
				if who and who == seatedFor[s] then
					rider = now
					-- the driver's client keeps simulating the car with a rider welded on
					if seat.Occupant then
						pcall(function()
							own(model, player)
						end)
					end
				end
			else
				local left = rider
				rider = nil
				seatedFor[s] = nil
				if left and left.Parent and not model:GetAttribute("Despawning") then
					stepOut(model, s, left)
				end
			end
			updateRide()
		end)
	end
	-- the owner changed who may ride: anyone who no longer may gets out
	local modeConn = player:GetAttributeChangedSignal("RideMode"):Connect(function()
		for _, s in riderSeatList do
			local h = s.Occupant
			local who = h and Players:GetPlayerFromCharacter(h.Parent)
			if h and who and not mayRide(who, player) then
				Net.remote("Popup")
					:FireClient(who, player.DisplayName .. " changed who can ride", "info")
				h.Sit = false
			end
		end
		updateRide()
	end)
	model.Destroying:Connect(function()
		modeConn:Disconnect()
	end)

	local driver: Humanoid? = nil
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local now = seat.Occupant
		if now then
			local who = Players:GetPlayerFromCharacter(now.Parent)
			if who ~= player then
				return -- only the owner drives: unseat cuts the weld and stands them up
			end
			driver = now
			prompt:SetAttribute("Open", false)
			pcall(function()
				own(model, player)
			end)
			if not stats.showDriver then
				setHidden(now.Parent :: Model, true)
			end
		else
			local left = driver
			driver = nil
			prompt:SetAttribute("Open", true)
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
	local groundUp, groundAt, tippedAt = Vector3.yAxis, 0, -math.huge
	local fullTorque = turn.MaxTorque
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
				local n, balanced = Ground.probe(chassis, groundParams)
				groundUp = n or Vector3.yAxis
				if n and not balanced then
					tippedAt = now
				end
			end
			if now - tippedAt < Vehicles.Balance.airFree then
				-- left hanging over an edge: let gravity tip it off, as the driver's client does
				local w = chassis.AssemblyAngularVelocity
				turn.AngularVelocity = Vector3.new(w.X, 0, w.Z)
				turn.MaxTorque = Vehicles.Balance.hold
					* chassis.AssemblyMass
					* workspace.Gravity
					* chassis.Size.Z
					/ 2
			else
				turn.AngularVelocity = chassis.CFrame.UpVector:Cross(groundUp) * LEVEL_RATE
				turn.MaxTorque = fullTorque
			end
		end
	end)

	-- a moment after spawning, once any old seat has let go; riders from the car it replaced get back in
	-- (any without a seat here, or no longer allowed, are stood beside it)
	task.delay(0.15, function()
		if humanoid.Health > 0 and model.Parent and not humanoid.SeatPart then
			humanoid.Jump = false
			seat:Sit(humanoid)
		end
		for _, who in riders do
			if who.Parent and model.Parent and not seatRider(model, player, who) then
				local h = who.Character and who.Character:FindFirstChildOfClass("Humanoid")
				local r = who.Character
					and who.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if h and r and h.Health > 0 and not h.SeatPart then
					local exit = chassis.CFrame
						* CFrame.new(size.X / 2 + RidersConfig.ExitGap, 2, 0)
					r.AssemblyLinearVelocity = Vector3.zero
					r.CFrame = CFrame.new(exit.Position)
				end
			end
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
		trialCar[player] = nil
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
