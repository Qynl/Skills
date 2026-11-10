--!strict
-- Server entry point. The ONLY Script: create remotes, boot services in
-- dependency order, then wire the network handlers.
--
-- Order matters: data before economy, economy before rounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require(script.Parent.DataService)
local RoundService = require(script.Parent.RoundService)

-- 1. endpoints must exist before any service fires them
local endpoints = Remotes.ensureAll()

-- 2. persistence, then gameplay
DataService.start()
RoundService.start(endpoints)

-- 3. one validated handler per endpoint ------------------------------------

local ShopPurchase = endpoints.ShopPurchase :: RemoteFunction
local CollectCoin = endpoints.CollectCoin :: RemoteEvent
local PlayerDataChanged = endpoints.PlayerDataChanged :: RemoteEvent

local purchaseTimestamps: { [Player]: number } = {}

local function rateLimited(player: Player): boolean
	local now = os.clock()
	local last = purchaseTimestamps[player] or 0
	if now - last < 1 / Config.MaxPurchasePerSecond then
		return true
	end
	purchaseTimestamps[player] = now
	return false
end

local function findShopItem(itemId: string)
	for _, item in ipairs(Config.Shop) do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

ShopPurchase.OnServerInvoke = function(player: Player, itemId: any): (boolean, string)
	-- shape -> existence -> rate -> authority -> apply -> report
	if type(itemId) ~= "string" or #itemId > 64 then
		return false, "Bad request."
	end
	local item = findShopItem(itemId)
	if not item then
		return false, "Unknown item."
	end
	if rateLimited(player) then
		return false, "Slow down."
	end

	local data = DataService.get(player)
	if not data then
		return false, "Your data is still loading."
	end
	if DataService.owns(player, item.id) and item.id == "trail" then
		return false, "You already own that."
	end
	if data.coins < item.price then
		return false, "Not enough coins."
	end

	DataService.addCoins(player, -item.price)
	DataService.grant(player, item.id)

	-- Tell THIS client the truth; the balance change is mirrored separately.
	PlayerDataChanged:FireClient(player, { coins = data.coins - item.price })
	return true, ("Bought %s."):format(item.name)
end

CollectCoin.OnServerEvent:Connect(function(player: Player, coinId: any)
	-- Intent only: the server decides whether the coin exists and is close
	-- enough. Never let the client say "I got 500 coins".
	if type(coinId) ~= "string" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local coin = workspace:FindFirstChild(coinId, true)
	if not coin or not coin:IsA("BasePart") then
		return
	end
	if (coin.Position - root.Position).Magnitude > 12 then
		return -- out of reach; drop it
	end

	DataService.addCoins(player, Config.CoinPickupValue)
	coin:Destroy()
end)

Players.PlayerRemoving:Connect(function(player)
	purchaseTimestamps[player] = nil
end)

print("[server] starter booted:", #Config.Shop, "shop items |", Config.RoundSeconds, "s rounds")
