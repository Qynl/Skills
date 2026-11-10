# Architecture

## The split

| Layer | Runs on | Owns | Never does |
|---|---|---|---|
| Server services | server | authority, persistence, validation | trust client values, render |
| Shared modules | both | config, remote names, pure helpers | hold run state |
| Client controllers | client | input, UI, prediction, camera, sound | decide outcomes, write data |
| Instances | replicated | data + visuals | store secrets (everything in a place is readable) |

Anything in a place file is visible to clients. Never put API keys, admin lists you care about, or "secret" logic in a Script — put secrets in `ServerStorage` or, better, nowhere in the place.

## Service skeleton

```lua
--!strict
-- ServerScriptService.Server.ShopService
local ShopService = {}

local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)

local started = false

function ShopService.start()
	assert(not started, "ShopService.start() called twice")
	started = true
	-- connect remotes, spawn loops, etc.
end

return ShopService
```

`Main.server.luau`:

```lua
local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)
local RoundService = require(script.Parent.RoundService)

DataService.start()      -- data before economy
ShopService.start()      -- economy before rounds (rounds award coins)
RoundService.start()
```

Ordering is explicit because dependencies are explicit. If a service needs another, require it at the top and call its functions — don't reach through globals.

## Remotes with validation

```lua
-- Shared/Remotes.luau owns the names; server creates, clients wait.
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShopPurchase = Remotes.get("ShopPurchase") :: RemoteFunction

ShopPurchase.OnServerInvoke = function(player: Player, itemId: unknown)
	-- 1. shape
	if type(itemId) ~= "string" then
		return false, "bad request"
	end
	-- 2. existence
	local item = ShopService.getItem(itemId)
	if not item then
		return false, "unknown item"
	end
	-- 3. rate limit
	if not ShopService.allowPurchase(player) then
		return false, "slow down"
	end
	-- 4. authority
	local coins = DataService.get(player).coins
	if coins < item.price then
		return false, "not enough coins"
	end
	-- 5. apply, then tell the client the truth
	DataService.addCoins(player, -item.price)
	ShopService.grant(player, item.id)
	return true, "purchased"
end
```

Every handler reads in that order: shape → existence → rate → authority → apply. Return `(ok, message)` rather than throwing, so the client can display something useful and the server doesn't spam the console.

Rate limiting:

```lua
local lastCall: { [Player]: number } = {}

function ShopService.allowPurchase(player: Player): boolean
	local now = os.clock()
	if (lastCall[player] or 0) + 0.25 > now then
		return false
	end
	lastCall[player] = now
	return true
end
```

Clean the table on `PlayerRemoving` so it doesn't leak.

## State flow

Round state lives on the server and is *pushed*:

```lua
-- server
local state = { phase = "Intermission", timeLeft = 15, mapName = "Tavern" }
local function broadcast()
	RoundState:FireAllClients(state)
end
```

```lua
-- client
RoundState.OnClientEvent:Connect(function(newState)
	state.phase = newState.phase
	state.timeLeft = newState.timeLeft
	ui:Render(state)
end)
```

For values a client may need on join (or after a streamed-in region), also keep them as replicated attributes or send them in a `RequestState` RemoteFunction at spawn. Fire-and-forget events alone leave late joiners with a blank HUD.

## Round loop

```lua
local function runRound()
	phase = "Playing"
	timeLeft = Config.RoundSeconds
	broadcast()
	while timeLeft > 0 do
		task.wait(1)
		timeLeft -= 1
		if #Players:GetPlayers() == 0 then
			return   -- empty server, stop cleanly
		end
		broadcast()
	end
	phase = "Results"
	broadcast()
	awardWinners()
	task.wait(5)
end
```

Use `task.spawn` once at startup, guard with a `running` flag, and make sure the loop exits when the server empties. `task.wait(1)` for a countdown is correct; polling at 60 Hz for a second-based timer is not.

## Client controllers

```lua
-- Client/Main.client.luau
local Hud = {}
function Hud.mount()
	-- build ScreenGui once; update via set functions, not rebuilds
end
Hud.mount()
RoundState.OnClientEvent:Connect(function(state) Hud.setRound(state) end)
```

- Build UI **once** in `mount()`, then mutate text/visibility. Rebuilding a ScreenGui on every state change is a common source of flicker and lag.
- Keep client state in a small table (`local state = { coins = 0 }`) and pass it to render functions; don't read from instances scattered across the place.
- Handle `CharacterAdded` for anything attached to the avatar, and disconnect old connections (`connection:Disconnect()`), or you stack handlers on respawn.

## Streaming-safe code

With `StreamingEnabled`, instances far from the player may not exist on the client. That means:

- Client scripts must not assume a part exists — use `WaitForChild` with a timeout and handle absence, or drive visuals from server state.
- Keep gameplay-relevant models `ModelStreamingMode = Atomic` so they arrive as a unit.
- `CollectionService` tags replicate on the server; the tagged instance may stream in later, so also handle `GetInstanceAddedSignal`.

## Teleports and multi-place

- `TeleportService:Teleport(placeId, player)` for single players; `TeleportAsync` with `TeleportOptions` for parties.
- Pass small data via `TeleportData` (client-readable — never secrets), or write to a DataStore keyed by a short-lived code and read it in the destination.
- `game:BindToClose` and save on `PlayerRemoving` cover the shutdown path.
- Reserved servers (`TeleportService:ReserveServer`) for private lobbies; treat reserved server IDs as secrets-ish (they're per-session access).

## Where people get stuck

- **Nothing happens on the client**: remote created client-side instead of server-side, or the client connected before the remote existed. Server calls `ensureAll()` at boot; client `WaitForChild`s with a timeout.
- **Works in Play Solo, not live**: server assumed players joined after the script ran. Add the `for _, player in Players:GetPlayers() do onPlayerAdded(player) end` pass at boot.
- **Coins duplicate after rejoin**: granted from the client, or the purchase wasn't idempotent, or the save wrote an old cache after a newer one.
- **Random nil errors**: character/Humanoid accessed before spawn; `character:WaitForChild("Humanoid", 5)` and bail out gracefully.
- **Server hangs**: a `RemoteFunction` invoked server→client, or a `while` loop with no yield.
