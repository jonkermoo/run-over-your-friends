--!strict
-- The menu at the top left (client/Hud): an asphalt bar with a dashed lane line along it, and on it one square
-- tile per menu in its own colour (GARAGE blue, STORE green, GOALS red, MAP amber, INVITE purple), its icon
-- poking out of the tile's top and its name on the tile's bottom edge. The open menu's tile gets a yellow
-- outline. Hud keeps the buttons; this only builds and paints them. Sizes: Config/Layout Menu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local LayoutConfig = require(ReplicatedStorage.Shared.Config.Layout)
local Style = require(script.Parent.Style)

local C, F = Style.colors, Style.fonts
local M = LayoutConfig.Menu

local SignMenu = {}

SignMenu.HEIGHT = M.Height -- layout px, the bar's height (sheets start at Layout.SheetTop, under it)
local TILE_TOP = M.Poke + 4 -- the tile's top inside the button: room for the icon poking out

-- each menu's tile: kind (its colour) and icon
local LOOKS: { [string]: { any } } = {
	GARAGE = { "blue", Icons.RoadCarRed },
	STORE = { "green", Icons.RoadBag },
	GOALS = { "red", Icons.RoadFlag },
	MAP = { "amber", Icons.RoadMap },
	INVITE = { "purple", Icons.RoadPeople },
	TUTORIAL = { "orange", Icons.RoadCone },
}

-- the bar: asphalt with a black outline and a lane line; Hud sizes it to its tiles
function SignMenu.strip(parent: Instance): Frame
	local strip = Style.card(parent)
	strip.BackgroundColor3 = C.asphalt
	strip:SetAttribute("Sign", "asphalt")
	local lane = Style.lane(strip)
	lane.Position = UDim2.fromOffset(8, TILE_TOP + M.Tile / 2 - 3)
	lane.Size = UDim2.new(1, -16, 0, 6)
	return strip
end

-- one tile; Hud gives it a LayoutOrder. Its Text stays empty: the name is a label on the bottom edge.
function SignMenu.tab(parent: Instance, text: string): TextButton
	local look = LOOKS[text] or LOOKS.GARAGE
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Text = ""
	b.Size = UDim2.fromOffset(M.Tile, M.Height)
	b.Parent = parent
	local face = Instance.new("Frame")
	face.Name = "Plate"
	face.Position = UDim2.fromOffset(0, TILE_TOP)
	face.Size = UDim2.fromOffset(M.Tile, M.Tile)
	face.ZIndex = 1
	face.Parent = b
	Style.sign(face, look[1], true)
	local icon = Style.image(b, look[2])
	icon.Name = "Pictogram"
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, TILE_TOP - M.Poke)
	icon.Size = UDim2.fromOffset(M.Icon, M.Icon)
	icon.ZIndex = 2
	local name = Style.label(b, text, 15, F.display, C.text)
	name.Name = "Plaque"
	name.AnchorPoint = Vector2.new(0.5, 0.5)
	name.Position = UDim2.new(0.5, 0, 0, TILE_TOP + M.Tile - 4)
	name.Size = UDim2.fromOffset(M.Tile + 16, 18)
	name.ZIndex = 3
	Style.outline(name, 3)
	return b
end

-- the open menu's tile has a yellow outline
function SignMenu.mark(b: TextButton, active: boolean)
	local face = b:FindFirstChild("Plate") :: Frame?
	if face then
		Style.ring(face, if active then C.yellow else nil)
	end
end

return SignMenu
