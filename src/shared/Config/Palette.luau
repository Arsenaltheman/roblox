--!strict
-- Art-direction colors (see docs/ART_BIBLE.md). Hex strings so this module also loads under Lune;
-- use Palette.color(name) in Roblox code.

local Palette = {
	sand = "#E8B97E",
	sandDark = "#C98F55",
	dirt = "#B9774A",
	wood = "#8A5A3B",
	woodDark = "#5B3A26",
	woodLight = "#B9835A",
	rail = "#6D6A70",
	iron = "#3B3A3F",
	brass = "#E2A93B",
	gold = "#FFC83D",
	cactus = "#4E9A4B",
	cactusDark = "#357A3A",
	sky = "#3FB7B0",
	skyDeep = "#1E6F86",
	paper = "#F3E2C0",
	ink = "#2B1D14",
	red = "#E2463A",
	purple = "#9A5AFF",
	cream = "#FFF4DD",
	rock = "#B06A45",
	rockDark = "#8A4E33",
}

local function hexToRgb(hex: string): (number, number, number)
	local r = tonumber(string.sub(hex, 2, 3), 16) :: number
	local g = tonumber(string.sub(hex, 4, 5), 16) :: number
	local b = tonumber(string.sub(hex, 6, 7), 16) :: number
	return r, g, b
end

return {
	hex = Palette,
	rgb = hexToRgb,
	-- Roblox-only helper.
	color = function(nameOrHex: string): Color3
		local hex = Palette[nameOrHex] or nameOrHex
		local r, g, b = hexToRgb(hex)
		return Color3.fromRGB(r, g, b)
	end,
}
