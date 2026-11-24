--!strict
-- Background music (Config/Audio Music): upbeat funk tracks shuffled at a low volume, dipping while a big
-- callout has the middle of the screen (Style.stage). On by default; the Settings panel (client/Settings)
-- turns it off and on, and the choice is saved (SetMusic, player attribute MusicOff).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Audio = require(ReplicatedStorage.Shared.Config.Audio)
local Net = require(ReplicatedStorage.Shared.Net)
local Style = require(script.Parent.Style)

local Music = {}

local M = Audio.Music
local player = Players.LocalPlayer

local track = Instance.new("Sound")
track.Name = "Music"
track.Volume = 0
track.Parent = SoundService

local off = false
local level = 0 -- 0..1 of M.Volume, eased toward where it should be

local listeners: { () -> () } = {}
local function show()
	for _, f in listeners do
		task.spawn(f)
	end
end

function Music.isOff(): boolean
	return off
end

-- turn the music off or on, and save it
function Music.setOff(value: boolean)
	if off == value then
		return
	end
	off = value
	show()
	Net.waitFor("SetMusic"):FireServer(off)
end

-- called whenever it's turned off or on
function Music.changed(f: () -> ())
	table.insert(listeners, f)
end

---------------------------------------------------------------- playing

local order: { number } = {}
local function nextTrack(): number
	if #order == 0 then
		order = table.clone(M.Tracks)
		for i = #order, 2, -1 do
			local j = math.random(1, i)
			order[i], order[j] = order[j], order[i]
		end
	end
	return table.remove(order, 1) :: number
end

local function playNext()
	track.SoundId = "rbxassetid://" .. nextTrack()
	track.TimePosition = 0
	track:Play()
end

track.Ended:Connect(function()
	task.delay(M.Gap, playNext)
end)

function Music.start()
	off = player:GetAttribute("MusicOff") == true
	show()
	player:GetAttributeChangedSignal("MusicOff"):Connect(function()
		off = player:GetAttribute("MusicOff") == true
		show()
	end)
	playNext()
	-- ease the volume: off, ducked under a big callout, or full
	RunService.Heartbeat:Connect(function(dt)
		local want = if off then 0 elseif Style.stageBusy() then M.DuckTo else 1
		local step = dt / M.Fade
		level = if level < want then math.min(want, level + step) else math.max(want, level - step)
		track.Volume = M.Volume * level
	end)
end

return Music
