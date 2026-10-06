--!strict
-- Cloud smoke test. Runs on a real Roblox server of the TEST place via Open Cloud Luau Execution:
--   python3 tools/cloud/publish.py && python3 tools/cloud/run_luau.py tests/cloud/smoke.luau
-- Returns { ok = boolean, checks = { [name]: "pass" | "FAIL: ..." | "warn: ..." } }.
-- Warnings (things the owner still has to set up) don't fail the run.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local checks: { [string]: string } = {}
local ok = true

local function check(name: string, fn: () -> (boolean, string?))
	local success, passed, detail = pcall(fn)
	if not success then
		checks[name] = "FAIL: " .. tostring(passed)
		ok = false
	elseif passed then
		checks[name] = "pass"
	elseif detail and string.sub(detail, 1, 5) == "warn:" then
		checks[name] = detail
	else
		checks[name] = "FAIL: " .. (detail or "")
		ok = false
	end
end

-- 1. The server booted (main.server.luau sets these once every service has init+start'ed).
check("server boot", function()
	local deadline = os.clock() + 45
	while not Workspace:GetAttribute("ServerReady") and os.clock() < deadline do
		task.wait(0.5)
	end
	if not Workspace:GetAttribute("ServerReady") then
		return false, "ServerReady never set (did the server script run?)"
	end
	local failures = Workspace:GetAttribute("BootFailures") :: string?
	if failures and failures ~= "" then
		return false, "services failed: " .. failures
	end
	return true
end)

-- 2. The train clock is running.
check("train epoch", function()
	return Workspace:GetAttribute("TrainEpoch") ~= nil, "TrainEpoch attribute missing"
end)

-- 3. Shared config loads on a real server and the odds tables are sane.
local Shared = ReplicatedStorage:WaitForChild("Shared", 10) :: Instance
check("shared config", function()
	assert(Shared, "ReplicatedStorage.Shared missing")
	local Rarities = (require :: any)(Shared:WaitForChild("Config"):WaitForChild("Rarities"))
	local total = 0
	for _, rarity in Rarities.list do
		total += rarity.wildWeight
	end
	return math.abs(total - 100) < 1e-6, `wild weights sum to {total}`
end)

-- 4. DataStores are reachable (TEST place needs "Enable Studio Access to API Services" / published).
check("datastore round trip", function()
	local store = DataStoreService:GetDataStore("SmokeTest")
	local stamp = tostring(os.time())
	store:SetAsync("ping", stamp)
	return store:GetAsync("ping") == stamp, "read back a different value"
end)

-- 5. Monetization ids are filled in (owner step; warning only).
check("product ids", function()
	local Products = (require :: any)(Shared:WaitForChild("Config"):WaitForChild("Products"))
	local missing = {}
	for _, product in Products.list do
		if product.kind ~= "privateServer" and not product.id then
			table.insert(missing, product.key)
		end
	end
	if #missing > 0 then
		return false, `warn: {#missing} products have no id yet ({missing[1]}, ...)`
	end
	return true
end)

-- 6. Audio ids are filled in (after tools/cloud/upload_assets.py; warning only).
check("audio ids", function()
	local AssetIds = (require :: any)(Shared:WaitForChild("Config"):WaitForChild("AssetIds"))
	local count = 0
	for _ in AssetIds.audio do
		count += 1
	end
	if count == 0 then
		return false, "warn: no audio uploaded yet"
	end
	return true
end)

for name, result in checks do
	print(`[smoke] {name}: {result}`)
end
return { ok = ok, checks = checks }
