-- Writes Config/CritterLooks + species tiers/rigs to JSON for the Blender build script.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Looks = require("../../src/shared/Config/CritterLooks")
local Species = require("../../src/shared/Config/Species")
local out = {}
for _, list in { Species.list, Species.exclusives } do
	for _, s in list do
		local look = Looks[s.id]
		out[s.id] = {
			tier = s.tier,
			rig = s.rig,
			body = look.body,
			accent = look.accent,
			features = look.features,
			shape = look.shape or { 1, 1, 1 },
		}
	end
end
fs.writeFile("tools/blender/out/looks.json", serde.encode("json", out, true))
print("wrote looks.json")
