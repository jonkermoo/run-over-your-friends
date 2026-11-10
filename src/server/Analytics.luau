--!strict
-- Roblox analytics (Creator Hub > Analytics): the first-session funnel, money in and out, and a few
-- custom events. Every call is wrapped so analytics can never break the game. Money earned by playing
-- is added up and sent once a minute per player, so busy players don't flood the economy log.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

local Analytics = {}

-- the first-session funnel, in order
Analytics.Steps = table.freeze({
	Joined = 1,
	SpawnedCar = 2,
	FirstHit = 3,
	FirstRampage = 4,
	TookRamp = 5,
	SmashedBuilding = 6,
	ClaimedGoal = 7,
	FirstPurchase = 8,
	JoinedEvent = 9,
	TutorialDone = 10,
})
local STEP_NAMES = {
	"Joined",
	"Spawned a car",
	"First hit",
	"First rampage",
	"Took a ramp",
	"Smashed a building",
	"Claimed a goal",
	"First vehicle bought",
	"Joined an event",
	"Tutorial done",
}

local reached: { [Player]: { [number]: boolean } } = {}
local pendingEarn: { [Player]: number } = {}

local function safe(f: () -> ())
	local ok, err = pcall(f)
	if not ok then
		warn("analytics:", err)
	end
end

local function balance(player: Player): number
	return math.floor((player:GetAttribute("Money") or 0) :: number)
end

-- each step once per session
function Analytics.step(player: Player, step: number)
	local seen = reached[player]
	if not seen then
		seen = {}
		reached[player] = seen
	end
	if seen[step] then
		return
	end
	seen[step] = true
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, STEP_NAMES[step])
	end)
end

-- money earned by running people over (batched)
function Analytics.earned(player: Player, amount: number)
	pendingEarn[player] = (pendingEarn[player] or 0) + amount
end

local function flushEarn(player: Player)
	local amount = math.floor(pendingEarn[player] or 0)
	pendingEarn[player] = nil
	if amount > 0 then
		safe(function()
			AnalyticsService:LogEconomyEvent(
				player,
				Enum.AnalyticsEconomyFlowType.Source,
				"Money",
				amount,
				balance(player),
				Enum.AnalyticsEconomyTransactionType.Gameplay.Name
			)
		end)
	end
end

-- one-off money in: goal rewards, packs, the like reward, the Roadster pass
function Analytics.source(
	player: Player,
	amount: number,
	kind: Enum.AnalyticsEconomyTransactionType,
	sku: string
)
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Money",
			math.floor(amount),
			balance(player),
			kind.Name,
			sku
		)
	end)
end

-- money out: buying a vehicle
function Analytics.spent(player: Player, amount: number, sku: string)
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Sink,
			"Money",
			math.floor(amount),
			balance(player),
			Enum.AnalyticsEconomyTransactionType.Shop.Name,
			sku
		)
	end)
end

function Analytics.custom(
	player: Player,
	name: string,
	value: number?,
	fields: { [string]: string }?
)
	safe(function()
		if fields then
			AnalyticsService:LogCustomEvent(player, name, value or 1, fields :: any)
		else
			AnalyticsService:LogCustomEvent(player, name, value or 1)
		end
	end)
end

function Analytics.start()
	local function onPlayer(player: Player)
		Analytics.step(player, Analytics.Steps.Joined)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		flushEarn(p)
		reached[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for player in pendingEarn do
				flushEarn(player)
			end
		end
	end)
end

return Analytics
