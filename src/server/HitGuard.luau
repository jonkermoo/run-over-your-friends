--!strict
-- Hits are reported by the driver's client, which owns its car's physics. This caps the speed a hit is paid
-- at by what the server itself saw the vehicle do lately, and pays nothing for a while after the vehicle jumps
-- further than it could drive (a teleport). Numbers: Config/HitGuard; rules: Rules/HitGuard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.HitGuard)
local Rules = require(ReplicatedStorage.Shared.Rules.HitGuard)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local VehicleService = require(script.Parent.VehicleService)

local HitGuard = {}

type Track = {
	chassis: BasePart,
	at: Vector3,
	t: number,
	speeds: { { t: number, v: number } }, -- server-side speed samples over the last RecentSeconds
	suspectUntil: number,
}

local tracks: { [Player]: Track } = {}

local function maxFor(stats: Vehicles.Vehicle): number
	return Rules.maxStuds(
		stats.topSpeed,
		Vehicles.has(stats, "Jet"),
		Vehicles.StudsPerMetre,
		Config
	)
end

local function sample(player: Player, now: number)
	local vehicle = VehicleService.of(player)
	local stats = vehicle and VehicleService.stats(vehicle)
	local chassis = vehicle and vehicle.PrimaryPart
	if not (vehicle and stats and chassis) then
		tracks[player] = nil
		return
	end
	local track = tracks[player]
	local pos = chassis.Position
	if not track or track.chassis ~= chassis then
		-- a new vehicle starts a fresh track (spawning one is not a teleport)
		tracks[player] = { chassis = chassis, at = pos, t = now, speeds = {}, suspectUntil = 0 }
		return
	end
	local flat = ((pos - track.at) * Vector3.new(1, 0, 1)).Magnitude
	if Rules.teleported(flat, now - track.t, maxFor(stats), Config) then
		track.suspectUntil = now + Config.SuspectSeconds
	end
	track.at, track.t = pos, now
	table.insert(track.speeds, { t = now, v = chassis.AssemblyLinearVelocity.Magnitude })
	while track.speeds[1] and track.speeds[1].t < now - Config.RecentSeconds do
		table.remove(track.speeds, 1)
	end
end

-- the speed (studs a second) to pay a hit at: the claim capped by the vehicle's limit and by what the server
-- saw it do lately; 0 just after a teleport
function HitGuard.speed(
	player: Player,
	stats: Vehicles.Vehicle,
	chassis: BasePart,
	claimed: number
): number
	local now = os.clock()
	local track = tracks[player]
	local seen = chassis.AssemblyLinearVelocity.Magnitude
	if track and track.chassis == chassis then
		if now < track.suspectUntil then
			return 0
		end
		for _, s in track.speeds do
			seen = math.max(seen, s.v)
		end
	end
	return Rules.speed(claimed, maxFor(stats), seen, Config)
end

function HitGuard.start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < Config.SampleSeconds then
			return
		end
		acc = 0
		local now = os.clock()
		for _, p in Players:GetPlayers() do
			sample(p, now)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		tracks[p] = nil
	end)
end

return HitGuard
