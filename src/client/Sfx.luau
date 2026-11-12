--!strict
-- Menu sounds (Config/Audio): a soft click on every button on screen, a whoosh when the garage, store or
-- goals sheet opens, and Sfx.play for the other screen moments (the till on a new ride, the podium fanfare).
-- Buttons are found as they appear, so a new screen gets its clicks without wiring; a button with the
-- attribute Quiet = true stays silent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Audio = require(ReplicatedStorage.Shared.Config.Audio)

local Sfx = {}

local sounds: { [string]: Sound } = {}
local function make(name: string, def: { id: number, volume: number }): Sound
	local s = Instance.new("Sound")
	s.Name = "Ui" .. name
	s.SoundId = "rbxassetid://" .. def.id
	s.Volume = def.volume
	s.Parent = SoundService
	sounds[name] = s
	return s
end
make("Click", Audio.Click)
make("Whoosh", Audio.Whoosh)
make("Till", Audio.Till)
make("Fanfare", Audio.Fanfare)

-- play one of Click, Whoosh, Till, Fanfare on this screen only
function Sfx.play(name: string)
	local s = sounds[name]
	if s then
		SoundService:PlayLocalSound(s)
	end
end

local lastClick = 0
local function click()
	local now = os.clock()
	if now - lastClick >= Audio.ClickGap then
		lastClick = now
		Sfx.play("Click")
	end
end

local hooked: { [GuiButton]: boolean } = {}
local function hook(d: Instance)
	if d:IsA("GuiButton") and not hooked[d] then -- a phone TapArea and its button click once (ClickGap)
		hooked[d] = true
		d.Activated:Connect(function()
			if not d:GetAttribute("Quiet") then
				click()
			end
		end)
		d.Destroying:Connect(function()
			hooked[d] = nil
		end)
	end
end

-- a sheet coming into view whooshes
local function watchSheet(sheet: Instance?)
	if sheet and sheet:IsA("GuiObject") then
		sheet:GetPropertyChangedSignal("Visible"):Connect(function()
			if sheet.Visible then
				Sfx.play("Whoosh")
			end
		end)
	end
end

function Sfx.start()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, d in pg:GetDescendants() do
		hook(d)
	end
	pg.DescendantAdded:Connect(hook)
	task.spawn(function()
		local hud = pg:WaitForChild("Hud", 30)
		watchSheet(hud and hud:FindFirstChild("Garage"))
		watchSheet(hud and hud:FindFirstChild("Store"))
		local goals = pg:WaitForChild("Goals", 30)
		watchSheet(goals and goals:WaitForChild("GoalsSheet", 10))
	end)
end

return Sfx
