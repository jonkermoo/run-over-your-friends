--!strict
-- The code the baked terrain was drawn from: src/server/MapBuilder.luau and every module it requires, on and
-- on, comments and spacing left out, hashed into one label. tools/lune/bake_terrain stores it on the bake
-- (BakedSource); tests/run fails when the code no longer matches, so a map change can't ship with an old bake
-- (every server would then draw the terrain itself, ~11 s slower). Paths are from the repo root.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local TerrainSource = {}

local ROOT_FILE = "src/server/MapBuilder.luau"

local function dirOf(path: string): string
	return string.match(path, "^(.*)/[^/]+$") or "."
end

local function normalise(path: string): string
	local parts = {}
	for piece in string.gmatch(path, "[^/]+") do
		if piece == ".." then
			table.remove(parts)
		elseif piece ~= "." then
			table.insert(parts, piece)
		end
	end
	return table.concat(parts, "/")
end

local function fileFor(base: string): string?
	for _, candidate in { base .. ".luau", base .. "/init.luau" } do
		if fs.isFile(candidate) then
			return candidate
		end
	end
	return nil
end

-- the files one source file requires (that exist in the repo)
local function requires(path: string, text: string): { string }
	local out = {}
	local dir = dirOf(path)
	for inner in string.gmatch(text, "require%(([^)]*)%)") do
		local base: string? = nil
		local shared = string.match(inner, "^ReplicatedStorage%.Shared%.([%w_%.]+)$")
		local str = string.match(inner, '^"([^"]+)"$')
		if shared then
			base = "src/shared/" .. string.gsub(shared, "%.", "/")
		elseif str then
			base = normalise(dir .. "/" .. str)
		elseif string.match(inner, "^script%.") then
			local up = dir
			local rest = string.sub(inner, #"script." + 1)
			-- script.Parent is the file's own folder; each further Parent goes up one
			rest = string.gsub(rest, "^Parent%.?", "", 1)
			while string.match(rest, "^Parent") do
				up = dirOf(up)
				rest = string.gsub(rest, "^Parent%.?", "", 1)
			end
			base = up .. "/" .. string.gsub(rest, "%.", "/")
		end
		local file = base and fileFor(base)
		if file then
			table.insert(out, file)
		end
	end
	return out
end

-- the code without comments, blank space or line endings
local function strip(text: string): string
	text = string.gsub(text, "%-%-%[(=*)%[.-%]%1%]", "")
	text = string.gsub(text, "%-%-[^\n]*", "")
	text = string.gsub(text, "%s+", " ")
	return text
end

-- every file the map build reads, sorted
function TerrainSource.files(): { string }
	local seen: { [string]: boolean } = {}
	local queue = { ROOT_FILE }
	while #queue > 0 do
		local path = table.remove(queue) :: string
		if not seen[path] then
			seen[path] = true
			for _, dep in requires(path, fs.readFile(path)) do
				table.insert(queue, dep)
			end
		end
	end
	local list = {}
	for path in seen do
		table.insert(list, path)
	end
	table.sort(list)
	return list
end

function TerrainSource.hash(): string
	local pieces = {}
	for _, path in TerrainSource.files() do
		table.insert(pieces, path .. "\n" .. strip(fs.readFile(path)))
	end
	return serde.hash("sha256", table.concat(pieces, "\n"))
end

return TerrainSource
