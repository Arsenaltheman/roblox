--!strict
-- Services call each other through Registry (untyped), so the type checker can't see those calls.
-- This check finds every `Registry.Service.member` reference and verifies the member exists in
-- src/server/Services/Service.luau as `function Service.member`, `Service.member =`, or a signal.
--   lune run tools/check-registry

local fs = require("@lune/fs")
local process = require("@lune/process")

local DIR = "src/server/Services"
local exports: { [string]: { [string]: boolean } } = {}

for _, file in fs.readDir(DIR) do
	local name = string.match(file, "^(.-)%.luau$")
	if name then
		local source = fs.readFile(`{DIR}/{file}`)
		-- The module table may be named differently from the file (e.g. ProgressionService).
		local moduleVar = string.match(source, "\nreturn ([%w_]+)%s*$") or name
		local members = {}
		for member in string.gmatch(source, "function " .. moduleVar .. "%.([%w_]+)") do
			members[member] = true
		end
		for member in string.gmatch(source, "\n" .. moduleVar .. "%.([%w_]+)%s*=") do
			members[member] = true
		end
		exports[name] = members
	end
end

local failures = 0
local function scan(path: string)
	for _, entry in fs.readDir(path) do
		local full = `{path}/{entry}`
		if fs.isDir(full) then
			scan(full)
		elseif string.match(entry, "%.luau$") then
			local source = fs.readFile(full)
			local line = 1
			for text in string.gmatch(source .. "\n", "(.-)\n") do
				for service, member in string.gmatch(text, "Registry%.([%w_]+)%.([%w_]+)") do
					local members = exports[service]
					if not members then
						print(`{full}:{line}: unknown service Registry.{service}`)
						failures += 1
					elseif not members[member] then
						print(`{full}:{line}: Registry.{service}.{member} does not exist`)
						failures += 1
					end
				end
				line += 1
			end
		end
	end
end

scan("src/server")
if failures > 0 then
	print(`{failures} broken Registry reference(s)`)
	process.exit(1)
end
print("Registry references OK")
