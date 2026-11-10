--!strict
-- Single source of truth for network endpoints.
--
-- The SERVER creates them (Remotes.ensureAll()), clients wait for them
-- (Remotes.get(name)). Creating remotes from the client silently doesn't
-- replicate, which is the #1 "my remote does nothing" bug.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

type Definition = { name: string, className: string }

local DEFINITIONS: { Definition } = {
	{ name = "RoundState", className = "RemoteEvent" }, -- server -> all clients: state table
	{ name = "PlayerDataChanged", className = "RemoteEvent" }, -- server -> one client: { coins = n }
	{ name = "ShopPurchase", className = "RemoteFunction" }, -- client -> server: (itemId) -> (ok, message)
	{ name = "CollectCoin", className = "RemoteEvent" }, -- client -> server: (coinId) intent
}

local Remotes = {}

local function getFolder(create: boolean): Folder?
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if not create then
		return nil
	end
	if RunService:IsClient() then
		return nil -- never create from the client
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

-- Server: create every endpoint once, at boot. Returns name -> instance.
function Remotes.ensureAll(): { [string]: Instance }
	local folder = getFolder(true)
	assert(folder, "Remotes.ensureAll() must be called on the server")

	local map: { [string]: Instance } = {}
	for _, definition in DEFINITIONS do
		local instance = folder:FindFirstChild(definition.name)
		if not instance then
			instance = Instance.new(definition.className)
			instance.Name = definition.name
			instance.Parent = folder
		end
		map[definition.name] = instance
	end
	return map
end

-- Both sides: resolve an endpoint. The client waits (with timeout) because the
-- server may not have booted yet; on the server it must already exist.
function Remotes.get(name: string, timeout: number?): Instance
	local folder = getFolder(false)
	if folder then
		local found = folder:FindFirstChild(name)
		if found then
			return found
		end
	end

	if RunService:IsServer() then
		error(("remote %q is missing — call Remotes.ensureAll() at server boot"):format(name))
	end

	local waited = folder and folder:WaitForChild(name, timeout or 15)
	assert(waited, ("timed out waiting for remote %q"):format(name))
	return waited
end

return Remotes
