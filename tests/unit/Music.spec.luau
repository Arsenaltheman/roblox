local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check
local req = frktest.assert.require

local Music = require("../../src/shared/Config/Music")
local Sounds = require("../../src/shared/Config/Sounds")

return function()
	test.suite("Music config", function()
		test.case("every state track is a music-bus sound key", function()
			for _, state in Music.priority do
				local def = Music.states[state]
				req.not_nil(def)
				req.is_true(#def.tracks >= 1)
				for _, key in def.tracks do
					local sound = Sounds[key]
					req.not_nil(sound)
					check.equal(sound.bus, "music")
					check.is_true(type(sound.id) == "string")
				end
			end
		end)

		test.case("stingers map to existing sound keys", function()
			for _, key in Music.stingers do
				req.not_nil(Sounds[key])
			end
		end)

		test.case("pick follows priority and falls back to calm", function()
			local none = { boss = false, tense = false, event = false, menu = false }
			check.equal(Music.pick(none), "calm")
			check.equal(Music.pick({ boss = false, tense = false, event = false, menu = true }), "menu")
			check.equal(Music.pick({ boss = false, tense = false, event = true, menu = true }), "event")
			check.equal(Music.pick({ boss = false, tense = true, event = true, menu = true }), "tense")
			check.equal(Music.pick({ boss = true, tense = true, event = true, menu = true }), "boss")
		end)

		test.case("duck depth is -8 dB", function()
			local gain = Music.duckGain()
			check.is_true(gain > 0.39 and gain < 0.40)
			check.is_true(Music.CROSSFADE > 0 and Music.DEBOUNCE > 0)
		end)
	end)
end
