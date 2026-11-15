--!strict
-- The VIP pass's gold tag: a VIP pill over each VIP player's head (just above Roblox's own name label) and a gold
-- [VIP] before their name in chat. Built on each screen from the PassVIP attribute (server/Passes), so it shows
-- for everyone as soon as the pass is bought. Your own tag hides in first person. Look: Config/Vip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config.Vip)
local Style = require(script.Parent.Style)

local VipTags = {}

local me = Players.LocalPlayer
local tags: { [Player]: BillboardGui } = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function isVip(p: Player): boolean
	return p:GetAttribute("PassVIP") == true
end

local function drop(p: Player)
	local t = tags[p]
	if t then
		t:Destroy()
		tags[p] = nil
	end
end

local function build(p: Player)
	drop(p)
	local character = p.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not isVip(p) or not head then
		return
	end
	local k = Style.billboardScale()
	local gui = Instance.new("BillboardGui")
	gui.Name = "VipTag"
	gui.Adornee = head
	gui.ResetOnSpawn = false
	gui.LightInfluence = 0
	gui.MaxDistance = Config.TagRange
	gui.Size = UDim2.fromOffset(
		math.floor(Config.TagWidth * k + 0.5),
		math.floor(Config.TagHeight * k + 0.5)
	)
	gui.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2 + Config.TagLift, 0)
	local pill = Instance.new("TextLabel")
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = rgb(Config.Gold)
	pill.FontFace = Style.fonts.display
	pill.TextSize = math.floor(Config.TagText * k + 0.5)
	pill.TextColor3 = rgb(Config.Ink)
	pill.Text = "VIP"
	pill.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = rgb(Config.Ink)
	edge.Thickness = 2
	edge.Parent = pill
	gui.Parent = me:WaitForChild("PlayerGui")
	tags[p] = gui
end

local function watch(p: Player)
	p:GetAttributeChangedSignal("PassVIP"):Connect(function()
		build(p)
	end)
	p.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		build(p)
	end)
	if p.Character then
		task.spawn(function()
			(p.Character :: Model):WaitForChild("Head", 10)
			build(p)
		end)
	end
end

-- a gold [VIP] before a VIP player's name in chat
local function chatPrefix()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local source = message.TextSource
		local from = source and Players:GetPlayerByUserId(source.UserId)
		if not from or not isVip(from) then
			return nil :: any
		end
		local props = Instance.new("TextChatMessageProperties")
		local c = Config.Gold
		props.PrefixText =
			`<font color="rgb({c[1]},{c[2]},{c[3]})">{Config.ChatPrefix}</font> {message.PrefixText}`
		return props
	end
end

function VipTags.start()
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(drop)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	chatPrefix()
	-- your own tag hides when the camera is at your head (first person, the cockpit view)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < Config.HideCheckEvery then
			return
		end
		acc = 0
		local own = tags[me]
		local cam = workspace.CurrentCamera
		local head = own and own.Adornee :: BasePart?
		if own and cam and head then
			own.Enabled = (cam.CFrame.Position - head.Position).Magnitude > Config.HideWithin
		end
	end)
end

return VipTags
