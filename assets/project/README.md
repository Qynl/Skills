# Roblox starter project (Rojo)

A vertical slice, not a game: coins, a 3-minute round with intermission, a validated shop, session-locked saves, and a client HUD. Copy the patterns, replace the content.

```
default.project.json
src/
  shared/Config.luau        tuning + shop table
  shared/Remotes.luau       endpoint definitions (server creates, clients wait)
  server/Main.server.luau   boots services, PlayerAdded/Removing, shop handler
  server/DataService.luau   session-locked DataStore, autosave, coins helpers
  server/RoundService.luau  intermission -> playing -> results, broadcasts state
  client/Main.client.luau   HUD, shop UI, remote listeners
```

## Install with Rojo

```bash
# from this folder
rojo serve            # then connect in Studio: Rojo plugin -> Connect
# or build a place file
rojo build -o Starter.rbxlx
```

Requires the [Rojo plugin](https://create.roblox.com/store/asset/13916111004) in Studio (or the Rojo CLI). The tree maps:

- `src/shared` → `ReplicatedStorage.Shared`
- `src/server` → `ServerScriptService.Server` (`.server.luau` becomes a `Script`)
- `src/client` → `StarterPlayer.StarterPlayerScripts.Client` (`.client.luau` becomes a `LocalScript`)

## Install without Rojo

Create the same instances by hand in Studio:

1. `ReplicatedStorage/Shared` (Folder) with `Config` and `Remotes` as ModuleScripts.
2. `ServerScriptService/Server` (Folder) with `Main` as a **Script**, and `DataService` / `RoundService` as ModuleScripts.
3. `StarterPlayer/StarterPlayerScripts/Client` (Folder) with `Main` as a **LocalScript**.

Paste each file's contents verbatim. Paths in the code use `script.Parent` and `ReplicatedStorage.Shared`, so the folder structure has to match.

## Before you run it

- `Config.MinPlayersToStart = 1` is for solo testing; raise it for a real lobby.
- DataStore calls don't work in Studio until **Game Settings → Security → Enable Studio Access to API Services** is on. If you don't want to touch real data, set `Config.DataStoreName = "PlayerData_TEST_v1"`.
- The shop is server-validated but the prices are placeholder. Change `Config.Shop` before shipping.

## What to change first

1. `Config` — round length, rewards, shop items.
2. `RoundService.runRound` — what happens during a round.
3. `Main.client` — the HUD layout and the shop panel.
4. `DataService` — the default record and `PlayerData` shape (bump `SchemaVersion` and add a migration when you do).
