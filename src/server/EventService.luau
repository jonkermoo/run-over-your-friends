--!strict
-- Server events on a schedule (Config/Events, Rules/Events): low gravity, golden rush, a giant, a stampede.
-- Clients read the workspace attributes EventPhase ("quiet" | "warn" | "live"), EventKey and EventEndsAt
-- (server time) to draw the banner; Event holds the key only while one is live (NpcService reads it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config.Events)
local Rules = require(ReplicatedStorage.Shared.Rules.Events)
local NpcService = require(script.Parent.NpcService)

local EventService = {}

local baseGravity = workspace.Gravity
local giantSpots: { Vector3 } = {}
local giant: Model? = nil
local random = Random.new()

function EventService.setGiantSpots(points: { Vector3 })
	giantSpots = points
end

local function nearPlayers(npc: Model): number
	local best = math.huge
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			best = math.min(best, (root.Position - npc:GetPivot().Position).Magnitude)
		end
	end
	return best
end

local function begin(key: string)
	if key == "LowGravity" then
		workspace.Gravity = baseGravity * Config.LowGravityScale
	elseif key == "GoldenRush" then
		-- the golden ones are near players, so there's something to chase straight away
		local list = NpcService.all()
		table.sort(list, function(a, b)
			return nearPlayers(a) < nearPlayers(b)
		end)
		for i = 1, math.min(Config.GoldenCount, #list) do
			NpcService.makeGolden(list[i])
		end
	elseif key == "Giant" then
		local at = if #giantSpots > 0
			then giantSpots[random:NextInteger(1, #giantSpots)]
			else Vector3.new(0, 0, 0)
		giant = NpcService.spawnGiant(at)
	end
end

local function finish(key: string)
	if key == "LowGravity" then
		workspace.Gravity = baseGravity
	elseif key == "GoldenRush" then
		NpcService.clearGolden()
	elseif key == "Giant" then
		-- an untoppled giant wanders off
		if giant and giant.Parent and not giant:GetAttribute("Down") then
			giant:Destroy()
		end
		giant = nil
	end
end

function EventService.start()
	local t0 = os.clock()
	local offset = random:NextInteger(0, #Config.List - 1)
	local live: string? = nil
	task.spawn(function()
		while true do
			local ph = Rules.phase(
				os.clock() - t0,
				#Config.List,
				Config.FirstAfter,
				Config.GapSeconds,
				Config.DurationSeconds,
				Config.WarnSeconds,
				offset
			)
			local event = Config.List[ph.index]
			local key = if event then event.key else ""
			local nowLive = if ph.phase == "live" then key else nil
			if nowLive ~= live then
				if live then
					finish(live)
				end
				live = nowLive
				workspace:SetAttribute("Event", live)
				if live then
					begin(live)
				end
			end
			workspace:SetAttribute("EventPhase", ph.phase)
			workspace:SetAttribute("EventKey", key)
			workspace:SetAttribute("EventEndsAt", workspace:GetServerTimeNow() + ph.endsIn)
			task.wait(0.5)
		end
	end)
end

return EventService
