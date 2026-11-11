--!strict
-- Player hits, free for everyone: hitting a player on foot sends them flying, hitting another player's vehicle
-- flings it. Config/PlayerHits keeps it from wrecking anyone's game: a shield after each hit, short ragdolls,
-- capped launches and weaker repeat hits from the same attacker. Very expensive cars skip most of that.
-- Players and their vehicles have no collision with vehicles (collision groups, set up in init); the
-- driver's client finds the hit by overlap and reports it here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local HitConfig = require(ReplicatedStorage.Shared.Config.PlayerHits)
local HitRules = require(ReplicatedStorage.Shared.Rules.PlayerHits)
local Impact = require(ReplicatedStorage.Shared.Rules.Impact)
local Net = require(ReplicatedStorage.Shared.Net)
local Ragdoll = require(ReplicatedStorage.Shared.Ragdoll)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local SocialService = require(script.Parent.SocialService)
local VehicleService = require(script.Parent.VehicleService)

local PlayerHitService = {}
local random = Random.new()
local lastHit: { [Player]: number } = {}
-- attacker -> victim -> recent hits by that attacker on that victim
local recent: { [Player]: { [Player]: { count: number, at: number } } } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- spawn shield, or the shield left by the victim's last hit (shorter against big cars)
local function protected(victim: Player, terms: HitRules.Terms): boolean
	local spawnUntil = victim:GetAttribute("NoHitUntil")
	if typeof(spawnUntil) == "number" and spawnUntil > now() then
		return true
	end
	local hitAt = victim:GetAttribute("HitAt")
	return typeof(hitAt) == "number" and hitAt + terms.shield > now()
end

-- how much of the full launch this hit does; counts it toward later repeats
local function repeatScale(attacker: Player, victim: Player, price: number): number
	local byAttacker = recent[attacker]
	if not byAttacker then
		byAttacker = {}
		recent[attacker] = byAttacker
	end
	local t = now()
	local entry = byAttacker[victim]
	if not entry or t - entry.at > HitConfig.RepeatWindow then
		entry = { count = 0, at = t }
		byAttacker[victim] = entry
	end
	local scale = HitRules.repeatScale(entry.count, price, HitConfig)
	entry.count += 1
	entry.at = t
	return scale
end

local function spin(): Vector3
	return Vector3.new(random:NextNumber(-6, 6), random:NextNumber(-6, 6), random:NextNumber(-6, 6))
end

-- send a player on foot flying; they get up after `terms.ragdoll` seconds
local function flingCharacter(victim: Player, velocity: Vector3, by: Player, terms: HitRules.Terms)
	local character = victim.Character
	if not character then
		return
	end
	victim:SetAttribute("HitAt", now())
	Ragdoll.enable(character)
	SocialService.launched(by, victim, character:FindFirstChild("HumanoidRootPart") :: BasePart?)
	Net.remote("Fling"):FireClient(victim, "Character", velocity, spin(), terms.ragdoll)
	task.delay(terms.ragdoll, function()
		if character.Parent then
			Ragdoll.disable(character)
		end
	end)
end

-- fling a vehicle: its driver's client applies it, or the server when it's parked
local function flingVehicle(
	model: Model,
	owner: Player?,
	velocity: Vector3,
	by: Player,
	terms: HitRules.Terms
)
	local chassis = model.PrimaryPart
	if not chassis then
		return
	end
	if owner then
		owner:SetAttribute("HitAt", now())
	end
	local seat = model:FindFirstChild("DriverSeat") :: VehicleSeat?
	local driver = seat and seat.Occupant and Players:GetPlayerFromCharacter(seat.Occupant.Parent)
	SocialService.launched(by, driver, chassis) -- only a driven car counts as launching someone
	model:SetAttribute("FlungAt", os.clock()) -- StuntService: air from a fling isn't a stunt
	if driver then
		Net.remote("Fling"):FireClient(driver, "Vehicle", velocity, spin() * 0.6, terms.carRecover)
	else
		local drive = chassis:FindFirstChild("Drive") :: LinearVelocity
		local turn = chassis:FindFirstChild("Turn") :: AngularVelocity
		drive.Enabled = false
		turn.Enabled = false
		chassis.AssemblyLinearVelocity = velocity
		chassis.AssemblyAngularVelocity = spin() * 0.6
		task.delay(terms.parkedRecover, function()
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
	if (lastHit[player] or 0) + 0.2 > t then
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
	local terms = HitRules.terms(stats.price, HitConfig)
	local energy = Impact.energy(stats.weight, speed / spm)
	local dir = (velocity * Vector3.new(1, 0, 1)).Unit
	local victim = Players:GetPlayerFromCharacter(target)
	if victim then
		if victim == player or protected(victim, terms) then
			return
		end
		lastHit[player] = t
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.SeatPart then
			return -- a seated player is hit through their vehicle
		end
		local launch = math.min(Impact.launchSpeed(energy), terms.launchCap)
			* repeatScale(player, victim, stats.price)
		flingCharacter(victim, (dir + Vector3.new(0, 0.7, 0)).Unit * launch, player, terms)
	elseif target.Parent == workspace:FindFirstChild("Vehicles") then
		local owner = VehicleService.ownerOf(target)
		if owner == player or (owner and protected(owner, terms)) then
			return
		end
		lastHit[player] = t
		local other = VehicleService.stats(target)
		local ratio = math.clamp(stats.weight / (if other then other.weight else 1500), 0.25, 4)
			^ 0.5
		local launch = math.min(
			Impact.launchSpeed(energy) * ratio,
			HitRules.carLaunchCap(stats.price, HitConfig)
		)
		if owner then
			launch *= repeatScale(player, owner, stats.price)
		end
		flingVehicle(target, owner, (dir + Vector3.new(0, 0.55, 0)).Unit * launch, player, terms)
	end
end

function PlayerHitService.start()
	Net.remote("PlayerHit").OnServerEvent:Connect(onHit)
	local function onPlayer(p: Player)
		p.CharacterAdded:Connect(function()
			p:SetAttribute("NoHitUntil", now() + HitConfig.SpawnShield)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastHit[p] = nil
		recent[p] = nil
		for _, byAttacker in recent do
			byAttacker[p] = nil
		end
	end)
end

return PlayerHitService
