--!strict
-- Every terrain change the map build makes goes through here. Filling the island's terrain takes most of a
-- server's start (about 11 s), so the place file ships with it already filled (assets/Terrain.rbxm, made by
-- MapBuilder.bake and tools/lune/bake_terrain). When that baked terrain is there, each change is only counted
-- into a fingerprint and kept, not drawn. At the end of the build the fingerprint is checked against the one
-- the bake stored: if they differ (the map changed since the bake), the terrain is cleared and every kept
-- change is drawn for real, as before, with a warning to bake again.
--
-- Kits use `Terra.terrain` like workspace.Terrain for the plain fills, and `Terra.run(name, fn, ...)` for a
-- change that reads the voxels first (fn(...) does the whole read and write on workspace.Terrain).
-- A change to how such a fn draws is not seen by the fingerprint (its arguments are): bump VERSION then.

local Pace = require(script.Parent.Pace)

local Terra = {}

local VERSION = 1
local ATTRIBUTE = "BakedTerrain"
local M1, M2 = 2147483629, 2147483587

local skipping = false
local baked: string? = nil
local kept: { { any } } = {}
local h1, h2 = 0, 0

local function mixInt(v: number)
	h1 = (h1 * 1000003 + v % M1) % M1
	h2 = (h2 * 999983 + v % M2 + 7) % M2
end

local function mixNumber(n: number)
	-- 1/64 stud: the same build gives the same numbers, and a last-bit difference between machines rounds away
	mixInt(math.floor(n * 64 + 0.5))
end

local function mixString(s: string)
	mixInt(#s)
	for i = 1, #s do
		mixInt(string.byte(s, i))
	end
end

local function mix(v: any)
	local t = typeof(v)
	if t == "number" then
		mixNumber(v)
	elseif t == "nil" then
		mixInt(1)
	elseif t == "boolean" then
		mixInt(if v then 2 else 3)
	elseif t == "string" then
		mixString(v)
	elseif t == "EnumItem" then
		mixString(tostring(v))
	elseif t == "Vector3" then
		mixNumber(v.X)
		mixNumber(v.Y)
		mixNumber(v.Z)
	elseif t == "CFrame" then
		for _, c in { v:GetComponents() } do
			mixNumber(c)
		end
	elseif t == "Region3" then
		mix(v.CFrame)
		mix(v.Size)
	elseif t == "Color3" then
		mixNumber(v.R * 255)
		mixNumber(v.G * 255)
		mixNumber(v.B * 255)
	elseif t == "table" then
		-- keys sorted, so a dictionary mixes the same every run
		local keys = {}
		for k in v do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		mixInt(#keys)
		for _, k in keys do
			mix(k)
			mix(v[k])
		end
	else
		error("Terra: can't fingerprint a " .. t)
	end
end

-- a terrain change: counted into the fingerprint, then drawn now or kept for later
function Terra.run(name: string, fn: (...any) -> (), ...: any)
	mixString(name)
	local n = select("#", ...)
	mixInt(n)
	for i = 1, n do
		mix((select(i, ...)))
	end
	if skipping then
		table.insert(kept, { fn, n, ... })
	else
		fn(...)
	end
end

local function fillBlock(cf: CFrame, size: Vector3, material: Enum.Material)
	workspace.Terrain:FillBlock(cf, size, material)
end
local function fillBall(at: Vector3, radius: number, material: Enum.Material)
	workspace.Terrain:FillBall(at, radius, material)
end
local function fillCylinder(cf: CFrame, height: number, radius: number, material: Enum.Material)
	workspace.Terrain:FillCylinder(cf, height, radius, material)
end
local function replaceMaterial(region: Region3, res: number, from: Enum.Material, to: Enum.Material)
	workspace.Terrain:ReplaceMaterial(region, res, from, to)
end
local function clear()
	workspace.Terrain:Clear()
end

-- the plain fills, called like workspace.Terrain's own (terrain:FillBlock(...))
Terra.terrain = {
	FillBlock = function(_, cf: CFrame, size: Vector3, material: Enum.Material)
		Terra.run("FillBlock", fillBlock, cf, size, material)
	end,
	FillBall = function(_, at: Vector3, radius: number, material: Enum.Material)
		Terra.run("FillBall", fillBall, at, radius, material)
	end,
	FillCylinder = function(_, cf: CFrame, height: number, radius: number, material: Enum.Material)
		Terra.run("FillCylinder", fillCylinder, cf, height, radius, material)
	end,
	ReplaceMaterial = function(
		_,
		region: Region3,
		res: number,
		from: Enum.Material,
		to: Enum.Material
	)
		Terra.run("ReplaceMaterial", replaceMaterial, region, res, from, to)
	end,
	Clear = function(_)
		Terra.run("Clear", clear)
	end,
}

-- is the island's terrain really in the place (and not just its label, e.g. from a live sync)?
local function hasGround(): boolean
	local region = Region3.new(Vector3.new(-16, -16, -16), Vector3.new(16, 0, 16))
	local ok, _, occs = pcall(function()
		return workspace.Terrain:ReadVoxels(region, 4)
	end)
	if not ok then
		return false
	end
	for _, plane in occs do
		for _, row in plane do
			for _, o in row do
				if o > 0 then
					return true
				end
			end
		end
	end
	return false
end

-- the start of a map build; `fresh` (the bake) always draws
function Terra.begin(fresh: boolean?)
	h1, h2 = 0, 0
	mixInt(VERSION)
	kept = {}
	local label = workspace.Terrain:GetAttribute(ATTRIBUTE)
	baked = if typeof(label) == "string" then label else nil
	skipping = not fresh and baked ~= nil and hasGround()
end

function Terra.fingerprint(): string
	return string.format("%d-%08x%08x", VERSION, h1, h2)
end

-- the end of a map build: the baked terrain is checked, and drawn again if it is out of date. Returns
-- whether the baked terrain was used.
function Terra.finish(): boolean
	local used = skipping
	skipping = false
	local fp = Terra.fingerprint()
	if used and fp ~= baked then
		warn(
			`Terra: the baked terrain is out of date ({baked} vs {fp}), drawing it at start; bake it again (MapBuilder.bake)`
		)
		used = false
		workspace.Terrain:Clear()
		for _, k in kept do
			k[1](table.unpack(k, 3, 2 + k[2]))
			Pace.step()
		end
	end
	kept = {}
	workspace.Terrain:SetAttribute(ATTRIBUTE, fp)
	return used
end

Terra.ATTRIBUTE = ATTRIBUTE

return Terra
