--!strict
-- The champions' podium in the middle of the spawn plaza (Config/Champions). MapBuilder builds the stage
-- (model ChampionStage: steps named Step_<key>, the trophy on its post); the server puts each step's #1 avatar
-- in ReplicatedStorage.Champions (server/ChampionService). Here: a plate on the front and back of each step
-- (the board's title and tag, or LAST WEEK, the player's name and score), each avatar cloned, scaled, posed by
-- bending its joints and stood on its step, banknotes drifting round the richest, and the whole stage turning
-- slowly, at the same angle for everyone. Far from the camera it stops turning.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Champions = require(ReplicatedStorage.Shared.Config.Champions)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Leaderboards = require(ReplicatedStorage.Shared.Config.Leaderboards)
local Style = require(script.Parent.Style)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local C, F = Style.colors, Style.fonts

local ChampionsClient = {}

type Plate = { tag: TextLabel, name: TextLabel, value: TextLabel }
type Slot = {
	key: string,
	step: BasePart,
	board: Leaderboards.Board?,
	plates: { Plate },
	avatar: Model?,
	source: Model?,
	stepLocal: CFrame, -- the step in the stage's frame
	offset: CFrame, -- the avatar's pivot in the stage's frame
}

local PX = 40 -- plate pixels per stud
local stage: Model? = nil
local base = CFrame.identity -- the stage's pivot as the server built it
local slots: { [string]: Slot } = {}
local holder: Folder? = nil

local function boardOf(key: string): Leaderboards.Board?
	for _, b in Leaderboards.Boards do
		if b.key == key then
			return b
		end
	end
	return nil
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return out
end

local function plate(step: BasePart, face: Enum.NormalId, board: Leaderboards.Board?): Plate
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ChampionPlate"
	gui.Adornee = step
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PX
	gui.LightInfluence = 0
	gui.MaxDistance = Champions.PlateDistance
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local accent = if board then Style.colors[board.color] or C.gold else C.gold
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 18)
	card.Size = UDim2.new(1, -36, 0, 196)
	card.BackgroundColor3 = C.panel
	card.BorderSizePixel = 0
	card.Parent = gui
	Style.shadow(card, C.ink, 6)
	local title = Style.label(card, if board then board.title else "", 34, F.display, accent)
	title.Position = UDim2.fromOffset(0, 10)
	title.Size = UDim2.new(1, 0, 0, 38)
	local tag = Style.pill(card, if board then board.tag else "", accent)
	tag.AnchorPoint = Vector2.new(0.5, 0)
	tag.Position = UDim2.new(0.5, 0, 0, 52)
	tag.TextSize = 18
	tag.Size = UDim2.fromOffset(0, 26)
	local name = Style.label(card, "", 34, F.heavy, C.text)
	name.Position = UDim2.fromOffset(10, 86)
	name.Size = UDim2.new(1, -20, 0, 44)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.AutoLocalize = false -- a player's name, never translated
	local value = Style.label(card, "", 44, F.display, accent)
	value.Position = UDim2.fromOffset(0, 132)
	value.Size = UDim2.new(1, 0, 0, 52)
	value.AutoLocalize = false
	return { tag = tag, name = name, value = value }
end

local function refreshPlates(slot: Slot)
	local src = slot.source
	local board = slot.board
	for _, p in slot.plates do
		if src then
			p.name.Text = tostring(src:GetAttribute("PlayerName") or "")
			local v = tonumber(src:GetAttribute("Value")) or 0
			p.value.Text = (if board then board.prefix else "") .. commas(v)
			p.tag.Text = if src:GetAttribute("LastWeek")
				then "LAST WEEK"
				else (if board then board.tag else "")
		else
			p.name.Text = "???"
			p.value.Text = "-"
			p.tag.Text = if board then board.tag else ""
		end
	end
end

local function pose(model: Model, poseName: string)
	local joints = Champions.Poses[poseName]
	if not joints then
		return
	end
	-- avatars come with Motor6D joints or, on the newer rigs, AnimationConstraints (posed by Transform; the
	-- Animator is removed in place() so nothing resets it)
	for _, d in model:GetDescendants() do
		local j = joints[d.Name]
		if j then
			local turn = CFrame.Angles(math.rad(j.x or 0), math.rad(j.y or 0), math.rad(j.z or 0))
			if d:IsA("Motor6D") then
				d.C0 *= turn
			elseif d:IsA("AnimationConstraint") then
				d.Transform *= turn
			end
		end
	end
end

-- banknotes drifting down round the avatar
local function bills(model: Model)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local at = Instance.new("Attachment")
	at.Position = Vector3.new(0, 4, 0)
	at.Parent = head
	local e = Instance.new("ParticleEmitter")
	e.Texture = `rbxassetid://{Icons.Bill}`
	e.Rate = Champions.Bills
	e.Lifetime = NumberRange.new(3, 4.5)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -3, 0)
	e.Drag = 1
	e.Size = NumberSequence.new(1.4)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.LightInfluence = 0.3
	e.Parent = at
end

local function place(slot: Slot)
	if slot.avatar then
		slot.avatar:Destroy()
		slot.avatar = nil
	end
	local src = slot.source
	if not src or not holder then
		return
	end
	local m = src:Clone()
	m.Name = slot.key
	for _, d in m:GetDescendants() do
		if d:IsA("Animator") then
			d:Destroy()
		end
	end
	pcall(function()
		m:ScaleTo(Champions.Scale)
	end)
	local stepCfg = nil
	for _, s in Champions.Steps do
		if s.key == slot.key then
			stepCfg = s
		end
	end
	m.Parent = holder
	-- the Humanoid rebuilds the joints once it is in the workspace: bend them after that
	task.wait(0.1)
	if slot.source ~= src or not m.Parent then
		m:Destroy()
		return
	end
	if stepCfg then
		pose(m, stepCfg.pose)
	end
	-- feet on the step's top, facing the step's front (-Z), measured at the stage's built angle
	local top = base * slot.stepLocal * CFrame.new(0, slot.step.Size.Y / 2, 0)
	m:PivotTo(CFrame.new(top.Position) * CFrame.new(0, 5, 0))
	local box, size = m:GetBoundingBox()
	local lift = (top.Position.Y - (box.Position.Y - size.Y / 2))
	local pivot = m:GetPivot() + Vector3.new(0, lift, 0)
	slot.offset = base:Inverse() * pivot
	if stepCfg and stepCfg.bills then
		bills(m)
	end
	slot.avatar = m
end

local function watch(folder: Instance)
	local function add(child: Instance)
		local slot = slots[child.Name]
		if not slot or not child:IsA("Model") then
			return
		end
		slot.source = child
		refreshPlates(slot)
		-- a model's pieces can arrive after the model itself: wait for all of them (up to 15 s)
		local want = tonumber(child:GetAttribute("Parts")) or 0
		local t0 = os.clock()
		while #child:GetDescendants() < want and os.clock() - t0 < 15 and child.Parent do
			task.wait(0.25)
		end
		if slot.source ~= child then
			return
		end
		place(slot)
		child.AttributeChanged:Connect(function()
			if slot.source == child then
				refreshPlates(slot)
			end
		end)
	end
	folder.ChildAdded:Connect(function(child)
		task.spawn(add, child)
	end)
	folder.ChildRemoved:Connect(function(child)
		local slot = slots[child.Name]
		if slot and slot.source == child then
			slot.source = nil
			refreshPlates(slot)
			if slot.avatar then
				slot.avatar:Destroy()
				slot.avatar = nil
			end
		end
	end)
	for _, child in folder:GetChildren() do
		task.spawn(add, child)
	end
end

local function attach()
	local map = workspace:WaitForChild("Map", 60)
	local static = map and map:WaitForChild("Static", 60)
	local found = static and static:WaitForChild("ChampionStage", 60)
	if not found or not found:IsA("Model") then
		return
	end
	stage = found
	local middle = found:WaitForChild("Step_" .. Champions.Steps[2].key, 30) :: BasePart?
	if not middle then
		return
	end
	base = CFrame.new(middle.Position.X, middle.Position.Y - middle.Size.Y / 2, middle.Position.Z)
	found.WorldPivot = base
	local f = Instance.new("Folder")
	f.Name = "ChampionAvatars"
	f.Parent = workspace
	holder = f
	for _, s in Champions.Steps do
		local step = found:WaitForChild("Step_" .. s.key, 30) :: BasePart?
		if step then
			local board = boardOf(s.key)
			local slot: Slot = {
				key = s.key,
				step = step,
				board = board,
				plates = {
					plate(step, Enum.NormalId.Front, board),
					plate(step, Enum.NormalId.Back, board),
				},
				avatar = nil,
				source = nil,
				stepLocal = base:Inverse() * step.CFrame,
				offset = CFrame.identity,
			}
			slots[s.key] = slot
			refreshPlates(slot)
		end
	end
	watch(ReplicatedStorage:WaitForChild("Champions"))
end

function ChampionsClient.start()
	task.spawn(attach)
	RunService.RenderStepped:Connect(function()
		local s = stage
		if not s or not s.Parent then
			return
		end
		local camera = workspace.CurrentCamera
		if
			camera
			and (camera.CFrame.Position - base.Position).Magnitude > Champions.ShowDistance
		then
			return
		end
		local t = workspace:GetServerTimeNow()
		local turn = base
			* CFrame.Angles(0, (t % Champions.TurnSeconds) / Champions.TurnSeconds * math.pi * 2, 0)
		s:PivotTo(turn)
		local bob = math.sin(t / Champions.BobSeconds * math.pi * 2)
			* Champions.BobStuds
			* Champions.Scale
		for _, slot in slots do
			local m = slot.avatar
			if m then
				m:PivotTo(turn * slot.offset + Vector3.new(0, bob, 0))
			end
		end
	end)
end

return ChampionsClient
