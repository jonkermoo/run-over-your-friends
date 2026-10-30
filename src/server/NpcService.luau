--!strict
-- Friend NPCs: pedestrians wearing the avatars of the players' friends. They wander the sidewalks;
-- a vehicle hit (reported by the driver's client, checked here) ragdolls and launches them and pays money.
-- Also the taxi call, the ice-cream jingle and the fire-truck cannon.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Impact = require(ReplicatedStorage.Shared.Rules.Impact)
local Net = require(ReplicatedStorage.Shared.Net)
local EventConfig = require(ReplicatedStorage.Shared.Config.Events)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Ragdoll = require(ReplicatedStorage.Shared.Ragdoll)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local World = require(ReplicatedStorage.Shared.Config.World)
local Analytics = require(script.Parent.Analytics)
local Data = require(script.Parent.Data)
local Passes = require(script.Parent.Passes)
local VehicleService = require(script.Parent.VehicleService)

local NpcService = {}
local CFG = World.Npc

local folder = Instance.new("Folder")
folder.Name = "Npcs"
folder.Parent = workspace

type Friend = { userId: number, name: string, friendOf: string }
local pool: { Friend } = {}
local poolIds: { [number]: boolean } = {}
local descriptions: { [number]: HumanoidDescription } = {}
local walkPoints: { Vector3 } = {}
type NpcState = {
	target: Vector3?,
	busyUntil: number,
	lastPaid: { [Player]: number },
	crowd: boolean,
}
local npcs: { [Model]: NpcState } = {}
local crowdPoints: { Vector3 } = {} -- the spawn plaza: a crowd always waits here, so a first hit comes fast
local knockListeners: { (Player, number) -> () } = {}
local launchListeners: { (Player, number) -> () } = {}
local combos: { [Player]: { count: number, last: number } } = {}
local lastCall: { [Player]: { [string]: number } } = {}
local random = Random.new()

local function rateOk(player: Player, key: string, interval: number): boolean
	local t = lastCall[player]
	if not t then
		t = {}
		lastCall[player] = t
	end
	local now = os.clock()
	if (t[key] or 0) + interval > now then
		return false
	end
	t[key] = now
	return true
end

local function addFriends(player: Player)
	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if not ok or not pages then
		return
	end
	for _ = 1, 3 do
		for _, f in (pages :: FriendPages):GetCurrentPage() do
			if not poolIds[f.Id] then
				poolIds[f.Id] = true
				table.insert(
					pool,
					{ userId = f.Id, name = f.DisplayName, friendOf = player.DisplayName }
				)
			end
		end
		if (pages :: FriendPages).IsFinished then
			break
		end
		local more = pcall(function()
			(pages :: FriendPages):AdvanceToNextPageAsync()
		end)
		if not more then
			break
		end
	end
end

local SKIN = {
	Color3.fromRGB(255, 220, 190),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(196, 140, 98),
	Color3.fromRGB(124, 84, 58),
}
local SHIRT = {
	Color3.fromRGB(52, 120, 200),
	Color3.fromRGB(200, 60, 60),
	Color3.fromRGB(60, 160, 90),
	Color3.fromRGB(230, 190, 60),
	Color3.fromRGB(120, 80, 170),
}

local function fallbackDescription(): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	local skin = SKIN[random:NextInteger(1, #SKIN)]
	d.HeadColor, d.LeftArmColor, d.RightArmColor = skin, skin, skin
	d.TorsoColor = SHIRT[random:NextInteger(1, #SHIRT)]
	local legs = Color3.fromRGB(40 + random:NextInteger(0, 40), 50, 70)
	d.LeftLegColor, d.RightLegColor = legs, legs
	return d
end

local function pickWalkPoint(near: Vector3?, crowd: boolean?): Vector3
	if crowd and #crowdPoints > 0 then
		return crowdPoints[random:NextInteger(1, #crowdPoints)]
	end
	if #walkPoints == 0 then
		return Vector3.new(0, 3, 0)
	end
	if near then
		for _ = 1, 8 do
			local p = walkPoints[random:NextInteger(1, #walkPoints)]
			if (p - near).Magnitude < 160 then
				return p
			end
		end
	end
	return walkPoints[random:NextInteger(1, #walkPoints)]
end

local function spawnNpc(crowd: boolean?): Model?
	local friend: Friend? = if #pool > 0 then pool[random:NextInteger(1, #pool)] else nil
	local desc: HumanoidDescription? = nil
	if friend then
		desc = descriptions[friend.userId]
		if not desc then
			local ok, result = pcall(function()
				return Players:GetHumanoidDescriptionFromUserId(friend.userId)
			end)
			if ok and result then
				descriptions[friend.userId] = result
				desc = result
			end
		end
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(
			desc or fallbackDescription(),
			Enum.HumanoidRigType.R15
		)
	end)
	if not ok or not model then
		return
	end
	local npc = model :: Model
	npc.Name = "Npc"
	local humanoid = npc:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = CFG.WalkSpeed
	humanoid.DisplayName = if friend
		then `{friend.name}  ·  friend of {friend.friendOf}`
		else "Pedestrian"
	humanoid.NameDisplayDistance = CFG.FriendNameRange
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	for _, d in npc:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Npcs"
		end
	end
	local at = pickWalkPoint(nil, crowd)
	npc:PivotTo(
		CFrame.new(at + Vector3.new(0, 3, 0))
			* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	)
	npc.Parent = folder
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	npcs[npc] = { target = nil, busyUntil = 0, lastPaid = {}, crowd = crowd == true }
	if
		workspace:GetAttribute("Event") == "GoldenRush"
		and random:NextNumber() < EventConfig.GoldenRespawnChance
	then
		NpcService.makeGolden(npc)
	end
	return npc
end

-- a golden pedestrian (Golden Rush) pays several times over
function NpcService.makeGolden(npc: Model)
	if npc:GetAttribute("Golden") or npc:GetAttribute("GiantHp") then
		return
	end
	npc:SetAttribute("Golden", true)
	local h = Instance.new("Highlight")
	h.Name = "GoldenGlow"
	h.FillColor = Color3.fromRGB(255, 205, 60)
	h.FillTransparency = 0.35
	h.OutlineColor = Color3.fromRGB(255, 240, 160)
	h.Parent = npc
end

function NpcService.clearGolden()
	for npc in npcs do
		npc:SetAttribute("Golden", nil)
		local h = npc:FindFirstChild("GoldenGlow")
		if h then
			h:Destroy()
		end
	end
end

function NpcService.all(): { Model }
	local out = {}
	for npc in npcs do
		if not npc:GetAttribute("Down") then
			table.insert(out, npc)
		end
	end
	return out
end

-- a giant (Giant in Town): a normal pedestrian scaled up that takes several hits to topple
function NpcService.spawnGiant(at: Vector3): Model?
	local npc = spawnNpc(false)
	if not npc then
		return nil
	end
	npc:ScaleTo(EventConfig.GiantScale)
	npc:PivotTo(CFrame.new(at + Vector3.new(0, 4 * EventConfig.GiantScale, 0)))
	npc:SetAttribute("GiantHp", EventConfig.GiantHits)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 14
		humanoid.DisplayName = `GIANT {humanoid.DisplayName}   ({EventConfig.GiantHits} hits)`
		humanoid.NameDisplayDistance = 400
	end
	return npc
end

-- knock an NPC down and send it flying; pays `share` of the hit to `player` (if any)
function NpcService.knock(
	npc: Model,
	velocity: Vector3,
	energy: number,
	player: Player?,
	share: number
)
	local state = npcs[npc]
	if not state or npc:GetAttribute("Down") then
		return
	end
	npc:SetAttribute("Down", true)
	Ragdoll.enable(npc)
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.AssemblyLinearVelocity = velocity
		root.AssemblyAngularVelocity = Vector3.new(
			random:NextNumber(-8, 8),
			random:NextNumber(-8, 8),
			random:NextNumber(-8, 8)
		)
	end
	local comboCount = 0
	if player and share > 0 then
		local now = os.clock()
		local combo = combos[player]
		if not combo or now - combo.last > Economy.ComboWindow then
			combo = { count = 0, last = now }
			combos[player] = combo
		end
		combo.count += 1
		combo.last = now
		comboCount = combo.count
		local pay = Impact.npcPayout(energy, combo.count, Economy) * share
		if (state.lastPaid[player] or -math.huge) + Economy.RepeatWindow > now then
			pay *= 0.5
		end
		state.lastPaid[player] = now
		if npc:GetAttribute("Golden") then
			pay *= EventConfig.GoldenMultiplier
		end
		if workspace:GetAttribute("Event") == "Stampede" then
			pay *= EventConfig.StampedeMultiplier
		end
		if Passes.has(player, "DoubleMoney") then
			pay *= Economy.DoubleMoney
		end
		Data.addMoney(player, pay)
		local text = "+$" .. tostring(math.floor(pay + 0.5))
		if combo.count > 1 then
			text ..= `  x{string.format(
				"%.1f",
				Impact.comboMultiplier(combo.count, Economy.ComboStep, Economy.ComboMax)
			)} COMBO`
		end
		Net.remote("Popup"):FireClient(player, text, "money")
		for _, listener in knockListeners do
			task.spawn(listener, player, combo.count)
		end
		-- how far they flew, for the launch goals
		if root then
			task.spawn(function()
				local start = root.Position * Vector3.new(1, 0, 1)
				local far = 0
				for _ = 1, 20 do
					task.wait(0.15)
					if not root.Parent then
						break
					end
					far = math.max(far, (root.Position * Vector3.new(1, 0, 1) - start).Magnitude)
				end
				for _, listener in launchListeners do
					task.spawn(listener, player, far)
				end
				if root.Parent and far > 15 then
					Net.remote("Fx")
						:FireClient(player, "Land", root.Position, far, 0, player.UserId)
				end
			end)
		end
	end
	if root then
		-- everyone nearby hears and sees it; the hitter's screen shakes
		Net.remote("Fx"):FireAllClients(
			"Hit",
			root.Position,
			Impact.strength(energy, 3000, 20000000),
			comboCount,
			if player then player.UserId else 0
		)
	end
	task.delay(World.Npc.RespawnSeconds, function()
		npcs[npc] = nil
		npc:Destroy()
		spawnNpc(state.crowd)
	end)
end

function NpcService.inRadius(pos: Vector3, radius: number): { Model }
	local out = {}
	for npc in npcs do
		local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and not npc:GetAttribute("Down") and (root.Position - pos).Magnitude <= radius then
			table.insert(out, npc)
		end
	end
	return out
end

local function onHit(player: Player, npc: unknown, velocity: unknown)
	if
		typeof(npc) ~= "Instance"
		or not npc:IsA("Model")
		or npc.Parent ~= folder
		or typeof(velocity) ~= "Vector3"
	then
		return
	end
	-- a knocked-down NPC can't be hit again, so a plain rate limit is enough here
	if velocity ~= velocity or not rateOk(player, "hit", 0.04) then
		return
	end
	local vehicle = VehicleService.of(player)
	local stats = vehicle and VehicleService.stats(vehicle)
	local chassis = vehicle and vehicle.PrimaryPart
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (vehicle and stats and chassis and root) then
		return
	end
	local spm = Vehicles.StudsPerMetre
	-- trust the client's speed only up to what this vehicle can do (plus the Roadster's jet)
	local maxStuds = stats.topSpeed
			/ 2.237
			* spm
			* (if Vehicles.has(stats, "Jet") then 1.45 else 1.2)
		+ 10
	local speed = math.min(velocity.Magnitude, maxStuds)
	local giantHp = npc:GetAttribute("GiantHp")
	local reach = chassis.Size.Magnitude / 2
		+ 14
		+ speed * 0.3
		+ (if typeof(giantHp) == "number" then 6 * EventConfig.GiantScale else 0)
	if (root.Position - chassis.Position).Magnitude > reach then
		return
	end
	local metres = speed / spm
	if metres < Economy.MinHitSpeed then
		return
	end
	local energy = Impact.energy(stats.weight, metres)
	local dir = if speed > 0.1 then velocity.Unit else chassis.CFrame.LookVector
	if Vehicles.has(stats, "Plow") then
		-- the blade throws people aside
		local side = chassis.CFrame.RightVector
		if (root.Position - chassis.Position):Dot(side) < 0 then
			side = -side
		end
		dir = (side * 0.8 + dir * 0.4).Unit
	end
	if typeof(giantHp) == "number" and giantHp > 1 then
		if not rateOk(player, "giant", 0.8) then
			return
		end
		npc:SetAttribute("GiantHp", giantHp - 1)
		local humanoid = npc:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayName =
				string.gsub(humanoid.DisplayName, "%(%d+ hits%)", `({giantHp - 1} hits)`)
		end
		root.AssemblyLinearVelocity += (dir * Vector3.new(1, 0, 1)) * 40
		local pay = EventConfig.GiantHitPay
			* (if Passes.has(player, "DoubleMoney") then Economy.DoubleMoney else 1)
		Data.addMoney(player, pay)
		Net.remote("Popup"):FireClient(player, `+${pay}  GIANT HIT!`, "big")
		Net.remote("Fx"):FireAllClients("Hit", root.Position, 1, 0, player.UserId)
		return
	end
	if typeof(giantHp) == "number" then
		Data.addMoney(player, EventConfig.GiantToppleBonus)
		Analytics.custom(player, "GiantToppled")
		for _, everyone in Players:GetPlayers() do
			Net.remote("Celebrate")
				:FireClient(everyone, "GIANT TOPPLED!", `{player.DisplayName} brought it down.`)
		end
	end
	local launch = Impact.launchSpeed(energy)
	NpcService.knock(
		npc,
		(dir * Vector3.new(1, 0, 1) + Vector3.new(0, 0.6, 0)).Unit * launch,
		energy,
		player,
		1
	)
end

local function bubble(part: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 60)
	gui.StudsOffset = Vector3.new(0, part.Size.Y + 6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	gui.Parent = part
	task.delay(2, gui.Destroy, gui)
end

local function walkTo(npc: Model, pos: Vector3, seconds: number, run: boolean)
	local state = npcs[npc]
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if state and humanoid then
		state.target = pos
		state.busyUntil = os.clock() + seconds
		humanoid.WalkSpeed = if run then CFG.WalkSpeed * 2.2 else CFG.WalkSpeed
		humanoid:MoveTo(pos)
	end
end

local function onFeature(player: Player, feature: unknown)
	if typeof(feature) ~= "string" then
		return
	end
	local vehicle = VehicleService.of(player)
	local stats = vehicle and VehicleService.stats(vehicle)
	local chassis = vehicle and vehicle.PrimaryPart
	if not (vehicle and stats and chassis and Vehicles.has(stats, feature :: any)) then
		return
	end
	if feature == "Taxi" and rateOk(player, "Taxi", 2) then
		bubble(chassis, "TAXI!")
		local best, bestD = nil, CFG.TaxiRange
		for _, npc in NpcService.inRadius(chassis.Position, CFG.TaxiRange) do
			local d = (npc:GetPivot().Position - chassis.Position).Magnitude
			if d < bestD and (npcs[npc].busyUntil < os.clock()) then
				best, bestD = npc, d
			end
		end
		if best then
			bubble((best :: Model):FindFirstChild("Head") :: BasePart, "Me! Me!")
			for i = 0, 10 do
				task.delay(i * 0.6, function()
					if best.Parent and chassis.Parent and not best:GetAttribute("Down") then
						walkTo(best, chassis.Position, 1, true)
					end
				end)
			end
		end
	elseif feature == "Jingle" and rateOk(player, "Jingle", 4) then
		bubble(chassis, "♪ ♫ ♪")
		local s = chassis:FindFirstChild("Jingle") :: Sound?
		if s then
			s:Play()
		end
		for _, npc in NpcService.inRadius(chassis.Position, CFG.JingleRange) do
			for i = 0, math.floor(CFG.JingleSeconds / 0.8) do
				task.delay(i * 0.8, function()
					if npc.Parent and chassis.Parent and not npc:GetAttribute("Down") then
						walkTo(npc, chassis.Position, 1, false)
					end
				end)
			end
		end
	elseif feature == "Cannon" and rateOk(player, "Cannon", 0.25) then
		local look = chassis.CFrame.LookVector
		for _, npc in NpcService.inRadius(chassis.Position, CFG.CannonRange) do
			local to = npc:GetPivot().Position - chassis.Position
			if to.Unit:Dot(look) > CFG.CannonCone then
				NpcService.knock(
					npc,
					(look + Vector3.new(0, 0.5, 0)).Unit * 70,
					200000,
					player,
					Economy.CannonShare
				)
			end
		end
	end
end

function NpcService.setWalkPoints(points: { Vector3 }, crowd: { Vector3 })
	walkPoints = points
	crowdPoints = crowd
end

-- called with the player and their combo count whenever they knock an NPC down for money
function NpcService.onKnock(listener: (Player, number) -> ())
	table.insert(knockListeners, listener)
end

-- called with the player and how far (studs, flat) the NPC flew, ~3 s after the hit
function NpcService.onLaunch(listener: (Player, number) -> ())
	table.insert(launchListeners, listener)
end

function NpcService.start()
	Players.PlayerAdded:Connect(addFriends)
	for _, p in Players:GetPlayers() do
		task.spawn(addFriends, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		combos[p] = nil
		lastCall[p] = nil
	end)
	Net.remote("HitNpc").OnServerEvent:Connect(onHit)
	Net.remote("Feature").OnServerEvent:Connect(onFeature)

	-- fill the streets slowly (avatar loads are rate limited)
	task.spawn(function()
		task.wait(2)
		while true do
			local count, crowd = 0, 0
			for _, state in npcs do
				count += 1
				if state.crowd then
					crowd += 1
				end
			end
			if crowd < Onboarding.SpawnCrowd then
				spawnNpc(true)
				task.wait(0.15)
			elseif
				count
				< CFG.Count
					+ (if workspace:GetAttribute("Event") == "Stampede"
						then EventConfig.StampedeExtraNpcs
						else 0)
			then
				spawnNpc()
				task.wait(0.15)
			else
				task.wait(1)
			end
		end
	end)

	-- wander
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for npc, state in npcs do
				if not npc:GetAttribute("Down") and state.busyUntil < now then
					local humanoid = npc:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.WalkSpeed = CFG.WalkSpeed
						local target = pickWalkPoint(npc:GetPivot().Position, state.crowd)
						walkTo(npc, target, random:NextNumber(6, 14), false)
					end
				end
			end
		end
	end)
end

return NpcService
