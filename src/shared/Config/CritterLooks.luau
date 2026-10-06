--!strict
-- How each critter looks while the Blender meshes are being made: body colors and features for the
-- procedural rig (client/Controllers/CritterRig.luau). Also the brief for the 3D art.
-- features: "mustache" | "hat" | "bandana" | "boots" | "badge" | "horns" | "ears" | "tail" | "longtail"
--   | "cloud" | "spikes" | "wheels" | "shell" | "beak" | "wings" | "flame" | "crown" | "glow" | "stack" | "lantern"
-- Hats also show rarity: Mythic and up (tier 30+) get a gold band, Outlaws (35-38) a black hat.

export type Look = {
	body: string,
	accent: string,
	features: { string },
	-- Body proportions (x, y, z) relative to a unit sphere.
	shape: { number }?,
}

return {
	CactusCarl = {
		body = "#4E9A4B",
		accent = "#2B1D14",
		features = { "mustache", "spikes", "hat" },
		shape = { 0.8, 1.3, 0.8 },
	},
	TumbleweedTim = {
		body = "#C9A26B",
		accent = "#7A5A33",
		features = { "spikes", "spikes" },
		shape = { 1, 1, 1 },
	},
	SirHayBale = {
		body = "#E8C55A",
		accent = "#9C6B2F",
		features = { "hat", "mustache" },
		shape = { 1.2, 0.8, 0.9 },
	},
	PebbleProspector = {
		body = "#9A928A",
		accent = "#5B3A26",
		features = { "hat", "boots" },
		shape = { 1, 0.85, 0.9 },
	},
	DustyBunny = { body = "#D8C3A5", accent = "#B08860", features = { "ears", "tail" } },
	LilLantern = {
		body = "#FFB43D",
		accent = "#3B3A3F",
		features = { "lantern", "glow" },
		shape = { 0.9, 1.1, 0.9 },
	},
	BootsMcGoat = { body = "#EDE3D2", accent = "#5B3A26", features = { "horns", "boots", "boots" } },
	PicklePete = {
		body = "#7FB241",
		accent = "#2B1D14",
		features = { "hat", "mustache" },
		shape = { 0.8, 1.3, 0.8 },
	},
	SaddleSnail = { body = "#C79A6A", accent = "#8A5A3B", features = { "shell", "hat" } },
	HorseshoeHank = {
		body = "#E2463A",
		accent = "#B9B9C0",
		features = { "badge", "boots" },
		shape = { 1.25, 0.75, 1 },
	},
	CornbreadCorgi = { body = "#E7A75A", accent = "#FFF4DD", features = { "ears", "tail", "bandana" } },
	WindmillWilly = {
		body = "#B9835A",
		accent = "#F3E2C0",
		features = { "wheels", "hat" },
		shape = { 0.9, 1.2, 0.9 },
	},
	BurritoBronco = {
		body = "#E8C58A",
		accent = "#C0392B",
		features = { "ears", "tail", "bandana" },
		shape = { 1.3, 0.85, 0.9 },
	},
	YeehawYak = { body = "#6B4A33", accent = "#F3E2C0", features = { "horns", "hat", "tail" } },
	RodeoRooster = { body = "#F4F0E6", accent = "#E2463A", features = { "beak", "hat", "boots" } },
	WagonWheelWalrus = {
		body = "#8C7B70",
		accent = "#FFF4DD",
		features = { "wheels", "mustache" },
		shape = { 1.3, 0.9, 1 },
	},
	PrairiePancake = {
		body = "#E9B26A",
		accent = "#8A4E1F",
		features = { "stack", "boots" },
		shape = { 1.2, 0.7, 1.2 },
	},
	CoyoteKazoo = { body = "#C08A55", accent = "#FFD34D", features = { "ears", "tail", "bandana" } },
	SheriffShrimpo = {
		body = "#FF8A6A",
		accent = "#E2A93B",
		features = { "badge", "hat", "boots" },
		shape = { 0.9, 1.1, 0.9 },
	},
	BanjoBison = {
		body = "#5B3A26",
		accent = "#E2A93B",
		features = { "horns", "tail", "hat" },
		shape = { 1.3, 1, 1 },
	},
	LassoLlama = {
		body = "#F3E6D3",
		accent = "#C0392B",
		features = { "ears", "bandana", "tail" },
		shape = { 0.9, 1.3, 0.9 },
	},
	TinStarToad = {
		body = "#6FAE4E",
		accent = "#C8C8D0",
		features = { "badge", "hat" },
		shape = { 1.2, 0.8, 1 },
	},
	CanyonCapybara = {
		body = "#9C6B43",
		accent = "#F3E2C0",
		features = { "ears", "bandana" },
		shape = { 1.3, 0.9, 1 },
	},
	GoldPanPanda = { body = "#F4F4F4", accent = "#2B2B2B", features = { "ears", "hat", "boots" } },
	GoldToothGoose = {
		body = "#FFFFFF",
		accent = "#FFC83D",
		features = { "beak", "crown", "wings" },
		shape = { 0.9, 1.25, 0.95 },
	},
	RattlesnakeRex = {
		body = "#A5893F",
		accent = "#5B3A26",
		features = { "longtail", "hat" },
		shape = { 1.2, 0.75, 0.85 },
	},
	Thunderhoof = {
		body = "#4A4852",
		accent = "#FFF15C",
		features = { "ears", "tail", "glow", "flame" },
		shape = { 1.3, 1, 0.9 },
	},
	DynamoArmadillo = {
		body = "#9A6F5A",
		accent = "#FFB43D",
		features = { "shell", "glow", "ears", "flame" },
		shape = { 1.15, 0.9, 1 },
	},
	SteamboatSloth = { body = "#8D7A63", accent = "#E2463A", features = { "hat", "lantern" } },
	SteamEngineStallion = {
		body = "#2E2E33",
		accent = "#E2A93B",
		features = { "wheels", "ears", "flame" },
		shape = { 1.4, 1, 0.9 },
	},
	CycloneCoyote = {
		body = "#7FB7D8",
		accent = "#FFFFFF",
		features = { "ears", "tail", "glow", "bandana" },
		shape = { 1.1, 0.95, 1.05 },
	},
	SunsetSerpent = {
		body = "#FF7A3D",
		accent = "#FFD34D",
		features = { "longtail", "crown", "glow" },
		shape = { 1.1, 0.85, 0.85 },
	},
	GoldenSpurGriffin = {
		body = "#E2A93B",
		accent = "#FFF4DD",
		features = { "wings", "beak", "boots", "ears" },
		shape = { 1.15, 1.1, 1.05 },
	},
	CanyonColossus = {
		body = "#B06A45",
		accent = "#4E9A4B",
		features = { "spikes", "hat", "horns", "boots" },
		shape = { 1.3, 1.3, 1.1 },
	},
	MidnightMarauder = {
		body = "#2A2540",
		accent = "#7B5CFF",
		features = { "hat", "bandana", "glow", "mustache" },
		shape = { 1, 1.15, 0.95 },
	},
	BlackHatBadger = {
		body = "#3A3A3F",
		accent = "#F4F4F4",
		features = { "hat", "ears", "tail", "badge" },
		shape = { 1.25, 0.85, 1.05 },
	},
	PhantomRider = {
		body = "#B8F5E0",
		accent = "#1E6F86",
		features = { "hat", "glow", "bandana", "flame" },
		shape = { 0.9, 1.3, 0.9 },
	},
	DustDevilDragon = {
		body = "#C46A3A",
		accent = "#FFD34D",
		features = { "wings", "horns", "flame", "longtail" },
		shape = { 1.2, 1.05, 1.1 },
	},
	CloudCowboy = {
		body = "#EAF6FF",
		accent = "#3FB7B0",
		features = { "hat", "glow", "cloud", "bandana" },
		shape = { 1.1, 1.05, 1.05 },
	},
	LaLocomotoraLoca = {
		body = "#E2463A",
		accent = "#FFC83D",
		features = { "wheels", "flame", "crown", "glow" },
		shape = { 1.4, 1.1, 1 },
	},
	-- Robux exclusives
	DeputyDuck = { body = "#FFE16B", accent = "#E2A93B", features = { "beak", "badge", "hat" } },
	GoldenLocomotive = {
		body = "#FFC83D",
		accent = "#2B1D14",
		features = { "wheels", "flame", "crown", "glow" },
		shape = { 1.4, 1, 0.9 },
	},
	DiamondDesperado = {
		body = "#9FF3FF",
		accent = "#1E6F86",
		features = { "bandana", "glow", "crown", "mustache" },
		shape = { 0.95, 1.2, 0.95 },
	},
} :: { [string]: Look }
