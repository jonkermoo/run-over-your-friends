--!strict
-- Car mastery: points for what a player does in a car go to that car (Config/Upgrades Points), saved per car.
-- People knocked down, holes in buildings and landed jumps come in through the services' listeners; whole
-- buildings, traffic wrecks and player hits call MasteryService.add where they pay; driving counts studs.
-- The client hears every gain (Net "Mastery") and shows it next to the hit cash; a new level opens upgrades.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Upgrades)
local Loc = require(ReplicatedStorage.Shared.Loc)
local Net = require(ReplicatedStorage.Shared.Net)
local Rules = require(ReplicatedStorage.Shared.Rules.Upgrades)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Data = require(script.Parent.Data)
local VehicleService = require(script.Parent.VehicleService)

local MasteryService = {}

export type Kind = "Npc" | "Player" | "Traffic" | "Smash" | "Collapse" | "Stunt"

local studs: { [Player]: number } = {}
local lastAt: { [Player]: Vector3 } = {}

local function give(player: Player, points: number)
	if points <= 0 then
		return
	end
	local profile = Data.get(player)
	local car = VehicleService.of(player)
	local id = car and car:GetAttribute("VehicleId")
	if not profile or typeof(id) ~= "string" or not profile.owned[id] then
		return
	end
	local before = profile.mastery[id] or 0
	local after = before + points
	profile.mastery[id] = after
	local oldLevel, newLevel = Rules.level(before), Rules.level(after)
	Data.changed(player)
	Net.remote("Mastery")
		:FireClient(player, id, points, after, if newLevel > oldLevel then newLevel else nil)
	if newLevel > oldLevel then
		-- a new level: the confetti card names what it opened (an upgrade at some levels, a decal at each)
		local decal = Config.Decals[newLevel]
		local decalName = if decal.id == "Signature"
			then Config.Signature[id] or decal.name
			else decal.name
		local upgradeAt = table.find(Config.UpgradeLevel, newLevel)
		local up = upgradeAt and Rules.get(id, upgradeAt)
		local row = Vehicles.ById[id]
		Net.remote("Celebrate"):FireClient(
			player,
			Loc.msg("MasteryLevel", { car = Loc.src(string.upper(row.name)), n = newLevel }),
			if up
				then Loc.msg("MasteryOpensBoth", {
					up = Loc.src(string.upper(up.name)),
					decal = Loc.src(string.upper(decalName)),
				})
				else Loc.msg("MasteryOpensDecal", { decal = Loc.src(string.upper(decalName)) })
		)
	end
end

-- points for one action in the car the player is driving
function MasteryService.add(player: Player, kind: Kind)
	give(player, (Config.Points :: any)[kind] or 0)
end

function MasteryService.start()
	local NpcService = require(script.Parent.NpcService) :: any
	local BuildingService = require(script.Parent.BuildingService) :: any
	local StuntService = require(script.Parent.StuntService) :: any
	NpcService.onKnock(function(player: Player)
		MasteryService.add(player, "Npc")
	end)
	BuildingService.onBreak(function(player: Player, count: number)
		if count > 0 then
			MasteryService.add(player, "Smash")
		end
	end)
	StuntService.onStunt(function(player: Player, kind: string)
		if kind == "Jumps" then
			MasteryService.add(player, "Stunt")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		studs[player] = nil
		lastAt[player] = nil
	end)
	-- driving: studs covered in the seat, a point per Config StudsPerPoint
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < Config.Points.DriveEvery then
			return
		end
		acc = 0
		for _, player in Players:GetPlayers() do
			local car = VehicleService.of(player)
			local chassis = car and car.PrimaryPart
			local seat = car and car:FindFirstChild("DriverSeat") :: VehicleSeat?
			if not (chassis and seat and seat.Occupant) then
				lastAt[player] = nil
				continue
			end
			local pos = chassis.Position
			local was = lastAt[player]
			lastAt[player] = pos
			if was then
				local step = (pos - was).Magnitude
				if step < Config.Points.MaxDriveStep then
					local pts, left = Rules.drivePoints((studs[player] or 0) + step)
					studs[player] = left
					give(player, pts)
				end
			end
		end
	end)
end

return MasteryService
