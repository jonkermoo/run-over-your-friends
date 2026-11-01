--!strict
-- Who lives in the city and what they do next: the roster (residents per home, office workers, staff, walkers),
-- which people wear a friend's avatar, which people are close enough to players to be built, and where
-- someone goes when they finish what they were doing. Pure, so Lune tests it. `rng` returns a number in [0, 1).

local Crowd = {}

export type Role = "walker" | "resident" | "office" | "food" | "warehouse" | "crowd" | "spectator"
export type Outfit = "casual" | "food" | "warehouse" | "office"
export type Person = { role: Role, home: number?, outfit: Outfit, friend: boolean }
export type PlaceKind =
	"home"
	| "office"
	| "restaurant"
	| "warehouse"
	| "shop"
	| "park"
	| "plaza"
	| "spawn"
	| "stunt"
export type Goal =
	"stay"
	| "home"
	| "work"
	| "spot"
	| "restaurant"
	| "shop"
	| "park"
	| "plaza"
	| "wander"
	| "crowd"
	| "stunt"

export type RosterConfig = {
	Walkers: number,
	ResidentsMin: number,
	ResidentsMax: number,
	OfficeWorkersMin: number,
	OfficeWorkersMax: number,
	RestaurantStaff: number,
	WarehouseStaff: number,
	Spectators: number,
	FriendEvery: number,
}

local function int(rng: () -> number, lo: number, hi: number): number
	return lo + math.min(math.floor(rng() * (hi - lo + 1)), hi - lo)
end

-- everyone in the city; places[k] is the kind of place k
function Crowd.roster(
	places: { PlaceKind },
	cfg: RosterConfig,
	spawnCrowd: number,
	rng: () -> number
): { Person }
	local out: { Person } = {}
	local function add(role: Role, home: number?, outfit: Outfit, n: number)
		for _ = 1, n do
			table.insert(out, { role = role, home = home, outfit = outfit, friend = false })
		end
	end
	for k, kind in places do
		if kind == "home" then
			add("resident", k, "casual", int(rng, cfg.ResidentsMin, cfg.ResidentsMax))
		elseif kind == "office" then
			add("office", k, "office", int(rng, cfg.OfficeWorkersMin, cfg.OfficeWorkersMax))
		elseif kind == "restaurant" then
			add("food", k, "food", cfg.RestaurantStaff)
		elseif kind == "warehouse" then
			add("warehouse", k, "warehouse", cfg.WarehouseStaff)
		elseif kind == "spawn" then
			add("crowd", k, "casual", spawnCrowd)
		elseif kind == "stunt" then
			add("spectator", k, "casual", cfg.Spectators)
		end
	end
	add("walker", nil, "casual", cfg.Walkers)
	return out
end

-- staff in uniform always look like staff; anyone else can be a friend
function Crowd.canBeFriend(p: Person): boolean
	return p.outfit == "casual" or p.outfit == "office"
end

-- marks one person in `every` (of the whole roster) as a friend, picked at random among those who can be
function Crowd.pickFriends(people: { Person }, every: number, rng: () -> number): number
	local eligible = {}
	for k, p in people do
		p.friend = false
		if Crowd.canBeFriend(p) then
			table.insert(eligible, k)
		end
	end
	local want = math.min(math.floor(#people / math.max(every, 1)), #eligible)
	for n = 1, want do
		local pick = n + math.min(math.floor(rng() * (#eligible - n + 1)), #eligible - n)
		eligible[n], eligible[pick] = eligible[pick], eligible[n]
		people[eligible[n]].friend = true
	end
	return want
end

-- should the next person built wear a friend's avatar, so about one in `every` of those shown are friends
function Crowd.wantFriend(shownFriends: number, shown: number, every: number): boolean
	return shownFriends < math.floor((shown + 1) / math.max(every, 1) + 0.5)
end

export type Candidate = { dist: number, indoor: boolean, active: boolean }
export type ActiveConfig = {
	MaxActive: number,
	ActivateRadius: number,
	DeactivateRadius: number,
	IndoorRadius: number,
	IndoorLeave: number,
}

-- which people should be built: close enough to a player (a wider radius to stay than to appear, so nobody
-- flickers at the edge), nearest first, at most MaxActive; returns a set of indices
function Crowd.pickActive(list: { Candidate }, cfg: ActiveConfig): { [number]: boolean }
	local keep: { { k: number, rank: number } } = {}
	for k, c in list do
		local radius = if c.indoor
			then (if c.active then cfg.IndoorLeave else cfg.IndoorRadius)
			else (if c.active then cfg.DeactivateRadius else cfg.ActivateRadius)
		if c.dist <= radius then
			-- people already built hold their place against newcomers a little further in
			table.insert(keep, { k = k, rank = if c.active then c.dist * 0.8 else c.dist })
		end
	end
	table.sort(keep, function(a, b)
		return a.rank < b.rank
	end)
	local out = {}
	for n = 1, math.min(#keep, cfg.MaxActive) do
		out[keep[n].k] = true
	end
	return out
end

export type GoalConfig = { HomeStayChance: number, OfficeLunchChance: number }

local function weighted(rng: () -> number, options: { { goal: Goal, w: number } }): Goal
	local total = 0
	for _, o in options do
		total += o.w
	end
	local r = rng() * total
	for _, o in options do
		r -= o.w
		if r < 0 then
			return o.goal
		end
	end
	return options[#options].goal
end

-- where someone goes when they finish; `atHome` means they're inside their own home or workplace
function Crowd.nextGoal(role: Role, atHome: boolean, rng: () -> number, cfg: GoalConfig): Goal
	if role == "food" or role == "warehouse" then
		return "spot"
	elseif role == "crowd" then
		return "crowd"
	elseif role == "spectator" then
		return "stunt"
	elseif role == "resident" then
		if not atHome then
			return "home"
		end
		if rng() < cfg.HomeStayChance then
			return "stay"
		end
		return weighted(rng, {
			{ goal = "restaurant", w = 0.25 },
			{ goal = "shop", w = 0.25 },
			{ goal = "park", w = 0.2 },
			{ goal = "plaza", w = 0.15 },
			{ goal = "wander", w = 0.15 },
		})
	elseif role == "office" then
		if not atHome then
			return "work"
		end
		if rng() < 0.5 then
			return "stay"
		end
		if rng() < cfg.OfficeLunchChance then
			return "restaurant"
		end
		return weighted(
			rng,
			{ { goal = "plaza", w = 0.4 }, { goal = "park", w = 0.3 }, { goal = "shop", w = 0.3 } }
		)
	end
	return weighted(rng, {
		{ goal = "wander", w = 0.4 },
		{ goal = "shop", w = 0.2 },
		{ goal = "restaurant", w = 0.15 },
		{ goal = "park", w = 0.15 },
		{ goal = "plaza", w = 0.1 },
	})
end

return Crowd
