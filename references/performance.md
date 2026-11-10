# Performance for builds

Beauty that drops frames isn't beauty. Roblox runs on phones with a fraction of a desktop GPU, so the build has to be disciplined even when the art direction isn't.

## Budgets

| Target | Sensible budget |
|---|---|
| Detailed area (a shop, courtyard, room) | 2–3k parts |
| A whole medium map | 10–20k parts, with streaming on |
| Parts visible in one frame | keep under ~5k |
| Unique materials in view | under ~12 |
| Shadow-casting dynamic lights in view | under ~10 |
| Mesh triangulation | props ≤ 5k tris; hero assets ≤ 20k |
| Simultaneous transparent surfaces | a handful, never stacked |

These are rules of thumb for 30fps on mid-tier mobile, not guarantees. Measure when it matters (MicroProfiler, Studio's performance stats, `Stats.RenderStats`), and test in a real playtest — never estimate from part count alone.

## Don't tile flat surfaces

The most common self-inflicted performance bug in Roblox builds. A 40×40 floor of 4×4 tiles is 100 parts, 100 draw calls, and a z-fighting risk at every seam, for a look identical to one 40×1×40 part with a texture.

- One part per flat plane; use a `Texture` with correct `StudsPerTileU`/`StudsPerTileV` for the pattern.
- If you need variation, split into 3–6 panels, not 100.
- `Union` big flat assemblies if you must cut holes, but keep the count low.

## Streaming

- Enable `Workspace.StreamingEnabled` for maps over ~1000 studs. It's the biggest client-side win available and it's free.
- It only works if the place is structured for it: group spatially related parts into `Model`s (`ModelStreamingMode = Atomic` when a script needs all of a model).
- Keep each model under ~64 cubic studs so it streams as a unit. Break big buildings into floor-by-floor or room-by-room models.
- `Model.LevelOfDetail = SLIM` on static decorations (not on anything animated or scripted).
- Streaming changes what exists on the client at a given moment. Don't rely on far-away instances existing in client scripts — server-side is the source of truth.

## Meshes and fidelity

- `RenderFidelity = Performance` for background props, `Automatic` for the hero shot, `Precise` only where the silhouette must hold at close range (it's the expensive one).
- `CollisionFidelity = Hull` (or `Box` for blocky props). `Precise` collisions are for things the player physically interacts with and are a real cost.
- No collisions at all (`CanCollide = false`, `CanQuery = false`) on decoration, foliage, trim, and anything outside the playable area.
- Convert repeated detail into a mesh once, then clone. A hundred identical parts is a hundred draw calls; a hundred clones of one mesh is far cheaper.
- Billboards and flat textures for distant background (trees on the horizon, city skyline): they cost almost nothing and read as depth.

## Lights and shadows

- Dynamic lights with `Shadows = true` are the expensive kind. Reserve them for the hero shot and the lights along the play path.
- Interior rooms need ~1 warm ceiling light each, not 6. Use `SurfaceLight` with a wide `Angle` instead of several point lights.
- `Neon` is cheap and self-illuminating; use it for signage and practicals rather than adding real lights behind them.
- Prefer baking a sense of light into the level (brightness contrast, warm/cool split) over adding more sources.
- On mobile-targeted maps, `LightingStyle = Realistic`/`Future` may need to drop to `ShadowMap`. Ask which device the target audience uses before spending frames.

## Transparency

- Stacked transparent parts multiply overdraw. A window, behind it a glass pane, behind that a transparent particle — that's three full-screen-ish blends.
- `Transparency = 0.02` still counts as transparent. If it doesn't need to be seen through, make it opaque.
- Particles: keep emission rates modest; a fog volume is cheaper than 500 particle emitters.

## Terrain

- Terrain is efficient for large organic areas and terrible as a substitute for walls and floors.
- Don't mix terrain and parts in a way that makes terrain pop through a floor; terrain cells are coarse and will poke through thin slabs.
- Large maps: `Terrain:WriteVoxels` batching beats per-voxel `FillBlock` calls if you're generating terrain from code.

## Measurement

- Studio: **MicroProfiler** (Ctrl+F6 / the MicroProfiler button) for frame spikes, and the **Performance** stats panel for part/mesh counts and triangles.
- Runtime: `Stats.RenderStats` (draw calls, triangles) and `Stats.Network` are readable from a client script when debugging.
- Measure the busiest moment — the hero shot with all players, effects and lights — not the empty spawn.
- If the user reports lag, ask for the device and the place size before optimizing. Guessing usually makes the build uglier without fixing the frame time.

## The cheap wins, in order

1. Untile flat surfaces.
2. Turn off collisions on decoration.
3. Enable streaming on big maps.
4. Reduce shadow-casting lights.
5. Lower `RenderFidelity` on background props.
6. Merge repeated detail into meshes.
7. Reduce stacked transparency.

Almost every laggy Roblox build is fixed by 1–4.
