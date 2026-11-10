---
name: roblox-build
description: Builds and polishes beautiful Roblox environments inside Roblox Studio through the Studio MCP server — maps, buildings, interiors, props, terrain, lighting, material and set dressing. Use this skill whenever someone wants something built, dressed, or made to look good in Roblox: "build me a house / castle / city / alley / shop interior in Studio", "my greybox looks flat", "make this Roblox map look good", "the lighting is ugly", "add detail and props to my scene", "can you build this from this reference image", or whenever a Roblox Studio or Studio MCP task is about the look of the place rather than its code — including execute_luau building scripts, screen_capture review, and Creator Store asset sourcing. Covers blockout, detail, lighting, composition, performance, and visual verification. For gameplay systems, remotes, data and monetization, use the roblox-game-dev skill instead.
---

# Building beautiful Roblox environments

A Roblox place reads as "good" for four reasons, in this order of leverage:

1. **Lighting** — it changes the entire scene without touching a single asset. Most "flat" places are a lighting problem, not a modelling problem.
2. **Composition and scale** — where the eye goes, whether things are the right size next to a player, whether the silhouette reads.
3. **Material coherence** — a small, consistent material palette instead of 40 random Plastic parts.
4. **Detail where it matters** — trim, edges, clutter, and story props on the things the player actually walks past.

Art assets come last, and often not at all. A well-lit, well-composed blockout looks better than a badly-lit sculpted one. Budget your effort accordingly, and never skip straight to props.

## 0. Check your toolbelt first

Capabilities differ between the official Studio MCP server and community ones, and they change. Before planning, list what you actually have — usually via `list_roblox_studios`, then `get_studio_state`. Expect most of these, but verify:

| Need | Official Studio MCP tool |
|---|---|
| Build / edit anything | `execute_luau` (`datamodel_type`: `Edit`, `Server`, or `Client`) |
| Read the place | `search_game_tree`, `inspect_instance`, `script_read`, `script_grep` |
| See the result | `screen_capture` (optionally with a camera position + look-at target) |
| Read errors / prints | `get_console_output` |
| Playtest | `start_stop_play`, `subagent` (`playtest`, `explore`), `character_navigation`, `user_keyboard_input`, `user_mouse_input` |
| Assets | `search_asset`, `insert_asset`, `generate_mesh`, `generate_material`, `generate_procedural_model`, `upload_image` |
| Docs | `http_get`, `skill` |

Community servers may expose `run_code`, `insert_model`, `get_selection`, `undo`/`redo` instead. Map the concept, not the name: everything reduces to *run Luau in Edit mode* and *look at the screen*. If there is **no** screenshot or playtest tool, say so plainly at the end — you can verify structure and numbers, not how it looks.

Every official tool call also takes a `studio_id`; get it from `list_roblox_studios` and keep using it.

## 1. Look before you build

Never start creating parts in a place you haven't inspected. One pass, cheap:

- `screen_capture` from a player-height camera — what does it look like now?
- `search_game_tree` with a depth limit (2–3) — what already exists, what are the workspace folders, is there a Lighting setup?
- `inspect_instance` on `Lighting` and `Workspace` — lighting technology, streaming settings, part count.

Then state the plan in one or two sentences: what style, what mood, what the hero shot is. This is the difference between a build and a pile.

## 2. Lock the style bible before the first part

Decisions made once, kept for the whole build. Put them in a file (`assets/style-bible.md` is a fill-in template) and reference them in every `execute_luau` call.

- **Three adjectives** for the mood (`weathered Nordic fishing village`, `neon-lit cyberpunk market`), not generic ones (`cool`, `nice`).
- **Palette**: 4–6 colors max, with one accent reserved for interactables. Everything else is value variation of the base hues.
- **Material language**: pick 4–6 materials and what each one means (`WoodPlanks` = structure, `Concrete` = civic, `Metal` = industrial). Consistency is what reads as intentional.
- **Grid**: a module size (16 studs is a good default for buildings, 4 for interiors) and the rule that floors, walls and roofs land on it.
- **Silhouette rule**: what makes this place recognizable from 100 studs away (a tower, a crane, a giant sign, a broken arch).

## 3. Blockout, then verify, then detail

Build in passes. Each pass ends with a screenshot from the player's actual camera, because self-evaluation without looking is how you get a build that only works top-down.

**Pass A — massing.** Big shapes only, correct scale, no materials beyond base colors. Get the silhouette and the flow right. If it doesn't read as a building/arena/cave here, detail won't fix it.

**Pass B — architecture.** Floors, walls, openings, roof, trim. Modelled from a small modular kit, not bespoke parts (see `references/build-craft.md`):
- Doors 7–8 studs tall × 4–5 wide; ceiling 10–14; wall 0.5–1 thick; stairs rise 1.0 / run 1.2; railing 3.
- Recess openings instead of pasting a door slab on a flat wall — depth is most of what makes Roblox architecture look real.
- Bevels and trim (`0.25`–`0.5` stud lips, cornices, window mullions) catch the light and break up flat planes.

**Pass C — materials and lighting.** Then, and only then, the pass that does the most work. See §4 and `references/lighting-and-materials.md`.

**Pass D — set dressing.** Clutter in clusters of 3, story props (`a knocked-over chair, a mug, a puddle`), and density that falls off away from the play space. Empty is fine; uniformly-spaced props look like a level editor.

## 4. Lighting and atmosphere

The single highest-leverage pass. Work in this order:

1. **Set the lighting mode.** On current Studio, `Lighting.LightingStyle = Enum.LightingStyle.Realistic` (the old `Soft` value is the flat look). If your engine version still uses `Lighting.Technology`, `Future` gives per-light shadows and real specular highlights at a real frame cost. **This property is often capability-gated from scripts** — if writing it errors, set it in the Properties panel and tell the user to. Either way it's a build-time decision, not a runtime one.
2. **Sun and exposure**: `ClockTime`, `Brightness` (2–3 daylight), `Ambient`/`OutdoorAmbient` (dark, desaturated, never pure black), `ExposureCompensation` (±0.3 max), `EnvironmentDiffuseScale`/`EnvironmentSpecularScale`.
3. **Atmosphere**: `Density` 0.2–0.4, `Offset` 0.1–0.25, `Haze` 0.5–2, `Color` as the scene's average tint. This is what creates depth — distance should *fade*, not just shrink.
4. **Post effects, one job each**: `BloomEffect` (only genuinely bright pixels), `ColorCorrectionEffect` (contrast +0.1, saturation small), `DepthOfFieldEffect` (subtle, focus far), `SunRaysEffect` (light, exterior only).
5. **Local lights**: a few real `PointLight`/`SurfaceLight`/`SpotLight` with `Shadows` on where it matters. Light pools are what make interiors read as interiors.

`assets/lighting-presets.luau` has five complete presets (golden hour, overcast, interior warm, night neon, storm) you can apply in one call and then tune.

## 5. Composition — where the eye goes

- **One hero shot.** Decide what the player sees first and build toward it. If everything is equally detailed, nothing is.
- **Silhouette and value contrast**: the player must read against the background. Don't put a dark doorway directly behind a dark character path.
- **Layering**: foreground frame (a lamp post, a railing), midground play space, background landmark. Three depths make a scene feel like a place.
- **Density contrast**: leave calm, empty space next to dense detail. Constant detail is noise.
- **Leading lines and frames**: paths, curbs, ceilings and doorways should point at the focal point.
- **Repetition with variance**: the same kit repeated is good; identical rotation and identical props in every slot is not. Vary rotation, wear props, and small offsets (±0.05–0.15 studs) so nothing lines up perfectly.
- **Scale check**: always judge against the ~5-stud character. A door 4 studs tall feels like a dollhouse; a 30-stud-wide room feels like a warehouse.

## 6. Performance is part of beauty

A gorgeous build that stutters on a phone is a failed build. `references/performance.md` has the detail; the rules that matter while building:

- **Don't tile flat surfaces.** One 40×1×40 floor slab, not 100 4×1×4 tiles. Same look, 1% of the parts.
- **Budget**: ~2–3k parts for a detailed medium build; past ~10k you need streaming and LOD hygiene, not more parts.
- **`StreamingEnabled`** for anything over ~1000 studs, with models grouped spatially and kept under ~64 cubic studs so they stream in as a unit.
- **Mesh fidelity**: `CollisionFidelity = Hull`, `RenderFidelity = Performance`/`Automatic` on decorative meshes; no collisions at all on things the player can't touch.
- **Transparency overdraw** and stacked transparent parts are expensive; `Neon` is cheap but only looks good in small doses.

## 7. Verify visually, every pass

Never report a build as done from script output alone. The loop is:

1. `execute_luau` (Edit) — create/change, and **print a summary**: part count, bounding box, what was created. `print` output comes back to you.
2. `screen_capture` — from the player camera, plus one wide shot. Pass an explicit camera position + look-at so the framing is deliberate, not whatever the viewport last showed.
3. Compare against the style bible. Name three concrete flaws. Fix them.
4. Repeat until the fixes are cosmetic tweaks rather than structural changes.

Then check: `get_console_output` clean, part count in budget, and a walkthrough (`start_stop_play` + `character_navigation`) doesn't clip or trap the player.

If you have no screenshot tool, say exactly that: "structure and counts verified, visuals not inspected". Do not describe a build as beautiful you have never seen.

## Working safely in someone's place

- Build under a single folder, e.g. `Workspace.__AgentBuild/<BuildName>`, so it can be reviewed and removed in one action. Move pieces into place only after the pass is approved.
- **Tag everything you create** with an attribute (`AgentBuild = true`, plus `BuildName` and `Pass`). It makes cleanup, undo and "what did the agent touch?" trivial. `assets/build-utils.luau` does this for you.
- Never delete or move instances you didn't create, never edit gameplay scripts, never run playtests that write to DataStores, and never publish or save over a live place.
- Call `ChangeHistoryService:SetWaypoint()` before a big pass so the user can Ctrl+Z a whole stage.
- Prefer many small, reviewable passes over one giant `execute_luau` that builds a city. If a call fails halfway, you want a known state, not a mystery.

## What's in this skill

| Path | Read it when |
|---|---|
| `assets/build-utils.luau` | **Before any build.** ModuleScript: tagged `part`/`wedge`/`cylinder`/`model`/`batch` helpers, grid snapping, provenance tagging, `Build.verify()` sanity checks, `Build.clearAll()` cleanup. |
| `assets/lighting-presets.luau` | The lighting pass. Five full presets (sun/atmosphere/post FX) + `apply(name)`. |
| `assets/style-bible.md` | Start of any build bigger than one room; keeps palette, materials, grid and mood consistent across calls. |
| `references/mcp-workflow.md` | Tool recipes, camera framing, batching, error handling, undo, multi-Studio, and what to do when the MCP server has fewer tools. |
| `references/lighting-and-materials.md` | Lighting numbers per mood, PBR/`SurfaceAppearance` rules, texture scale, material vocabulary. |
| `references/build-craft.md` | Scale table, modular kit, architecture details, composition, set dressing, environment recipes, prop sourcing. |
| `references/performance.md` | Streaming, part budgets, LOD, collisions, lights, mobile targets. |
| `evals/evals.json` | To test whether this skill is producing good builds. |

## Anti-patterns (the "AI build" tells)

- Every object the same 4×1×2 brick, unrotated, evenly spaced.
- Ten materials picked for variety rather than meaning; `SmoothPlastic` everywhere.
- Default `Soft` lighting with a default Atmosphere, so nothing fades and nothing contrasts.
- Parts floating, intersecting, or off the 0.5-stud grid, so surfaces never look flush.
- Detail concentrated on wall tops nobody sees; nothing at player eye level.
- Clutter as confetti: 500 tiny parts scattered to "add detail" instead of 40 deliberate ones.
- Flat floors tiled into hundreds of parts, then a complaint that the place runs badly.
- Touching gameplay scripts or deleting existing content to make room.
- Claiming it looks great without ever looking at a capture.
