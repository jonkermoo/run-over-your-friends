--!strict
-- Game feel: what a hit, a landing, a smashed wall or a blast looks and sounds like.
-- Camera shake ("trauma", decays fast) scaled by impact strength, an impact flash and FOV punch on your
-- own hits, pooled 3D sounds (made once so they play on time), dust and glass bursts, the combo
-- announcer, and a "112 STUDS!" readout where your victim lands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cockpit = require(ReplicatedStorage.Shared.Config.Cockpit)
local CrowdConfig = require(ReplicatedStorage.Shared.Config.Crowd)
local Net = require(ReplicatedStorage.Shared.Net)
local Drive = require(script.Parent.Drive)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local camera = workspace.CurrentCamera
local C, F = Style.colors, Style.fonts

local Fx = {}

-- Pro Sound Effects library sounds (free for Roblox games); several per kind for variety
local SOUNDS: { [string]: { id: { number }, volume: number, pitch: { number }, pool: number } } = {
	Thud = {
		id = { 9113524166, 9113564874, 9113573357 },
		volume = 1.4,
		pitch = { 0.9, 1.1 },
		pool = 6,
	},
	Boink = {
		id = { 9113854234, 9113854388, 9113854411 },
		volume = 0.7,
		pitch = { 0.95, 1.25 },
		pool = 4,
	},
	Squeal = { id = { 9114398347 }, volume = 0.6, pitch = { 0.95, 1.3 }, pool = 3 },
	Cash = { id = { 9113728756 }, volume = 0.45, pitch = { 1, 1 }, pool = 3 },
	Whoosh = { id = { 9126229255 }, volume = 0.6, pitch = { 0.9, 1.1 }, pool = 3 },
	Crash = { id = { 9120828678, 9120369181 }, volume = 1.3, pitch = { 0.85, 1.05 }, pool = 4 },
	Glass = { id = { 9114592102, 9114591515 }, volume = 0.9, pitch = { 0.9, 1.1 }, pool = 3 },
	Boom = { id = { 9116973611 }, volume = 2.2, pitch = { 0.8, 0.95 }, pool = 2 },
	Sting = { id = { 9125648149 }, volume = 0.6, pitch = { 1, 1 }, pool = 2 },
	-- people: whoever gets hit, someone jumping clear, and the crowd running from a crash
	Scream = {
		id = { 9118844102, 9125652432, 9125652466 },
		volume = 0.8,
		pitch = { 0.95, 1.15 },
		pool = 4,
	},
	Yelp = { id = { 9114399063, 9125652949 }, volume = 0.8, pitch = { 1, 1.2 }, pool = 3 },
	Honk = { id = { 9120385543, 9120382911 }, volume = 0.6, pitch = { 0.9, 1.1 }, pool = 3 }, -- traffic getting past you
	Panic = {
		id = { 9125905087, 9125905538, 9125905515 },
		volume = 1.1,
		pitch = { 0.95, 1.1 },
		pool = 3,
	},
}
local COMBO_WORDS =
	{ "", "DOUBLE!", "TRIPLE!", "MULTI!", "MEGA!", "ULTRA!", "MONSTER!", "RAMPAGE!" }
local COMBO_COLORS = { C.text, C.money, C.yellow, C.orange, C.red, C.pink, C.blue, C.yellow }

---------------------------------------------------------------- sound pool

local holder = Instance.new("Part")
holder.Name = "FxSounds"
holder.Anchored = true
holder.CanCollide = false
holder.CanQuery = false
holder.CanTouch = false
holder.Transparency = 1
holder.Size = Vector3.one
holder.Parent = workspace

type Voice = { attachment: Attachment, sound: Sound }
local pools: { [string]: { voices: { Voice }, next: number } } = {}
for kind, def in SOUNDS do
	local voices = {}
	for i = 1, def.pool do
		local a = Instance.new("Attachment")
		a.Parent = holder
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. def.id[(i - 1) % #def.id + 1]
		s.Volume = def.volume
		s.RollOffMinDistance = 20
		s.RollOffMaxDistance = 400
		s.Parent = a
		table.insert(voices, { attachment = a, sound = s })
	end
	pools[kind] = { voices = voices, next = 1 }
end

local function play(kind: string, at: Vector3?, pitchScale: number?)
	local pool = pools[kind]
	local def = SOUNDS[kind]
	if not pool then
		return
	end
	local v = pool.voices[pool.next]
	pool.next = pool.next % #pool.voices + 1
	v.attachment.WorldPosition = at or camera.CFrame.Position
	v.sound.PlaybackSpeed = (def.pitch[1] + math.random() * (def.pitch[2] - def.pitch[1]))
		* (pitchScale or 1)
	v.sound.TimePosition = 0
	v.sound:Play()
end

---------------------------------------------------------------- camera shake and flash

local trauma = 0
local function shake(amount: number)
	trauma = math.min(1, trauma + amount)
end

-- after the first-person camera (Cockpit, Camera + 1)
RunService:BindToRenderStep("RoyfShake", Enum.RenderPriority.Camera.Value + 2, function(dt)
	if trauma <= 0 then
		return
	end
	local t = os.clock() * 28
	-- softer in first person, with little sideways sway so it can't push the camera through the glass
	local inside = Drive.view.firstPerson
	local k = trauma * trauma * (if inside then Cockpit.shake else 1)
	local angle = math.rad(3.2) * k
	camera.CFrame *= CFrame.Angles(
		angle * math.noise(t, 1.3),
		angle * math.noise(t, 7.1),
		angle * 0.6 * math.noise(t, 13.7)
	) + camera.CFrame.RightVector * ((if inside then Cockpit.shakeSway else 0.6) * k * math.noise(
		t,
		21.1
	))
	trauma = math.max(0, trauma - dt * 1.6)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "Fx"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 4
gui.Parent = playerGui
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = gui

local function impactFlash(strength: number)
	flash.BackgroundTransparency = 1 - 0.35 * strength
	TweenService:Create(flash, TweenInfo.new(0.16), { BackgroundTransparency = 1 }):Play()
	-- a quick FOV punch (the driving code eases it back)
	camera.FieldOfView = math.max(40, camera.FieldOfView - 4 - 8 * strength)
end

---------------------------------------------------------------- particles

local function burst(at: Vector3, color: Color3, count: number, speed: number, size: number)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = workspace.Terrain
	local p = Instance.new("ParticleEmitter")
	p.Color = ColorSequence.new(color)
	p.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, size * 2.2),
	})
	p.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	p.Speed = NumberRange.new(speed * 0.4, speed)
	p.SpreadAngle = Vector2.new(180, 180)
	p.Lifetime = NumberRange.new(0.5, 1)
	p.Drag = 3
	p.Acceleration = Vector3.new(0, 6, 0)
	p.Rate = 0
	p.Parent = a
	p:Emit(count)
	task.delay(1.5, function()
		a:Destroy()
	end)
end

local function stars(at: Vector3)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = workspace.Terrain
	local p = Instance.new("ParticleEmitter")
	p.Color = ColorSequence.new(C.gold, C.text)
	p.LightEmission = 0.6
	p.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	p.Speed = NumberRange.new(25, 45)
	p.SpreadAngle = Vector2.new(180, 180)
	p.Lifetime = NumberRange.new(0.3, 0.5)
	p.Rate = 0
	p.Parent = a
	p:Emit(14)
	task.delay(1, function()
		a:Destroy()
	end)
end

---------------------------------------------------------------- big text

-- combo words slam in right of centre, slanted, with two hard offset copies behind (pink, then ink)
local function announce(word: string, color: Color3, sizeBoost: number, x: number?, y: number?)
	local left, top = x or 0.66, y or 0.4
	local slam = Instance.new("Frame")
	slam.BackgroundTransparency = 1
	slam.AnchorPoint = Vector2.new(0.5, 0.5)
	slam.Position = UDim2.fromScale(left, top)
	slam.Size = UDim2.fromOffset(700, 100)
	slam.Rotation = math.random(-8, -3)
	slam.Parent = gui
	local size = 64 + sizeBoost
	local labels = {}
	for i, look in
		{ { C.ink, 10 }, { if color == C.pink then C.blue else C.pink, 5 }, { color, 0 } }
	do
		local l = Style.label(slam, word, size, F.display, look[1])
		l.Position = UDim2.fromOffset(look[2], look[2])
		l.Size = UDim2.fromScale(1, 1)
		l.ZIndex = i
		if i == 3 then
			Style.outline(l, 4)
		end
		table.insert(labels, l)
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 2
	scale.Parent = slam
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(0.7, function()
		TweenService
			:Create(slam, TweenInfo.new(0.35), { Position = UDim2.fromScale(left, top - 0.04) })
			:Play()
		for _, l in labels do
			TweenService:Create(l, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			local s = l:FindFirstChildOfClass("UIStroke")
			if s then
				TweenService:Create(s, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			end
		end
		task.delay(0.4, function()
			slam:Destroy()
		end)
	end)
end

local function worldText(at: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = at + Vector3.new(0, 4, 0)
	anchor.Parent = workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Adornee = anchor
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(260, 60)
	bb.Parent = playerGui
	local l = Style.label(bb, text, 34, F.display, color)
	l.Size = UDim2.fromScale(1, 1)
	Style.outline(l, 3)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = l
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService
		:Create(
			bb,
			TweenInfo.new(1.6, Enum.EasingStyle.Quad),
			{ StudsOffset = Vector3.new(0, 8, 0) }
		)
		:Play()
	task.delay(1.1, function()
		TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	end)
	task.delay(1.7, function()
		bb:Destroy()
		anchor:Destroy()
	end)
end

---------------------------------------------------------------- events

local function onFx(kind: string, at: Vector3, a: number, b: number, userId: number)
	local mine = userId == player.UserId
	local near = (at - camera.CFrame.Position).Magnitude
	if kind == "Hit" then
		local strength = math.clamp(a, 0, 1)
		play("Thud", at, 1.1 - 0.3 * strength)
		play("Boink", at)
		if math.random() < 0.55 then
			play("Squeal", at)
		end
		burst(
			at,
			Color3.fromRGB(220, 210, 190),
			10 + math.floor(strength * 20),
			20 + 40 * strength,
			1.2
		)
		stars(at + Vector3.new(0, 2, 0))
		-- the one hit screams; a few people round them scream as they run (the server sends them running)
		if math.random() < 0.8 then
			play("Scream", at)
		end
		local npcs = workspace:FindFirstChild("Npcs")
		local voices = 0
		for _, m in (if npcs then npcs:GetChildren() else {}) do
			if voices >= CrowdConfig.React.ScreamVoices then
				break
			end
			local r = m:FindFirstChild("HumanoidRootPart") :: BasePart?
			local d = r and (r.Position - at).Magnitude
			if
				r
				and d
				and d > 3
				and d < CrowdConfig.React.FleeRadius
				and not m:GetAttribute("Down")
			then
				voices += 1
				task.delay(0.15 + math.random() * 0.5, play, "Panic", r.Position)
			end
		end
		if mine then
			shake(0.25 + 0.5 * strength)
			impactFlash(strength)
			task.delay(0.12, play, "Cash", nil, 1 + math.min(b, 8) * 0.06)
			if b >= 2 then
				local i = math.min(b, #COMBO_WORDS)
				announce(COMBO_WORDS[i], COMBO_COLORS[i], math.min(b, 10) * 3)
				play("Sting", nil, 0.9 + math.min(b, 10) * 0.05)
			end
		elseif near < 120 then
			shake(0.1)
		end
	elseif kind == "Honk" then
		play("Honk", at)
	elseif kind == "Dodge" then
		play("Yelp", at)
	elseif kind == "Land" then
		local studs = math.floor(a)
		local word, color = `{studs} STUDS!`, C.text
		if studs >= 300 then
			word, color = `{studs} STUDS!! ORBIT!`, C.purple
		elseif studs >= 150 then
			word, color = `{studs} STUDS! HOME RUN!`, C.gold
		elseif studs >= 80 then
			color = C.money
		end
		worldText(at, word, color)
		play("Whoosh", at)
	elseif kind == "Break" then
		local radius = b
		play("Crash", at, 1.05 - math.clamp(radius / 40, 0, 0.3))
		if a > 4 then
			play("Glass", at)
		end
		burst(at, Color3.fromRGB(190, 185, 175), 20 + math.min(a, 60), 25 + radius, 2.5)
		shake(math.clamp((if mine then 0.35 else 0.15) * (1 - near / 300) + radius / 100, 0, 0.8))
	elseif kind == "Boom" then
		play("Boom", at)
		burst(at, Color3.fromRGB(80, 75, 70), 40, 60, 5)
		shake(math.clamp(1.1 - near / (a * 6), 0.1, 1))
	end
end

-- a whole building coming down (src/client/Collapse): the hit, then the storeys landing one after another
function Fx.feelCollapse(at: Vector3, mine: boolean, near: number)
	play("Boom", at)
	play("Crash", at, 0.8)
	play("Glass", at)
	if mine then
		shake(1)
		impactFlash(1)
	else
		shake(math.clamp(0.5 * (1 - near / 500), 0, 0.5))
	end
	for _, wait in { 0.35, 0.85, 1.4 } do
		task.delay(wait, play, "Crash", at, 0.7 + math.random() * 0.15)
		task.delay(wait, shake, if mine then 0.3 else 0.1)
	end
end

-- the money shot, in the middle of the screen, with the till
function Fx.announceBig(word: string, amount: string)
	announce(word, C.yellow, 34, 0.5, 0.3)
	announce(amount, C.money, 20, 0.5, 0.42)
	play("Sting", nil, 0.85)
	play("Cash", nil, 0.9)
end

function Fx.start()
	Net.waitFor("Fx").OnClientEvent:Connect(onFx)
	-- goal and purchase moments get the till
	Net.waitFor("Popup").OnClientEvent:Connect(function(_, kind)
		if kind == "goal" or kind == "big" then
			play("Cash", nil, 0.9)
		end
	end)
end

return Fx
