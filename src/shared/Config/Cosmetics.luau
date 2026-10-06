--!strict
-- Cosmetics: earned with Gold Nuggets in the Trading Post (rotating stock), from strongboxes,
-- or bought with Robux. Purely visual.

export type Cosmetic = {
	id: string,
	slot: "lassoTrail" | "hat" | "poster" | "ranchTheme" | "title" | "horse" | "cape",
	name: string,
	nuggets: number?,
	-- Shown color/accent for UI and VFX.
	color: string,
}

local list: { Cosmetic } = {
	{ id = "trail_dust", slot = "lassoTrail", name = "Dust Trail", nuggets = 40, color = "#C98F55" },
	{ id = "trail_fire", slot = "lassoTrail", name = "Campfire Trail", nuggets = 120, color = "#FF6A1F" },
	{ id = "trail_star", slot = "lassoTrail", name = "Shooting Star", nuggets = 260, color = "#FFE16B" },
	{ id = "trail_rainbow", slot = "lassoTrail", name = "Rainbow Rope", nuggets = 600, color = "#FF5FD2" },
	{ id = "trail_gold", slot = "lassoTrail", name = "Gold Lasso (VIP)", color = "#FFC83D" },
	{ id = "hat_StarterStetson", slot = "hat", name = "Starter Stetson", color = "#8A5A3B" },
	{ id = "hat_cactus", slot = "hat", name = "Cactus Cap", nuggets = 80, color = "#4E9A4B" },
	{ id = "hat_flower", slot = "hat", name = "Flower Hat", nuggets = 150, color = "#FF8FB1" },
	{ id = "hat_sheriff", slot = "hat", name = "Sheriff Hat", nuggets = 300, color = "#E2A93B" },
	{ id = "hat_premium", slot = "hat", name = "Premium Top Hat", color = "#2B1D14" },
	{ id = "hat_club", slot = "hat", name = "Club Stetson", color = "#FFC83D" },
	{ id = "title_regular", slot = "title", name = "Regular", color = "#3FB7B0" },
	-- Mastery capes: level 50 in a Trail Skill. Never sold, never traded.
	{ id = "cape_rustler", slot = "cape", name = "Rustler's Cape", color = "#E2463A" },
	{ id = "cape_wrangler", slot = "cape", name = "Wrangler's Cape", color = "#E2A93B" },
	{ id = "cape_trader", slot = "cape", name = "Trader's Cape", color = "#3FB7B0" },
	{ id = "cape_rancher", slot = "cape", name = "Rancher's Cape", color = "#4E9A4B" },
	{ id = "cape_gambler", slot = "cape", name = "Gambler's Cape", color = "#9A5AFF" },
	{ id = "cape_ranger", slot = "cape", name = "Ranger's Cape", color = "#FF8C28" },
	{ id = "poster_classic", slot = "poster", name = "Classic Wanted", nuggets = 30, color = "#F3E2C0" },
	{ id = "poster_gold", slot = "poster", name = "Golden Bounty", nuggets = 200, color = "#FFC83D" },
	{ id = "poster_neon", slot = "poster", name = "Neon Outlaw", nuggets = 350, color = "#3FB7B0" },
	{ id = "theme_cabin", slot = "ranchTheme", name = "Log Cabin", nuggets = 150, color = "#8A5A3B" },
	{ id = "theme_rodeo", slot = "ranchTheme", name = "Rodeo Lights", nuggets = 400, color = "#E2463A" },
	{ id = "theme_ghost", slot = "ranchTheme", name = "Ghost Town", nuggets = 700, color = "#B8F5E0" },
	{ id = "title_rookie", slot = "title", name = "Rookie Rustler", nuggets = 20, color = "#A7ADB4" },
	{ id = "title_marshal", slot = "title", name = "Marshal", color = "#E2A93B" },
	{ id = "title_legend", slot = "title", name = "Legend of the West", color = "#FF5FD2" },
	-- Bounty Trail chapter titles (earned only).
	{ id = "title_greenhorn", slot = "title", name = "Greenhorn", color = "#A7D98B" },
	{ id = "title_deputy", slot = "title", name = "Deputy", color = "#3FB7B0" },
	{ id = "title_outlaw", slot = "title", name = "Outlaw", color = "#E2463A" },
	{ id = "title_gunslinger", slot = "title", name = "Gunslinger", color = "#FF8C28" },
	{ id = "title_marshal_trail", slot = "title", name = "Marshal of the Trail", color = "#E2A93B" },
	{ id = "title_bountyhunter", slot = "title", name = "Bounty Hunter", color = "#9A5AFF" },
	{ id = "title_legend_trail", slot = "title", name = "Living Legend", color = "#FF5FD2" },
	{ id = "title_king", slot = "title", name = "King of the West", color = "#FFC83D" },
	-- Rail Pass premium track (tiers 20 and 40). Colour follows the season (Config/Season.color).
	{ id = "title_season", slot = "title", name = "Rail Baron", color = "#3FB7B0" },
	{ id = "hat_season", slot = "hat", name = "Season Stetson", color = "#3FB7B0" },
}

local byId: { [string]: Cosmetic } = {}
for _, cosmetic in list do
	byId[cosmetic.id] = cosmetic
end

return {
	list = list,
	byId = byId,
	-- Trading Post: how many cosmetics are in stock at once, and how often stock rotates.
	stockSize = 4,
	restockSeconds = 5 * 60,
}
