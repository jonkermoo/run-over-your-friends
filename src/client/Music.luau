--!strict
-- Background music (Config/Audio Music): upbeat funk tracks shuffled at a low volume, dipping while a big
-- callout has the middle of the screen (Style.stage). On by default; the speaker button left of the cash box
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
local C, F = Style.colors, Style.fonts
local player = Players.LocalPlayer

local track = Instance.new("Sound")
track.Name = "Music"
track.Volume = 0
track.Parent = SoundService

local off = false
local level = 0 -- 0..1 of M.Volume, eased toward where it should be

---------------------------------------------------------------- the speaker button

local gui = Instance.new("ScreenGui")
gui.Name = "Music"
gui.ResetOnSpawn = false
Style.fit(gui)

local button = Instance.new("TextButton")
button.Name = "MusicButton"
button.AutoButtonColor = false
button.BackgroundColor3 = C.panel
button.BorderSizePixel = 0
button.Text = ""
button.AnchorPoint = Vector2.new(1, 0)
button.Position = UDim2.new(1, -(14 + 196 + 10), 0, 8) -- left of the cash box (client/Hud: 196 wide, 14 in)
button.Size = UDim2.fromOffset(54, 54)
button.Parent = gui
Style.shadow(button)
local word = Style.label(button, "MUSIC", 11, F.heavy, C.yellow)
word.Position = UDim2.fromOffset(0, 6)
word.Size = UDim2.new(1, 0, 0, 12)
local state = Style.label(button, "ON", 20, F.display, C.money)
state.Position = UDim2.fromOffset(0, 20)
state.Size = UDim2.new(1, 0, 0, 26)
local slash = Instance.new("Frame") -- a red strike across while it's off
slash.AnchorPoint = Vector2.new(0.5, 0.5)
slash.Position = UDim2.fromScale(0.5, 0.5)
slash.Size = UDim2.new(1.1, 0, 0, 4)
slash.Rotation = -35
slash.BackgroundColor3 = C.red
slash.BorderSizePixel = 0
slash.Visible = false
slash.Parent = button

local function show()
	state.Text = if off then "OFF" else "ON"
	state.TextColor3 = if off then C.dim else C.money
	slash.Visible = off
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
	Style.onTap(button, function()
		off = not off
		show()
		Net.waitFor("SetMusic"):FireServer(off)
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
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
