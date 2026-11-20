--!strict
-- The champions' podium avatars (Config/Champions). LeaderboardService passes each step's #1 here; when the
-- player on a step changes, their avatar is built from their Roblox outfit (they don't have to be in this
-- server) into ReplicatedStorage.Champions as a model named after the step's board key, with attributes
-- UserId, PlayerName, Value and LastWeek. Clients clone it onto the stage and pose it (client/Champions).
-- Builds go one at a time with a gap between them; the last good avatar stays until the new one is ready.
-- If Roblox can't give the outfit, a plain default avatar stands in, and the real one is tried again later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Champions)

local ChampionService = {}

type Entry = { userId: number, name: string, value: number }
type Want = { userId: number, name: string, value: number, lastWeek: boolean }

local folder: Folder
local want: { [string]: Want? } = {} -- who should stand on each step
local built: { [string]: { userId: number, real: boolean, at: number } } = {} -- what is on it now
local busy = false

-- the description, from the newer Async calls when this engine has them
local function describe(userId: number): HumanoidDescription?
	local ok, desc = pcall(function()
		return (Players :: any):GetHumanoidDescriptionFromUserIdAsync(userId)
	end)
	if not ok then
		ok, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(userId)
		end)
	end
	return if ok and desc then desc else nil
end

local function fromDescription(desc: HumanoidDescription): Model?
	local ok, model = pcall(function()
		return (Players :: any):CreateHumanoidModelFromDescriptionAsync(
			desc,
			Enum.HumanoidRigType.R15
		)
	end)
	if not ok then
		ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
	end
	return if ok and model then model else nil
end

-- a statue: nothing in it runs, collides, gets touched or found by hit checks; only the root is anchored
local function still(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d.Name == "HumanoidRootPart"
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
		pcall(function()
			(hum :: any).EvaluateStateMachine = false
		end)
	end
end

local function label(model: Model, key: string, w: Want)
	model:SetAttribute("UserId", w.userId)
	model:SetAttribute("PlayerName", w.name)
	model:SetAttribute("Value", math.floor(w.value))
	model:SetAttribute("LastWeek", w.lastWeek)
	model:SetAttribute("Key", key)
end

-- build the avatar for one step (yields)
local function build(key: string, w: Want)
	local desc = describe(w.userId)
	local model = if desc then fromDescription(desc) else nil
	local real = model ~= nil
	if not model then
		model = fromDescription(Instance.new("HumanoidDescription"))
	end
	if not model then
		built[key] = { userId = w.userId, real = false, at = os.clock() }
		return
	end
	local m = model :: Model
	still(m)
	m.Name = key
	label(m, key, w)
	m:SetAttribute("Parts", #m:GetDescendants()) -- clients wait until all of it has arrived
	-- the step may have changed hands while this one loaded: drop it, the next pass builds the right one
	local now = want[key]
	if not now or now.userId ~= w.userId then
		m:Destroy()
		return
	end
	local old = folder:FindFirstChild(key)
	m.Parent = folder
	if old and old ~= m then
		old:Destroy()
	end
	built[key] = { userId = w.userId, real = real, at = os.clock() }
end

-- one build at a time; a step needs one when its player changed, or its stand-in is due for a retry
local function pump()
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		while true do
			local nextKey: string? = nil
			for _, step in Config.Steps do
				local w, b = want[step.key], built[step.key]
				if
					w
					and (
						not b
						or b.userId ~= w.userId
						or (not b.real and os.clock() - b.at >= Config.RetrySeconds)
					)
				then
					nextKey = step.key
					break
				end
			end
			if not nextKey then
				break
			end
			build(nextKey, want[nextKey] :: Want)
			task.wait(Config.BuildGap)
		end
		busy = false
	end)
end

-- the #1 of a step's board (nil = nobody yet); lastWeek marks last week's winner on the weekly step
function ChampionService.update(key: string, entry: Entry?, lastWeek: boolean)
	if not entry then
		want[key] = nil
		local old = folder and folder:FindFirstChild(key)
		if old then
			old:Destroy()
		end
		built[key] = nil
		return
	end
	local w = { userId = entry.userId, name = entry.name, value = entry.value, lastWeek = lastWeek }
	want[key] = w
	-- same player: just keep the plate's numbers fresh
	local current = folder:FindFirstChild(key)
	if current and current:GetAttribute("UserId") == entry.userId then
		label(current :: Model, key, w)
	end
	pump()
end

function ChampionService.start()
	folder = Instance.new("Folder")
	folder.Name = "Champions"
	folder.Parent = ReplicatedStorage
	-- stand-ins are retried even when nobody's rank changes
	task.spawn(function()
		while true do
			task.wait(Config.RetrySeconds / 2)
			pump()
		end
	end)
end

return ChampionService
