--!strict
-- Teleporting from the city map (client/CityMap, Config/Teleport, Rules/Teleport): a player asks for an area by
-- key; the server checks it (cooldown, alive, not riding in someone else's car, not next to the live event),
-- picks a free landing spot there (several per area, so a group lands apart), streams it in around the player and
-- moves them, or their car with everyone in it. Answers with Teleport (ok, reason).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Teleport)
local World = require(ReplicatedStorage.Shared.Config.World)
local Suburbs = require(ReplicatedStorage.Shared.Config.Suburbs)
local Country = require(ReplicatedStorage.Shared.Config.Country)
local Net = require(ReplicatedStorage.Shared.Net)
local Rules = require(ReplicatedStorage.Shared.Rules.Teleport)
local Analytics = require(script.Parent.Analytics)
local EventService = require(script.Parent.EventService)
local HitGuard = require(script.Parent.HitGuard)
local RateLimit = require(script.Parent.RateLimit)
local VehicleService = require(script.Parent.VehicleService)

local TeleportService = {}

local areas = Rules.areas(Cfg.Places, World.Map, Suburbs.Hoods, Country.Moto.Rect)
local spots: { [string]: { Rules.Spot } } = {}
local readyAt: { [Player]: number } = {}
local moving: { [Player]: boolean } = {}
local random = Random.new()

-- every player's spot and every car's, but the asker's own
local function busy(except: Player): { Rules.Spot }
	local out = {}
	for _, p in Players:GetPlayers() do
		if p ~= except then
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				table.insert(out, { x = root.Position.X, z = root.Position.Z })
			end
			local car = VehicleService.of(p)
			if car then
				local at = car:GetPivot().Position
				table.insert(out, { x = at.X, z = at.Z })
			end
		end
	end
	return out
end

-- the ground under (x, z), past people and cars; nil over water or nothing
local function groundAt(x: number, z: number, ignore: { Instance }): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = false
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), params)
	if not hit or hit.Material == Enum.Material.Water then
		return nil
	end
	return hit.Position
end

local function ignoreList(): { Instance }
	local list: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
		local car = VehicleService.of(p)
		if car then
			table.insert(list, car)
		end
	end
	return list
end

-- is the player sitting in someone else's car (a seat under a model with an OwnerId: VehicleService.spawn)?
local function ridingOther(humanoid: Humanoid, own: Model?): boolean
	local seat = humanoid.SeatPart
	if not seat or (own and seat:IsDescendantOf(own)) then
		return false
	end
	local at: Instance? = seat.Parent
	while at and at ~= workspace do
		if at:IsA("Model") and at:GetAttribute("OwnerId") ~= nil then
			return true
		end
		at = at.Parent
	end
	return false
end

local function answer(player: Player, ok: boolean, reason: string?)
	Net.remote("Teleport"):FireClient(player, ok, reason)
end

local function teleport(player: Player, key: any)
	if moving[player] then
		return
	end
	local area = Rules.find(areas, key)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local car = VehicleService.of(player)
	local ex, ez = nil, nil
	local live = EventService.spot()
	if live then
		ex, ez = live.X, live.Z
	end
	local reason = Rules.refusal({
		known = area ~= nil,
		alive = humanoid ~= nil and root ~= nil and humanoid.Health > 0,
		passenger = humanoid ~= nil and ridingOther(humanoid, car),
		now = os.clock(),
		readyAt = readyAt[player] or 0,
		nearEvent = area ~= nil and Rules.nearEvent(area, ex, ez, Cfg.EventKeepAway),
	})
	if reason or not (area and humanoid and root and character) then
		answer(player, false, reason)
		return
	end
	local inCar = car ~= nil and humanoid.SeatPart ~= nil and humanoid.SeatPart:IsDescendantOf(car)

	local list = spots[area.key] or {}
	if #list == 0 then
		answer(player, false, "Unknown")
		return
	end
	local ignore = ignoreList()
	local size = Vector3.new(6, 6, 6)
	if inCar and car then
		local _, s = car:GetBoundingBox()
		size = s
	end
	local face = function(at: Vector3): CFrame
		-- face into the area (along a road for road spots near the middle is close enough)
		local to = Vector3.new(area.x, at.Y, area.z)
		if (to - at).Magnitude < 1 then
			return CFrame.new(at)
		end
		return CFrame.lookAt(at, to)
	end
	local chosen: CFrame? = nil
	for _, i in Rules.order(list, busy(player), Cfg.Clear, random:NextInteger(1, #list)) do
		local s = list[i]
		-- a spot by the live event is skipped (the area's middle may be just outside its keep-away)
		local nearLive = ex ~= nil
			and ez ~= nil
			and (s.x - ex) ^ 2 + (s.z - ez) ^ 2 < Cfg.EventKeepAway ^ 2
		local g = if nearLive then nil else groundAt(s.x, s.z, ignore)
		if g then
			local cf = face(g)
			if not VehicleService.blockedAt(cf, size, ignore) then
				chosen = cf
				break
			end
		end
	end
	if not chosen then
		answer(player, false, "Unknown")
		return
	end

	-- the cooldown starts now, before the stream-in wait, so a second ask can't slip in
	moving[player] = true
	readyAt[player] = os.clock() + Cfg.Cooldown
	player:SetAttribute("TeleportReadyAt", workspace:GetServerTimeNow() + Cfg.Cooldown)
	pcall(function()
		player:RequestStreamAroundAsync(chosen.Position, Cfg.StreamTimeout)
	end)
	moving[player] = nil
	-- things may have changed while the area streamed in: the car gone, the player out of it or dead (then the
	-- cooldown is given back)
	if not (character.Parent and humanoid.Health > 0) then
		readyAt[player] = nil
		player:SetAttribute("TeleportReadyAt", nil)
		answer(player, false, "Dead")
		return
	end
	car = VehicleService.of(player)
	inCar = car ~= nil and humanoid.SeatPart ~= nil and humanoid.SeatPart:IsDescendantOf(car)
	if inCar and car then
		VehicleService.moveTo(player, car, chosen)
		HitGuard.moved(player)
	else
		if humanoid.SeatPart then
			humanoid.Sit = false
			task.wait()
		end
		character:PivotTo(chosen + Vector3.new(0, Cfg.Lift, 0))
		root.AssemblyLinearVelocity = Vector3.zero
	end
	answer(player, true, nil)
	Analytics.teleported(player, area.key, inCar)
end

-- road points from the built map (MapBuilder spawnPoints): each area's landing spots
function TeleportService.setRoadPoints(points: { Vector3 })
	local roads = {}
	for _, p in points do
		table.insert(roads, { x = p.X, z = p.Z })
	end
	for _, area in areas do
		spots[area.key] = Rules.spots(area, roads, Cfg.MinGap, Cfg.MaxSpots)
	end
end

function TeleportService.start()
	Net.remote("Teleport").OnServerEvent:Connect(function(player, key)
		if typeof(key) ~= "string" or not RateLimit.allow(player, "teleport", 1) then
			return
		end
		teleport(player, key)
	end)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
		moving[player] = nil
	end)
end

return TeleportService
