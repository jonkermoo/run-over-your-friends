--!strict
-- What people look like. Ordinary people are clones of one base character, dressed by colouring body parts
-- (skin, shirt, sleeves, trousers, shoes) and adding hair and simple worn pieces (a cap, an apron, a
-- hi-vis vest, a tie), so one spare character can be re-dressed as anyone in an instant. Friends are built
-- from their own avatars and keep their own animations (read from the avatar's Animate script and stored
-- as attributes for the client). Spare characters wait in ServerStorage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Crowd = require(ReplicatedStorage.Shared.Config.Crowd)
local World = require(ReplicatedStorage.Shared.Config.World)

local NpcLooks = {}

export type Look = {
	skin: Color3,
	shirt: Color3,
	sleeves: Color3, -- lower arms: shirt colour (long sleeves) or skin
	upperArms: Color3,
	pants: Color3,
	shoes: Color3,
	hair: number, -- index into the hair list, 0 = none
	cap: Color3?,
	apron: Color3?,
	vest: Color3?,
	stripe: Color3?,
	tie: Color3?,
	shirtFront: Color3?, -- under an open jacket
}

local storage = Instance.new("Folder")
storage.Name = "NpcPool"
storage.Parent = ServerStorage

local base: Model? = nil
local hairs: { Accessory } = {}
local spare: { Model } = {}
local friendSpare: { [number]: { Model } } = {}
local friendRigs = 0
local descriptions: { [number]: HumanoidDescription | false } = {}
local loading: { [number]: boolean } = {}
local random = Random.new()

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function pick<T>(list: { T }): T
	return list[random:NextInteger(1, #list)]
end

-- a fresh outfit for someone of this kind
function NpcLooks.roll(outfit: string): Look
	local skin = rgb(pick(Crowd.Skin))
	local look: Look
	if outfit == "food" then
		local f = Crowd.Food
		look = {
			skin = skin,
			shirt = rgb(f.Shirt),
			sleeves = skin,
			upperArms = rgb(f.Shirt),
			pants = rgb(f.Pants),
			shoes = Color3.fromRGB(30, 30, 34),
			hair = 0,
			cap = rgb(f.Cap),
			apron = rgb(f.Apron),
		}
	elseif outfit == "warehouse" then
		local w = Crowd.Warehouse
		local shirt = rgb(pick(w.Shirts))
		look = {
			skin = skin,
			shirt = shirt,
			sleeves = if random:NextNumber() < 0.5 then skin else shirt,
			upperArms = shirt,
			pants = rgb(pick(w.Pants)),
			shoes = Color3.fromRGB(90, 66, 44),
			hair = random:NextInteger(0, #Crowd.Hair),
			vest = rgb(w.Vest),
			stripe = rgb(w.Stripe),
		}
	elseif outfit == "office" then
		local o = Crowd.Office
		local shirt = rgb(pick(o.Shirts))
		local pants = rgb(pick(o.Pants))
		local jacket = random:NextNumber() < o.JacketChance
		look = {
			skin = skin,
			shirt = if jacket then pants else shirt,
			sleeves = if jacket then pants else shirt,
			upperArms = if jacket then pants else shirt,
			pants = pants,
			shoes = Color3.fromRGB(24, 24, 26),
			hair = random:NextInteger(1, #Crowd.Hair),
			tie = rgb(pick(o.Ties)),
			shirtFront = if jacket then shirt else nil,
		}
	else
		local c = Crowd.Casual
		local shirt = rgb(pick(c.Shirts))
		look = {
			skin = skin,
			shirt = shirt,
			sleeves = if random:NextNumber() < c.ShortSleeves then skin else shirt,
			upperArms = shirt,
			pants = rgb(pick(c.Pants)),
			shoes = rgb(pick(c.Shoes)),
			hair = random:NextInteger(0, #Crowd.Hair),
			cap = if random:NextNumber() < c.CapChance then rgb(pick(c.Shirts)) else nil,
		}
	end
	return look
end

-- humanoid settings every crowd character gets
local function prepare(model: Model, displayName: string?, nameRange: number)
	model.Name = "Npc"
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = World.Npc.WalkSpeed
	humanoid.DisplayName = displayName or "Pedestrian"
	humanoid.DisplayDistanceType = if displayName
		then Enum.HumanoidDisplayDistanceType.Viewer
		else Enum.HumanoidDisplayDistanceType.None
	humanoid.NameDisplayDistance = nameRange
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	for _, state in
		{
			Enum.HumanoidStateType.Climbing,
			Enum.HumanoidStateType.Swimming,
			Enum.HumanoidStateType.Seated,
			Enum.HumanoidStateType.Flying,
			Enum.HumanoidStateType.Jumping,
			Enum.HumanoidStateType.StrafingNoPhysics,
		}
	do
		humanoid:SetStateEnabled(state, false)
	end
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	-- the avatar's own Animate script can't run on a server character; its animation ids go to attributes
	local animate = model:FindFirstChild("Animate")
	if animate then
		local function id(slot: string, name: string): string?
			local folder = animate:FindFirstChild(slot)
			local anim = folder and folder:FindFirstChild(name)
			return if anim and anim:IsA("Animation") then anim.AnimationId else nil
		end
		model:SetAttribute("AnimIdle", id("idle", "Animation1"))
		model:SetAttribute("AnimIdle2", id("idle", "Animation2"))
		model:SetAttribute("AnimWalk", id("walk", "WalkAnim"))
		model:SetAttribute("AnimRun", id("run", "RunAnim"))
		model:SetAttribute("AnimFall", id("fall", "FallAnim"))
		animate:Destroy()
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Npcs"
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
end

local function build(desc: HumanoidDescription): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	return if ok then model else nil
end

-- the base character and the hair pieces; call once (yields while avatars load)
function NpcLooks.init()
	local d = Instance.new("HumanoidDescription")
	local model = build(d)
	if model then
		prepare(model, nil, 0)
		model:SetAttribute("AnimIdle", nil)
		model:SetAttribute("AnimIdle2", nil)
		model:SetAttribute("AnimWalk", nil)
		model:SetAttribute("AnimRun", nil)
		model:SetAttribute("AnimFall", nil)
		for _, a in model:GetChildren() do
			if a:IsA("Accessory") or a:IsA("Shirt") or a:IsA("Pants") or a:IsA("ShirtGraphic") then
				a:Destroy()
			end
		end
		base = model
	else
		warn("[NpcLooks] couldn't build the base character")
	end
	for _, id in Crowd.Hair do
		local hd = Instance.new("HumanoidDescription")
		hd.HairAccessory = tostring(id)
		local donor = build(hd)
		local acc = donor and donor:FindFirstChildOfClass("Accessory")
		if acc then
			acc.Parent = storage
			for _, p in acc:GetDescendants() do
				if p:IsA("BasePart") then
					p.CollisionGroup = "Npcs"
					p.CanQuery = false
					p.CanTouch = false
					p.Massless = true
				end
			end
			table.insert(hairs, acc)
		else
			warn(`[NpcLooks] hair {id} didn't load`)
		end
		if donor then
			donor:Destroy()
		end
	end
end

function NpcLooks.hairCount(): number
	return #hairs
end

local ARM_UPPER = { "LeftUpperArm", "RightUpperArm" }
local ARM_LOWER = { "LeftLowerArm", "RightLowerArm" }
local HANDS = { "LeftHand", "RightHand" }
local LEGS = { "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LowerTorso" }
local FEET = { "LeftFoot", "RightFoot" }

local function paint(model: Model, names: { string }, color: Color3)
	for _, n in names do
		local p = model:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			p.Color = color
		end
	end
end

local function gear(
	model: Model,
	on: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	name: string
)
	local body = model:FindFirstChild(on) :: BasePart?
	if not body then
		return
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CollisionGroup = "Npcs"
	p.CFrame = body.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = body
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	p.Parent = model:FindFirstChild("Gear") or model
end

-- put an outfit on an ordinary character
function NpcLooks.dress(model: Model, look: Look)
	local old = model:FindFirstChild("Gear")
	if old then
		old:Destroy()
	end
	for _, a in model:GetChildren() do
		if a:IsA("Accessory") then
			a:Destroy()
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "Gear"
	folder.Parent = model
	paint(model, { "Head" }, look.skin)
	paint(model, HANDS, look.skin)
	paint(model, { "UpperTorso" }, look.shirt)
	paint(model, ARM_UPPER, look.upperArms)
	paint(model, ARM_LOWER, look.sleeves)
	paint(model, LEGS, look.pants)
	paint(model, FEET, look.shoes)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	if look.hair > 0 and look.hair <= #hairs and not look.cap then
		humanoid:AddAccessory(hairs[look.hair]:Clone())
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	local torso = model:FindFirstChild("UpperTorso") :: BasePart?
	local hips = model:FindFirstChild("LowerTorso") :: BasePart?
	if head and look.cap then
		local hs = head.Size
		gear(
			model,
			"Head",
			Vector3.new(hs.X * 1.06, hs.Y * 0.36, hs.Z * 1.06),
			CFrame.new(0, hs.Y * 0.42, 0),
			look.cap,
			"Cap"
		)
		gear(
			model,
			"Head",
			Vector3.new(hs.X * 0.9, 0.1, hs.Z * 0.55),
			CFrame.new(0, hs.Y * 0.3, -hs.Z * 0.62),
			look.cap,
			"Brim"
		)
	end
	if torso then
		local ts = torso.Size
		if look.vest then
			gear(
				model,
				"UpperTorso",
				ts + Vector3.new(0.1, -0.1, 0.1),
				CFrame.new(),
				look.vest,
				"Vest"
			)
			gear(
				model,
				"UpperTorso",
				Vector3.new(ts.X + 0.14, 0.2, ts.Z + 0.14),
				CFrame.new(0, -ts.Y * 0.18, 0),
				look.stripe or Color3.new(1, 1, 1),
				"Stripe"
			)
		end
		if look.shirtFront then
			gear(
				model,
				"UpperTorso",
				Vector3.new(ts.X * 0.32, ts.Y * 0.96, 0.05),
				CFrame.new(0, 0, -ts.Z / 2 - 0.01),
				look.shirtFront,
				"ShirtFront"
			)
		end
		if look.tie then
			gear(
				model,
				"UpperTorso",
				Vector3.new(0.24, ts.Y * 0.72, 0.06),
				CFrame.new(0, -ts.Y * 0.08, -ts.Z / 2 - 0.05),
				look.tie,
				"Tie"
			)
		end
	end
	if hips and look.apron then
		local ls = hips.Size
		gear(
			model,
			"LowerTorso",
			Vector3.new(ls.X * 0.95, ls.Y + 0.9, 0.1),
			CFrame.new(0, -0.4, -ls.Z / 2 - 0.06),
			look.apron,
			"Apron"
		)
	end
end

-- a spare ordinary character (dress it before use); nil before init has finished
function NpcLooks.take(): Model?
	local m = table.remove(spare)
	if m then
		return m
	end
	if not base then
		return nil
	end
	return (base :: Model):Clone()
end

-- a friend's character if one is ready; starts building one if not (returns nil meanwhile)
function NpcLooks.takeFriend(userId: number, name: string, friendOf: string): Model?
	local list = friendSpare[userId]
	local m = list and table.remove(list)
	if m then
		return m
	end
	if loading[userId] or descriptions[userId] == false or friendRigs >= Crowd.FriendRigsMax then
		return nil
	end
	loading[userId] = true
	task.spawn(function()
		local desc = descriptions[userId]
		if desc == nil then
			local ok, result = pcall(function()
				return Players:GetHumanoidDescriptionFromUserId(userId)
			end)
			desc = if ok and result then result else false
			descriptions[userId] = desc
		end
		if desc then
			local model = build(desc :: HumanoidDescription)
			if model then
				prepare(model, `{name}  ·  friend of {friendOf}`, World.Npc.FriendNameRange)
				model:SetAttribute("FriendId", userId)
				model.Parent = storage
				friendSpare[userId] = friendSpare[userId] or {}
				table.insert(friendSpare[userId], model)
				friendRigs += 1
			end
		end
		loading[userId] = nil
	end)
	return nil
end

-- clear what a character picked up while out (glow, attributes) and put it away for reuse
function NpcLooks.give(model: Model)
	if not (model:FindFirstChild("HumanoidRootPart") and model:FindFirstChild("Head")) then
		NpcLooks.forget(model)
		model:Destroy()
		return
	end
	for _, name in { "Down", "Golden", "GiantHp", "Gait" } do
		model:SetAttribute(name, nil)
	end
	local glow = model:FindFirstChild("GoldenGlow")
	if glow then
		glow:Destroy()
	end
	local friendId = model:GetAttribute("FriendId")
	model.Parent = storage
	if typeof(friendId) == "number" then
		friendSpare[friendId] = friendSpare[friendId] or {}
		table.insert(friendSpare[friendId], model)
	elseif #spare < Crowd.PoolSpare + Crowd.MaxActive then
		table.insert(spare, model)
	else
		model:Destroy()
	end
end

function NpcLooks.forget(model: Model)
	local friendId = model:GetAttribute("FriendId")
	if typeof(friendId) == "number" then
		friendRigs -= 1
	end
end

return NpcLooks
