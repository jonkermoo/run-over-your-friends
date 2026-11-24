--!strict
-- Which car prompts this player sees (server/VehicleService makes them, Config/Riders): DRIVE on their own car
-- and RIDE on everyone else's, each only while the server marks it Open (the driver's seat is empty / a rider
-- seat is free and the owner takes riders) and while this player isn't sitting in a vehicle. A car whose owner
-- takes friends only shows RIDE to their friends; the server checks again either way.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Riding = {}

local player = Players.LocalPlayer
local EVERY = 0.25 -- seconds between checks

local prompts: { [ProximityPrompt]: boolean } = {}
local friendOf: { [number]: boolean } = {} -- owner user id -> friends with this player (nil = asking)

local function isFriend(userId: number): boolean
	local known = friendOf[userId]
	if known == nil then
		friendOf[userId] = false
		task.spawn(function()
			local ok, yes = pcall(function()
				return player:IsFriendsWith(userId)
			end)
			friendOf[userId] = ok and yes == true
		end)
		return false
	end
	return known
end

local function sync(seated: boolean)
	for prompt in prompts do
		local car = prompt.Parent and prompt.Parent.Parent
		if not (car and car:IsA("Model")) then
			prompts[prompt] = nil
			continue
		end
		local ownerId = car:GetAttribute("OwnerId")
		local mine = ownerId == player.UserId
		local open = prompt:GetAttribute("Open") == true and not seated
		if prompt.Name == "DrivePrompt" then
			prompt.Enabled = mine and open
		else
			local friendsOnly = car:GetAttribute("RideMode") == "Friends"
			prompt.Enabled = not mine
				and open
				and (not friendsOnly or (typeof(ownerId) == "number" and isFriend(ownerId)))
		end
	end
end

local function watch(d: Instance)
	if d:IsA("ProximityPrompt") and (d.Name == "DrivePrompt" or d.Name == "RidePrompt") then
		prompts[d] = true
		d.Enabled = false
	end
end

function Riding.start()
	local folder = workspace:WaitForChild("Vehicles")
	for _, d in folder:GetDescendants() do
		watch(d)
	end
	folder.DescendantAdded:Connect(watch)
	folder.DescendantRemoving:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			prompts[d] = nil
		end
	end)
	local last = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - last < EVERY then
			return
		end
		last = now
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		sync(humanoid ~= nil and humanoid.SeatPart ~= nil)
	end)
end

return Riding
