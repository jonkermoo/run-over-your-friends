--!strict
-- Translated text, in two tables built by Rojo from CSV files (Key, Source, Context, Example, es, pt):
-- - src/shared/Lines.csv (Shared.Lines): every line that mixes words and numbers, one keyed entry each, with
--   {name} slots. Only this module reads it: kept out of LocalizationService so Roblox's own matching never
--   fits a slot line onto a player's name ("{n}ST" would turn FAST into FA.º).
-- - src/localization/GameText.csv (LocalizationService.GameText): plain fixed text ("SKIP"), no keys. It needs
--   no code: Roblox matches a label's Text against its Source column by itself (AutoLocalize).
--
-- Client:  label.Text = Loc.text("Combo", { n = 3 })   or   Loc.set(label, "Combo", { n = 3 })
-- Server:  Net.remote("Popup"):FireClient(player, Loc.msg("Combo", { n = 3 }), "big")
--          (the client turns it into the player's language with Loc.resolve)
-- An argument can itself be a message (Loc.msg / Loc.src), translated first: an event's title inside a line.
-- Missing keys and missing translations fall back to English, never an error.

export type Args = { [string]: any }
export type Msg = { k: string?, s: string?, a: Args? }

local Loc = {}

-- fill "{name}" slots from args; slots with no value stay as they are
function Loc.fill(template: string, args: Args?): string
	if not args then
		return template
	end
	return (
		string.gsub(template, "{([%w_]+)}", function(name)
			local v = args[name]
			return if v == nil then nil else tostring(v)
		end)
	)
end

-- a line to send to a client: a key from the table and its arguments
function Loc.msg(key: string, args: Args?): Msg
	return { k = key, a = args }
end

-- English text that may be in the table's Source column (an event title from Config)
function Loc.src(text: string, args: Args?): Msg
	return { s = text, a = args }
end

-- a place: 1 -> 1ST (1.º, 1º)
function Loc.ordinal(n: number): Msg
	local tens, ones = n % 100, n % 10
	local suffix = if tens >= 11 and tens <= 13
		then "TH"
		elseif ones == 1 then "ST"
		elseif ones == 2 then "ND"
		elseif ones == 3 then "RD"
		else "TH"
	return Loc.msg("Ord" .. suffix, { n = n })
end

-- a contest score rounded, with its unit word (Config/Events contest.unit, plural): "12 pieces", "1 piece"
-- (the same English as Rules/Contest.amount)
function Loc.amount(n: number, unit: string): Msg
	local whole = math.floor(n + 0.5)
	if whole == 1 and string.sub(unit, -1) == "s" then
		unit = string.sub(unit, 1, -2)
	end
	return Loc.msg("Amount_" .. unit, { n = whole })
end

-- the parts that need the engine: loaded on first use (client or server), never in Lune
type Engine = {
	byKey: (key: string, args: Args) -> string?,
	bySource: (text: string, args: Args) -> string?,
}
local engine: Engine? = nil
local loaded = false

local function load(): Engine?
	if loaded then
		return engine
	end
	loaded = true
	if typeof(game) ~= "Instance" or typeof(script) ~= "Instance" then
		return nil
	end
	local LocalizationService = game:GetService("LocalizationService")
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local lines = (script :: Instance).Parent:WaitForChild("Lines", 10) :: LocalizationTable?
	local plain = LocalizationService:WaitForChild("GameText", 10) :: LocalizationTable?
	if not (lines and plain) then
		return nil
	end

	local sources: { [string]: string } = {} -- key -> English
	local keyOfSource: { [string]: string } = {} -- English -> key
	for _, e in lines:GetEntries() do
		sources[e.Key] = e.Source
		keyOfSource[e.Source] = e.Key
	end

	-- the player's language. In Studio a "TestLocale" attribute on LocalizationService ("es", "pt-br") stands in
	-- for it, so a play test shows these lines in another language (Roblox's own matching of plain labels follows
	-- Studio's Player Emulator instead).
	local byKeyT: Translator? = nil
	local plainT: Translator? = nil
	if RunService:IsClient() then
		local player = Players.LocalPlayer
		local function pick()
			local test = if RunService:IsStudio()
				then LocalizationService:GetAttribute("TestLocale")
				else nil
			local localeId = if typeof(test) == "string" and test ~= ""
				then test
				else player.LocaleId
			local ok, a, b = pcall(function()
				return lines:GetTranslator(localeId), plain:GetTranslator(localeId)
			end)
			byKeyT, plainT = if ok then a else nil, if ok then b else nil
		end
		pick()
		player:GetPropertyChangedSignal("LocaleId"):Connect(pick)
		LocalizationService:GetAttributeChangedSignal("TestLocale"):Connect(pick)
	end

	local function byKey(key: string, args: Args): string?
		if not sources[key] then
			return nil
		end
		if byKeyT then
			local ok, text = pcall(function()
				return (byKeyT :: Translator):FormatByKey(key, args)
			end)
			if ok then
				return text
			end
		end
		return Loc.fill(sources[key], args)
	end

	engine = {
		byKey = byKey,
		bySource = function(text: string, args: Args): string?
			local key = keyOfSource[text]
			if key then
				return byKey(key, args)
			end
			if plainT then
				local ok, out = pcall(function()
					return (plainT :: Translator):Translate(game, text)
				end)
				if ok and out ~= "" then
					return Loc.fill(out, args)
				end
			end
			return nil
		end,
	}
	return engine
end

local resolve: (value: any) -> string

local function resolveArgs(args: Args?): Args
	-- every value goes in as text: FormatByKey writes a bare number as "3.00"
	local out = {}
	if args then
		for name, v in args do
			out[name] = if typeof(v) == "table" then resolve(v) else tostring(v)
		end
	end
	return out
end

-- a key's line in the player's language (English when there is no translation, the key itself if unknown)
function Loc.text(key: string, args: Args?): string
	local filled = resolveArgs(args)
	local e = load()
	local text = if e then e.byKey(key, filled) else nil
	return text or Loc.fill(key, filled)
end

-- English text in the player's language when the table has it (else the English, filled)
function Loc.source(text: string, args: Args?): string
	local filled = resolveArgs(args)
	local e = load()
	local out = if e then e.bySource(text, filled) else nil
	return out or Loc.fill(text, filled)
end

-- anything sent for display: a plain string (translated if the table has it) or a Msg
function resolve(value: any): string
	if typeof(value) == "string" then
		return Loc.source(value)
	elseif typeof(value) == "table" then
		if typeof(value.k) == "string" then
			return Loc.text(value.k, value.a)
		elseif typeof(value.s) == "string" then
			return Loc.source(value.s, value.a)
		end
	end
	return tostring(value)
end
Loc.resolve = resolve

-- set a label to a translated line and keep Roblox's own matching off it (the text is already translated, and
-- lines with numbers would otherwise be captured once per number)
function Loc.set(label: TextLabel | TextButton, key: string, args: Args?)
	label.AutoLocalize = false
	label.Text = Loc.text(key, args)
end

return Loc
