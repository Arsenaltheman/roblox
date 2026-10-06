--!strict
-- UI design tokens (docs/ART_BIBLE.md). Chunky, warm, Western: thick dark outlines, rounded corners,
-- wanted-poster paper, brass accents. Every rarity color is paired with an icon (color-blind safe).

local Palette = require("@game/ReplicatedStorage/Shared/Config/Palette")
local Rarities = require("@game/ReplicatedStorage/Shared/Config/Rarities")
local Mutations = require("@game/ReplicatedStorage/Shared/Config/Mutations")

local C = Palette.color

local Theme = {}

Theme.color = {
	ink = C("ink"),
	paper = C("paper"),
	cream = C("cream"),
	wood = C("wood"),
	woodDark = C("woodDark"),
	brass = C("brass"),
	gold = C("gold"),
	red = C("red"),
	sky = C("sky"),
	skyDeep = C("skyDeep"),
	green = Color3.fromRGB(95, 203, 78),
	white = Color3.new(1, 1, 1),
	shadow = Color3.fromRGB(43, 29, 20),
	cash = Color3.fromRGB(120, 220, 90),
	nugget = Color3.fromRGB(255, 200, 61),
	-- Bright accents for buttons and tiles (each menu gets its own colour).
	orange = Color3.fromRGB(255, 140, 40),
	purple = Color3.fromRGB(150, 90, 255),
	pink = Color3.fromRGB(255, 95, 170),
	teal = Color3.fromRGB(30, 200, 200),
	blue = Color3.fromRGB(60, 150, 255),
	yellow = Color3.fromRGB(255, 205, 40),
}
Theme.color.green = Color3.fromRGB(70, 215, 70)

Theme.font = {
	title = Font.fromEnum(Enum.Font.LuckiestGuy),
	heading = Font.fromEnum(Enum.Font.FredokaOne),
	number = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold),
	body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
}

Theme.stroke = 3
Theme.corner = UDim.new(0, 14)

function Theme.rarityColor(id: string): Color3
	local rarity = Rarities.byId[id]
	return if rarity then C(rarity.color) else Theme.color.paper
end

function Theme.rarityForTier(tier: number): Color3
	return C(Rarities.forTier(tier).color)
end

function Theme.mutationColor(id: string?): Color3?
	if not id or id == "" then
		return nil
	end
	local mutation = Mutations.byId[id]
	return if mutation then C(mutation.color) else nil
end

-- Small glyphs paired with rarity colors (no image assets needed).
Theme.rarityGlyph = {
	circle = "●",
	triangle = "▲",
	square = "■",
	diamond = "◆",
	star = "★",
	flame = "✦",
	skull_hat = "☠",
	question = "?",
}

function Theme.glyphFor(rarityId: string): string
	local rarity = Rarities.byId[rarityId]
	return if rarity then (Theme.rarityGlyph[rarity.icon] or "●") else "●"
end

-- Lighter / darker variants for gradients.
function Theme.lighten(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), amount)
end

function Theme.darken(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), amount)
end

return Theme
