-- Moves the camera lock ("shift lock") off Shift, which boosts, onto the keys in Config/Camera.
-- Roblox's MouseLockController reads its keys from a BoundKeys StringValue under itself and
-- re-binds when that value changes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Camera)

local CamLock = {}

function CamLock.start()
	local wait = Config.FindTimeout
	local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts", wait)
	local module = scripts and scripts:WaitForChild("PlayerModule", wait)
	local camera = module and module:WaitForChild("CameraModule", wait)
	local controller = camera and camera:WaitForChild("MouseLockController", wait)
	local keys = controller and controller:WaitForChild("BoundKeys", wait)
	if keys and keys:IsA("StringValue") then
		keys.Value = Config.MouseLockKeys
	else
		warn("CamLock: camera lock keys not found; lock stays on Shift")
	end
end

return CamLock
