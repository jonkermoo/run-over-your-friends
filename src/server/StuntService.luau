--!strict
-- Stunts: watches every driven car, and when one leaves the ground and comes back down on its wheels, pays
-- for the jump (Rules/Stunts: air time and flat spins; slow vehicles boosted; double in the
-- stunt park). Landing on the roof is a wipeout and pays nothing. Measured here, not on the client: a ray
-- down from the chassis against the car's usual ride height. Jet cars don't score (they can fly), and air
-- right after a player-hit fling doesn't count. A jump needs a real launch (speed and a change of height) and
-- is void past Config MaxAir, so a car that floats or flies up earns nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Stunts)
local Net = require(ReplicatedStorage.Shared.Net)
local Stunts = require(ReplicatedStorage.Shared.Rules.Stunts)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Data = require(script.Parent.Data)
local VehicleService = require(script.Parent.VehicleService)

local StuntService = {}

local NORMAL_GRAVITY = 196.2

type Track = {
	vehicle: Model,
	rest: number?, -- the chassis's height over the ground when sat on its wheels
	up: boolean, -- off the ground right now
	jump: {
		air: number,
		yaw: number,
		void: boolean,
		speed: number, -- m/s across the ground as it left it
		fromY: number, -- chassis height where it left the ground
		hiY: number,
	}?,
	downAt: number, -- when it last touched down (the landing is judged Settle seconds later)
	last: CFrame,
	airLeft: number, -- fractions of a second of air not yet sent to the goals
}
local tracks: { [Player]: Track } = {}

local listeners: { (Player, string, number) -> () } = {}
-- kind: "Air" (whole seconds), "Jumps" (1 per clean landing) or "Stunt" (one jump's pay, for contests)
function StuntService.onStunt(listener: (Player, string, number) -> ())
	table.insert(listeners, listener)
end

local function emit(player: Player, kind: string, amount: number)
	for _, listener in listeners do
		task.spawn(listener, player, kind, amount)
	end
end

local park: Instance? = nil
local function inPark(pos: Vector3): boolean
	park = park or workspace:FindFirstChild("StuntPark", true)
	local centre = park and park:GetAttribute("Centre")
	local size = park and park:GetAttribute("Size")
	if typeof(centre) ~= "Vector3" or typeof(size) ~= "Vector3" then
		return false
	end
	local rel = pos - centre
	return math.abs(rel.X) <= size.X / 2 and math.abs(rel.Z) <= size.Z / 2
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.CollisionGroup = "Vehicles" -- people, debris and other cars don't count as ground

local function clearance(chassis: BasePart, vehicle: Model): number?
	rayParams.FilterDescendantsInstances = { vehicle }
	local hit = workspace:Raycast(chassis.Position, Vector3.new(0, -60, 0), rayParams)
	return hit and (chassis.Position.Y - hit.Position.Y)
end

-- degrees the nose swung round flat between two frames
local function turned(a: CFrame, b: CFrame): number
	local ax, bx = a.LookVector, b.LookVector
	return math.deg(math.atan2(ax.Z, ax.X) - math.atan2(bx.Z, bx.X) + math.pi) % 360 - 180
end

local function land(player: Player, t: Track, chassis: BasePart, stats: Vehicles.Vehicle)
	local j = t.jump
	t.jump = nil
	if not j or j.void then
		return
	end
	local y = chassis.Position.Y
	local result = Stunts.score({
		air = j.air,
		launched = Stunts.launched(j.speed, j.hiY - j.fromY, j.fromY - y, Config),
		yaw = j.yaw,
		upright = chassis.CFrame.UpVector.Y >= Config.Upright,
		gravity = workspace.Gravity / NORMAL_GRAVITY,
		topSpeed = stats.topSpeed,
		inPark = inPark(chassis.Position),
	}, Config)
	if not result.counts then
		return
	end
	if not result.clean then
		Net.remote("Popup"):FireClient(player, "WIPEOUT", "info")
		return
	end
	Data.addMoney(player, result.pay)
	local where = if inPark(chassis.Position) then `  STUNT PARK x{Config.Park}` else ""
	Net.remote("Popup"):FireClient(
		player,
		`{result.label} {string.format("%.1f", result.air)}s  +${result.pay}{where}`,
		"big"
	)
	t.airLeft += result.air
	local whole = math.floor(t.airLeft)
	if whole > 0 then
		t.airLeft -= whole
		emit(player, "Air", whole)
	end
	emit(player, "Jumps", 1)
	emit(player, "Stunt", result.pay)
end

local function step(player: Player, now: number, dt: number)
	local vehicle = VehicleService.of(player)
	local stats = vehicle and VehicleService.stats(vehicle)
	local chassis = vehicle and vehicle.PrimaryPart
	local seat = vehicle and vehicle:FindFirstChild("DriverSeat") :: VehicleSeat?
	if
		not (vehicle and stats and chassis and seat and seat.Occupant)
		or Vehicles.has(stats, "Jet")
	then
		tracks[player] = nil
		return
	end
	local t = tracks[player]
	if not t or t.vehicle ~= vehicle then
		t = { vehicle = vehicle, up = false, downAt = 0, last = chassis.CFrame, airLeft = 0 }
		tracks[player] = t
	end
	local cf = chassis.CFrame
	local c = clearance(chassis, vehicle)
	local rest = t.rest
	local upright = cf.UpVector.Y > 0.8
	-- the ride height: the lowest it sits upright, drifting back up slowly (suspension, a new car)
	if c and upright and not t.up then
		t.rest = if rest == nil or c < rest
			then c
			else rest + (math.min(c, rest + Config.Clearance) - rest) * math.min(1, dt)
		rest = t.rest
	end
	local wasUp = t.up
	t.up = rest ~= nil and (c == nil or c > rest + Config.Clearance)

	if t.up then
		local flungAt = vehicle:GetAttribute("FlungAt")
		local j = t.jump
			or {
				air = 0,
				yaw = 0,
				void = typeof(flungAt) == "number" and now - flungAt < Config.FlungGrace,
				speed = (chassis.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
					/ Vehicles.StudsPerMetre,
				fromY = cf.Position.Y,
				hiY = cf.Position.Y,
			}
		t.jump = j
		j.hiY = math.max(j.hiY, cf.Position.Y)
		j.air += dt
		j.yaw += turned(t.last, cf)
	elseif wasUp then
		t.downAt = now
	elseif t.jump and now - t.downAt >= Config.Settle then
		land(player, t, chassis, stats)
	end
	t.last = cf
end

function StuntService.start()
	Players.PlayerRemoving:Connect(function(p)
		tracks[p] = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(step, player, now, dt)
			if not ok then
				warn("[Stunts]", err)
				tracks[player] = nil
			end
		end
	end)
end

return StuntService
