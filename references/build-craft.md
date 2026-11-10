# Build craft: scale, kit, composition, detail

## Scale reference (studs)

1 stud ≈ 0.28 m. Build against the R15 avatar, which is about **5 studs tall and 4 wide**, and can step up to **2 studs**.

| Thing | Size |
|---|---|
| Character (R15) | ~5 tall, ~4 wide |
| Door opening | 7–8 tall × 4–5 wide |
| Window | 3–4 tall, sill ~3 above the floor |
| Ceiling height | 10–14 (12 is comfortable) |
| Wall thickness | 0.5–1 |
| Floor slab | 1 |
| Stair step | rise 1.0, run 1.2 |
| Railing height | 3 |
| Counter / table | 3–3.5; chair seat 1.8–2 |
| Road lane | 12–16 wide |
| Single-storey building | 12–16 tall to eaves |
| Modular grid | 16 for buildings, 4 for interiors, 0.5 for alignment |

Two rules that fix most "it looks wrong" builds:

- A part's **position is its center**, not its corner. `y = floorTop + height/2` puts a part on the floor.
- Put positions on a **0.5-stud grid**. Off-grid parts never look flush, and flush is what reads as built rather than assembled.

## Modular kit

Build once, place many times. A kit of 8–15 pieces covers a whole town:

```
Kit/
  Wall_Straight_16      Wall_Door_16       Wall_Window_16
  Floor_16              Roof_Slope_16      Roof_Ridge_16
  Trim_Base_16          Trim_Cornice_16    Column_12
  Stair_8x12            Rail_16            Door_Single (Model: frame + slab + handle)
```

- Keep every piece the same module width so pieces swap without gaps.
- Build the kit in a scratch folder (`Workspace.__AgentBuild/Tavern/Kit`), then `:Clone()` pieces into place. Cloning a 6-part wall beats generating 6 parts at 40 locations, and it keeps the look consistent.
- Name pieces by module and use, not by number — you will be searching them later.
- Vary on placement: rotate a prop 3–12°, offset 0.05–0.15 studs, skip an occasional kit piece for a gap/ruin. Perfect repetition is the "asset flip" smell.

## Architecture details that carry realism

- **Recess openings.** Cut the wall into pieces around the opening and inset the frame 0.25–0.5 studs. A door slapped on a flat plane reads as a decal.
- **Trim everywhere**: baseboard, door casing, window mullions (a 0.15-stud cross), cornice, roof fascia. Cheap parts, huge payoff, and they catch the light.
- **Roofs**: slope 30–45°, overhang 1–2 studs past the wall, visible rafters under an eave. A flat box roof is the fastest way to look unfinished.
- **Foundations**: raise the floor 0.5–1 stud above terrain and add a plinth. Buildings sitting exactly on terrain look glued.
- **Interiors**: ceiling with a beam grid, wall thickness you can see in the doorway, baseboards, and one light per room. Empty rooms read as unfinished even when they're "clean".
- **Wear**: a few cracked tiles, a leaning board, a puddle `Part` with `Glass` material, a spilled crate. Two or three per area, not fifty.
- **Support**: if it's tall, it needs visible structure — columns, buttresses, cables, a base that widens. Floating towers look like bugs.

## Composition

- **Hero shot first.** Pick the camera the player gets on spawn; design the build around that frame, then make the other angles work.
- **Three layers**: foreground frame (lamp post, railing, arch), midground play space, background landmark. A build with only a midground looks like a diorama.
- **One focal point per vista.** A tower, a lit sign, a shrine, a crashed ship. Everything else supports it with lower contrast.
- **Value hierarchy**: ground dark, walls mid, focal element bright. Squint at your capture — the player should be one of the brightest or most saturated things on screen.
- **60-30-10 color**: 60% dominant hue, 30% secondary, 10% accent. Reserve the accent for interactables so the player's eye learns it.
- **Density contrast**: a calm plaza makes the crowded market feel crowded. Uniform detail everywhere flattens both.
- **Leading lines and sightlines**: paths, curbs, ceiling beams and doorways should point at something worth reaching. Block the boring directions with a wall or a crowd of props.
- **Verticality and negative space**: not every available stud needs a part. Gaps let the silhouette read and give the eye a rest.

## Set dressing

- **Clusters of three**: a table, two chairs and a mug. A crate, a barrel, a rope coil. Single props float; trios read as a scene.
- **Story props**: who was here and what were they doing? An overturned stool, a half-eaten plate, a dropped lantern, wet footprints (`Texture` on the floor), a scorch mark.
- **Density falls off** away from the play path. Near the path: detail at hand height. Far away: silhouette only (meshes, fewer parts, no collisions).
- **Height variety**: dressing lives at foot, hand and eye height. Everything on the floor at the same height reads as scatter.
- **Keep walkable space clear.** Dressing that blocks the player is a bug, not detail. Check with a walkthrough.

## Environment recipes

**Forest / wilderness** — Terrain for ground (`Grass`), scattered tree meshes at 3 scales with random yaw, a rock cluster on the skyline, a path of `Ground`/`LeafyGrass` material 8–10 studs wide, atmosphere density 0.4 with a cool tint, and mist `Atmosphere` in valleys. Trees: 30% hero quality near the path, 70% low-fidelity billboards/meshes far out.

**City block** — 16-stud module, 2–3 storey facades with recessed windows and awnings, a 12–16 stud street with curbs and lane paint (`Texture`), sidewalk 6–8 wide, street lamps every 24 studs, a hero landmark (tower/sign) on the axis, and light pools at night. Vary facade height and color, never the module.

**Interior (shop, tavern, base)** — 12-stud ceiling, beams at 4-stud spacing, baseboards, 2–3 light sources (one warm ceiling `SurfaceLight`, one accent), a counter with objects on it, shelving with 3–5 props per shelf, a rug or floor material change to divide space, and one story detail (an open ledger, a broken crate).

**Cave / ruin** — Terrain or chunky rocks with irregular, non-grid rotation; narrow then wide then narrow again; one light source at the far end to pull the player; puddles and rubble; darkness that is *dark* (Ambient near 0, no Atmosphere glare) so the light reads.

**Arena / obby** — readability beats beauty: high-contrast platforms against a low-contrast background, one accent color marking the route, a clear "you are here" landmark at spawn, and no detail that can be mistaken for a platform edge.

## Prop sourcing

- `search_asset` (Creator Store / your inventory) → `insert_asset` by ID is the fastest way to real props. Check the license (many are free, some require purchase) and the tri-count; a 40k-triangle chair is not a chair, it's a frame-time problem.
- `generate_mesh` for one-off hero props (a statue, a mascot), `generate_procedural_model` for parametric things (a fence line, a stair set, a modular wall). Both can take a reference image via `store_image`/`upload_image`.
- Keep sourced meshes on the same grid and scale as the kit, and set `CollisionFidelity = Hull` + `RenderFidelity = Performance` on decoration.
- Prefer a coherent set from one source over pieces from six sources: mixed art styles are the loudest "made by a committee" signal.

## CSG

Unions are great for one-off shapes (arches, cut-out walls, rubble) and terrible in bulk. Scripted CSG is slower than primitives and harder to iterate. Use it for the hero geometry, not for a wall grid you could build from 6 kit parts, and prefer `GeometryService:UnionAsync` over legacy methods when available. Keep collisions simple after unioning (`CollisionFidelity = Hull` or `Box`).
