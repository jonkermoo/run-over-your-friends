--!strict
-- SHOW UI in the Settings panel (client/Settings, Config/HideUi, Rules/HideUi): switched off (or the U key), it
-- hides every screen of ours (HUD, cash box, menu strip, event card, goals, pointers, callouts, pop-ups),
-- our name tags and world labels, and Roblox's chat, player list and backpack. The SETTINGS tile and its
-- panel stay up, with the phone driving buttons. Pressed again, everything goes back to what the game wants
-- shown by then: screens that opened meanwhile come up, screens that closed stay closed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Cfg = require(ReplicatedStorage.Shared.Config.HideUi)
local Rules = require(ReplicatedStorage.Shared.Rules.HideUi)

local HideUi = {}

local player = Players.LocalPlayer

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

local listeners: { () -> () } = {}
local function show()
	for _, f in listeners do
		task.spawn(f)
	end
end

-- called whenever the UI is hidden or shown
function HideUi.changed(f: () -> ())
	table.insert(listeners, f)
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
	local key = (Enum.KeyCode :: any)[Cfg.Key] :: Enum.KeyCode
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == key then
			HideUi.toggle()
		end
	end)
end

return HideUi
