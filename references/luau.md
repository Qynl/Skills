# Luau patterns and pitfalls

## Scheduling

```lua
task.wait(1)                     -- yields one frame at minimum, 1s requested
task.spawn(function() ... end)   -- start now, don't wait
task.delay(2, function() ... end)
task.defer(function() ... end)   -- run next resumption cycle
```

- Legacy `wait()`, `spawn()`, `delay()` still exist and are throttled/buggy under load. Use `task.*` everywhere.
- `task.wait()` with no argument yields one frame — that's an accidental per-frame loop. Prefer explicit `RunService.Heartbeat:Wait()`.
- `task.spawn` errors are not propagated to the caller; wrap risky bodies in `pcall` and log with context.

## Events over polling

```lua
-- yes
RunService.Heartbeat:Connect(update)
humanoid:GetPropertyChangedSignal("Health"):Connect(onHealth)
part.Touched:Connect(onTouch)          -- debounce inside

-- no
while true do
	if humanoid.Health < 50 then ... end
	task.wait()
end
```

Polling a condition every frame is both slower and less reliable than the property/attribute signal. `Touched` is famously noisy — debounce per player with a cooldown table and check `humanoid.Health > 0`.

## Types that earn their keep

```lua
--!strict
export type Item = { id: string, price: number, name: string }
export type PlayerData = { coins: number, wins: number, owned: { [string]: boolean } }

local function grant(player: Player, item: Item): boolean
	...
end
```

`--!strict` on shared modules and services catches nil-index bugs early. Type annotations on public function signatures are enough — don't annotate every local and turn the file into noise. For Roblox API types (`Instance`, `BasePart`, `RemoteEvent`), annotate at the boundary: `local remote = Remotes.get("X") :: RemoteEvent`.

## Tables and copying

```lua
local copy = table.clone(original)          -- shallow
local function deepCopy(t)                   -- explicit, only when needed
	local out = {}
	for k, v in pairs(t) do out[k] = if type(v) == "table" then deepCopy(v) else v end
	return out
end
```

Return a copy of internal state (`function Data.get(p) return table.clone(cache[p]) end`) or treat the returned table as read-only — otherwise every caller is a potential corruption bug.

## Iteration and control flow

```lua
for _, item in list do ... end                    -- generalized iteration, preferred
for i = 1, #list do ... end                      -- when you need the index
for key, value in pairs(dict) do ... end

for _, item in list do
	if not item.enabled then continue end         -- Luau `continue`
	process(item)
end
```

Don't mutate a table while iterating it; collect the changes and apply after.

## Strings

```lua
local msg = ("%s bought %s for %d"):format(player.Name, item.name, item.price)
local msg2 = `{player.Name} bought {item.name} for {item.price}`   -- interpolation
```

Interpolation is fine and readable; `:format` is slightly faster in hot paths. Avoid `..` chains in loops.

## Instances

- Cache service references at the top of the module. `game:GetService` in a loop is cheap but pointless.
- `Instance.new("Part", parent)` (parent as second arg) is discouraged: set properties first, then parent, or you pay replication cost for every intermediate state. For a few parts it doesn't matter; for hundreds it does.
- Use `WaitForChild` only where the thing genuinely might not exist yet (client startup, streamed content). `:FindFirstChild` in a loop every frame is a smell.
- `:Destroy()` disconnects connections on instances, but your own `RBXScriptConnection`s must be disconnected manually.
- Pool what you create often: effects, damage numbers, UI rows. Creating and destroying 60 parts/second is a frame-time leak.

## Numbers and math

```lua
math.clamp(x, 0, 1)
math.round(x)                     -- returns integer-valued float
Vector3.zero, CFrame.identity
humanoid:MoveTo(pos)              -- pathfinding-free movement, with MoveToFinished
humanoid:Move(direction)          -- continuous, for player-like control
```

- `os.clock()` for elapsed time, `os.time()` for wall-clock (and DataStore lock timestamps).
- Compare vectors with `.Magnitude`/`dot`, not `.X ==` component by component.
- `CFrame.lookAt(from, to)` for aiming; `Lerp` for smooth interpolation by alpha.

## Error handling

```lua
local ok, err = pcall(function()
	return Store:GetAsync(key)
end)
if not ok then
	warn(("[data] get failed for %d: %s"):format(player.UserId, tostring(err)))
end
```

- Wrap every external call (DataStore, HTTP, MarketplaceService) in `pcall`.
- Retry with exponential backoff and jitter; cap attempts; log the final failure with enough context to debug.
- Keep `warn` messages grep-able and prefixed (`[data]`, `[shop]`). Logs are your only production debugger.
- Never `error()` inside a remote handler on invalid input — return `(false, reason)`.

## Performance habits

- Nothing allocates per frame: reuse tables, pool effects, avoid `string.format` in `Heartbeat` if it's just debug output.
- Prefer `RunService.Heartbeat` for simulation tick and `RunService.RenderStepped` only for camera/visual smoothing.
- Server: `Heartbeat` at 60 Hz is fine for logic; don't run pathfinding for 50 NPCs every frame — stagger them (each NPC thinks every 0.2–0.5 s).
- `GetDescendants()` on a big workspace is expensive. Index once (build a lookup by tag/name) and update on `GetInstanceAddedSignal`/`Removed`.
- Measure with the MicroProfiler and the Developer console's script activity before optimizing; guessing usually optimizes the wrong thing.

## Style that survives a team

- Names: `PascalCase` services/modules, `camelCase` locals, `SCREAMING_CASE` constants.
- Module shape: state at top, private helpers as `local function`, public functions on the returned table, `start()` last.
- Comment the *why*, not the *what*. `-- lock before write: two servers can race` earns its line; `-- loop over players` doesn't.
- One responsibility per module; if a file needs "and" to describe it, split it.
