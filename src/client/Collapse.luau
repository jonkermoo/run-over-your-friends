--!strict
-- A whole building coming down, drawn on each screen: the server only says which one. The pieces near the hit
-- are thrown out, the storeys drop one after another into the dust, and whoever hit it sees it in slow motion
-- (Drive.timeScale). Only anchored pieces moved locally, so nothing here reaches the server or its physics.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Rules = require(ReplicatedStorage.Shared.Rules.Collapse)
local Smash = require(ReplicatedStorage.Shared.Config.Smash)
local Drive = require(script.Parent.Drive)
local Fx = require(script.Parent.Fx)

local CFG = Smash.Collapse
local player = Players.LocalPlayer
local random = Random.new()

local Collapse = {}

type Piece = {
	part: BasePart,
	from: CFrame,
	wait: number,
	velocity: Vector3,
	axis: Vector3,
	spin: number,
	floorY: number,
}
type Show = {
	pieces: { Piece },
	clock: number,
	mine: boolean,
	moved: { BasePart },
	frames: { CFrame },
	dust: { ParticleEmitter },
	puffs: number,
	anchor: Attachment,
}

local shows: { Show } = {}

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "CollapseGrade"
grade.Enabled = false
grade.Parent = Lighting

local function slowLook()
	grade.Enabled = true
	grade.Saturation = -0.3
	grade.Contrast = 0.15
	task.delay(CFG.SlowSeconds, function()
		TweenService:Create(grade, TweenInfo.new(0.3), { Saturation = 0, Contrast = 0 }):Play()
		task.delay(0.35, function()
			grade.Enabled = false
		end)
	end)
end

local function vanish(part: BasePart)
	part.Transparency = 1
end

local function makeDust(anchor: Attachment, size: Vector3, mine: boolean): { ParticleEmitter }
	local dust = {}
	local spots = 7
	for i = 1, spots do
		local angle = i / spots * math.pi * 2
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(math.cos(angle) * size.X * 0.5, 0, math.sin(angle) * size.Z * 0.5)
		a.Parent = anchor
		local p = Instance.new("ParticleEmitter")
		p.Color = ColorSequence.new(Color3.fromRGB(196, 186, 170))
		p.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 12),
			NumberSequenceKeypoint.new(1, 42),
		})
		p.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.7, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		p.Lifetime = NumberRange.new(2.2, 3.6)
		p.Speed = NumberRange.new(14, 34)
		p.Drag = 1.6
		p.SpreadAngle = Vector2.new(70, 70)
		p.RotSpeed = NumberRange.new(-30, 30)
		p.Rotation = NumberRange.new(0, 360)
		p.Rate = 0
		p.TimeScale = if mine then CFG.SlowScale else 1
		p.Parent = a
		table.insert(dust, p)
	end
	return dust
end

local function puff(show: Show)
	for _, p in show.dust do
		p:Emit(24)
	end
end

local function finish(show: Show)
	for _, piece in show.pieces do
		piece.part.CFrame = piece.from
		vanish(piece.part)
	end
	local anchor = show.anchor
	task.delay(5, function()
		anchor:Destroy()
	end)
end

local function step(dt: number)
	for i = #shows, 1, -1 do
		local show = shows[i]
		local rate = if show.mine then Drive.timeScale() else 1
		show.clock += dt * rate
		if show.mine then
			for _, p in show.dust do
				p.TimeScale = rate
			end
		end
		local clock = show.clock
		table.clear(show.moved)
		table.clear(show.frames)
		for _, piece in show.pieces do
			local t = clock - piece.wait
			if t > 0 then
				local from = piece.from
				local y, landed = Rules.fallHeight(
					from.Position.Y,
					piece.velocity.Y,
					t,
					CFG.Gravity,
					piece.floorY,
					CFG.SinkSpeed
				)
				local turning = if landed then math.min(t, 1) else t
				table.insert(show.moved, piece.part)
				table.insert(
					show.frames,
					CFrame.new(
						from.Position.X + piece.velocity.X * math.min(t, CFG.DriftSeconds),
						y,
						from.Position.Z + piece.velocity.Z * math.min(t, CFG.DriftSeconds)
					)
						* from.Rotation
						* CFrame.fromAxisAngle(piece.axis, piece.spin * turning)
				)
			end
		end
		if #show.moved > 0 then
			workspace:BulkMoveTo(show.moved, show.frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		-- each new wave of dust as the next storeys come down
		local wave = math.floor(clock / CFG.DustEvery)
		if wave >= show.puffs and clock < CFG.ShowSeconds then
			show.puffs = wave + 1
			puff(show)
		end
		if clock >= CFG.ShowSeconds then
			table.remove(shows, i)
			finish(show)
		end
	end
end

local function commas(n: number): string
	local grouped = string.gsub(string.reverse(tostring(math.floor(n))), "(%d%d%d)", "%1,")
	local text = string.gsub(string.reverse(grouped), "^,", "")
	return text
end

local function start(building: Model, at: Vector3, push: Vector3, pay: number, userId: number)
	local mine = userId == player.UserId
	local camera = workspace.CurrentCamera
	local near = (at - camera.CFrame.Position).Magnitude

	if mine then
		slowLook()
		Fx.feelCollapse(at, true, near)
		task.delay(CFG.PaySeconds, function()
			Fx.announceBig("DEMOLISHED!", "+$" .. commas(pay))
		end)
	elseif near < CFG.FeelStuds then
		Fx.feelCollapse(at, false, near)
	end

	-- a building streamed out on this screen arrives as nil: the feel and the pay above are all it gets
	if typeof(building) ~= "Instance" then
		return
	end
	local parts: { BasePart } = {}
	local minY, maxY = math.huge, -math.huge
	for _, p in building:GetDescendants() do
		if p:IsA("BasePart") and p.Anchored and p.Transparency < 1 then
			table.insert(parts, p)
			minY = math.min(minY, p.Position.Y - p.Size.Y / 2)
			maxY = math.max(maxY, p.Position.Y + p.Size.Y / 2)
		end
	end
	if #parts == 0 then
		return
	end
	if near > CFG.FarStuds or #shows >= CFG.MaxShows then
		for _, p in parts do
			vanish(p)
		end
		return
	end

	local tall = math.max(maxY - minY, 1)
	local pieces: { Piece } = {}
	local flat = push * Vector3.new(1, 0, 1)
	for i, p in parts do
		if i > CFG.MaxPieces then
			vanish(p)
			continue
		end
		local height = (p.Position.Y - minY) / tall
		local away = (p.Position - at) * Vector3.new(1, 0, 1)
		local reach = away.Magnitude
		away = if reach > 0.1 then away.Unit else flat.Unit
		local blasted = (p.Position - at).Magnitude < CFG.BlastRadius
		local velocity
		if blasted then
			velocity = flat * CFG.BlastPush
				+ away * random:NextNumber(CFG.BlastOut[1], CFG.BlastOut[2])
				+ Vector3.new(0, random:NextNumber(CFG.BlastUp[1], CFG.BlastUp[2]), 0)
		else
			-- the walls fall a little outward, the way a storey spreads as it lands
			velocity = away * random:NextNumber(CFG.DropOut[1], CFG.DropOut[2])
				+ Vector3.new(0, random:NextNumber(-2, 2), 0)
		end
		local axis = Vector3.new(
			random:NextNumber(-1, 1),
			random:NextNumber(-1, 1),
			random:NextNumber(-1, 1) + 0.01
		).Unit
		table.insert(pieces, {
			part = p,
			from = p.CFrame,
			wait = if blasted then 0 else Rules.startDelay(height, CFG),
			velocity = velocity,
			axis = axis,
			-- only what's blown out tumbles; the rest comes straight down, or the walls read as a pincushion
			spin = if blasted
				then random:NextNumber(CFG.BlastSpin[1], CFG.BlastSpin[2])
				else random:NextNumber(CFG.DropSpin[1], CFG.DropSpin[2]),
			floorY = minY + p.Size.Y / 2,
		})
	end

	local cf, size = building:GetBoundingBox()
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = Vector3.new(cf.Position.X, minY + 1, cf.Position.Z)
	anchor.Parent = workspace.Terrain
	local show: Show = {
		pieces = pieces,
		clock = 0,
		mine = mine,
		moved = {},
		frames = {},
		dust = makeDust(anchor, size, mine),
		puffs = 0,
		anchor = anchor,
	}
	table.insert(shows, show)
end

function Collapse.start()
	Net.waitFor("Collapse").OnClientEvent:Connect(start)
	RunService.RenderStepped:Connect(step)
end

return Collapse
