--!strict
-- Every network message in the game. Pure data so tests can check that each client->server
-- message has a rate limit (src/shared/Sim/RateLimit.luau).

return {
	-- Client -> server requests (RemoteEvents). The server validates and rate-limits every one.
	clientToServer = {
		"BuyCage",
		"Collect",
		"Sell",
		"Place",
		"Lock",
		"StealStart",
		"StealCancel",
		"Lasso",
		"CrackStart",
		"Hatch",
		"Claim",
		"Frontier",
		"ShopBuy",
		"Equip",
		"Setting",
		"Sticker",
		"SheriffPower",
		"Lockpick",
		"ClientLog",
		"BugReport",
		"HeistGrab",
		"BuyBoots",
		"SpinWheel",
		"BuyGear",
		"UseGear",
		"HitBoss",
		"Sprint",
		"TradeInvite",
		"TradeRespond",
		"TradeOffer",
		"TradeNuggets",
		"TradeReady",
		"TradeCancel",
	},
	-- Client -> server with a reply (RemoteFunctions). Kept minimal.
	functions = {
		"GetOdds",
	},
	-- Server -> client messages.
	serverToClient = {
		"State",
		"TrainManifest",
		"CageSold",
		"CarryState",
		"Reveal",
		"Announce",
		"Toast",
		"Fx",
		"WheelResult",
		"TradeInvited",
		"TradeState",
	},
}
