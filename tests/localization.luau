--!strict
-- Translation table checks (src/shared/Lines.csv, src/localization/GameText.csv, src/shared/Loc), called from
-- tests/run.

local fs = require("@lune/fs")

local Loc = require("../src/shared/Loc")
local DriveHud = require("../src/shared/Rules/DriveHud")
local EventConfig = require("../src/shared/Config/Events")
local LoadingConfig = require("../src/shared/Config/Loading")
local Onboarding = require("../src/shared/Config/Onboarding")
local PaintConfig = require("../src/shared/Config/Paints")
local Products = require("../src/shared/Config/Products")
local QuestConfig = require("../src/shared/Config/Quests")
local ServerGoals = require("../src/shared/Config/ServerGoals")

local LOCALES = { "es", "pt" }
-- where the code names a key: Loc.text("Key"), Loc.msg("Key"), Loc.set(label, "Key")
local KEY_PATTERNS = {
	'Loc%.text%(%s*"([%w_]+)"',
	'Loc%.msg%(%s*"([%w_]+)"',
	'Loc%.set%([^,]+,%s*"([%w_]+)"',
}

-- one CSV line into fields ("" quotes, commas inside quotes)
local function fields(line: string): { string }
	local out, cur, quoted, i = {}, {}, false, 1
	while i <= #line do
		local ch = string.sub(line, i, i)
		if quoted then
			if ch == '"' and string.sub(line, i + 1, i + 1) == '"' then
				table.insert(cur, '"')
				i += 1
			elseif ch == '"' then
				quoted = false
			else
				table.insert(cur, ch)
			end
		elseif ch == '"' then
			quoted = true
		elseif ch == "," then
			table.insert(out, table.concat(cur))
			cur = {}
		else
			table.insert(cur, ch)
		end
		i += 1
	end
	table.insert(out, table.concat(cur))
	return out
end

local function slots(s: string): string
	local names = {}
	for name in string.gmatch(s, "{([%w_]+)}") do
		table.insert(names, name)
	end
	table.sort(names)
	return table.concat(names, ",")
end

local function sourceFiles(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			sourceFiles(path, out)
		elseif string.match(name, "%.luau$") then
			table.insert(out, path)
		end
	end
end

return function(check: (string, boolean) -> ())
	local keys: { [string]: string } = {}
	local sources: { [string]: boolean } = {}
	local rowsOk, slotsOk, uniqueOk, keyedOk = true, true, true, true
	-- Lines.csv: keyed lines with slots, read by Loc only; GameText.csv: plain text, no keys, no slots
	for _, file in { { "src/shared/Lines.csv", true }, { "src/localization/GameText.csv", false } } do
		local path, keyed = file[1], file[2]
		local lines = string.split((string.gsub(fs.readFile(path), "\r", "")), "\n")
		check("translations: header of " .. path, lines[1] == "Key,Source,Context,Example,es,pt")
		for n = 2, #lines do
			if lines[n] ~= "" then
				local f = fields(lines[n])
				local key, source = f[1], f[2]
				if #f ~= 6 or source == "" then
					rowsOk = false
					print(`  bad row {path}:{n}: {lines[n]}`)
				end
				if (key ~= "") ~= keyed or (not keyed and slots(source) ~= "") then
					keyedOk = false
					print(`  {path}:{n} belongs in the other file: {source}`)
				end
				for i, locale in LOCALES do
					local value = f[4 + i] or ""
					if value == "" then
						rowsOk = false
						print(`  {path}:{n} has no {locale}: {source}`)
					elseif slots(value) ~= slots(source) then
						slotsOk = false
						print(`  {path}:{n} {locale} slots differ: {value}`)
					end
				end
				if sources[source] or (key ~= "" and keys[key]) then
					uniqueOk = false
					print("  repeated: " .. key .. " / " .. source)
				end
				sources[source] = true
				if key ~= "" then
					keys[key] = source
				end
			end
		end
	end
	check("translations: keyed lines in Lines.csv, plain text in GameText.csv", keyedOk)
	check("translations: every row has es and pt", rowsOk)
	check("translations: {slots} match the English", slotsOk)
	check("translations: keys and sources are unique", uniqueOk)

	-- every key the code names exists (Loc.text / Loc.msg / Loc.set lines)
	local files = {}
	sourceFiles("src", files)
	local missing = {}
	for _, path in files do
		if path == "src/shared/Loc.luau" then
			continue -- builds its keys (Ord.., Amount_..), checked below
		end
		for _, line in string.split(fs.readFile(path), "\n") do
			local found = {}
			for _, pattern in KEY_PATTERNS do
				for word in string.gmatch(line, pattern) do
					table.insert(found, word)
				end
			end
			if string.find(line, "Loc%.") then
				-- Loc.set(label, if one then "KeyA" else "KeyB", ...)
				for a, b in string.gmatch(line, 'then "([%w_]+)" else "([%w_]+)"') do
					table.insert(found, a)
					table.insert(found, b)
				end
			end
			for _, word in found do
				if not keys[word] then
					table.insert(missing, `{path}: {word}`)
				end
			end
		end
	end
	for _, m in missing do
		print("  missing key " .. m)
	end
	check("translations: every key in the code is in the table", #missing == 0)

	-- English the code passes as plain text (matched by Source)
	local plain = {}
	for _, e in EventConfig.List do
		table.insert(plain, e.title)
		table.insert(plain, e.text)
		if e.contest then
			local unit = e.contest.unit
			check("translations: unit " .. unit, keys["Amount_" .. unit] ~= nil)
			check(
				"translations: unit " .. unit .. " (one)",
				keys["Amount_" .. string.sub(unit, 1, -2)] ~= nil
			)
		end
	end
	for _, c in Onboarding.Cheers do
		table.insert(plain, c)
	end
	for _, tip in LoadingConfig.Tips do
		table.insert(plain, tip)
	end
	for _, car in
		{
			{},
			{ feature = "TAXI!" },
			{ feature = "JINGLE", jingleOn = true },
			{ feature = "JINGLE" },
			{ feature = "WATER" },
			{ jet = true },
			{ thruster = true },
		} :: { DriveHud.Car }
	do
		for _, row in DriveHud.rows(car) do
			table.insert(plain, row.label)
		end
	end
	-- goal lines: Loc.goal reads Quest_<kind> / ServerGoal_<kind>, which must be the template's English
	local goalsOk = true
	for _, set in QuestConfig :: any do
		if typeof(set) == "table" and set.Templates then
			for _, q in set.Templates do
				goalsOk = goalsOk and keys["Quest_" .. q.kind] == q.text
			end
		end
	end
	for _, k in ServerGoals.Kinds do
		goalsOk = goalsOk and keys["ServerGoal_" .. k.kind] == k.text
	end
	check("translations: every goal kind has its line", goalsOk)
	for _, paint in PaintConfig.List do
		table.insert(plain, paint.name)
	end
	for _, pack in Products.MoneyPacks do
		table.insert(plain, string.upper(pack.title))
		table.insert(plain, string.upper(pack.title) .. "!")
		if pack.tag then
			table.insert(plain, pack.tag)
		end
	end
	local plainMissing = 0
	for _, s in plain do
		if not sources[s] then
			plainMissing += 1
			print("  not in the table: " .. s)
		end
	end
	check("translations: config text is in the table", plainMissing == 0)

	-- the helper's pure parts
	check("loc: fill", Loc.fill("{n} HITS! {word}", { n = 3, word = "MEGA!" }) == "3 HITS! MEGA!")
	check("loc: fill keeps unknown slots", Loc.fill("{a} {b}", { a = 1 }) == "1 {b}")
	check("loc: fill with a dollar", Loc.fill("+${pay}", { pay = 50 }) == "+$50")
	check(
		"loc: no table loaded, a key falls back to itself",
		Loc.text("Combo", { n = 2 }) == "Combo"
	)
	check("loc: ordinal keys", keys[Loc.ordinal(1).k :: string] == "{n}ST")
	check("loc: 12th", Loc.ordinal(12).k == "OrdTH" and Loc.ordinal(22).k == "OrdND")
	check("loc: one piece", Loc.amount(1, "pieces").k == "Amount_piece")
	check("loc: upper with accents", Loc.upper("Verde-limão día") == "VERDE-LIMÃO DÍA")
	check("loc: plain strings pass through", Loc.resolve("+$50") == "+$50")
	check(
		"loc: a source msg without the engine",
		Loc.resolve(Loc.src("{n} studs", { n = 4 })) == "4 studs"
	)
end
