--!strict
-- Shared tuning. The server is authoritative over everything here; the client
-- only reads it for display (round length, shop labels).

local Config = {
	-- Rounds
	IntermissionSeconds = 15,
	RoundSeconds = 180,
	ResultsSeconds = 5,
	MinPlayersToStart = 1, -- raise for a real lobby; 1 is for solo testing

	-- Economy
	StartingCoins = 0,
	WinReward = 50,
	ParticipationReward = 10,
	CoinPickupValue = 5,

	-- Shop (server-validated; the client never sends a price)
	Shop = {
		{
			id = "speed",
			name = "Quick Boots",
			description = "+15% walk speed for the rest of the round",
			price = 100,
		},
		{
			id = "magnet",
			name = "Coin Magnet",
			description = "Pull nearby coins toward you",
			price = 250,
		},
		{
			id = "trail",
			name = "Victory Trail",
			description = "Cosmetic trail, permanent",
			price = 500,
		},
	},

	-- Data
	DataStoreName = "PlayerData_v1",
	SchemaVersion = 1,
	AutosaveSeconds = 120,
	SessionLockSeconds = 60,

	-- Safety rails
	MaxPurchasePerSecond = 4,
}

return Config
