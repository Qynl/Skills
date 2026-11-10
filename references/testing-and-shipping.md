# Testing and shipping

## The test matrix

Run this before claiming a Roblox feature works:

| Test | How | What it catches |
|---|---|---|
| Two clients | Studio multi-client test, 2 players | state leaking between players, round-start assumptions |
| Late join | join after the round started | missing initial state sync, nil character |
| Rejoin | leave, rejoin | data persistence, duplicate grants, lock leaks |
| Respawn | die in-game | connections re-added, HUD reset, character refs |
| Mobile viewport | 360×640 device emulation | unreadable UI, unreachable buttons |
| Garbage remotes | fire from the client console with `nil`, tables, huge strings | server errors, exploits |
| Empty server | everyone leaves mid-round | loops that never exit |
| Shutdown | stop the server with players | save on `BindToClose` |

Static checks that catch things before you run anything:

```bash
luau-analyze --mode=nonstrict src/server/*.luau src/shared/*.luau
stylua --check src
```

`luau-analyze` needs Roblox type definitions to be fully useful; without them it still catches syntax errors, shadowing, and obvious nil arithmetic. Add `--!strict` to shared modules and treat analyzer errors as build failures.

## Playtesting through Studio MCP

When the Studio MCP server is connected, you can actually drive the game:

1. `get_studio_state` — confirm you're in Edit, then `start_stop_play` to enter play mode.
2. `character_navigation` — walk the player to a position/instance to reach the thing you're testing.
3. `user_keyboard_input` / `user_mouse_input` — press the keys, click the shop button.
4. `get_console_output` — read server and client prints and errors.
5. `subagent` with `playtest` — for "can a player complete the first loop without getting stuck".
6. `start_stop_play` again to stop. Edits during play are discarded.

Rules for this workflow:

- **Never test purchases or data writes against a live DataStore.** Use a separate test key (`PlayerData_TEST_v1`) or a `Config.StudioMode` flag that swaps in an in-memory store. Buying a dev product in a test is real Robux.
- Play mode resets on stop; state you need to inspect must be printed, not assumed.
- If there is no play tool available, say so and list what you verified statically (types, analyzer, logic review) instead of "it works".

## Unit tests

Jest-Lua (or plain assertion modules) works well for pure logic: economy math, upgrade stacking, migration functions, inventory rules. Extract the rules into `shared/` modules with no instance dependencies and they become testable.

```lua
-- tests/Economy.spec.luau
local Economy = require(game.ReplicatedStorage.Shared.Economy)
return function(expect)
	expect(Economy.priceFor(1)).toBe(100)
	expect(Economy.priceFor(3)).toBe(250)
	expect(Economy.canAfford({ coins = 60 }, 100)).toBe(false)
end
```

Test the things that would corrupt data or money. Don't test that a Part exists.

## Publishing

- **Version control**: Rojo + Git. `default.project.json` builds the place from `src/`; commit code, not just the `.rbxmx`. Publishing from a build you can reproduce is the whole point.
- **Save a version before every publish** (File → Publish to Roblox → version notes). Roblox keeps version history; use it as your rollback.
- **Staged rollout**: publish to a test place / a private server first, play one full round with two clients, then publish to the live place.
- **One change per publish.** If a publish breaks something, you need to know which change did it.
- Keep a `CHANGELOG.md` with dates and the version numbers; three lines per release beats archaeology later.

## Roblox-specific shipping checklist

- [ ] `StreamingEnabled` set appropriately, models grouped and `LevelOfDetail` assigned.
- [ ] DataStore schema versioned; migration tested with an old record.
- [ ] `BindToClose` saves, and shutdown is under Roblox's ~30 s limit.
- [ ] Analytics events wired (join, first reward, purchase, round end).
- [ ] Thumbnails and icon uploaded — a game with a default icon gets no clicks.
- [ ] Title/description explain the loop in one sentence each.
- [ ] `SocialService` / age-appropriate content settings reviewed for your genre.
- [ ] Private server / reserved server behaviour tested if you ship lobbies.
- [ ] Badge/achievement IDs configured if used.
- [ ] Mobile and console input both work (no mouse-only interactions).
- [ ] Text is readable and localisable (avoid baked text in images for critical info).

## After launch

- **Read the analytics daily for a week.** Retention and funnel drop-off tell you what to build next far better than intuition.
- **Watch the error logs.** A new error spike after a publish is an instant rollback candidate.
- **Fix first, add later.** The first week's job is making the existing loop smooth, not adding a second one.
- **Balance from data, not vibes.** If 80% of players never buy the second upgrade, the price or the reward is wrong — change one variable at a time.

## Honest reporting

When you hand back a change, say:

- what you ran (multi-client? mobile? analyzer?),
- what you could not run (no Studio session, no second client, no purchase test),
- what remains unverified (visuals, feel, balance).

"It compiles and the analyzer is clean" is a useful statement. "It works" after only reading the code is not, and it costs the user more time than saying nothing.
