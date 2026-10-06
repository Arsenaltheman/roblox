--!strict
-- Client entry point (the only LocalScript). Boots controllers, wires server messages to the
-- store, mounts the UI.

local Players = game:GetService("Players")
local ScriptContext = game:GetService("ScriptContext")
local Workspace = game:GetService("Workspace")

local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Store = require("./Store")
local App = require("./UI/App")
local Reveal = require("./UI/Reveal")

local controllers = script.Parent:WaitForChild("Controllers")
local ORDER = { "Quality", "Sound", "Vfx", "TrainView", "Pens", "Context" }
local loaded = {}
for _, name in ORDER do
	loaded[name] = (require :: any)(controllers:WaitForChild(name))
end
for _, name in ORDER do
	local ok, err = pcall(loaded[name].init)
	if not ok then
		warn(`[Client] {name}.init failed: {err}`)
	end
end
for _, name in ORDER do
	local ok, err = pcall(loaded[name].start)
	if not ok then
		warn(`[Client] {name}.start failed: {err}`)
	end
end

local localPlayer = Players.LocalPlayer

-- Server -> client
Net.listen("State", function(snapshot)
	Store.state(snapshot)
end)
Net.listen("Toast", function(text: string)
	Store.toast(text)
	loaded.Sound.play("toast")
end)
Net.listen("Announce", function(text: string, kind: string)
	Store.announce(text, kind)
	if kind == "golden" then
		loaded.Sound.play("goldenExpress")
		loaded.Sound.announce("ann_goldenExpress")
	end
end)
Net.listen("Reveal", function(data)
	Reveal.push(data)
end)

-- Attributes the server sets for quick HUD values.
local function syncPlayerAttributes()
	Store.income((localPlayer:GetAttribute("Income") :: number?) or 0)
	Store.uncollected((localPlayer:GetAttribute("Uncollected") :: number?) or 0)
end
localPlayer.AttributeChanged:Connect(syncPlayerAttributes)
syncPlayerAttributes()
Workspace:GetAttributeChangedSignal("GoldenCycle"):Connect(function()
	Store.goldenCycle((Workspace:GetAttribute("GoldenCycle") :: number?) or -1)
end)

-- UI
App.mount()
local revealGui = Instance.new("ScreenGui")
revealGui.Name = "Reveal"
revealGui.ResetOnSpawn = false
revealGui.DisplayOrder = 20
revealGui.IgnoreGuiInset = true
revealGui.Parent = localPlayer:WaitForChild("PlayerGui")
Reveal.mount(revealGui)

-- Client errors are reported (sampled + rate-limited by the server).
local reported = 0
ScriptContext.Error:Connect(function(message: string, trace: string)
	if reported < 5 then
		reported += 1
		Net.request("ClientLog", 3, string.sub(message .. " | " .. string.gsub(trace, "\n", " / "), 1, 160))
	end
end)
