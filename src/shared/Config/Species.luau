--!strict
-- The critter roster. One species per tier (1 = cheapest, 40 = rarest).
-- `rig` picks which modular body the art kit builds it from. `exclusive` species are Robux-only
-- and never roll from cages or eggs.
-- Names are original. Rule: no ethnic caricatures, no Native imagery, no weapons.

export type Species = {
	id: string,
	name: string,
	tier: number,
	rig: "quadruped" | "biped" | "blob",
	blurb: string,
	exclusive: boolean?,
}

local Species: { Species } = {
	-- Common (1-6)
	{ id = "CactusCarl", name = "Cactus Carl", tier = 1, rig = "blob", blurb = "A cactus with a magnificent mustache." },
	{ id = "TumbleweedTim", name = "Tumbleweed Tim", tier = 2, rig = "blob", blurb = "Never stops rolling. Never." },
	{ id = "SirHayBale", name = "Sir Hay Bale", tier = 3, rig = "blob", blurb = "Extremely polite. Slightly itchy." },
	{ id = "PebbleProspector", name = "Pebble Prospector", tier = 4, rig = "biped", blurb = "A rock looking for a shinier rock." },
	{ id = "DustyBunny", name = "Dusty Bunny", tier = 5, rig = "quadruped", blurb = "Sneezes clouds of desert dust." },
	{ id = "LilLantern", name = "Lil' Lantern", tier = 6, rig = "blob", blurb = "Glows brighter when it's happy." },
	-- Uncommon (7-12)
	{ id = "BootsMcGoat", name = "Boots McGoat", tier = 7, rig = "quadruped", blurb = "Wears four boots. Owns twelve." },
	{ id = "PicklePete", name = "Pickle Pete", tier = 8, rig = "biped", blurb = "A pickle with a ten-gallon hat." },
	{ id = "SaddleSnail", name = "Saddle Snail", tier = 9, rig = "blob", blurb = "Fastest snail in the county. Allegedly." },
	{ id = "HorseshoeHank", name = "Horseshoe Hank", tier = 10, rig = "quadruped", blurb = "A crab who collects lucky horseshoes." },
	{ id = "CornbreadCorgi", name = "Cornbread Corgi", tier = 11, rig = "quadruped", blurb = "Smells like breakfast." },
	{ id = "WindmillWilly", name = "Windmill Willy", tier = 12, rig = "biped", blurb = "Spins when he's excited." },
	-- Rare (13-18)
	{ id = "BurritoBronco", name = "Burrito Bronco", tier = 13, rig = "quadruped", blurb = "Half horse, half burrito, all bucking." },
	{ id = "YeehawYak", name = "Yeehaw Yak", tier = 14, rig = "quadruped", blurb = "Yells YEEHAW at sunrise." },
	{ id = "RodeoRooster", name = "Rodeo Rooster", tier = 15, rig = "biped", blurb = "Rides anything that moves." },
	{ id = "WagonWheelWalrus", name = "Wagon Wheel Walrus", tier = 16, rig = "blob", blurb = "Rolls everywhere on two wagon wheels." },
	{ id = "PrairiePancake", name = "Prairie Pancake", tier = 17, rig = "blob", blurb = "A stack of pancakes with tiny legs." },
	{ id = "CoyoteKazoo", name = "Coyote Kazoo", tier = 18, rig = "quadruped", blurb = "Howls exclusively in kazoo." },
	-- Epic (19-24)
	{ id = "SheriffShrimpo", name = "Sheriff Shrimpo", tier = 19, rig = "biped", blurb = "Small shrimp. Big badge." },
	{ id = "BanjoBison", name = "Banjo Bison", tier = 20, rig = "quadruped", blurb = "Knows one song. Plays it beautifully." },
	{ id = "LassoLlama", name = "Lasso Llama", tier = 21, rig = "quadruped", blurb = "Never misses a throw." },
	{ id = "TinStarToad", name = "Tin Star Toad", tier = 22, rig = "blob", blurb = "Deputized by mistake." },
	{ id = "CanyonCapybara", name = "Canyon Capybara", tier = 23, rig = "quadruped", blurb = "Unbothered. Moisturized. Western." },
	{ id = "GoldPanPanda", name = "Gold Pan Panda", tier = 24, rig = "biped", blurb = "Pans for gold. Finds snacks." },
	-- Legendary (25-29)
	{ id = "GoldToothGoose", name = "Gold Tooth Goose", tier = 25, rig = "biped", blurb = "Honks in solid gold." },
	{ id = "RattlesnakeRex", name = "Rattlesnake Rex", tier = 26, rig = "blob", blurb = "Rattles a maraca tail." },
	{ id = "Thunderhoof", name = "Thunderhoof", tier = 27, rig = "quadruped", blurb = "Every step is a thunderclap." },
	{ id = "DynamoArmadillo", name = "Dynamo Armadillo", tier = 28, rig = "quadruped", blurb = "Rolls up into a spinning sparkler." },
	{ id = "SteamboatSloth", name = "Steamboat Sloth", tier = 29, rig = "biped", blurb = "Slow, but powered by steam." },
	-- Mythic (30-34)
	{ id = "SteamEngineStallion", name = "Steam Engine Stallion", tier = 30, rig = "quadruped", blurb = "Half train, half horse. Whistles." },
	{ id = "CycloneCoyote", name = "Cyclone Coyote", tier = 31, rig = "quadruped", blurb = "Runs so fast it makes weather." },
	{ id = "SunsetSerpent", name = "Sunset Serpent", tier = 32, rig = "blob", blurb = "Glows orange at golden hour." },
	{ id = "GoldenSpurGriffin", name = "Golden Spur Griffin", tier = 33, rig = "quadruped", blurb = "Wings, spurs, attitude." },
	{ id = "CanyonColossus", name = "Canyon Colossus", tier = 34, rig = "biped", blurb = "A mesa that decided to walk." },
	-- Outlaw (35-38)
	{ id = "MidnightMarauder", name = "Midnight Marauder", tier = 35, rig = "biped", blurb = "Only seen after dark." },
	{ id = "BlackHatBadger", name = "Black Hat Badger", tier = 36, rig = "quadruped", blurb = "The meanest hat in the West." },
	{ id = "PhantomRider", name = "Phantom Rider", tier = 37, rig = "biped", blurb = "Rides a horse nobody can see." },
	{ id = "DustDevilDragon", name = "Dust Devil Dragon", tier = 38, rig = "quadruped", blurb = "Breathes tiny tornadoes." },
	-- Secret (39-40)
	{ id = "CloudCowboy", name = "Cloud Cowboy", tier = 39, rig = "biped", blurb = "Rides the thunderstorm home." },
	{ id = "LaLocomotoraLoca", name = "La Locomotora Loca", tier = 40, rig = "quadruped", blurb = "A runaway train with a heart of gold." },
}

-- Robux-only exclusives. Their income tracks the owner's progress (see Economy.exclusiveIncome),
-- so `tier` here is only a display hint.
local Exclusives: { Species } = {
	{ id = "DeputyDuck", name = "Deputy Duck", tier = 8, rig = "biped", blurb = "Starter Pack exclusive. Quacks on duty.", exclusive = true },
	{ id = "GoldenLocomotive", name = "Golden Locomotive", tier = 30, rig = "quadruped", blurb = "Pure gold. Pure steam.", exclusive = true },
	{ id = "DiamondDesperado", name = "Diamond Desperado", tier = 36, rig = "biped", blurb = "Sparkles while it steals the show.", exclusive = true },
}

local byId: { [string]: Species } = {}
local byTier: { [number]: Species } = {}
for _, species in Species do
	byId[species.id] = species
	byTier[species.tier] = species
end
for _, species in Exclusives do
	byId[species.id] = species
end

return {
	list = Species,
	exclusives = Exclusives,
	byId = byId,
	byTier = byTier,
	count = #Species,
}
