--!strict
-- NPC hits: a vehicle hit (reported by the driver's client, checked here) ragdolls and launches a pedestrian
-- and pays money. The people themselves (who they are, where they walk, friends' avatars) live in CrowdService.
-- Also the taxi call, the ice-cream jingle, the fire-truck cannon, golden pedestrians and the giant.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Impact = require(ReplicatedStorage.Shared.Rules.Impact)
local Net = require(ReplicatedStorage.Shared.Net)
local EventConfig = require(ReplicatedStorage.Shared.Config.Events)
local Ragdoll = require(ReplicatedStorage.Shared.Ragdoll)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local World = require(ReplicatedStorage.Shared.Config.World)
local Analytics = require(script.Parent.Analytics)
local CrowdService = require(script.Parent.CrowdService)
local Data = require(script.Parent.Data)
local Passes = require(script.Parent.Passes)
local SocialService = require(script.Parent.SocialService)
local VehicleService = require(script.Parent.VehicleService)

local NpcService = {}
local CFG = World.Npc

local folder = CrowdService.folder
local knockListeners: { (Player, number) -> () } = {}
local launchListeners: { (Player, number) -> () } = {}
local combos: { [Player]: { count: number, last: number } } = {}
local lastCall: { [Player]: { [string]: number } } = {}
local random = Random.new()
local friendsAdded: { [Player]: boolean } = {}
local jingleToken: { [Sound]: number } = {}

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
	if friendsAdded[player] then
		return
	end
	friendsAdded[player] = true
	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if not ok or not pages then
		return
	end
	for _ = 1, 3 do
		for _, f in (pages :: FriendPages):GetCurrentPage() do
			CrowdService.addFriend({
				userId = f.Id,
				name = f.DisplayName,
				friendOf = player.DisplayName,
			})
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

-- a golden pedestrian (Golden Rush) pays several times over
function NpcService.makeGolden(npc: Model)
	if npc:GetAttribute("Golden") or npc:GetAttribute("GiantHp") then
		return
	end
	CrowdService.setGolden(npc, true)
end

function NpcService.clearGolden()
	CrowdService.clearGolden()
end

function NpcService.all(): { Model }
	local out = {}
	for _, npc in CrowdService.active() do
		if not npc:GetAttribute("Down") then
			table.insert(out, npc)
		end
	end
	return out
end

-- a giant (Giant in Town): a normal pedestrian scaled up that takes several hits to topple
function NpcService.spawnGiant(at: Vector3): Model?
	local npc = CrowdService.spawnGiant(at)
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
	local state = CrowdService.personOf(npc)
	if not state or npc:GetAttribute("Down") then
		return
	end
	npc:SetAttribute("Down", true)
	CrowdService.down(npc)
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
		pay *= SocialService.multiplier(player)
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
	task.delay(World.Npc.RespawnSeconds, CrowdService.recycle, npc)
end

function NpcService.inRadius(pos: Vector3, radius: number): { Model }
	local out = {}
	for _, npc in CrowdService.active() do
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
	local body = VehicleService.bodyNear(vehicle, root.Position) or chassis
	local reach = body.Size.Magnitude / 2
		+ 14
		+ speed * 0.3
		+ (if typeof(giantHp) == "number" then 6 * EventConfig.GiantScale else 0)
	if (root.Position - body.Position).Magnitude > reach then
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
		local pay = math.floor(
			EventConfig.GiantHitPay
				* (if Passes.has(player, "DoubleMoney") then Economy.DoubleMoney else 1)
				* SocialService.multiplier(player)
		)
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
	CrowdService.hold(npc, pos, seconds, run)
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
			if d < bestD and not CrowdService.isBusy(npc) then
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
			-- the tune's first JingleSeconds, then a fade (a press while it plays starts it over)
			local token = (jingleToken[s] or 0) + 1
			jingleToken[s] = token
			s.Volume = Vehicles.Jingle.volume
			s.TimePosition = 0
			s:Play()
			local fade = Vehicles.Jingle.fade
			task.delay(CFG.JingleSeconds - fade, function()
				if jingleToken[s] ~= token or not s.Parent then
					return
				end
				TweenService
					:Create(s, TweenInfo.new(fade, Enum.EasingStyle.Exponential), { Volume = 0 })
					:Play()
				task.delay(fade, function()
					if jingleToken[s] == token and s.Parent then
						s:Stop()
					end
				end)
			end)
			if token == 1 then
				s.Destroying:Once(function()
					jingleToken[s] = nil
				end)
			end
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
		friendsAdded[p] = nil
	end)
	Net.remote("HitNpc").OnServerEvent:Connect(onHit)
	Net.remote("Feature").OnServerEvent:Connect(onFeature)

	CrowdService.start()
end

return NpcService
