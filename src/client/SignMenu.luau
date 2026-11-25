--!strict
-- The menu strip at the top left (client/Hud), Street Sign style: a steel gantry with a pictogram sign
-- hanging from it for each menu, each in its menu's own colour, with a black name plaque under it. The
-- open menu's plaque turns yellow. Hud keeps the buttons; this only builds and paints them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Style = require(script.Parent.Style)

local C, F = Style.colors, Style.fonts

local SignMenu = {}

SignMenu.HEIGHT = 64 -- layout px from the strip's top to the plaques' bottom (sheets start at Layout.SheetTop)
local PLATE_W, PLATE_H, PLAQUE_H, PLATE_TOP = 58, 38, 15, 10

-- each menu's sign: face, pictogram colour, image
local LOOKS: { [string]: { any } } = {
	GARAGE = { C.blue, C.text, Icons.SignGarage },
	STORE = { Color3.fromRGB(11, 125, 75), C.text, Icons.SignStore },
	GOALS = { C.brown, C.text, Icons.SignGoals },
	MAP = { Color3.fromRGB(232, 106, 0), C.text, Icons.SignMap },
	INVITE = { C.red, C.text, Icons.SignInvite },
	TUTORIAL = { C.yellow, C.ink, Icons.SignTutorial },
}

-- the strip: an empty frame with the gantry across its top
function SignMenu.strip(parent: Instance): Frame
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Parent = parent
	local gantry = Instance.new("Frame")
	gantry.Name = "Gantry"
	gantry.BackgroundColor3 = Color3.fromRGB(176, 183, 189)
	gantry.BorderSizePixel = 0
	gantry.Position = UDim2.fromOffset(-6, 0)
	gantry.Size = UDim2.new(1, 12, 0, 7)
	gantry.Parent = strip
	Style.corner(gantry, 2)
	Style.stroke(gantry, Color3.fromRGB(61, 66, 72), 1.5, 0)
	local shine = Instance.new("Frame")
	shine.BackgroundColor3 = Color3.fromRGB(226, 230, 234)
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromOffset(0, 1)
	shine.Size = UDim2.new(1, 0, 0, 2)
	shine.Parent = gantry
	return strip
end

-- one hanging sign; Hud gives it a LayoutOrder. Its Text stays empty: the name is on the plaque.
function SignMenu.tab(parent: Instance, text: string): TextButton
	local look = LOOKS[text] or LOOKS.GARAGE
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Text = ""
	b.Size = UDim2.fromOffset(PLATE_W + 6, SignMenu.HEIGHT)
	b.Parent = parent
	-- two hangers from the gantry down to the plate
	for _, x in { 14, PLATE_W - 8 } do
		local rod = Instance.new("Frame")
		rod.BackgroundColor3 = Color3.fromRGB(115, 123, 131)
		rod.BorderSizePixel = 0
		rod.Position = UDim2.fromOffset(x, 4)
		rod.Size = UDim2.fromOffset(3, PLATE_TOP - 2)
		rod.Parent = b
	end
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.BackgroundColor3 = look[1]
	plate.BorderSizePixel = 0
	plate.Position = UDim2.fromOffset(3, PLATE_TOP)
	plate.Size = UDim2.fromOffset(PLATE_W, PLATE_H)
	plate.Parent = b
	Style.corner(plate, 6)
	Style.stroke(plate, C.ink, 2, 0)
	local line = Instance.new("Frame")
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromOffset(2, 2)
	line.Size = UDim2.new(1, -4, 1, -4)
	line.Parent = plate
	Style.corner(line, 4)
	Style.stroke(line, look[2], 1.6, 0)
	local pic = Style.image(plate, look[3], look[2])
	pic.Name = "Pictogram"
	pic.AnchorPoint = Vector2.new(0.5, 0.5)
	pic.Position = UDim2.fromScale(0.5, 0.5)
	pic.Size = UDim2.fromOffset(28, 28)
	local plaque = Instance.new("TextLabel")
	plaque.Name = "Plaque"
	plaque.BackgroundColor3 = C.ink
	plaque.BorderSizePixel = 0
	plaque.Position = UDim2.fromOffset(3, PLATE_TOP + PLATE_H - 1)
	plaque.Size = UDim2.fromOffset(PLATE_W, PLAQUE_H)
	plaque.Text = text
	plaque.TextSize = 11
	plaque.FontFace = F.heavy
	plaque.TextColor3 = C.text
	plaque.Parent = b
	Style.corner(plaque, 4)
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
