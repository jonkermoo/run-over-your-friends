--!strict
-- Client-only facts for analytics (src/server/Analytics): the device, load time, store and garage opened, items
-- viewed, the offer cards, and whether a menu is open or the player is idle. Each goes to the server on Net
-- "Track" with values from the fixed sets in Config/Analytics; nothing here may ever break the game.

local GuiService = game:GetService("GuiService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Cfg = require(ReplicatedStorage.Shared.Config.Analytics)
local Net = require(ReplicatedStorage.Shared.Net)
local Rules = require(ReplicatedStorage.Shared.Rules.Analytics)

local Track = {}

local remote: RemoteEvent? = nil

function Track.send(kind: string, a: any?, b: any?, c: any?)
	task.spawn(function()
		pcall(function()
			local r = remote or Net.waitFor("Track")
			remote = r
			r:FireServer(kind, a, b, c)
		end)
	end)
end

function Track.device(): string
	local ok, device = pcall(function()
		local cam = workspace.CurrentCamera
		local v = if cam then cam.ViewportSize else Vector2.zero
		return Rules.device({
			tenFoot = GuiService:IsTenFootInterface(),
			touch = UserInputService.TouchEnabled,
			keyboard = UserInputService.KeyboardEnabled,
			gamepad = UserInputService.GamepadEnabled,
			shortSide = math.min(v.X, v.Y),
		}, Cfg)
	end)
	return if ok then device else "Unknown"
end

-- the store or garage was opened ("Store" | "Garage")
function Track.opened(sheet: string)
	Track.send("Open", sheet)
end

-- a vehicle shown big in the garage, or a store section scrolled into view (the server logs each once)
local viewedSent: { [string]: boolean } = {}
function Track.viewed(sheet: string, item: string)
	local key = sheet .. ":" .. item
	if not viewedSent[key] then
		viewedSent[key] = true
		Track.send("View", sheet, item)
	end
end

-- an offer card ("Starter" | "Upsell") was shown, or its buy button pressed ("Shown" | "Pressed")
function Track.offer(which: string, stage: string)
	Track.send("Offer", which, stage)
end

-- isMenuOpen: true while a menu or card covers the game
function Track.start(isMenuOpen: () -> boolean)
	-- load time: client/first Loading puts the seconds from client start to spawn-ready on ReplicatedFirst
	task.spawn(function()
		local seconds = ReplicatedFirst:GetAttribute("LoadSeconds")
		while seconds == nil do
			ReplicatedFirst:GetAttributeChangedSignal("LoadSeconds"):Wait()
			seconds = ReplicatedFirst:GetAttribute("LoadSeconds")
		end
		Track.send(
			"Ready",
			Track.device(),
			seconds,
			ReplicatedFirst:GetAttribute("LoadReady") == true
		)
	end)

	local lastInput = os.clock()
	local function touched()
		lastInput = os.clock()
	end
	UserInputService.InputBegan:Connect(touched)
	UserInputService.InputChanged:Connect(function(input)
		-- the mouse moving or a stick held counts; tiny stick noise doesn't
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.Position.Magnitude > 0.2
		then
			touched()
		end
	end)
	local sent = "Active"
	task.spawn(function()
		while true do
			task.wait(Cfg.StateCheckSeconds)
			local ok, menu = pcall(isMenuOpen)
			local state = if ok and menu
				then "Menu"
				elseif os.clock() - lastInput > Cfg.IdleSeconds then "Idle"
				else "Active"
			if state ~= sent then
				sent = state
				Track.send("State", state)
			end
		end
	end)
end

return Track
