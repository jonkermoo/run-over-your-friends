--!strict
-- The menu strip at the top left (client/Hud), Street Sign style: a pictogram sign plate for each menu, each
-- in its menu's own colour, with a black name plaque under it, drawn from the UI kit (client/Style). The open
-- menu's plaque turns yellow. Hud keeps the buttons; this only builds and paints them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Style = require(script.Parent.Style)

local C, F = Style.colors, Style.fonts

local SignMenu = {}

SignMenu.HEIGHT = 54 -- layout px from the strip's top to the plaques' bottom (sheets start at Layout.SheetTop)
local PLATE_W, PLATE_H, PLAQUE_H = 58, 40, 15

-- each menu's sign: sign kind, face colour, image
local LOOKS: { [string]: { any } } = {
	GARAGE = { "blue", C.blue, Icons.SignGarage },
	STORE = { "green", Color3.fromRGB(11, 125, 75), Icons.SignStore },
	GOALS = { "red", C.red, Icons.SignGoals },
	MAP = { "orange", Color3.fromRGB(232, 106, 0), Icons.SignMap },
	INVITE = { "purple", Color3.fromRGB(122, 62, 196), Icons.SignInvite },
	TUTORIAL = { "yellow", C.yellow, Icons.SignTutorial },
}

-- the strip: an empty frame the plates sit in
function SignMenu.strip(parent: Instance): Frame
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Parent = parent
	return strip
end

-- one sign plate; Hud gives it a LayoutOrder. Its Text stays empty: the name is on the plaque.
function SignMenu.tab(parent: Instance, text: string): TextButton
	local look = LOOKS[text] or LOOKS.GARAGE
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Text = ""
	b.Size = UDim2.fromOffset(PLATE_W + 4, SignMenu.HEIGHT)
	b.Parent = parent
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.Position = UDim2.fromOffset(2, 0)
	plate.Size = UDim2.fromOffset(PLATE_W, PLATE_H)
	plate.Parent = b
	Style.sign(plate, look[1], true)
	plate.BackgroundColor3 = look[2]
	local ink = Style.signs[look[1]].text
	local pic = Style.image(plate, look[3], ink)
	pic.Name = "Pictogram"
	pic.AnchorPoint = Vector2.new(0.5, 0.5)
	pic.Position = UDim2.fromScale(0.5, 0.5)
	pic.Size = UDim2.fromOffset(28, 28)
	local plaque = Instance.new("TextLabel")
	plaque.Name = "Plaque"
	plaque.Position = UDim2.fromOffset(2, PLATE_H - 1)
	plaque.Size = UDim2.fromOffset(PLATE_W, PLAQUE_H)
	plaque.Text = text
	plaque.TextSize = 11
	plaque.FontFace = F.heavy
	plaque.TextColor3 = C.text
	plaque.Parent = b
	Style.sign(plaque, "green", true)
	plaque.BackgroundColor3 = C.ink
	return b
end

-- the open menu's plaque is yellow with black words
function SignMenu.mark(b: TextButton, active: boolean)
	local plaque = b:FindFirstChild("Plaque") :: TextLabel?
	if plaque then
		plaque.BackgroundColor3 = if active then C.yellow else C.ink
		plaque.TextColor3 = if active then C.ink else C.text
	end
end

return SignMenu
