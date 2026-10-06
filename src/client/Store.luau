--!strict
-- Client state as Vide sources. Controllers write; UI reads.

local Vide = require("@game/ReplicatedStorage/Packages/Vide")

local source = Vide.source

export type Toast = { id: number, text: string, at: number }
export type Announcement = { id: number, text: string, kind: string, at: number }

local Store = {
	-- Latest private snapshot from the server (see server/Services/Ui.luau snapshot()).
	state = source(nil :: any),
	income = source(0),
	uncollected = source(0),
	toasts = source({} :: { Toast }),
	announcements = source({} :: { Announcement }),
	-- The contextual action the big button will perform ("" = none).
	action = source({ kind = "", label = "", sub = "" } :: { kind: string, label: string, sub: string }),
	-- Which menu is open ("" = none).
	menu = source(""),
	-- Odds panel content (nil = closed).
	odds = source(nil :: any),
	-- Reveal queue head (nil = none).
	reveal = source(nil :: any),
	quality = source(2),
	weather = source(""),
	serverLuck = source(1),
	goldenCycle = source(-1),
	trainCycle = source(-1),
	activeMinutes = source(0),
	grab = source(nil :: { started: number, duration: number }?),
}

local nextId = 0

function Store.toast(text: string)
	nextId += 1
	local list = table.clone(Store.toasts())
	table.insert(list, { id = nextId, text = text, at = os.clock() })
	while #list > 3 do
		table.remove(list, 1)
	end
	Store.toasts(list)
	local id = nextId
	task.delay(3.5, function()
		local current = Store.toasts()
		for i, t in current do
			if t.id == id then
				local copy = table.clone(current)
				table.remove(copy, i)
				Store.toasts(copy)
				break
			end
		end
	end)
end

function Store.announce(text: string, kind: string)
	nextId += 1
	local list = table.clone(Store.announcements())
	table.insert(list, { id = nextId, text = text, kind = kind, at = os.clock() })
	while #list > 2 do
		table.remove(list, 1)
	end
	Store.announcements(list)
	local id = nextId
	task.delay(5, function()
		local current = Store.announcements()
		for i, a in current do
			if a.id == id then
				local copy = table.clone(current)
				table.remove(copy, i)
				Store.announcements(copy)
				break
			end
		end
	end)
end

return Store
