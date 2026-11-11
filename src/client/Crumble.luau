--!strict
-- Bricks from crumbling walls and street furniture, simulated on this screen only: the server says which cells
-- of which parts broke (Rules/Crumble), this throws them as pooled bricks that tumble, freeze once they settle
-- (so they stop costing physics), lie a while and sink away. Never more than MaxLive (fewer on phones) at once:
-- the oldest goes first. Nothing here reaches the server or its physics; bricks are in the Debris group, so
-- vehicles drive through them and the game's own hit checks never see them (CanQuery off).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Rules = require(ReplicatedStorage.Shared.Rules.Crumble)
local Smash = require(ReplicatedStorage.Shared.Config.Smash)

local CFG = Smash.Crumble
local Crumble = {}

-- one broken part, as the server sends it (Net Crumble)
export type Burst = {
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	transparency: number,
	shape: string, -- "Block" | "Cylinder" | "Other" (thrown whole: a copy of `part`)
	part: BasePart?,
	na: number,
	nb: number,
	fly: { number },
}

type Brick = {
	part: BasePart,
	born: number,
	life: number,
	settled: boolean,
	from: CFrame?,
	depth: number,
	pooled: boolean,
}

local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local maxLive = if phone then CFG.MaxLivePhone else CFG.MaxLive
local PARK = CFrame.new(0, -400, 0)
local random = Random.new()

local folder = Instance.new("Folder")
folder.Name = "Bricks"
local live: { Brick } = {}
local spare: { Part } = {}
local moved: { BasePart } = {}
local frames: { CFrame } = {}

local function park(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 1
	p.CFrame = PARK
end

local function newPart(): Part
	local p = Instance.new("Part")
	p.CanQuery = false
	p.CanTouch = false
	p.CollisionGroup = "Debris"
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	park(p)
	p.Parent = folder
	return p
end

local function free(b: Brick)
	if b.pooled then
		park(b.part)
		table.insert(spare, b.part :: Part)
	else
		b.part:Destroy()
	end
end

local function between(range: { number }): number
	return random:NextNumber(range[1], range[2])
end

local function shade(c: Color3): Color3
	local k = 1 + random:NextNumber(-CFG.Shade, CFG.Shade)
	return Color3.new(
		math.clamp(c.R * k, 0, 1),
		math.clamp(c.G * k, 0, 1),
		math.clamp(c.B * k, 0, 1)
	)
end

-- the place and size of each thrown cell of a burst (a cylinder is cut along its length only)
function Crumble.bricks(b: Burst): { { cf: CFrame, size: Vector3 } }
	local s = { b.size.X, b.size.Y, b.size.Z }
	local k, a, c = Rules.axes(s[1], s[2], s[3])
	if b.shape == "Cylinder" then
		k, a, c = 3, 1, 2
	end
	local grid = { na = b.na, nb = b.nb }
	local A, B = s[a], s[c]
	local out = {}
	for _, cell in b.fly do
		local i, j = (cell - 1) % grid.na, (cell - 1) // grid.na
		local u, v = Rules.cellCentre(grid, A, B, i, j)
		local off = { 0, 0, 0 }
		off[a], off[c] = u, v
		local fill = between(CFG.Shrink)
		local size = { s[1], s[2], s[3] }
		size[a] = A / grid.na * fill
		if b.shape ~= "Cylinder" then
			size[c] = B / grid.nb * fill
			size[k] = s[k] * math.max(fill, 0.9)
		end
		table.insert(out, {
			cf = b.cf * CFrame.new(off[1], off[2], off[3]),
			size = Vector3.new(size[1], size[2], size[3]),
		})
	end
	return out
end

local function launch(p: BasePart, at: Vector3, push: Vector3, scatter: number)
	local away = p.Position - at
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.yAxis
	p.AssemblyLinearVelocity = push
		+ (away * between(CFG.Out) + Vector3.new(0, between(CFG.Up), 0)) * scatter
	p.AssemblyAngularVelocity = Vector3.new(
		random:NextNumber(-CFG.Spin, CFG.Spin),
		random:NextNumber(-CFG.Spin, CFG.Spin),
		random:NextNumber(-CFG.Spin, CFG.Spin)
	)
end

local function track(p: BasePart, pooled: boolean)
	table.insert(live, {
		part = p,
		born = os.clock(),
		life = between(CFG.LifeSeconds),
		settled = false,
		from = nil,
		depth = p.Size.Magnitude + 0.5,
		pooled = pooled,
	})
end

-- a part for one more brick: a spare one, a new one, or the oldest brick's when the screen is full
local function take(): Part
	while #live >= maxLive do
		free(table.remove(live, 1) :: Brick)
	end
	return table.remove(spare) or newPart()
end

-- a part that isn't a box or a cylinder (a ball, a wedge, a mesh) is thrown whole, as a copy
local function throwCopy(b: Burst, at: Vector3, push: Vector3, scatter: number)
	local source = b.part
	if not source or not source.Parent then
		return
	end
	local ok, copy = pcall(function()
		return source:Clone()
	end)
	if not ok or not copy then
		return
	end
	for _, child in copy:GetChildren() do
		if
			not (child:IsA("DataModelMesh") or child:IsA("Decal") or child:IsA("SurfaceAppearance"))
		then
			child:Destroy()
		end
	end
	while #live >= maxLive do
		free(table.remove(live, 1) :: Brick)
	end
	copy.CFrame = b.cf
	copy.Transparency = b.transparency
	copy.CanCollide = true
	copy.CanQuery = false
	copy.CanTouch = false
	copy.CollisionGroup = "Debris"
	copy.Anchored = false
	copy.Parent = folder
	launch(copy, at, push, scatter)
	track(copy, false)
end

-- throw the broken cells of every burst: `at` is the hit, `push` the velocity they carry on with and `scatter`
-- how hard they fly apart (share of Out and Up; 1 when not given)
function Crumble.throw(bursts: { Burst }, at: Vector3, push: Vector3, scatter: number?)
	local spread = scatter or 1
	local camera = workspace.CurrentCamera
	if not camera or (at - camera.CFrame.Position).Magnitude > CFG.FarStuds then
		return
	end
	for _, b in bursts do
		if b.shape == "Other" then
			throwCopy(b, at, push, spread)
			continue
		end
		local shape = if b.shape == "Cylinder" then Enum.PartType.Cylinder else Enum.PartType.Block
		for _, brick in Crumble.bricks(b) do
			local p = take()
			p.Shape = shape
			p.Size = brick.size
			p.CFrame = brick.cf
			p.Color = shade(b.color)
			p.Material = b.material
			p.Transparency = b.transparency
			p.CanCollide = true
			p.Anchored = false
			launch(p, at, push, spread)
			track(p, true)
		end
	end
end

-- for a whole building coming down (src/client/Collapse): `part` cut into at most `most` anchored bricks
-- standing where it was, for the show to move; nil when it can't be cut (not a plain box), or it's too small
-- to be worth it. Give them back with Crumble.release.
function Crumble.cut(part: BasePart, most: number): { BasePart }?
	if not part:IsA("Part") or part.Shape ~= Enum.PartType.Block or most < 2 then
		return nil
	end
	local size = part.Size
	local _, a, c = Rules.axes(size.X, size.Y, size.Z)
	local s = { size.X, size.Y, size.Z }
	local grid = Rules.grid(s[a], s[c], math.huge, most, CFG)
	if grid.na * grid.nb < 2 then
		return nil
	end
	local b: Burst = {
		cf = part.CFrame,
		size = size,
		color = part.Color,
		material = part.Material,
		transparency = part.Transparency,
		shape = "Block",
		na = grid.na,
		nb = grid.nb,
		fly = Rules.all(grid),
	}
	local out = {}
	for _, brick in Crumble.bricks(b) do
		local p = table.remove(spare) or newPart()
		p.Shape = Enum.PartType.Block
		p.Size = brick.size
		p.CFrame = brick.cf
		p.Color = shade(b.color)
		p.Material = b.material
		p.Transparency = b.transparency
		table.insert(out, p)
	end
	return out
end

function Crumble.release(parts: { BasePart })
	for _, p in parts do
		park(p)
		table.insert(spare, p :: Part)
	end
end

local function step()
	local now = os.clock()
	table.clear(moved)
	table.clear(frames)
	for i = #live, 1, -1 do
		local b = live[i]
		local age = now - b.born
		if age > b.life + CFG.SinkSeconds or not b.part.Parent then
			table.remove(live, i)
			if b.part.Parent then
				free(b)
			end
		elseif age > b.life then
			-- sink out of sight, frozen
			local from = b.from
			if not from then
				b.part.Anchored = true
				b.part.CanCollide = false
				from = b.part.CFrame
				b.from = from
			end
			table.insert(moved, b.part)
			table.insert(
				frames,
				(from :: CFrame) - Vector3.new(0, (age - b.life) / CFG.SinkSeconds * b.depth, 0)
			)
		elseif
			not b.settled
			and age > CFG.SettleAfter
			and b.part.AssemblyLinearVelocity.Magnitude < CFG.SettleSpeed
		then
			-- lying still: freeze it so it costs no physics
			b.settled = true
			b.part.Anchored = true
		end
	end
	if #moved > 0 then
		workspace:BulkMoveTo(moved, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Crumble.start()
	folder.Parent = workspace
	Net.waitFor("Crumble").OnClientEvent:Connect(Crumble.throw)
	RunService.Heartbeat:Connect(step)
end

return Crumble
