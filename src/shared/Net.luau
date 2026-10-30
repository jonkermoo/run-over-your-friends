--!strict
-- The ONLY place client/server message names are defined.
-- Add a name here, then use Net.remote(name) on both sides.

local Net = {}

Net.Messages = table.freeze({
	-- client -> server
	SpawnVehicle = "SpawnVehicle", -- (vehicleId)
	DespawnVehicle = "DespawnVehicle", -- ()
	BuyVehicle = "BuyVehicle", -- (vehicleId)
	BuyPass = "BuyPass", -- (passName): real purchase prompt, or a test toggle in Studio
	ClaimLike = "ClaimLike", -- ()
	HitNpc = "HitNpc", -- (npc: Model, velocity: Vector3)
	BreakAt = "BreakAt", -- (position: Vector3, velocity: Vector3)
	WreckerHit = "WreckerHit", -- (target: Model, velocity: Vector3)
	SelfDestruct = "SelfDestruct", -- ()
	Feature = "Feature", -- (feature: string)
	-- server -> client
	Fling = "Fling", -- (kind: "Character" | "Vehicle", velocity: Vector3, spin: Vector3)
	Popup = "Popup", -- (text: string, kind: string)
	Celebrate = "Celebrate", -- (title: string, subtitle: string): confetti moment
	Goals = "Goals", -- (state: { Hourly: Set, Daily: Set }): the player's current goal sets
	Fx = "Fx", -- (kind: "Hit" | "Land" | "Break" | "Boom", position: Vector3, a: number, b: number, userId: number)
	Boards = "Boards", -- ({ endsAt: number, now: number, boards: { [key]: { Entry } } }): weekly leaderboards
})

export type MessageName =
	"SpawnVehicle"
	| "DespawnVehicle"
	| "BuyVehicle"
	| "BuyPass"
	| "ClaimLike"
	| "HitNpc"
	| "BreakAt"
	| "WreckerHit"
	| "SelfDestruct"
	| "Feature"
	| "Fling"
	| "Popup"
	| "Celebrate"
	| "Goals"
	| "Fx"
	| "Boards"

-- Roblox services are fetched lazily so the name table above stays testable in Lune.
function Net.remote(name: MessageName): RemoteEvent
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		assert(RunService:IsServer(), "Remotes folder missing; the server must create it first")
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		folder = created
	end
	local remote = folder:FindFirstChild(name)
	if not remote then
		assert(RunService:IsServer(), "Remote missing: " .. name)
		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Parent = folder
		remote = created
	end
	return remote :: RemoteEvent
end

-- client side: wait for the server to make it
function Net.waitFor(name: MessageName): RemoteEvent
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
