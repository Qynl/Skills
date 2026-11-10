--!strict
--[[
	DataService — session-locked player data.

	This is a teaching implementation of the moving parts: pcall + backoff,
	a session lock so two servers can't write the same save, schema versioning,
	debounced autosave, and save-on-leave/shutdown.

	For production, use ProfileStore (or ProfileService): it has years of
	hardening around crashes, region failover and transaction queues. Read this
	file for the concepts, ship the library.

	Requires: ReplicatedStorage.Shared.Config
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local STORE = DataStoreService:GetDataStore(Config.DataStoreName)

-- A unique id for this server session. game.JobId is empty in Studio, so fall
-- back to something unique enough for local testing.
local SESSION_ID = if game.JobId ~= "" then game.JobId else ("studio-%d-%d"):format(os.time(), math.random(1, 1e6))

type PlayerData = {
	coins: number,
	wins: number,
	owned: { [string]: boolean },
}

local DEFAULT_DATA: PlayerData = {
	coins = Config.StartingCoins,
	wins = 0,
	owned = {},
}

local cache: { [Player]: PlayerData } = {}
local started = false
local autosaveThread: thread?

-- ------------------------------------------------------------------ helpers

local function retry<T>(fn: () -> T, attempts: number?): (boolean, T?)
	local tries = attempts or 4
	local lastErr: any
	for i = 1, tries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		-- 0.5s, 1s, 2s, ... with a little jitter so servers don't sync up
		task.wait(0.5 * 2 ^ (i - 1) + math.random() * 0.25)
	end
	warn(("[data] gave up after %d attempts: %s"):format(tries, tostring(lastErr)))
	return false, nil
end

local function keyFor(userId: number): string
	return "u_" .. tostring(userId)
end

local function copyOf(data: PlayerData): PlayerData
	return {
		coins = data.coins,
		wins = data.wins,
		owned = table.clone(data.owned),
	}
end

-- v0 -> current. Add a step per schema bump; never edit an old step.
local MIGRATIONS: { [number]: (record: any) -> any } = {
	[1] = function(record: any): any
		local data = record.data or {}
		data.coins = tonumber(data.coins) or 0
		data.wins = tonumber(data.wins) or 0
		data.owned = if type(data.owned) == "table" then data.owned else {}
		record.data = data
		return record
	end,
}

local function migrate(record: any): any
	local version = tonumber(record.schema) or 0
	while version < Config.SchemaVersion do
		version += 1
		local step = MIGRATIONS[version]
		if step then
			record = step(record)
		end
		record.schema = version
	end
	return record
end

local function leaderstatsFor(player: Player): (Folder?, IntValue?)
	local folder = player:FindFirstChild("leaderstats")
	if folder and folder:IsA("Folder") then
		local coins = folder:FindFirstChild("Coins")
		if coins and coins:IsA("IntValue") then
			return folder, coins
		end
	end
	return nil, nil
end

-- ------------------------------------------------------------------ public

local DataService = {}

function DataService.start(): ()
	assert(not started, "DataService.start() called twice")
	started = true

	Players.PlayerRemoving:Connect(function(player)
		DataService.save(player, true)
		cache[player] = nil
	end)

	-- Players who joined before this script ran still need setup.
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(DataService.onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(DataService.onPlayerAdded)

	-- One autosave loop for everyone (a loop per player is a classic leak).
	autosaveThread = task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for player in pairs(cache) do
				if player.Parent then
					DataService.save(player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in pairs(cache) do
			pending += 1
			task.spawn(function()
				DataService.save(player, true)
				pending -= 1
			end)
		end
		-- Roblox gives roughly 30s to shut down; wait a little, then let go.
		local waited = 0
		while pending > 0 and waited < 10 do
			task.wait(0.25)
			waited += 0.25
		end
	end)
end

function DataService.load(player: Player): (boolean, string?)
	if cache[player] then
		return true, nil
	end

	local key = keyFor(player.UserId)
	local locked = false

	local ok = retry(function()
		return STORE:UpdateAsync(key, function(old: any)
			old = old or {}
			local lock = old.lock
			local now = os.time()

			-- Someone else holds a fresh lock: cancel this write (nil) and bail.
			if lock and lock.session ~= SESSION_ID and type(lock.ts) == "number" and (now - lock.ts) < Config.SessionLockSeconds then
				locked = true
				return nil
			end

			local record = migrate(old)
			record.data = record.data or copyOf(DEFAULT_DATA)
			record.lock = { session = SESSION_ID, ts = now }
			return record
		end)
	end)

	if locked then
		return false, "Your data is open in another server. Rejoin in a minute."
	end
	if not ok then
		return false, "Could not load your data. Please rejoin."
	end

	-- Read it back so we get the post-migration shape (UpdateAsync returns the
	-- written record via GetAsync only in newer API variants, so re-fetch).
	local fetchedOk, record = retry(function()
		return STORE:GetAsync(key)
	end)
	if not fetchedOk or type(record) ~= "table" or type(record.data) ~= "table" then
		return false, "Could not read your data. Please rejoin."
	end

	local data: PlayerData = {
		coins = tonumber(record.data.coins) or 0,
		wins = tonumber(record.data.wins) or 0,
		owned = if type(record.data.owned) == "table" then record.data.owned else {},
	}
	cache[player] = data

	local folder, coinsValue = leaderstatsFor(player)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
		coinsValue = Instance.new("IntValue")
		coinsValue.Name = "Coins"
		coinsValue.Parent = folder
	end
	if coinsValue then
		coinsValue.Value = data.coins
	end
	return true, nil
end

function DataService.onPlayerAdded(player: Player): ()
	local ok, message = DataService.load(player)
	if not ok then
		player:Kick(message or "Data error. Please rejoin.")
	end
end

function DataService.get(player: Player): PlayerData?
	local data = cache[player]
	if not data then
		return nil
	end
	return copyOf(data)
end

function DataService.addCoins(player: Player, amount: number): boolean
	local data = cache[player]
	if not data then
		return false
	end
	local next = math.max(0, data.coins + math.floor(amount))
	local delta = next - data.coins
	if delta == 0 then
		return false
	end
	data.coins = next

	local _, coinsValue = leaderstatsFor(player)
	if coinsValue then
		coinsValue.Value = next
	end

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local changed = remotes and remotes:FindFirstChild("PlayerDataChanged")
	if changed and changed:IsA("RemoteEvent") then
		changed:FireClient(player, { coins = next })
	end
	return true
end

function DataService.addWin(player: Player): ()
	local data = cache[player]
	if data then
		data.wins += 1
	end
end

function DataService.owns(player: Player, itemId: string): boolean
	local data = cache[player]
	return data ~= nil and data.owned[itemId] == true
end

function DataService.grant(player: Player, itemId: string): ()
	local data = cache[player]
	if data then
		data.owned[itemId] = true
	end
end

function DataService.save(player: Player, releaseLock: boolean): boolean
	local data = cache[player]
	if not data then
		return false
	end
	local key = keyFor(player.UserId)

	local ok = retry(function()
		return STORE:UpdateAsync(key, function(old: any)
			old = old or {}
			-- Someone else took the lock while we were alive: don't clobber them.
			if old.lock and old.lock.session ~= SESSION_ID and not releaseLock then
				return nil
			end
			old.schema = Config.SchemaVersion
			old.data = data
			old.lock = if releaseLock then nil else { session = SESSION_ID, ts = os.time() }
			return old
		end)
	end, 3)

	if not ok then
		warn(("[data] save failed for %s (%d)"):format(player.Name, player.UserId))
	end
	return ok
end

function DataService.heartbeat(): () -- call every 30s from a service if you want lock refresh
	for player in pairs(cache) do
		local key = keyFor(player.UserId)
		retry(function()
			return STORE:UpdateAsync(key, function(old: any)
				if old and old.lock and old.lock.session == SESSION_ID then
					old.lock.ts = os.time()
					return old
				end
				return nil
			end)
		end, 2)
	end
end

return DataService
