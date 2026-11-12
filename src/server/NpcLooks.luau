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
local Game = require(ReplicatedStorage.Shared.Config.Game)
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
	-- picks (0..1) among the classic items, read when dressing: people are rolled before the items load
	face: number,
	clothes: { shirt: number, pants: number }?, -- casual people only; uniforms are painted on
	hat: number?, -- a catalog hat instead of hair
}

-- the classic clothes, faces and hats from Config/Crowd, loaded once in init
local shirtTemplates: { string } = {}
local pantsTemplates: { string } = {}
local faceTextures: { string } = {}
local hats: { Accessory } = {}

local storage = Instance.new("Folder")
storage.Name = "NpcPool"
storage.Parent = ServerStorage

local base: Model? = nil
local hairs: { Accessory } = {}
local spare: { Model } = {}
local friendSpare: { [number]: { Model } } = {}
-- which friend each friend character wears; kept on the server so the friend's user id never replicates
local friendOfModel: { [Model]: number } = {}
local friendKeys: { [number]: number } = {} -- friend user id -> a small key the clients see instead
local nextFriendKey = 0
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
			face = 0,
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
			face = 0,
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
			face = 0,
		}
	elseif outfit == "shop" then
		-- casual clothes under the shop's apron
		look = NpcLooks.roll("casual")
		look.apron = rgb(pick(Crowd.Shop.Aprons))
		look.cap = nil
		look.hat = nil
	else
		local c = Crowd.Casual
		local shirt = rgb(pick(c.Shirts))
		local hat = if random:NextNumber() < Crowd.Avatar.HatChance
			then random:NextNumber()
			else nil
		look = {
			skin = skin,
			shirt = shirt,
			sleeves = if random:NextNumber() < c.ShortSleeves then skin else shirt,
			upperArms = shirt,
			pants = rgb(pick(c.Pants)),
			shoes = rgb(pick(c.Shoes)),
			-- a hat sits on the hairline, so hair under it would poke through
			hair = if hat then 0 else random:NextInteger(0, #Crowd.Hair),
			face = 0,
			clothes = { shirt = random:NextNumber(), pants = random:NextNumber() },
			hat = hat,
		}
	end
	look.face = random:NextNumber()
	return look
end

-- humanoid settings every crowd character gets
local function prepare(model: Model, displayName: string?, nameRange: number)
	model.Name = "Npc"
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = World.Npc.WalkSpeed
	humanoid.DisplayName = displayName or "Pedestrian"
	-- name tags are drawn by each player's client (client/NameTags), so Roblox's own stays off
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
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
		model:SetAttribute("AnimSit", id("sit", "SitAnim"))
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
	local A = Crowd.Avatar
	-- the classic head and clothes, read off throwaway characters (one per row of items)
	for i = 1, math.max(#A.Shirts, #A.Pants, #A.Faces, #A.Hats) do
		local dd = Instance.new("HumanoidDescription")
		dd.Head = A.Head
		dd.Shirt = A.Shirts[i] or 0
		dd.Pants = A.Pants[i] or 0
		dd.Face = A.Faces[i] or 0
		dd.HatAccessory = if A.Hats[i] then tostring(A.Hats[i]) else ""
		local donor = build(dd)
		if donor then
			donor:ScaleTo(Game.BodyScale)
			local shirt = donor:FindFirstChildOfClass("Shirt")
			if A.Shirts[i] and shirt and shirt.ShirtTemplate ~= "" then
				table.insert(shirtTemplates, shirt.ShirtTemplate)
			end
			local trousers = donor:FindFirstChildOfClass("Pants")
			if A.Pants[i] and trousers and trousers.PantsTemplate ~= "" then
				table.insert(pantsTemplates, trousers.PantsTemplate)
			end
			local head = donor:FindFirstChild("Head")
			local face = head and head:FindFirstChildOfClass("Decal")
			if A.Faces[i] and face and face.Texture ~= "" then
				table.insert(faceTextures, face.Texture)
			end
			local hat = A.Hats[i] and donor:FindFirstChildOfClass("Accessory")
			if hat then
				hat.Parent = storage
				for _, p in hat:GetDescendants() do
					if p:IsA("BasePart") then
						p.CollisionGroup = "Npcs"
						p.CanQuery = false
						p.CanTouch = false
						p.Massless = true
					end
				end
				table.insert(hats, hat)
			end
			donor:Destroy()
		end
	end
	if #shirtTemplates < #A.Shirts or #pantsTemplates < #A.Pants or #faceTextures < #A.Faces then
		warn(
			`[NpcLooks] classic items loaded: {#shirtTemplates} shirts, {#pantsTemplates} pants, {#faceTextures} faces`
		)
	end

	local d = Instance.new("HumanoidDescription")
	d.Head = A.Head
	local model = build(d)
	if model then
		prepare(model, nil, 0)
		model:SetAttribute("AnimIdle", nil)
		model:SetAttribute("AnimIdle2", nil)
		model:SetAttribute("AnimWalk", nil)
		model:SetAttribute("AnimRun", nil)
		model:SetAttribute("AnimFall", nil)
		model:SetAttribute("AnimSit", nil)
		for _, a in model:GetChildren() do
			if
				a:IsA("Accessory")
				or a:IsA("Clothing")
				or a:IsA("ShirtGraphic")
				or a:IsA("BodyColors")
			then
				a:Destroy()
			end
		end
		-- the city's people are as big as the players (Game.BodyScale); so is every copy of this one
		model:ScaleTo(Game.BodyScale)
		base = model
	else
		warn("[NpcLooks] couldn't build the base character")
	end
	for _, id in Crowd.Hair do
		local hd = Instance.new("HumanoidDescription")
		hd.HairAccessory = tostring(id)
		local donor = build(hd)
		if donor then
			donor:ScaleTo(Game.BodyScale) -- the hair grows with the head it was made for
		end
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

-- the item a 0..1 pick lands on
local function chosen<T>(list: { T }, at: number): T
	return list[math.min(#list, math.floor(at * #list) + 1)]
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
	local head = model:FindFirstChild("Head") :: BasePart?
	if head and #faceTextures > 0 then
		local faceDecal = head:FindFirstChildOfClass("Decal")
		if not faceDecal then
			faceDecal = Instance.new("Decal")
			faceDecal.Name = "face"
			faceDecal.Face = Enum.NormalId.Front
			faceDecal.Parent = head
		end
		(faceDecal :: Decal).Texture = chosen(faceTextures, look.face)
	end
	-- classic clothes go over skin-coloured limbs; uniforms are painted onto the body parts
	local clothes = if #shirtTemplates > 0 and #pantsTemplates > 0 then look.clothes else nil
	local shirt = model:FindFirstChildOfClass("Shirt")
	local trousers = model:FindFirstChildOfClass("Pants")
	if clothes then
		if not shirt then
			shirt = Instance.new("Shirt")
			shirt.Parent = model
		end
		if not trousers then
			trousers = Instance.new("Pants")
			trousers.Parent = model
		end
		(shirt :: Shirt).ShirtTemplate = chosen(shirtTemplates, clothes.shirt);
		(trousers :: Pants).PantsTemplate = chosen(pantsTemplates, clothes.pants)
		for _, names in { { "Head", "UpperTorso" }, HANDS, ARM_UPPER, ARM_LOWER, LEGS, FEET } do
			paint(model, names, look.skin)
		end
	else
		if shirt then
			shirt:Destroy()
		end
		if trousers then
			trousers:Destroy()
		end
		paint(model, { "Head" }, look.skin)
		paint(model, HANDS, look.skin)
		paint(model, { "UpperTorso" }, look.shirt)
		paint(model, ARM_UPPER, look.upperArms)
		paint(model, ARM_LOWER, look.sleeves)
		paint(model, LEGS, look.pants)
		paint(model, FEET, look.shoes)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	if look.hat and #hats > 0 then
		humanoid:AddAccessory(chosen(hats, look.hat):Clone())
	elseif look.hair > 0 and look.hair <= #hairs and not look.cap then
		humanoid:AddAccessory(hairs[look.hair]:Clone())
	end
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
-- the key a friend's characters carry (attribute FriendKey); only that friend's own players learn the name
function NpcLooks.friendKey(userId: number): number
	local key = friendKeys[userId]
	if not key then
		nextFriendKey += 1
		key = nextFriendKey
		friendKeys[userId] = key
	end
	return key
end

-- the friend user id a character wears, or nil for an ordinary person
function NpcLooks.friendId(model: Model): number?
	return friendOfModel[model]
end

function NpcLooks.takeFriend(userId: number): Model?
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
				-- no name on the character itself: everyone else sees a plain pedestrian
				prepare(model, nil, World.Npc.FriendNameRange)
				model:ScaleTo(Game.BodyScale)
				friendOfModel[model] = userId
				model:SetAttribute("FriendKey", NpcLooks.friendKey(userId))
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
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = false -- it may have been sitting
	if math.abs(model:GetScale() - Game.BodyScale) > 1e-3 then
		model:ScaleTo(Game.BodyScale) -- a giant back to everyday size
	end
	local glow = model:FindFirstChild("GoldenGlow")
	if glow then
		glow:Destroy()
	end
	local friendId = friendOfModel[model]
	model.Parent = storage
	if friendId then
		friendSpare[friendId] = friendSpare[friendId] or {}
		table.insert(friendSpare[friendId], model)
	elseif #spare < Crowd.PoolSpare + Crowd.MaxActive then
		table.insert(spare, model)
	else
		model:Destroy()
	end
end

function NpcLooks.forget(model: Model)
	if friendOfModel[model] then
		friendRigs -= 1
		friendOfModel[model] = nil
	end
end

return NpcLooks
