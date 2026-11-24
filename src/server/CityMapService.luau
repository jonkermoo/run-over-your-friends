--!strict
-- The city map's dots (client/CityMap): far players aren't streamed in on a client, so once a second the
-- server sends every player's spot and heading (Rules/CityMap.pack), the live contest's leader and the live
-- event's spot to each client that has its map open, and to nobody else. Which car a player has out is the
-- VehicleId player attribute, already on every client; each spot says whether they're in it, or whose car they
-- ride in (a rider seat in someone else's car). Numbers: Config/CityMap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.CityMap)
local Net = require(ReplicatedStorage.Shared.Net)
local Rules = require(ReplicatedStorage.Shared.Rules.CityMap)
local EventService = require(script.Parent.EventService)
local RateLimit = require(script.Parent.RateLimit)
local VehicleService = require(script.Parent.VehicleService)

local CityMapService = {}

local watching: { [Player]: boolean } = {}

-- the car a seat belongs to (a model with an OwnerId: VehicleService.spawn) and its owner's user id
local function carOfSeat(seat: BasePart): (Model?, number?)
	local at: Instance? = seat.Parent
	while at and at ~= workspace do
		local owner = at:GetAttribute("OwnerId")
		if at:IsA("Model") and typeof(owner) == "number" then
			return at, owner
		end
		at = at.Parent
	end
	return nil, nil
end

-- where a player is, which way they face, and whether they're in their car or riding in someone else's (then
-- it's the car's spot and facing)
local function spotOf(player: Player): Rules.Spot?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local cf = root.CFrame
	local car = VehicleService.of(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local inCar = car ~= nil
		and humanoid ~= nil
		and humanoid.SeatPart ~= nil
		and humanoid.SeatPart:IsDescendantOf(car)
	local ride: number? = nil
	if inCar and car then
		cf = car:GetPivot()
	elseif humanoid and humanoid.SeatPart then
		local other, owner = carOfSeat(humanoid.SeatPart)
		if other and owner and owner ~= player.UserId then
			cf = other:GetPivot()
			ride = owner
		end
	end
	local look = cf.LookVector
	return {
		id = player.UserId,
		x = cf.Position.X,
		z = cf.Position.Z,
		h = Rules.heading(look.X, look.Z),
		car = inCar,
		ride = ride,
	}
end

-- everyone's spots, the contest leader (0 = none) and the event's spot, ready for the remote
local function payload(): ({ number }, number, number?, number?)
	local spots = {}
	for _, p in Players:GetPlayers() do
		local s = spotOf(p)
		if s then
			table.insert(spots, s)
		end
	end
	local at = EventService.spot()
	local leader = EventService.leader() or 0
	if at then
		return Rules.pack(spots), leader, math.round(at.X), math.round(at.Z)
	end
	return Rules.pack(spots), leader
end

local function sendTo(players: { Player })
	if #players == 0 then
		return
	end
	local remote = Net.remote("MapDots")
	local flat, leader, ex, ez = payload()
	for _, p in players do
		remote:FireClient(p, flat, leader, ex, ez)
	end
end

function CityMapService.start()
	Net.remote("MapDots")
	-- a flag: spamming it only flips the sender's own flag; the at-once send on opening is rate-limited
	Net.remote("MapOpen").OnServerEvent:Connect(function(player, open)
		if typeof(open) ~= "boolean" then
			return
		end
		watching[player] = if open then true else nil
		if open and RateLimit.allow(player, "map", Cfg.OpenSendGap) then
			sendTo({ player }) -- the first dots at once, not up to a second later
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		watching[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Cfg.SendEvery)
			local list = {}
			for p in watching do
				if p.Parent then
					table.insert(list, p)
				end
			end
			sendTo(list)
		end
	end)
end

return CityMapService
