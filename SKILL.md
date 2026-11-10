---
name: roblox-game-dev
description: Builds, extends and debugs Roblox games — Luau scripting, server/client architecture, remotes, round systems, DataStores, economy, UI, monetization, testing and publishing. Use this skill whenever someone is making a Roblox game: "make me a Roblox game", "add coins / a shop / a leaderboard / a battle pass to my Roblox game", "my Roblox script isn't working", "how do I save player data in Roblox", "the remote event is being exploited", "set up Rojo", "add a round system", or any mention of Roblox Studio scripting, Studio MCP execute_luau for code, Luau, DataStoreService, RemoteEvent/RemoteFunction, ProfileStore, MarketplaceService, or Rojo project files. Covers architecture through to shipping and verification. For environment art, lighting and set dressing, use the roblox-build skill instead.
---

# Roblox game development

Roblox code fails in predictable ways: logic that trusts the client, remotes with no validation, data that isn't session-locked, per-frame work that should be event-driven, and features that work in Play Solo but not with two players. This skill is the architecture and the checklist that avoids those, plus the order to build in so you always have something playable.

## The one rule

**The server owns state. The client owns presentation.**

Anything the player can exploit is server-side: currency, inventory, damage, cooldowns, round outcomes, purchases. The client sends *intent* ("I want to buy X", "I pressed fire") and renders *results* (a replicated value changed). Every bug where a player has infinite coins is a violation of this rule, and it is much cheaper to design for than to audit later.

## Architecture that scales past a prototype

```
ReplicatedStorage/
  Shared/            Config, Remotes, Types, Signals, pure helpers  (no state)
ServerScriptService/
  Server/            Main.server.luau  <- the only Script; boots services
                     DataService, RoundService, ShopService (ModuleScripts)
StarterPlayer/StarterPlayerScripts/
  Client/            Main.client.luau  <- the only LocalScript; boots UI/input
```

- **One entry point per side.** `Main.server` requires and starts services in order (data → economy → rounds → gameplay). `Main.client` builds UI and connects to remotes. A dozen loose Scripts with implicit ordering is the main reason bigger Roblox projects become unmaintainable.
- **Services are ModuleScripts** with `start()`, explicit dependencies, and no top-level side effects beyond defining state. They're testable and reloadable.
- **Shared is stateless.** Config, remote definitions, and pure functions. If it holds run state, it's not shared.
- **`CollectionService` tags** over name-matching or giant if-chains: tag a model `"Generator"` and one system handles all of them.
- **Attributes for replicated, simple state** (`coins`, `roundPhase`), remotes for events, ModuleScripts for logic. Avoid `_G`, avoid `BindableEvent` for cross-module calls (use a small Signal module).

`references/architecture.md` has the full patterns: remotes with validation, service skeleton, round loop, client state store, streaming-safe code, teleporting, and how to test with multiple clients.

## Build order: vertical slice first

Do not build "all the systems" then connect them. Build one mechanic end-to-end:

1. Server: the authoritative rule (e.g. "claiming a generator gives coins after 5 seconds").
2. Remote: client intent in, validated; state out.
3. Client: input + feedback + UI for that state.
4. Data: persist the one number it changes.
5. Test with two players, then a mobile-sized viewport.

That slice defines the conventions everything else copies. Only then add the shop, the round timer, the second mechanic. A Roblox game with one polished loop beats five half-connected systems, and shipping is usually the thing that teaches you what's missing.

## Luau rules that matter

- `task.wait` / `task.spawn` / `task.delay` — never legacy `wait()`/`spawn()`/`delay()`. The legacy ones are throttled and buggy under load.
- **Event-driven over polling.** `RunService.Heartbeat` for continuous simulation, `task.wait(1)` for a countdown, `GetPropertyChangedSignal` for state. No `while true do if condition then ... end wait() end` spin loops.
- `--!strict` on shared and service modules. Types catch the "nil on first join" class of bugs that dominate Roblox errors.
- Avoid creating instances in `RenderStepped`/`Heartbeat`. Pool effects; reuse UI.
- `table.clone` shallow-copies; deep-copy config only when you must. Never hand a caller your internal table.
- Cache service references at module top (`local Players = game:GetService("Players")`), not inside loops.
- Use `for _, v in list do` (generalized iteration) and `continue` instead of nesting.
- Guard `player.PlayerGui`, `character`, `HumanoidRootPart` — they're absent before spawn and after death. `character:WaitForChild("Humanoid")`, and re-check on `CharacterAdded`.

`references/luau.md` covers idioms, gotchas, and performance patterns in more depth.

## Networking

```lua
-- Shared endpoint definitions (server creates, clients wait)
local RoundState = Remotes.get("RoundState") :: RemoteEvent
```

- **`RemoteEvent`** for anything one-way or fire-and-forget. **`RemoteFunction`** only for client→server questions with an immediate answer (a shop purchase), and never server→client (a client can hang the server's thread by not returning).
- **`UnreliableRemoteEvent`** for high-frequency ephemeral data (positions, cosmetics) where dropping is fine; never for purchases.
- **Validate everything**: types, ranges, ownership, phase, cooldown, and whether the player can afford it. Server-side cooldowns, not just client-side.
- **Rate limit per player** in the handler (e.g. one purchase per 0.25 s) — a loop of 10k remote calls is a one-line exploit.
- Responses should be small and idempotent. For purchases, the server's decision is the truth; the client just displays it.

## Data

- `DataStoreService` with a **session lock** so two servers can't write the same player's data. Use **ProfileStore / ProfileService** for production; the bundled `assets/project/src/server/DataService.luau` is a teaching implementation of the same idea.
- Respect budgets: ~60 reads + 60 writes per minute per key is the practical ceiling; DataStores are not a database. Batch, debounce (save on leave + every 120 s + on purchase), and never save per coin.
- **Version your schema** (`schema = 1`) and write a migration function before you need one. Adding a field with a default is easy; changing a field's meaning without a migration corrupts saves.
- `pcall` every DataStore call, retry with backoff, and never lose the player's data because of a transient 502. On a failed save, keep the cache and retry; on a failed load, kick the player with a clear message rather than starting them at zero.
- `leaderstats` for the numbers the player should see on the player list; attributes for everything else. Create `leaderstats` on `PlayerAdded`, and handle players who joined before the script ran.

`references/data-and-economy.md` covers locking, migrations, currency design, shop pricing, passes and dev products.

## UI

- `ScreenGui` + `Frame`s sized in **`Scale`** with `UIAspectRatioConstraint`, or `Offset` with an explicit `UIScale` — never pixel values that break on phones.
- `TextScaled` or `UITextSizeConstraint`; the default text size is unreadable on a 360px-wide phone.
- Respect `GuiService:GetGuiInset()` for top bars, and keep tap targets ≥44 px.
- UI reads state, never computes authority. If the client shows 500 coins and the server thinks 50, the server is right and the client is out of sync — send the truth.
- `TweenService` for transitions (0.12–0.2 s), `UIStroke`/`UICorner` for shape. Avoid per-frame layout reads (`AbsoluteSize` in a loop) — they force reflow.

## Monetization (if the game has it)

- **Passes** = permanent unlocks; **Developer Products** = repeatable purchases (currency, boosts). Both go through `MarketplaceService`.
- `ProcessReceipt` must be **idempotent**: store the `PurchaseId` and return `PurchaseGranted` only once, even if Roblox retries. This is the single most common monetization bug.
- Show the price from `GetProductInfo`, handle `PromptProductPurchaseFinished` / `PromptGamePassPurchaseFinished` by granting on the server, and never grant from a client signal.
- Price anchoring: the smallest pack should feel like a snack, the middle one like the best deal. Don't gate core progression behind Robux in a game aimed at kids — design for cosmetics/convenience, and check Roblox's current paid-random-item and policy rules before shipping anything loot-box-shaped.

## Test like it's multiplayer

Play Solo lies. Before saying it works:

1. **Two clients** (Studio's multi-client test with 2 players) — does the round start, does one player's purchase affect only them, does data save when one leaves?
2. **`--!strict` + `luau-analyze`** on the modules (the CLI is on GitHub releases: `luau-analyze --mode=nonstrict src/**/*.luau` catches typos before runtime).
3. **Server console clean**: no infinite yields, no "attempt to index nil".
4. **Mobile viewport** at 360×640 — UI legible, buttons reachable.
5. **Rejoin** — data persisted, leaderstats correct, no duplicate currency.
6. **Exploit sanity**: fire the remote from the client console with garbage arguments; the server should reject it, not error into a crash.

With the Studio MCP server you can `start_stop_play`, drive input with `user_keyboard_input`/`user_mouse_input`, walk with `character_navigation`, and read `get_console_output` — use it to actually verify instead of asserting. If you can't playtest, say what you verified statically.

`references/testing-and-shipping.md` has the test matrix, publishing flow, versioning, and analytics.

## What's in this skill

| Path | Read it when |
|---|---|
| `assets/project/` | **Starting a new game.** A Rojo-ready vertical slice: `Config`, typed `Remotes`, session-locked `DataService`, `RoundService` with a signal, server entry with a validated shop purchase, and a client HUD. `assets/project/README.md` explains install and paste-in-Studio fallback. |
| `references/architecture.md` | Designing modules, remotes, round/state flow, client stores, streaming and teleports. |
| `references/luau.md` | Language idioms, common runtime errors, performance, and style. |
| `references/data-and-economy.md` | Saving, session locks, migrations, currency, shops, passes/products. |
| `references/testing-and-shipping.md` | Multi-client tests, MCP playtesting, publishing, rollouts, analytics. |
| `evals/evals.json` | To test whether this skill is producing working games. |

## Anti-patterns

- Client-authoritative currency, damage, or inventory ("the client said it has 999999 coins").
- Remote handlers without type/range/ownership/cooldown checks, or one global rate limit shared by everyone.
- `while true do ... task.wait() end` polling where an event exists.
- Saving on every change, or not saving on `PlayerRemoving` (and on `game:BindToClose`).
- DataStore calls outside `pcall`, or retry loops with no backoff.
- One giant Script with 2000 lines and no module boundaries.
- `RemoteFunction` called server→client.
- Creating parts/UI every frame.
- Building four systems before any of them works with two players.
- Reporting "works" from Play Solo, or from code that only compiled.
