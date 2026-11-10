# Studio MCP workflow for building

## Connecting (when the user asks how)

The Studio MCP server ships inside Roblox Studio. Enable it in **Assistant → … → Manage MCP Servers → Enable Studio as MCP server**, then connect the client via Quick connect (Claude Code, Cursor, Codex, Gemini, VS Code, Claude Desktop, Antigravity), a JSON config, or a CLI command. macOS binary: `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`; Windows: `%LOCALAPPDATA%\Roblox\mcp.bat`. Transport is stdio; the first client connection shows a green indicator in that panel.

Config snippet (macOS):

```json
{"mcpServers": {"Roblox_Studio": {"command": "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"}}}
```

Never publish, never save over a live place, and never connect a client the user doesn't trust — MCP clients can read and modify the open place.

## The loop

```
list_roblox_studios            -> studio_id
get_studio_state               -> Edit / Client / Server availability
search_game_tree (depth 2-3)   -> what exists
inspect_instance Lighting      -> current look + settings
screen_capture (player camera) -> before
execute_luau (Edit)            -> one pass, prints a summary
screen_capture (3 angles)      -> after
inspect / fix / repeat
```

Never batch building and verification into one silent step. Each `execute_luau` pass should end with prints you can grade.

## execute_luau

- `datamodel_type` is **`Edit`** for building. `Server`/`Client` only exist while a playtest is running.
- It returns the result or an error string verbatim, and `print`/`warn` output. Treat returned errors as the source of truth; don't retry blindly with the same code.
- The sandbox is Studio's command bar: `game`, `workspace`, `Instance`, `Vector3`, `CFrame`, `Color3`, `Enum`, `task`, services via `game:GetService` are all available. `script` is **not** (there's no script context) — pass state explicitly, or have the code `require` a ModuleScript.
- Instances are live in the user's place immediately. There's no staging area unless you make one. Make one:

```lua
local root = workspace:FindFirstChild("__AgentBuild") or Instance.new("Folder")
root.Name = "__AgentBuild"
root.Parent = workspace
local build = Instance.new("Folder")
build.Name = "Tavern"
build.Parent = root
```

- Everything you create should be attributable. Set attributes at creation (`Part:SetAttribute("AgentBuild", true)`), so cleanup is `for _, d in ipairs(workspace:GetDescendants()) do if d:GetAttribute("AgentBuild") then d:Destroy() end end` and so the user can audit the diff.
- Set a history waypoint before a pass so one Ctrl+Z removes it:

```lua
game:GetService("ChangeHistoryService"):SetWaypoint("agent: tavern blockout")
```

## Writing scripts vs building

Building and scripting share `execute_luau`, but scripts should go through `multi_edit` / a `ModuleScript` so they're readable and reviewable:

```lua
local ServerStorage = game:GetService("ServerStorage")
local tools = ServerStorage:FindFirstChild("AgentTools") or Instance.new("Folder")
tools.Name = "AgentTools"
tools.Parent = ServerStorage
```

Then create a `ModuleScript` with `multi_edit` and `require` it from `execute_luau`. It's reusable within the session, editable later, and doesn't pollute the place with a giant script nobody can read. Put helper modules in `ServerStorage`, not `ServerScriptService`.

## Reading the place

- `search_game_tree`: pass a path (`Workspace.Town`), an instance type filter (`Part`, `MeshPart`), a keyword, and a depth limit. Unbounded deep searches on a big place return thousands of rows and burn context for nothing.
- `inspect_instance`: readable properties, attributes, and a child summary. Use it on `Lighting`, `Workspace`, `Terrain`, and specific models — not on every part.
- `script_read` with line ranges for existing code; `script_grep` for a name across the whole place.
- Prefer one `execute_luau` that computes statistics (`#workspace:GetDescendants()`, counts by material, bounding box) over dozens of inspect calls. Numbers are cheap, screenshots are not.

## Screen capture — the part that decides quality

`screen_capture` is the only way to know whether the build looks good, and it's also the most expensive call. Use it deliberately:

- Frame the **hero shot**: the view a player gets walking in. Camera at ~5–6 studs above the floor, looking slightly down (`0.1–0.2` radians), FOV equivalent to a normal eye view. Don't judge from a top-down plane.
- Take a second, wider shot for silhouette/composition, and a third from a spot the player will actually stand (doorway, spawn, balcony).
- Pass explicit camera position + look-at target when the tool supports it; otherwise you inherit whatever the user's viewport last showed.
- Capture after the lighting pass, not before — you're judging the lighting too.
- When you compare, name three specific flaws rather than "looks good": `the wall plane is unbroken for 40 studs`, `window trim is missing so openings read as holes`, `the doorway is too dark to find`.

## Playtesting a build

- `start_stop_play` → `get_studio_state` to confirm the play state, `get_console_output` for errors.
- `character_navigation` moves the avatar to a position or instance; use it to walk the space (entrance → hero shot → exit) instead of trusting your mental map.
- `subagent` with `playtest` is useful for "can a player get from spawn to the shrine without getting stuck"; `explore` is useful for a compact summary of a big place.
- Stop the playtest before editing again. Edits made during play are discarded.

## When the toolbelt is smaller

Community MCP servers (e.g. ones exposing `run_code`, `insert_model`, `get_selection`, `undo`/`redo`, `get_playtest_output`) map cleanly onto the loop: `run_code` = `execute_luau`, `insert_model` = `insert_asset`. If there is no capture tool, build more conservatively, keep geometry simple and verifiable, print measurements, and tell the user visuals weren't inspected.

If there's **no MCP at all**, don't fake it: produce a single self-contained Luau script the user can paste into the Studio command bar, with the same tagged-folder discipline and a printed summary, and say where to run it.

## Multi-Studio

Multiple open Studio windows are addressed by `studio_id`. Always resolve it with `list_roblox_studios` at the start and pass the same ID for every call; two places can look identical and one of them is the user's live game.

## Token and time discipline

- Screenshots: 1 per pass normally, 3 when judging the final look.
- `search_game_tree`: depth ≤ 3, filtered.
- One `execute_luau` per meaningful stage, not per part.
- Print compactly: `print(("%d parts, bounds %s"):format(n, tostring(bounds)))` beats dumping a table of 800 instances.
