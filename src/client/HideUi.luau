--!strict
-- The UI ON/OFF button left of the MUSIC button (Config/HideUi, Rules/HideUi): pressed (or the U key), it
-- hides every screen of ours (HUD, cash box, menu strip, event card, goals, pointers, callouts, pop-ups),
-- our name tags and world labels, and Roblox's chat, player list and backpack. It stays up itself, with the
-- MUSIC button and the phone driving buttons. Pressed again, everything goes back to what the game wants
-- shown by then: screens that opened meanwhile come up, screens that closed stay closed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Cfg = require(ReplicatedStorage.Shared.Config.HideUi)
local Rules = require(ReplicatedStorage.Shared.Rules.HideUi)
local Style = require(script.Parent.Style)

local HideUi = {}

local C, F = Style.colors, Style.fonts
local player = Players.LocalPlayer

---------------------------------------------------------------- the button (the MUSIC button's twin)

local gui = Instance.new("ScreenGui")
gui.Name = "HideUi"
gui.ResetOnSpawn = false
Style.fit(gui)

local button = Instance.new("TextButton")
button.Name = "HideUiButton"
button.AutoButtonColor = false
button.BackgroundColor3 = C.panel
button.BorderSizePixel = 0
button.Text = ""
button.AnchorPoint = Vector2.new(1, 0)
-- left of the MUSIC button (client/Music: 54 wide, 10 left of the 196-wide cash box, 14 in)
button.Position = UDim2.new(1, -(14 + 196 + 10 + 54 + Cfg.Gap), 0, 8)
button.Size = UDim2.fromOffset(54, 54)
button.Parent = gui
Style.shadow(button)
local word = Style.label(button, "UI", 11, F.heavy, C.yellow)
word.Position = UDim2.fromOffset(0, 6)
word.Size = UDim2.new(1, 0, 0, 12)
local state = Style.label(button, "ON", 20, F.display, C.money)
state.Position = UDim2.fromOffset(0, 20)
state.Size = UDim2.new(1, 0, 0, 26)
local slash = Instance.new("Frame") -- a red strike across while it's off
slash.AnchorPoint = Vector2.new(0.5, 0.5)
slash.Position = UDim2.fromScale(0.5, 0.5)
slash.Size = UDim2.new(1.1, 0, 0, 4)
slash.Rotation = -35
slash.BackgroundColor3 = C.red
slash.BorderSizePixel = 0
slash.Visible = false
slash.Parent = button

---------------------------------------------------------------- hiding

local hidden = false
local entries: { [LayerCollector]: Rules.Entry } = {}
local watches: { RBXScriptConnection } = {}
local core: { [Enum.CoreGuiType]: boolean } = {}

local function setEnabled(g: LayerCollector, on: boolean)
	g.Enabled = on
end

local function cover(d: Instance)
	if entries[d :: any] or not (d:IsA("ScreenGui") or d:IsA("BillboardGui")) then
		return
	end
	local g = d :: LayerCollector
	if not Rules.hides(g.ClassName, g.Name, Cfg) then
		return
	end
	local e, off = Rules.hide(g.Enabled)
	entries[g] = e
	if off then
		setEnabled(g, false)
	end
	-- the game keeps switching it while hidden: note what it wants, keep it off
	table.insert(
		watches,
		g:GetPropertyChangedSignal("Enabled"):Connect(function()
			if hidden and entries[g] == e and Rules.changed(e, g.Enabled) then
				setEnabled(g, false)
			end
		end)
	)
end

local function show()
	state.Text = if hidden then "OFF" else "ON"
	state.TextColor3 = if hidden then C.dim else C.money
	slash.Visible = hidden
end

local function hideAll()
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	hidden = true
	for _, d in pg:GetChildren() do
		cover(d)
	end
	table.insert(watches, pg.ChildAdded:Connect(cover)) -- a new name tag, a world pop-up
	-- world labels of ours outside PlayerGui (the ice-cream sign, speech bubbles)
	for _, d in workspace:GetDescendants() do
		if d:IsA("BillboardGui") then
			cover(d)
		end
	end
	table.insert(
		watches,
		workspace.DescendantAdded:Connect(function(d)
			if d:IsA("BillboardGui") then
				cover(d)
			end
		end)
	)
	for _, name in Cfg.Core do
		local t = (Enum.CoreGuiType :: any)[name] :: Enum.CoreGuiType
		core[t] = StarterGui:GetCoreGuiEnabled(t)
		StarterGui:SetCoreGuiEnabled(t, false)
	end
end

local function showAll()
	hidden = false
	for _, c in watches do
		c:Disconnect()
	end
	table.clear(watches)
	for g, e in entries do
		if g.Parent then
			setEnabled(g, Rules.restore(e))
		end
	end
	table.clear(entries)
	for t, was in core do
		StarterGui:SetCoreGuiEnabled(t, was)
	end
	table.clear(core)
end

function HideUi.toggle()
	if hidden then
		showAll()
	else
		hideAll()
	end
	show()
end

function HideUi.hidden(): boolean
	return hidden
end

function HideUi.start()
	show()
	Style.onTap(button, HideUi.toggle)
	local key = (Enum.KeyCode :: any)[Cfg.Key] :: Enum.KeyCode
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == key then
			HideUi.toggle()
		end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

return HideUi
