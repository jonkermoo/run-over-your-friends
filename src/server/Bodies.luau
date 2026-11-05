--!strict
-- Every player's character is Game.BodyScale times a stock Roblox avatar, set on the server once the avatar
-- has loaded (so its hats and hair grow with it). The vehicles are built as much bigger (VehicleBuilder).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Game = require(ReplicatedStorage.Shared.Config.Game)

local Bodies = {}

local function grow(player: Player, character: Model)
	local waited = 0
	while not player:HasAppearanceLoaded() and waited < Game.AppearanceWait do
		waited += task.wait(0.1)
	end
	if player.Character ~= character or not character.Parent then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then
		return
	end
	local before = character:GetScale()
	if math.abs(before - Game.BodyScale) < 1e-3 then
		return
	end
	local hip = humanoid.HipHeight
	character:ScaleTo(Game.BodyScale)
	-- it grows about its middle: lift it by what its legs grew, so its feet don't start in the ground
	character:PivotTo(character:GetPivot() + Vector3.new(0, humanoid.HipHeight - hip, 0))
end

function Bodies.start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			grow(player, character)
		end)
		if player.Character then
			task.spawn(grow, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
end

return Bodies
