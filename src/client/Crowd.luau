--!strict
-- Animates the city's people on this screen only: idle, walk or run from each character's Gait attribute
-- (set by the server). Ordinary people use the Rthro set; friends carry their own animation ids as
-- attributes. Only characters near the camera animate; further ones hold still and drop their tracks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Crowd)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Rules = require(ReplicatedStorage.Shared.Rules.Crowd)
local InteriorConfig = require(ReplicatedStorage.Shared.Config.Interiors)

local Crowd = {}

type Rig = {
	tracks: { [string]: AnimationTrack },
	playing: string?,
}

local rigs: { [Model]: Rig } = {}
local animations: { [string]: Animation } = {}

local function animation(id: string): Animation
	local a = animations[id]
	if not a then
		a = Instance.new("Animation")
		a.AnimationId = id
		animations[id] = a
	end
	return a
end

local function idOf(model: Model, attr: string, fallback: number): string
	local v = model:GetAttribute(attr)
	if typeof(v) == "string" and v ~= "" then
		return v
	end
	return "rbxassetid://" .. fallback
end

local function load(model: Model): Rig?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local idle = if math.random() < 0.85
		then idOf(model, "AnimIdle", Config.RthroIdle[1])
		else idOf(model, "AnimIdle2", Config.RthroIdle[2])
	local ids = {
		idle = idle,
		walk = idOf(model, "AnimWalk", Config.RthroWalk),
		run = idOf(model, "AnimRun", Config.RthroRun),
		sit = idOf(model, "AnimSit", InteriorConfig.SitAnim),
	}
	local rig: Rig = { tracks = {}, playing = nil }
	for name, id in ids do
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(animation(id))
		end)
		if ok and track then
			track.Priority = if name == "idle"
				then Enum.AnimationPriority.Idle
				else Enum.AnimationPriority.Movement
			track.Looped = true
			rig.tracks[name] = track
		end
	end
	rigs[model] = rig
	return rig
end

local function stopAll(rig: Rig)
	for _, t in rig.tracks do
		if t.IsPlaying then
			t:Stop(0.2)
		end
	end
	rig.playing = nil
end

local function drop(model: Model)
	local rig = rigs[model]
	if rig then
		for _, t in rig.tracks do
			t:Stop(0)
			t:Destroy()
		end
		rigs[model] = nil
	end
end

local function update(folder: Instance)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	for _, child in folder:GetChildren() do
		if not child:IsA("Model") then
			continue
		end
		local model = child :: Model
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		local d = (root.Position - eye).Magnitude
		local rig = rigs[model]
		-- how many times an everyday person this one is (a giant is several)
		local size = model:GetScale() / Game.BodyScale
		local radius = Rules.animRadius(size, Config)
		if model:GetAttribute("Down") then
			if rig then
				stopAll(rig)
			end
		elseif d < radius then
			rig = rig or load(model)
			if rig then
				local gait = model:GetAttribute("Gait")
				local want = if gait == "walk"
						or gait == "run"
						or gait == "sit"
					then gait
					else "idle"
				local track = rig.tracks[want]
				if track and rig.playing ~= want then
					for name, t in rig.tracks do
						if name ~= want and t.IsPlaying then
							t:Stop(0.25)
						end
					end
					track:Play(0.25)
					rig.playing = want
				end
				if want == "walk" and track then
					local humanoid = model:FindFirstChildOfClass("Humanoid")
					if humanoid then
						track:AdjustSpeed(Rules.walkAnimSpeed(humanoid.WalkSpeed, size, Config))
					end
				end
			end
		elseif rig and d > radius * 1.4 then
			drop(model)
		elseif rig then
			stopAll(rig)
		end
	end
end

function Crowd.start()
	task.spawn(function()
		local folder = workspace:WaitForChild("Npcs")
		folder.ChildRemoved:Connect(function(child)
			if child:IsA("Model") then
				drop(child)
			end
		end)
		while true do
			task.wait(0.2)
			update(folder)
		end
	end)
end

return Crowd
