--!strict
-- The world's look (Config/Look), set once the map stands: Lighting, sky, haze, clouds, grade, bloom, sun
-- rays (the start-up values, also what Edit mode shows), and the buildings' window glass in soft tints.
-- In play each client's DayNight then drives the clock, light, haze, grade and bloom through the day.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Look)
local GlassRules = require(ReplicatedStorage.Shared.Rules.Glass)

local LookService = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function lighting()
	local look = Config.Look
	Lighting.ClockTime = look.ClockTime
	Lighting.GeographicLatitude = look.Latitude
	Lighting.Brightness = look.Brightness
	Lighting.ExposureCompensation = look.Exposure
	Lighting.GlobalShadows = look.Shadows
	Lighting.Ambient = rgb(look.Ambient)
	Lighting.OutdoorAmbient = rgb(look.OutdoorAmbient)
	Lighting.ColorShift_Top = rgb(look.SunTint)
	Lighting.ShadowSoftness = look.ShadowSoftness
	Lighting.EnvironmentDiffuseScale = look.DiffuseScale
	Lighting.EnvironmentSpecularScale = look.SpecularScale
	local air = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	air.Density = look.AirDensity
	air.Offset = look.AirOffset
	air.Haze = look.AirHaze
	air.Glare = look.AirGlare
	air.Color = rgb(look.AirColor)
	air.Decay = rgb(look.AirDecay)
	air.Parent = Lighting
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	local faces = look.Sky
	if faces.Up ~= 0 then
		sky.SkyboxFt = `rbxassetid://{faces.Ft}`
		sky.SkyboxBk = `rbxassetid://{faces.Bk}`
		sky.SkyboxLf = `rbxassetid://{faces.Lf}`
		sky.SkyboxRt = `rbxassetid://{faces.Rt}`
		sky.SkyboxUp = `rbxassetid://{faces.Up}`
		sky.SkyboxDn = `rbxassetid://{faces.Dn}`
	end
	sky.SunAngularSize = look.SunSize
	sky.StarCount = 0
	sky.Parent = Lighting
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = look.CloudCover
	clouds.Density = look.CloudDensity
	clouds.Color = rgb(look.CloudColor)
	clouds.Parent = workspace.Terrain
	local grade = (Lighting:FindFirstChild("Grade") :: ColorCorrectionEffect?)
		or Instance.new("ColorCorrectionEffect")
	grade.Name = "Grade"
	grade.Saturation = look.Saturation
	grade.Contrast = look.Contrast
	grade.Brightness = look.GradeBrightness
	grade.TintColor = rgb(look.Tint)
	grade.Parent = Lighting
	local bloom = (Lighting:FindFirstChild("Bloom") :: BloomEffect?) or Instance.new("BloomEffect")
	bloom.Name = "Bloom"
	bloom.Intensity = look.BloomIntensity
	bloom.Size = look.BloomSize
	bloom.Threshold = look.BloomThreshold
	bloom.Parent = Lighting
	local rays = (Lighting:FindFirstChild("Rays") :: SunRaysEffect?)
		or Instance.new("SunRaysEffect")
	rays.Name = "Rays"
	rays.Intensity = look.SunRays
	rays.Spread = look.SunRaysSpread
	rays.Parent = Lighting
end

-- every building's window glass in its own soft tint; colours only, no new parts
local function glass(buildings: Instance)
	local G = Config.Glass
	for _, building in buildings:GetChildren() do
		local tint = G.Tints[GlassRules.pick(building.Name, #G.Tints)]
		for _, p in building:GetDescendants() do
			if p:IsA("BasePart") and p.Material == Enum.Material.Glass then
				local _, sat, val = p.Color:ToHSV()
				local h, s, v = GlassRules.tint(sat, val, tint, G)
				p.Color = Color3.fromHSV(h, s, v)
				p.Transparency = math.max(p.Transparency, G.MinTransparency)
			end
		end
	end
end

-- after the map is built and before the buildings are registered (their rebuild keeps these colours)
function LookService.apply(buildings: Instance)
	lighting()
	glass(buildings)
end

return LookService
